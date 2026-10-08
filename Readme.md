# Comic

漫画阅读应用：Flutter 前端 + Node.js 后端，支持 Windows 桌面、Android 与 Web。

## 功能特性

- **书库浏览与搜索**：随机洗牌网格、关键字搜索（标题/作者）、收藏角标。
- **发现**：随机阅读、拖拽切换、读完自动续下一本。
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
dart format lib/

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
