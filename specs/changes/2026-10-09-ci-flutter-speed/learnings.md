# 实施记录

- 迁移范围仅 CI 的 check 任务；release.yml 和后端 runner 保持不变。
- 先测 SDK 与 pub 缓存都开启的冷、暖运行，再比较 pub 缓存关闭结果。
- 自审：现有范围脚本显式使用 pwsh，Ubuntu runner 提供 PowerShell；Git 路径判断不依赖 Windows 分隔符。
- Ubuntu 首轮（冷缓存）完整通过：check 144 秒、Setup Flutter 59 秒、pub get 12 秒、分析 16 秒、测试 24 秒、首次缓存保存 16 秒；范围脚本跨平台通过。
- 开启 pub 缓存的 Linux 命中运行通过：总耗时 77 秒，环境准备 17 秒，依赖恢复 1 秒，分析 18 秒，测试 25 秒；期间 master 合入超分辨率代码，无法将总耗时与首轮直接归因于缓存。
- 实测发现事件 base SHA 可能落后于实际检出的测试合并提交；范围判断应使用实际合并提交的第一父提交，避免把新的 master 改动归入 PR。
