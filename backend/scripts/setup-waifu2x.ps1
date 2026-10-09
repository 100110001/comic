$ErrorActionPreference = 'Stop'
$version = '20250915'
$expectedHash = '7425BE94B94E4C8F37A1E433AC0E0100C43790E2C37418F4B65D8235ADFBDC87'
$backendRoot = Split-Path -Parent $PSScriptRoot
$destination = Join-Path $backendRoot 'tools\waifu2x'
$temporaryRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('comic-waifu2x-' + [guid]::NewGuid())
New-Item -ItemType Directory -Path $temporaryRoot -Force | Out-Null
try {
  $archive = Join-Path $temporaryRoot 'waifu2x.zip'
  $url = "https://github.com/nihui/waifu2x-ncnn-vulkan/releases/download/$version/waifu2x-ncnn-vulkan-$version-windows.zip"
  Write-Host '下载官方 waifu2x Windows 便携引擎…'
  Invoke-WebRequest -Uri $url -OutFile $archive -UseBasicParsing
  if ((Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash -ne $expectedHash) {
    throw '引擎包 SHA256 校验失败，停止部署'
  }
  Expand-Archive -LiteralPath $archive -DestinationPath $temporaryRoot
  $extracted = Join-Path $temporaryRoot "waifu2x-ncnn-vulkan-$version-windows"
  New-Item -ItemType Directory -Path $destination -Force | Out-Null
  Get-ChildItem -LiteralPath $extracted | Copy-Item -Destination $destination -Recurse -Force
  Write-Host "引擎已准备：$destination"
  Write-Host '在 backend/.env 设置 WAIFU2X_ENABLED=1，重启后端后使用。'
} finally {
  $resolvedTemporary = [System.IO.Path]::GetFullPath($temporaryRoot)
  $resolvedTempBase = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath()).TrimEnd('\') + '\'
  if ($resolvedTemporary.StartsWith($resolvedTempBase, [System.StringComparison]::OrdinalIgnoreCase)) {
    Remove-Item -LiteralPath $resolvedTemporary -Recurse -Force
  }
}
