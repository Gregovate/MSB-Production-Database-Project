param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[0-9a-f]{40}$')]
    [string]$ReleaseSha,
    [string]$Server = 'msbadmin@192.168.5.9'
)

$ErrorActionPreference = 'Stop'

# Never infer the repository from the current PowerShell directory.
$Primary = (& git rev-parse --show-toplevel).Trim()
if ($LASTEXITCODE -ne 0) { throw 'STOP: Run from the MSB repository.' }
if (-not (Test-Path -LiteralPath $Primary -PathType Container)) {
    throw "STOP: MSB primary repository not found: $Primary"
}

$Origin = (& git -C $Primary remote get-url origin).Trim()
if ($LASTEXITCODE -ne 0 -or
    $Origin -notmatch 'Gregovate/MSB-Production-Database-Project(?:\.git)?$') {
    throw "STOP: repository identity mismatch: $Origin"
}

# Fetch only the target main ref. Never update/reset the caller's checkout.
& git -C $Primary fetch origin '+refs/heads/main:refs/remotes/origin/main'
if ($LASTEXITCODE -ne 0) { throw 'STOP: Cannot refresh origin/main.' }

& git -C $Primary cat-file -e "$ReleaseSha^{commit}"
if ($LASTEXITCODE -ne 0) { throw 'STOP: Approved release commit unavailable.' }

& git -C $Primary merge-base --is-ancestor $ReleaseSha origin/main
if ($LASTEXITCODE -ne 0) { throw 'STOP: Release SHA is not merged into main.' }

# This tool release must retain the exact PR494 accepted application target.
$ReleaseSource = (& git -C $Primary show "$($ReleaseSha):Setup/Acceptance/setup_494_release.py")
if ($LASTEXITCODE -ne 0 -or
    -not ($ReleaseSource -join "`n").Contains('8164cae8ecb71311abaa8d41d4e6d4be3e223231')) {
    throw 'STOP: Release profile is missing the approved PR494 target.'
}

$Review = Join-Path ([System.IO.Path]::GetTempPath()) ('MSB494-release-' + [guid]::NewGuid().ToString('N'))
$Bundle = Join-Path ([System.IO.Path]::GetTempPath()) ('MSB494-bundle-' + [guid]::NewGuid().ToString('N'))
$Remote = '/tmp/' + (Split-Path -Leaf $Bundle)
# Discover all registered worktrees without switching or modifying them.
& git -C $Primary worktree list
if ($LASTEXITCODE -ne 0) { throw 'STOP: Worktree discovery failed.' }
$OwnReview = $false
try {
    & git -C $Primary worktree add --detach $Review $ReleaseSha
    if ($LASTEXITCODE -ne 0) { throw 'STOP: Isolated release worktree could not be created.' }
    $OwnReview = $true

    New-Item -ItemType Directory -Path $Bundle | Out-Null
    & python (Join-Path $Review 'Setup\Acceptance\setup_494_transport.py') $Review $Bundle
    if ($LASTEXITCODE -ne 0) { throw 'STOP: Exact committed-byte transport failed.' }

    Write-Host 'Authority: Server Management Setup_Source_Only_Application_Deployment_Runbook.md'
    Write-Host "Exact tooling: $ReleaseSha"
    Write-Host 'Accepted application: 8164cae8ecb71311abaa8d41d4e6d4be3e223231 / V0.3.127-inline-planning'
    Write-Host 'Source-only: no migration, maintenance entry, SMTP send or timer change.'
    Write-Host 'Pause Setup edits briefly for the read-only preservation checks. Only msb-setup is restarted.'

    & scp -r $Bundle "$($Server):/tmp/"
    if ($LASTEXITCODE -ne 0) { throw 'STOP: Single bundle transfer failed.' }

    # Foreground SSH owns sudo; retain the remote bundle on any failure.
    $Command = "sudo -v && timeout --foreground --signal=TERM 2400s env PYTHONDONTWRITEBYTECODE=1 python3 '$Remote/setup_494_release.py' && rm -- '$Remote/setup_494_release.py' '$Remote/setup_88_report_source_only_deploy.py' && rmdir -- '$Remote'"
    & ssh -tt -o ServerAliveInterval=15 -o ServerAliveCountMax=3 $Server $Command
    if ($LASTEXITCODE -ne 0) {
        throw "HOLD: Release runner returned $LASTEXITCODE. Retain remote report; do not retry or change maintenance state."
    }
    Write-Host 'PR494 REMOTE RUNNER PASS - retain report; protected live check remains.'
} finally {
    if ($OwnReview) {
        $Status = @(git -C $Review status --porcelain)
        $Head = (& git -C $Review rev-parse HEAD).Trim()
        if ($LASTEXITCODE -eq 0 -and $Status.Count -eq 0 -and $Head -eq $ReleaseSha) {
            & git -C $Primary worktree remove $Review
        } else {
            Write-Warning "Preserving release review worktree: $Review"
        }
    }
    if (Test-Path -LiteralPath $Bundle) {
        Remove-Item -LiteralPath $Bundle -Recurse -Force
    }
}
