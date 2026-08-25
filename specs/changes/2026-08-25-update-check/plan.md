---
title: 版本管理与检查更新
type: feat
date: 2026-08-25
origin: specs/changes/2026-08-25-update-check/define.md
---

# 版本管理与检查更新

## Summary

单一版本源 + 发布脚本；设置页"关于"区检查更新，Windows/Android App 内更新。

## Requirements

- R1. pubspec 单一版本源，脚本同步各文件与 tag。
- R2. 设置页显示当前版本 + 检查更新。
- R3. 新版本提示并可一键下载安装。
- R4. Windows 静默安装 / Android 系统安装器。
- R5. 失败可重试、下载有进度。
- R6. 清单地址集中配置。

## Key Technical Decisions

- 版本比较：`package_info_plus` 读本地版本，与清单 `latestVersion` 做数字段比较（忽略 build 号）。
- 下载：`http` 写入系统临时目录；Windows 用 `Process` 启动 `/VERYSILENT` 安装；Android 用 `open_filex` 唤起系统安装器。
- 发布脚本：PowerShell，校验版本格式、同步 pubspec/installer、生成 `releases/update.json`、维护 CHANGELOG、打 tag；可选自动构建上传。

## Implementation Units

### U1. ✅ 依赖与配置

- **Goal:** 新增所需依赖与更新清单地址、Android 权限。
- **Requirements:** R6
- **Dependencies:** 无
- **Files:** `pubspec.yaml`、`lib/config.dart`、`android/app/src/main/AndroidManifest.xml`
- **Approach:** `pub add package_info_plus open_filex`；`config.dart` 增加 `kUpdateManifestUrl`；Manifest 加 `REQUEST_INSTALL_PACKAGES`。
- **Verification:** analyze 通过，依赖解析成功。

### U2. ✅ 更新服务与版本比较

- **Goal:** 拉取并解析更新清单、比较版本、下载文件。
- **Requirements:** R3, R5
- **Dependencies:** U1
- **Files:** `lib/models/update_info.dart`（新建）、`lib/services/update_service.dart`（新建）
- **Approach:** `UpdateInfo` 解析 `latestVersion/platforms/releaseNotes`；`fetchUpdateInfo` 带超时；`isNewer` 数字段比较；`downloadToTemp` 返回本地路径。
- **Verification:** 单元级手动验证比较函数与解析。

### U3. ✅ 设置页"关于"区

- **Goal:** 显示当前版本、检查更新、下载并安装。
- **Requirements:** R2, R3, R5
- **Dependencies:** U2
- **Files:** `lib/screens/settings_screen.dart`
- **Approach:** 转 `ConsumerStatefulWidget`；"关于"区显示版本 + 检查更新按钮；状态机 idle/checking/latest/available/error/downloading；可用时显示新版本与"下载并更新"。
- **Verification:** 各状态切换正确，错误可重试。

### U4. ✅ 平台安装

- **Goal:** Windows 静默安装、Android 唤起安装器。
- **Requirements:** R4
- **Dependencies:** U2
- **Files:** `lib/services/update_service.dart`
- **Approach:** Windows `Process.start(path, [/VERYSILENT,/SUPPRESSMSGBOXES,/NORESTART])` 后退出 App；Android `OpenFilex.open(path, type: 'application/vnd.android.package-archive')`。
- **Verification:** 平台分支正确，下载完成后触发安装。

### U5. ✅ 发布脚本与 CHANGELOG

- **Goal:** 一键同步版本并维护更新清单。
- **Requirements:** R1
- **Dependencies:** 无
- **Files:** `scripts/release.ps1`（新建）、`CHANGELOG.md`（新建）
- **Approach:** `-Version` 校验 `X.Y.Z`；同步 pubspec `version`、installer `AppVersion`；生成 `releases/update.json`（Windows/Android 下载地址模板）；追加 CHANGELOG（`-Notes` 可选）；`git tag vX.Y.Z`；打印构建与上传命令，`-Upload` 时自动执行。
- **Verification:** 跑一遍 `-Version 1.0.1` 后各文件一致、tag 生成。

## Acceptance Examples

- AE1. release 脚本同步全部版本。Covers R1。
- AE2. 设置页检查/下载/安装。Covers R2–R4。
- AE3. 失败可重试。Covers R5。

## Scope Boundaries

**Deferred to Follow-Up Work**

- 启动自动检查、断点续传、哈希校验。

## Spec Impact

- `specs/settings.spec.md` — updated：新增"关于"区（当前版本、检查更新、App 内更新）与版本管理约定。
