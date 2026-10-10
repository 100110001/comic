import 'dart:async';

import 'package:flutter/material.dart';
import '../widgets/display_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/comic.dart';
import '../models/reading_progress_entry.dart';
import '../platform.dart';
import '../providers/comics_providers.dart';
import '../providers/reading_progress_provider.dart';
import '../providers/search_history_provider.dart';
import '../providers/server_provider.dart';
import '../widgets/search_history_view.dart';
import '../theme.dart';
import '../utils/user_error.dart';
import '../widgets/comic_grid.dart';
import '../widgets/status_views.dart';
import 'detail_screen.dart';
import 'reader_screen.dart';
import 'search_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends ConsumerState<HomeScreen> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  String _keyword = '';
  Timer? _continueTimer;
  (int, int, int)? _continuePosition;
  bool _continueVisible = false;

  @override
  void initState() {
    super.initState();
    ref.listenManual(serverSessionProvider, (_, _) {
      _searchController.clear();
      setState(() => _keyword = '');
    });
    ref.listenManual(recentReadingWithLocalProvider, (_, next) {
      final entries = next.value;
      final entry = entries != null && entries.isNotEmpty
          ? entries.first
          : null;
      final position = entry == null
          ? null
          : (entry.comic.id, entry.chapterId, entry.pageNumber);
      if (position == _continuePosition) return;
      _continueTimer?.cancel();
      setState(() {
        _continuePosition = position;
        _continueVisible = position != null;
      });
      if (_continueVisible) {
        _continueTimer = Timer(const Duration(seconds: 5), () {
          if (mounted) setState(() => _continueVisible = false);
        });
      }
    }, fireImmediately: true);
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        _loadMore();
      }
    });
  }

  @override
  void dispose() {
    _continueTimer?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void searchAuthor(String author) {
    _searchController.text = author;
    _search(author);
  }

  void _chooseKeyword(String keyword) {
    if (!mounted) return;
    _searchController.text = keyword;
    _searchController.selection = TextSelection.collapsed(
      offset: keyword.length,
    );
    _search(keyword);
  }

  Future<void> _search(String keyword, {bool remember = true}) async {
    _keyword = keyword.trim();
    setState(() {});
    if (remember && _keyword.isNotEmpty) {
      final source = ref.read(serverSessionProvider).url;
      unawaited(
        ref
            .read(searchHistoryStoreProvider.notifier)
            .remember(source, _keyword)
            .catchError((Object error) {
              if (mounted) _showRequestError(error, '搜索历史保存失败，搜索仍可继续');
            }),
      );
    }
    try {
      await ref.read(searchProvider.notifier).search(_keyword);
    } catch (error) {
      if (mounted) _showRequestError(error, '搜索失败');
    }
  }

  Future<void> _loadMore() async {
    try {
      if (_keyword.isEmpty) {
        await ref.read(randomLibraryProvider.notifier).loadMore();
      } else {
        await ref.read(searchProvider.notifier).loadMore();
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(userMessageFor(error, fallback: '加载更多失败，请重试')),
            action: SnackBarAction(label: '重试', onPressed: _loadMore),
          ),
        );
      }
    }
  }

  Future<void> _refresh() async {
    try {
      if (_keyword.isEmpty) {
        await ref.read(randomLibraryProvider.notifier).reshuffle();
      } else {
        await ref.read(searchProvider.notifier).search(_keyword);
      }
      ref.invalidate(recentReadingProvider);
    } catch (error) {
      if (mounted) _showRequestError(error, '刷新失败');
    }
  }

  void _showRequestError(Object error, String fallback) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(userMessageFor(error, fallback: fallback))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final desktop = isDesktopAt(MediaQuery.of(context).size.width);
    final randomAsync = ref.watch(randomLibraryProvider);
    final searchAsync = ref.watch(searchProvider);
    final recentAsync = ref.watch(recentReadingWithLocalProvider);

    final random = randomAsync.value;
    final search = searchAsync.value;
    final recent = recentAsync.value;
    final recentEntry = (recent != null && recent.isNotEmpty)
        ? recent.first
        : null;
    final textScaler = MediaQuery.textScalerOf(context);
    final showContinue = _continueVisible && recentEntry != null;
    final continueBottomPadding = !showContinue
        ? 0.0
        : (textScaler.scale(12) * 3 + textScaler.scale(15) * 1.5 + 46)
              .clamp(112.0, double.infinity)
              .toDouble();

    final comics = _keyword.isEmpty
        ? (random?.comics ?? const <Comic>[])
        : (search?.comics ?? const <Comic>[]);
    final hasError = _keyword.isEmpty
        ? randomAsync.hasError || random?.error != null
        : searchAsync.hasError || search?.error != null;
    final currentError = _keyword.isEmpty
        ? randomAsync.error ?? random?.error
        : searchAsync.error ?? search?.error;
    final loading = _keyword.isEmpty
        ? randomAsync.isLoading ||
              (random?.isLoadingMore ?? false) ||
              (random?.isRefreshing ?? false)
        : searchAsync.isLoading ||
              (search?.isLoadingMore ?? false) ||
              (search?.isRefreshing ?? false);
    final c = context.appColors;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: desktop ? 76 : 64,
        titleSpacing: desktop ? 28 : 16,
        title: desktop
            ? Align(
                alignment: Alignment.centerRight,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 420),
                  decoration: BoxDecoration(
                    color: c.surface1,
                    borderRadius: BorderRadius.circular(kRadiusButton),
                    border: Border.all(color: c.border),
                  ),
                  child: TextField(
                    controller: _searchController,
                    style: TextStyle(color: c.text1, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: '搜索漫画、作者…',
                      hintStyle: TextStyle(color: c.text2),
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      prefixIcon: Icon(Icons.search, color: c.text2, size: 20),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: '搜索历史',
                            icon: Icon(Icons.history, color: c.text2, size: 20),
                            onPressed: () => showSearchHistory(
                              context,
                              onSelected: _chooseKeyword,
                            ),
                          ),
                          if (_keyword.isNotEmpty)
                            IconButton(
                              tooltip: '清空搜索',
                              icon: Icon(Icons.close, color: c.text2, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                _search('');
                              },
                            ),
                          IconButton(
                            tooltip: '搜索',
                            icon: Icon(
                              Icons.arrow_forward,
                              color: c.accent,
                              size: 20,
                            ),
                            onPressed: () => _search(_searchController.text),
                          ),
                        ],
                      ),
                    ),
                    onSubmitted: _search,
                  ),
                ),
              )
            : const Text('漫画书库'),
        actions: desktop
            ? null
            : [
                IconButton(
                  icon: Icon(Icons.search, color: c.text2),
                  tooltip: '搜索',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SearchScreen()),
                  ),
                ),
              ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: Stack(
          children: [
            Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    desktop ? 28 : 16,
                    4,
                    desktop ? 28 : 16,
                    16,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _keyword.isEmpty ? '随便看看' : '搜索结果',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _keyword.isEmpty
                                  ? random == null
                                        ? '发现下一本想读的漫画'
                                        : '${random.total} 部漫画 · 发现下一本想读的故事'
                                  : '“$_keyword” · ${search?.total ?? 0} 部漫画',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: c.text2, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: loading ? null : _refresh,
                        icon: Icon(
                          _keyword.isEmpty
                              ? Icons.shuffle_rounded
                              : Icons.refresh,
                          size: 18,
                        ),
                        label: Text(_keyword.isEmpty ? '换一批' : '刷新结果'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: hasError && comics.isEmpty
                      ? StatusView(
                          icon: Icons.cloud_off,
                          message: userMessageFor(
                            currentError,
                            fallback: '加载失败',
                          ),
                          actionLabel: '重试',
                          onAction: _keyword.isEmpty
                              ? () => ref.invalidate(randomLibraryProvider)
                              : () => _search(_keyword, remember: false),
                        )
                      : ComicGrid(
                          controller: _scrollController,
                          comics: comics,
                          loading: loading,
                          bottomPadding: continueBottomPadding,
                          emptyMessage: _keyword.isEmpty
                              ? '书库里还没有漫画'
                              : '没有找到相关漫画',
                          onColumnsChanged: (columns) => ref
                              .read(randomLibraryProvider.notifier)
                              .setPageSize(columns * 6),
                          onTap: (comic) => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DetailScreen(comicId: comic.id),
                            ),
                          ),
                        ),
                ),
              ],
            ),
            if (showContinue)
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: _FloatingContinueBar(
                      entry: recentEntry,
                      onReturn: () {
                        if (mounted) ref.invalidate(recentReadingProvider);
                      },
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

class _FloatingContinueBar extends StatelessWidget {
  final ReadingProgressEntry entry;
  final VoidCallback onReturn;
  const _FloatingContinueBar({required this.entry, required this.onReturn});

  @override
  Widget build(BuildContext context) {
    final comic = entry.comic;
    final c = context.appColors;
    return Material(
      color: c.surface1,
      elevation: 4,
      clipBehavior: Clip.antiAlias,
      shadowColor: Colors.black.withValues(alpha: 0.18),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kRadiusFloat),
      ),
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
          onReturn();
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 16, 12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(kRadiusThumb),
                child: SizedBox(
                  width: 44,
                  height: 60,
                  child: comic.coverUrl != null
                      ? DisplayNetworkImage(
                          comic.coverUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => _placeholder(context),
                        )
                      : _placeholder(context),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '继续阅读',
                      style: TextStyle(color: c.accent, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      comic.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: c.text1,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${entry.chapterTitle} · 第${entry.pageNumber + 1}页',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: c.text2, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(Icons.play_circle_fill, color: c.accent, size: 36),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholder(BuildContext context) {
    final c = context.appColors;
    return Container(
      color: c.surface2,
      child: Icon(Icons.image_not_supported, color: c.text2),
    );
  }
}
