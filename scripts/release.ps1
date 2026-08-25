param(
  [Parameter(Mandatory = $true)]
  [string]$Version,
  [string]$Notes = "",
  [string]$ReleasesRepoDir = "",
  [switch]$Upload
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $RepoRoot

if ($Version -notmatch '^\d+\.\d+\.\d+$') {
  throw "版本号格式应为 X.Y.Z，当前: $Version"
}

# 1. 同步 pubspec.yaml（build 号 +1）
$pubspec = Get-Content pubspec.yaml -Raw
$pubspec = $pubspec -replace '(?m)^version: .*$', "version: $Version+1"
Set-Content pubspec.yaml $pubspec -NoNewline

# 2. 同步 installer.iss
$iss = Get-Content installer.iss -Raw
$iss = $iss -replace '(?m)^AppVersion=.*$', "AppVersion=$Version"
Set-Content installer.iss $iss -NoNewline

# 3. 生成更新清单（发布到公开 releases 仓）
$update = @{
  latestVersion = $Version
  platforms     = @{
    windows = @{
      downloadUrl = "https://github.com/100110001/comic-releases/releases/download/v$Version/comic-setup.exe"
    }
    android = @{
      downloadUrl = "https://github.com/100110001/comic-releases/releases/download/v$Version/app-release.apk"
    }
  }
  releaseNotes  = $Notes
} | ConvertTo-Json -Depth 4
New-Item -ItemType Directory -Force -Path releases | Out-Null
Set-Content releases/update.json $update -NoNewline -Encoding UTF8

# 4. CHANGELOG
if (-not (Test-Path CHANGELOG.md)) {
  Set-Content CHANGELOG.md "# 更新日志`n`n## [Unreleased]`n" -Encoding UTF8
}
$date = Get-Date -Format 'yyyy-MM-dd'
$entry = if ($Notes) { "`n## [$Version] - $date`n`n$Notes`n" } else { "`n## [$Version] - $date`n" }
Add-Content CHANGELOG.md $entry -Encoding UTF8

# 5. 提交并打 tag
git add pubspec.yaml installer.iss releases/update.json CHANGELOG.md
git commit -m "chore(release): v$Version"
git tag "v$Version"

Write-Host ""
Write-Host "已同步版本 $Version：pubspec / installer.iss / releases/update.json / CHANGELOG / tag v$Version"
Write-Host ""
Write-Host "构建与上传（或加 -Upload 自动执行）："
Write-Host "  flutter build windows --release"
Write-Host "  flutter build apk --release"
Write-Host "  ISCC installer.iss"
Write-Host "  gh release create v$Version installer/comic-setup.exe build/app/outputs/flutter-apk/app-release.apk --repo 100110001/comic-releases --title v$Version"
Write-Host "  git push && git push origin v$Version"

if ($Upload) {
  Write-Host ""
  Write-Host "开始自动构建上传…"
  flutter build windows --release
  flutter build apk --release
  ISCC installer.iss
  gh release create "v$Version" installer/comic-setup.exe build/app/outputs/flutter-apk/app-release.apk --repo 100110001/comic-releases --title "v$Version" --notes $Notes
  git push
  git push origin "v$Version"

  if ($ReleasesRepoDir -ne "") {
    Copy-Item releases/update.json (Join-Path $ReleasesRepoDir "update.json") -Force
    Push-Location $ReleasesRepoDir
    git add update.json
    git commit -m "chore(release): v$Version"
    git push
    Pop-Location
    Write-Host "update.json 已同步到公开 releases 仓"
  } else {
    Write-Host "提示：请把 releases/update.json 复制到公开 releases 仓（comic-releases）的 update.json 并推送。"
  }
  Write-Host "完成：v$Version 已发布"
}
