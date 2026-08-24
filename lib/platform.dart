import 'package:flutter/foundation.dart';

/// 桌面/手机布局切换的窗口宽度阈值。
const double kDesktopBreakpoint = 720;

/// Android/iOS 恒为手机形态。
bool get isMobilePlatform =>
    defaultTargetPlatform == TargetPlatform.android ||
    defaultTargetPlatform == TargetPlatform.iOS;

/// 是否 Windows 桌面（自绘窗口标题栏等仅在 Windows 生效）。
bool get isWindowsPlatform =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

/// 桌面形态判定：Android/iOS 恒为手机；其余平台（Windows/Linux/macOS/Web）
/// 按窗口宽度决定，宽于阈值用桌面布局，否则用手机布局。
bool isDesktopAt(double width) =>
    !isMobilePlatform && width >= kDesktopBreakpoint;
