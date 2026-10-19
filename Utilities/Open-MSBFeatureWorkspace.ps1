# MSB Database — one high-contrast VS Code window per feature Git worktree.
# Local workstation convenience ONLY. Never edits tracked files, Git state,
# Production databases, services, ports, permissions or acceptance runners.
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$WorktreePath,

    [Parameter(Mandatory = $true)]
    [ValidateRange(1, 999999)]
    [int]$IssueNumber,

    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[A-Za-z0-9][A-Za-z0-9 _-]{0,59}$')]
    [string]$Label,

    [ValidateSet('Auto', 'Blue', 'Yellow', 'Teal', 'Green', 'Purple', 'Orange')]
    [string]$Color = 'Auto',

    [switch]$NoLaunch
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    throw 'HOLD: Git is required to verify the feature worktree.'
}
$resolved = (Resolve-Path -LiteralPath $WorktreePath -ErrorAction Stop).ProviderPath
$requested = [System.IO.Path]::GetFullPath($resolved).TrimEnd('\', '/')
$gitRootOutput = & git -C $requested rev-parse --show-toplevel
if ($LASTEXITCODE -ne 0 -or -not $gitRootOutput) {
    throw 'HOLD: Path is not a Git checkout.'
}
$gitRoot = [System.IO.Path]::GetFullPath(
    (($gitRootOutput | Select-Object -First 1).Trim())
).TrimEnd('\', '/')
if (-not [string]::Equals(
    $requested, $gitRoot, [System.StringComparison]::OrdinalIgnoreCase
)) {
    throw 'HOLD: WorktreePath must be the exact Git worktree root, not a subfolder.'
}
$branchName = (& git -C $gitRoot branch --show-current).Trim()
if ($LASTEXITCODE -ne 0 -or -not $branchName -or $branchName -eq 'main') {
    throw 'HOLD: An actual checked-out feature branch is required.'
}

$palette = @('Purple', 'Orange', 'Green', 'Teal', 'Yellow', 'Blue')
if ($Color -eq 'Auto') {
    # Stable per issue number. #171 => Teal, #88 => Yellow, #419 => Blue.
    $Color = $palette[$IssueNumber % $palette.Count]
}
$themes = @{
    Blue   = @{ title = '#175DA5'; inactive = '#376C9F'; bar = '#245D96'; status = '#12518D' }
    Yellow = @{ title = '#9A7600'; inactive = '#786729'; bar = '#A47C06'; status = '#896B05' }
    Teal   = @{ title = '#087F8C'; inactive = '#236B75'; bar = '#126A75'; status = '#075F6A' }
    Green  = @{ title = '#257349'; inactive = '#345E49'; bar = '#275D46'; status = '#1C6040' }
    Purple = @{ title = '#6541A5'; inactive = '#604C83'; bar = '#57398B'; status = '#533282' }
    Orange = @{ title = '#A45414'; inactive = '#875D3C'; bar = '#87501F'; status = '#904713' }
}
$theme = $themes[$Color]
$folderLabel = ('#{0} {1}' -f $IssueNumber, $Label.ToUpperInvariant())
# Use the worktree path directly, never a stale $Worktree variable.
$title = ('{0} - {1} - ' -f $Color.ToUpperInvariant(), $folderLabel) +
    '$' + '{activeEditorShort} - ' + '$' + '{rootName}'

if (-not $env:LOCALAPPDATA) {
    throw 'HOLD: Windows LOCALAPPDATA is required for external workspace storage.'
}
$workspaceDir = Join-Path $env:LOCALAPPDATA 'MSB-VSCode-Workspaces'
[System.IO.Directory]::CreateDirectory($workspaceDir) | Out-Null
$slug = ($Label.ToLowerInvariant() -replace '[^a-z0-9_-]+', '-').Trim('-')
$sha256 = [System.Security.Cryptography.SHA256]::Create()
try {
    $digest = [BitConverter]::ToString(
        $sha256.ComputeHash([System.Text.Encoding]::UTF8.GetBytes(
            $gitRoot.ToLowerInvariant()
        ))
    ).Replace('-', '').ToLowerInvariant().Substring(0, 8)
} finally {
    $sha256.Dispose()
}
$workspaceName = ('MSB-Feature-{0}-{1}-{2}.code-workspace' -f
    $IssueNumber, $slug, $digest)
$workspaceFile = Join-Path $workspaceDir $workspaceName

# A workspace may have user preferences. Preserve it before any update.
if (Test-Path -LiteralPath $workspaceFile) {
    $previous = Get-Content -LiteralPath $workspaceFile -Raw |
        ConvertFrom-Json
    if ($null -eq $previous.folders -or
        @($previous.folders).Count -ne 1 -or
        -not [string]::Equals(
            [string]$previous.folders[0].path,
            $gitRoot,
            [System.StringComparison]::OrdinalIgnoreCase
        )) {
        throw 'HOLD: An existing workspace points to a different checkout.'
    }
    $backup = '{0}.backup-{1}' -f $workspaceFile,
        (Get-Date -Format 'yyyyMMdd-HHmmssfff')
    Copy-Item -LiteralPath $workspaceFile -Destination $backup
}

$settings = @{
    'window.title' = $title
    'workbench.colorTheme' = 'Default Dark Modern'
    'terminal.integrated.fontSize' = 14
    'editor.fontSize' = 14
    'window.zoomLevel' = 0
    'workbench.colorCustomizations' = @{
        'titleBar.activeBackground' = $theme.title
        'titleBar.activeForeground' = '#FFFFFF'
        'titleBar.inactiveBackground' = $theme.inactive
        'titleBar.inactiveForeground' = '#E6ECF5'
        'activityBar.background' = $theme.bar
        'activityBar.foreground' = '#FFFFFF'
        'statusBar.background' = $theme.status
        'statusBar.foreground' = '#FFFFFF'
        'sideBar.background' = '#10243C'
        'sideBar.foreground' = '#F8FAFC'
        'editor.background' = '#0F172A'
        'editor.foreground' = '#F8FAFC'
        'panel.background' = '#101A2D'
        'terminal.background' = '#101A2D'
        'terminal.foreground' = '#F8FAFC'
        'terminalCursor.foreground' = '#FFCC33'
        'terminal.selectionBackground' = '#365076'
    }
}
$workspace = @{
    folders = @(@{ name = $folderLabel; path = $gitRoot })
    settings = $settings
}
$json = $workspace | ConvertTo-Json -Depth 10
[System.IO.File]::WriteAllText(
    $workspaceFile, $json, (New-Object System.Text.UTF8Encoding($false))
)

Write-Host ('Feature:  #{0} / {1}' -f $IssueNumber, $branchName)
Write-Host ('Checkout: {0}' -f $gitRoot)
Write-Host ('Color:    {0}; terminal/editor 14px, zoom 0' -f $Color)
Write-Host ('Workspace (outside Git): {0}' -f $workspaceFile)

$changes = @(& git -C $gitRoot status --porcelain --untracked-files=all)
if ($LASTEXITCODE -ne 0) {
    throw 'HOLD: Git status check failed. No Git files were altered.'
}
if ($changes.Count -gt 0) {
    Write-Warning 'Git worktree has existing changes; workspace setup did not modify or clear them.'
}
if (-not $NoLaunch) {
    if (-not (Get-Command code -ErrorAction SilentlyContinue)) {
        throw ('Workspace saved; VS Code command "code" not found. Open manually: {0}' -f
            $workspaceFile)
    }
    & code --new-window $workspaceFile
    if ($LASTEXITCODE -ne 0) {
        throw 'VS Code did not open. The external workspace file is safe.'
    }
}
