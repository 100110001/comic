---
title: 超分后十页滑动窗口方案
date: 2026-10-09
---

# 超分后十页滑动窗口方案

## 目标与范围

落实 R1—R4，超分窗口为当前页加后十页，共最多十一项。

## 技术决策

- 当前页、手动重试与阅读推进共享窗口大小；接口提交和轮询同步允许十一项。
- 保留后端任务去重、缓存及当前页优先；引擎改造保留为后续工作。
- 增强等待上限十二分钟，容纳默认单图一分钟时十一项连续处理；等待期间始终显示原图。

## 实现单元

### U1. 已完成：后十页滑动窗口

依赖：无。修改 app/lib/screens/reader_screen.dart、settings_screen.dart、app/lib/providers/super_resolution_provider.dart、backend/src/routes/images.ts、super-resolution.ts 与服务的窗口常量。

验证：既有测试扩展一百页示例的 1—11、8—18、95—100 窗口及关闭回退，执行五项门禁。

## 规范影响

更新 specs/super-resolution.spec.md 的最多十一项接口契约。
更新 specs/reader.spec.md、specs/data-layer.convention.md 的后十页窗口、章末截断及十二分钟等待。
