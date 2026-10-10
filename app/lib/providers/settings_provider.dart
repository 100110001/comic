import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _themeModeKey = 'themeMode';
const kCloseToTrayKey = 'closeToTray';
const kWindowBoundsKey = 'windowBounds';

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

/// 读取上次保存的窗口位置与尺寸（无记录返回 null）。
Future<Rect?> loadWindowBounds() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(kWindowBoundsKey);
  if (raw == null) return null;
  final parts = raw.split(',').map(double.tryParse).toList();
  if (parts.length != 4 || parts.any((p) => p == null)) return null;
  final rect = Rect.fromLTWH(parts[0]!, parts[1]!, parts[2]!, parts[3]!);
  // 校验坐标合法性：尺寸过小或位置异常（如最小化占位 -32000）直接忽略
  if (rect.width < 200 ||
      rect.height < 150 ||
      rect.left < -10000 ||
      rect.top < -10000) {
    return null;
  }
  return rect;
}

Future<void> saveWindowBounds(Rect bounds) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(
    kWindowBoundsKey,
    '${bounds.left},${bounds.top},${bounds.width},${bounds.height}',
  );
}

enum SuperResolutionMode { on, adaptive, off }

const kSuperResolutionDefaultKey = 'superResolutionDefault';
const kSuperResolutionModeKey = 'superResolutionMode';
final superResolutionDefaultProvider =
    NotifierProvider<SuperResolutionDefaultNotifier, SuperResolutionMode>(
      SuperResolutionDefaultNotifier.new,
    );

class SuperResolutionDefaultNotifier extends Notifier<SuperResolutionMode> {
  SuperResolutionDefaultNotifier({
    bool? initial,
    SuperResolutionMode? initialMode,
  }) : initial =
           initialMode ??
           (initial == null
               ? SuperResolutionMode.adaptive
               : initial
               ? SuperResolutionMode.on
               : SuperResolutionMode.off);
  final SuperResolutionMode initial;
  @override
  SuperResolutionMode build() => initial;
  Future<void> _pending = Future<void>.value();

  Future<void> setMode(SuperResolutionMode value) {
    final operation = _pending.then((_) async {
      if (!ref.mounted) return;
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs.setString(kSuperResolutionModeKey, value.name)) {
        throw StateError('超分设置保存失败');
      }
      if (ref.mounted) state = value;
    });
    _pending = operation.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {},
    );
    return operation;
  }

  Future<void> setEnabled(bool value) =>
      setMode(value ? SuperResolutionMode.on : SuperResolutionMode.off);
}

Future<SuperResolutionMode> loadSuperResolutionMode() async {
  final prefs = await SharedPreferences.getInstance();
  final stored = prefs.get(kSuperResolutionModeKey);
  for (final mode in SuperResolutionMode.values) {
    if (stored == mode.name) return mode;
  }
  final legacy = prefs.get(kSuperResolutionDefaultKey);
  if (legacy is bool) {
    return legacy ? SuperResolutionMode.on : SuperResolutionMode.off;
  }
  return SuperResolutionMode.adaptive;
}

/// 兼容旧版布尔接口；新入口使用三种策略。
Future<bool> loadSuperResolutionDefault() async =>
    await loadSuperResolutionMode() != SuperResolutionMode.off;

enum ReaderMode { automatic, single, doublePage, continuous }

enum ReadingDirection { leftToRight, rightToLeft }

enum ReaderFit { contain, fitWidth, original }

enum ReaderBackground { theme, dark, gray, paper }

const readerModeLabels = {
  ReaderMode.automatic: '跟随设备',
  ReaderMode.single: '单页阅读',
  ReaderMode.doublePage: '双页阅读',
  ReaderMode.continuous: '连续阅读',
};
const readingDirectionLabels = {
  ReadingDirection.leftToRight: '从左到右',
  ReadingDirection.rightToLeft: '从右到左',
};
const readerFitLabels = {
  ReaderFit.contain: '适应窗口',
  ReaderFit.fitWidth: '适应宽度',
  ReaderFit.original: '实际大小',
};
const readerBackgroundLabels = {
  ReaderBackground.theme: '跟随主题',
  ReaderBackground.dark: '深色',
  ReaderBackground.gray: '灰色',
  ReaderBackground.paper: '护眼米色',
};
const superResolutionModeLabels = {
  SuperResolutionMode.on: '开启',
  SuperResolutionMode.adaptive: '自适应',
  SuperResolutionMode.off: '关闭',
};

class ReaderPreferences {
  const ReaderPreferences({
    this.mode = ReaderMode.automatic,
    this.direction = ReadingDirection.leftToRight,
    this.fit = ReaderFit.contain,
    this.background = ReaderBackground.theme,
    this.autoHide = true,
  });

  final ReaderMode mode;
  final ReadingDirection direction;
  final ReaderFit fit;
  final ReaderBackground background;
  final bool autoHide;

  ReaderPreferences copyWith({
    ReaderMode? mode,
    ReadingDirection? direction,
    ReaderFit? fit,
    ReaderBackground? background,
    bool? autoHide,
  }) => ReaderPreferences(
    mode: mode ?? this.mode,
    direction: direction ?? this.direction,
    fit: fit ?? this.fit,
    background: background ?? this.background,
    autoHide: autoHide ?? this.autoHide,
  );

  Map<String, Object> toJson() => {
    'mode': mode.name,
    'direction': direction.name,
    'fit': fit.name,
    'background': background.name,
    'autoHide': autoHide,
  };

  factory ReaderPreferences.fromJson(Map<String, dynamic> json) {
    T value<T extends Enum>(String key, List<T> values, T fallback) => values
        .firstWhere((value) => value.name == json[key], orElse: () => fallback);
    return ReaderPreferences(
      mode: value('mode', ReaderMode.values, ReaderMode.automatic),
      direction: value(
        'direction',
        ReadingDirection.values,
        ReadingDirection.leftToRight,
      ),
      fit: value('fit', ReaderFit.values, ReaderFit.contain),
      background: value(
        'background',
        ReaderBackground.values,
        ReaderBackground.theme,
      ),
      autoHide: json['autoHide'] is bool ? json['autoHide'] as bool : true,
    );
  }
}

const kReaderPreferencesKey = 'readerPreferences.v1';
final readerPreferencesProvider =
    NotifierProvider<ReaderPreferencesNotifier, ReaderPreferences>(
      ReaderPreferencesNotifier.new,
    );

class ReaderPreferencesNotifier extends Notifier<ReaderPreferences> {
  ReaderPreferencesNotifier({this.initial = const ReaderPreferences()});
  final ReaderPreferences initial;
  Future<void> _pending = Future<void>.value();

  @override
  ReaderPreferences build() => initial;

  /// 两个入口的变更串行合并，持久化失败不发布新值。
  Future<void> update(ReaderPreferences Function(ReaderPreferences) change) {
    final operation = _pending.then((_) async {
      if (!ref.mounted) return;
      final next = change(state);
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs.setString(
        kReaderPreferencesKey,
        jsonEncode(next.toJson()),
      )) {
        throw StateError('阅读设置保存失败');
      }
      if (ref.mounted) state = next;
    });
    _pending = operation.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {},
    );
    return operation;
  }
}

Future<ReaderPreferences> loadReaderPreferences() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.get(kReaderPreferencesKey);
    if (raw is! String) return const ReaderPreferences();
    final json = jsonDecode(raw);
    if (json is! Map<String, dynamic>) return const ReaderPreferences();
    return ReaderPreferences.fromJson(json);
  } catch (_) {
    return const ReaderPreferences();
  }
}
