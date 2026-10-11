# Issue #205 / PR #320 — governed local regression gate.
# Run from any PowerShell directory. No Node.js, database writes, or deployment.
# Prints candidate identity ONLY after successful regression.
[CmdletBinding()]
param(
    [string]$ExpectedSha = "",
    [string]$Branch = "fix/205-workload-visibility-accountability"
)

$ErrorActionPreference = "Stop"
$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path

# Worktree and branch checks prevent running tests against the wrong project.
$ActualBranch = (& git -C $RepoRoot branch --show-current).Trim()
if ($LASTEXITCODE -ne 0 -or $ActualBranch -ne $Branch) {
    throw "STOP: Wrong worktree branch: $ActualBranch (expected $Branch)"
}

$ActualSha = (& git -C $RepoRoot rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0) { throw "STOP: Cannot read candidate SHA" }
if ($ExpectedSha -and $ActualSha -ne $ExpectedSha) {
    throw "STOP: Candidate SHA mismatch: $ActualSha (expected $ExpectedSha)"
}

$Dirty = @(& git -C $RepoRoot status --porcelain)
if ($LASTEXITCODE -ne 0) { throw "STOP: Cannot read worktree status" }
if ($Dirty.Count -gt 0) {
    throw "STOP: Worktree has uncommitted changes"
}

Push-Location $RepoRoot
try {
    python -m pytest Setup/Application -q
    if ($LASTEXITCODE -ne 0) {
        throw "STOP: Setup regression failed for $ActualSha"
    }
} finally {
    Pop-Location
}

# Final terminal lines: never claim verified candidate if tests failed.
Write-Host ""
Write-Host "=============================================="
Write-Host "SETUP #205 REGRESSION: PASS"
Write-Host "Candidate SHA: $ActualSha"
Write-Host "Branch: $ActualBranch"
Write-Host "Production deployment: NOT AUTHORIZED"
Write-Host "=============================================="
