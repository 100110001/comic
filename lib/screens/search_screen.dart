import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/comic.dart';
import '../providers/comics_providers.dart';
import '../theme.dart';
import '../widgets/comic_grid.dart';
import '../widgets/status_views.dart';
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
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          style: const TextStyle(color: kText1, fontSize: 14),
          decoration: const InputDecoration(
            hintText: '搜索漫画、作者…',
            hintStyle: TextStyle(color: kText2),
            border: InputBorder.none,
            isDense: true,
            prefixIcon: Icon(Icons.search, color: kText2, size: 20),
          ),
          onSubmitted: _search,
        ),
      ),
      body: keyword.isEmpty
          ? const StatusView(icon: Icons.search, message: '输入关键字搜索漫画或作者')
          : RefreshIndicator(
              onRefresh: () => _search(keyword),
              child: hasError && comics.isEmpty
                  ? StatusView(
                      icon: Icons.cloud_off,
                      message: '搜索失败',
                      actionLabel: '重试',
                      onAction: () => ref.invalidate(searchProvider),
                    )
                  : loading
                  ? const Center(child: CircularProgressIndicator())
                  : comics.isEmpty
                  ? const EmptyListView(message: '没有找到相关漫画')
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
