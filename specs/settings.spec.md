---
status: complete
scope: feature
---

# 设置与外观

## Responsibilities

提供设置页与应用级外观偏好：主题模式可选浅色/深色/跟随系统，选择本地持久化、重启保持。入口为桌面侧栏"设置"与手机"我的"页右上角齿轮。

## Public Contract

- 设置页提供"外观"区的主题模式三选一（浅色/深色/跟随系统），切换即时生效。
- 设置页提供"窗口"区的"关闭窗口时最小化到系统托盘"开关（仅 Windows 桌面版显示，默认开启）：开启时关闭窗口退到托盘，关闭时直接退出应用。
- 主题偏好以本地偏好存储持久化（`shared_preferences`），无记录时默认跟随系统。
- 桌面侧栏"设置"与手机"我的"页齿轮均可进入同一个设置页。

## Notes

- 浅色/深色双套颜色令牌由 `lib/theme.dart` 的 `AppColors`（`ThemeExtension`）提供，组件经 `context.appColors` 取色；`MaterialApp` 同时注册浅/深主题并按 `themeMode` 切换。
- 阅读器背景与工具栏跟随主题：深色为黑底、浅色为浅底浅工具栏，阅读交互不受影响。
