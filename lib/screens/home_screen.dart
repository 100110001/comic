import 'dart:math';
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
  int _seed = 0;
  double _viewportWidth = 0;

  @override
  void initState() {
    super.initState();
    _seed = _newSeed();
    _loadGrid();
    _loadRecent();
    _scrollController.addListener(() {
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
    _seed = _newSeed();
    setState(() {
      _comics.clear();
      _pageOffset = 1;
      _total = 0;
    });
    await Future.wait([_loadGrid(), _loadRecent()]);
  }

  Future<void> _loadGrid() async {
    if (_loading) return;
    if (_comics.length >= _total && _total > 0) return;
    setState(() => _loading = true);
    try {
      if (_keyword.isEmpty) {
        // 随机模式：按种子分页加载，页大小 = 列数 × 6
        final columns = comicGridColumns(
          _viewportWidth > 0 ? _viewportWidth : 600,
        );
        final r = await ApiService.getRandomPage(
          seed: _seed,
          pageOffset: _pageOffset,
          pageSize: columns * 6,
        );
        if (!mounted) return;
        setState(() {
          _comics.addAll(r.list);
          _total = r.total;
          _pageOffset++;
        });
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

  int _newSeed() => Random().nextInt(1 << 31);

  Future<void> _refreshComicFavorited(int comicId) async {
    try {
      final r = await ApiService.getComic(comicId);
      if (!mounted) return;
      final updated = List<Comic>.from(_comics);
      var changed = false;
      for (var i = 0; i < updated.length; i++) {
        if (updated[i].id == comicId &&
            updated[i].favorited != r.comic.favorited) {
          updated[i] = updated[i].withFavorited(r.comic.favorited);
          changed = true;
        }
      }
      if (changed) {
        setState(
          () => _comics
            ..clear()
            ..addAll(updated),
        );
      }
    } catch (_) {
      // 同步失败不阻塞
    }
  }

  @override
  Widget build(BuildContext context) {
    _viewportWidth = MediaQuery.of(context).size.width;
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
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: _loading && _comics.isEmpty
                      ? const Center(child: CircularProgressIndicator())
                      : ComicGrid(
                          controller: _scrollController,
                          comics: _comics,
                          loading: _loading,
                          bottomPadding: _recent != null ? 96 : 0,
                          onTap: (comic) async {
                            await Navigator.push(
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
                            );
                            _refreshComicFavorited(comic.id);
                          },
                        ),
                ),
              ],
            ),
            if (_recent != null)
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: _FloatingContinueBar(
                  entry: _recent!,
                  onReturn: _refreshRecent,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FloatingContinueBar extends StatelessWidget {
  final ReadingProgressEntry entry;
  final Future<void> Function()? onReturn;
  const _FloatingContinueBar({required this.entry, this.onReturn});

  @override
  Widget build(BuildContext context) {
    final comic = entry.comic;
    return Material(
      color: const Color(0xFF1f2937),
      elevation: 6,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
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
          padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SizedBox(
                  width: 44,
                  height: 60,
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
