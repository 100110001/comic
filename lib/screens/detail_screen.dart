import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/chapter.dart';
import '../models/comic.dart';
import '../providers/comics_providers.dart';
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
    } finally {
      if (mounted) setState(() => _authorFavoriteBusy = false);
    }
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

    return Scaffold(
      backgroundColor: const Color(0xFF0d1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161b22),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          detail?.comic.title ?? '',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white, fontSize: 15),
        ),
        actions: [
          if (detail != null)
            IconButton(
              tooltip: detail.favorited ? '取消收藏' : '收藏',
              icon: Icon(
                detail.favorited ? Icons.favorite : Icons.favorite_border,
                color: detail.favorited
                    ? const Color(0xFFf778ba)
                    : Colors.white,
              ),
              onPressed: _favoriteBusy ? null : _toggleFavorite,
            ),
        ],
      ),
      body: detailAsync.isLoading
          ? const Center(child: CircularProgressIndicator())
          : detailAsync.hasError
          ? _DetailError(
              onRetry: () =>
                  ref.invalidate(comicDetailProvider(widget.comicId)),
            )
          : LayoutBuilder(
              builder: (ctx, constraints) {
                final header = _Header(
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
                  progress: detail.progress,
                  onContinue: detail.progress == null
                      ? null
                      : () => _continueReading(detail.progress!),
                );
                final chapterList = _ChapterList(
                  comicId: widget.comicId,
                  chapters: detail.chapters,
                );
                if (constraints.maxWidth >= 720) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: 330,
                        child: SingleChildScrollView(child: header),
                      ),
                      const VerticalDivider(width: 1, color: Color(0xFF21262d)),
                      Expanded(child: chapterList),
                    ],
                  );
                }
                return Column(
                  children: [
                    header,
                    const Divider(color: Color(0xFF21262d), height: 1),
                    Expanded(child: chapterList),
                  ],
                );
              },
            ),
    );
  }
}

class _DetailError extends StatelessWidget {
  final VoidCallback onRetry;
  const _DetailError({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off, color: Color(0xFF8b949e), size: 48),
          const SizedBox(height: 12),
          const Text('加载失败', style: TextStyle(color: Color(0xFF8b949e))),
          const SizedBox(height: 12),
          FilledButton.tonal(onPressed: onRetry, child: const Text('重试')),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final Comic comic;
  final bool favorited;
  final bool authorFavorited;
  final VoidCallback? onToggleFavorite;
  final VoidCallback? onToggleAuthorFavorite;
  final void Function(String author)? onAuthorTap;
  final ({int chapterId, int pageNumber})? progress;
  final VoidCallback? onContinue;

  const _Header({
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
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: comic.coverUrl != null
                ? Image.network(
                    comic.coverUrl!,
                    width: 100,
                    height: 140,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => _placeholder(),
                  )
                : _placeholder(),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  comic.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (comic.author != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Flexible(
                        child: GestureDetector(
                          onTap: () => onAuthorTap?.call(comic.author!),
                          child: Text(
                            comic.author!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF58a6ff),
                              fontSize: 13,
                              decoration: TextDecoration.underline,
                              decorationColor: Color(0xFF58a6ff),
                            ),
                          ),
                        ),
                      ),
                      if (onToggleAuthorFavorite != null) ...[
                        const SizedBox(width: 4),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          tooltip: authorFavorited ? '取消收藏作者' : '收藏作者',
                          icon: Icon(
                            authorFavorited ? Icons.star : Icons.star_border,
                            color: authorFavorited
                                ? const Color(0xFFf5c542)
                                : const Color(0xFF8b949e),
                            size: 18,
                          ),
                          onPressed: onToggleAuthorFavorite,
                        ),
                      ],
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  '${comic.chapterCount}话 · ${comic.imageCount}P',
                  style: const TextStyle(
                    color: Color(0xFF58a6ff),
                    fontSize: 12,
                  ),
                ),
                if (progress != null) ...[
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF58a6ff),
                      foregroundColor: Colors.black,
                    ),
                    icon: const Icon(Icons.play_arrow, size: 18),
                    label: const Text('继续阅读'),
                    onPressed: onContinue,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder() => Container(
    width: 100,
    height: 140,
    color: const Color(0xFF21262d),
    child: const Icon(Icons.image_not_supported, color: Color(0xFF8b949e)),
  );
}

class _ChapterList extends StatelessWidget {
  final int comicId;
  final List<Chapter> chapters;
  const _ChapterList({required this.comicId, required this.chapters});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: chapters.length,
      separatorBuilder: (_, _) =>
          const Divider(color: Color(0xFF21262d), height: 1, indent: 16),
      itemBuilder: (ctx, i) {
        final ch = chapters[i];
        return ListTile(
          title: Text(
            ch.title,
            style: const TextStyle(color: Color(0xFFc9d1d9), fontSize: 14),
          ),
          trailing: const Icon(Icons.chevron_right, color: Color(0xFF8b949e)),
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
        );
      },
    );
  }
}
