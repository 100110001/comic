---
date: 2026-08-24
topic: ui-feedback
---

# UI 交互反馈修复（按钮 hover/点击、区域对比、窗口按钮 hover、页面转场）

## Summary

修复四类反馈：全局按钮 hover/点击效果加强；侧栏与内容区对比更明显；窗口最小化/最大化按钮补齐可见 hover；详情页/阅读器的"从中间弹出"转场改为侧滑。

## Problem Frame

按钮 hover/水波过淡、最小化/最大化 hover 色与侧栏底色相同导致看不见、区域间缺乏明显差异、路由转场（Windows 默认缩放弹出）观感差。

## Key Decisions

- **全局反馈加强**：主题 `hoverColor`/`splashColor`/`highlightColor` 提高，并加 `IconButtonThemeData`。
- **窗口按钮 hover**：非关闭按钮 hover 用半透明白底 + 图标变亮；关闭保持红底白图标。
- **区域对比**：深色 `navBg` 提亮到 `#21262d`，侧栏右分隔线用更亮的 `border` 色。
- **转场**：全局 `PageTransitionsTheme` 改为 Cupertino 侧滑（去掉缩放弹出）。

## Requirements

- R1. 全局按钮 hover 与点击反馈明显可感知。
- R2. 窗口三按钮（除 X）hover 有可见反馈，X hover 红底白图标不变。
- R3. 侧栏与内容区背景对比清晰。
- R4. 详情页/阅读器/搜索等推入路由为侧滑转场，不再是"从中间弹出"。
- R5. 不改变布局、交互逻辑、接口与数据层。

## Acceptance Examples

- AE1. 悬停任意按钮/图标有明显底色变化，点击有水波。Covers R1。
- AE2. 悬停最小化/最大化按钮出现浅色底与图标变亮。Covers R2。
- AE3. 打开详情页/阅读器为从右滑入。Covers R4。
