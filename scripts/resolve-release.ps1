param(
  [Parameter(Mandatory = $true)][string]$Tag,
  [Parameter(Mandatory = $true)][string]$ReleasesJson,
  [string]$Root = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'
$tagPattern = '^v(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$'
if ($Tag -cnotmatch $tagPattern) { throw '目标标签必须为稳定的 vX.Y.Z' }
$version = [version]$Tag.Substring(1)
$commit = git -C $Root rev-parse --verify "refs/tags/${Tag}^{commit}"
if ($LASTEXITCODE -ne 0) { throw '目标标签不存在或未指向提交' }

# API 使用 --paginate --slurp，逐页展开；不把未发布的 Git 标签当作正式基线。
$pages = ConvertFrom-Json -InputObject $ReleasesJson
$releases = @($pages | ForEach-Object { $_ })
if (@($releases | Where-Object { $_.tag_name -ceq $Tag -and !$_.draft }).Count -gt 0) {
  throw '目标 Release 已公布，禁止覆盖'
}
$previousTag = $null
$previousVersion = $null
foreach ($release in $releases) {
  if ($release.draft -or $release.prerelease -or $release.tag_name -cnotmatch $tagPattern) { continue }
  $publishedVersion = [version]$release.tag_name.Substring(1)
  if ($publishedVersion -gt $version) { throw '已有更高正式版本，禁止回退 latest' }
  if ($publishedVersion -lt $version -and ($null -eq $previousVersion -or $publishedVersion -gt $previousVersion)) {
    $previousVersion = $publishedVersion
    $previousTag = $release.tag_name
  }
}
if (!$previousTag) { throw '无法确定上一正式稳定版本' }
$previousCommit = git -C $Root rev-parse --verify "refs/tags/${previousTag}^{commit}"
if ($LASTEXITCODE -ne 0) { throw '上一正式版本的标签不存在或未指向提交' }
$previousPubspec = git -C $Root show "${previousCommit}:app/pubspec.yaml"
if ($LASTEXITCODE -ne 0 -or ($previousPubspec -join "`n") -notmatch '(?m)^version: ([^+\s]+)\+\d+\s*$' -or
    $Matches[1] -cne $previousTag.Substring(1)) {
  throw '上一正式版本标签与应用版本不一致'
}
[pscustomobject]@{ Tag = $Tag; Commit = $commit; PreviousTag = $previousTag; PreviousCommit = $previousCommit }
