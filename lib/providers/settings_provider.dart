import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _themeModeKey = 'themeMode';
const kCloseToTrayKey = 'closeToTray';

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);

/// 外观模式状态：切换即时生效并持久化到本地偏好。
class ThemeModeNotifier extends Notifier<ThemeMode> {
  ThemeModeNotifier({this.initial = ThemeMode.system});

  final ThemeMode initial;

  @override
  ThemeMode build() => initial;

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModeKey, mode.name);
  }
}

/// 启动时读取持久化的外观偏好，无记录时默认跟随系统。
Future<ThemeMode> loadThemeMode() async {
  final prefs = await SharedPreferences.getInstance();
  final stored = prefs.getString(_themeModeKey);
  return ThemeMode.values.firstWhere(
    (m) => m.name == stored,
    orElse: () => ThemeMode.system,
  );
}

final closeToTrayProvider = NotifierProvider<CloseToTrayNotifier, bool>(
  CloseToTrayNotifier.new,
);

/// 关闭窗口是否最小化到系统托盘（仅 Windows 桌面版生效）。
class CloseToTrayNotifier extends Notifier<bool> {
  CloseToTrayNotifier({this.initial = true});

  final bool initial;

  @override
  bool build() => initial;

  Future<void> setEnabled(bool value) async {
    state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kCloseToTrayKey, value);
  }
}

/// 启动时读取托盘偏好，无记录时默认开启。
Future<bool> loadCloseToTray() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(kCloseToTrayKey) ?? true;
}
