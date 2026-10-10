import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/chapter.dart';
import '../models/comic.dart';
import '../models/favorite_author.dart';
import '../models/reading_progress_entry.dart';
import '../services/api_client.dart';
import 'server_provider.dart';

// ---- 简单查询（会话内缓存） ----

final favoritesProvider = FutureProvider<List<Comic>>(
  (ref) => ref.watch(apiClientProvider).getFavorites(),
);

final favoriteAuthorsProvider = FutureProvider<List<FavoriteAuthor>>(
  (ref) => ref.watch(apiClientProvider).getFavoriteAuthors(),
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
    });

final recentReadingProvider = FutureProvider<List<ReadingProgressEntry>>(
  (ref) => ref.watch(apiClientProvider).getRecent(),
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

final comicDetailProvider = FutureProvider.family<ComicDetail, int>((
  ref,
  id,
) async {
  final r = await ref.watch(apiClientProvider).getComic(id);
  return ComicDetail(
    comic: r.comic,
    chapters: r.chapters,
    favorited: r.favorited,
    authorFavorited: r.authorFavorited,
    progress: r.progress,
  );
});

// ---- 首页随机分页（seed 独立持有，失效不重排） ----

class RandomSeedNotifier extends Notifier<int> {
  @override
  int build() => Random().nextInt(1 << 31);

  void reshuffle() => state = Random().nextInt(1 << 31);
}

final randomSeedProvider = NotifierProvider<RandomSeedNotifier, int>(
  RandomSeedNotifier.new,
);

class RandomLibraryState {
  final int seed;
  final int pageOffset;
  final int total;
  final int pageSize;
  final List<Comic> comics;
  final bool isLoadingMore;
  final bool isRefreshing;
  final Object? error;

  const RandomLibraryState({
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

class RandomLibraryNotifier extends AsyncNotifier<RandomLibraryState> {
  int _queryGeneration = 0;
  int _pageSize = 30;

  bool _isCurrent(ApiClient client, int queryGeneration) =>
      ref.mounted &&
      _queryGeneration == queryGeneration &&
      ref.read(serverSessionProvider).generation == client.generation;

  @override
  Future<RandomLibraryState> build() async {
    final client = ref.watch(apiClientProvider);
    _queryGeneration++;
    final seed = ref.read(randomSeedProvider);
    final result = await _fetch(
      client: client,
      seed: seed,
      pageOffset: 1,
      pageSize: _pageSize,
    );
    return result.copyWith(pageSize: _pageSize);
  }

  Future<RandomLibraryState> _fetch({
    required ApiClient client,
    required int seed,
    required int pageOffset,
    required int pageSize,
  }) async {
    final r = await client.getRandomPage(
      seed: seed,
      pageOffset: pageOffset,
      pageSize: pageSize,
    );
    return RandomLibraryState(
      seed: seed,
      pageOffset: pageOffset,
      total: r.total,
      pageSize: pageSize,
      comics: r.list,
    );
  }

  void setPageSize(int size) {
    _pageSize = size;
    final s = state.value;
    if (s == null || s.pageSize == size) return;
    state = state.whenData((s) => s.copyWith(pageSize: size));
  }

  Future<void> loadMore() async {
    final s = state.value;
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

  Future<void> reshuffle() async {
    ref.read(randomSeedProvider.notifier).reshuffle();
    if (state.value == null) {
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

final randomLibraryProvider =
    AsyncNotifierProvider<RandomLibraryNotifier, RandomLibraryState>(
      RandomLibraryNotifier.new,
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
  int _queryGeneration = 0;

  @override
  SearchState build() {
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
      final r = await client.getComics(
        pageOffset: 1,
        pageSize: 30,
        keyword: keyword,
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
      final r = await client.getComics(
        pageOffset: s.pageOffset + 1,
        pageSize: 30,
        keyword: s.keyword,
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
);

// ---- 变更助手（mutation + 失效矩阵） ----

Future<void> setComicFavorite(
  WidgetRef ref, {
  required int comicId,
  required bool favorited,
}) async {
  final client = ref.read(apiClientProvider);
  await client.setFavorite(comicId, favorited);
  if (ref.read(serverSessionProvider).generation != client.generation) return;
  ref.invalidate(favoritesProvider);
  ref.invalidate(comicDetailProvider(comicId));
  // 列表原地更新收藏角标，避免重排或丢失已加载分页
  ref.read(randomLibraryProvider.notifier).updateFavorited(comicId, favorited);
  ref.read(searchProvider.notifier).updateFavorited(comicId, favorited);
}

Future<void> setAuthorFavorite(
  WidgetRef ref, {
  required String author,
  required bool favorited,
  required int comicId,
}) async {
  final client = ref.read(apiClientProvider);
  await client.setAuthorFavorite(author, favorited);
  if (ref.read(serverSessionProvider).generation != client.generation) return;
  ref.invalidate(favoriteAuthorsProvider);
  ref.invalidate(comicDetailProvider(comicId));
}

Future<void> openComicDirectory(WidgetRef ref, int comicId) async {
  final client = ref.read(apiClientProvider);
  await client.openComicDirectory(comicId);
}
