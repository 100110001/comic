import 'package:flutter/material.dart';
import '../models/comic.dart';
import '../services/api.dart';
import 'detail_screen.dart';

class RandomScreen extends StatefulWidget {
  final void Function(String)? onAuthorTap;
  const RandomScreen({super.key, this.onAuthorTap});

  @override
  State<RandomScreen> createState() => _RandomScreenState();
}

class _RandomScreenState extends State<RandomScreen> {
  List<Comic> _comics = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await ApiService.getRandomComics(pageSize: 30);
      setState(() => _comics = list);
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0d1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161b22),
        title: const Text('随机', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF8b949e)),
            tooltip: '刷新',
            onPressed: _loading ? null : _load,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFF21262d)),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: GridView.builder(
                padding: const EdgeInsets.all(12),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 160,
                  childAspectRatio: 0.58,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: _comics.length,
                itemBuilder: (ctx, i) => _ComicCard(comic: _comics[i], onAuthorTap: widget.onAuthorTap),
              ),
            ),
    );
  }
}

class _ComicCard extends StatelessWidget {
  final Comic comic;
  final void Function(String)? onAuthorTap;
  const _ComicCard({required this.comic, this.onAuthorTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      elevation: 2,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => DetailScreen(comicId: comic.id, onAuthorTap: onAuthorTap)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 3 / 4,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  comic.coverUrl != null
                      ? Image.network(
                          comic.coverUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stack) => _placeholder(),
                        )
                      : _placeholder(),
                  Positioned(
                    right: 4,
                    bottom: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${comic.chapterCount}话 · ${comic.imageCount}P',
                        style: const TextStyle(color: Colors.white, fontSize: 10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 5, 6, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    comic.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Color(0xFF1a1a1a), fontSize: 12),
                  ),
                  if (comic.author != null)
                    Text(
                      comic.author!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Color(0xFF888888), fontSize: 11),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
        color: const Color(0xFF21262d),
        child: const Icon(Icons.image_not_supported, color: Color(0xFF8b949e)),
      );
}
