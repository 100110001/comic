---
title: 安卓固定签名实现计划
date: 2026-10-19
origin: specs/changes/2026-10-19-android-fixed-signing/define.md
---

# 安卓固定签名实现计划

## 概述

落实 R1–R3，发布密钥由环境变量提供，GitHub Secrets 持久保存。

## 技术决策

- Gradle release 使用独立签名配置，发布任务缺少配置或文件时明确失败；debug 不受影响。
- CI 在运行器临时目录还原密钥，构建后始终清理，密码仅注入必要步骤。
- 不自动生成每次发布的新密钥；一次性生成及备份由维护者在安全环境完成。

## 实现单元

### U1. 固定签名与发布配置

依赖：无。
文件：app/android/app/build.gradle.kts、.github/workflows/release.yml、.gitignore、docs/android-signing.md、Readme.md。
验证：执行仓库五项门禁，检查 debug 构建和缺少配置的 release 拒绝路径；真实签名 APK 需维护者配置密钥后验证。

## Spec Impact

- specs/project-layout.convention.md：更新安卓发布固定签名、缺失配置失败及密钥保密要求。

## 范围边界

不修改版本号策略，不处理已安装旧版迁移。按用户偏好整个循环使用同一分支和面向 master 的 PR。
