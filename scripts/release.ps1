param(
  [Parameter(Mandatory = $true)][string]$Version,
  [Parameter(Mandatory = $true)][ValidateSet('patch', 'minor', 'major')][string]$ChangeType,
  [Parameter(Mandatory = $true)][string]$CompatibilityNotes,
  [Parameter(Mandatory = $true)][string]$Notes,
  [string]$WindowsMinimumVersion = '',
  [string]$AndroidMinimumVersion = '',
  [string]$MinimumSupportReason = ''
)

$ErrorActionPreference = 'Stop'
$RepoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $RepoRoot
$versionPattern = '^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$'
if ($Version -notmatch $versionPattern) { throw '版本号格式必须为稳定的 X.Y.Z' }
if ([string]::IsNullOrWhiteSpace($Notes) -or [string]::IsNullOrWhiteSpace($CompatibilityNotes)) {
  throw '更新说明和兼容性说明不能为空'
}
$branch = git branch --show-current
if ($LASTEXITCODE -ne 0 -or !$branch -or $branch -eq 'master') { throw '请在独立发版分支准备发布' }
git diff --quiet
if ($LASTEXITCODE -ne 0) { throw '已跟踪文件存在未提交修改' }
git diff --cached --quiet
if ($LASTEXITCODE -ne 0) { throw '暂存区必须为空' }
$tags = git tag --list "v$Version"
if ($LASTEXITCODE -ne 0 -or $tags) { throw '标签已存在或无法检查标签' }

$pubspecPath = Join-Path $RepoRoot 'app/pubspec.yaml'
$pubspec = [IO.File]::ReadAllText($pubspecPath, [Text.Encoding]::UTF8)
if ($pubspec -notmatch '(?m)^version: ([^+\s]+)\+(\d+)\s*$') { throw '无法读取当前版本及构建号' }
$oldVersion = [version]$Matches[1]
$buildNumber = [long]$Matches[2] + 1
$nextVersion = [version]$Version
if ($nextVersion -le $oldVersion -or $buildNumber -gt 2100000000) { throw '版本必须递增且构建号不能越界' }
$actualChange = if ($nextVersion.Major -gt $oldVersion.Major) { 'major' }
  elseif ($nextVersion.Minor -gt $oldVersion.Minor) { 'minor' } else { 'patch' }
if ($actualChange -ne $ChangeType -or
    ($ChangeType -eq 'minor' -and $nextVersion.Build -ne 0) -or
    ($ChangeType -eq 'major' -and ($nextVersion.Minor -ne 0 -or $nextVersion.Build -ne 0))) {
  throw '版本号与声明的变更级别不一致，主/次版本升级需重置低位版本'
}
$manifestPath = Join-Path $RepoRoot 'releases/update.json'
$previous = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
if ($previous.latestVersion -cne $oldVersion.ToString()) { throw '现有应用与清单版本不一致' }
$installerPath = Join-Path $RepoRoot 'app/installer.iss'
$installer = [IO.File]::ReadAllText($installerPath, [Text.Encoding]::UTF8)
if ($installer -notmatch '(?m)^AppVersion=([^\r\n]+)' -or $Matches[1] -cne $oldVersion.ToString()) {
  throw '现有安装器与应用版本不一致'
}
$changelogPath = Join-Path $RepoRoot 'CHANGELOG.md'
$changelog = [IO.File]::ReadAllText($changelogPath, [Text.Encoding]::UTF8)
$platforms = [ordered]@{}
foreach ($platform in @('windows', 'android')) {
  $oldMinimum = $previous.platforms.$platform.minimumSupportedVersion
  if (!$oldMinimum) { $oldMinimum = '0.0.0' }
  $minimum = if ($platform -eq 'windows') { $WindowsMinimumVersion } else { $AndroidMinimumVersion }
  if (!$minimum) { $minimum = $oldMinimum }
  if ($minimum -notmatch $versionPattern -or [version]$minimum -gt $nextVersion) {
    throw "$platform 最低支持版本无效或高于最新版本"
  }
  $raised = [version]$minimum -gt [version]$oldMinimum
  if ($raised -and [string]::IsNullOrWhiteSpace($MinimumSupportReason)) {
    throw "$platform 提高最低版本必须提供 MinimumSupportReason"
  }
  $reason = if ($MinimumSupportReason) { $MinimumSupportReason } else {
    $previous.platforms.$platform.minimumSupportReason
  }
  $asset = if ($platform -eq 'windows') { 'comic-setup.exe' } else { 'app-release.apk' }
  $platforms[$platform] = [ordered]@{
    downloadUrl = "https://github.com/100110001/comic/releases/download/v$Version/$asset"
    minimumSupportedVersion = $minimum
    minimumSupportReason = $reason
  }
}

# 所有参数校验完成后才写发布文件；只准备提交与本地标签，不发布线上更新。
$utf8 = [Text.UTF8Encoding]::new($false)
$pubspec = $pubspec -replace '(?m)^version: .*$', "version: $Version+$buildNumber"
[IO.File]::WriteAllText($pubspecPath, $pubspec, $utf8)
$installer = $installer -replace '(?m)^AppVersion=.*$', "AppVersion=$Version"
[IO.File]::WriteAllText($installerPath, $installer, $utf8)
$update = [ordered]@{
  latestVersion = $Version
  buildNumber = $buildNumber
  platforms = $platforms
  releaseNotes = $Notes
  changeType = $ChangeType
  compatibilityNotes = $CompatibilityNotes
} | ConvertTo-Json -Depth 5
[IO.File]::WriteAllText($manifestPath, $update, $utf8)
$entry = "`n## [$Version] - $(Get-Date -Format 'yyyy-MM-dd')`n`n$Notes`n`n兼容性（$ChangeType）：$CompatibilityNotes`n"
if ($MinimumSupportReason) { $entry += "`n最低支持版本调整原因：$MinimumSupportReason`n" }
[IO.File]::WriteAllText($changelogPath, $changelog + $entry, $utf8)
& (Join-Path $PSScriptRoot 'validate-release.ps1') -Version $Version
git add app/pubspec.yaml app/installer.iss releases/update.json CHANGELOG.md
if ($LASTEXITCODE -ne 0) { throw '暂存发布文件失败' }
git commit -m "chore(release): v$Version"
if ($LASTEXITCODE -ne 0) { throw '提交发布文件失败' }
git tag "v$Version"
if ($LASTEXITCODE -ne 0) { throw '创建本地发布标签失败' }
Write-Host "已准备 v$Version+$buildNumber；请推送发版分支并创建 PR，合并后再推送标签。"
