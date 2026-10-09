# 实施记录

- 迁移范围仅 CI 的 check 任务；release.yml 和后端 runner 保持不变。
- 先测 SDK 与 pub 缓存都开启的冷、暖运行，再比较 pub 缓存关闭结果。
- 自审：现有范围脚本显式使用 pwsh，Ubuntu runner 提供 PowerShell；Git 路径判断不依赖 Windows 分隔符。
