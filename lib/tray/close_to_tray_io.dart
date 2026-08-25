import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';
import '../providers/settings_provider.dart';

/// Windows 桌面：关闭窗口时最小化到系统托盘。
Future<void> setupCloseToTray() async {
  if (!Platform.isWindows) return;
  await windowManager.ensureInitialized();
  await windowManager.setPreventClose(true);
  // 隐藏系统标题栏与原生窗口按钮，由 App 自绘标题栏控制窗口。
  await windowManager.setTitleBarStyle(
    TitleBarStyle.hidden,
    windowButtonVisibility: false,
  );
  // 恢复上次的窗口位置与尺寸
  await windowManager.waitUntilReadyToShow(null, () async {
    final bounds = await loadWindowBounds();
    if (bounds != null) {
      await windowManager.setBounds(bounds);
    }
  });
  windowManager.addListener(_CloseHandler());
  trayManager.addListener(_TrayHandler());

  final exeDir = File(Platform.resolvedExecutable).parent.path;
  await trayManager.setIcon(
    '$exeDir/data/flutter_assets/windows/runner/resources/app_icon.ico',
  );
  await trayManager.setToolTip('Comic');
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
    final bounds = await windowManager.getBounds();
    await saveWindowBounds(bounds);
    final prefs = await SharedPreferences.getInstance();
    final minimizeToTray = prefs.getBool(kCloseToTrayKey) ?? true;
    if (minimizeToTray) {
      await windowManager.hide();
    } else {
      await windowManager.destroy();
    }
  }
}

class _TrayHandler extends TrayListener {
  @override
  void onTrayIconMouseDown() async {
    await windowManager.show();
    await windowManager.focus();
  }

  @override
  void onTrayIconRightMouseDown() {
    // Windows 不会自动弹菜单，需手动调起
    trayManager.popUpContextMenu();
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
    }
  }
}
