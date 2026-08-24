import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/comic.dart';
import '../providers/comics_providers.dart';
import '../providers/discovery_providers.dart';
import '../theme.dart';
import '../widgets/status_views.dart';
import 'reader_screen.dart';

/// 发现：随机阅读入口。一次展示一本漫画，拖拽（触摸滑动/鼠标按住拖动）
/// 左右切换，点击卡片直接进入阅读器；序列位置与发现会话阅读器共享。
class DiscoveryScreen extends ConsumerStatefulWidget {
  const DiscoveryScreen({super.key});

  @override
  ConsumerState<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends ConsumerState<DiscoveryScreen> {
  double _dragX = 0;
  bool _dragging = false;
  bool _slideFromLeft = false;

  double _threshold(double width) => (width * 0.15).clamp(48.0, 120.0);

  Future<void> _switchTo(
    Future<Comic?> Function() action, {
    required bool next,
  }) async {
    setState(() {
      _slideFromLeft = next;
      _dragging = false;
    });
    try {
      await action();
      if (!mounted) return;
      setState(() => _dragX = 0);
    } catch (_) {
      if (!mounted) return;
      setState(() => _dragX = 0);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('切换失败，请重试')));
    }
  }

  void _handleDragEnd() {
    final threshold = _threshold(MediaQuery.of(context).size.width);
    if (_dragX <= -threshold) {
      _switchTo(() => ref.read(discoveryProvider.notifier).next(), next: true);
    } else if (_dragX >= threshold) {
      _switchTo(() => ref.read(discoveryProvider.notifier).prev(), next: false);
    } else {
      setState(() {
        _dragging = false;
        _dragX = 0;
      });
    }
  }

  Future<void> _refresh() async {
    try {
      await ref.read(discoveryProvider.notifier).refresh();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('换一批失败，请重试')));
    }
  }

  Future<void> _openReader(Comic comic) async {
    try {
      final detail = await ref.read(comicDetailProvider(comic.id).future);
      if (!mounted) return;
      if (detail.chapters.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('暂无章节')));
        return;
      }
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ReaderScreen(
            comicId: comic.id,
            chapterId: detail.chapters.first.id,
            title: comic.title,
            onNextComic: () => ref.read(discoveryProvider.notifier).next(),
            onPrevComic: () => ref.read(discoveryProvider.notifier).prev(),
            canPrevComic: () =>
                ref.read(discoveryProvider).value?.canGoPrev ?? false,
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('加载失败，请重试')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(discoveryProvider);
    final state = async.value;
    final comic = state?.current;
    final c = context.appColors;

    final Widget body;
    if (async.isLoading && comic == null) {
      body = const Center(child: CircularProgressIndicator());
    } else if (async.hasError && comic == null) {
      body = StatusView(
        icon: Icons.cloud_off,
        message: '加载失败',
        actionLabel: '重试',
        onAction: () => ref.invalidate(discoveryProvider),
      );
    } else if (comic == null) {
      body = const StatusView(icon: Icons.menu_book_outlined, message: '书库为空');
    } else {
      final s = state!;
      body = Column(
        children: [
          Expanded(
            child: Center(
              child: AnimatedContainer(
                duration: _dragging
                    ? Duration.zero
                    : const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                transform: Matrix4.translationValues(_dragX, 0, 0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildFan(
                      comic,
                      s.prev,
                      s.next,
                      _coverWidth(MediaQuery.of(context).size.width),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      comic.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: c.text1,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (comic.author != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        comic.author!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: c.text2, fontSize: 13),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      '${comic.chapterCount}话 · ${comic.imageCount}P',
                      style: TextStyle(color: c.accent, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Text(
            '序列第 ${s.index + 1} / ${s.total} 本',
            style: TextStyle(color: c.text2, fontSize: 12),
          ),
          const SizedBox(height: 6),
          Text('拖拽切换 · 点击阅读', style: TextStyle(color: c.text2, fontSize: 12)),
          const SizedBox(height: 24),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('发现'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: c.text2),
            tooltip: '换一批',
            onPressed: _refresh,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: SizedBox(height: 1, child: ColoredBox(color: c.borderStrong)),
        ),
      ),
      body: body,
    );
  }

  double _coverWidth(double width) =>
      width > 720 ? 300.0 : (width - 150).clamp(170.0, 300.0).toDouble();

  /// 鸡爪结构：中间当前本大卡，左右两侧露出上一本/下一本的封面小卡并向外倾斜。
  Widget _buildFan(Comic comic, Comic? prev, Comic? next, double coverWidth) {
    final sideW = coverWidth * 0.52;
    final sideH = sideW * 4 / 3;
    final coverH = coverWidth * 4 / 3;
    return SizedBox(
      width: coverWidth * 1.7,
      height: coverH + 16,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          if (prev != null)
            Positioned(
              left: coverWidth * 0.2,
              top: (coverH - sideH) / 2 + 10,
              child: GestureDetector(
                onTap: () => _switchTo(
                  () => ref.read(discoveryProvider.notifier).prev(),
                  next: false,
                ),
                child: Transform.rotate(
                  angle: -0.14,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: KeyedSubtree(
                      key: ValueKey('prev-${prev.id}'),
                      child: _miniCover(prev, sideW, sideH),
                    ),
                  ),
                ),
              ),
            ),
          if (next != null)
            Positioned(
              right: coverWidth * 0.2,
              top: (coverH - sideH) / 2 + 10,
              child: GestureDetector(
                onTap: () => _switchTo(
                  () => ref.read(discoveryProvider.notifier).next(),
                  next: true,
                ),
                child: Transform.rotate(
                  angle: 0.14,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: KeyedSubtree(
                      key: ValueKey('next-${next.id}'),
                      child: _miniCover(next, sideW, sideH),
                    ),
                  ),
                ),
              ),
            ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragStart: (_) => setState(() => _dragging = true),
            onHorizontalDragUpdate: (d) => setState(() => _dragX += d.delta.dx),
            onHorizontalDragEnd: (_) => _handleDragEnd(),
            onTap: () => _openReader(comic),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              transitionBuilder: (child, anim) => SlideTransition(
                position: Tween<Offset>(
                  begin: _slideFromLeft
                      ? const Offset(1, 0)
                      : const Offset(-1, 0),
                  end: Offset.zero,
                ).animate(anim),
                child: child,
              ),
              child: KeyedSubtree(
                key: ValueKey('current-${comic.id}'),
                child: _mainCover(comic, coverWidth),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _mainCover(Comic comic, double coverWidth) {
    final c = context.appColors;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(kRadiusFloat),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(kRadiusFloat),
        child: Container(
          width: coverWidth,
          height: coverWidth * 4 / 3,
          color: c.surface2,
          child: comic.coverUrl != null
              ? Image.network(
                  comic.coverUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => _placeholder(),
                )
              : _placeholder(),
        ),
      ),
    );
  }

  Widget _miniCover(Comic comic, double width, double height) {
    final c = context.appColors;
    return Opacity(
      opacity: 0.6,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(kRadiusThumb),
        child: Container(
          width: width,
          height: height,
          color: c.surface2,
          child: comic.coverUrl != null
              ? Image.network(
                  comic.coverUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => _placeholder(),
                )
              : _placeholder(),
        ),
      ),
    );
  }

  Widget _placeholder() {
    final c = context.appColors;
    return Container(
      color: c.surface2,
      child: Icon(Icons.image_not_supported, color: c.text2),
    );
  }
}
