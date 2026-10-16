import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../widgets/loading_placeholders.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/chapter.dart';
import '../models/comic.dart';
import '../models/image_item.dart';
import '../models/reading_progress_entry.dart';
import '../providers/reading_progress_provider.dart';
import '../providers/server_provider.dart';
import '../services/api_client.dart';
import '../services/library_reading_session.dart';
import '../platform.dart';
import '../providers/comics_providers.dart';
import '../providers/reader_providers.dart';
import '../providers/settings_provider.dart';
import '../widgets/reader_settings_controls.dart';
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
  final LibraryReadingSession? readingSession;
  final Future<Comic?> Function()? onNextComic;
  final Future<Comic?> Function()? onPrevComic;
  final bool Function()? canPrevComic;
  const ReaderScreen({
    super.key,
    required this.comicId,
    required this.chapterId,
    required this.title,
    this.initialPage,
    this.readingSession,
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
  int _spreadCount = 1;
  String? _panel;
  bool _fullscreen = false;
  bool _exiting = false;
  Timer? _autoTimer;
  bool _autoReading = false;
  double _scrollSpeed = 50;
  int _pageSeconds = 5;
  int _autoTicks = 0;
  final List<({int chapter, ImageItem image})> _flow = [];
  final Map<int, List<ImageItem>> _flowChapters = {};
  int _flowLastChapter = 0;
  int _flowGeneration = 0;
  bool _flowLoading = false;
  Object? _flowError;
  bool get _mobile => !isDesktopAt(MediaQuery.sizeOf(context).width);
  List<ImageItem> get _scrollImages => _mobile && _flow.isNotEmpty
      ? _flow.map((entry) => entry.image).toList()
      : _images;
  int _flowPage(int page) => _mobile && _flow.isNotEmpty
      ? _flow.indexWhere((entry) => entry.chapter == _chapterIndex) + page
      : page;
  bool _scrollReading = false;
  ImageProvider<Object>? _imageLayoutSignature;
  Object? _superResolutionLayoutSignature;
  int _imageLayoutGeneration = 0;
  bool _chromeVisible = false;

  ReaderPreferences get _preferences => ref.read(readerPreferencesProvider);
  bool get _rightToLeft =>
      _preferences.direction == ReadingDirection.rightToLeft;
  BoxFit get _pageFit => !_desktopImages
      ? BoxFit.fitWidth
      : switch (_preferences.fit) {
          ReaderFit.contain => BoxFit.contain,
          ReaderFit.fitWidth => BoxFit.fitWidth,
          ReaderFit.original => BoxFit.none,
        };
  Color get _readerBackground => switch (_preferences.background) {
    ReaderBackground.theme => context.appColors.readerBg,
    ReaderBackground.dark => Colors.black,
    ReaderBackground.gray => const Color(0xff35383d),
    ReaderBackground.paper => const Color(0xffeee8da),
  };

  Chapter? get _currentChapter =>
      _chapters.isEmpty ? null : _chapters[_chapterIndex];
  bool get _hasPrev => _chapterIndex > 0;
  bool get _hasNext => _chapterIndex < _chapters.length - 1;
  bool get _hasComicSequence =>
      widget.readingSession != null || widget.onNextComic != null;
  bool get _canNextComic =>
      widget.readingSession?.canNext(_comicId) ?? (widget.onNextComic != null);
  bool get _canPrevComic =>
      widget.readingSession?.canPrev(_comicId) ??
      widget.canPrevComic?.call() ??
      false;

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
    HardwareKeyboard.instance.addHandler(_handleEscape);
    _init();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (identical(_progressQueue.checkpointActiveReader, _checkpointCallback)) {
      _progressQueue.checkpointActiveReader = null;
    }
    HardwareKeyboard.instance.removeHandler(_handleEscape);
    _autoTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _stopAutoReading();
      unawaited(_saveProgress());
    }
  }

  bool _handleEscape(KeyEvent event) {
    if (ModalRoute.of(context)?.isCurrent == true &&
        !isMobilePlatform &&
        event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape) {
      _exitReader();
      return true;
    }
    return false;
  }

  Future<void> _exitReader() async {
    if (_exiting) return;
    _exiting = true;
    _stopAutoReading();
    try {
      await _checkpoint();
    } catch (_) {
      _exiting = false;
      return;
    }
    unawaited(_progressQueue.sync(_progressClient).catchError((_) {}));
    if (!mounted) return;
    setState(() => _panel = null);
    if (_fullscreen && isWindowsPlatform) {
      await windowManager.setFullScreen(false);
    }
    if (mounted) {
      await WidgetsBinding.instance.endOfFrame;
      if (mounted) Navigator.of(context).pop();
    }
  }

  void _setPanel(String? panel) {
    _stopAutoReading();
    setState(() {
      _panel = panel;
    });
  }

  void _stopAutoReading() {
    _autoTimer?.cancel();
    if (_autoReading && mounted) setState(() => _autoReading = false);
  }

  void _startAutoReading() {
    _autoTimer?.cancel();
    _autoTicks = 0;
    setState(() {
      _autoReading = true;
      _panel = null;
      _chromeVisible = false;
    });
    _autoTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (!mounted || _loading || _initialJumping || _panel != null) return;
      if (_loadFailed || _images.isEmpty) {
        _stopAutoReading();
        return;
      }
      if (_scrollReading && _scrollController.hasClients) {
        final position = _scrollController.position;
        if (position.pixels < position.maxScrollExtent) {
          _scrollController.jumpTo(
            math.min(
              position.maxScrollExtent,
              position.pixels + _scrollSpeed / 20,
            ),
          );
        } else if (_mobile && _flowLastChapter < _chapters.length - 1) {
          if (_flowError != null) {
            _stopAutoReading();
            return;
          }
          _appendNextChapter();
        } else if (_hasNext || _canNextComic) {
          _autoContinue();
        } else {
          _stopAutoReading();
        }
      } else if (++_autoTicks >= _pageSeconds * 20) {
        _autoTicks = 0;
        if (_currentPage + _spreadCount >= _images.length &&
            !_hasNext &&
            !_canNextComic) {
          _stopAutoReading();
        } else {
          _nextPage();
        }
      }
    });
  }

  Future<void> _toggleFullscreen() async {
    try {
      if (isWindowsPlatform) {
        final next = !await windowManager.isFullScreen();
        await windowManager.setFullScreen(next);
        if (mounted) setState(() => _fullscreen = next);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('无法切换全屏，请重试')));
      }
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
    if (_currentPage + _spreadCount < _images.length) {
      _goToPage(_currentPage + _spreadCount);
    } else {
      _autoContinue();
    }
  }

  void _prevPage() {
    if (_images.isEmpty) return;
    if (_currentPage > 0) {
      _goToPage(math.max(0, _currentPage - _spreadCount));
    } else {
      _prevChapter();
    }
  }

  /// 桌面形态章内直达指定页（页码越界时收敛到首/末页）。
  void _goToPage(int page) {
    if (_images.isEmpty) return;
    final target = page.clamp(0, _images.length - 1).toInt();
    if (_scrollReading) {
      _jumpToPage(target);
      return;
    }
    setState(() => _currentPage = target);
    _precacheAround(target);
    _recordPosition();
  }

  /// 桌面形态的键盘翻页与换章绑定；边界行为复用对应操作。
  Map<ShortcutActivator, VoidCallback> _desktopShortcutBindings() {
    return {
      const SingleActivator(LogicalKeyboardKey.arrowLeft): _rightToLeft
          ? _nextPage
          : _prevPage,
      const SingleActivator(LogicalKeyboardKey.arrowRight): _rightToLeft
          ? _prevPage
          : _nextPage,
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
    } else if (_canNextComic) {
      await _nextComic();
    }
  }

  /// 连续阅读：按开读时的列表顺序切换，从目标第 1 章开始。
  Future<void> _nextComic() async {
    if (!_canNextComic || _switchingComic) return;
    await _switchComic(
      () => widget.readingSession?.next(_comicId) ?? widget.onNextComic!(),
    );
  }

  Future<void> _prevComic() async {
    if (_switchingComic || !_canPrevComic) return;
    await _switchComic(
      () => widget.readingSession?.prev(_comicId) ?? widget.onPrevComic!(),
    );
  }

  Future<void> _switchComic(Future<Comic?> Function() adjacent) async {
    setState(() => _switchingComic = true);
    try {
      await _saveProgress();
      final comic = await adjacent();
      if (!mounted) return;
      if (comic == null) {
        _stopAutoReading();
        return;
      }
      await _loadComic(comic);
    } catch (error) {
      if (!mounted) return;
      _stopAutoReading();
      if (widget.readingSession?.isCurrent ?? true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(userMessageFor(error, fallback: '切换漫画失败，请重试')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _switchingComic = false);
    }
  }

  /// 整体替换为另一本漫画：章节列表 + 定位到第 1 章。
  Future<void> _loadComic(Comic comic) async {
    if (!(widget.readingSession?.isCurrent ?? true)) return;
    final generation = ref.read(serverSessionProvider).generation;
    final detail = await ref.read(comicDetailProvider(comic.id).future);
    if (!mounted ||
        ref.read(serverSessionProvider).generation != generation ||
        !(widget.readingSession?.isCurrent ?? true)) {
      return;
    }
    if (detail.chapters.isEmpty) {
      _stopAutoReading();
      setState(() => _switchingComic = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('暂无章节')));
      return;
    }
    setState(() {
      _comic = detail.comic;
      _comicId = comic.id;
      _title = comic.title;
      _chapters = detail.chapters;
      _chapterIndex = 0;
    });
    await _loadChapter(_chapters[0].id);
    if (mounted) setState(() => _switchingComic = false);
  }

  Future<void> _loadChapter(int chapterId, {int? initialPage}) async {
    _flowGeneration++;
    _flow.clear();
    _flowChapters.clear();
    _flowLoading = false;
    _flowError = null;
    _flowLastChapter = _chapterIndex;
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
        _flowChapters[_chapterIndex] = images;
        _flow.addAll(
          images.map((image) => (chapter: _chapterIndex, image: image)),
        );
        _currentPage =
            initialPage != null &&
                initialPage >= 0 &&
                initialPage < images.length
            ? initialPage
            : 0;
        _pendingJumpPage = _currentPage;
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
    ref.invalidate(chapterImagesProvider(chapterId));
    await _loadChapter(chapterId);
  }

  ImageProvider<Object> _imageProvider(ImageItem item) => displayImageProvider(
    item.url,
    logicalSize: _imageViewport!,
    devicePixelRatio: _imagePixelRatio,
    fit: _pageFit,
  );

  void _updateImageLayout(Size size, {required bool desktop}) {
    final ratio = MediaQuery.devicePixelRatioOf(context);
    _imageViewport = size;
    _imagePixelRatio = ratio;
    _desktopImages = desktop;
    final signature = _imageProvider(_images.first);
    final srLayout = (size, ratio, desktop, _pageFit);
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
      if (_mobile &&
          _scrollController.hasClients &&
          _scrollController.position.extentAfter < 1000 &&
          _flowError == null) {
        _appendNextChapter();
      }
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
            ((_desktopImages && _pageFit == BoxFit.none && image.width != null
                        ? image.width! / _imagePixelRatio
                        : _desktopImages &&
                              _pageFit == BoxFit.contain &&
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
      fit: _pageFit,
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

  Future<void> _superResolutionAction(String action) async {
    final controller = ref.read(superResolutionProvider.notifier);
    if (action == 'prevComic') {
      await _prevComic();
      return;
    }
    if (action == 'nextComic') {
      await _nextComic();
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
        await ref
            .read(superResolutionDefaultProvider.notifier)
            .setMode(SuperResolutionMode.off);
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
    for (final img in _scrollImages) {
      _extents.add(top);
      top += _estimatedHeight(img, width);
    }

    final target = _pendingJumpPage == null
        ? null
        : _flowPage(_pendingJumpPage!);
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
    final contentHeight =
        _extents.last + _estimatedHeight(_scrollImages.last, _extentWidth!);
    final targetOffset = _extents[target].clamp(
      0.0,
      math.max(0.0, contentHeight - _imageViewport!.height),
    );
    _scrollController.jumpTo(targetOffset.clamp(0.0, max).toDouble());
    if (max >= targetOffset) {
      _initialJumping = false;
      _recordPosition();
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

  Future<void> _appendNextChapter() async {
    if (_flowLoading || _flowLastChapter >= _chapters.length - 1) return;
    final generation = _flowGeneration;
    final index = _flowLastChapter + 1;
    if (_flowError != null) {
      ref.invalidate(chapterImagesProvider(_chapters[index].id));
    }
    setState(() {
      _flowLoading = true;
      _flowError = null;
    });
    try {
      final images = await ref.read(
        chapterImagesProvider(_chapters[index].id).future,
      );
      if (!mounted || generation != _flowGeneration) return;
      if (images.isEmpty) throw StateError('下一章暂无图片');
      setState(() {
        _flowChapters[index] = images;
        _flow.addAll(images.map((image) => (chapter: index, image: image)));
        _flowLastChapter = index;
        _flowLoading = false;
        if (_extentWidth != null) _buildExtents(_extentWidth!);
      });
    } catch (error) {
      if (!mounted || generation != _flowGeneration) return;
      setState(() {
        _flowLoading = false;
        _flowError = error;
      });
    }
  }

  void _onScroll() {
    if (!_scrollReading ||
        _loading ||
        _initialJumping ||
        _extents.isEmpty ||
        !_scrollController.hasClients) {
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
    final atEnd = offset >= _scrollController.position.maxScrollExtent - 1;
    if (_mobile && _flow.isNotEmpty) {
      if (atEnd) page = _flow.length - 1;
      final entry = _flow[page];
      final localPage =
          page - _flow.indexWhere((item) => item.chapter == entry.chapter);
      final changedChapter = entry.chapter != _chapterIndex;
      if (changedChapter) {
        ref.read(superResolutionProvider.notifier).resetChapter();
      }
      if (changedChapter || localPage != _currentPage) {
        setState(() {
          _chapterIndex = entry.chapter;
          _chapterId = _chapters.isEmpty
              ? _chapterId
              : _chapters[_chapterIndex].id;
          _images = _flowChapters[entry.chapter]!;
          _currentPage = localPage;
        });
        _precacheAround(localPage);
        _recordPosition();
      }
      if (_scrollController.position.extentAfter < 1000 && _flowError == null) {
        _appendNextChapter();
      }
    } else {
      if (atEnd) page = _images.length - 1;
      if (page != _currentPage) {
        setState(() => _currentPage = page);
        _precacheAround(page);
        _recordPosition();
      }
      if (atEnd && (_hasNext || _canNextComic)) _autoContinue();
    }
  }

  void _jumpToPage(int page) {
    if (!_scrollController.hasClients || _extents.isEmpty) return;
    if (page < 0 || page >= _extents.length) return;
    setState(() => _currentPage = page);
    _initialJumping = true;
    _jumpAttempts = 0;
    final generation = ++_jumpGeneration;
    _performInitialJump(_flowPage(page), generation);
    _precacheAround(page);
    _recordPosition();
  }

  Future<void> _ensureChapters() async {
    if (_chapters.isNotEmpty) return;
    try {
      ref.invalidate(comicDetailProvider(_comicId));
      final detail = await ref.read(comicDetailProvider(_comicId).future);
      if (!mounted || _chapters.isNotEmpty) return;
      final targetId = _chapterId;
      final idx = detail.chapters.indexWhere((c) => c.id == targetId);
      if (idx < 0) return;
      setState(() {
        _comic = detail.comic;
        _chapters = detail.chapters;
        _chapterIndex = idx;
        _flowGeneration++;
        _flowLoading = false;
        _flowError = null;
        _flowChapters.clear();
        _flowChapters[idx] = _images;
        _flow.clear();
        _flow.addAll(_images.map((image) => (chapter: idx, image: image)));
        _flowLastChapter = idx;
      });
    } catch (_) {
      // 章节列表仍不可用
    }
  }

  Future<void> _openDirectory() async {
    await _ensureChapters();
    if (mounted) _setPanel('directory');
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
    final preferences = ref.watch(readerPreferencesProvider);
    final continuous = !desktop || preferences.mode == ReaderMode.continuous;
    _spreadCount =
        !continuous &&
            preferences.mode == ReaderMode.doublePage &&
            width >= kDesktopBreakpoint
        ? 2
        : 1;
    if (_scrollReading != continuous) {
      _scrollReading = continuous;
      _extentWidth = null;
      if (!_loading) _jumpGeneration++;
      _pendingJumpPage = continuous ? _currentPage : null;
      _initialJumping = continuous;
      _jumpAttempts = 0;
    }
    ref.watch(superResolutionProvider);
    ref.watch(localReadingProgressProvider(_comicId));
    final c = context.appColors;
    final scaffold = Scaffold(
      backgroundColor: _readerBackground,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onSecondaryTapDown: desktop
                    ? (details) => _setPanel('settings')
                    : null,
                onDoubleTap: desktop
                    ? null
                    : () {
                        _stopAutoReading();
                        setState(() => _chromeVisible = !_chromeVisible);
                      },
                child: _buildChapterBody(desktop),
              ),
            ),
            if (!desktop && _chromeVisible) ...[
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Material(
                  color: c.readerBar,
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: '返回上一页',
                        onPressed: _exitReader,
                        icon: const Icon(Icons.arrow_back),
                      ),
                      Expanded(
                        child: Text(
                          _currentChapter?.title ?? _title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        tooltip: '菜单',
                        onPressed: () => _setPanel('settings'),
                        icon: const Icon(Icons.more_horiz),
                      ),
                      IconButton(
                        tooltip: '关闭控制层',
                        onPressed: () => setState(() => _chromeVisible = false),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (_autoReading)
              Positioned(
                top: 12,
                right: 12,
                child: FilledButton.tonalIcon(
                  onPressed: _stopAutoReading,
                  icon: const Icon(Icons.pause),
                  label: const Text('停止自动阅读'),
                ),
              ),
            if (_panel != null) Positioned.fill(child: _buildPanel(desktop)),
          ],
        ),
      ),
    );
    return PopScope(
      canPop: _panel == null,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          if (!_exiting) _saveProgress();
          if (_fullscreen && isWindowsPlatform) {
            unawaited(windowManager.setFullScreen(false));
          }
        } else if (_panel != null) {
          _setPanel(null);
        }
      },
      child: desktop
          ? CallbackShortcuts(
              bindings: _panel == null ? _desktopShortcutBindings() : {},
              child: Focus(autofocus: true, child: scaffold),
            )
          : scaffold,
    );
  }

  Widget _progressControl() => ReaderProgressBar(
    chapterTitle: _currentChapter?.title ?? _title,
    currentPage: _currentPage,
    totalPages: _images.length,
    onSeek: (page) {
      _stopAutoReading();
      _goToPage(page);
    },
  );

  Widget _buildPanel(bool desktop) {
    final c = context.appColors;
    final directory = _panel == 'directory';
    const panelWidth = 460.0;
    final content = Material(
      color: c.surface1,
      elevation: 12,
      borderRadius: BorderRadius.circular(kRadiusFloat),
      clipBehavior: Clip.antiAlias,
      child: directory
          ? ChapterDirectory(
              chapters: _chapters,
              currentIndex: _chapterIndex,
              onClose: () => _setPanel(null),
              onSelect: (i) {
                _setPanel(null);
                _goToChapter(i);
              },
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 8, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '阅读设置',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      if (desktop && isWindowsPlatform)
                        IconButton(
                          tooltip: _fullscreen ? '退出全屏' : '全屏',
                          onPressed: _toggleFullscreen,
                          icon: Icon(
                            _fullscreen
                                ? Icons.fullscreen_exit
                                : Icons.fullscreen,
                          ),
                        ),
                      IconButton(
                        tooltip: '返回上一页',
                        onPressed: _exitReader,
                        icon: const Icon(Icons.arrow_back),
                      ),
                      IconButton(
                        tooltip: '关闭阅读设置',
                        onPressed: () => _setPanel(null),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                Flexible(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _navigationContents(),
                          const Divider(height: 32),
                          _settingsContents(),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            Positioned.fill(
              child: ModalBarrier(
                dismissible: true,
                onDismiss: () => _setPanel(null),
                semanticsLabel: '关闭阅读面板',
                color: Colors.black38,
              ),
            ),
            Align(
              alignment: desktop
                  ? Alignment.centerRight
                  : Alignment.bottomCenter,
              child: SizedBox(
                width: desktop
                    ? panelWidth
                    : math.min(640.0, constraints.maxWidth),
                height: desktop
                    ? constraints.maxHeight
                    : constraints.maxHeight * .88,
                child: content,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _navigationContents() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _progressControl(),
      const SizedBox(height: 4),
      Row(
        children: [
          Expanded(
            child: TextButton(
              onPressed: _hasPrev
                  ? () {
                      _setPanel(null);
                      _prevChapter();
                    }
                  : null,
              child: const Text('上一章'),
            ),
          ),
          Expanded(
            child: TextButton(
              onPressed: _openDirectory,
              child: const Text('章节目录'),
            ),
          ),
          Expanded(
            child: TextButton(
              onPressed: _hasNext
                  ? () {
                      _setPanel(null);
                      _nextChapter();
                    }
                  : null,
              child: const Text('下一章'),
            ),
          ),
        ],
      ),
      if (_hasComicSequence)
        Wrap(
          spacing: 8,
          children: [
            TextButton(
              onPressed: _canPrevComic && !_switchingComic
                  ? () {
                      _setPanel(null);
                      _prevComic();
                    }
                  : null,
              child: const Text('上一本'),
            ),
            TextButton(
              onPressed: _canNextComic && !_switchingComic
                  ? () {
                      _setPanel(null);
                      _nextComic();
                    }
                  : null,
              child: const Text('下一本'),
            ),
          ],
        ),
    ],
  );

  Widget _settingsContents() {
    final sr = ref.watch(superResolutionProvider);
    final image = _images.isEmpty ? null : _images[_currentPage];
    final job = sr.results[image?.url];
    final status = !sr.enabled
        ? '超分关闭 · 原图'
        : sr.reasons[image?.url] ??
              job?.error ??
              switch (job?.status) {
                'ready' => '超分 2× 已就绪',
                'queued' => '排队中 · 原图',
                _ => '处理中 · 原图',
              };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ReaderSettingsControls(compact: true),
        const SizedBox(height: 4),
        Text(status, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 4),
        Text(
          'waifu2x · 固定 2× · 预处理后 ${sr.lookahead} 页',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton(
              onPressed: sr.enabled && image != null
                  ? () => _superResolutionAction('retry')
                  : null,
              child: const Text('重试超分'),
            ),
            OutlinedButton(
              onPressed: () => _superResolutionAction('clear'),
              child: const Text('清空超分缓存'),
            ),
          ],
        ),
        const Divider(height: 32),
        Text('自动滚动／翻页', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 12),
        if (_scrollReading) ...[
          Text('滚动速度：${_scrollSpeed.round()} 像素／秒'),
          Slider(
            value: _scrollSpeed,
            min: 10,
            max: 200,
            divisions: 19,
            onChanged: (value) => setState(() => _scrollSpeed = value),
          ),
        ] else ...[
          Text('翻页间隔：$_pageSeconds 秒'),
          Slider(
            value: _pageSeconds.toDouble(),
            min: 2,
            max: 30,
            divisions: 28,
            onChanged: (value) => setState(() => _pageSeconds = value.round()),
          ),
        ],
        OutlinedButton.icon(
          onPressed: image == null ? null : _startAutoReading,
          icon: const Icon(Icons.play_arrow),
          label: const Text('开始自动阅读'),
        ),
        const Divider(height: 32),
        Text('图片信息', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 12),
        Text(
          image == null
              ? '暂无图片'
              : '第 ${_currentPage + 1} 页 · ${image.width ?? "未知"} × ${image.height ?? "未知"}',
        ),
        if (image != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              image.filename,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        if (ref.watch(localReadingProgressProvider(_comicId)) != null) ...[
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _saveProgress,
            icon: const Icon(Icons.cloud_upload_outlined),
            label: const Text('同步阅读进度'),
          ),
        ],
      ],
    );
  }

  /// 章节主体的统一状态分支：加载中 / 加载失败 / 空章 / 正常阅读。
  Widget _buildChapterBody(bool desktop) {
    if (_loading) return const ImageLoadingPlaceholder(label: '正在加载章节');
    if (_loadFailed) return _buildLoadError();
    if (_images.isEmpty) return _buildEmptyChapter();
    return _scrollReading
        ? _buildContinuousBody(desktop: desktop)
        : _buildPagedBody(context);
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

  Widget _buildContinuousBody({required bool desktop}) =>
      NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification is ScrollStartNotification &&
              notification.dragDetails != null) {
            _stopAutoReading();
          }
          if (!desktop &&
              notification is OverscrollNotification &&
              notification.overscroll > 0 &&
              !_loading &&
              !_initialJumping &&
              !_flowLoading) {
            if (_flowLastChapter < _chapters.length - 1 && _flowError == null) {
              _appendNextChapter();
            } else if (_flowLastChapter == _chapters.length - 1 &&
                _canNextComic) {
              _autoContinue();
            }
          }
          return false;
        },
        child: _buildScrollBody(desktop: desktop),
      );

  Widget _buildScrollBody({required bool desktop}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = desktop
            ? math.min(constraints.maxWidth, 960.0)
            : constraints.maxWidth;
        if (_extentWidth != width ||
            _imageViewport?.height != constraints.maxHeight) {
          if (_extentWidth != null) {
            _pendingJumpPage = _currentPage;
            _jumpGeneration++;
            _jumpAttempts = 0;
          }
          _buildExtents(width);
        }
        _updateImageLayout(Size(width, constraints.maxHeight), desktop: false);
        final images = _scrollImages;
        return Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: width,
            child: Listener(
              onPointerSignal: (event) {
                if (desktop &&
                    event is PointerScrollEvent &&
                    event.scrollDelta.dy > 0 &&
                    !_initialJumping &&
                    !_loading &&
                    _scrollController.hasClients &&
                    _scrollController.offset >=
                        _scrollController.position.maxScrollExtent - 1) {
                  _autoContinue();
                }
              },
              child: ListView.builder(
                controller: _scrollController,
                padding: EdgeInsets.zero,
                // ignore: deprecated_member_use
                cacheExtent: 800,
                itemCount: images.length + (desktop ? 0 : 1),
                itemBuilder: (ctx, i) {
                  if (i == images.length) {
                    return Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          if (_flowLoading)
                            const CircularProgressIndicator()
                          else if (_flowLastChapter < _chapters.length - 1)
                            TextButton(
                              onPressed: _appendNextChapter,
                              child: Text(
                                _flowError == null ? '继续向下阅读' : '下一章加载失败，点击重试',
                              ),
                            )
                          else ...[
                            const Text('已读完'),
                            TextButton(
                              onPressed: _exitReader,
                              child: const Text('返回上一页'),
                            ),
                            if (_hasComicSequence)
                              TextButton(
                                onPressed: _canNextComic && !_switchingComic
                                    ? _nextComic
                                    : null,
                                child: const Text('下一本'),
                              ),
                          ],
                        ],
                      ),
                    );
                  }
                  final image = images[i];
                  return _LazyImage(
                    key: ValueKey((
                      desktop ? _chapterIndex : _flow[i].chapter,
                      image.url,
                    )),
                    provider: _imageProvider(image),
                    enhanced: _enhancedProvider(image),
                    onEnhancedError: _enhancedFailure(image),
                    height: _estimatedHeight(image, width),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPagedBody(BuildContext context) {
    final page = _currentPage.clamp(0, _images.length - 1).toInt();
    final List<int?> pages = [
      page,
      if (_spreadCount == 2) page + 1 < _images.length ? page + 1 : null,
    ];
    final ordered = _rightToLeft ? pages.reversed.toList() : pages;
    return GestureDetector(
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity.abs() < 100) return;
        if ((velocity < 0) != _rightToLeft) {
          _nextPage();
        } else {
          _prevPage();
        }
      },
      child: Listener(
        onPointerSignal: (event) {
          if (event is PointerScrollEvent && event.scrollDelta.dy != 0) {
            GestureBinding.instance.pointerSignalResolver.register(event, (_) {
              if (event.scrollDelta.dy > 0) {
                _nextPage();
              } else {
                _prevPage();
              }
            });
          }
        },
        child: Column(
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final slot = Size(
                    constraints.maxWidth / _spreadCount,
                    constraints.maxHeight,
                  );
                  _updateImageLayout(slot, desktop: true);
                  return Stack(
                    children: [
                      ColoredBox(
                        color: _readerBackground,
                        child: Row(
                          children: [
                            for (final index in ordered)
                              SizedBox(
                                width: slot.width,
                                height: slot.height,
                                child: index == null
                                    ? null
                                    : _buildPageImage(index, slot),
                              ),
                          ],
                        ),
                      ),
                      if (_chromeVisible) ...[
                        Align(
                          alignment: Alignment.centerLeft,
                          child: IconButton.filledTonal(
                            tooltip: _rightToLeft ? '下一页' : '上一页',
                            onPressed: _rightToLeft ? _nextPage : _prevPage,
                            icon: const Icon(Icons.chevron_left),
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: IconButton.filledTonal(
                            tooltip: _rightToLeft ? '上一页' : '下一页',
                            onPressed: _rightToLeft ? _prevPage : _nextPage,
                            icon: const Icon(Icons.chevron_right),
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageImage(int page, Size slot) {
    final image = _images[page];
    final fit = _pageFit;
    final ratio = MediaQuery.devicePixelRatioOf(context);
    final imageWidth = fit == BoxFit.none
        ? (image.width ?? slot.width * ratio) / ratio
        : slot.width;
    final imageHeight = fit == BoxFit.none
        ? (image.height ?? slot.height * ratio) / ratio
        : fit == BoxFit.fitWidth
        ? _estimatedHeight(image, imageWidth)
        : slot.height;
    final content = SizedBox(
      width: imageWidth,
      height: imageHeight,
      child: EnhancedImage(
        enhanced: _enhancedProvider(image),
        fit: fit == BoxFit.none ? BoxFit.contain : fit,
        onError: _enhancedFailure(image),
        original: Image(
          image: _imageProvider(image),
          key: ValueKey('page-img-$page-$_imageRetryTick'),
          fit: fit == BoxFit.none ? BoxFit.contain : fit,
          frameBuilder: (context, child, frame, synchronous) => imageFrame(
            context,
            child,
            frame,
            synchronous,
            placeholder: const ImageLoadingPlaceholder(),
          ),
          loadingBuilder: (_, child, progress) => progress == null
              ? child
              : ImageLoadingPlaceholder(progress: progress),
          errorBuilder: (_, _, _) => GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _retryPageImage(page),
            child: const _ImageRetryBox(),
          ),
        ),
      ),
    );
    if (fit == BoxFit.contain) return content;
    final vertical = SingleChildScrollView(
      key: ValueKey((page, fit, slot)),
      child: Align(alignment: Alignment.topCenter, child: content),
    );
    if (fit == BoxFit.fitWidth) return vertical;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(width: math.max(imageWidth, slot.width), child: vertical),
    );
  }

  Future<void> _retryPageImage(int page) async {
    if (page >= _images.length || _imageViewport == null) return;
    final url = _images[page].url;
    final generation = _jumpGeneration;
    await _imageProvider(_images[page]).evict();
    if (!mounted ||
        generation != _jumpGeneration ||
        page >= _images.length ||
        _images[page].url != url) {
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
                  frameBuilder: (context, child, frame, synchronous) =>
                      imageFrame(
                        context,
                        child,
                        frame,
                        synchronous,
                        placeholder: const ImageLoadingPlaceholder(),
                      ),
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

  Widget _loadingBox({ImageChunkEvent? progress}) =>
      ImageLoadingPlaceholder(progress: progress);
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
