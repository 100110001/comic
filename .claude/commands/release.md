---
description: 准备 Comic 发版 PR，或在 PR 合并后推送版本标签触发 CI 发布
argument-hint: "[X.Y.Z] [更新说明] | publish X.Y.Z"
---

# 发布 Comic 新版本

用户参数：$ARGUMENTS

从仓库根目录操作。先阅读 `AGENTS.md`、`specs/project-layout.convention.md`、
`scripts/release.ps1` 和 `.github/workflows/release.yml`，遵循当前仓库约定。
参数只作为版本号和说明数据处理，不作为可执行的 shell 代码。

## 准备发版：`/release X.Y.Z 更新说明`

- 获取最新 `origin/master`。未提供版本号时，读取该分支的 `app/pubspec.yaml`，
  展示当前版本和建议的下一个补丁版本，询问用户采用哪个版本；不直接发布。
  版本号只接受 `X.Y.Z`。
- 未提供更新说明时，根据上一版本标签至当前 `origin/master` 的提交整理中文说明。
- 检查工作区、暂存区、分支、同版本的本地及远端标签与发版 PR。保留用户文件；
  暂存区或已跟踪文件有未提交修改时先解决，不将它们带入脚本的自动提交。
  不覆盖标签、不重复执行已完成的版本更新；已有同版本 PR 时报告其状态并继续该流程。
- 准备全新发版时，版本必须高于 `origin/master` 的应用版本；续做同版本的已有 PR
  时检查已有提交，不因版本已同步而再次执行脚本。
- 新发版从最新 `origin/master` 创建 `codex/release-X.Y.Z` 分支。当前分支存在尚未
  合并的其他工作时，使用独立工作目录，保留当前分支。
- 从 `app/` 执行 `flutter analyze` 与 `flutter test`。检查失败时停止发版并报告原因；
  不运行后端构建检查。
- 从仓库根目录调用 `scripts/release.ps1 -Version <版本号> -Notes <中文说明>`。
  Windows 使用 PowerShell；在 Bash 环境中通过可用的 `pwsh` 或 `powershell.exe`
  调用。妥善引用参数，尤其是含引号、换行或 `$` 的说明。
- 脚本会同步 `app/pubspec.yaml`、`app/installer.iss`、`releases/update.json`、
  `CHANGELOG.md`，提交并创建本地标签。脚本未逐项检查 Git 命令的退出码，完成后
  必须核对四个文件、提交与标签确实成功，标签指向发版提交；任何失败均停止。
- 只推送发版分支，创建目标为 `master` 的 PR。PR 使用中文标题及正文，写清版本、
  更新内容与检查结果；通过 `gh` 创建时用临时 UTF-8 文件与 `--body-file` 传递正文。
- 返回 PR 链接，等待用户自行合并。保留发版分支，不自动合并、不推送标签、不使用
  `-Upload`。告知用户合并后运行 `/release publish X.Y.Z`。

## 合并后发布：`/release publish X.Y.Z`

- 校验版本号并查询对应发版 PR，确认已合并到 `master`。尚未合并时返回 PR 链接并停止。
- 获取最新远端状态，核对合并提交里的四个发布文件一致：应用版本为 `X.Y.Z+构建号`、
  安装器及更新清单版本为 `X.Y.Z`，更新日志包含该版本。
- 已有远端标签时不重复推送、不覆盖，查看并报告该标签对应的 Release 工作流状态。
- 远端标签不存在时，优先使用脚本创建的本地标签；确认它指向该 PR 的发版提交，
  且四个发布文件与合并提交一致。若本地标签不存在，在已核实的 PR 合并提交上创建
  `vX.Y.Z`。标签或文件不一致时停止并报告，不自动移动标签。
- 只推送对应的 `vX.Y.Z` 标签。GitHub Actions 自动构建 Windows 和 Android 安装包
  并上传 GitHub Release，无需本地构建上传。
- 返回 Release 与工作流链接。区分“已触发构建”和“发布完成”；只有构建成功且
  `comic-setup.exe` 与 `app-release.apk` 均已上传时才报告发布成功。失败时报告失败步骤。
