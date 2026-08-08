import 'package:flutter/material.dart';
import '../models/image_item.dart';
import '../services/api.dart';

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
  List<ImageItem> _images = [];
  bool _loading = true;
  final _scrollController = ScrollController();
  final List<double> _extents = [];
  int _currentPage = 0;
  bool _didInitialJump = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _saveProgress();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final images = await ApiService.getChapterImages(widget.chapterId);
    if (!mounted) return;
    setState(() {
      _images = images;
      _loading = false;
    });
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

    if (!_didInitialJump) {
      _didInitialJump = true;
      final target = widget.initialPage;
      if (target != null && target > 0 && target < _extents.length) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !_scrollController.hasClients) return;
          final max = _scrollController.position.maxScrollExtent;
          _scrollController.jumpTo(_extents[target].clamp(0.0, max));
        });
      }
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
  }

  void _saveProgress() {
    if (_images.isEmpty) return;
    ApiService.updateProgress(
      comicId: widget.comicId,
      chapterId: widget.chapterId,
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
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          widget.title,
          style: const TextStyle(color: Colors.white, fontSize: 15),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              controller: _scrollController,
              cacheExtent: 800,
              itemCount: _images.length,
              itemBuilder: (ctx, i) => _LazyImage(url: _images[i].url),
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
    // widget 进入视口（被 build）时才开始加载
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) {
      // 占位高度，防止全部 item 同时 build
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
