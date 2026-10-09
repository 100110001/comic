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
- CI 按本次改动范围独立执行两个项目的完整门禁：`app/` 改动执行 Flutter 检查，
  `backend/` 改动执行后端检查；混合改动检查两边，包括各项目内的文档、资源和依赖。
- 仅修改根级 `Readme.md`（名称大小写不敏感）、`AGENTS.md`、`CHANGELOG.md`，
  或 `docs/`、`specs/`、`.claude/` 下的 Markdown 文档时，免于两边项目门禁。
  CI、共享配置和白名单外的文件改动保守执行两边检查。
- 文档免检和项目范围判断在工作流内部执行，仍产生 `check` 状态；不通过顶层路径
  过滤省略必需检查。免检仅省去项目环境准备和门禁，仍执行检出与范围判断。
- PR 范围覆盖基准提交到测试合并提交的差异，push 范围覆盖推送前后差异；移动文件
  同时计入来源和目标项目。首次推送没有基准时检查两边，无法取得或判断差异时失败，
  不以范围未知为由跳过检查。
- Flutter CI 固定使用 3.38.9，并从 `app/` 执行依赖恢复、`lib/` 与 `test/` 的只读
  格式检查、静态分析（包含 `flutter_lints`）和测试；格式或分析问题使检查失败。
- 后端 CI 独立使用 Node.js 24.11.1、pnpm 10.24.0，从 `backend/` 按
  `pnpm-lock.yaml` 冻结恢复依赖，执行 Prettier 格式检查与 TypeScript ESLint
  推荐规则校验；lint 的错误和警告均使检查失败。校验不启动服务或连接业务数据库。
- 后端格式化与只读格式校验均覆盖 `src/**/*.ts`，对应 `npm run format` 与
  `npm run format:check`；`npm run lint` 只检查，`npm run lint:fix` 修复可修复
  问题。TypeScript 文件检出时使用 LF，避免 Windows 换行转换造成格式误报。
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
