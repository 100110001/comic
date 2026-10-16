import 'dart:async';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/chapter.dart';
import '../models/comic.dart';
import '../models/favorite_author.dart';
import '../models/reading_progress_entry.dart';
import '../services/api_client.dart';
import '../services/library_reading_session.dart';
import 'server_provider.dart';

// Riverpod 会在加载与失败时保留 previous；来源改变后只允许展示当前来源的快照。
abstract class ServerQueryNotifier<T> extends AsyncNotifier<T> {
  int? _requestedGeneration;
  int? _valueGeneration;

  Future<T> trackSource(ApiClient client, Future<T> Function() query) async {
    _requestedGeneration = client.generation;
    final result = await query();
    if (ref.mounted &&
        ref.read(apiClientProvider).generation == client.generation) {
      _valueGeneration = client.generation;
    }
    return result;
  }

  AsyncValue<T> get currentSourceState {
    // 尚未开始服务端查询时，状态由初始化过程提供。
    if (_requestedGeneration == null ||
        _valueGeneration == ref.read(apiClientProvider).generation) {
      return state;
    }
    return state.isLoading || state.hasError
        ? state.unwrapPrevious()
        : AsyncLoading<T>();
  }
}

// ---- 简单查询（会话内缓存） ----

class FavoritesNotifier extends ServerQueryNotifier<List<Comic>> {
  @override
  Future<List<Comic>> build() {
    final client = ref.watch(apiClientProvider);
    return trackSource(client, client.getFavorites);
  }

  void confirm(int comicId, bool favorited, Comic? comic) {
    final current = currentSourceState.value;
    if (current != null) {
      final remaining = current.where((item) => item.id != comicId).toList();
      state = AsyncData(
        favorited && comic != null
            ? [comic.withFavorited(true), ...remaining]
            : favorited
            ? current
            : remaining,
      );
    }
    ref.invalidateSelf();
  }
}

final favoritesProvider = AsyncNotifierProvider<FavoritesNotifier, List<Comic>>(
  FavoritesNotifier.new,
  retry: (_, _) => null,
);

class FavoriteAuthorsNotifier
    extends ServerQueryNotifier<List<FavoriteAuthor>> {
  @override
  Future<List<FavoriteAuthor>> build() {
    final client = ref.watch(apiClientProvider);
    return trackSource(client, client.getFavoriteAuthors);
  }

  void confirm(String author, bool favorited) {
    final current = currentSourceState.value;
    if (!favorited && current != null) {
      state = AsyncData(
        current.where((item) => item.author != author).toList(),
      );
    }
    ref.invalidateSelf();
  }
}

final favoriteAuthorsProvider =
    AsyncNotifierProvider<FavoriteAuthorsNotifier, List<FavoriteAuthor>>(
      FavoriteAuthorsNotifier.new,
      retry: (_, _) => null,
    );

/// 作者卡片只展示该作者的真实作品，不把标题命中的其他漫画当成其作品。
final favoriteAuthorBooksProvider = FutureProvider.autoDispose
    .family<List<Comic>, String>((ref, author) async {
      final result = await ref
          .watch(apiClientProvider)
          .getComics(keyword: author, pageSize: 8);
      return result.list
          .where((comic) => comic.author == author)
          .take(2)
          .toList();
    }, retry: (_, _) => null);

final recentReadingProvider = FutureProvider<List<ReadingProgressEntry>>(
  (ref) => ref.watch(apiClientProvider).getRecent(),
  retry: (_, _) => null,
);

class ComicDetail {
  final Comic comic;
  final List<Chapter> chapters;
  final bool favorited;
  final bool authorFavorited;
  final ({int chapterId, int pageNumber})? progress;

  const ComicDetail({
    required this.comic,
    required this.chapters,
    required this.favorited,
    required this.authorFavorited,
    this.progress,
  });
}

// 注册实际存在的查询，收藏确认只同步这些缓存，不额外发起首页或搜索请求。
class _ComicQueries {
  final details = <ComicDetailNotifier>{};
  final searches = <SearchNotifier>{};
  final libraries = <RandomLibraryNotifier>{};
}

final _comicQueriesProvider = Provider((ref) => _ComicQueries());

class ComicDetailNotifier extends ServerQueryNotifier<ComicDetail> {
  ComicDetailNotifier(this.comicId);
  final int comicId;

  @override
  Future<ComicDetail> build() async {
    final queries = ref.read(_comicQueriesProvider);
    queries.details.add(this);
    ref.onDispose(() => queries.details.remove(this));
    final client = ref.watch(apiClientProvider);
    return trackSource(client, () async {
      final r = await client.getComic(comicId);
      return ComicDetail(
        comic: r.comic,
        chapters: r.chapters,
        favorited: r.favorited,
        authorFavorited: r.authorFavorited,
        progress: r.progress,
      );
    });
  }

  ComicDetail? get current => currentSourceState.value;

  void confirm({bool? favorited, String? author, bool? authorFavorited}) {
    final detail = currentSourceState.value;
    if (detail != null) {
      state = AsyncData(
        ComicDetail(
          comic: favorited == null
              ? detail.comic
              : detail.comic.withFavorited(favorited),
          chapters: detail.chapters,
          favorited: favorited ?? detail.favorited,
          authorFavorited: author == detail.comic.author
              ? authorFavorited ?? detail.authorFavorited
              : detail.authorFavorited,
          progress: detail.progress,
        ),
      );
    }
    // 先更新已确认值，再使旧请求失效；刷新失败仍可展示已确认的缓存。
    ref.invalidateSelf();
  }
}

final comicDetailProvider =
    AsyncNotifierProvider.family<ComicDetailNotifier, ComicDetail, int>(
      ComicDetailNotifier.new,
      retry: (_, _) => null,
    );

typedef _ComicPage = ({List<Comic> list, int total});

// 只记录请求尚在途期间发生的确认，读取完成即释放；后续刷新仍以服务器为准。
class _FavoriteReads {
  final _pending = <Map<int, bool>>{};

  void confirm(int comicId, bool favorited) {
    for (final changes in _pending) {
      changes[comicId] = favorited;
    }
  }

  Future<_ComicPage> track(Future<_ComicPage> Function() request) async {
    final changes = <int, bool>{};
    _pending.add(changes);
    try {
      final result = await request();
      return (
        list: result.list
            .map(
              (comic) => changes.containsKey(comic.id)
                  ? comic.withFavorited(changes[comic.id]!)
                  : comic,
            )
            .toList(),
        total: result.total,
      );
    } finally {
      _pending.remove(changes);
    }
  }
}

// ---- 首页分页（排序与 seed 独立持有，收藏变更不重排） ----

enum LibrarySort { random, recent }

class LibrarySortNotifier extends Notifier<LibrarySort> {
  @override
  LibrarySort build() => LibrarySort.random;

  void select(LibrarySort sort) => state = sort;
}

final librarySortProvider = NotifierProvider<LibrarySortNotifier, LibrarySort>(
  LibrarySortNotifier.new,
);

class RandomSeedNotifier extends Notifier<int> {
  @override
  int build() => Random().nextInt(1 << 31);

  void reshuffle() => state = Random().nextInt(1 << 31);
}

final randomSeedProvider = NotifierProvider<RandomSeedNotifier, int>(
  RandomSeedNotifier.new,
);

class RandomLibraryState {
  final LibrarySort sort;
  final int seed;
  final int pageOffset;
  final int total;
  final int pageSize;
  final List<Comic> comics;
  final bool isLoadingMore;
  final bool isRefreshing;
  final Object? error;

  const RandomLibraryState({
    this.sort = LibrarySort.random,
    required this.seed,
    required this.pageOffset,
    required this.total,
    required this.pageSize,
    required this.comics,
    this.isLoadingMore = false,
    this.isRefreshing = false,
    this.error,
  });

  RandomLibraryState copyWith({
    int? pageOffset,
    int? total,
    int? pageSize,
    List<Comic>? comics,
    bool? isLoadingMore,
    bool? isRefreshing,
    Object? error,
    bool clearError = false,
  }) => RandomLibraryState(
    sort: sort,
    seed: seed,
    pageOffset: pageOffset ?? this.pageOffset,
    total: total ?? this.total,
    pageSize: pageSize ?? this.pageSize,
    comics: comics ?? this.comics,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    isRefreshing: isRefreshing ?? this.isRefreshing,
    error: clearError ? null : error ?? this.error,
  );
}

class RandomLibraryNotifier extends ServerQueryNotifier<RandomLibraryState> {
  final _favoriteReads = _FavoriteReads();
  int _queryGeneration = 0;
  int _pageSize = 30;
  Future<void>? _refreshFuture;

  LibraryReadingSession readingSession() {
    final s = currentSourceState.requireValue;
    final client = ref.read(apiClientProvider);
    return LibraryReadingSession(
      client: client,
      isCurrent: () =>
          ref.mounted &&
          ref.read(serverSessionProvider).generation == client.generation,
      comics: s.comics,
      total: s.total,
      pageSize: s.pageSize,
      seed: s.seed,
      recent: s.sort == LibrarySort.recent,
    );
  }

  bool _isCurrent(ApiClient client, int queryGeneration) =>
      ref.mounted &&
      _queryGeneration == queryGeneration &&
      ref.read(serverSessionProvider).generation == client.generation;

  @override
  Future<RandomLibraryState> build() async {
    final queries = ref.read(_comicQueriesProvider);
    queries.libraries.add(this);
    ref.onDispose(() => queries.libraries.remove(this));
    final client = ref.watch(apiClientProvider);
    final sort = ref.watch(librarySortProvider);
    _refreshFuture = null;
    _queryGeneration++;
    final seed = ref.read(randomSeedProvider);
    final result = await _fetch(
      client: client,
      sort: sort,
      seed: seed,
      pageOffset: 1,
      pageSize: _pageSize,
    );
    return result.copyWith(pageSize: _pageSize);
  }

  Future<RandomLibraryState> _fetch({
    required ApiClient client,
    required LibrarySort sort,
    required int seed,
    required int pageOffset,
    required int pageSize,
  }) => trackSource(client, () async {
    final r = await _favoriteReads.track(
      () => client.getComics(
        random: sort == LibrarySort.random,
        seed: sort == LibrarySort.random ? seed : null,
        recent: sort == LibrarySort.recent,
        pageOffset: pageOffset,
        pageSize: pageSize,
      ),
    );
    return RandomLibraryState(
      sort: sort,
      seed: seed,
      pageOffset: pageOffset,
      total: r.total,
      pageSize: pageSize,
      comics: r.list,
    );
  });

  void setPageSize(int size) {
    size = size.clamp(1, 100);
    _pageSize = size;
    final s = currentSourceState.value;
    if (s == null || s.pageSize == size) return;
    state = state.whenData((s) => s.copyWith(pageSize: size));
  }

  Future<void> loadMore() async {
    final s = currentSourceState.value;
    if (s == null ||
        state.isLoading ||
        s.isRefreshing ||
        s.isLoadingMore ||
        s.comics.length >= s.total) {
      return;
    }
    final client = ref.read(apiClientProvider);
    final generation = _queryGeneration;
    // 接口偏移由页号和页大小共同决定；变更页大小后从已消费位置续接。
    final skip = s.comics.length % s.pageSize;
    state = AsyncData(s.copyWith(isLoadingMore: true));
    try {
      final next = await _fetch(
        client: client,
        sort: s.sort,
        seed: s.seed,
        pageOffset: s.comics.length ~/ s.pageSize + 1,
        pageSize: s.pageSize,
      );
      if (!_isCurrent(client, generation)) return;
      final current = state.requireValue;
      state = AsyncData(
        current.copyWith(
          pageOffset: next.pageOffset,
          total: next.total,
          comics: [...current.comics, ...next.comics.skip(skip)],
          isLoadingMore: false,
          clearError: true,
        ),
      );
    } catch (_) {
      if (!_isCurrent(client, generation)) return;
      state = AsyncData(state.requireValue.copyWith(isLoadingMore: false));
      rethrow;
    }
  }

  Future<void> reshuffle() {
    if (state.isLoading) return future.then((_) {});
    final existing = _refreshFuture;
    if (existing != null) return existing;
    late final Future<void> pending;
    pending = _reshuffle().whenComplete(() {
      if (identical(_refreshFuture, pending)) _refreshFuture = null;
    });
    _refreshFuture = pending;
    return pending;
  }

  Future<void> _reshuffle() async {
    final sort = ref.read(librarySortProvider);
    if (sort == LibrarySort.random) {
      ref.read(randomSeedProvider.notifier).reshuffle();
    }
    if (currentSourceState.value == null) {
      ref.invalidateSelf();
      await future;
      return;
    }
    final seed = ref.read(randomSeedProvider);
    final client = ref.read(apiClientProvider);
    final generation = ++_queryGeneration;
    state = AsyncData(
      state.requireValue.copyWith(
        isLoadingMore: false,
        isRefreshing: true,
        clearError: true,
      ),
    );
    try {
      final next = await _fetch(
        client: client,
        sort: sort,
        seed: seed,
        pageOffset: 1,
        pageSize: _pageSize,
      );
      if (!_isCurrent(client, generation)) return;
      state = AsyncData(next.copyWith(pageSize: _pageSize));
    } catch (error) {
      if (!_isCurrent(client, generation)) return;
      state = AsyncData(
        state.requireValue.copyWith(isRefreshing: false, error: error),
      );
      rethrow;
    }
  }

  void updateFavorited(int comicId, bool favorited) {
    _favoriteReads.confirm(comicId, favorited);
    final s = currentSourceState.value;
    if (s == null) return;
    state = state.whenData(
      (s) => s.copyWith(
        comics: s.comics
            .map((c) => c.id == comicId ? c.withFavorited(favorited) : c)
            .toList(),
      ),
    );
  }
}

final randomLibraryProvider =
    AsyncNotifierProvider<RandomLibraryNotifier, RandomLibraryState>(
      RandomLibraryNotifier.new,
      retry: (_, _) => null,
    );

// ---- 搜索（关键字 + 分页） ----

class SearchState {
  final String keyword;
  final int pageOffset;
  final int total;
  final List<Comic> comics;
  final bool isLoadingMore;
  final bool isRefreshing;
  final Object? error;

  const SearchState({
    required this.keyword,
    required this.pageOffset,
    required this.total,
    required this.comics,
    this.isLoadingMore = false,
    this.isRefreshing = false,
    this.error,
  });

  SearchState copyWith({
    String? keyword,
    int? pageOffset,
    int? total,
    List<Comic>? comics,
    bool? isLoadingMore,
    bool? isRefreshing,
    Object? error,
    bool clearError = false,
  }) => SearchState(
    keyword: keyword ?? this.keyword,
    pageOffset: pageOffset ?? this.pageOffset,
    total: total ?? this.total,
    comics: comics ?? this.comics,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    isRefreshing: isRefreshing ?? this.isRefreshing,
    error: clearError ? null : error ?? this.error,
  );
}

class SearchNotifier extends AsyncNotifier<SearchState> {
  final _favoriteReads = _FavoriteReads();
  int _queryGeneration = 0;

  @override
  SearchState build() {
    final queries = ref.read(_comicQueriesProvider);
    queries.searches.add(this);
    ref.onDispose(() => queries.searches.remove(this));
    ref.watch(apiClientProvider);
    _queryGeneration++;
    return const SearchState(keyword: '', pageOffset: 1, total: 0, comics: []);
  }

  bool _isCurrent(ApiClient client, int queryGeneration) =>
      ref.mounted &&
      _queryGeneration == queryGeneration &&
      ref.read(serverSessionProvider).generation == client.generation;

  Future<void> search(String keyword) async {
    final client = ref.read(apiClientProvider);
    final generation = ++_queryGeneration;
    final cached = state.value;
    final previous = cached?.keyword == keyword
        ? cached!.copyWith(isLoadingMore: false)
        : SearchState(
            keyword: keyword,
            pageOffset: 1,
            total: 0,
            comics: const [],
          );
    if (keyword.isEmpty) {
      state = AsyncData(previous);
      return;
    }
    state = AsyncData(previous.copyWith(isRefreshing: true, clearError: true));
    try {
      final r = await _favoriteReads.track(
        () => client.getComics(pageOffset: 1, pageSize: 30, keyword: keyword),
      );
      if (!_isCurrent(client, generation)) return;
      state = AsyncData(
        SearchState(
          keyword: keyword,
          pageOffset: 1,
          total: r.total,
          comics: r.list,
        ),
      );
    } catch (error) {
      if (!_isCurrent(client, generation)) return;
      state = AsyncData(
        state.requireValue.copyWith(isRefreshing: false, error: error),
      );
      rethrow;
    }
  }

  Future<void> loadMore() async {
    final s = state.value;
    if (s == null ||
        state.isLoading ||
        s.isRefreshing ||
        s.isLoadingMore ||
        s.keyword.isEmpty ||
        s.comics.length >= s.total) {
      return;
    }
    final client = ref.read(apiClientProvider);
    final generation = _queryGeneration;
    state = AsyncData(s.copyWith(isLoadingMore: true));
    try {
      final r = await _favoriteReads.track(
        () => client.getComics(
          pageOffset: s.pageOffset + 1,
          pageSize: 30,
          keyword: s.keyword,
        ),
      );
      if (!_isCurrent(client, generation)) return;
      final current = state.requireValue;
      state = AsyncData(
        current.copyWith(
          pageOffset: s.pageOffset + 1,
          total: r.total,
          comics: [...current.comics, ...r.list],
          isLoadingMore: false,
          clearError: true,
        ),
      );
    } catch (_) {
      if (!_isCurrent(client, generation)) return;
      state = AsyncData(state.requireValue.copyWith(isLoadingMore: false));
      rethrow;
    }
  }

  void updateFavorited(int comicId, bool favorited) {
    _favoriteReads.confirm(comicId, favorited);
    final s = state.value;
    if (s == null) return;
    state = state.whenData(
      (s) => s.copyWith(
        comics: s.comics
            .map((c) => c.id == comicId ? c.withFavorited(favorited) : c)
            .toList(),
      ),
    );
  }
}

final searchProvider = AsyncNotifierProvider<SearchNotifier, SearchState>(
  SearchNotifier.new,
  retry: (_, _) => null,
);

// 每个页面独立持有搜索会话，嵌套作者搜索不会替换上层查询。
final searchSessionProvider = AsyncNotifierProvider.autoDispose
    .family<SearchNotifier, SearchState, Object>(
      (_) => SearchNotifier(),
      retry: (_, _) => null,
    );

class FavoriteMutationState {
  const FavoriteMutationState({
    this.comics = const {},
    this.authors = const {},
  });
  final Set<int> comics;
  final Set<String> authors;
  bool comicBusy(int id) => comics.contains(id);
  bool authorBusy(String author) => authors.contains(author);
}

class FavoriteMutations extends Notifier<FavoriteMutationState> {
  final _comicRequests = <int, Future<void>>{};
  final _authorRequests = <String, Future<void>>{};

  @override
  FavoriteMutationState build() {
    ref.watch(apiClientProvider);
    _comicRequests.clear();
    _authorRequests.clear();
    return const FavoriteMutationState();
  }

  bool _current(ApiClient client) =>
      ref.mounted &&
      ref.read(apiClientProvider).generation == client.generation;

  Future<void> setComicFavorite({
    required int comicId,
    required bool favorited,
  }) {
    final existing = _comicRequests[comicId];
    if (existing != null) return existing;
    final client = ref.read(apiClientProvider);
    state = FavoriteMutationState(
      comics: {...state.comics, comicId},
      authors: state.authors,
    );
    late final Future<void> pending;
    pending = _setComic(client, comicId, favorited).whenComplete(() {
      if (!_current(client) || !identical(_comicRequests[comicId], pending)) {
        return;
      }
      _comicRequests.remove(comicId);
      state = FavoriteMutationState(
        comics: {...state.comics}..remove(comicId),
        authors: state.authors,
      );
    });
    _comicRequests[comicId] = pending;
    return pending;
  }

  Future<void> _setComic(ApiClient client, int comicId, bool favorited) async {
    await client.setFavorite(comicId, favorited);
    if (!_current(client)) return;
    final queries = ref.read(_comicQueriesProvider);
    Comic? comic;
    for (final detail in queries.details.toList()) {
      if (detail.comicId == comicId) {
        comic = detail.current?.comic;
        detail.confirm(favorited: favorited);
      }
    }
    if (ref.exists(favoritesProvider)) {
      ref.read(favoritesProvider.notifier).confirm(comicId, favorited, comic);
    }
    for (final library in queries.libraries.toList()) {
      library.updateFavorited(comicId, favorited);
    }
    for (final search in queries.searches.toList()) {
      search.updateFavorited(comicId, favorited);
    }
  }

  Future<void> setAuthorFavorite({
    required String author,
    required bool favorited,
  }) {
    final existing = _authorRequests[author];
    if (existing != null) return existing;
    final client = ref.read(apiClientProvider);
    state = FavoriteMutationState(
      comics: state.comics,
      authors: {...state.authors, author},
    );
    late final Future<void> pending;
    pending = _setAuthor(client, author, favorited).whenComplete(() {
      if (!_current(client) || !identical(_authorRequests[author], pending)) {
        return;
      }
      _authorRequests.remove(author);
      state = FavoriteMutationState(
        comics: state.comics,
        authors: {...state.authors}..remove(author),
      );
    });
    _authorRequests[author] = pending;
    return pending;
  }

  Future<void> _setAuthor(
    ApiClient client,
    String author,
    bool favorited,
  ) async {
    await client.setAuthorFavorite(author, favorited);
    if (!_current(client)) return;
    for (final detail in ref.read(_comicQueriesProvider).details.toList()) {
      // 尚在首屏加载的详情也必须淘汰变更前的响应。
      if (detail.current == null || detail.current!.comic.author == author) {
        detail.confirm(author: author, authorFavorited: favorited);
      }
    }
    if (ref.exists(favoriteAuthorsProvider)) {
      ref.read(favoriteAuthorsProvider.notifier).confirm(author, favorited);
    }
  }
}

final favoriteMutationsProvider =
    NotifierProvider<FavoriteMutations, FavoriteMutationState>(
      FavoriteMutations.new,
    );

Future<void> openComicDirectory(WidgetRef ref, int comicId) async {
  final client = ref.read(apiClientProvider);
  await client.openComicDirectory(comicId);
}

final currentFavoritesProvider = Provider<AsyncValue<List<Comic>>>((ref) {
  ref.watch(favoritesProvider);
  ref.watch(apiClientProvider);
  return ref.read(favoritesProvider.notifier).currentSourceState;
});
final currentFavoriteAuthorsProvider =
    Provider<AsyncValue<List<FavoriteAuthor>>>((ref) {
      ref.watch(favoriteAuthorsProvider);
      ref.watch(apiClientProvider);
      return ref.read(favoriteAuthorsProvider.notifier).currentSourceState;
    });
final currentComicDetailProvider =
    Provider.family<AsyncValue<ComicDetail>, int>((ref, id) {
      ref.watch(comicDetailProvider(id));
      ref.watch(apiClientProvider);
      return ref.read(comicDetailProvider(id).notifier).currentSourceState;
    });
final currentRandomLibraryProvider = Provider<AsyncValue<RandomLibraryState>>((
  ref,
) {
  ref.watch(randomLibraryProvider);
  ref.watch(apiClientProvider);
  return ref.read(randomLibraryProvider.notifier).currentSourceState;
});
