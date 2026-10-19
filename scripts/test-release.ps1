$ErrorActionPreference = 'Stop'
$sourceRoot = Split-Path -Parent $PSScriptRoot
$fixtureRoot = Join-Path ([IO.Path]::GetTempPath()) ('comic-release-test-' + [guid]::NewGuid().ToString('N'))
$originalLocation = Get-Location
$utf8 = [Text.UTF8Encoding]::new($false)

function Assert-True($condition, [string]$message) {
  if (!$condition) { throw $message }
}
function Expect-Failure([scriptblock]$action, [string]$message) {
  $failed = $false
  try { & $action } catch { $failed = $true; Write-Host "预期拒绝：$($_.Exception.Message)" }
  Assert-True $failed $message
}

try {
  foreach ($dir in @('app', 'scripts', 'releases', 'assets')) {
    New-Item -ItemType Directory -Path (Join-Path $fixtureRoot $dir) -Force | Out-Null
  }
  Copy-Item -LiteralPath (Join-Path $sourceRoot 'scripts/release.ps1') -Destination (Join-Path $fixtureRoot 'scripts/release.ps1')
  Copy-Item -LiteralPath (Join-Path $sourceRoot 'scripts/validate-release.ps1') -Destination (Join-Path $fixtureRoot 'scripts/validate-release.ps1')
  [IO.File]::WriteAllText((Join-Path $fixtureRoot 'app/pubspec.yaml'), "version: 1.2.1+7`n", $utf8)
  [IO.File]::WriteAllText((Join-Path $fixtureRoot 'app/installer.iss'), "AppVersion=1.2.1`n", $utf8)
  [IO.File]::WriteAllText((Join-Path $fixtureRoot 'CHANGELOG.md'), "# 更新日志`n", $utf8)
  $initialManifest = @{
    latestVersion = '1.2.1'
    platforms = @{
      windows = @{}
      android = @{ minimumSupportedVersion = '1.2.0' }
    }
  } | ConvertTo-Json -Depth 4
  [IO.File]::WriteAllText((Join-Path $fixtureRoot 'releases/update.json'), $initialManifest, $utf8)
  Set-Location $fixtureRoot
  git init --initial-branch=codex/test-release
  if ($LASTEXITCODE -ne 0) { throw '测试仓库初始化失败' }
  git config user.name '发布流程测试'
  git config user.email 'release-test@example.invalid'
  git config commit.gpgsign false
  git config tag.gpgsign false
  git add .
  git -c commit.gpgsign=false commit -m '初始化测试'
  if ($LASTEXITCODE -ne 0) { throw '测试初始提交失败' }
  git tag v1.2.1

  $baseline = (Get-FileHash app/pubspec.yaml).Hash
  Expect-Failure { & ./scripts/release.ps1 -Version 1.2.2 -ChangeType major -CompatibilityNotes '兼容' -Notes '测试' } '错误版本级别应拒绝'
  Expect-Failure { & ./scripts/release.ps1 -Version 1.2.2 -ChangeType patch -CompatibilityNotes '兼容' -Notes '测试' -AndroidMinimumVersion 1.2.2 } '提高门槛未给原因应拒绝'
  Expect-Failure { & ./scripts/release.ps1 -Version 1.2.2 -ChangeType patch -CompatibilityNotes '兼容' -Notes '测试' -WindowsMinimumVersion 2.0.0 } '最低版本越界应拒绝'
  Assert-True ((Get-FileHash app/pubspec.yaml).Hash -eq $baseline) '拒绝非法参数前不能改写应用版本'

  & ./scripts/release.ps1 -Version 1.2.2 -ChangeType patch -CompatibilityNotes '兼容旧客户端' -Notes '测试补丁'
  Assert-True ((Get-Content app/pubspec.yaml -Raw).Trim() -eq 'version: 1.2.2+8') '构建号应递增'
  $manifest = Get-Content releases/update.json -Raw | ConvertFrom-Json
  Assert-True ($manifest.platforms.windows.minimumSupportedVersion -eq '0.0.0') '旧清单缺少最低版本时不应自动停用历史版本'
  Assert-True ($manifest.platforms.android.minimumSupportedVersion -eq '1.2.0') 'Android 最低版本应继承'
  & ./scripts/validate-release.ps1 -Version 1.2.2 -PreviousRef v1.2.1

  & ./scripts/release.ps1 -Version 1.3.0 -ChangeType minor -CompatibilityNotes '兼容协议，修复严重缺陷' -Notes '测试功能' -AndroidMinimumVersion 1.2.2 -MinimumSupportReason '修复旧版严重缺陷'
  Assert-True ((Get-Content app/pubspec.yaml -Raw).Trim() -eq 'version: 1.3.0+9') '跨次版本仍应递增构建号'
  & ./scripts/validate-release.ps1 -Version 1.3.0 -PreviousRef v1.2.2

  Copy-Item releases/update.json assets/update.json
  [IO.File]::WriteAllBytes((Join-Path $fixtureRoot 'assets/comic-setup.exe'), [byte[]](1, 2, 3))
  Expect-Failure { & ./scripts/validate-release.ps1 -Version 1.3.0 -AssetDirectory assets } '缺少 APK 应阻止发布'
  [IO.File]::WriteAllBytes((Join-Path $fixtureRoot 'assets/app-release.apk'), [byte[]](1, 2, 3))
  & ./scripts/validate-release.ps1 -Version 1.3.0 -AssetDirectory assets
  [IO.File]::WriteAllText((Join-Path $fixtureRoot 'assets/update.json'), '{}', $utf8)
  Expect-Failure { & ./scripts/validate-release.ps1 -Version 1.3.0 -AssetDirectory assets } '远端清单不一致应阻止发布'
  Expect-Failure { & ./scripts/validate-release.ps1 -Version 1.3.1 } '标签与清单不同应阻止发布'
  Write-Host '发布准备与资产校验集成测试通过（临时测试资产不是真实安装包）。'
} finally {
  Set-Location $originalLocation
  # 仅清理由本次测试生成、位于系统临时目录内的固定前缀目录。
  $resolvedFixture = [IO.Path]::GetFullPath($fixtureRoot)
  $resolvedTemp = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\') + '\'
  if ($resolvedFixture.StartsWith($resolvedTemp, [StringComparison]::OrdinalIgnoreCase) -and
      [IO.Path]::GetFileName($resolvedFixture) -match '^comic-release-test-[0-9a-f]{32}$') {
    Remove-Item -LiteralPath $resolvedFixture -Recurse -Force
  }
}
