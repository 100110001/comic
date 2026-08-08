import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../models/chapter.dart';
import '../models/image_item.dart';
import '../platform.dart';
import '../services/api.dart';
import '../widgets/chapter_drawer.dart';
import '../widgets/reader_progress_bar.dart';

class ReaderScreen extends StatefulWidget {
  final int comicId;
  final int chapterId;
  final String title;
  final int? initialPage;
  const ReaderScreen({
    super.key,
    required this.comicId,
    required this.chapterId,
    required this.title,
    this.initialPage,
  });

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  List<Chapter> _chapters = [];
  List<ImageItem> _images = [];
  int _chapterIndex = 0;
  int _currentPage = 0;
  int? _pendingJumpPage;
  bool _loading = true;
  final _scrollController = ScrollController();
  final List<double> _extents = [];

  Chapter? get _currentChapter =>
      _chapters.isEmpty ? null : _chapters[_chapterIndex];
  bool get _hasPrev => _chapterIndex > 0;
  bool get _hasNext => _chapterIndex < _chapters.length - 1;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _init();
  }

  @override
  void dispose() {
    _saveProgress();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    try {
      final r = await ApiService.getComic(widget.comicId);
      if (!mounted) return;
      final idx = r.chapters.indexWhere((c) => c.id == widget.chapterId);
      setState(() {
        _chapters = r.chapters;
        _chapterIndex = idx < 0 ? 0 : idx;
      });
      await _loadChapter(
        _chapters[_chapterIndex].id,
        initialPage: widget.initialPage,
      );
    } catch (_) {
      // 章节列表加载失败时仍直接加载当前章节
      await _loadChapter(widget.chapterId);
    }
  }

  Future<void> _goToChapter(int index, {int? initialPage}) async {
    if (index < 0 || index >= _chapters.length) return;
    setState(() => _chapterIndex = index);
    await _loadChapter(_chapters[index].id, initialPage: initialPage);
  }

  Future<void> _nextChapter() async {
    if (_hasNext) await _goToChapter(_chapterIndex + 1);
  }

  Future<void> _prevChapter() async {
    if (_hasPrev) await _goToChapter(_chapterIndex - 1);
  }

  void _nextPage() {
    if (_images.isEmpty) return;
    if (_currentPage < _images.length - 1) {
      setState(() => _currentPage++);
    } else {
      _autoContinue();
    }
  }

  void _prevPage() {
    if (_images.isEmpty) return;
    if (_currentPage > 0) {
      setState(() => _currentPage--);
    } else {
      _prevChapter();
    }
  }

  /// 自动续章：主体形态在越过本章最后一页时调用。
  Future<void> _autoContinue() async {
    if (_hasNext) await _nextChapter();
  }

  Future<void> _loadChapter(int chapterId, {int? initialPage}) async {
    setState(() {
      _loading = true;
      _images = [];
      _extents.clear();
      _pendingJumpPage = null;
    });
    try {
      final images = await ApiService.getChapterImages(chapterId);
      if (!mounted) return;
      setState(() {
        _images = images;
        _currentPage = initialPage != null && initialPage < images.length
            ? initialPage
            : 0;
        _pendingJumpPage =
            initialPage != null &&
                initialPage > 0 &&
                initialPage < images.length
            ? initialPage
            : null;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  double _estimatedHeight(ImageItem img, double width) {
    final w = img.width;
    final h = img.height;
    if (w != null && h != null && w > 0) return width * h / w;
    return width * 4 / 3; // 未知尺寸时的兜底宽高比
  }

  void _buildExtents(double width) {
    _extents.clear();
    var top = 0.0;
    for (final img in _images) {
      _extents.add(top);
      top += _estimatedHeight(img, width);
    }

    final target = _pendingJumpPage;
    if (target != null && target > 0 && target < _extents.length) {
      _pendingJumpPage = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scrollController.hasClients) return;
        final max = _scrollController.position.maxScrollExtent;
        _scrollController.jumpTo(_extents[target].clamp(0.0, max));
      });
    }
  }

  void _onScroll() {
    if (_extents.isEmpty || !_scrollController.hasClients) return;
    final offset = _scrollController.offset;
    var page = 0;
    for (var i = 1; i < _extents.length; i++) {
      if (_extents[i] <= offset + 1) {
        page = i;
      } else {
        break;
      }
    }
    _currentPage = page;
    // 滚动接近本章底部时自动续章
    if (_hasNext &&
        !_loading &&
        offset >= _scrollController.position.maxScrollExtent - 200) {
      _autoContinue();
    }
  }

  void _saveProgress() {
    if (_images.isEmpty) return;
    ApiService.updateProgress(
      comicId: widget.comicId,
      chapterId: _currentChapter?.id ?? widget.chapterId,
      pageNumber: _currentPage,
    ).catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    if (!_loading && _extents.isEmpty && _images.isNotEmpty) {
      _buildExtents(MediaQuery.of(context).size.width);
    }
    return Scaffold(
      backgroundColor: Colors.black,
      endDrawer: isDesktop && _chapters.isNotEmpty
          ? ChapterDrawer(
              chapters: _chapters,
              currentIndex: _chapterIndex,
              onSelect: (i) {
                Navigator.pop(context);
                _goToChapter(i);
              },
            )
          : null,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          _currentChapter?.title ?? widget.title,
          style: const TextStyle(color: Colors.white, fontSize: 15),
        ),
        actions: [
          if (isDesktop)
            IconButton(
              icon: const Icon(Icons.format_list_bulleted, color: Colors.white),
              tooltip: '目录',
              onPressed: _chapters.isEmpty
                  ? null
                  : () => Scaffold.of(context).openEndDrawer(),
            ),
          IconButton(
            icon: const Icon(Icons.chevron_left, color: Colors.white),
            tooltip: '上一章',
            onPressed: _hasPrev ? _prevChapter : null,
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, color: Colors.white),
            tooltip: '下一章',
            onPressed: _hasNext ? _nextChapter : null,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : isDesktop
          ? _buildPagedBody(context)
          : _buildScrollBody(),
    );
  }

  Widget _buildScrollBody() {
    return ListView.builder(
      controller: _scrollController,
      cacheExtent: 800,
      itemCount: _images.length,
      itemBuilder: (ctx, i) => _LazyImage(url: _images[i].url),
    );
  }

  Widget _buildPagedBody(BuildContext context) {
    if (_images.isEmpty) {
      return const Center(
        child: Text('本章暂无图片', style: TextStyle(color: Colors.grey)),
      );
    }
    final page = _currentPage.clamp(0, _images.length - 1).toInt();
    return Listener(
      onPointerSignal: (event) {
        if (event is PointerScrollEvent) {
          if (event.scrollDelta.dy > 0) {
            _nextPage();
          } else {
            _prevPage();
          }
        }
      },
      child: Column(
        children: [
          Expanded(
            child: Container(
              color: Colors.black,
              alignment: Alignment.center,
              child: Image.network(
                _images[page].url,
                fit: BoxFit.contain,
                loadingBuilder: (_, child, progress) {
                  if (progress == null) return child;
                  return const Center(child: CircularProgressIndicator());
                },
                errorBuilder: (_, _, _) => const Center(
                  child: Icon(Icons.broken_image, color: Colors.grey, size: 48),
                ),
              ),
            ),
          ),
          ReaderProgressBar(
            currentPage: page,
            totalPages: _images.length,
            onSeek: (p) => setState(() => _currentPage = p),
          ),
        ],
      ),
    );
  }
}

class _LazyImage extends StatefulWidget {
  final String url;
  const _LazyImage({required this.url});

  @override
  State<_LazyImage> createState() => _LazyImageState();
}

class _LazyImageState extends State<_LazyImage> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) {
      return const SizedBox(width: double.infinity, height: 600);
    }

    return Image.network(
      widget.url,
      width: double.infinity,
      fit: BoxFit.fitWidth,
      loadingBuilder: (_, child, progress) {
        if (progress == null) return child;
        return SizedBox(
          height: 400,
          child: Center(
            child: CircularProgressIndicator(
              value: progress.expectedTotalBytes != null
                  ? progress.cumulativeBytesLoaded /
                        progress.expectedTotalBytes!
                  : null,
            ),
          ),
        );
      },
      errorBuilder: (context, error, stack) => const SizedBox(
        height: 200,
        child: Center(
          child: Icon(Icons.broken_image, color: Colors.grey, size: 48),
        ),
      ),
    );
  }
}
