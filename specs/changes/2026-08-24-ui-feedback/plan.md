---
title: UI 交互反馈修复
type: fix
date: 2026-08-24
origin: specs/changes/2026-08-24-ui-feedback/define.md
---

# UI 交互反馈修复

## Summary

加强按钮 hover/水波、补齐窗口按钮 hover、提升区域对比、路由转场改侧滑。

## Requirements

- R1. 按钮 hover/点击反馈明显。
- R2. 窗口最小化/最大化 hover 可见。
- R3. 侧栏/内容区对比清晰。
- R4. 路由推入为侧滑转场。
- R5. 不改布局/交互/接口/数据层。

## Key Technical Decisions

- 主题级反馈色提升 + `IconButtonThemeData`；窗口按钮 hover 用半透明白底；`navBg` 提亮 + 分隔线换 `border` 色；`PageTransitionsTheme` 全平台 Cupertino 侧滑。

## Implementation Units

### U1. ✅ 全局按钮反馈加强

- **Goal:** hover/点击反馈可感知。
- **Requirements:** R1, R5
- **Dependencies:** 无
- **Files:** `lib/theme.dart`
- **Approach:** `hoverColor` accent 8%、`splashColor` 12%、`highlightColor` 6%，新增 `IconButtonThemeData` hover/splash。
- **Verification:** 悬停按钮/图标底色明显，点击有水波。

### U2. ✅ 窗口按钮 hover

- **Goal:** 三按钮 hover 均可见。
- **Requirements:** R2, R5
- **Dependencies:** 无
- **Files:** `lib/widgets/window_title_bar.dart`
- **Approach:** 非关闭按钮 hover 背景半透明白 8%、图标变 `text1`；关闭红底白图标不变。
- **Verification:** 最小化/最大化悬停有反馈。

### U3. ✅ 区域对比

- **Goal:** 侧栏与内容区分明。
- **Requirements:** R3, R5
- **Dependencies:** 无
- **Files:** `lib/theme.dart`、`lib/main.dart`
- **Approach:** 深色 `navBg` 提亮到 `#21262d`；侧栏分隔线用 `c.border`；导航项 hover 底色用 `c.border`。
- **Verification:** 深浅模式下侧栏/内容区分明。

### U4. ✅ 路由转场侧滑

- **Goal:** 详情/阅读器等推入为侧滑。
- **Requirements:** R4, R5
- **Dependencies:** 无
- **Files:** `lib/theme.dart`
- **Approach:** `PageTransitionsTheme` 全平台 `CupertinoPageTransitionsBuilder`。
- **Verification:** 打开详情/阅读器从右滑入，不再缩放弹出。

## Acceptance Examples

- AE1. 按钮 hover/点击反馈明显。Covers R1。
- AE2. 最小化/最大化 hover 可见。Covers R2。
- AE3. 路由侧滑进入。Covers R4。

## Spec Impact

- `specs/ui-style.convention.md` — updated：交互反馈（hover/水波强度）、窗口按钮 hover、路由侧滑转场约定。
