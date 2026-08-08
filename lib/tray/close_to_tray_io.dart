import 'dart:io';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

/// Windows 桌面：关闭窗口时最小化到系统托盘。
Future<void> setupCloseToTray() async {
  if (!Platform.isWindows) return;
  await windowManager.ensureInitialized();
  await windowManager.setPreventClose(true);
  windowManager.addListener(_CloseHandler());
  trayManager.addListener(_TrayHandler());

  final exeDir = File(Platform.resolvedExecutable).parent.path;
  await trayManager.setIcon(
    '$exeDir/data/flutter_assets/windows/runner/resources/app_icon.ico',
  );
  await trayManager.setToolTip('漫画库');
  await trayManager.setContextMenu(
    Menu(
      items: [
        MenuItem(key: 'show', label: '显示主窗口'),
        MenuItem(key: 'quit', label: '退出'),
      ],
    ),
  );
}

class _CloseHandler extends WindowListener {
  @override
  void onWindowClose() async {
    await windowManager.hide();
  }
}

class _TrayHandler extends TrayListener {
  @override
  void onTrayIconMouseDown() async {
    await windowManager.show();
    await windowManager.focus();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) async {
    switch (menuItem.key) {
      case 'show':
        await windowManager.show();
        await windowManager.focus();
        break;
      case 'quit':
        await trayManager.destroy();
        await windowManager.destroy();
        exit(0);
    }
  }
}
