---
title: Flutter CI 提速实施计划
date: 2026-10-09
origin: specs/changes/2026-10-09-ci-flutter-speed/define.md
---

# 实施计划

## 概述

Windows 环境准备约占任务耗时的一半，缓存解压是已确认瓶颈。保留门禁，优化运行环境和重复依赖恢复。

## 需求

- R1. Flutter 3.38.9 的完整检查在 Ubuntu 成功，范围判断保持兼容。
- R2. Windows 发布工作流及后端检查配置保持现状。
- R3. 区分首次运行与缓存命中，记录 pub 缓存开关的实测结果。

## 关键决策

- 固定 ubuntu-24.04 以避免 runner 系统漂移；现有 pwsh 范围脚本跨平台执行。
- 已执行 pub get 后，分析与测试使用 --no-pub；本地完成门禁仍按 AGENTS 原命令运行。
- 先验证开启 pub 缓存，再重复运行取得缓存命中结果，随后关闭缓存对比；选择更快配置，样本不足时保留缓存。

## 实施单元

### U1. 云端验证与配置选择

- 文件：.github/workflows/ci.yml。
- 验证：五项本地门禁，Ubuntu 完整门禁、范围脚本兼容性、冷缓存与缓存命中运行、pub 缓存开关对比。

## 规范影响

- specs/project-layout.convention.md：Flutter 检查 runner 和重复依赖恢复策略；Windows 发布仍在 Windows 执行。
- AGENTS.md：同步云端检查环境说明。

## 延后

测试拆分、SDK 精简缓存、自托管 runner 和构建平台迁移均不在范围内。