---
title: UI 细节打磨
type: feat
date: 2026-08-24
origin: specs/changes/2026-08-24-ui-refine/define.md
---

# UI 细节打磨

## Summary

标题栏合并应用名、导航反馈平滑化、页面切换过渡、背景色差拉开、设置页文案理顺。

## Requirements

- R1. 标题栏一行容纳"漫画库"与窗口三按钮。
- R2. 导航项 hover 平滑、点击反馈明显。
- R3. 页面切换淡入过渡，保留状态。
- R4. 左右背景色差清晰（深浅皆然）。
- R5. 不改变布局/交互/接口/数据层。

## Key Technical Decisions

- `navBg` 新令牌用于标题栏与侧栏；浅色内容背景改纯白拉开对比。
- 页面过渡用 `TweenAnimationBuilder`（按 index 键控）包 `IndexedStack`：淡入 + 6px 上移，状态保留。
- 导航项 hover 用 `AnimatedContainer`（160ms），点击用 accent 水波（18%）。

## Implementation Units

### U1. 标题栏与侧栏标题合并

- **Goal:** "漫画库"进入标题栏，侧栏顶部不再重复标题。
- **Requirements:** R1, R5
- **Dependencies:** 无
- **Files:** `lib/widgets/window_title_bar.dart`、`lib/main.dart`
- **Approach:** 标题栏左侧渲染"漫画库"（并入拖拽区），侧栏去掉标题并加顶部留白。
- **Verification:** 顶部一行标题+按钮，拖拽/双击仍可用。

### U2. 导航项交互反馈

- **Goal:** hover 平滑、点击水波明显。
- **Requirements:** R2, R5
- **Dependencies:** 无
- **Files:** `lib/main.dart`
- **Approach:** `_SideNavItem` 改 Stateful：MouseRegion + `AnimatedContainer`（160ms）背景，`InkWell` 水波 accent 18%。
- **Verification:** 悬停底色过渡自然，点击有水波。

### U3. 页面切换过渡

- **Goal:** 侧栏页面切换有淡入效果且保留状态。
- **Requirements:** R3, R5
- **Dependencies:** 无
- **Files:** `lib/main.dart`
- **Approach:** `IndexedStack` 外包 `TweenAnimationBuilder`（key=index，220ms 淡入 + 上移 6px）。
- **Verification:** 切换有淡入，切回后首页滚动位置不变。

### U4. 背景色差与导航底色

- **Goal:** 标题栏/侧栏与内容区背景对比清晰。
- **Requirements:** R4, R5
- **Dependencies:** 无
- **Files:** `lib/theme.dart`、`lib/main.dart`、`lib/widgets/window_title_bar.dart`
- **Approach:** `AppColors` 增加 `navBg`（深 `#1c2128`/浅 `#f6f8fa`）；浅色 `bg` 改纯白；标题栏与侧栏用 `navBg`。
- **Verification:** 深/浅模式下左右区域可明显区分。

### U5. 设置页文案理顺

- **Goal:** 设置项说明更清楚。
- **Requirements:** R5
- **Dependencies:** 无
- **Files:** `lib/screens/settings_screen.dart`
- **Approach:** 按用户确认的理解问题调整文案/结构（待确认）。
- **Verification:** 设置项含义一目了然。

## Acceptance Examples

- AE1. 顶部一行标题+三按钮。Covers R1。
- AE2. hover 平滑、点击水波。Covers R2。
- AE3. 页面切换淡入且保留状态。Covers R3。
- AE4. 深浅模式下左右色差清晰。Covers R4。

## Spec Impact

- `specs/ui-style.convention.md` — updated：新增 `navBg` 令牌与页面切换过渡、导航反馈约定。
