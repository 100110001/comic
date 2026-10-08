## 规范与变更循环

- 规范文件（`*.spec.md`、`*.convention.md`）是本仓库设计的事实源。开始处理某个
  区域前先搜索相关规范；代码应以规范为准，而不是反过来。
- 完整规范格式及 **定义 → 计划 → 实现 → 收割** 变更循环位于
  `.claude/spec-conventions.md`。该文件同步自 `brindlechute/playbook`，不要原地
  修改。
- 使用 `.claude/skills/` 下的 `br-define`、`br-plan`、`br-work`、`br-reaper`
  运行变更循环。这些技能同样由上游同步，不要原地修改。

## 项目边界

- `app/` 是完整 Flutter 项目。Flutter、Dart、Android、iOS、Web、Windows 和
  Inno Setup 相关命令均从该目录执行。
- `backend/` 是独立 Node.js 后端项目，其命令从该目录执行。
- 仓库根目录用于共享规范、CI、文档和发版协调；根级 `scripts/release.ps1`
  负责跨应用目录与仓库级发布元数据的发版流程。

## 构建与 CI 门禁

在认为一个 `br-work` 单元完成前，从 `app/` 运行：

```bash
flutter analyze
flutter test
```

后端位于本仓库中，但按用户偏好不纳入构建检查。GitHub Actions 位于
`.github/workflows/`：push/PR 使用固定的 Flutter **3.38.9** 运行
`flutter analyze` 与 `flutter test`；推送 `v*` 标签后自动构建 Windows 和
Android，并上传 GitHub Release。Flutter 依赖由已提交的 `app/pubspec.lock`
锁定。

## 提交约定

提交消息不要求附加 trailer。

## 文档语言

- 本项目的人类可读文档只使用中文，包括 README、spec、convention，以及
  `define.md`、`plan.md`、`learnings.md` 等变更过程文档。
- 不为同一内容维护额外的英文版本。代码标识、文件路径、命令和外部专有名词
  保持原样，不强行翻译。
- `.claude/` 下明确标注为上游同步的文件不受中文化要求约束，也不得为此原地修改。

## 变更工作流（用户偏好）

- 每项新工作都从 `master` 创建独立分支（`codex/<slug>`），整个变更循环在同一
  分支完成。
- 变更完成后创建目标为 `master` 的 PR，由用户自行合并。
- PR 打开期间继续在该分支工作；合并前不要切回 `master`。
