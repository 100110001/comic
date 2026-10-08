import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/comic.dart';
import '../models/reading_progress_entry.dart';
import '../platform.dart';
import '../providers/comics_providers.dart';
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

  @override
  void initState() {
    super.initState();
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

  void searchAuthor(String author) {
    _searchController.text = author;
    _search(author);
  }

  Future<void> _search(String keyword) async {
    _keyword = keyword.trim();
    setState(() {});
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
    final recentAsync = ref.watch(recentReadingProvider);

    final random = randomAsync.value;
    final search = searchAsync.value;
    final recent = recentAsync.value;
    final recentEntry = (recent != null && recent.isNotEmpty)
        ? recent.first
        : null;

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
        title: desktop
            ? Container(
                constraints: const BoxConstraints(maxWidth: 420),
                decoration: BoxDecoration(
                  color: c.surface2,
                  borderRadius: BorderRadius.circular(kRadiusButton),
                  border: Border.all(color: c.border),
                ),
                child: TextField(
                  controller: _searchController,
                  style: TextStyle(color: c.text1, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: '搜索漫画、作者…',
                    hintStyle: TextStyle(color: c.text2),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    prefixIcon: Icon(Icons.search, color: c.text2, size: 20),
                    suffixIcon: _keyword.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.close, color: c.text2, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              _search('');
                            },
                          )
                        : null,
                  ),
                  onSubmitted: _search,
                ),
              )
            : const Text('Comic'),
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
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: SizedBox(height: 1, child: ColoredBox(color: c.borderStrong)),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: Stack(
          children: [
            Column(
              children: [
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
                              : () => _search(_keyword),
                        )
                      : ComicGrid(
                          controller: _scrollController,
                          comics: comics,
                          loading: loading,
                          bottomPadding: recentEntry != null ? 96 : 0,
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
            if (recentEntry != null)
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: _FloatingContinueBar(
                  entry: recentEntry,
                  onReturn: () => ref.invalidate(recentReadingProvider),
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
      color: c.surface2,
      elevation: 4,
      clipBehavior: Clip.antiAlias,
      shadowColor: Colors.black.withValues(alpha: 0.4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kRadiusFloat),
        side: BorderSide(color: c.border),
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
          padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(kRadiusThumb),
                child: SizedBox(
                  width: 44,
                  height: 60,
                  child: comic.coverUrl != null
                      ? Image.network(
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
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${entry.chapterTitle} · 第${entry.pageNumber + 1}页',
                      style: TextStyle(color: c.text2, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Icon(Icons.play_circle_fill, color: c.accent, size: 32),
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
