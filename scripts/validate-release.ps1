param(
  [Parameter(Mandatory = $true)][string]$Version,
  [string]$Root = (Split-Path -Parent $PSScriptRoot),
  [string]$AssetDirectory = '',
  [string]$PreviousRef = ''
)

$ErrorActionPreference = 'Stop'
$versionPattern = '^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$'
if ($Version -notmatch $versionPattern) { throw '发布版本必须为稳定的 X.Y.Z' }
$manifest = Get-Content -LiteralPath (Join-Path $Root 'releases/update.json') -Raw -Encoding UTF8 | ConvertFrom-Json
if ($manifest.latestVersion -cne $Version) { throw '更新清单与发布版本不一致' }
$pubspec = Get-Content -LiteralPath (Join-Path $Root 'app/pubspec.yaml') -Raw -Encoding UTF8
if ($pubspec -notmatch '(?m)^version: ([^+\s]+)\+(\d+)\s*$' -or $Matches[1] -cne $Version) {
  throw '应用版本与发布版本不一致或缺少构建号'
}
if ([long]$Matches[2] -le 0 -or [long]$Matches[2] -gt 2100000000) { throw 'Android 构建号越界' }
$buildNumber = [long]$Matches[2]
if ($manifest.buildNumber -ne $buildNumber) { throw '清单与应用构建号不一致' }
$previous = $null
if ($PreviousRef) {
  $previousJson = git -C $Root show "${PreviousRef}:releases/update.json"
  if ($LASTEXITCODE -ne 0) { throw '无法读取上一发布清单' }
  $previous = ($previousJson -join "`n") | ConvertFrom-Json
  $previousPubspec = git -C $Root show "${PreviousRef}:app/pubspec.yaml"
  if ($LASTEXITCODE -ne 0 -or ($previousPubspec -join "`n") -notmatch '(?m)^version: ([^+\s]+)\+(\d+)\s*$') {
    throw '无法读取上一发布版本'
  }
  $oldVersion = [version]$Matches[1]
  if ($buildNumber -le [long]$Matches[2] -or [version]$Version -le $oldVersion) { throw '版本或构建号未递增' }
  $nextVersion = [version]$Version
  $actualChange = if ($nextVersion.Major -gt $oldVersion.Major) { 'major' }
    elseif ($nextVersion.Minor -gt $oldVersion.Minor) { 'minor' } else { 'patch' }
  if ($manifest.changeType -cne $actualChange -or
      ($actualChange -eq 'minor' -and $nextVersion.Build -ne 0) -or
      ($actualChange -eq 'major' -and ($nextVersion.Minor -ne 0 -or $nextVersion.Build -ne 0))) {
    throw '版本号与变更级别不一致'
  }
}
$installer = Get-Content -LiteralPath (Join-Path $Root 'app/installer.iss') -Raw -Encoding UTF8
if ($installer -notmatch '(?m)^AppVersion=([^\r\n]+)' -or $Matches[1] -cne $Version) {
  throw '安装器版本与发布版本不一致'
}
if ($manifest.changeType -notin @('patch', 'minor', 'major') -or
    [string]::IsNullOrWhiteSpace($manifest.compatibilityNotes) -or
    [string]::IsNullOrWhiteSpace($manifest.releaseNotes)) {
  throw '发布缺少变更级别、兼容性说明或更新说明'
}
$changelog = Get-Content -LiteralPath (Join-Path $Root 'CHANGELOG.md') -Raw -Encoding UTF8
if (!$changelog.Contains("## [$Version]")) { throw '更新日志缺少发布版本' }
$assets = @{ windows = 'comic-setup.exe'; android = 'app-release.apk' }
foreach ($platform in @('windows', 'android')) {
  $entry = $manifest.platforms.$platform
  if ($null -eq $entry -or $entry.minimumSupportedVersion -notmatch $versionPattern -or
      [version]$entry.minimumSupportedVersion -gt [version]$Version) {
    throw "$platform 最低支持版本无效"
  }
  $expected = "https://github.com/100110001/comic/releases/download/v$Version/$($assets[$platform])"
  if ($entry.downloadUrl -cne $expected) { throw "$platform 下载地址与版本不一致" }
  if ($null -ne $previous) {
    $oldMinimum = $previous.platforms.$platform.minimumSupportedVersion
    if (!$oldMinimum) { $oldMinimum = '0.0.0' }
    if ([version]$entry.minimumSupportedVersion -gt [version]$oldMinimum -and
        [string]::IsNullOrWhiteSpace($entry.minimumSupportReason)) {
      throw "$platform 提高最低版本缺少原因"
    }
  }
}
if ($AssetDirectory) {
  foreach ($name in @('comic-setup.exe', 'app-release.apk', 'update.json')) {
    $asset = Get-Item -LiteralPath (Join-Path $AssetDirectory $name) -ErrorAction Stop
    if ($asset.Length -le 0) { throw "发布资产为空：$name" }
  }
  $expectedHash = (Get-FileHash -LiteralPath (Join-Path $Root 'releases/update.json') -Algorithm SHA256).Hash
  $actualHash = (Get-FileHash -LiteralPath (Join-Path $AssetDirectory 'update.json') -Algorithm SHA256).Hash
  if ($actualHash -cne $expectedHash) { throw '上传清单与已验证清单不一致' }
}
Write-Host "发布文件校验通过：v$Version"
