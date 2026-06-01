# Comic

漫画阅读应用，Flutter 前端 + Node.js 后端。

## 后端 `backend/`

```bash
# 安装依赖
pnpm install

# 开发模式（热重载）
npm run dev           # http://localhost:8888

# 初始化数据库 + 扫描文件 + 导入数据
npm run setup

# 单独构建
npm run build
```

## 前端 `Flutter`

```bash
# 安装依赖
flutter pub get

# 运行
flutter run -d chrome       # Web
flutter run -d windows      # Windows 桌面
flutter run                 # 选择设备

# 格式化代码
dart format lib/

# 构建
flutter build web
flutter build windows
```
