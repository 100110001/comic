import 'package:flutter/widgets.dart';
import '../utils/display_image_provider.dart';

/// 在图片的实际布局区域中选择解码尺寸，不改变占位或裁切。
class DisplayNetworkImage extends StatelessWidget {
  const DisplayNetworkImage(
    this.url, {
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.errorBuilder,
    this.loadingBuilder,
  });

  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final ImageErrorWidgetBuilder? errorBuilder;
  final ImageLoadingBuilder? loadingBuilder;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = constraints.constrain(
        Size(
          width?.isFinite == true ? width! : constraints.maxWidth,
          height?.isFinite == true ? height! : constraints.maxHeight,
        ),
      );
      return Image(
        image: displayImageProvider(
          url,
          logicalSize: size,
          devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
          fit: fit,
        ),
        width: width,
        height: height,
        fit: fit,
        errorBuilder: errorBuilder,
        loadingBuilder: loadingBuilder,
      );
    },
  );
}
