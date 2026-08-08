import 'package:flutter/material.dart';
import '../models/comic.dart';
import '../services/api.dart';
import '../widgets/comic_grid.dart';
import 'detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final List<Comic> _comics = [];
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  String _keyword = '';
  int _pageOffset = 1;
  int _total = 0;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_keyword.isEmpty) return;
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        _loadMore();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _search(String keyword) async {
    _keyword = keyword.trim();
    setState(() {
      _comics.clear();
      _pageOffset = 1;
      _total = 0;
    });
    await _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loading || _keyword.isEmpty) return;
    if (_comics.length >= _total && _total > 0) return;
    setState(() => _loading = true);
    try {
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
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _syncFavorites() async {
    try {
      final favs = await ApiService.getFavorites();
      if (!mounted) return;
      final ids = favs.map((c) => c.id).toSet();
      final updated = List<Comic>.from(_comics);
      var changed = false;
      for (var i = 0; i < updated.length; i++) {
        final fav = ids.contains(updated[i].id);
        if (fav != updated[i].favorited) {
          updated[i] = updated[i].withFavorited(fav);
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
    return Scaffold(
      backgroundColor: const Color(0xFF0d1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161b22),
        iconTheme: const IconThemeData(color: Colors.white),
        title: TextField(
          controller: _controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: const InputDecoration(
            hintText: '搜索漫画、作者…',
            hintStyle: TextStyle(color: Color(0xFF8b949e)),
            border: InputBorder.none,
          ),
          onSubmitted: _search,
        ),
      ),
      body: _keyword.isEmpty
          ? const Center(
              child: Text(
                '输入关键字搜索漫画或作者',
                style: TextStyle(color: Color(0xFF8b949e)),
              ),
            )
          : RefreshIndicator(
              onRefresh: () => _search(_keyword),
              child: _loading && _comics.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : _comics.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 120),
                        Center(
                          child: Text(
                            '没有找到相关漫画',
                            style: TextStyle(color: Color(0xFF8b949e)),
                          ),
                        ),
                      ],
                    )
                  : ComicGrid(
                      controller: _scrollController,
                      comics: _comics,
                      loading: _loading,
                      onTap: (comic) async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => DetailScreen(comicId: comic.id),
                          ),
                        );
                        _syncFavorites();
                      },
                    ),
            ),
    );
  }
}
