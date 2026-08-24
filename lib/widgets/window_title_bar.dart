import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import '../theme.dart';

/// 自定义窗口标题栏（仅 Windows 桌面）：拖拽区 + 最小化/最大化/关闭。
class WindowTitleBar extends StatefulWidget {
  const WindowTitleBar({super.key});

  @override
  State<WindowTitleBar> createState() => _WindowTitleBarState();
}

class _WindowTitleBarState extends State<WindowTitleBar> with WindowListener {
  bool _maximized = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _syncMaximized();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  Future<void> _syncMaximized() async {
    final maximized = await windowManager.isMaximized();
    if (mounted && maximized != _maximized) {
      setState(() => _maximized = maximized);
    }
  }

  @override
  void onWindowMaximize() {
    if (mounted) setState(() => _maximized = true);
  }

  @override
  void onWindowUnmaximize() {
    if (mounted) setState(() => _maximized = false);
  }

  void _minimize() => windowManager.minimize();

  void _toggleMaximize() {
    if (_maximized) {
      windowManager.unmaximize();
    } else {
      windowManager.maximize();
    }
  }

  /// 关闭走 windowManager.close()，由托盘逻辑按设置决定退托盘或退出。
  void _close() => windowManager.close();

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Material(
      color: c.navBg,
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: c.borderStrong)),
        ),
        child: Row(
          children: [
            Expanded(
              child: MouseRegion(
                cursor: SystemMouseCursors.move,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onDoubleTap: _toggleMaximize,
                  onPanStart: (_) => windowManager.startDragging(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '漫画库',
                        style: TextStyle(
                          color: c.text1,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            _TitleBarButton(icon: Icons.remove, onTap: _minimize),
            _TitleBarButton(
              icon: _maximized ? Icons.filter_none : Icons.crop_square,
              onTap: _toggleMaximize,
            ),
            _TitleBarButton(icon: Icons.close, onTap: _close, danger: true),
          ],
        ),
      ),
    );
  }
}

class _TitleBarButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool danger;

  const _TitleBarButton({
    required this.icon,
    required this.onTap,
    this.danger = false,
  });

  @override
  State<_TitleBarButton> createState() => _TitleBarButtonState();
}

class _TitleBarButtonState extends State<_TitleBarButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = widget.danger
        ? (_hovered
              ? Colors.white
              : dark
              ? Colors.white
              : c.text1)
        : c.text2;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: InkWell(
        hoverColor: widget.danger ? const Color(0xFFe81123) : c.surface2,
        onTap: widget.onTap,
        child: SizedBox(
          width: 46,
          height: 40,
          child: Icon(widget.icon, size: 16, color: iconColor),
        ),
      ),
    );
  }
}
