# 安卓固定发布签名

发布 APK 使用固定密钥，缺少配置时失败；调试构建不需要发布密钥。

## 首次配置

用 JDK 的 keytool 生成一次密钥，在已存在的安全备份目录执行：

```powershell
keytool -genkeypair -v -keystore D:\Backups\comic-release.jks -alias comic-release -keyalg RSA -keysize 2048 -validity 10000
```

按提示输入密码，安全备份密钥和密码，不要提交到仓库。默认 PKCS12 密钥库使用相同的密钥库和密钥密码。

在 GitHub 仓库 Settings → Secrets and variables → Actions 添加：

| Secret | 内容 |
| --- | --- |
| ANDROID_KEYSTORE_BASE64 | 密钥文件的 Base64 |
| ANDROID_KEYSTORE_PASSWORD | 密钥库密码 |
| ANDROID_KEY_ALIAS | comic-release |
| ANDROID_KEY_PASSWORD | 密钥密码 |

本机复制 Base64 到剪贴板，直接粘贴到 Secret，保存后清空剪贴板：

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes('D:\Backups\comic-release.jks')) | Set-Clipboard
```

Base64 与密钥一样需要保密。所有后续发布复用这些 Secrets；CI 临时恢复密钥并在结束时清理。

## 本地发布

设置环境变量后，从 app/ 运行构建：

```powershell
$env:ANDROID_KEYSTORE_PATH = 'D:\Backups\comic-release.jks'
$env:ANDROID_KEY_ALIAS = 'comic-release'
$env:ANDROID_KEYSTORE_PASSWORD = [System.Net.NetworkCredential]::new('', (Read-Host '密钥库密码' -AsSecureString)).Password
$env:ANDROID_KEY_PASSWORD = $env:ANDROID_KEYSTORE_PASSWORD
Set-Location app
flutter build apk --release
```

独立密钥密码需要单独安全输入。构建后关闭终端以清除环境变量。
