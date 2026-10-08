# 项目命令速查

## Claude Code 聊天命令

在本仓库中启动 Claude Code，然后在聊天输入框输入以下命令；不要在 PowerShell
中直接输入斜杠命令。

| 命令 | 用途 | 定义位置 |
| --- | --- | --- |
| `/br-define <需求>` | 定义问题、范围与预期结果 | `.claude/skills/br-define/SKILL.md` |
| `/br-plan <需求或定义路径>` | 制定实施计划及规范影响 | `.claude/skills/br-plan/SKILL.md` |
| `/br-work <计划路径>` | 按计划实施变更并创建 PR | `.claude/skills/br-work/SKILL.md` |
| `/br-reaper <变更目录>` | 将已完成变更收割到规范并清理过程文档 | `.claude/skills/br-reaper/SKILL.md` |
| `/release <X.Y.Z> <更新说明>` | 同步发布文件、创建发版 PR，等待用户合并 | `.claude/commands/release.md` |
| `/release publish <X.Y.Z>` | 确认发版 PR 已合并后推送标签，触发 CI 发布 | 同上 |

四个 `br-*` 技能和 `.claude/spec-conventions.md` 从上游同步，不原地修改。
执行时以 `AGENTS.md` 的仓库偏好为准：从 `master` 创建 `codex/<slug>`，同一变更
在同一分支完成，PR 由用户自行合并。

例如准备下一版本（版本号按实际情况替换）：

```text
/release 1.0.6 优化阅读体验，修复搜索问题
```

合并该命令创建的 PR 后，再运行：

```text
/release publish 1.0.6
```

单独输入 `/release` 会先询问版本号。新增命令若未显示，重新打开本项目的
Claude Code 会话后再输入 `/` 查看命令列表。

## Flutter 终端命令

以下命令均从 `app/` 执行。CI 固定 Flutter **3.38.9**，依赖以 `pubspec.lock` 为准。

| 命令 | 用途 |
| --- | --- |
| `flutter pub get` | 按锁定文件恢复依赖 |
| `flutter analyze` | 静态分析，变更完成门禁 |
| `flutter test` | 执行测试，变更完成门禁 |
| `flutter run -d windows` | 运行 Windows 应用 |
| `flutter run -d chrome` | 运行 Web 开发版本 |
| `flutter devices` | 列出设备，随后可用 `flutter run -d <设备 ID>` |
| `flutter doctor` | 检查开发环境 |
| `dart format lib/ test/` | 格式化应用与测试代码 |
| `flutter pub outdated` | 查看可升级依赖 |
| `flutter pub upgrade` | 升级约束范围内的依赖并更新锁定文件 |
| `flutter pub upgrade <包名>` | 升级指定依赖 |
| `flutter build windows --release` | 构建 Windows 应用 |
| `flutter build apk --release` | 构建 Android APK |
| `ISCC installer.iss` | 构建 Windows 安装器，需先构建 Windows 应用 |
| `flutter build web` | 构建 Web 静态资源 |
| `flutter pub run msix:create` | 构建 MSIX，需先构建 Windows 应用；版本另见 `pubspec.yaml` 的 `msix_config` |

运行中的 Flutter 终端可按 `r` 热重载、`R` 热重启。

## 后端终端命令

以下命令均从 `backend/` 执行。后端按项目偏好不纳入 Flutter 构建门禁。

| 命令 | 用途及实际影响 |
| --- | --- |
| `pnpm install` | 安装后端依赖 |
| `npm run dev` | 自动结束配置端口上的旧监听进程，再启动支持热重载的开发服务 |
| `npm run stop` | 结束配置端口上的监听进程 |
| `npm run build` | 编译 TypeScript 到 `dist/` |
| `npm run start` | 运行已编译的 `dist/server.js`，需先构建 |
| `npm run setup` | 初始化数据库、扫描并增量导入漫画、可选清理项目 Redis 缓存；保留已有 ID |
| `npm run clear-cache` | 清理本项目 Redis 缓存；Redis 不可用时失败 |
| `npm run format` | 使用 Prettier 格式化 `src/**/*.ts` |
| `npm run reorganize-chapters` | 将无子目录漫画的根目录图片移动到 `第1話/`，改变实际文件路径 |
| `npm run flatten-original` | 批量将漫画 `original/` 的内容上移，删除腾空的 `original/`；同名目标跳过 |
| `npm run flatten-original -- "<目录>"` | 对指定漫画目录或库目录执行上移 |
| `npm run fix-chapter-order` | 按章节标题重排数据库章节顺序，并更新封面 |

目录整理命令直接移动磁盘文件；执行前确认 `backend/.env` 中的漫画目录及数据备份，
整理后运行 `npm run setup` 同步数据库。端口清理命令作用于配置端口上的监听进程，
并不限于本项目启动的服务。

## PowerShell 手动发版

从仓库根目录执行。脚本入口仍为 `scripts/release.ps1`；它会写发布文件、自动提交
并创建本地标签，运行前确保暂存区和已跟踪文件没有其他未提交修改。

```powershell
git fetch origin master
git switch -c codex/release-1.0.6 origin/master
Push-Location app
flutter analyze
flutter test
Pop-Location
# 两项检查通过后再继续
.\scripts\release.ps1 -Version 1.0.6 -Notes "本次更新内容"
git push -u origin codex/release-1.0.6
gh pr create --base master --title "发布 v1.0.6" --body "更新版本号及发布说明"
```

检查四个发布文件、提交和本地标签正确，并自行合并 PR 后，再执行：

```powershell
git push origin v1.0.6
```

GitHub Actions 的 `Release` 工作流会构建并上传 `comic-setup.exe` 与 `app-release.apk`。
推送标签只是触发构建，工作流成功且两个资产均上传后才算发布完成。
`-Upload` 会直接在本机构建、上传并推送，正常走 CI 与 PR 流程时不使用。

需要手动补传已构建的安装包时，先在 `app/` 执行 Windows、APK 与安装器构建，
再回到仓库根目录执行（版本号按实际情况替换）：

```powershell
gh release upload v1.0.6 --clobber app/installer/comic-setup.exe app/build/app/outputs/flutter-apk/app-release.apk
```
