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

## 配置

| 文件 | 说明 |
|---|---|
| `backend/.env` | 端口、数据库连接、漫画目录 |
| `lib/config.dart` | 后端 API 地址 |
