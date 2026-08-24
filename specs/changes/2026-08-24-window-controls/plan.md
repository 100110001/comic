---
title: 自定义窗口标题栏与窗口控制按钮（Windows）
type: feat
date: 2026-08-24
origin: specs/changes/2026-08-24-window-controls/define.md
---

# 自定义窗口标题栏与窗口控制按钮（Windows）

## Summary

Windows 桌面版隐藏原生标题栏，自绘拖拽区与最小化/最大化/关闭按钮；关闭复用托盘设置，仅 Windows 生效。

## Requirements

- R1. Windows 隐藏系统标题栏与原生窗口按钮。
- R2. 自定义标题栏含拖拽区与最小化/最大化(还原)/关闭按钮。
- R3. 关闭遵循"关闭窗口时最小化到托盘"设置。
- R4. 最大化/还原图标实时切换。
- R5. 非 Windows 平台不变。

## Key Technical Decisions

- 标题栏挂在 `MaterialApp.builder` 层，覆盖所有路由；自带 `Material` 外壳避免缺少 Material 祖先。
- 拖拽用 `windowManager.startDragging()`，双击切换最大化。
- 关闭按钮只调 `windowManager.close()`，托盘逻辑保持不变。

## Implementation Units

### U1. ✅ 平台判定与隐藏原生标题栏

- **Goal:** 新增 Windows 平台判定，并隐藏原生标题栏与按钮。
- **Requirements:** R1, R5
- **Dependencies:** 无
- **Files:** `lib/platform.dart`、`lib/tray/close_to_tray_io.dart`
- **Approach:** `platform.dart` 增加 `isWindowsPlatform`；`setupCloseToTray` 中调用 `setTitleBarStyle(TitleBarStyle.hidden, windowButtonVisibility: false)`。
- **Verification:** Windows 下原生标题栏消失；其他平台不受影响。

### U2. ✅ 自定义标题栏组件

- **Goal:** 实现标题栏：拖拽区 + 三按钮，最大化状态监听。
- **Requirements:** R2, R4
- **Dependencies:** U1
- **Files:** `lib/widgets/window_title_bar.dart`（新建）
- **Approach:** `WindowTitleBar`（StatefulWidget + `WindowListener`）：拖拽区 `startDragging`、双击切换最大化；按钮 46x40，关闭按钮 hover 红色；最大化状态由 `onWindowMaximize/onWindowUnmaximize` 同步。
- **Verification:** 三按钮可用，图标随窗口状态切换。

### U3. ✅ 接入应用外壳

- **Goal:** 标题栏在 Windows 下全局显示。
- **Requirements:** R2, R5
- **Dependencies:** U2
- **Files:** `lib/main.dart`
- **Approach:** `MaterialApp.builder` 在 Windows 下返回 `Column(标题栏 + Expanded(child))`，保留现有侧键返回 Listener。
- **Verification:** 所有页面顶部都有自定义标题栏；阅读器内也可拖动/关闭窗口。

## Acceptance Examples

- AE1. 拖拽移动窗口、双击最大化/还原。Covers R2。
- AE2. 关闭按钮遵循托盘开关。Covers R3。
- AE3. 最大化图标实时切换。Covers R4。

## Scope Boundaries

**Deferred to Follow-Up Work**

- 标题栏显示窗口标题、边缘贴靠手势、全屏时隐藏标题栏。

## Spec Impact

- `specs/app-shell.spec.md` — updated：Windows 桌面版使用自绘标题栏与窗口控制按钮，关闭行为仍遵循设置。
