import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../models/image_item.dart';
import '../theme.dart';
import 'enhanced_image.dart';
import 'loading_placeholders.dart';

/// 阅读页与滚动偏移共用图片高度，未知尺寸沿用 4:3 占位比例。
double readerImageHeight(ImageItem image, double width) {
  final w = image.width;
  final h = image.height;
  if (w != null && h != null && w > 0) return width * h / w;
  return width * 4 / 3;
}

/// 分页手势、双页槽位与方向按钮；阅读位置由页面持有。
class ReaderPagedView extends StatelessWidget {
  const ReaderPagedView({
    super.key,
    required this.currentPage,
    required this.imageCount,
    required this.spreadCount,
    required this.rightToLeft,
    required this.backgroundColor,
    required this.controlsVisible,
    required this.onInteraction,
    required this.onNextPage,
    required this.onPrevPage,
    required this.onLayout,
    required this.pageBuilder,
  });

  final int currentPage;
  final int imageCount;
  final int spreadCount;
  final bool rightToLeft;
  final Color backgroundColor;
  final bool controlsVisible;
  final VoidCallback onInteraction;
  final VoidCallback onNextPage;
  final VoidCallback onPrevPage;
  final ValueChanged<Size> onLayout;
  final Widget Function(int page, Size slot) pageBuilder;

  @override
  Widget build(BuildContext context) {
    final page = currentPage.clamp(0, imageCount - 1).toInt();
    final List<int?> pages = [
      page,
      if (spreadCount == 2) page + 1 < imageCount ? page + 1 : null,
    ];
    final ordered = rightToLeft ? pages.reversed.toList() : pages;
    return GestureDetector(
      onHorizontalDragStart: (_) => onInteraction(),
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity.abs() < 100) return;
        if ((velocity < 0) != rightToLeft) {
          onNextPage();
        } else {
          onPrevPage();
        }
      },
      child: Listener(
        onPointerSignal: (event) {
          if (event is PointerScrollEvent && event.scrollDelta.dy != 0) {
            onInteraction();
            GestureBinding.instance.pointerSignalResolver.register(event, (_) {
              if (event.scrollDelta.dy > 0) {
                onNextPage();
              } else {
                onPrevPage();
              }
            });
          }
        },
        child: Column(
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final slot = Size(
                    constraints.maxWidth / spreadCount,
                    constraints.maxHeight,
                  );
                  onLayout(slot);
                  return Stack(
                    children: [
                      ColoredBox(
                        color: backgroundColor,
                        child: Row(
                          children: [
                            for (final index in ordered)
                              SizedBox(
                                width: slot.width,
                                height: slot.height,
                                child: index == null
                                    ? null
                                    : pageBuilder(index, slot),
                              ),
                          ],
                        ),
                      ),
                      if (controlsVisible) ...[
                        Align(
                          alignment: Alignment.centerLeft,
                          child: IconButton.filledTonal(
                            tooltip: rightToLeft ? '下一页' : '上一页',
                            onPressed: rightToLeft ? onNextPage : onPrevPage,
                            icon: const Icon(Icons.chevron_left),
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: IconButton.filledTonal(
                            tooltip: rightToLeft ? '上一页' : '下一页',
                            onPressed: rightToLeft ? onPrevPage : onNextPage,
                            icon: const Icon(Icons.chevron_right),
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 单页图片适配与原图/增强图呈现；重试由页面校验请求代际。
class ReaderPageImage extends StatelessWidget {
  const ReaderPageImage({
    super.key,
    required this.image,
    required this.page,
    required this.slot,
    required this.fit,
    required this.provider,
    required this.imageKey,
    required this.onRetry,
    this.enhanced,
    required this.onEnhancedError,
  });

  final ImageItem image;
  final int page;
  final Size slot;
  final BoxFit fit;
  final ImageProvider<Object> provider;
  final Key imageKey;
  final VoidCallback onRetry;
  final ImageProvider<Object>? enhanced;
  final VoidCallback onEnhancedError;

  @override
  Widget build(BuildContext context) {
    final ratio = MediaQuery.devicePixelRatioOf(context);
    final imageWidth = fit == BoxFit.none
        ? (image.width ?? slot.width * ratio) / ratio
        : slot.width;
    final imageHeight = fit == BoxFit.none
        ? (image.height ?? slot.height * ratio) / ratio
        : fit == BoxFit.fitWidth
        ? readerImageHeight(image, imageWidth)
        : slot.height;
    final content = SizedBox(
      width: imageWidth,
      height: imageHeight,
      child: EnhancedImage(
        enhanced: enhanced,
        fit: fit == BoxFit.none ? BoxFit.contain : fit,
        onError: onEnhancedError,
        original: Image(
          image: provider,
          key: imageKey,
          fit: fit == BoxFit.none ? BoxFit.contain : fit,
          frameBuilder: (context, child, frame, synchronous) => imageFrame(
            context,
            child,
            frame,
            synchronous,
            placeholder: const ImageLoadingPlaceholder(),
          ),
          loadingBuilder: (_, child, progress) => progress == null
              ? child
              : ImageLoadingPlaceholder(progress: progress),
          errorBuilder: (_, _, _) => GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onRetry,
            child: const _ImageRetryBox(),
          ),
        ),
      ),
    );
    if (fit == BoxFit.contain) return content;
    final vertical = SingleChildScrollView(
      key: ValueKey((page, fit, slot)),
      child: Align(alignment: Alignment.topCenter, child: content),
    );
    if (fit == BoxFit.fitWidth) return vertical;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(width: math.max(imageWidth, slot.width), child: vertical),
    );
  }
}

/// 连续阅读的固定高度图片，独立管理首帧挂载与单图重试。
class ReaderScrollImage extends StatefulWidget {
  final ImageProvider<Object> provider;
  final double height;
  final ImageProvider<Object>? enhanced;
  final VoidCallback onEnhancedError;
  const ReaderScrollImage({
    super.key,
    required this.provider,
    required this.height,
    this.enhanced,
    required this.onEnhancedError,
  });

  @override
  State<ReaderScrollImage> createState() => _ReaderScrollImageState();
}

class _ReaderScrollImageState extends State<ReaderScrollImage> {
  bool _visible = false;
  int _retryTick = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    // 固定高度渲染：高度 = 视口宽 × 图片高/宽，与预估滚动偏移一致，
    // 图片加载不改变布局，跳转可精确到页。
    return SizedBox(
      width: double.infinity,
      height: widget.height,
      child: ClipRect(
        child: !_visible
            ? _loadingBox()
            : EnhancedImage(
                enhanced: widget.enhanced,
                fit: BoxFit.fitWidth,
                onError: widget.onEnhancedError,
                original: Image(
                  image: widget.provider,
                  key: ValueKey(_retryTick),
                  width: double.infinity,
                  height: widget.height,
                  fit: BoxFit.fitWidth,
                  frameBuilder: (context, child, frame, synchronous) =>
                      imageFrame(
                        context,
                        child,
                        frame,
                        synchronous,
                        placeholder: const ImageLoadingPlaceholder(),
                      ),
                  loadingBuilder: (_, child, progress) {
                    if (progress == null) return child;
                    return _loadingBox(progress: progress);
                  },
                  errorBuilder: (_, _, _) => GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _retry,
                    child: const _ImageRetryBox(),
                  ),
                ),
              ),
      ),
    );
  }

  Future<void> _retry() async {
    final provider = widget.provider;
    await provider.evict();
    if (!mounted || widget.provider != provider) return;
    setState(() => _retryTick++);
  }

  Widget _loadingBox({ImageChunkEvent? progress}) =>
      ImageLoadingPlaceholder(progress: progress);
}

/// 单图失败占位：显示可点击的"重试"提示。
class _ImageRetryBox extends StatelessWidget {
  const _ImageRetryBox();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.appColors.readerBar,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.broken_image, color: context.appColors.text2, size: 48),
            const SizedBox(height: 6),
            Text(
              '点击重试',
              style: TextStyle(color: context.appColors.text2, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
