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
| `lib/` | Flutter 前端代码 |
| `backend/` | Node.js 后端 |
| `scripts/` | 发版脚本（`release.ps1`） |
| `specs/` | 设计规范（spec 是设计的事实源） |
| `installer.iss` | Windows 安装包（Inno Setup）配置 |

> 版本锁定：Flutter 固定 **3.38.9**（CI 已锁定）；Flutter 依赖锁定见 `pubspec.lock`（已提交），后端依赖见 `backend/pnpm-lock.yaml`。

## 快速开始

### 1. 后端 `backend/`

```bash
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

重新导入前先清表：

```sql
TRUNCATE TABLE images;
TRUNCATE TABLE chapters;
TRUNCATE TABLE comics;
```

### 2. 前端 `Flutter`

```bash
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
| `lib/config.dart` | 后端 API 地址、更新清单地址 |

## 发版（检查更新）

仓库为公开仓库，App 设置页"关于"区的"检查更新"会读取
`lib/config.dart` 里配置的清单地址：
`https://raw.githubusercontent.com/100110001/comic/master/releases/update.json`。
发现新版本后，Windows 静默安装、Android 唤起系统安装器。

每次发版按以下流程操作：

```powershell
# 1. 升版本号并同步各文件（pubspec / installer.iss / releases/update.json / CHANGELOG），打 vX.Y.Z tag
.\scripts\release.ps1 -Version 1.0.1 -Notes "本次更新内容"

# 2. 推送代码与 tag —— CI（release.yml）会自动构建 Windows + Android 并上传到 v1.0.1 Release
git push && git push origin v1.0.1
```

注意事项：

- 版本号格式必须为 `X.Y.Z`；`release.ps1` 会自动同步 pubspec、installer、update.json、CHANGELOG 并打 tag（脚本读写统一为 UTF-8，兼容 Windows PowerShell 5.1）。
- 推送 tag 后等 CI 完成即可；需要手动构建/上传时：
  `flutter build windows --release`、`flutter build apk --release`、`ISCC installer.iss`，
  再 `gh release upload v1.0.1 --clobber installer/comic-setup.exe build/app/outputs/flutter-apk/app-release.apk`。
- `releases/update.json` 的 `latestVersion` 必须与发布的版本一致（脚本自动处理）。
- 发布完成后，App 的"检查更新"即可检测到新版本。
