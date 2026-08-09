import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/chapter.dart';
import '../models/image_item.dart';
import '../platform.dart';
import '../providers/comics_providers.dart';
import '../providers/reader_providers.dart';
import '../widgets/chapter_drawer.dart';
import '../widgets/reader_progress_bar.dart';

class ReaderScreen extends ConsumerStatefulWidget {
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
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  List<Chapter> _chapters = [];
  List<ImageItem> _images = [];
  int _chapterIndex = 0;
  int _currentPage = 0;
  int? _pendingJumpPage;
  int _jumpAttempts = 0;
  bool _initialJumping = false;
  int _jumpGeneration = 0;
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
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    try {
      final detail = await ref.read(comicDetailProvider(widget.comicId).future);
      if (!mounted) return;
      final idx = detail.chapters.indexWhere((c) => c.id == widget.chapterId);
      setState(() {
        _chapters = detail.chapters;
        _chapterIndex = idx < 0 ? 0 : idx;
      });
      await _loadChapter(
        _chapters[_chapterIndex].id,
        initialPage: widget.initialPage,
      );
    } catch (_) {
      // 章节列表加载失败时仍直接加载当前章节
      await _loadChapter(widget.chapterId, initialPage: widget.initialPage);
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
      _precacheAround(_currentPage);
    } else {
      _autoContinue();
    }
  }

  void _prevPage() {
    if (_images.isEmpty) return;
    if (_currentPage > 0) {
      setState(() => _currentPage--);
      _precacheAround(_currentPage);
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
      _jumpAttempts = 0;
      _initialJumping = false;
      _jumpGeneration++;
    });
    try {
      final images = await ref.read(chapterImagesProvider(chapterId).future);
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
      _precacheAround(_currentPage);
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// 预加载当前页前后各 1–2 张图片，避免翻页/滚动切换时闪屏。
  void _precacheAround(int page) {
    if (_images.isEmpty) return;
    for (var i = page - 1; i <= page + 2; i++) {
      if (i < 0 || i >= _images.length) continue;
      precacheImage(NetworkImage(_images[i].url), context).catchError((_) {});
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
      _initialJumping = true;
      final generation = _jumpGeneration;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _performInitialJump(target, generation);
      });
    }
  }

  /// 目标页在图片真实加载完成前可能超出 maxScrollExtent，
  /// 多帧重试直到目标可到达或达到尝试上限。
  void _performInitialJump(int target, int generation) {
    if (generation != _jumpGeneration || target >= _extents.length) {
      _initialJumping = false;
      return;
    }
    if (!mounted || !_scrollController.hasClients) {
      _initialJumping = false;
      return;
    }
    final max = _scrollController.position.maxScrollExtent;
    _scrollController.jumpTo(_extents[target].clamp(0.0, max));
    if (max >= _extents[target]) {
      _initialJumping = false;
      return;
    }
    if (_jumpAttempts < 120) {
      _jumpAttempts++;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _performInitialJump(target, generation),
      );
    } else {
      _initialJumping = false;
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
    if (page != _currentPage) {
      setState(() => _currentPage = page);
      _precacheAround(page);
    }
    // 滚动接近本章底部时自动续章
    if (_hasNext &&
        !_initialJumping &&
        !_loading &&
        offset >= _scrollController.position.maxScrollExtent - 200) {
      _autoContinue();
    }
  }

  void _jumpToPage(int page) {
    if (!_scrollController.hasClients || _extents.isEmpty) return;
    if (page < 0 || page >= _extents.length) return;
    final max = _scrollController.position.maxScrollExtent;
    _scrollController.jumpTo(_extents[page].clamp(0.0, max));
    _precacheAround(page);
  }

  void _openMobileDirectory() {
    if (_chapters.isEmpty) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161b22),
      builder: (ctx) => SafeArea(
        child: ListView.builder(
          itemCount: _chapters.length,
          itemBuilder: (ctx, i) {
            final selected = i == _chapterIndex;
            return ListTile(
              selected: selected,
              title: Text(
                _chapters[i].title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? const Color(0xFF58a6ff) : Colors.white,
                  fontSize: 13,
                ),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _goToChapter(i);
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _ensureChapters() async {
    if (_chapters.isNotEmpty) return;
    try {
      final detail = await ref.read(comicDetailProvider(widget.comicId).future);
      if (!mounted || _chapters.isNotEmpty) return;
      final targetId = _currentChapter?.id ?? widget.chapterId;
      final idx = detail.chapters.indexWhere((c) => c.id == targetId);
      setState(() {
        _chapters = detail.chapters;
        _chapterIndex = idx < 0 ? 0 : idx;
      });
    } catch (_) {
      // 章节列表仍不可用
    }
  }

  Future<void> _openDirectory(BuildContext buttonContext) async {
    final desktop = isDesktopAt(MediaQuery.of(buttonContext).size.width);
    if (_chapters.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('正在加载章节…')));
      await _ensureChapters();
      if (!mounted) return;
      if (_chapters.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('暂无章节信息')));
        return;
      }
    }
    if (desktop) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Scaffold.of(buttonContext).openEndDrawer();
      });
    } else {
      _openMobileDirectory();
    }
  }

  void _saveProgress() {
    if (_images.isEmpty) return;
    updateReadingProgress(
      ref,
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
    final desktop = isDesktopAt(MediaQuery.of(context).size.width);
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _saveProgress();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        endDrawer: desktop
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
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 15),
          ),
          actions: [
            Builder(
              builder: (buttonContext) => IconButton(
                icon: const Icon(
                  Icons.format_list_bulleted,
                  color: Colors.white,
                ),
                tooltip: '目录',
                onPressed: () => _openDirectory(buttonContext),
              ),
            ),
            IconButton(
              icon: Icon(
                Icons.chevron_left,
                color: _hasPrev ? Colors.white : const Color(0xFF484f58),
              ),
              tooltip: '上一章',
              onPressed: _hasPrev ? _prevChapter : null,
            ),
            IconButton(
              icon: Icon(
                Icons.chevron_right,
                color: _hasNext ? Colors.white : const Color(0xFF484f58),
              ),
              tooltip: '下一章',
              onPressed: _hasNext ? _nextChapter : null,
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : desktop
            ? _buildPagedBody(context)
            : _buildMobileBody(),
      ),
    );
  }

  Widget _buildMobileBody() {
    return Stack(
      children: [
        _buildScrollBody(),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SafeArea(
            top: false,
            child: ReaderProgressBar(
              currentPage: _currentPage,
              totalPages: _images.length,
              onSeek: _jumpToPage,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildScrollBody() {
    final width = MediaQuery.of(context).size.width;
    return ListView.builder(
      controller: _scrollController,
      cacheExtent: 800,
      itemCount: _images.length,
      itemBuilder: (ctx, i) => _LazyImage(
        url: _images[i].url,
        height: _estimatedHeight(_images[i], width),
      ),
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
            onSeek: (p) {
              setState(() => _currentPage = p);
              _precacheAround(p);
            },
          ),
        ],
      ),
    );
  }
}

class _LazyImage extends StatefulWidget {
  final String url;
  final double height;
  const _LazyImage({required this.url, required this.height});

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
    // 固定高度渲染：高度 = 视口宽 × 图片高/宽，与预估滚动偏移一致，
    // 图片加载不改变布局，跳转可精确到页。
    return SizedBox(
      width: double.infinity,
      height: widget.height,
      child: ClipRect(
        child: !_visible
            ? _loadingBox()
            : Image.network(
                widget.url,
                width: double.infinity,
                height: widget.height,
                fit: BoxFit.fitWidth,
                loadingBuilder: (_, child, progress) {
                  if (progress == null) return child;
                  return _loadingBox(progress: progress);
                },
                errorBuilder: (_, _, _) => _errorBox(),
              ),
      ),
    );
  }

  Widget _loadingBox({ImageChunkEvent? progress}) => ColoredBox(
    color: const Color(0xFF161b22),
    child: Center(
      child: progress != null && progress.expectedTotalBytes != null
          ? CircularProgressIndicator(
              value:
                  progress.cumulativeBytesLoaded / progress.expectedTotalBytes!,
            )
          : const CircularProgressIndicator(),
    ),
  );

  Widget _errorBox() => ColoredBox(
    color: const Color(0xFF161b22),
    child: const Center(
      child: Icon(Icons.broken_image, color: Colors.grey, size: 48),
    ),
  );
}
