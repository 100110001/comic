import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/chapter.dart';
import '../models/comic.dart';
import '../models/favorite_author.dart';
import '../models/reading_progress_entry.dart';
import '../services/api.dart';

// ---- 简单查询（会话内缓存） ----

final favoritesProvider = FutureProvider<List<Comic>>(
  (ref) => ApiService.getFavorites(),
);

final favoriteAuthorsProvider = FutureProvider<List<FavoriteAuthor>>(
  (ref) => ApiService.getFavoriteAuthors(),
);

final recentReadingProvider = FutureProvider<List<ReadingProgressEntry>>(
  (ref) => ApiService.getRecent(),
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
  final r = await ApiService.getComic(id);
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

  const RandomLibraryState({
    required this.seed,
    required this.pageOffset,
    required this.total,
    required this.pageSize,
    required this.comics,
  });

  RandomLibraryState copyWith({
    int? pageOffset,
    int? total,
    int? pageSize,
    List<Comic>? comics,
  }) => RandomLibraryState(
    seed: seed,
    pageOffset: pageOffset ?? this.pageOffset,
    total: total ?? this.total,
    pageSize: pageSize ?? this.pageSize,
    comics: comics ?? this.comics,
  );
}

class RandomLibraryNotifier extends AsyncNotifier<RandomLibraryState> {
  @override
  Future<RandomLibraryState> build() async {
    final seed = ref.read(randomSeedProvider);
    return _fetch(seed: seed, pageOffset: 1, pageSize: 30);
  }

  Future<RandomLibraryState> _fetch({
    required int seed,
    required int pageOffset,
    required int pageSize,
  }) async {
    final r = await ApiService.getRandomPage(
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

  Future<void> setPageSize(int size) async {
    final s = state.value;
    if (s == null || s.pageSize == size) return;
    state = AsyncData(s.copyWith(pageSize: size));
  }

  Future<void> loadMore() async {
    final s = state.value;
    if (s == null || s.comics.length >= s.total) return;
    final next = await _fetch(
      seed: s.seed,
      pageOffset: s.pageOffset + 1,
      pageSize: s.pageSize,
    );
    state = AsyncData(
      s.copyWith(
        pageOffset: next.pageOffset,
        total: next.total,
        comics: [...s.comics, ...next.comics],
      ),
    );
  }

  Future<void> reshuffle() async {
    ref.read(randomSeedProvider.notifier).reshuffle();
    final seed = ref.read(randomSeedProvider);
    final s = state.value;
    final pageSize = s?.pageSize ?? 30;
    final next = await _fetch(seed: seed, pageOffset: 1, pageSize: pageSize);
    state = AsyncData(next);
  }

  void updateFavorited(int comicId, bool favorited) {
    final s = state.value;
    if (s == null) return;
    state = AsyncData(
      s.copyWith(
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

  const SearchState({
    required this.keyword,
    required this.pageOffset,
    required this.total,
    required this.comics,
  });

  SearchState copyWith({
    String? keyword,
    int? pageOffset,
    int? total,
    List<Comic>? comics,
  }) => SearchState(
    keyword: keyword ?? this.keyword,
    pageOffset: pageOffset ?? this.pageOffset,
    total: total ?? this.total,
    comics: comics ?? this.comics,
  );
}

class SearchNotifier extends AsyncNotifier<SearchState> {
  @override
  Future<SearchState> build() async =>
      const SearchState(keyword: '', pageOffset: 1, total: 0, comics: []);

  Future<void> search(String keyword) async {
    final r = await ApiService.getComics(
      pageOffset: 1,
      pageSize: 30,
      keyword: keyword,
    );
    state = AsyncData(
      SearchState(
        keyword: keyword,
        pageOffset: 1,
        total: r.total,
        comics: r.list,
      ),
    );
  }

  Future<void> loadMore() async {
    final s = state.value;
    if (s == null || s.keyword.isEmpty || s.comics.length >= s.total) return;
    final r = await ApiService.getComics(
      pageOffset: s.pageOffset + 1,
      pageSize: 30,
      keyword: s.keyword,
    );
    state = AsyncData(
      s.copyWith(
        pageOffset: s.pageOffset + 1,
        total: r.total,
        comics: [...s.comics, ...r.list],
      ),
    );
  }

  void updateFavorited(int comicId, bool favorited) {
    final s = state.value;
    if (s == null) return;
    state = AsyncData(
      s.copyWith(
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
  Ref ref, {
  required int comicId,
  required bool favorited,
}) async {
  await ApiService.setFavorite(comicId, favorited);
  ref.invalidate(favoritesProvider);
  ref.invalidate(comicDetailProvider(comicId));
  // 列表原地更新收藏角标，避免重排或丢失已加载分页
  ref.read(randomLibraryProvider.notifier).updateFavorited(comicId, favorited);
  ref.read(searchProvider.notifier).updateFavorited(comicId, favorited);
}

Future<void> setAuthorFavorite(
  Ref ref, {
  required String author,
  required bool favorited,
  required int comicId,
}) async {
  await ApiService.setAuthorFavorite(author, favorited);
  ref.invalidate(favoriteAuthorsProvider);
  ref.invalidate(comicDetailProvider(comicId));
}
