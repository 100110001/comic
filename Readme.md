# Comic

漫画阅读应用，Flutter 前端 + Node.js 后端。

## 后端 `backend/`

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

### 数据库操作（重新导入前先清表）

```sql
TRUNCATE TABLE images;
TRUNCATE TABLE chapters;
TRUNCATE TABLE comics;
```

---

## 前端 `Flutter`

```bash
# 安装依赖
flutter pub get

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
flutter build windows --release              # 编译 Windows 可执行文件（产物在 build\windows\x64\runner\Release\）
# 然后用 Inno Setup Compiler 打开 installer.iss，按 F9 编译 → 生成 installer\comic-setup.exe
flutter build web                            # Web 静态文件
flutter pub run msix:create                  # Windows MSIX 安装包（需先 build windows）

# 查看已连接设备
flutter devices

# 检查环境
flutter doctor
```

---

## 发版（检查更新）

仓库为公开仓库，App 设置页"关于"区的"检查更新"会读取
`lib/config.dart` 里配置的清单地址：
`https://raw.githubusercontent.com/100110001/comic/master/releases/update.json`。
发现新版本后，Windows 静默安装、Android 唤起系统安装器。

每次发版按以下流程操作：

```powershell
# 1. 升版本号并同步各文件（pubspec / installer.iss / releases/update.json / CHANGELOG），打 vX.Y.Z tag
.\scripts\release.ps1 -Version 1.0.1 -Notes "本次更新内容"

# 2. 构建
flutter build windows --release
flutter build apk --release
ISCC installer.iss          # 生成 installer\comic-setup.exe

# 3. 发布 Release（tag 已由脚本创建）
gh release create v1.0.1 installer/comic-setup.exe build/app/outputs/flutter-apk/app-release.apk --title v1.0.1 --notes "本次更新内容"

# 4. 推送代码与 tag
git push && git push origin v1.0.1
```

注意事项：

- 版本号格式必须为 `X.Y.Z`；`release.ps1` 会自动同步 pubspec、installer、update.json、CHANGELOG 并打 tag（脚本读写统一为 UTF-8）。
- 如果 `gh release create` 提示 tag 已存在，说明之前建过 Release，改用 `gh release upload v1.0.1 --clobber <文件>` 替换资产。
- `releases/update.json` 的 `latestVersion` 必须与发布的版本一致（脚本自动处理）。
- 发布完成后，仓库内 App 的"检查更新"即可检测到新版本。

---

## 配置

| 文件 | 说明 |
|---|---|
| `backend/.env` | 端口、数据库连接、漫画目录 |
| `lib/config.dart` | 后端 API 地址 |
