# Windows regression for local MSB feature-worktree workspace helper.
# Disposable Git fixture under TEMP; no Production operations.
[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Require([bool]$condition, [string]$message) {
    if (-not $condition) { throw ('FAIL: ' + $message) }
}

$scriptUnderTest = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\Open-MSBFeatureWorkspace.ps1')).ProviderPath
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('msb-feature-window-test-' + [guid]::NewGuid().ToString('N'))
$oldAppData = $env:LOCALAPPDATA
try {
    [System.IO.Directory]::CreateDirectory($tempRoot) | Out-Null
    $env:LOCALAPPDATA = Join-Path $tempRoot 'LocalAppData'
    [System.IO.Directory]::CreateDirectory($env:LOCALAPPDATA) | Out-Null
    $checkout = Join-Path $tempRoot 'FeatureWorktree'
    & git init -q -b 'issue-419-test' $checkout
    Require ($LASTEXITCODE -eq 0) 'Git fixture initialization failed'
    [System.IO.Directory]::CreateDirectory((Join-Path $checkout '.vscode')) | Out-Null
    $tracked = Join-Path $checkout '.vscode\settings.json'
    [System.IO.File]::WriteAllText($tracked, '{"workbench.colorTheme":"Existing tracked theme"}')
    & git -C $checkout add -f .vscode/settings.json
    Require ($LASTEXITCODE -eq 0) 'Could not stage fixture'
    & git -C $checkout -c 'user.name=MSB Test' -c 'user.email=test@example.invalid' commit -qm 'fixture'
    Require ($LASTEXITCODE -eq 0) 'Could not commit fixture'

    foreach ($item in @(
        @{ issue = 419; label = 'WORK ORDERS'; color = 'BLUE' },
        @{ issue = 88; label = 'CONTAINER REVIEW'; color = 'YELLOW' },
        @{ issue = 171; label = 'GIS'; color = 'TEAL' }
    )) {
        & $scriptUnderTest -WorktreePath $checkout -IssueNumber $item.issue -Label $item.label -NoLaunch
        $workspaceFolder = Join-Path $env:LOCALAPPDATA 'MSB-VSCode-Workspaces'
        $found = @(Get-ChildItem -LiteralPath $workspaceFolder -Filter ('MSB-Feature-{0}-*.code-workspace' -f $item.issue))
        Require ($found.Count -eq 1) ('Workspace missing for issue #' + $item.issue)
        $workspace = Get-Content -LiteralPath $found[0].FullName -Raw | ConvertFrom-Json
        Require ($workspace.folders.Count -eq 1) 'Workspace must have one folder'
        Require ([string]::Equals([string]$workspace.folders[0].path, $checkout, [System.StringComparison]::OrdinalIgnoreCase)) 'Wrong worktree'
        Require ($workspace.settings.'workbench.colorTheme' -eq 'Default Dark Modern') 'High contrast theme missing'
        Require ($workspace.settings.'terminal.integrated.fontSize' -eq 14) 'Terminal font regression'
        Require ($workspace.settings.'editor.fontSize' -eq 14) 'Editor font regression'
        Require ($workspace.settings.'window.zoomLevel' -eq 0) 'Zoom regression'
        Require ($workspace.settings.'window.title'.StartsWith($item.color + ' - #' + $item.issue + ' ')) 'Wrong workstream title'
        Require ($workspace.settings.'workbench.colorCustomizations'.'terminal.foreground' -eq '#F8FAFC') 'Terminal color regression'
        $status = @(& git -C $checkout status --porcelain --untracked-files=all)
        Require ($LASTEXITCODE -eq 0) 'Git status failed'
        Require ($status.Count -eq 0) 'Tracked worktree changed'
        Require ((Get-Content -LiteralPath $tracked -Raw).Trim() -eq '{"workbench.colorTheme":"Existing tracked theme"}') 'Tracked .vscode altered'
    }

    & $scriptUnderTest -WorktreePath $checkout -IssueNumber 419 -Label 'WORK ORDERS' -NoLaunch
    $backups = @(Get-ChildItem -LiteralPath (Join-Path $env:LOCALAPPDATA 'MSB-VSCode-Workspaces') -Filter 'MSB-Feature-419-*.backup-*')
    Require ($backups.Count -ge 1) 'Existing external workspace was not backed up'

    $nested = Join-Path $checkout 'Subfolder'
    [System.IO.Directory]::CreateDirectory($nested) | Out-Null
    $denied = $false
    try {
        & $scriptUnderTest -WorktreePath $nested -IssueNumber 419 -Label 'WORK ORDERS' -NoLaunch
    } catch {
        $denied = $_.Exception.Message -like '*exact Git worktree root*'
    }
    Require $denied 'Nested path should fail closed'

    Write-Host 'PASS: distinct colors, 14px fonts, external workspace, unchanged Git'
}
finally {
    $env:LOCALAPPDATA = $oldAppData
    if (Test-Path -LiteralPath $tempRoot) { Remove-Item -LiteralPath $tempRoot -Recurse -Force }
}
