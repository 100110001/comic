# Comic

漫画阅读应用：Flutter 前端 + Node.js 后端，支持 Windows 桌面、Android 与 Web。

## 功能特性

- **书库浏览与搜索**：随机洗牌网格、关键字搜索（标题/作者）、收藏角标。
- **发现**：随机阅读、拖拽切换、读完自动续下一本。
- **可选超分**：后端 waifu2x 2×，原图先显示、后台增强、失败回退与缓存清理。
- **阅读器**：桌面滚轮/键盘翻页、沉浸式工具栏、图片失败重试、阅读进度记录、自动续章。
- **我的**：最近阅读、收藏、收藏作者。
- **设置**：浅色/深色/跟随系统主题、关闭窗口最小化到托盘（Windows）、检查更新（App 内更新）。

## 技术栈

- Flutter（Riverpod 状态管理）
- Node.js + Express + MySQL + Redis
- Inno Setup（Windows 安装包）

## 项目结构

| 目录/文件 | 说明 |
| --- | --- |
| `app/` | 完整 Flutter 应用（源码、测试、平台工程和 Windows 安装器） |
| `backend/` | Node.js 后端 |
| `scripts/` | 发版脚本（`release.ps1`） |
| `specs/` | 设计规范（spec 是设计的事实源） |
| `releases/` | 应用更新清单 |

> 版本锁定：Flutter 固定 **3.38.9**（CI 已锁定）；Flutter 依赖锁定见 `app/pubspec.lock`（已提交），后端依赖见 `backend/pnpm-lock.yaml`。

Claude Code 聊天命令、Flutter 和后端终端命令、手动发版流程统一见
[项目命令速查](docs/commands.md)。

## 快速开始

### 1. 后端 `backend/`

```bash
cd backend

# 安装依赖
pnpm install

# 开发模式（热重载）
npm run dev                  # http://localhost:8888

# 初始化数据库 + 扫描文件 + 导入数据（首次或重新导入时使用）
npm run setup

# 格式化代码
npm run format

# 校验格式和 lint（CI 同样执行）
npm run format:check
npm run lint

# 构建（生产环境）
npm run build
npm run start
```

`setup` 是可重复执行的增量导入：已有漫画、章节和图片会复用原有 ID，收藏与
阅读进度不会因正常重新扫描而丢失，不需要也不应在重新导入前清空核心表。导入
成功后会自动失效本项目的 Redis 图片列表缓存；Redis 不可用时会提示并跳过缓存
清理，不影响数据库导入结果。

需要单独清理本项目缓存时运行：

```bash
npm run clear-cache
```

手动命令在 Redis 不可用时返回失败，方便脚本和运维发现缓存并未清理。

### 2. Flutter 应用 `app/`

```bash
cd app

# 安装依赖
flutter pub get

# 升级依赖（pub get 只按 lock 安装，不升级）
flutter pub upgrade              # 全部升级到 pubspec 约束内最新
flutter pub upgrade <包名>        # 只升级某个包
flutter pub outdated             # 查看哪些包有新版

# 运行
flutter run -d chrome        # Web（开发）
flutter run -d windows       # Windows 桌面
flutter run -d <device-id>   # 指定设备（flutter devices 查看）

# 热重载 / 热重启（运行时在终端按）
# r  → 热重载（保留状态）
# R  → 热重启（重置状态）

# 格式化代码
dart format lib/ test/

# 校验格式、lint 和测试（CI 同样执行）
dart format --output=none --set-exit-if-changed lib/ test/
flutter analyze
flutter test

# 构建安装包
flutter build apk --release                  # Android APK
flutter build windows --release              # Windows 可执行文件（产物在 build\windows\x64\runner\Release\）
# 然后用 Inno Setup Compiler 打开 installer.iss 按 F9 编译 → installer\comic-setup.exe
flutter build web                            # Web 静态文件
flutter pub run msix:create                  # Windows MSIX 安装包（需先 build windows）

# 查看已连接设备 / 检查环境
flutter devices
flutter doctor
```

## 配置

| 文件 | 说明 |
| --- | --- |
| `backend/.env` | 端口、数据库连接、漫画目录（本地环境变量，不提交） |
| `app/lib/config.dart` | 后端 API 地址、更新清单地址 |

## 发版（检查更新）

仓库为公开仓库，App 设置页"关于"区的"检查更新"会读取
`app/lib/config.dart` 里配置的清单地址：
`https://raw.githubusercontent.com/100110001/comic/master/releases/update.json`。
发现新版本后，Windows 静默安装、Android 唤起系统安装器。

在 Claude Code 中使用 `/release X.Y.Z 更新说明` 准备发版 PR；自行合并到 `master`
后，使用 `/release publish X.Y.Z` 推送标签，触发 CI 自动构建并上传安装包。
完整用法和 PowerShell 手动流程见 [项目命令速查](docs/commands.md)。

`scripts/release.ps1` 统一同步应用版本、安装器版本、更新清单和更新日志。
发布完成后，App 的“检查更新”即可检测到新版本。

## 本地漫画超分（可选）

仓库已包含 Windows 便携引擎 `20250915`、`models-cunet` 模型和许可证，位于 `backend/tools/waifu2x/`，正常拉取项目后即可配置启用，无需额外下载。Flutter 客户端无需安装引擎。需要兼容 Vulkan 的显卡与驱动。`backend/` 下的 `npm run setup:waifu2x` 保留为重新下载与更新入口；脚本校验官方包的 SHA256，更新版本时须同步修改脚本内的版本与校验值，并提交更新后的引擎、模型文件。

后端默认允许超分，无需设置 `WAIFU2X_ENABLED=1`；如需禁用，在 `backend/.env` 设置 `WAIFU2X_ENABLED=0` 并重启后端。在设置页“阅读”中开启“默认开启 2× 超分”，新进入的漫画阅读器会自动使用超分，并提前处理当前页及后两页，翻页时推进预处理窗口；阅读器工具栏可临时关闭，不修改设置默认值。未保存偏好时默认关闭。原图先显示，就绪后显示增强图。失败仍可阅读原图，可通过“重试超分”重提。关闭入口立即回原图。

| 环境变量 | 默认值 / 用途 |
| --- | --- |
| `WAIFU2X_ENABLED` | `1`，设为 `0` 禁用 |
| `WAIFU2X_EXECUTABLE` | `tools/waifu2x/waifu2x-ncnn-vulkan.exe`，Linux 使用无后缀文件 |
| `WAIFU2X_MODEL_DIR` | 引擎目录内 `models-cunet` |
| `WAIFU2X_CACHE_DIR` | `data/super-resolution`，必须在 `COMIC_ROOT` 外 |
| `WAIFU2X_CACHE_MB` | `2048`，按最近访问清理磁盘缓存 |
| `WAIFU2X_TIMEOUT_MS` | `60000`，单图推理超时 |

后端运行后访问 `/super-resolution-monitor.html`（本机默认 `http://localhost:8888/super-resolution-monitor.html`），可观察每次超分提交、缓存命中、排队/处理/失败，并拖动对比原图与增强图。记录最近 500 次提交，后端重启清空；监视页只观察，不主动生成超分。

Linux/macOS 可手动部署对应官方便携包并配置路径；一份缓存目录只交给一个后端进程。更新引擎或模型后需要重启后端。任务队列不持久化，重启后可重新提交，已有缓存仍可复用。

第一版固定 2×、关闭降噪；超过 2000 万输入像素的图片回退原图。生成结果与漫画目录分开，原文件不修改；阅读器菜单可清空超分缓存并回原图。PNG/JPEG 的普通网络加载与 Flutter 尺寸解码策略继续沿用现有实现。超分输出采用无损 WebP；结果体积可能显著大于原始 JPEG，请按磁盘容量配置缓存。
