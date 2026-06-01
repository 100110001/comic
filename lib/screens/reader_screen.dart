import 'package:flutter/material.dart';
import '../models/image_item.dart';
import '../services/api.dart';

class ReaderScreen extends StatefulWidget {
  final int chapterId;
  final String title;
  const ReaderScreen({super.key, required this.chapterId, required this.title});

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  List<ImageItem> _images = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final images = await ApiService.getChapterImages(widget.chapterId);
    setState(() {
      _images = images;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(widget.title,
            style: const TextStyle(color: Colors.white, fontSize: 15)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
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
