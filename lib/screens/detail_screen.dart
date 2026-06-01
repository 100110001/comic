import 'package:flutter/material.dart';
import '../models/comic.dart';
import '../models/chapter.dart';
import '../services/api.dart';
import 'reader_screen.dart';

class DetailScreen extends StatefulWidget {
  final int comicId;
  final void Function(String)? onAuthorTap;
  const DetailScreen({super.key, required this.comicId, this.onAuthorTap});

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  Comic? _comic;
  List<Chapter> _chapters = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await ApiService.getComic(widget.comicId);
    setState(() {
      _comic = r.comic;
      _chapters = r.chapters;
      _loading = false;
    });
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('删除《${_comic?.title}》将同时删除本地文件，不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await ApiService.deleteComic(widget.comicId);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0d1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161b22),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          _comic?.title ?? '',
          style: const TextStyle(color: Colors.white, fontSize: 15),
        ),
        actions: [
          if (_comic != null)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: _delete,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _Header(comic: _comic!, onAuthorTap: widget.onAuthorTap),
                const Divider(color: Color(0xFF21262d), height: 1),
                Expanded(child: _ChapterList(chapters: _chapters)),
              ],
            ),
    );
  }
}

class _Header extends StatelessWidget {
  final Comic comic;
  final void Function(String)? onAuthorTap;
  const _Header({required this.comic, this.onAuthorTap});

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
                    errorBuilder: (_, __, ___) => _placeholder(),
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
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (comic.author != null) ...[
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () {
                      onAuthorTap?.call(comic.author!);
                      Navigator.pop(context);
                    },
                    child: Text(
                      comic.author!,
                      style: const TextStyle(
                        color: Color(0xFF58a6ff),
                        fontSize: 13,
                        decoration: TextDecoration.underline,
                        decorationColor: Color(0xFF58a6ff),
                      ),
                    ),
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
  final List<Chapter> chapters;
  const _ChapterList({required this.chapters});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: chapters.length,
      separatorBuilder: (_, __) =>
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
              builder: (_) => ReaderScreen(chapterId: ch.id, title: ch.title),
            ),
          ),
        );
      },
    );
  }
}
