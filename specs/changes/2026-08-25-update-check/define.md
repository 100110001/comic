---
date: 2026-08-25
topic: update-check
---

# 版本管理与检查更新（App 内更新）

## Summary

建立版本管理流程并在 App 内提供检查更新：以 `pubspec.yaml` 为单一版本源，`release.ps1` 一键同步版本并生成更新清单；设置页"关于"区检查更新，Windows 静默安装、Android 唤起系统安装器。

## Problem Frame

项目目前没有版本管理：pubspec、installer.iss、下载地址各管各的，容易漂移；也没有 App 内检查更新的能力。主仓库私有，更新清单与安装包放在独立公开 releases 仓，免 token。

## Key Decisions

- **单一版本源**：`pubspec.yaml` 的 `version`；脚本同步 `installer.iss`、生成 `update.json`、打 `vX.Y.Z` tag。
- **更新源**：公开 releases 仓（默认 `100110001/comic-releases`）的 `update.json`，含 Windows/Android 下载地址。
- **App 内更新**：Windows 下载安装包后静默安装（Inno `/VERYSILENT`，UAC 一次授权）；Android 下载 APK 后唤起系统安装器（`REQUEST_INSTALL_PACKAGES` + `open_filex`）。
- **入口**：设置页"关于"区，显示当前版本 + 检查更新。

## Requirements

- R1. `pubspec.yaml` 为唯一版本源，发布脚本同步 installer/update.json/tag。
- R2. 设置页显示当前版本并可手动检查更新。
- R3. 检查到新版本后提示版本号与更新说明，可一键下载并安装。
- R4. Windows 静默安装新版本；Android 通过系统安装器安装 APK。
- R5. 检查失败可重试；下载过程显示进度。
- R6. 更新清单地址集中配置（`config.dart` 常量）。

## Acceptance Examples

- AE1. 跑 `release.ps1 -Version 1.0.1` 后 pubspec/installer/update.json/tag 版本一致。Covers R1。
- AE2. 设置页"检查更新"在有新版本时显示"发现 vX"，点击下载并安装。Covers R2–R4。
- AE3. 无网络或清单不存在时提示失败并可重试。Covers R5。

## Scope Boundaries

**Deferred for later**

- 启动时自动检查更新（先手动）、增量下载/断点续传、安装包校验（哈希）。
