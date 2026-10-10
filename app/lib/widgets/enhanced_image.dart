import 'package:flutter/material.dart';
import '../theme.dart';

class EnhancedImage extends StatelessWidget {
  const EnhancedImage({
    super.key,
    required this.original,
    this.enhanced,
    required this.fit,
    required this.onError,
  });
  final Widget original;
  final ImageProvider<Object>? enhanced;
  final BoxFit fit;
  final VoidCallback onError;

  @override
  Widget build(BuildContext context) {
    if (enhanced == null) return original;
    return Stack(
      fit: StackFit.passthrough,
      children: [
        original,
        Positioned.fill(
          child: IgnorePointer(
            child: Image(
              key: ValueKey(enhanced),
              image: enhanced!,
              fit: fit,
              frameBuilder: (_, child, frame, synchronous) =>
                  frame != null || synchronous
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        child,
                        Positioned(
                          top: 8,
                          right: 8,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(kRadiusSmall),
                            ),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              child: Text(
                                '2× 超分',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  : const SizedBox.shrink(),
              errorBuilder: (_, _, _) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (context.mounted) onError();
                });
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      ],
    );
  }
}
