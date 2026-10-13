import 'dart:async';
import 'package:flutter/material.dart';
import '../theme.dart';

/// 一组占位共用一个轻量呼吸动画，不参与数据加载。
class SkeletonPulse extends StatefulWidget {
  const SkeletonPulse({super.key, required this.child});
  final Widget child;

  @override
  State<SkeletonPulse> createState() => _SkeletonPulseState();
}

class _SkeletonPulseState extends State<SkeletonPulse>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    value: 1,
    duration: const Duration(milliseconds: 1000),
  );
  Timer? _delay;
  late final _opacity = Tween<double>(
    begin: 0.55,
    end: 1,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context) || !TickerMode.of(context)) {
      _delay?.cancel();
      _delay = null;
      _controller.stop();
      _controller.value = 1;
    } else if (!_controller.isAnimating && _delay == null) {
      // 快请求只显示静态占位，不强制延长等待。
      _delay = Timer(const Duration(milliseconds: 150), () {
        _delay = null;
        if (mounted) _controller.repeat(reverse: true);
      });
    }
  }

  @override
  void dispose() {
    _delay?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: FadeTransition(opacity: _opacity, child: widget.child),
  );
}

class SkeletonBlock extends StatelessWidget {
  const SkeletonBlock({super.key, this.width, this.height, this.radius = 8});
  final double? width;
  final double? height;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: context.appColors.surface2,
      borderRadius: BorderRadius.circular(radius),
    ),
  );
}

/// 首帧尚未解码时也显示占位；命中同步缓存或减少动画时直接呈现。
Widget imageFrame(
  BuildContext context,
  Widget child,
  int? frame,
  bool synchronous, {
  required Widget placeholder,
}) {
  if (frame == null) return placeholder;
  if (synchronous || MediaQuery.disableAnimationsOf(context)) return child;
  return TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: const Duration(milliseconds: 180),
    child: child,
    builder: (_, opacity, child) => Opacity(opacity: opacity, child: child),
  );
}

class ImageLoadingPlaceholder extends StatelessWidget {
  const ImageLoadingPlaceholder({
    super.key,
    this.progress,
    this.label = '正在加载图片',
  });
  final ImageChunkEvent? progress;
  final String label;

  @override
  Widget build(BuildContext context) {
    final total = progress?.expectedTotalBytes;
    final value = total != null && total > 0
        ? (progress!.cumulativeBytesLoaded / total).clamp(0.0, 1.0)
        : null;
    return Semantics(
      label: label,
      child: ColoredBox(
        color: context.appColors.readerBar,
        child: LayoutBuilder(
          builder: (context, constraints) => Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SkeletonPulse(
                    child: Icon(
                      Icons.auto_stories_outlined,
                      size: 32,
                      color: context.appColors.text2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: context.appColors.text2),
                  ),
                  if (value != null) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: 120,
                      child: LinearProgressIndicator(value: value),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 详情和发现的封面、信息占位；自然滚动适配窄屏与小窗口。
class ComicInfoSkeleton extends StatelessWidget {
  const ComicInfoSkeleton({super.key, this.chapters = false});
  final bool chapters;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '正在加载漫画',
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1120),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: SkeletonPulse(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 600;
                    const info = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SkeletonBlock(height: 24, width: 260),
                        SizedBox(height: 16),
                        SkeletonBlock(height: 14, width: 140),
                        SizedBox(height: 24),
                        SkeletonBlock(height: 14),
                        SizedBox(height: 10),
                        SkeletonBlock(height: 14),
                        SizedBox(height: 24),
                        SkeletonBlock(height: 44, width: 180),
                      ],
                    );
                    const cover = SizedBox(
                      width: 156,
                      child: AspectRatio(
                        aspectRatio: 3 / 4,
                        child: SkeletonBlock(),
                      ),
                    );
                    return wide
                        ? const Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              cover,
                              SizedBox(width: 28),
                              Expanded(child: info),
                            ],
                          )
                        : const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [cover, SizedBox(height: 24), info],
                          );
                  },
                ),
                if (chapters) ...[
                  const SizedBox(height: 32),
                  for (var i = 0; i < 5; i++)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: SkeletonBlock(height: 56),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class ReadingListSkeleton extends StatelessWidget {
  const ReadingListSkeleton({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
    label: '正在加载书库',
    child: SkeletonPulse(
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: 6,
        separatorBuilder: (_, _) => const SizedBox(height: 16),
        itemBuilder: (_, _) => const Row(
          children: [
            SkeletonBlock(width: 66, height: 88),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBlock(height: 18),
                  SizedBox(height: 14),
                  SkeletonBlock(height: 12, width: 120),
                  SizedBox(height: 10),
                  SkeletonBlock(height: 12, width: 160),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
