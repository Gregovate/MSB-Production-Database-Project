param(
    [string]$Server = 'msbadmin@192.168.5.9',
    [Parameter(Mandatory=$true)]
    [int]$PreviewPort,
    [string]$PreviewEmail = 'gliebig@sheboyganlights.org'
)

$ErrorActionPreference = 'Stop'

if ($PreviewPort -eq 8794) {
    throw 'PreviewPort 8794 is the live Production Setup listener and must never be used for browser preview.'
}

$patchImpl = Join-Path $PSScriptRoot 'run_setup_session_browser_preview_patch_impl.ps1'
if (-not (Test-Path -LiteralPath $patchImpl)) {
    throw "Setup browser preview patch implementation is missing: $patchImpl"
}

# Normalize the patch implementation itself before PowerShell parses its
# multiline here-strings. This makes all guarded LF comparisons deterministic
# on Windows without changing tracked files in the worktree.
$text = [System.IO.File]::ReadAllText($patchImpl)
$text = $text.Replace("`r`n", "`n").Replace("`r", "`n")

# The dynamically compiled patch script has no reliable automatic PSScriptRoot,
# so substitute the real Acceptance directory as a literal before execution.
$rootLiteral = $PSScriptRoot.Replace("'", "''")
$text = $text.Replace('$PSScriptRoot', "'$rootLiteral'")

$script = [scriptblock]::Create($text)
& $script -Server $Server -PreviewPort $PreviewPort -PreviewEmail $PreviewEmail
