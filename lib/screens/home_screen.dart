import 'package:flutter/material.dart';
import '../models/comic.dart';
import '../models/reading_progress_entry.dart';
import '../platform.dart';
import '../services/api.dart';
import '../widgets/comic_grid.dart';
import 'detail_screen.dart';
import 'reader_screen.dart';
import 'search_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  final List<Comic> _comics = [];
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  ReadingProgressEntry? _recent;
  String _keyword = '';
  int _pageOffset = 1;
  int _total = 0;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadGrid();
    _loadRecent();
    _scrollController.addListener(() {
      if (_keyword.isEmpty) return;
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        _loadGrid();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRecent() async {
    try {
      final list = await ApiService.getRecent();
      if (!mounted) return;
      setState(() => _recent = list.isNotEmpty ? list.first : null);
    } catch (_) {
      // 记录加载失败不阻塞首页
    }
  }

  Future<void> _refreshRecent() async {
    await Future.delayed(const Duration(milliseconds: 400));
    await _loadRecent();
  }

  void searchAuthor(String author) {
    _searchController.text = author;
    _search(author);
  }

  Future<void> _search(String keyword) async {
    _keyword = keyword.trim();
    setState(() {
      _comics.clear();
      _pageOffset = 1;
      _total = 0;
    });
    await _loadGrid();
  }

  Future<void> _refresh() async {
    setState(() {
      _comics.clear();
      _pageOffset = 1;
      _total = 0;
    });
    await Future.wait([_loadGrid(), _loadRecent()]);
  }

  Future<void> _loadGrid() async {
    if (_loading) return;
    if (_keyword.isNotEmpty && _comics.length >= _total && _total > 0) {
      return;
    }
    setState(() => _loading = true);
    try {
      if (_keyword.isEmpty) {
        // 随机模式：全量加载，刷新即重排
        final list = await ApiService.getRandomLibrary();
        if (!mounted) return;
        setState(
          () => _comics
            ..clear()
            ..addAll(list),
        );
      } else {
        final r = await ApiService.getComics(
          pageOffset: _pageOffset,
          pageSize: 30,
          keyword: _keyword,
        );
        if (!mounted) return;
        setState(() {
          _comics.addAll(r.list);
          _total = r.total;
          _pageOffset++;
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final desktop = isDesktopAt(MediaQuery.of(context).size.width);
    return Scaffold(
      backgroundColor: const Color(0xFF0d1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161b22),
        title: desktop
            ? TextField(
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
              )
            : const Text('漫画库', style: TextStyle(color: Colors.white)),
        actions: desktop
            ? null
            : [
                IconButton(
                  icon: const Icon(Icons.search, color: Color(0xFF8b949e)),
                  tooltip: '搜索',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SearchScreen()),
                  ),
                ),
              ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: SizedBox(
            height: 1,
            child: ColoredBox(color: Color(0xFF21262d)),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: Column(
          children: [
            if (_recent != null)
              _ContinueCard(entry: _recent!, onReturn: _refreshRecent),
            Expanded(
              child: _loading && _comics.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : ComicGrid(
                      controller: _scrollController,
                      comics: _comics,
                      loading: _loading,
                      onTap: (comic) => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DetailScreen(
                            comicId: comic.id,
                            onAuthorTap: (author) {
                              _searchController.text = author;
                              _search(author);
                            },
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContinueCard extends StatelessWidget {
  final ReadingProgressEntry entry;
  final Future<void> Function()? onReturn;
  const _ContinueCard({required this.entry, this.onReturn});

  @override
  Widget build(BuildContext context) {
    final comic = entry.comic;
    return Material(
      color: const Color(0xFF161b22),
      child: InkWell(
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ReaderScreen(
                comicId: comic.id,
                chapterId: entry.chapterId,
                title: entry.chapterTitle,
                initialPage: entry.pageNumber,
              ),
            ),
          );
          await onReturn?.call();
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SizedBox(
                  width: 52,
                  height: 70,
                  child: comic.coverUrl != null
                      ? Image.network(
                          comic.coverUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => _placeholder(),
                        )
                      : _placeholder(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '继续阅读',
                      style: TextStyle(color: Color(0xFF58a6ff), fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      comic.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${entry.chapterTitle} · 第${entry.pageNumber + 1}页',
                      style: const TextStyle(
                        color: Color(0xFF8b949e),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.play_circle_fill,
                color: Color(0xFF58a6ff),
                size: 32,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
    color: const Color(0xFF21262d),
    child: const Icon(Icons.image_not_supported, color: Color(0xFF8b949e)),
  );
}
