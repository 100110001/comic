---
title: 超分连续预处理方案
date: 2026-10-09
---

# 超分连续预处理方案

## 目标与范围

实现 R1—R4：五页请求窗口与后台小批处理；保留当前页优先、错误回退、任务去重和代际取消。

## 技术决策

- 当前页独立处理，后台每批最多两张，降低新当前页等待批次的时间和流水线内存压力。
- 同批复用一次官方目录模式启动，采用单推理线程与加载/保存流水线；降低引擎重启开销，不以提高利用率读数为目标。
- 输入复制到缓存外的原文件保持完整；临时目录位于衍生缓存，发布仍逐图检查尺寸与源文件状态。
- 运行中的批次不抢占；新当前页在下一批优先。失败批次中仍可发布有效结果，清理后旧批次不发布。
- 批次总超时按图片数量乘单图上限；客户端轮询上限扩大到五分钟，覆盖五页串行最坏情况。

## 实现单元

### U1. 五页窗口与后台流水线

依赖：无。涉及 backend/src/services/super-resolution.ts、backend/src/routes/images.ts、backend/src/routes/super-resolution.ts、app/lib/screens/reader_screen.dart、app/lib/screens/settings_screen.dart、app/lib/providers/super_resolution_provider.dart 以及既有阅读器测试。

验证：执行五项仓库门禁；使用无敏感内容的固定样图比较五张逐图启动与小批处理总耗时，验证真实 GPU 输出、清理取消和逐图发布失败隔离。

## 规范影响

更新 specs/super-resolution.spec.md：五项接口限制、小批流水线、清理与批次超时。
更新 specs/reader.spec.md、specs/data-layer.convention.md：当前及后四页超分窗口与五分钟轮询上限，原图预加载范围不变。
