---
status: complete
scope: convention
---

# 项目目录与协作边界

## Responsibilities

规定仓库根目录、Flutter 应用和 Node.js 后端的职责边界，以及开发、CI、发版和
项目文档应采用的统一入口。

## Rules

- `app/` 是完整 Flutter 项目，包含源码、测试、平台工程、依赖清单、Flutter
  工具元数据和 Windows 安装器。Flutter、Dart 与 Inno Setup 命令均从该目录执行。
- `backend/` 是独立 Node.js 后端项目，其依赖、构建、数据库和内容维护命令均从
  该目录执行。
- 仓库根目录只承载两个项目共享的规范、CI、文档、变更工具、发布协调脚本和发布
  元数据，不同时充当某个项目的构建根目录。
- Flutter CI 固定使用 3.38.9，并从 `app/` 执行依赖恢复、静态分析和测试。后端按
  项目偏好不纳入该构建门禁。
- 根级 `scripts/release.ps1` 协调应用版本、安装器版本、根级更新清单、更新日志、
  Git 提交与版本标签；Flutter 与安装器构建在 `app/` 内完成。
- GitHub Release 对外提供 `comic-setup.exe` 和 `app-release.apk`；仓库内部目录调整
  不改变资产名称和更新清单中的公开下载地址。
- Flutter 生成文件和构建产物位于 `app/` 的项目边界内并保持忽略；已纳入版本控制
  的 Windows 安装包位于 `app/installer/`。
- 项目自有的人类可读文档只使用中文，不为同一内容维护英文副本。代码标识、路径、
  命令、外部专有名词及 `.claude/` 下禁止原地修改的上游同步文件保留原文。

## Notes

- 根目录是 `scripts/release.ps1` 的调用入口；该脚本负责在仓库级文件与应用级文件
  之间协调发版。
- 应用内部路径以 `app/` 为项目根；例如 Flutter asset key 和平台工程相对路径不含
  仓库级 `app/` 前缀。
