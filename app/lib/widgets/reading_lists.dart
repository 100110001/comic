import 'package:flutter/material.dart';
import 'display_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/comic.dart';
import '../models/favorite_author.dart';
import '../models/reading_progress_entry.dart';
import '../providers/comics_providers.dart';
import '../providers/reading_progress_provider.dart';
import '../screens/detail_screen.dart';
import '../screens/search_screen.dart';
import '../theme.dart';
import '../utils/user_error.dart';
import 'status_views.dart';
import 'comic_grid.dart';

class RecentReadingList extends ConsumerStatefulWidget {
  const RecentReadingList({super.key});

  @override
  ConsumerState<RecentReadingList> createState() => _RecentReadingListState();
}

class _RecentReadingListState extends ConsumerState<RecentReadingList> {
  @override
  Widget build(BuildContext context) {
    final async = ref.watch(recentReadingWithLocalProvider);
    final items = async.value ?? const <ReadingProgressEntry>[];
    final loading = async.isLoading && items.isEmpty;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960),
        child: RefreshIndicator(
          onRefresh: () async => ref.invalidate(recentReadingProvider),
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : async.hasError && items.isEmpty
              ? StatusView(
                  icon: Icons.cloud_off,
                  message: userMessageFor(async.error, fallback: '加载失败'),
                  actionLabel: '重试',
                  onAction: () => ref.invalidate(recentReadingProvider),
                )
              : items.isEmpty
              ? const EmptyListView(message: '暂无最近阅读')
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: items.length + 1,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (ctx, i) {
                    if (i == 0) {
                      return _CollectionHeading(
                        title: '最近读过',
                        count: '${items.length} 本',
                        note: '最近阅读优先',
                      );
                    }
                    final e = items[i - 1];
                    return _EntryTile(
                      coverUrl: e.comic.coverUrl,
                      title: e.comic.title,
                      author: e.comic.author,
                      subtitle: '${e.chapterTitle} · 第${e.pageNumber + 1}页',
                      onTap: () => Navigator.push(
                        ctx,
                        MaterialPageRoute(
                          builder: (_) => DetailScreen(comicId: e.comic.id),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}

class FavoritesList extends ConsumerStatefulWidget {
  const FavoritesList({super.key});

  @override
  ConsumerState<FavoritesList> createState() => _FavoritesListState();
}

class _FavoritesListState extends ConsumerState<FavoritesList> {
  @override
  Widget build(BuildContext context) {
    final async = ref.watch(favoritesProvider);
    final items = async.value ?? const <Comic>[];
    final loading = async.isLoading && items.isEmpty;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960),
        child: RefreshIndicator(
          onRefresh: () async => ref.invalidate(favoritesProvider),
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : async.hasError && items.isEmpty
              ? StatusView(
                  icon: Icons.cloud_off,
                  message: userMessageFor(async.error, fallback: '加载失败'),
                  actionLabel: '重试',
                  onAction: () => ref.invalidate(favoritesProvider),
                )
              : items.isEmpty
              ? const EmptyListView(message: '暂无收藏')
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(28, 8, 28, 20),
                      child: _CollectionHeading(
                        title: '收藏的漫画',
                        count: '${items.length} 本',
                        note: '按收藏时间',
                      ),
                    ),
                    Expanded(
                      child: ComicGrid(
                        comics: items
                            .map((comic) => comic.withFavorited(true))
                            .toList(),
                        loading: false,
                        onTap: (comic) => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => DetailScreen(comicId: comic.id),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class FavoriteAuthorsList extends ConsumerStatefulWidget {
  const FavoriteAuthorsList({super.key});

  @override
  ConsumerState<FavoriteAuthorsList> createState() =>
      _FavoriteAuthorsListState();
}

class _FavoriteAuthorsListState extends ConsumerState<FavoriteAuthorsList> {
  @override
  Widget build(BuildContext context) {
    final async = ref.watch(favoriteAuthorsProvider);
    final items = async.value ?? const <FavoriteAuthor>[];
    final loading = async.isLoading && items.isEmpty;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960),
        child: RefreshIndicator(
          onRefresh: () async => ref.invalidate(favoriteAuthorsProvider),
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : async.hasError && items.isEmpty
              ? StatusView(
                  icon: Icons.cloud_off,
                  message: userMessageFor(async.error, fallback: '加载失败'),
                  actionLabel: '重试',
                  onAction: () => ref.invalidate(favoriteAuthorsProvider),
                )
              : items.isEmpty
              ? const EmptyListView(message: '暂无收藏作者')
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final columns =
                        constraints.maxWidth >= 640 &&
                            MediaQuery.textScalerOf(context).scale(14) <= 20
                        ? 2
                        : 1;
                    final rows = (items.length / columns).ceil();
                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: rows + 1,
                      separatorBuilder: (_, _) => const SizedBox(height: 16),
                      itemBuilder: (context, row) {
                        if (row == 0) {
                          return _CollectionHeading(
                            title: '关注的创作者',
                            count: '${items.length} 位',
                            note: '按收藏时间',
                          );
                        }
                        final start = (row - 1) * columns;
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (var col = 0; col < columns; col++) ...[
                              if (col > 0) const SizedBox(width: 16),
                              Expanded(
                                child: start + col < items.length
                                    ? _AuthorCard(author: items[start + col])
                                    : const SizedBox.shrink(),
                              ),
                            ],
                          ],
                        );
                      },
                    );
                  },
                ),
        ),
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  final String? coverUrl;
  final String title;
  final String? author;
  final String subtitle;
  final VoidCallback onTap;

  const _EntryTile({
    required this.coverUrl,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.author,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Material(
      color: c.surface1,
      borderRadius: BorderRadius.circular(kRadiusCard),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(kRadiusThumb),
                child: SizedBox(
                  width: 76,
                  height: 76 * 4 / 3,
                  child: coverUrl != null
                      ? DisplayNetworkImage(
                          coverUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => _placeholder(context),
                        )
                      : _placeholder(context),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: c.text1,
                        fontSize: 17,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (author != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        author!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: c.text2, fontSize: 12),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: c.accent.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(kRadiusSmall),
                      ),
                      child: Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: c.accent, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: c.text2, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholder(BuildContext context) {
    final c = context.appColors;
    return Container(
      color: c.surface2,
      child: Icon(Icons.auto_stories_outlined, color: c.text2),
    );
  }
}

class _CollectionHeading extends StatelessWidget {
  const _CollectionHeading({
    required this.title,
    required this.count,
    required this.note,
  });
  final String title;
  final String count;
  final String note;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 16,
      runSpacing: 8,
      children: [
        Text(
          '$title · $count',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
        ),
        Text(note, style: Theme.of(context).textTheme.bodySmall),
      ],
    ),
  );
}

class _AuthorCard extends ConsumerWidget {
  const _AuthorCard({required this.author});
  final FavoriteAuthor author;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.appColors;
    final books = ref.watch(favoriteAuthorBooksProvider(author.author));
    void openWorks() => Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SearchScreen(initialKeyword: author.author),
      ),
    );
    return Material(
      color: c.surface1,
      borderRadius: BorderRadius.circular(kRadiusCard),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: c.accent.withValues(alpha: 0.10),
                  child: Icon(Icons.person_outline, color: c.accent, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Tooltip(
                        message: author.author,
                        child: Text(
                          author.author,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${author.comicCount} 部作品',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.star_outline, color: c.star, size: 18),
              ],
            ),
            const SizedBox(height: 20),
            if (books.isLoading && !books.hasValue)
              const SizedBox(
                height: 96,
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else if (books.hasError && !books.hasValue)
              TextButton.icon(
                onPressed: () =>
                    ref.invalidate(favoriteAuthorBooksProvider(author.author)),
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('封面加载失败，重试'),
              )
            else if (books.value?.isNotEmpty ?? false)
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final comic in books.value!)
                    Tooltip(
                      message: comic.title,
                      child: SizedBox(
                        width: 72,
                        height: 96,
                        child: Material(
                          color: c.surface2,
                          borderRadius: BorderRadius.circular(kRadiusThumb),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => DetailScreen(comicId: comic.id),
                              ),
                            ),
                            child: comic.coverUrl == null
                                ? Icon(
                                    Icons.auto_stories_outlined,
                                    color: c.text2,
                                  )
                                : DisplayNetworkImage(
                                    comic.coverUrl!,
                                    errorBuilder: (_, _, _) => Icon(
                                      Icons.auto_stories_outlined,
                                      color: c.text2,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: openWorks,
              icon: const Icon(Icons.north_east, size: 16),
              label: const Text('查看全部作品'),
            ),
          ],
        ),
      ),
    );
  }
}
