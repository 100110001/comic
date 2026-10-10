import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/chapter.dart';
import '../models/comic.dart';
import '../models/image_item.dart';
import '../models/reading_progress_entry.dart';
import '../providers/reading_progress_provider.dart';
import '../providers/server_provider.dart';
import '../services/api_client.dart';
import '../platform.dart';
import '../providers/comics_providers.dart';
import '../providers/reader_providers.dart';
import '../providers/super_resolution_provider.dart';
import '../widgets/enhanced_image.dart';
import '../theme.dart';
import '../utils/user_error.dart';
import '../utils/display_image_provider.dart';
import '../widgets/chapter_drawer.dart';
import '../widgets/reader_progress_bar.dart';
import '../widgets/status_views.dart';

class ReaderScreen extends ConsumerStatefulWidget {
  final int comicId;
  final int chapterId;
  final String title;
  final int? initialPage;
  final Future<Comic?> Function()? onNextComic;
  final Future<Comic?> Function()? onPrevComic;
  final bool Function()? canPrevComic;
  const ReaderScreen({
    super.key,
    required this.comicId,
    required this.chapterId,
    required this.title,
    this.initialPage,
    this.onNextComic,
    this.onPrevComic,
    this.canPrevComic,
  });

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen>
    with WidgetsBindingObserver {
  late ReadingProgressQueue _progressQueue;
  late ApiClient _progressClient;
  late Future<void> Function() _checkpointCallback;
  Comic? _comic;
  bool _saveErrorVisible = false;
  late int _comicId;
  late int _chapterId;
  List<Chapter> _chapters = [];
  List<ImageItem> _images = [];
  int _chapterIndex = 0;
  int _currentPage = 0;
  int? _pendingJumpPage;
  int _jumpAttempts = 0;
  bool _initialJumping = false;
  int _jumpGeneration = 0;
  bool _loading = true;
  bool _loadFailed = false;
  Object? _loadError;
  int _imageRetryTick = 0;
  String _title = '';
  bool _switchingComic = false;
  final _scrollController = ScrollController();
  final List<double> _extents = [];
  double? _extentWidth;
  Size? _imageViewport;
  double _imagePixelRatio = 1;
  bool _desktopImages = false;
  ImageProvider<Object>? _imageLayoutSignature;
  Object? _superResolutionLayoutSignature;
  int _imageLayoutGeneration = 0;
  Timer? _hideTimer;
  bool _chromeVisible = true;
  bool _pointerOverChrome = false;

  Chapter? get _currentChapter =>
      _chapters.isEmpty ? null : _chapters[_chapterIndex];
  bool get _hasPrev => _chapterIndex > 0;
  bool get _hasNext => _chapterIndex < _chapters.length - 1;
  bool get _canPrevComic => widget.canPrevComic?.call() ?? false;

  @override
  void initState() {
    super.initState();
    _progressQueue = ref.read(readingProgressQueueProvider.notifier);
    _progressClient = ref.read(apiClientProvider);
    _checkpointCallback = _checkpoint;
    _progressQueue.checkpointActiveReader = _checkpointCallback;
    WidgetsBinding.instance.addObserver(this);
    _comicId = widget.comicId;
    _chapterId = widget.chapterId;
    _title = widget.title;
    _scrollController.addListener(_onScroll);
    _hideTimer = Timer(const Duration(seconds: 3), _maybeHideChrome);
    _init();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (identical(_progressQueue.checkpointActiveReader, _checkpointCallback)) {
      _progressQueue.checkpointActiveReader = null;
    }
    _hideTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      unawaited(_saveProgress());
    }
  }

  /// 桌面沉浸：点击阅读区或按键等有意交互恢复工具栏并重置隐藏计时；
  /// 滚轮翻页视为阅读动作，不触发。
  void _onActivity() {
    if (!mounted) return;
    if (!_chromeVisible) setState(() => _chromeVisible = true);
    _restartHideTimer();
  }

  void _restartHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), _maybeHideChrome);
  }

  /// 无操作超时后隐藏工具栏；指针停留在工具栏区域时推迟隐藏。
  void _maybeHideChrome() {
    if (!mounted) return;
    if (_pointerOverChrome) {
      _restartHideTimer();
      return;
    }
    final desktop = isDesktopAt(MediaQuery.of(context).size.width);
    if (desktop && _chromeVisible) {
      setState(() => _chromeVisible = false);
    }
  }

  Future<void> _init() async {
    try {
      final detail = await ref.read(comicDetailProvider(_comicId).future);
      if (!mounted) return;
      final idx = detail.chapters.indexWhere((c) => c.id == widget.chapterId);
      setState(() {
        _comic = detail.comic;
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
    _recordPosition();
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
      _goToPage(_currentPage + 1);
    } else {
      _autoContinue();
    }
  }

  void _prevPage() {
    if (_images.isEmpty) return;
    if (_currentPage > 0) {
      _goToPage(_currentPage - 1);
    } else {
      _prevChapter();
    }
  }

  /// 桌面形态章内直达指定页（页码越界时收敛到首/末页）。
  void _goToPage(int page) {
    if (_images.isEmpty) return;
    final target = page.clamp(0, _images.length - 1).toInt();
    setState(() => _currentPage = target);
    _precacheAround(target);
    _recordPosition();
  }

  /// 桌面形态的键盘翻页与换章绑定；边界行为复用对应操作。
  Map<ShortcutActivator, VoidCallback> _desktopShortcutBindings() {
    return {
      const SingleActivator(LogicalKeyboardKey.arrowLeft): _prevPage,
      const SingleActivator(LogicalKeyboardKey.arrowRight): _nextPage,
      const SingleActivator(LogicalKeyboardKey.pageUp): _prevChapter,
      const SingleActivator(LogicalKeyboardKey.pageDown): _nextChapter,
      const SingleActivator(LogicalKeyboardKey.space): _nextPage,
      const SingleActivator(LogicalKeyboardKey.home): () => _goToPage(0),
      const SingleActivator(LogicalKeyboardKey.end): () =>
          _goToPage(_images.length - 1),
    };
  }

  /// 自动续章：主体形态在越过本章最后一页时调用。
  Future<void> _autoContinue() async {
    if (_hasNext) {
      await _nextChapter();
    } else if (widget.onNextComic != null) {
      await _nextComic();
    }
  }

  /// 发现模式：切到序列里的下一本漫画（从第 1 章开始）。
  Future<void> _nextComic() async {
    final next = widget.onNextComic;
    if (next == null || _switchingComic) return;
    setState(() => _switchingComic = true);
    await _saveProgress();
    final comic = await next();
    if (!mounted) return;
    if (comic == null) {
      setState(() => _switchingComic = false);
      return;
    }
    await _loadComic(comic);
  }

  /// 发现模式：切到序列里的上一本漫画（从第 1 章开始）。
  Future<void> _prevComic() async {
    final prev = widget.onPrevComic;
    if (prev == null || _switchingComic || !_canPrevComic) return;
    setState(() => _switchingComic = true);
    await _saveProgress();
    final comic = await prev();
    if (!mounted) return;
    if (comic == null) {
      setState(() => _switchingComic = false);
      return;
    }
    await _loadComic(comic);
  }

  /// 整体替换为另一本漫画：章节列表 + 定位到第 1 章。
  Future<void> _loadComic(Comic comic) async {
    ComicDetail? detail;
    try {
      detail = await ref.read(comicDetailProvider(comic.id).future);
    } catch (_) {
      detail = null;
    }
    if (!mounted) return;
    if (detail == null || detail.chapters.isEmpty) {
      setState(() => _switchingComic = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('暂无章节')));
      return;
    }
    setState(() {
      _comic = detail!.comic;
      _comicId = comic.id;
      _title = comic.title;
      _chapters = detail.chapters;
      _chapterIndex = 0;
    });
    await _loadChapter(_chapters[0].id);
    if (mounted) setState(() => _switchingComic = false);
  }

  Future<void> _loadChapter(int chapterId, {int? initialPage}) async {
    ref.read(superResolutionProvider.notifier).resetChapter();
    setState(() {
      _chapterId = chapterId;
      _loading = true;
      _loadFailed = false;
      _loadError = null;
      _images = [];
      _extents.clear();
      _extentWidth = null;
      _imageViewport = null;
      _imageLayoutSignature = null;
      _imageLayoutGeneration++;
      _pendingJumpPage = null;
      _jumpAttempts = 0;
      _initialJumping = false;
      _jumpGeneration++;
    });
    final generation = _jumpGeneration;
    try {
      final images = await ref.read(chapterImagesProvider(chapterId).future);
      if (!mounted || generation != _jumpGeneration) return;
      setState(() {
        _images = images;
        _currentPage =
            initialPage != null &&
                initialPage >= 0 &&
                initialPage < images.length
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
      _recordPosition();
    } catch (error) {
      if (mounted && generation == _jumpGeneration) {
        setState(() {
          _loading = false;
          _loadFailed = true;
          _loadError = error;
        });
      }
    }
  }

  /// 章节级重试：重新拉取当前章节的图片列表。
  Future<void> _reloadChapter() async {
    final chapterId = _chapterId;
    await _loadChapter(chapterId);
  }

  ImageProvider<Object> _imageProvider(ImageItem item) => displayImageProvider(
    item.url,
    logicalSize: _imageViewport!,
    devicePixelRatio: _imagePixelRatio,
    fit: _desktopImages ? BoxFit.contain : BoxFit.fitWidth,
  );

  void _updateImageLayout(Size size, {required bool desktop}) {
    final ratio = MediaQuery.devicePixelRatioOf(context);
    _imageViewport = size;
    _imagePixelRatio = ratio;
    _desktopImages = desktop;
    final signature = _imageProvider(_images.first);
    final srLayout = (size, ratio, desktop);
    if (signature == _imageLayoutSignature &&
        srLayout == _superResolutionLayoutSignature) {
      return;
    }
    _imageLayoutSignature = signature;
    _superResolutionLayoutSignature = srLayout;
    final layoutGeneration = ++_imageLayoutGeneration;
    final chapterGeneration = _jumpGeneration;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          _loading ||
          layoutGeneration != _imageLayoutGeneration ||
          chapterGeneration != _jumpGeneration) {
        return;
      }
      _precacheAround(_currentPage);
    });
  }

  /// 显示与相邻页预加载使用同一尺寸缓存，布局确定前不预加载原图。
  void _precacheAround(int page) {
    if (_images.isEmpty) return;
    ref
        .read(superResolutionProvider.notifier)
        .setWindow(
          _images.skip(page).take(superResolutionWindowSize).toList(),
          targetWidths: _superResolutionTargets(page),
        );
    if (_imageViewport == null) return;
    for (var i = page - 1; i <= page + 2; i++) {
      if (i < 0 || i >= _images.length) continue;
      unawaited(
        precacheImage(
          _imageProvider(_images[i]),
          context,
          onError: (error, stack) {},
        ),
      );
    }
  }

  Map<String, int> _superResolutionTargets(int page) {
    final viewport = _imageViewport;
    if (viewport == null) return {};
    return {
      for (final image in _images.skip(page).take(superResolutionWindowSize))
        image.url:
            ((_desktopImages &&
                            image.width != null &&
                            image.height != null &&
                            image.height! > 0
                        ? math.min(
                            viewport.width,
                            viewport.height * image.width! / image.height!,
                          )
                        : viewport.width) *
                    _imagePixelRatio)
                .ceil(),
    };
  }

  ImageProvider<Object>? _enhancedProvider(ImageItem image) {
    final sr = ref.read(superResolutionProvider);
    final url = sr.enabled && !sr.reasons.containsKey(image.url)
        ? sr.results[image.url]?.url
        : null;
    if (url == null || _imageViewport == null) return null;
    return displayImageProvider(
      url,
      logicalSize: _imageViewport!,
      devicePixelRatio: _imagePixelRatio,
      fit: _desktopImages ? BoxFit.contain : BoxFit.fitWidth,
    );
  }

  VoidCallback _enhancedFailure(ImageItem image) {
    final controller = ref.read(superResolutionProvider.notifier);
    final generation = controller.generation;
    final expected = ref.read(superResolutionProvider).results[image.url];
    return () => controller.imageFailed(
      image.url,
      generation: generation,
      expected: expected,
    );
  }

  void _toggleSuperResolution() {
    final enabled = ref.read(superResolutionProvider).enabled;
    ref.read(superResolutionProvider.notifier).setEnabled(!enabled);
    _precacheAround(_currentPage);
    _onActivity();
  }

  Future<void> _superResolutionAction(String action) async {
    final controller = ref.read(superResolutionProvider.notifier);
    if (action == 'toggle') {
      _toggleSuperResolution();
      return;
    }
    if (action == 'sync') {
      await _saveProgress();
      return;
    }
    if (action == 'retry') {
      if (_images.isEmpty) return;
      for (final image
          in _images.skip(_currentPage).take(superResolutionWindowSize)) {
        await _enhancedProvider(image)?.evict();
      }
      if (!mounted) return;
      controller.setWindow(
        _images.skip(_currentPage).take(superResolutionWindowSize).toList(),
        retry: true,
        targetWidths: _superResolutionTargets(_currentPage),
      );
    } else {
      try {
        await controller.clearCache();
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('超分缓存已清空，已切回原图')));
        }
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(userMessageFor(error, fallback: '缓存清理失败'))),
          );
        }
      }
    }
  }

  double _estimatedHeight(ImageItem img, double width) {
    final w = img.width;
    final h = img.height;
    if (w != null && h != null && w > 0) return width * h / w;
    return width * 4 / 3; // 未知尺寸时的兜底宽高比
  }

  void _buildExtents(double width) {
    _extentWidth = width;
    _extents.clear();
    var top = 0.0;
    for (final img in _images) {
      _extents.add(top);
      top += _estimatedHeight(img, width);
    }

    final target = _pendingJumpPage;
    if (target != null && target >= 0 && target < _extents.length) {
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
    if (generation != _jumpGeneration) return;
    if (target >= _extents.length) {
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
    if (_initialJumping || _extents.isEmpty || !_scrollController.hasClients) {
      return;
    }
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
      _recordPosition();
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
    final c = context.appColors;
    showModalBottomSheet(
      context: context,
      backgroundColor: c.surface1,
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
                  color: selected ? c.accent : c.text1,
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
      final detail = await ref.read(comicDetailProvider(_comicId).future);
      if (!mounted || _chapters.isNotEmpty) return;
      final targetId = _chapterId;
      final idx = detail.chapters.indexWhere((c) => c.id == targetId);
      setState(() {
        _comic = detail.comic;
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

  Future<void> _checkpoint() async {
    if (_images.isEmpty || _loading || _loadFailed) return;
    final metadata = _comic;
    final entry = ReadingProgressEntry(
      comic: Comic(
        id: _comicId,
        title: metadata?.title ?? _title,
        author: metadata?.author,
        coverPath: metadata?.coverPath,
        chapterCount: metadata?.chapterCount ?? 0,
        imageCount: metadata?.imageCount ?? _images.length,
        serverUrl: _progressClient.baseUrl,
      ),
      chapterId: _chapterId,
      chapterTitle: _currentChapter?.title ?? _title,
      pageNumber: _currentPage,
    );
    try {
      await _progressQueue.record(entry);
    } catch (_) {
      if (mounted && !_saveErrorVisible) {
        _saveErrorVisible = true;
        ScaffoldMessenger.of(context)
            .showSnackBar(
              SnackBar(
                content: const Text('阅读进度无法保存在本机，请重试'),
                action: SnackBarAction(label: '重试', onPressed: _recordPosition),
              ),
            )
            .closed
            .then((_) => _saveErrorVisible = false);
      }
      rethrow;
    }
  }

  void _recordPosition() {
    unawaited(_checkpoint().catchError((_) {}));
  }

  Future<void> _saveProgress() async {
    try {
      await _checkpoint();
      unawaited(_progressQueue.sync(_progressClient).catchError((_) {}));
    } catch (_) {
      // 本地写入失败已反馈，后续有效位置变化或手动重试再次保存。
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final desktop = isDesktopAt(width);
    if (!desktop &&
        !_loading &&
        _images.isNotEmpty &&
        (_extentWidth != width || _desktopImages)) {
      if (_extentWidth != null || _desktopImages) {
        _pendingJumpPage = _currentPage;
        _jumpGeneration++;
        _jumpAttempts = 0;
      }
      _buildExtents(width);
    }
    final sr = ref.watch(superResolutionProvider);
    final srJob = _images.isEmpty
        ? null
        : sr.results[_images[_currentPage].url];
    final srReason = _images.isEmpty
        ? null
        : sr.reasons[_images[_currentPage].url];
    final srHint = !sr.enabled
        ? '开启超分 2×'
        : srReason != null
        ? '$srReason，打开菜单可关闭'
        : srJob?.status == 'failed'
        ? (srJob?.error ?? '超分失败，继续使用原图')
        : srJob?.status == 'ready'
        ? '超分 2× 已就绪，打开菜单可关闭'
        : '超分 2× 处理中，打开菜单可关闭';
    final srStatus = !sr.enabled
        ? '超分关闭 · 原图'
        : srReason != null
        ? '自适应 · $srReason'
        : srJob?.status == 'failed'
        ? '超分失败 · 已回退原图'
        : srJob?.status == 'ready'
        ? '超分 2× 已就绪'
        : srJob?.status == 'queued'
        ? '超分已开启 · 排队中'
        : '超分已开启 · 处理中';
    final pending = ref.watch(localReadingProgressProvider(_comicId));
    final c = context.appColors;
    final Widget scaffold = Scaffold(
      backgroundColor: c.readerBg,
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
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: MouseRegion(
          onEnter: (_) {
            setState(() => _pointerOverChrome = true);
            _restartHideTimer();
          },
          onExit: (_) {
            setState(() => _pointerOverChrome = false);
            _restartHideTimer();
          },
          child: AnimatedOpacity(
            opacity: _chromeVisible ? 1 : 0,
            duration: const Duration(milliseconds: 200),
            child: IgnorePointer(
              ignoring: !_chromeVisible,
              child: AppBar(
                backgroundColor: c.readerBar,
                iconTheme: IconThemeData(color: c.text1),
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _currentChapter?.title ?? _title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: c.text1,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      srStatus,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: sr.enabled
                            ? Theme.of(context).colorScheme.primary
                            : c.text2,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                bottom: PreferredSize(
                  preferredSize: Size.fromHeight(1),
                  child: SizedBox(
                    height: 1,
                    child: ColoredBox(color: c.borderStrong),
                  ),
                ),
                actions: [
                  PopupMenuButton<String>(
                    tooltip: srHint,
                    style: IconButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: Icon(
                      Icons.auto_awesome,
                      color: sr.enabled
                          ? Theme.of(context).colorScheme.primary
                          : c.text1,
                    ),
                    onSelected: _superResolutionAction,
                    itemBuilder: (_) => [
                      if (sr.enabled)
                        PopupMenuItem(
                          enabled: false,
                          child: Text(
                            srReason ??
                                (srJob?.status == 'failed'
                                    ? (srJob?.error ?? '超分失败，继续使用原图')
                                    : srJob?.status == 'ready'
                                    ? '超分 2× 已就绪'
                                    : '超分 2× 处理中'),
                          ),
                        ),
                      if (sr.enabled)
                        PopupMenuItem(
                          enabled: false,
                          child: Text('预处理：后 ${sr.lookahead} 页'),
                        ),
                      PopupMenuItem(
                        value: 'toggle',
                        enabled: _images.isNotEmpty,
                        child: Text(sr.enabled ? '关闭超分 2×' : '开启超分 2×'),
                      ),
                      PopupMenuItem(
                        value: 'retry',
                        enabled: sr.enabled,
                        child: const Text('重试超分'),
                      ),
                      const PopupMenuItem(
                        value: 'clear',
                        child: Text('清空超分缓存'),
                      ),
                      if (pending != null && width < 500)
                        const PopupMenuItem(
                          value: 'sync',
                          child: Text('进度已存本机，点击同步'),
                        ),
                    ],
                  ),
                  if (pending != null && width >= 500)
                    IconButton(
                      icon: Icon(Icons.cloud_upload_outlined, color: c.text1),
                      tooltip: '进度已存本机，点击同步',
                      onPressed: _saveProgress,
                    ),
                  Builder(
                    builder: (buttonContext) => IconButton(
                      icon: Icon(Icons.format_list_bulleted, color: c.text1),
                      tooltip: '目录',
                      onPressed: () => _openDirectory(buttonContext),
                    ),
                  ),
                  if (widget.onPrevComic != null)
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: Icon(
                        Icons.skip_previous,
                        color: _canPrevComic && !_switchingComic
                            ? c.text1
                            : c.text2.withValues(alpha: 0.45),
                      ),
                      tooltip: '上一本',
                      onPressed: _canPrevComic && !_switchingComic
                          ? _prevComic
                          : null,
                    ),
                  if (widget.onNextComic != null)
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: Icon(
                        Icons.skip_next,
                        color: _switchingComic
                            ? c.text2.withValues(alpha: 0.45)
                            : c.text1,
                      ),
                      tooltip: '下一本',
                      onPressed: _switchingComic ? null : _nextComic,
                    ),
                  IconButton(
                    icon: Icon(
                      Icons.chevron_left,
                      color: _hasPrev
                          ? c.text1
                          : c.text2.withValues(alpha: 0.45),
                    ),
                    tooltip: '上一章',
                    onPressed: _hasPrev ? _prevChapter : null,
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.chevron_right,
                      color: _hasNext
                          ? c.text1
                          : c.text2.withValues(alpha: 0.45),
                    ),
                    tooltip: '下一章',
                    onPressed: _hasNext ? _nextChapter : null,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: _buildChapterBody(desktop),
    );
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _saveProgress();
      },
      child: desktop
          ? GestureDetector(
              onTap: _onActivity,
              child: CallbackShortcuts(
                bindings: _desktopShortcutBindings(),
                child: Focus(
                  autofocus: true,
                  onKeyEvent: (node, event) {
                    _onActivity();
                    return KeyEventResult.ignored;
                  },
                  child: scaffold,
                ),
              ),
            )
          : scaffold,
    );
  }

  /// 章节主体的统一状态分支：加载中 / 加载失败 / 空章 / 正常阅读。
  Widget _buildChapterBody(bool desktop) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_loadFailed) return _buildLoadError();
    if (_images.isEmpty) return _buildEmptyChapter();
    return desktop ? _buildPagedBody(context) : _buildMobileBody();
  }

  Widget _buildLoadError() {
    return StatusView(
      icon: Icons.cloud_off,
      message: userMessageFor(_loadError, fallback: '章节加载失败'),
      actionLabel: '重试',
      onAction: _reloadChapter,
    );
  }

  Widget _buildEmptyChapter() {
    return StatusView(
      icon: Icons.photo_outlined,
      message: '本章暂无图片',
      actionLabel: '重试',
      onAction: _reloadChapter,
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        _updateImageLayout(Size(width, constraints.maxHeight), desktop: false);
        return ListView.builder(
          controller: _scrollController,
          // ignore: deprecated_member_use
          cacheExtent: 800,
          itemCount: _images.length,
          itemBuilder: (ctx, i) {
            final image = _images[i];
            return _LazyImage(
              key: ValueKey(_images[i].url),
              provider: _imageProvider(_images[i]),
              enhanced: _enhancedProvider(_images[i]),
              onEnhancedError: _enhancedFailure(image),
              height: _estimatedHeight(_images[i], width),
            );
          },
        );
      },
    );
  }

  Widget _buildPagedBody(BuildContext context) {
    final page = _currentPage.clamp(0, _images.length - 1).toInt();
    final image = _images[page];
    final c = context.appColors;
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
            child: LayoutBuilder(
              builder: (context, constraints) {
                _updateImageLayout(constraints.biggest, desktop: true);
                return Container(
                  color: c.readerBg,
                  alignment: Alignment.center,
                  child: EnhancedImage(
                    enhanced: _enhancedProvider(_images[page]),
                    fit: BoxFit.contain,
                    onError: _enhancedFailure(image),
                    original: Image(
                      image: _imageProvider(_images[page]),
                      key: ValueKey('page-img-$page-$_imageRetryTick'),
                      fit: BoxFit.contain,
                      loadingBuilder: (_, child, progress) {
                        if (progress == null) return child;
                        return const Center(child: CircularProgressIndicator());
                      },
                      errorBuilder: (_, _, _) => GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _retryCurrentImage,
                        child: const _ImageRetryBox(),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          AnimatedOpacity(
            opacity: _chromeVisible ? 1 : 0,
            duration: const Duration(milliseconds: 200),
            child: IgnorePointer(
              ignoring: !_chromeVisible,
              child: ReaderProgressBar(
                currentPage: page,
                totalPages: _images.length,
                onSeek: (p) {
                  _goToPage(p);
                  _onActivity();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 单图重试：清理该 URL 缓存后强制重建当前页图片。
  Future<void> _retryCurrentImage() async {
    if (_images.isEmpty || _imageViewport == null) return;
    final url = _images[_currentPage].url;
    final generation = _jumpGeneration;
    await _imageProvider(_images[_currentPage]).evict();
    if (!mounted ||
        generation != _jumpGeneration ||
        _images.isEmpty ||
        _images[_currentPage].url != url) {
      return;
    }
    setState(() => _imageRetryTick++);
  }
}

class _LazyImage extends StatefulWidget {
  final ImageProvider<Object> provider;
  final double height;
  final ImageProvider<Object>? enhanced;
  final VoidCallback onEnhancedError;
  const _LazyImage({
    super.key,
    required this.provider,
    required this.height,
    this.enhanced,
    required this.onEnhancedError,
  });

  @override
  State<_LazyImage> createState() => _LazyImageState();
}

class _LazyImageState extends State<_LazyImage> {
  bool _visible = false;
  int _retryTick = 0;

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
            : EnhancedImage(
                enhanced: widget.enhanced,
                fit: BoxFit.fitWidth,
                onError: widget.onEnhancedError,
                original: Image(
                  image: widget.provider,
                  key: ValueKey(_retryTick),
                  width: double.infinity,
                  height: widget.height,
                  fit: BoxFit.fitWidth,
                  loadingBuilder: (_, child, progress) {
                    if (progress == null) return child;
                    return _loadingBox(progress: progress);
                  },
                  errorBuilder: (_, _, _) => GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _retry,
                    child: const _ImageRetryBox(),
                  ),
                ),
              ),
      ),
    );
  }

  Future<void> _retry() async {
    final provider = widget.provider;
    await provider.evict();
    if (!mounted || widget.provider != provider) return;
    setState(() => _retryTick++);
  }

  Widget _loadingBox({ImageChunkEvent? progress}) => ColoredBox(
    color: context.appColors.readerBar,
    child: Center(
      child: progress != null && progress.expectedTotalBytes != null
          ? CircularProgressIndicator(
              value:
                  progress.cumulativeBytesLoaded / progress.expectedTotalBytes!,
            )
          : const CircularProgressIndicator(),
    ),
  );
}

/// 单图失败占位：显示可点击的"重试"提示。
class _ImageRetryBox extends StatelessWidget {
  const _ImageRetryBox();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.appColors.readerBar,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.broken_image, color: context.appColors.text2, size: 48),
            const SizedBox(height: 6),
            Text(
              '点击重试',
              style: TextStyle(color: context.appColors.text2, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
