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
| `dart format --output=none --set-exit-if-changed lib/ test/` | 只检查格式，格式不符时失败；CI 门禁 |
| `flutter analyze` | 静态分析与 `flutter_lints` 校验，CI 门禁 |
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

若终端停留在仓库根目录，可以使用以下 PowerShell 写法。Flutter 和 Dart 命令
仍在 `app/` 内执行，避免遗漏 `app/` 前缀：

```powershell
Push-Location app
dart format lib/ test/
Pop-Location
```

只校验、不修改文件：

```powershell
Push-Location app
dart format --output=none --set-exit-if-changed lib/ test/
flutter analyze
flutter test
Pop-Location
```

任一校验返回非零退出码时应先修复问题，再提交。

## 后端终端命令

以下命令均从 `backend/` 执行。CI 使用 Node.js **24.11.1** 和 pnpm **10.24.0**，
通过 `pnpm install --frozen-lockfile` 恢复依赖，运行 `pnpm run lint` 完成后端门禁。

首次开发执行 `pnpm install` 安装依赖。下表按 `package.json` 的 `scripts` 顺序列出，每个入口只出现一次。

| 命令 | 用途及实际影响 |
| --- | --- |
| `predev`（自动钩子） | 执行 `npm run dev` 前自动调用 stop，无需手动执行 |
| `npm run dev` | Windows 自动清理配置端口后启动热重载开发服务；其他平台提示跳过清理后启动 |
| `npm run stop` | Windows 结束配置端口上的监听进程；其他平台提示跳过，需手动停止旧服务 |
| `npm run build` | 编译 TypeScript 到 `dist/` |
| `npm run start` | 运行已编译的 `dist/server.js`，需先构建 |
| `npm run lint` | 依次执行格式检查、lint、构建（含类型检查）、测试；生成 dist，测试可启动本机临时 HTTP 服务，不连接业务数据库；CI 门禁 |
| `npm run fix` | 先自动修复 lint，再格式化 src 下的 TypeScript 文件；lint 仍有错误或警告时返回失败并停止后续格式化 |
| `npm run setup` | 初始化数据库、扫描并增量导入漫画、可选清理项目 Redis 缓存；保留已有 ID |
| `npm run setup:waifu2x` | 重新下载与更新 Windows 超分引擎，日常启动不需要执行 |
| `npm run db:init` | 初始化数据库并补齐既有表约束；需要 MySQL |
| `npm run comics:sync` | 扫描漫画目录、增量导入本次结果、可选清缓存；用于已有数据库的日常更新 |
| `npm run comics:organize` | 先展开 original，再将无子目录漫画的根图片归入第1話；不更新数据库 |
| `npm run comics:fix-chapter-order` | 不重扫磁盘，修复数据库章节排序和封面，再可选清缓存 |
| `npm run cache:clear` | 清理本项目 Redis 缓存；Redis 不可用时失败；加 `-- --optional` 可在不可用时跳过 |

`comics:organize` 的参数示例（同一个命令，不是额外入口）：

```powershell
# 预览配置的漫画库，不修改文件
npm run comics:organize -- --dry-run

# 预览单个漫画
npm run comics:organize -- --comic "<漫画目录>" --dry-run

# 预览指定漫画库；--root 与 --comic 互斥
npm run comics:organize -- --root "<漫画库>" --dry-run
```

去掉 `--dry-run` 即实际执行整理。

维护命令按 `db:*`、`comics:*`、`cache:*` 分组，各入口直接执行对应脚本，不保留旧名称别名。
`setup` 组合 `db:init` 与 `comics:sync`；同步内部依次扫描、导入和可选清缓存，必需阶段失败即停止。
同步使用本次扫描结果，`data/scan.json` 仅保留供检查，不作为下一次同步的输入。
目录整理遇到同名目标不覆盖，保留冲突项和未清空的 original，报告非零退出状态；
单个漫画出错后继续处理其余漫画，已完成的移动不回滚。含直接符号链接的漫画跳过并报错，
不跟随库内的链接目录；已有子目录或第1話同名目标时不归章。

目录整理命令直接移动磁盘文件；执行前确认 `backend/.env` 中的漫画目录及数据备份，
整理后运行 `npm run comics:sync` 同步数据库。导入不删除旧章节或旧图片索引，
已导入的漫画改路径后仍可能需要人工核对旧索引。Windows 端口清理精确匹配本地监听端口；清理失败时返回失败并阻止开发启动。
其他平台提示跳过自动清理并成功返回，不阻止 dev 启动；端口已被占用时需手动停止旧服务。
端口清理命令作用于配置端口上的监听进程，
并不限于本项目启动的服务。

日常只使用 `npm run fix` 与 `npm run lint`。lint 任一步失败即停止，构建同时
完成类型检查，不再重复执行 tsc --noEmit；后端测试不需要 MySQL、Redis 或漫画目录。
fix 会修改源码，不能自动修复的问题需按输出手动修正；修复后仍须运行 lint。
`.gitattributes` 将 TypeScript 文件的检出换行固定为 LF，与 Prettier 保持一致。

## PowerShell 手动发版

从仓库根目录执行。脚本入口仍为 `scripts/release.ps1`；它会写发布文件、自动提交
并创建本地标签，运行前确保暂存区和已跟踪文件没有其他未提交修改。

```powershell
git fetch origin master
git switch -c codex/release-1.0.6 origin/master
Push-Location app
dart format --output=none --set-exit-if-changed lib/ test/
flutter analyze
flutter test
Pop-Location
Push-Location backend
npm run lint
Pop-Location
# 全部检查通过后再继续
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
