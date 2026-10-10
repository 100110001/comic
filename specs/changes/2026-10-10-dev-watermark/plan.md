---
title: 开发版水印实现计划
type: feat
date: 2026-10-10
origin: specs/changes/2026-10-10-dev-watermark/define.md
---

# 开发版水印实现计划

## 概述

在应用外壳统一绘制构建水印，让页面导航、弹窗与阅读器共享同一标识。

## 需求

- R1. `debug` 与 `profile` 显示`DEVELOP`，`release` 隐藏。
- R2. 水印覆盖全部应用路由与弹窗。
- R3. 保持指针事件和界面布局，使用主题颜色。

## 技术决策

- 使用 Flutter 的 `kReleaseMode` 判断构建类型，沿用现有正式包的 `--release` 构建方式。
- 在 `MaterialApp.builder` 中使用 `Banner` 前景绘制左上角水印。水印使用独立的安全区浮层，并忽略指针事件。
- 背景使用 `AppColors.accent`，文字使用主题的 `onPrimary`，适配浅色与深色。

## 实现单元

### U1. 全局开发版角标（已实现并通过门禁）

- **依赖：** 无。
- **文件：** `app/lib/main.dart`、`app/lib/widgets/window_title_bar.dart`。
- **方式：** 保留全局鼠标侧键监听与 Windows 标题栏，在非正式构建中添加角标；Windows 标题文字向右留出水印空间。
- **验证：** 从 `app/` 执行格式检查、静态分析、现有测试；从 `backend/` 执行格式检查与 lint。审查正式构建分支和前景绘制命中行为。

## Spec Impact

- `specs/app-shell.spec.md`：记录水印的构建范围、全局可见性与交互约束。
- `specs/ui-style.convention.md`：记录角标位置及主题配色。
