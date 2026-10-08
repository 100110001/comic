import 'package:flutter/material.dart';
import '../widgets/display_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/chapter.dart';
import '../models/comic.dart';
import '../providers/comics_providers.dart';
import '../providers/reading_progress_provider.dart';
import '../theme.dart';
import '../utils/user_error.dart';
import '../widgets/status_views.dart';
import 'reader_screen.dart';
import 'search_screen.dart';

class DetailScreen extends ConsumerStatefulWidget {
  final int comicId;
  const DetailScreen({super.key, required this.comicId});

  @override
  ConsumerState<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends ConsumerState<DetailScreen> {
  bool _favoriteBusy = false;
  bool _authorFavoriteBusy = false;

  Future<void> _toggleFavorite() async {
    if (_favoriteBusy) return;
    final detail = ref.read(comicDetailProvider(widget.comicId)).value;
    if (detail == null) return;
    setState(() => _favoriteBusy = true);
    try {
      await setComicFavorite(
        ref,
        comicId: widget.comicId,
        favorited: !detail.favorited,
      );
    } catch (error) {
      if (mounted) _showError(error, '收藏操作失败');
    } finally {
      if (mounted) setState(() => _favoriteBusy = false);
    }
  }

  Future<void> _toggleAuthorFavorite() async {
    if (_authorFavoriteBusy) return;
    final detail = ref.read(comicDetailProvider(widget.comicId)).value;
    final author = detail?.comic.author;
    if (detail == null || author == null) return;
    setState(() => _authorFavoriteBusy = true);
    try {
      await setAuthorFavorite(
        ref,
        author: author,
        favorited: !detail.authorFavorited,
        comicId: widget.comicId,
      );
    } catch (error) {
      if (mounted) _showError(error, '作者收藏操作失败');
    } finally {
      if (mounted) setState(() => _authorFavoriteBusy = false);
    }
  }

  void _showError(Object error, String fallback) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(userMessageFor(error, fallback: fallback))),
    );
  }

  void _continueReading(({int chapterId, int pageNumber}) progress) {
    final detail = ref.read(comicDetailProvider(widget.comicId)).value;
    var chapterTitle = '';
    for (final c in detail?.chapters ?? const <Chapter>[]) {
      if (c.id == progress.chapterId) {
        chapterTitle = c.title;
        break;
      }
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReaderScreen(
          comicId: widget.comicId,
          chapterId: progress.chapterId,
          title: chapterTitle,
          initialPage: progress.pageNumber,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(comicDetailProvider(widget.comicId));
    final detail = detailAsync.value;
    final pending = ref.watch(localReadingProgressProvider(widget.comicId));
    final local = pending?.position;
    final progress =
        local != null &&
            detail?.chapters.any((chapter) => chapter.id == local.chapterId) ==
                true
        ? local
        : detail?.progress;
    final c = context.appColors;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          detail?.comic.title ?? '',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (detail != null)
            IconButton(
              tooltip: detail.favorited ? '取消收藏' : '收藏',
              icon: Icon(
                detail.favorited ? Icons.favorite : Icons.favorite_border,
                color: detail.favorited ? c.favorite : c.text1,
              ),
              onPressed: _favoriteBusy ? null : _toggleFavorite,
            ),
        ],
      ),
      body: detailAsync.isLoading
          ? const Center(child: CircularProgressIndicator())
          : detailAsync.hasError
          ? StatusView(
              icon: Icons.cloud_off,
              message: userMessageFor(detailAsync.error, fallback: '加载失败'),
              actionLabel: '重试',
              onAction: () =>
                  ref.invalidate(comicDetailProvider(widget.comicId)),
            )
          : LayoutBuilder(
              builder: (ctx, constraints) {
                final header = _Header(
                  vertical: constraints.maxWidth >= 720,
                  comic: detail!.comic,
                  favorited: detail.favorited,
                  authorFavorited: detail.authorFavorited,
                  onToggleFavorite: _favoriteBusy ? null : _toggleFavorite,
                  onToggleAuthorFavorite: _authorFavoriteBusy
                      ? null
                      : _toggleAuthorFavorite,
                  onAuthorTap: (author) => Navigator.push(
                    ctx,
                    MaterialPageRoute(
                      builder: (_) => SearchScreen(initialKeyword: author),
                    ),
                  ),
                  progress: progress,
                  onContinue: progress == null
                      ? detail.chapters.isEmpty
                            ? null
                            : () {
                                final first = detail.chapters.first;
                                Navigator.push(
                                  ctx,
                                  MaterialPageRoute(
                                    builder: (_) => ReaderScreen(
                                      comicId: widget.comicId,
                                      chapterId: first.id,
                                      title: first.title,
                                      initialPage: 0,
                                    ),
                                  ),
                                );
                              }
                      : () => _continueReading(progress),
                );
                final chapterList = _ChapterList(
                  comicId: widget.comicId,
                  chapters: detail.chapters,
                  currentChapterId: progress?.chapterId,
                );
                if (constraints.maxWidth >= 720) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: 360,
                        child: SingleChildScrollView(child: header),
                      ),
                      const VerticalDivider(width: 1),
                      Expanded(child: chapterList),
                    ],
                  );
                }
                return CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(child: header),
                    _ChapterList(
                      comicId: widget.comicId,
                      chapters: detail.chapters,
                      currentChapterId: progress?.chapterId,
                      asSliver: true,
                    ),
                  ],
                );
              },
            ),
    );
  }
}

class _Header extends StatelessWidget {
  final bool vertical;
  final Comic comic;
  final bool favorited;
  final bool authorFavorited;
  final VoidCallback? onToggleFavorite;
  final VoidCallback? onToggleAuthorFavorite;
  final void Function(String author)? onAuthorTap;
  final ({int chapterId, int pageNumber})? progress;
  final VoidCallback? onContinue;

  const _Header({
    required this.vertical,
    required this.comic,
    required this.favorited,
    required this.authorFavorited,
    this.onToggleFavorite,
    this.onToggleAuthorFavorite,
    this.onAuthorTap,
    this.progress,
    this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final cover = ClipRRect(
      borderRadius: BorderRadius.circular(kRadiusCard),
      child: SizedBox(
        width: vertical ? 160 : 96,
        height: vertical ? 214 : 128,
        child: comic.coverUrl != null
            ? DisplayNetworkImage(
                comic.coverUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _placeholder(context),
              )
            : _placeholder(context),
      ),
    );
    final metadata = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(comic.title, style: Theme.of(context).textTheme.titleLarge),
        if (comic.author != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Flexible(
                child: TextButton(
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    alignment: Alignment.centerLeft,
                  ),
                  onPressed: () => onAuthorTap?.call(comic.author!),
                  child: Text(
                    comic.author!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              IconButton(
                tooltip: authorFavorited ? '取消收藏作者' : '收藏作者',
                icon: Icon(
                  authorFavorited ? Icons.star : Icons.star_border,
                  color: authorFavorited ? c.star : c.text2,
                  size: 20,
                ),
                onPressed: onToggleAuthorFavorite,
              ),
            ],
          ),
        ],
        const SizedBox(height: 8),
        Text(
          '${comic.chapterCount} 话 · ${comic.imageCount} 页',
          style: TextStyle(color: c.text2, fontSize: 13),
        ),
      ],
    );
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: c.surface1,
        borderRadius: BorderRadius.circular(kRadiusFloat),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (vertical) ...[
            Center(child: cover),
            const SizedBox(height: 24),
            metadata,
          ] else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                cover,
                const SizedBox(width: 16),
                Expanded(child: metadata),
              ],
            ),
          const SizedBox(height: 20),
          FilledButton.icon(
            icon: const Icon(Icons.play_arrow_rounded, size: 22),
            label: Text(
              progress != null
                  ? '继续阅读'
                  : onContinue != null
                  ? '开始阅读'
                  : '暂无章节',
            ),
            onPressed: onContinue,
          ),
          if (progress != null) ...[
            const SizedBox(height: 8),
            Text(
              '上次读到第 ${progress!.pageNumber + 1} 页',
              textAlign: TextAlign.center,
              style: TextStyle(color: c.text2, fontSize: 12),
            ),
          ],
          const SizedBox(height: 10),
          OutlinedButton.icon(
            icon: Icon(
              favorited ? Icons.favorite : Icons.favorite_border,
              color: favorited ? c.favorite : c.text2,
              size: 18,
            ),
            label: Text(favorited ? '已收藏' : '收藏漫画'),
            onPressed: onToggleFavorite,
          ),
        ],
      ),
    );
  }

  Widget _placeholder(BuildContext context) {
    final c = context.appColors;
    return Container(
      width: 100,
      height: 140,
      color: c.surface2,
      child: Icon(Icons.image_not_supported, color: c.text2),
    );
  }
}

class _ChapterList extends StatelessWidget {
  final int comicId;
  final List<Chapter> chapters;
  final int? currentChapterId;
  final bool asSliver;
  const _ChapterList({
    required this.comicId,
    required this.chapters,
    this.currentChapterId,
    this.asSliver = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final sliver = SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      sliver: SliverList.builder(
        itemCount: chapters.length + 1,
        itemBuilder: (ctx, i) {
          if (i == 0) {
            return Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 20),
              child: Row(
                children: [
                  Text('章节目录', style: Theme.of(ctx).textTheme.titleMedium),
                  const SizedBox(width: 10),
                  Text(
                    '${chapters.length} 话',
                    style: TextStyle(color: c.text2, fontSize: 12),
                  ),
                ],
              ),
            );
          }
          final ch = chapters[i - 1];
          final isCurrent = ch.id == currentChapterId;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: isCurrent ? c.accent.withValues(alpha: 0.10) : c.surface1,
              borderRadius: BorderRadius.circular(kRadiusButton),
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                leading: Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: c.bg,
                    borderRadius: BorderRadius.circular(kRadiusThumb),
                  ),
                  child: Text(
                    '$i',
                    style: TextStyle(
                      color: isCurrent ? c.accent : c.text2,
                      fontSize: 12,
                    ),
                  ),
                ),
                title: Text(
                  ch.title,
                  style: TextStyle(
                    color: isCurrent ? c.accent : c.text1,
                    fontSize: 14,
                    fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
                subtitle: isCurrent
                    ? Text(
                        '上次读到这里',
                        style: TextStyle(color: c.accent, fontSize: 12),
                      )
                    : null,
                trailing: Icon(
                  isCurrent ? Icons.menu_book : Icons.chevron_right,
                  color: isCurrent ? c.accent : c.text2,
                  size: 20,
                ),
                onTap: () => Navigator.push(
                  ctx,
                  MaterialPageRoute(
                    builder: (_) => ReaderScreen(
                      comicId: comicId,
                      chapterId: ch.id,
                      title: ch.title,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
    return asSliver ? sliver : CustomScrollView(slivers: [sliver]);
  }
}
