import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/comic.dart';
import '../models/reading_progress_entry.dart';
import '../platform.dart';
import '../providers/comics_providers.dart';
import '../widgets/comic_grid.dart';
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
  bool _recentBarVisible = false;
  ReadingProgressEntry? _lastRecentEntry;
  Timer? _barHideTimer;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        if (_keyword.isEmpty) {
          ref.read(randomLibraryProvider.notifier).loadMore();
        } else {
          ref.read(searchProvider.notifier).loadMore();
        }
      }
    });
    // 首帧后按实际列数校准页大小
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final width = MediaQuery.of(context).size.width;
      ref
          .read(randomLibraryProvider.notifier)
          .setPageSize(comicGridColumns(width) * 6);
    });
  }

  @override
  void dispose() {
    _barHideTimer?.cancel();
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
    if (_keyword.isNotEmpty) {
      await ref.read(searchProvider.notifier).search(_keyword);
    }
  }

  Future<void> _refresh() async {
    if (_keyword.isEmpty) {
      await ref.read(randomLibraryProvider.notifier).reshuffle();
    } else {
      await ref.read(searchProvider.notifier).search(_keyword);
    }
    ref.invalidate(recentReadingProvider);
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
    // A fresh reading entry re-shows the bar; it auto-hides after 3 seconds.
    if (recentEntry != null && recentEntry != _lastRecentEntry) {
      _lastRecentEntry = recentEntry;
      _recentBarVisible = true;
      _barHideTimer?.cancel();
      _barHideTimer = Timer(const Duration(seconds: 3), () {
        if (mounted && _recentBarVisible) {
          setState(() => _recentBarVisible = false);
        }
      });
    }

    final comics = _keyword.isEmpty
        ? (random?.comics ?? const <Comic>[])
        : (search?.comics ?? const <Comic>[]);
    final hasError = _keyword.isEmpty
        ? randomAsync.hasError
        : searchAsync.hasError;
    final loading = _keyword.isEmpty
        ? randomAsync.isLoading ||
              (random != null && random.comics.length < random.total)
        : searchAsync.isLoading && search?.comics.isEmpty == true;

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
                  child: hasError && comics.isEmpty
                      ? _ErrorRetry(
                          onRetry: _keyword.isEmpty
                              ? () => ref.invalidate(randomLibraryProvider)
                              : () => _search(_keyword),
                        )
                      : ComicGrid(
                          controller: _scrollController,
                          comics: comics,
                          loading: loading,
                          bottomPadding: _recentBarVisible ? 96 : 0,
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
                child: IgnorePointer(
                  ignoring: !_recentBarVisible,
                  child: AnimatedSlide(
                    offset: _recentBarVisible
                        ? Offset.zero
                        : const Offset(0, 1.2),
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    child: AnimatedOpacity(
                      opacity: _recentBarVisible ? 1 : 0,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                      child: _FloatingContinueBar(
                        entry: recentEntry,
                        onReturn: () =>
                            ref.invalidate(recentReadingProvider),
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

class _ErrorRetry extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorRetry({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off, color: Color(0xFF8b949e), size: 48),
          const SizedBox(height: 12),
          const Text('加载失败', style: TextStyle(color: Color(0xFF8b949e))),
          const SizedBox(height: 12),
          FilledButton.tonal(onPressed: onRetry, child: const Text('重试')),
        ],
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
          onReturn();
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
