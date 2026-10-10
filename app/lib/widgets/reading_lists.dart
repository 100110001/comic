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
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (ctx, i) {
                    final e = items[i];
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
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (ctx, i) {
                    final comic = items[i];
                    return _EntryTile(
                      coverUrl: comic.coverUrl,
                      title: comic.title,
                      author: comic.author,
                      subtitle: '${comic.chapterCount}话 · ${comic.imageCount}P',
                      onTap: () => Navigator.push(
                        ctx,
                        MaterialPageRoute(
                          builder: (_) => DetailScreen(comicId: comic.id),
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
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (ctx, i) {
                    final item = items[i];
                    return Material(
                      color: context.appColors.surface1,
                      borderRadius: BorderRadius.circular(kRadiusCard),
                      clipBehavior: Clip.antiAlias,
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: context.appColors.star.withValues(
                              alpha: 0.08,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.person_outline,
                            color: context.appColors.star,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          item.author,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: context.appColors.text1,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: Text(
                          '${item.comicCount} 部作品',
                          style: TextStyle(
                            color: context.appColors.text2,
                            fontSize: 12,
                          ),
                        ),
                        trailing: Icon(
                          Icons.chevron_right,
                          color: context.appColors.text2,
                        ),
                        onTap: () => Navigator.push(
                          ctx,
                          MaterialPageRoute(
                            builder: (_) =>
                                SearchScreen(initialKeyword: item.author),
                          ),
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
                  width: 60,
                  height: 80,
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
                        fontSize: 15,
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
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: c.text2, fontSize: 12),
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
      child: Icon(Icons.image_not_supported, color: c.text2),
    );
  }
}
