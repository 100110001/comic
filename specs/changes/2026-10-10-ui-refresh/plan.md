---
title: 全应用 UI 改版实施计划
date: 2026-10-10
origin: specs/changes/2026-10-10-ui-refresh/define.md
---

# 全应用 UI 改版实施计划

## 概述

沿用现有 Flutter Material 3、AppColors 和 Riverpod，将已确认的简洁书库视觉应用到实际页面，不照搬预览中的示例业务行为。用户要求同一分支完成循环并提交一个 PR。

## 需求

- R1. 统一两套配色、圆角、字体层级与弱化面板样式。
- R2. 首页搜索和封面、桌面导航、书库、详情与发现保持功能并统一视觉。
- R3. 设置响应式重组，保持真实状态和持久化；阅读器保留沉浸与操作契约。
- R4. 验证 320px、大字体、桌面布局，并运行五项本地门禁。

## 关键决策

- 使用现有主题与控件，避免引入在线字体或新依赖。
- 互斥选项继续使用 ChoiceChip，统一为低描边的分段视觉并允许换行。
- 保留首页浮条、详情独立滚动和发现三卡；仅改善间距与可用尺寸。
- 减少灰色卡片外框，保留输入框与焦点反馈的可识别性。

## 实施单元

### U1. 主题、外壳、封面与设置（已完成）

- 文件：app/lib/theme.dart、app/lib/main.dart、app/lib/widgets/comic_card.dart、app/lib/screens/settings_screen.dart。
- 方式：统一色值和圆角，弱化侧栏，去封面文字区底框，重组设置。
- 验证：现有主题、网格、设置持久化与大字体测试。

### U2. 首页、书库、详情、发现及阅读器（已完成）

- 依赖：U1。
- 文件：app/lib/screens/home_screen.dart、search_screen.dart、mine_screen.dart、detail_screen.dart、discovery_screen.dart、reader_screen.dart；app/lib/widgets/reading_lists.dart、chapter_drawer.dart、reader_progress_bar.dart、status_views.dart。
- 方式：共享主题覆盖，调整页面排版和控件，发现按内容约束布局；业务逻辑保持。
- 验证：小屏与大字体、空态和错误重试，阅读定位、键盘与超分现有回归。

### U3. 验证与规范收割（验证完成，执行收割）

- 依赖：U2。
- 文件：app/test/ui_layout_test.dart；规范影响中列出的文件。
- 方式：运行项目完整门禁，渲染实际 Flutter 页面，自审最终 diff，规范描述最终实现并删除本目录。

## 规范影响

- specs/ui-style.convention.md：更新配色、圆角、封面、设置、导航及页面样式约定。
- specs/settings.spec.md：记录阅读与外观的合并分组。
- specs/discovery.spec.md：记录内容约束与窄窗口可滚动性。

## 风险

- 字体缩放会改变选择项宽度与行高，使用自然布局并扩展现有测试。
- 发现页需同时受可用宽高约束，不使用屏幕总宽推算侧栏内封面。
