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
  final _scrollController = ScrollController();

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
    super.dispose();
  }

  Future<void> _loadMore() async {
    if (_loading || _comics.length >= _total && _total > 0) return;
    setState(() => _loading = true);
    try {
      final r = await ApiService.getComics(pageOffset: _pageOffset, pageSize: 30);
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
        title: const Text('漫画库', style: TextStyle(color: Colors.white)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFF21262d)),
        ),
      ),
      body: GridView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 180,
          childAspectRatio: 0.65,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemCount: _comics.length + (_loading ? 1 : 0),
        itemBuilder: (ctx, i) {
          if (i == _comics.length) {
            return const Center(child: CircularProgressIndicator());
          }
          return _ComicCard(comic: _comics[i]);
        },
      ),
    );
  }
}

class _ComicCard extends StatelessWidget {
  final Comic comic;
  const _ComicCard({required this.comic});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => DetailScreen(comicId: comic.id)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: comic.coverUrl != null
                  ? Image.network(
                      comic.coverUrl!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      errorBuilder: (_, __, ___) => _placeholder(),
                    )
                  : _placeholder(),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            comic.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
          if (comic.author != null)
            Text(
              comic.author!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFF8b949e), fontSize: 11),
            ),
        ],
      ),
    );
  }

  Widget _placeholder() => Container(
        color: const Color(0xFF21262d),
        child: const Icon(Icons.image_not_supported, color: Color(0xFF8b949e)),
      );
}
