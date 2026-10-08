param(
  [Parameter(Mandatory = $true)]
  [string]$Version,
  [string]$Notes = "",
  [switch]$Upload
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $PSScriptRoot
$AppRoot = Join-Path $RepoRoot "app"
Set-Location $RepoRoot

if ($Version -notmatch '^\d+\.\d+\.\d+$') {
  throw "版本号格式应为 X.Y.Z，当前: $Version"
}

# 1. 同步 pubspec.yaml（build 号 +1，统一 UTF-8 读写避免乱码；单行写法兼容 PowerShell 5.1）
$pubspecPath = Join-Path $AppRoot "pubspec.yaml"
$pubspec = [System.IO.File]::ReadAllText($pubspecPath, [System.Text.Encoding]::UTF8)
$pubspec = $pubspec -replace '(?m)^version: .*$', "version: $Version+1"
[System.IO.File]::WriteAllText($pubspecPath, $pubspec, [System.Text.UTF8Encoding]::new($false))

# 2. 同步 installer.iss
$installerPath = Join-Path $AppRoot "installer.iss"
$iss = [System.IO.File]::ReadAllText($installerPath, [System.Text.Encoding]::UTF8)
$iss = $iss -replace '(?m)^AppVersion=.*$', "AppVersion=$Version"
[System.IO.File]::WriteAllText($installerPath, $iss, [System.Text.UTF8Encoding]::new($false))

# 3. 生成更新清单（随主仓库提交，raw 地址由 config.dart 指向）
$update = @{
  latestVersion = $Version
  platforms     = @{
    windows = @{
      downloadUrl = "https://github.com/100110001/comic/releases/download/v$Version/comic-setup.exe"
    }
    android = @{
      downloadUrl = "https://github.com/100110001/comic/releases/download/v$Version/app-release.apk"
    }
  }
  releaseNotes  = $Notes
} | ConvertTo-Json -Depth 4
New-Item -ItemType Directory -Force -Path releases | Out-Null
[System.IO.File]::WriteAllText((Join-Path $RepoRoot "releases\update.json"), $update, [System.Text.UTF8Encoding]::new($false))

# 4. CHANGELOG
$changelogPath = Join-Path $RepoRoot "CHANGELOG.md"
if (-not (Test-Path $changelogPath)) {
  [System.IO.File]::WriteAllText($changelogPath, "# 更新日志`n`n## [Unreleased]`n", [System.Text.UTF8Encoding]::new($false))
}
$date = Get-Date -Format 'yyyy-MM-dd'
$entry = if ($Notes) { "`n## [$Version] - $date`n`n$Notes`n" } else { "`n## [$Version] - $date`n" }
$changelog = [System.IO.File]::ReadAllText($changelogPath, [System.Text.Encoding]::UTF8)
[System.IO.File]::WriteAllText($changelogPath, $changelog + $entry, [System.Text.UTF8Encoding]::new($false))

# 5. 提交并打 tag
git add app/pubspec.yaml app/installer.iss releases/update.json CHANGELOG.md
git commit -m "chore(release): v$Version"
git tag "v$Version"

Write-Host ""
Write-Host "已同步版本 $Version：app/pubspec / app/installer.iss / releases/update.json / CHANGELOG / tag v$Version"
Write-Host ""
Write-Host "构建与上传（或加 -Upload 自动执行）："
Write-Host "  Push-Location app"
Write-Host "  flutter build windows --release"
Write-Host "  flutter build apk --release"
Write-Host "  ISCC installer.iss"
Write-Host "  Pop-Location"
Write-Host "  gh release create v$Version app/installer/comic-setup.exe app/build/app/outputs/flutter-apk/app-release.apk --title v$Version"
Write-Host "  git push && git push origin v$Version"

if ($Upload) {
  Write-Host ""
  Write-Host "开始自动构建上传…"
  Push-Location $AppRoot
  try {
    flutter build windows --release
    flutter build apk --release
    ISCC installer.iss
  } finally {
    Pop-Location
  }
  gh release create "v$Version" app/installer/comic-setup.exe app/build/app/outputs/flutter-apk/app-release.apk --title "v$Version" --notes $Notes
  git push
  git push origin "v$Version"
  Write-Host "update.json 已随主仓库推送，无需单独同步"
  Write-Host "完成：v$Version 已发布"
}
