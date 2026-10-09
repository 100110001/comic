---
title: 阅读器键盘换章实现计划
type: feat
date: 2026-10-09
origin: specs/changes/2026-10-09-reader-chapter-keys/define.md
---

# 阅读器键盘换章实现计划

## 概述

桌面阅读器现将 Page Up/Page Down 用于翻页，本次按用户确认的需求改为换章。

## 需求

- R1. 两键直接切上一章、下一章，目标从第一页开始。
- R2. 无对应章节时不动作，发现会话最后一章不通过 Page Down 续书。
- R3. 保留其他键的翻页与定位行为，以及手机连续滚动。

## 技术决策

复用 `_prevChapter`、`_nextChapter`，与工具栏共享边界检查、章节加载和断点记录。沿用桌面 `CallbackShortcuts`，无需新增焦点管理或平台事件处理。

## 实现单元

### U1. 桌面键盘换章

- 文件：`app/lib/screens/reader_screen.dart`、`app/test/reader_screen_test.dart`。
- 方案：调整两条键盘绑定；扩展现有阅读器测试夹具以提供多个章节。
- 验证：Widget 交互回归覆盖章中换章、进度条焦点、首末章边界、最后章不续书与本机断点；单章节不换页。该场景同时穿过快捷键、异步加载和进度记录，值得保留集成回归。
- 门禁：从 `app/` 运行 Dart 格式检查、Flutter 分析与全量测试，从 `backend/` 运行格式检查与 lint。

## 规范影响

更新 `specs/reader.spec.md`：Page Up/Page Down 切换上一章/下一章，与章内翻页的快捷键及越界语义分开描述。实现验证后收割，完整变更循环按仓库偏好保持在同一分支和最终 PR 中。
