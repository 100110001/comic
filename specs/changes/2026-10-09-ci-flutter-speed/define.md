---
title: 缩短 Flutter CI 环境准备时间
date: 2026-10-09
---

# 变更定义

- 保留完整格式、分析和测试门禁及按改动范围检查规则。
- 仅迁移 Flutter 检查 runner；Windows 发布构建继续使用 Windows。
- 基于同一依赖版本比较 Ubuntu 缓存命中运行与 Windows 基线，并比较 pub 缓存开关。
- 不承诺固定加速比例，以云端实测作为配置选择依据。
- 用户已授权继续实施；变更流程在同一分支完成，最后创建目标 master 的 PR。