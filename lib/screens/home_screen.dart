import 'package:flutter/material.dart';
import '../models/comic.dart';
import '../services/api.dart';
import 'detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<Comic> _comics = [];
  int _pageOffset = 1;
  int _total = 0;
  bool _loading = false;
  String _keyword = '';
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadMore();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        _loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search(String keyword) async {
    _keyword = keyword;
    setState(() {
      _comics.clear();
      _pageOffset = 1;
      _total = 0;
    });
    await _loadMore();
  }

  Future<void> _refresh() async {
    setState(() {
      _comics.clear();
      _pageOffset = 1;
      _total = 0;
    });
    await _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loading || _comics.length >= _total && _total > 0) return;
    setState(() => _loading = true);
    try {
      final r = await ApiService.getComics(
        pageOffset: _pageOffset,
        pageSize: 30,
        keyword: _keyword,
      );
      setState(() {
        _comics.addAll(r.list);
        _total = r.total;
        _pageOffset++;
      });
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
        title: TextField(
          controller: _searchController,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: '搜索漫画、作者…',
            hintStyle: const TextStyle(color: Color(0xFF8b949e)),
            border: InputBorder.none,
            prefixIcon: const Icon(
              Icons.search,
              color: Color(0xFF8b949e),
              size: 20,
            ),
            suffixIcon: _keyword.isNotEmpty
                ? IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: Color(0xFF8b949e),
                      size: 18,
                    ),
                    onPressed: () {
                      _searchController.clear();
                      _search('');
                    },
                  )
                : null,
          ),
          onSubmitted: _search,
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFF21262d)),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: GridView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.all(12),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 160,
            childAspectRatio: 0.58,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: _comics.length + (_loading ? 1 : 0),
          itemBuilder: (ctx, i) {
            if (i == _comics.length) {
              return const Center(child: CircularProgressIndicator());
            }
            return _ComicCard(
              comic: _comics[i],
              onSearch: _search,
              searchController: _searchController,
            );
          },
        ),
      ),
    );
  }
}

class _ComicCard extends StatelessWidget {
  final Comic comic;
  final Future<void> Function(String) onSearch;
  final TextEditingController searchController;

  const _ComicCard({
    required this.comic,
    required this.onSearch,
    required this.searchController,
  });

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
          MaterialPageRoute(
            builder: (_) => DetailScreen(
              comicId: comic.id,
              onAuthorTap: (author) {
                searchController.text = author;
                onSearch(author);
              },
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 封面：固定 3:4 宽高比，撑满卡片宽度
            AspectRatio(
              aspectRatio: 3 / 4,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  comic.coverUrl != null
                      ? Image.network(
                          comic.coverUrl!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                          errorBuilder: (context, error, stack) =>
                              _placeholder(),
                        )
                      : _placeholder(),
                  Positioned(
                    right: 4,
                    bottom: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${comic.chapterCount}话 · ${comic.imageCount}P',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                        ),
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
                    style: const TextStyle(
                      color: Color(0xFF1a1a1a),
                      fontSize: 12,
                    ),
                  ),
                  if (comic.author != null)
                    Text(
                      comic.author!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF888888),
                        fontSize: 11,
                      ),
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
