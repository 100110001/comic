import 'package:flutter/foundation.dart';

/// 桌面形态：Windows/Linux/macOS 与 Web（浏览器）统一按桌面设计，
/// 手机浏览器同样按桌面处理（响应式 Web 不在范围内）。
bool get isDesktop =>
    kIsWeb ||
    defaultTargetPlatform == TargetPlatform.windows ||
    defaultTargetPlatform == TargetPlatform.linux ||
    defaultTargetPlatform == TargetPlatform.macOS;
