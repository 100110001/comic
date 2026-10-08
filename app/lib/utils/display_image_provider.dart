import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

typedef DisplayImageKey = ({
  NetworkImage source,
  int width,
  int? height,
  BoxFit fit,
});

const _pixelSizes = [
  128,
  192,
  256,
  384,
  512,
  768,
  1024,
  1536,
  2048,
  3072,
  4096,
];

int? _pixelBucket(double logical, double ratio) {
  final pixels = logical * ratio;
  if (!pixels.isFinite || pixels <= 0) return null;
  for (final size in _pixelSizes) {
    if (size >= pixels) return size;
  }
  return null;
}

/// 缓存身份保留完整 URL；显示、预加载和重试共用此工厂。
ImageProvider<Object> displayImageProvider(
  String url, {
  required Size logicalSize,
  required double devicePixelRatio,
  BoxFit fit = BoxFit.cover,
}) {
  final source = NetworkImage(url);
  if (kIsWeb) return source;
  final width = _pixelBucket(logicalSize.width, devicePixelRatio);
  final height = fit == BoxFit.fitWidth
      ? null
      : _pixelBucket(logicalSize.height, devicePixelRatio);
  if (width == null || (height == null && fit != BoxFit.fitWidth)) {
    return source;
  }
  return DisplaySizedNetworkImage(
    source,
    width: width,
    height: height,
    fit: fit,
  );
}

/// 按原图比例解码；cover 必须满足裁切后的短边清晰度，不能拉伸原图。
class DisplaySizedNetworkImage extends ImageProvider<DisplayImageKey> {
  const DisplaySizedNetworkImage(
    this.source, {
    required this.width,
    this.height,
    required this.fit,
  });

  final NetworkImage source;
  final int width;
  final int? height;
  final BoxFit fit;

  @override
  Future<DisplayImageKey> obtainKey(ImageConfiguration configuration) => source
      .obtainKey(configuration)
      .then((key) => (source: key, width: width, height: height, fit: fit));

  @override
  ImageStreamCompleter loadImage(
    DisplayImageKey key,
    ImageDecoderCallback decode,
  ) {
    final completer = source.loadImage(
      key.source,
      (buffer, {getTargetSize}) => decode(
        buffer,
        getTargetSize: (intrinsicWidth, intrinsicHeight) {
          final horizontal = key.width / intrinsicWidth;
          final vertical = (key.height ?? intrinsicHeight) / intrinsicHeight;
          final desired = key.fit == BoxFit.fitWidth
              ? horizontal
              : key.fit == BoxFit.cover
              ? math.max(horizontal, vertical)
              : math.min(horizontal, vertical);
          final scale = math.min(1.0, desired);
          return ui.TargetImageSize(
            width: math.max(1, (intrinsicWidth * scale).ceil()),
            height: math.max(1, (intrinsicHeight * scale).ceil()),
          );
        },
      ),
    );
    // NetworkImage 的错误清理只认识源 key，包装后的尺寸 key 也要清理。
    late ImageStreamListener listener;
    listener = ImageStreamListener(
      (image, synchronous) => completer.removeListener(listener),
      onError: (Object error, StackTrace? stack) {
        completer.removeListener(listener);
        scheduleMicrotask(() => PaintingBinding.instance.imageCache.evict(key));
      },
    );
    completer.addListener(listener);
    return completer;
  }

  @override
  bool operator ==(Object other) =>
      other is DisplaySizedNetworkImage &&
      other.source == source &&
      other.width == width &&
      other.height == height &&
      other.fit == fit;

  @override
  int get hashCode => Object.hash(source, width, height, fit);
}
