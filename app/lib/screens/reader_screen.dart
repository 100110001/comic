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
  int _spreadCount = 1;
  bool _settingsOpen = false;
  bool _scrollReading = false;
  ImageProvider<Object>? _imageLayoutSignature;
  Object? _superResolutionLayoutSignature;
  int _imageLayoutGeneration = 0;
  Timer? _hideTimer;
  bool _chromeVisible = true;
  bool _pointerOverChrome = false;

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
    if (_preferences.autoHide) {
      _hideTimer = Timer(const Duration(seconds: 3), _maybeHideChrome);
    }
  }

  /// 无操作超时后隐藏工具栏；指针停留在工具栏区域时推迟隐藏。
  void _maybeHideChrome() {
    if (!mounted) return;
    if (!_preferences.autoHide) return;
    if (_pointerOverChrome || _settingsOpen) {
      _restartHideTimer();
      return;
    }
    if (_chromeVisible) {
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
    final contentHeight =
        _extents.last + _estimatedHeight(_images.last, _extentWidth!);
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
    if (atEnd) page = _images.length - 1;
    if (page != _currentPage) {
      setState(() => _currentPage = page);
      _precacheAround(page);
      _recordPosition();
    }
    // 滚动接近本章底部时自动续章
    final desktop = isDesktopAt(MediaQuery.sizeOf(context).width);
    if ((_hasNext || (desktop && widget.onNextComic != null)) &&
        (desktop
            ? atEnd
            : offset >= _scrollController.position.maxScrollExtent - 200)) {
      _autoContinue();
    }
  }

  void _jumpToPage(int page) {
    if (!_scrollController.hasClients || _extents.isEmpty) return;
    if (page < 0 || page >= _extents.length) return;
    setState(() => _currentPage = page);
    _initialJumping = true;
    _jumpAttempts = 0;
    final generation = ++_jumpGeneration;
    _performInitialJump(page, generation);
    _precacheAround(page);
    _recordPosition();
  }

  Future<void> _openReadingSettings() async {
    _onActivity();
    _settingsOpen = true;
    final desktop = isDesktopAt(MediaQuery.sizeOf(context).width);
    Widget panel(BuildContext ctx) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(ctx).height * 0.85,
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '阅读设置',
                      style: Theme.of(ctx).textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    tooltip: '关闭阅读设置',
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const Text('应用于所有漫画，与设置页同步'),
              const SizedBox(height: 8),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const ReaderSettingsControls(compact: true),
                      const Divider(),
                      Consumer(
                        builder: (context, panelRef, _) {
                          final sr = panelRef.watch(superResolutionProvider);
                          final pending = panelRef.watch(
                            localReadingProgressProvider(_comicId),
                          );
                          final url = _images.isEmpty
                              ? null
                              : _images[_currentPage].url;
                          final job = sr.results[url];
                          final status = !sr.enabled
                              ? '超分关闭 · 原图'
                              : sr.reasons[url] ??
                                    job?.error ??
                                    (job?.status == 'ready'
                                        ? '超分 2× 已就绪'
                                        : '超分处理中 · 预处理后 ${sr.lookahead} 页');
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                status,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: sr.enabled && _images.isNotEmpty
                                        ? () => _superResolutionAction('retry')
                                        : null,
                                    icon: const Icon(Icons.refresh, size: 18),
                                    label: const Text('重试超分'),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: () =>
                                        _superResolutionAction('clear'),
                                    icon: const Icon(
                                      Icons.cleaning_services_outlined,
                                      size: 18,
                                    ),
                                    label: const Text('清空超分缓存'),
                                  ),
                                  if (pending != null &&
                                      MediaQuery.sizeOf(context).width < 500)
                                    OutlinedButton.icon(
                                      onPressed: _saveProgress,
                                      icon: const Icon(
                                        Icons.cloud_upload_outlined,
                                        size: 18,
                                      ),
                                      label: const Text('同步阅读进度'),
                                    ),
                                  if (MediaQuery.sizeOf(context).width < 500 &&
                                      widget.onPrevComic != null)
                                    OutlinedButton(
                                      onPressed:
                                          _canPrevComic && !_switchingComic
                                          ? () {
                                              Navigator.pop(ctx);
                                              _prevComic();
                                            }
                                          : null,
                                      child: const Text('上一本'),
                                    ),
                                  if (MediaQuery.sizeOf(context).width < 500 &&
                                      widget.onNextComic != null)
                                    OutlinedButton(
                                      onPressed: !_switchingComic
                                          ? () {
                                              Navigator.pop(ctx);
                                              _nextComic();
                                            }
                                          : null,
                                      child: const Text('下一本'),
                                    ),
                                ],
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (desktop) {
      await showDialog<void>(
        context: context,
        builder: (ctx) =>
            Dialog(child: SizedBox(width: 440, child: panel(ctx))),
      );
    } else {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        constraints: const BoxConstraints(maxWidth: 640),
        builder: panel,
      );
    }
    _settingsOpen = false;
    if (mounted) _onActivity();
  }

  void _openMobileDirectory() {
    if (_chapters.isEmpty) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 640),
      builder: (ctx) => SizedBox(
        height: MediaQuery.sizeOf(ctx).height * 0.7,
        child: ChapterDirectory(
          chapters: _chapters,
          currentIndex: _chapterIndex,
          onSelect: (i) {
            Navigator.pop(ctx);
            _goToChapter(i);
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
    final preferences = ref.watch(readerPreferencesProvider);
    ref.listen(readerPreferencesProvider, (previous, next) {
      if (previous?.autoHide != next.autoHide) _onActivity();
    });
    final continuous =
        preferences.mode == ReaderMode.continuous ||
        (preferences.mode == ReaderMode.automatic && !desktop);
    _spreadCount =
        !continuous &&
            preferences.mode == ReaderMode.doublePage &&
            width >= kDesktopBreakpoint
        ? 2
        : 1;
    if (!desktop && !preferences.autoHide) _chromeVisible = true;
    if (_scrollReading != continuous) {
      _scrollReading = continuous;
      _extentWidth = null;
      if (!_loading) _jumpGeneration++;
      _pendingJumpPage = continuous ? _currentPage : null;
      _initialJumping = continuous;
      _jumpAttempts = 0;
    }
    final sr = ref.watch(superResolutionProvider);
    final srJob = _images.isEmpty
        ? null
        : sr.results[_images[_currentPage].url];
    final srReason = _images.isEmpty
        ? null
        : sr.reasons[_images[_currentPage].url];
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
    final textScaler = MediaQuery.textScalerOf(context);
    final toolbarHeight = math.max(
      kToolbarHeight,
      textScaler.scale(15) * 1.3 + textScaler.scale(11) * 1.3 + 10,
    );
    final Widget scaffold = Scaffold(
      backgroundColor: _readerBackground,
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
        preferredSize: Size.fromHeight(toolbarHeight),
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
                toolbarHeight: toolbarHeight,
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
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: c.text1,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      srStatus,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
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
                  IconButton(
                    tooltip: '阅读设置',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.tune),
                    onPressed: _openReadingSettings,
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
                  if (widget.onPrevComic != null && width >= 500)
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
                  if (widget.onNextComic != null && width >= 500)
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
      child: GestureDetector(
        onTap: _onActivity,
        child: desktop
            ? CallbackShortcuts(
                bindings: _desktopShortcutBindings(),
                child: Focus(
                  autofocus: true,
                  onKeyEvent: (node, event) {
                    _onActivity();
                    return KeyEventResult.ignored;
                  },
                  child: scaffold,
                ),
              )
            : scaffold,
      ),
    );
  }

  /// 章节主体的统一状态分支：加载中 / 加载失败 / 空章 / 正常阅读。
  Widget _buildChapterBody(bool desktop) {
    if (_loading) return const Center(child: CircularProgressIndicator());
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

  Widget _buildContinuousBody({required bool desktop}) {
    return Stack(
      children: [
        _buildScrollBody(desktop: desktop),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SafeArea(
            top: false,
            child: AnimatedOpacity(
              opacity: _chromeVisible ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              child: IgnorePointer(
                ignoring: !_chromeVisible,
                child: ReaderProgressBar(
                  currentPage: _currentPage,
                  totalPages: _images.length,
                  onSeek: (page) {
                    _jumpToPage(page);
                    _onActivity();
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

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
            SafeArea(
              top: false,
              child: AnimatedOpacity(
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
          loadingBuilder: (_, child, progress) => progress == null
              ? child
              : const Center(child: CircularProgressIndicator()),
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
