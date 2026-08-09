import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/comic.dart';
import '../providers/comics_providers.dart';
import '../widgets/comic_grid.dart';
import 'detail_screen.dart';

class SearchScreen extends ConsumerStatefulWidget {
  final String? initialKeyword;
  const SearchScreen({super.key, this.initialKeyword});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    final initial = widget.initialKeyword;
    if (initial != null && initial.isNotEmpty) {
      _controller.text = initial;
      ref.read(searchProvider.notifier).search(initial);
    }
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        ref.read(searchProvider.notifier).loadMore();
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
    await ref.read(searchProvider.notifier).search(keyword.trim());
  }

  @override
  Widget build(BuildContext context) {
    final searchAsync = ref.watch(searchProvider);
    final state = searchAsync.value;
    final comics = state?.comics ?? const <Comic>[];
    final keyword = state?.keyword ?? '';
    final hasError = searchAsync.hasError;
    final loading = searchAsync.isLoading && comics.isEmpty;

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
      body: keyword.isEmpty
          ? const Center(
              child: Text(
                '输入关键字搜索漫画或作者',
                style: TextStyle(color: Color(0xFF8b949e)),
              ),
            )
          : RefreshIndicator(
              onRefresh: () => _search(keyword),
              child: hasError && comics.isEmpty
                  ? _SearchError(onRetry: () => ref.invalidate(searchProvider))
                  : loading
                  ? const Center(child: CircularProgressIndicator())
                  : comics.isEmpty
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
                      comics: comics,
                      loading: searchAsync.isLoading,
                      onTap: (comic) => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DetailScreen(comicId: comic.id),
                        ),
                      ),
                    ),
            ),
    );
  }
}

class _SearchError extends StatelessWidget {
  final VoidCallback onRetry;
  const _SearchError({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off, color: Color(0xFF8b949e), size: 48),
          const SizedBox(height: 12),
          const Text('搜索失败', style: TextStyle(color: Color(0xFF8b949e))),
          const SizedBox(height: 12),
          FilledButton.tonal(onPressed: onRetry, child: const Text('重试')),
        ],
      ),
    );
  }
}
