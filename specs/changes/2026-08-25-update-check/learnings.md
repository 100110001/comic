# Learnings

## 版本管理与检查更新

- 新增依赖：`package_info_plus`（读本地版本）、`open_filex`（Android 唤起系统安装器）。
- `update.json` 结构：`latestVersion` + `platforms.{windows,android}.downloadUrl` + `releaseNotes`。
- 版本比较：数字段比较，忽略 `+build` 与 `-prerelease` 部分。
- Windows 更新：`Process.start(exe, [/VERYSILENT,/SUPPRESSMSGBOXES,/NORESTART])` 后 `exit(0)`；`installer.iss` 加 `CloseApplications=yes` 保证安装器能替换运行中的文件。
- Android 更新：Manifest 加 `REQUEST_INSTALL_PACKAGES`，下载 APK 后用 `OpenFilex.open(type: application/vnd.android.package-archive)`。
- `release.ps1`：`-Version` 强制 `X.Y.Z`；同步 pubspec（build +1）/installer/update.json/CHANGELOG；打 `vX.Y.Z` tag；`-Upload` 自动构建 + `gh release create`；`-ReleasesRepoDir` 把 update.json 推送到公开 releases 仓。
- 设置页"关于"区状态机：idle / checking / latest / available / error / downloading；Web 端隐藏检查按钮。
