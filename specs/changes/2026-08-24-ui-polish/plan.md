---
title: 全 App UI 视觉精修
type: feat
date: 2026-08-24
origin: specs/changes/2026-08-24-ui-polish/define.md
---

# 全 App UI 视觉精修

## Summary

以集中设计令牌与组件主题为基础，逐屏精修全 App 视觉：外壳导航、首页/搜索、详情、发现、我的/列表、阅读器。只改视觉，交互与数据层不变。

## Problem Frame

样式散落硬编码、默认 Material 组件与深色配色冲突、卡片/列表/状态页缺少统一规范，用户要求全 App 一起打磨。

## Requirements

**主题与令牌**

- R1. 全局颜色/圆角/字体/间距由集中令牌定义，主色调延续现有深色体系。
- R2. 所有 Material 组件通过主题统一，不再与自定配色冲突。

**卡片与列表**

- R3. 漫画卡片（网格）统一圆角、边框/阴影、封面占位与文字层级；收藏角标样式一致。
- R4. 列表项（最近阅读/收藏/收藏作者）与详情章节列表统一缩略图圆角与文字层级。
- R5. 详情页头部信息区面板化，按钮与信息层级清晰。

**页面**

- R6. 外壳导航（桌面侧栏/手机底部 tab）视觉精修，选中态与间距统一。
- R7. 首页、发现、搜索的 AppBar、输入框、加载/空/错误态样式统一且精致。
- R8. 阅读器工具栏、进度条、目录与状态页精修，保持既有交互不变。

**约束**

- R9. 不改变任何布局结构、交互逻辑、接口与数据层行为。

## Key Technical Decisions

- **集中令牌文件**：新建主题文件定义颜色、圆角、字体、间距与组件主题；各页面引用令牌而非硬编码。
- **共用状态组件**：空态/错误态抽为共用组件，全 App 一致。
- **保持行为**：任何视觉改动不得触碰滚动、翻页、拖拽、收藏、进度保存等逻辑路径。

## High-Level Technical Design

令牌概览（延续现有深色体系）：

| 令牌 | 值 | 用途 |
| --- | --- | --- |
| `bg` | `#0d1117` | 页面背景 |
| `surface1` | `#161b22` | AppBar/面板/导航 |
| `surface2` | `#1c2128` | 卡片/浮层 |
| `border` | `#30363d` | 卡片/分隔线 |
| `accent` | `#58a6ff` | 强调/选中 |
| `text1` | `#e6edf3` | 主文字 |
| `text2` | `#8b949e` | 次要文字 |
| 圆角 | 卡片 10 / 缩略图 8 / 按钮 8 / 浮层 14 | 统一层级 |

页面 → 处理映射：

- 外壳：侧栏选中胶囊、底部 tab 选中态、页面脚手架 AppBar 层次。
- 首页/搜索：搜索框、错误/空态、悬浮续读条。
- 详情：头部面板、按钮、章节列表。
- 发现：主卡/侧卡圆角与阴影。
- 我的/列表：条目缩略图与文字层级。
- 阅读器：工具栏、进度条、目录、状态页。

## Implementation Units

### U1. ✅ 主题令牌与组件主题

- **Goal:** 建立集中设计令牌与全局组件主题，替换主题相关硬编码。
- **Requirements:** R1, R2, R9
- **Dependencies:** 无
- **Files:** `lib/theme.dart`（新建）、`lib/main.dart`
- **Approach:** 新建主题文件集中定义颜色/圆角/字体/间距与 `ThemeData` 组件主题（AppBar、Card、按钮、输入框、Slider、导航、Tab、SnackBar、Divider、进度指示器）；`main.dart` 引用并移除重复的组件样式。
- **Verification:** `flutter analyze` 无问题；全 App 默认组件呈现统一深色风格，无与自定配色冲突的默认样式。

### U2. ✅ 通用状态组件

- **Goal:** 空态/错误态抽成共用组件，全 App 一致。
- **Requirements:** R7, R9
- **Dependencies:** U1
- **Files:** `lib/widgets/status_views.dart`（新建）、`lib/screens/home_screen.dart`、`lib/screens/detail_screen.dart`、`lib/screens/discovery_screen.dart`、`lib/screens/search_screen.dart`、`lib/widgets/reading_lists.dart`、`lib/screens/reader_screen.dart`
- **Approach:** 提供 `StatusView`（图标+文案+可选按钮）与空态包装；各页错误/空态改为引用，删除重复实现。
- **Verification:** 各页错误与空态样式统一；重试行为不变。

### U3. ✅ 漫画卡片与网格

- **Goal:** 网格卡片视觉统一：封面圆角、边框/阴影、占位、文字层级、收藏角标。
- **Requirements:** R3, R9
- **Dependencies:** U1
- **Files:** `lib/widgets/comic_card.dart`、`lib/widgets/comic_grid.dart`
- **Approach:** 卡片用主题圆角（10）+ 细边框 + 轻阴影；封面占位统一；标题/作者字号与颜色走令牌；角标与话数标签统一样式。
- **Verification:** 桌面与手机网格观感统一；卡片高度计算不变（文字区高度保持一致）。

### U4. ✅ 外壳导航

- **Goal:** 桌面侧栏与手机底部 tab 视觉精修。
- **Requirements:** R6, R9
- **Dependencies:** U1
- **Files:** `lib/main.dart`
- **Approach:** 侧栏选中态用胶囊指示、图标与标签间距统一；底部 tab 选中态、图标填充与背景统一；页面脚手架 AppBar 加层次（分隔线）。
- **Verification:** 桌面/手机切换导航视觉统一，条目与切换逻辑不变。

### U5. ✅ 首页

- **Goal:** 首页 AppBar/搜索框、错误态、悬浮续读条视觉精修。
- **Requirements:** R7, R9
- **Dependencies:** U2, U3
- **Files:** `lib/screens/home_screen.dart`
- **Approach:** 搜索框走输入框主题；错误态用共用组件；悬浮续读条用主题圆角/阴影并统一文字层级。
- **Verification:** 首页各状态样式统一，搜索/刷新/续读条逻辑不变。

### U6. ✅ 详情页

- **Goal:** 详情头部面板化，按钮与章节列表视觉统一。
- **Requirements:** R5, R9
- **Dependencies:** U2, U3
- **Files:** `lib/screens/detail_screen.dart`
- **Approach:** 头部信息区用面板（surface2 + 边框 + 圆角）承载封面与信息；按钮走主题；章节列表缩略圆角与文字层级统一。
- **Verification:** 桌面双栏与手机纵向布局样式统一，收藏/续读/章节跳转逻辑不变。

### U7. ✅ 发现与搜索

- **Goal:** 发现主卡/侧卡与搜索页视觉精修。
- **Requirements:** R7, R9
- **Dependencies:** U2, U3
- **Files:** `lib/screens/discovery_screen.dart`、`lib/screens/search_screen.dart`
- **Approach:** 主卡与侧卡统一圆角/阴影/占位；序列提示与操作提示文字层级统一；搜索空/错误态用共用组件。
- **Verification:** 拖拽切换与点击开读逻辑不变；搜索行为不变。

### U8. ✅ 我的与列表

- **Goal:** "我的"页 Tab 与各列表项视觉统一。
- **Requirements:** R4, R6, R9
- **Dependencies:** U1, U2
- **Files:** `lib/screens/mine_screen.dart`、`lib/widgets/reading_lists.dart`
- **Approach:** 列表缩略图圆角 8 + 边框；标题/副标题走令牌；Tab 样式走主题；空态用共用组件。
- **Verification:** 三个列表样式统一，刷新与跳转逻辑不变。

### U9. ✅ 阅读器 chrome

- **Goal:** 阅读器工具栏、进度条、目录与状态页视觉精修，交互不变。
- **Requirements:** R8, R9
- **Dependencies:** U1, U2
- **Files:** `lib/screens/reader_screen.dart`、`lib/widgets/reader_progress_bar.dart`、`lib/widgets/chapter_drawer.dart`
- **Approach:** 进度条重做为细轨道样式（走 Slider 主题），工具栏按钮与标题用令牌，目录列表与选中态统一，章节失败/空态用共用组件；保持点击呼出、滚轮翻页等行为。
- **Verification:** 阅读器视觉协调；键盘/沉浸/重试/续章等交互行为全部不变。

## Acceptance Examples

- AE1. 桌面首页网格卡片圆角/阴影/文字统一，收藏角标可读。Covers R3。
- AE2. 全 App 空态与错误态使用同一组件。Covers R7。
- AE3. 阅读器进度条与工具栏协调，滚轮翻页、点击呼出行为不变。Covers R8。
- AE4. 默认组件不再与自定配色冲突。Covers R2。

## Scope Boundaries

**Deferred to Follow-Up Work**

- 浅色主题、封面图重绘、图标重绘、动画体系、布局结构调整。

## Risks & Dependencies

- 阅读器文件与 PR #8 有叠加：UI 分支基于 reader-ux-desktop 分支，建议先合并 #8 再合 UI PR，diff 会自动收敛。
- 卡片高度计算依赖文字区固定高度：调整字体/间距时保持文字区高度不变，避免网格卡片高宽比漂移。

## Spec Impact

- `specs/ui-style.convention.md` — new：记录全 App 设计令牌（颜色/圆角/字体/间距）与组件规范，作为后续 UI 改动的约定。
