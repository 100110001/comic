---
title: UI 视觉改版（现代深色风格）
type: feat
date: 2026-08-24
origin: specs/changes/2026-08-24-ui-redesign/define.md
---

# UI 视觉改版（现代深色风格）

## Summary

以新的设计令牌与组件主题替换现有 GitHub 深色体系，逐组件精修至 Codex / Discord / Kook 一类现代观感；交互与数据层不变。

## Requirements

- R1. 全 App 采用新视觉体系：背景层次、强调色、圆角、边框、阴影统一。
- R2. 卡片/按钮/输入框/导航/Tab/开关/SnackBar 按新体系精修，含 hover/选中态。
- R3. 浅色模式同步改版。
- R4. 阅读器保持黑底沉浸，工具栏与进度条协调。
- R5. 不改变布局、交互、接口与数据层。

## Key Technical Decisions

- **令牌集中在 `lib/theme.dart`**：改版只动 `AppColors.dark/light` 与组件主题，页面代码基本不动。
- **强调色**：按确认的方向定（Discord blurple / Codex 蓝 / Kook 青绿）。
- **圆角**：卡片 12–16、按钮/输入框 10、导航胶囊 12。
- **层次**：卡片加细边框 + 轻阴影，hover 轻微抬升/高亮。

## Implementation Units

### U1. 新设计令牌与组件主题

- **Goal:** 替换颜色/圆角/阴影令牌与组件主题，全 App 呈现新视觉。
- **Requirements:** R1, R3, R5
- **Dependencies:** 无
- **Files:** `lib/theme.dart`
- **Approach:** 按确认方向重写 `AppColors.dark/light` 与组件主题（AppBar/Card/Button/Input/Slider/Nav/Tab/Switch/SnackBar/Scrollbar）。
- **Verification:** 深/浅两套协调，`flutter analyze` 无问题。

### U2. 卡片与网格细节

- **Goal:** 卡片 hover/阴影/边框与新体系一致。
- **Requirements:** R2, R5
- **Dependencies:** 无（沿用现有令牌）
- **Files:** `lib/widgets/comic_card.dart`、`lib/widgets/comic_grid.dart`
- **Approach:** 卡片加 hover 高亮/抬升、封面圆角与边框统一。
- **Verification:** 网格观感统一，卡片高宽比不变。

### U3. ✅ 桌面侧栏改版（图标+文字列表式）

- **Goal:** 桌面左侧导航改为图标+文字列表式：顶部"漫画库"标题、圆角行、选中强调色淡底、悬停浅底、"设置"固定在底部。
- **Requirements:** R2, R5
- **Dependencies:** U1
- **Files:** `lib/main.dart`
- **Approach:** 用自定义侧栏（约 208px 宽）替换 `NavigationRail`；主项 5 个 + 底部固定"设置"；选中 accent 15% 底 + accent 图标/文字，悬停 surface2。
- **Verification:** 桌面侧栏观感现代，切换/失效逻辑不变。

### U4. 状态页与细节组件

- **Goal:** 空态/错误态、开关、SnackBar 等细节组件与新体系一致。
- **Requirements:** R2, R5
- **Dependencies:** U1
- **Files:** `lib/widgets/status_views.dart`、`lib/screens/settings_screen.dart`
- **Approach:** 状态图标底、开关样式、设置页面板按新令牌微调。
- **Verification:** 各状态页观感统一。

### U5. 阅读器协调

- **Goal:** 阅读器黑底沉浸与工具栏/进度条协调。
- **Requirements:** R4, R5
- **Dependencies:** U1
- **Files:** `lib/screens/reader_screen.dart`、`lib/widgets/reader_progress_bar.dart`
- **Approach:** 工具栏/进度条按新令牌微调，画布保持黑底。
- **Verification:** 阅读交互不变。

## Acceptance Examples

- AE1. 网格卡片观感统一，hover 抬升/高亮。Covers R1, R2。
- AE2. 侧栏选中态圆角胶囊。Covers R2。
- AE3. 浅/深切换协调，阅读器黑底不变。Covers R3, R4。

## Scope Boundaries

**Deferred to Follow-Up Work**

- 页面转场动画体系、图标/封面重绘、自定义字体。

## Spec Impact

- `specs/ui-style.convention.md` — updated：设计令牌更新为新视觉体系（颜色/圆角/阴影/强调色）。
