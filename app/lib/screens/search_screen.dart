import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/comic.dart';
import '../providers/comics_providers.dart';
import '../providers/search_history_provider.dart';
import '../providers/server_provider.dart';
import '../widgets/search_history_view.dart';
import '../theme.dart';
import '../utils/user_error.dart';
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
  bool _showHistory = true;
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    ref.listenManual(serverSessionProvider, (_, _) {
      _controller.clear();
      setState(() => _showHistory = true);
    });
    final initial = widget.initialKeyword?.trim() ?? '';
    _showHistory = initial.isEmpty;
    _controller.text = initial;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _search(initial, remember: initial.isNotEmpty);
    });
    _scrollController.addListener(() {
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

  void _chooseKeyword(String keyword) {
    if (!mounted) return;
    _controller.text = keyword;
    _controller.selection = TextSelection.collapsed(offset: keyword.length);
    _search(keyword);
  }

  Future<void> _search(String keyword, {bool remember = true}) async {
    final word = keyword.trim();
    setState(() => _showHistory = word.isEmpty);
    if (remember && word.isNotEmpty) {
      final source = ref.read(serverSessionProvider).url;
      unawaited(
        ref
            .read(searchHistoryStoreProvider.notifier)
            .remember(source, word)
            .catchError((Object error) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      userMessageFor(error, fallback: '搜索历史保存失败，搜索仍可继续'),
                    ),
                  ),
                );
              }
            }),
      );
    }
    try {
      await ref.read(searchProvider.notifier).search(word);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(userMessageFor(error, fallback: '搜索失败，请重试'))),
      );
    }
  }

  Future<void> _loadMore() async {
    try {
      await ref.read(searchProvider.notifier).loadMore();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(userMessageFor(error, fallback: '加载更多失败，请重试')),
          action: SnackBarAction(label: '重试', onPressed: _loadMore),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final searchAsync = ref.watch(searchProvider);
    final state = searchAsync.value;
    final comics = state?.comics ?? const <Comic>[];
    final keyword = state?.keyword ?? '';
    final hasError = searchAsync.hasError || state?.error != null;
    final loading =
        (searchAsync.isLoading || (state?.isRefreshing ?? false)) &&
        comics.isEmpty;
    final c = context.appColors;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 8,
        actions: [
          IconButton(
            tooltip: '清空搜索',
            icon: const Icon(Icons.close),
            onPressed: () {
              _controller.clear();
              _search('', remember: false);
            },
          ),
          IconButton(
            tooltip: '搜索历史',
            icon: const Icon(Icons.history),
            onPressed: () =>
                showSearchHistory(context, onSelected: _chooseKeyword),
          ),
        ],
        title: TextField(
          controller: _controller,
          autofocus: true,
          style: TextStyle(color: c.text1, fontSize: 14),
          decoration: InputDecoration(
            hintText: '搜索漫画、作者…',
            hintStyle: TextStyle(color: c.text2),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 12,
            ),
            isDense: true,
            prefixIcon: Icon(Icons.search, color: c.text2, size: 20),
          ),
          onSubmitted: _search,
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 20, 28, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _showHistory ? '搜索' : '搜索结果',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  _showHistory
                      ? '找到下一本想读的漫画'
                      : '「$keyword」 · ${state?.total ?? 0} 本漫画',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Expanded(
            child: _showHistory
                ? SearchHistoryView(onSelected: _chooseKeyword)
                : RefreshIndicator(
                    onRefresh: () => _search(keyword, remember: false),
                    child: hasError && comics.isEmpty
                        ? StatusView(
                            icon: Icons.cloud_off,
                            message: userMessageFor(
                              searchAsync.error ?? state?.error,
                              fallback: '搜索失败',
                            ),
                            actionLabel: '重试',
                            onAction: () => _search(keyword, remember: false),
                          )
                        : loading
                        ? const Center(child: CircularProgressIndicator())
                        : comics.isEmpty
                        ? const EmptyListView(message: '没有找到相关漫画')
                        : ComicGrid(
                            controller: _scrollController,
                            comics: comics,
                            loading:
                                searchAsync.isLoading ||
                                (state?.isRefreshing ?? false) ||
                                (state?.isLoadingMore ?? false),
                            onTap: (comic) => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => DetailScreen(comicId: comic.id),
                              ),
                            ),
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}
