import 'package:flutter/material.dart';
import '../theme.dart';

/// Codex 风交互反馈：悬停底色 160ms 平滑过渡，按下轻微缩放（0.97）。
class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final BorderRadius radius;
  final Color? hoverColor;

  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.radius = const BorderRadius.all(Radius.circular(kRadiusButton)),
    this.hoverColor,
  });

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _hovered = false;
  bool _pressed = false;

  void _setHover(bool value) => setState(() => _hovered = value);

  void _setPressed(bool value) => setState(() => _pressed = value);

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => _setHover(true),
      onExit: (_) {
        _setPressed(false);
        _setHover(false);
      },
      child: Listener(
        onPointerDown: (_) => _setPressed(true),
        onPointerUp: (_) => _setPressed(false),
        onPointerCancel: (_) => _setPressed(false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: AnimatedScale(
            scale: _pressed ? 0.97 : 1.0,
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              decoration: BoxDecoration(
                color: _hovered
                    ? (widget.hoverColor ?? c.accent.withValues(alpha: 0.10))
                    : Colors.transparent,
                borderRadius: widget.radius,
              ),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}
