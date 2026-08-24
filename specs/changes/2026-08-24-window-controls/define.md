---
date: 2026-08-24
topic: window-controls
---

# 自定义窗口标题栏与窗口控制按钮（Windows）

## Summary

在 Windows 桌面版隐藏系统原生标题栏，自绘标题栏：顶部拖拽区（双击最大化/还原）+ 右侧最小化/最大化/关闭三个按钮。关闭按钮复用现有"关闭窗口时最小化到托盘"设置。其他平台不变。

## Problem Frame

系统原生标题栏的按钮样式与 App 视觉不统一，且无法跟随后续 UI 改版；用户希望自己实现右上角三个按钮。

## Key Decisions

- **用 `window_manager` 隐藏原生标题栏**：`setTitleBarStyle(TitleBarStyle.hidden, windowButtonVisibility: false)`。
- **标题栏放在 `MaterialApp.builder` 层**：全局覆盖所有路由（含阅读器），始终可拖拽/控制窗口。
- **关闭按钮走现有托盘逻辑**：调用 `windowManager.close()`，由 `onWindowClose` 按 `closeToTray` 设置决定退托盘或退出。
- **仅 Windows 生效**：其他平台保持原生标题栏。

## Requirements

- R1. Windows 桌面版隐藏系统标题栏与原生窗口按钮。
- R2. 自定义标题栏提供拖拽区与最小化/最大化(还原)/关闭三个按钮。
- R3. 关闭按钮遵循"关闭窗口时最小化到托盘"设置。
- R4. 最大化/还原按钮图标随窗口状态实时切换。
- R5. 非 Windows 平台行为不变。

## Acceptance Examples

- AE1. Windows 下可拖拽标题栏移动窗口，双击最大化/还原。Covers R2。
- AE2. 关闭托盘开关后点自定义关闭按钮直接退出；开启后退到托盘。Covers R3。
- AE3. 最大化后按钮变为"还原"图标。Covers R4。

## Scope Boundaries

**Deferred for later**

- 标题栏居中显示窗口标题、拖拽到屏幕边缘的贴靠手势、阅读器全屏时隐藏标题栏。
