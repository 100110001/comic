# waifu2x Windows 便携引擎

本目录随 Git 提交，拉取项目后无需单独安装超分程序。

- 来源：[nihui/waifu2x-ncnn-vulkan](https://github.com/nihui/waifu2x-ncnn-vulkan)。
- 版本：`20250915`，官方 Windows 便携包。
- 原始压缩包 SHA256：`7425BE94B94E4C8F37A1E433AC0E0100C43790E2C37418F4B65D8235ADFBDC87`。
- 保留文件：`waifu2x-ncnn-vulkan.exe`、`vcomp140.dll`、完整 `models-cunet/`、上游 `LICENSE`。模型保持官方原样。
- 总体积约 29 MiB，使用普通 Git 文件保存。
- 环境要求：Windows、兼容 Vulkan 的显卡与驱动。

在 `backend/.env` 设置 `WAIFU2X_ENABLED=1` 并重启后端即可启用。Linux/macOS 需自行部署对应平台引擎并配置路径。

从 `backend/` 执行 `npm run setup:waifu2x` 可重新下载并校验固定版本。升级时同步修改 `scripts/setup-waifu2x.ps1` 中的版本和 SHA256，执行脚本后提交本目录更新，并重启后端。脚本保留本说明，不修改 `.env`。

上游许可证见 [LICENSE](LICENSE)，原始版权和许可声明保持完整。
