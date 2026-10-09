param(
    [Parameter(Mandatory = $true)]
    [string]$BaseSha
)

$ErrorActionPreference = 'Stop'
$appChanged = $false
$backendChanged = $false

if ($BaseSha -notmatch '^[0-9a-fA-F]{40}$') {
    throw 'CI 基准提交必须是完整的 Git SHA。'
}

if ($BaseSha -eq ('0' * 40)) {
    # 首次推送没有可比较的基准，保守执行两边检查。
    $appChanged = $true
    $backendChanged = $true
} else {
    git rev-parse --verify --quiet "$BaseSha`^{commit}" | Out-Null
    if ($LASTEXITCODE -ne 0) {
        git fetch --no-tags --depth=1 origin $BaseSha
        if ($LASTEXITCODE -ne 0) {
            throw '无法取得 CI 基准提交。'
        }
    }

    $changedFiles = @(git -c core.quotepath=false diff --name-only --no-renames $BaseSha HEAD --)
    if ($LASTEXITCODE -ne 0) {
        throw '无法读取 CI 变更范围。'
    }

    foreach ($file in $changedFiles) {
        if ($file -cmatch '^app/') {
            $appChanged = $true
        } elseif ($file -cmatch '^backend/') {
            $backendChanged = $true
        } elseif ($file -match '^(Readme\.md|AGENTS\.md|CHANGELOG\.md|(?:docs|specs|\.claude)/.*\.md)$') {
            # 仅明确的仓库文档免检，目录内的应用资源仍按项目检查。
            continue
        } else {
            # CI、共享配置和未知文件必须检查两边。
            $appChanged = $true
            $backendChanged = $true
        }
    }
}

$appOutput = $appChanged.ToString().ToLowerInvariant()
$backendOutput = $backendChanged.ToString().ToLowerInvariant()
Write-Host "CI 范围：app=$appOutput，backend=$backendOutput"
if ($env:GITHUB_OUTPUT) {
    Add-Content -LiteralPath $env:GITHUB_OUTPUT -Value "app=$appOutput"
    Add-Content -LiteralPath $env:GITHUB_OUTPUT -Value "backend=$backendOutput"
}
