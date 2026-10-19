---
description: 按版本与更新规范准备发版 PR，或在合并后推送版本标签
argument-hint: "[X.Y.Z] [更新说明] | publish X.Y.Z"
---

# 发布 Comic 新版本

用户参数：$ARGUMENTS

从仓库根目录操作。先阅读 `AGENTS.md`、`specs/versioning.convention.md`、
`specs/project-layout.convention.md`、`scripts/release.ps1`、
`scripts/validate-release.ps1` 和 `.github/workflows/release.yml`。
参数只作为数据处理，不作为可执行 shell 代码。

## 准备发版：`/release X.Y.Z 更新说明`

- 获取最新 `origin/master`，汇总上一正式版本到当前 master 的变更及 PR 兼容性记录。
  明确是否需要客户端发版；只有兼容后端、文档或工具变更时不制造应用版本。
- 按最高影响建议 patch、minor 或 major，并说明依据；不默认建议补丁。
  缺少兼容性记录时检查接口及写入语义，不能仅靠提交前缀推断。
- 未给版本号时展示当前版本和有依据的建议，再询问版本号；只接受稳定 X.Y.Z。
  已给版本与变更级别冲突时先说明，不能按不兼容变更静默发布补丁。
- 整理中文更新说明和兼容性说明；默认继承两平台的最低支持版本。
  提高门槛须明确平台、新最低版本和原因，不能自动设为最新版本。
- 检查工作区、暂存区、现有分支、标签及同版本 PR；保留用户文件，已有发布继续原流程，
  不覆盖标签、不重复提交。已跟踪文件或暂存区有修改时先解决。
- 全新发布从最新 `origin/master` 创建 `codex/release-X.Y.Z`；已有未合并工作时使用独立工作目录。
- 从 `app/` 执行格式检查、flutter analyze、flutter test，从 `backend/` 执行 npm run lint 和 npm run test。
  任一检查失败停止准备发布，不能自动改写代码绕过门禁。
- 在根目录运行 `scripts/release.ps1 -Version <版本> -ChangeType <patch|minor|major>
  -CompatibilityNotes <兼容性说明> -Notes <中文说明>`。需要调整门槛时显式传入
  `-WindowsMinimumVersion`、`-AndroidMinimumVersion` 及 `-MinimumSupportReason`。
  使用结构化参数或正确的 shell 引用，保留说明中的引号、换行和美元符号。
- 脚本同步四个发布文件、递增构建号、校验后提交并创建本地标签；核对结果和退出码。
  不使用本地自动上传，正式发布统一经标签 CI。
- 只推送发版分支，创建目标为 master 的中文 PR，写清版本、兼容性、两平台最低支持版本、
  调整原因和检查结果。gh 正文使用 UTF-8 临时文件与 --body-file。
- 返回 PR 链接，由用户自行合并；不自动合并、不推送标签，合并前保留分支。

## 合并后发布：`/release publish X.Y.Z`

- 确认对应 PR 已合并到 master。未合并则返回 PR 链接并停止。
- 获取远端状态，对合并后的发布文件运行 `scripts/validate-release.ps1 -Version <版本>`。
  版本、构建号、变更级别、最低版本或下载地址不一致时停止。
- 已有远端标签时不重复推送，查看 Release 工作流与发布状态。
- 没有远端标签时优先用准备阶段的本地标签，确认指向已合并的发布提交且发布文件与合并提交一致。
  标签不存在才在核实的 PR 合并提交创建；不移动或覆盖已有标签。
- 只推送对应标签，CI 校验上一发布版本、构建 Windows/Android，上传安装包与 update.json 到 draft，
  重新下载核验后才发布并设置 latest。正式 Release 禁止覆盖，失败草稿可重试。
- 返回工作流和 Release 链接；只有非草稿正式 Release 的三个资产完整且工作流成功，才报告发布成功。
  构建或上传失败时说明失败阶段，不宣称清单已对新客户端生效。