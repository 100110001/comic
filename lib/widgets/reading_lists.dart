import 'package:flutter/material.dart';
import '../models/comic.dart';
import '../models/favorite_author.dart';
import '../models/reading_progress_entry.dart';
import '../services/api.dart';
import '../screens/detail_screen.dart';
import '../screens/search_screen.dart';

class RecentReadingList extends StatefulWidget {
  const RecentReadingList({super.key});

  @override
  State<RecentReadingList> createState() => _RecentReadingListState();
}

class _RecentReadingListState extends State<RecentReadingList> {
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
                        builder: (_) => DetailScreen(comicId: e.comic.id),
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

class FavoritesList extends StatefulWidget {
  const FavoritesList({super.key});

  @override
  State<FavoritesList> createState() => _FavoritesListState();
}

class FavoriteAuthorsList extends StatefulWidget {
  const FavoriteAuthorsList({super.key});

  @override
  State<FavoriteAuthorsList> createState() => FavoriteAuthorsListState();
}

class FavoriteAuthorsListState extends State<FavoriteAuthorsList> {
  List<FavoriteAuthor> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() async {
    try {
      final list = await ApiService.getFavoriteAuthors();
      if (mounted) setState(() => _items = list);
    } catch (_) {
      // 加载失败保持现状，下拉可重试
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: reload,
      child: _loading && _items.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
          ? ListView(
              children: const [
                SizedBox(height: 120),
                Center(
                  child: Text(
                    '暂无收藏作者',
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
                indent: 16,
              ),
              itemBuilder: (ctx, i) {
                final item = _items[i];
                return ListTile(
                  leading: const Icon(Icons.star, color: Color(0xFFf5c542)),
                  title: Text(
                    item.author,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  subtitle: Text(
                    '${item.comicCount} 部作品',
                    style: const TextStyle(
                      color: Color(0xFF8b949e),
                      fontSize: 12,
                    ),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: Color(0xFF8b949e),
                  ),
                  onTap: () async {
                    await Navigator.push(
                      ctx,
                      MaterialPageRoute(
                        builder: (_) =>
                            SearchScreen(initialKeyword: item.author),
                      ),
                    );
                    reload();
                  },
                );
              },
            ),
    );
  }
}

class _FavoritesListState extends State<FavoritesList> {
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
