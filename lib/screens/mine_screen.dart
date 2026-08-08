import 'package:flutter/material.dart';
import '../models/comic.dart';
import '../models/reading_progress_entry.dart';
import '../services/api.dart';
import 'detail_screen.dart';
import 'reader_screen.dart';

class MineScreen extends StatelessWidget {
  const MineScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFF0d1117),
        appBar: AppBar(
          backgroundColor: const Color(0xFF161b22),
          title: const Text('我的', style: TextStyle(color: Colors.white)),
          bottom: const TabBar(
            indicatorColor: Color(0xFF58a6ff),
            labelColor: Color(0xFF58a6ff),
            unselectedLabelColor: Color(0xFF8b949e),
            tabs: [
              Tab(text: '最近阅读'),
              Tab(text: '收藏'),
            ],
          ),
        ),
        body: const TabBarView(children: [_RecentList(), _FavoritesList()]),
      ),
    );
  }
}

class _RecentList extends StatefulWidget {
  const _RecentList();

  @override
  State<_RecentList> createState() => _RecentListState();
}

class _RecentListState extends State<_RecentList> {
  List<ReadingProgressEntry> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await ApiService.getRecent();
      if (mounted) setState(() => _items = list);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: _loading && _items.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
          ? ListView(
              children: const [
                SizedBox(height: 120),
                Center(
                  child: Text(
                    '暂无最近阅读',
                    style: TextStyle(color: Color(0xFF8b949e)),
                  ),
                ),
              ],
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _items.length,
              separatorBuilder: (_, _) => const Divider(
                color: Color(0xFF21262d),
                height: 1,
                indent: 76,
              ),
              itemBuilder: (ctx, i) {
                final e = _items[i];
                return _EntryTile(
                  coverUrl: e.comic.coverUrl,
                  title: e.comic.title,
                  author: e.comic.author,
                  subtitle: '${e.chapterTitle} · 第${e.pageNumber + 1}页',
                  onTap: () async {
                    await Navigator.push(
                      ctx,
                      MaterialPageRoute(
                        builder: (_) => ReaderScreen(
                          comicId: e.comic.id,
                          chapterId: e.chapterId,
                          title: e.chapterTitle,
                          initialPage: e.pageNumber,
                        ),
                      ),
                    );
                    _load();
                  },
                );
              },
            ),
    );
  }
}

class _FavoritesList extends StatefulWidget {
  const _FavoritesList();

  @override
  State<_FavoritesList> createState() => _FavoritesListState();
}

class _FavoritesListState extends State<_FavoritesList> {
  List<Comic> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await ApiService.getFavorites();
      if (mounted) setState(() => _items = list);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: _loading && _items.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
          ? ListView(
              children: const [
                SizedBox(height: 120),
                Center(
                  child: Text(
                    '暂无收藏',
                    style: TextStyle(color: Color(0xFF8b949e)),
                  ),
                ),
              ],
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _items.length,
              separatorBuilder: (_, _) => const Divider(
                color: Color(0xFF21262d),
                height: 1,
                indent: 76,
              ),
              itemBuilder: (ctx, i) {
                final comic = _items[i];
                return _EntryTile(
                  coverUrl: comic.coverUrl,
                  title: comic.title,
                  author: comic.author,
                  subtitle: '${comic.chapterCount}话 · ${comic.imageCount}P',
                  onTap: () async {
                    await Navigator.push(
                      ctx,
                      MaterialPageRoute(
                        builder: (_) => DetailScreen(comicId: comic.id),
                      ),
                    );
                    _load();
                  },
                );
              },
            ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  final String? coverUrl;
  final String title;
  final String? author;
  final String subtitle;
  final VoidCallback onTap;

  const _EntryTile({
    required this.coverUrl,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.author,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: SizedBox(
          width: 52,
          height: 68,
          child: coverUrl != null
              ? Image.network(
                  coverUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => _placeholder(),
                )
              : _placeholder(),
        ),
      ),
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Colors.white, fontSize: 14),
      ),
      subtitle: Text(
        author != null ? '$subtitle · $author' : subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Color(0xFF8b949e), fontSize: 12),
      ),
      trailing: const Icon(Icons.chevron_right, color: Color(0xFF8b949e)),
    );
  }

  Widget _placeholder() => Container(
    color: const Color(0xFF21262d),
    child: const Icon(Icons.image_not_supported, color: Color(0xFF8b949e)),
  );
}
