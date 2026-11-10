param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[0-9a-f]{40}$')]
    [string]$ReleaseSha,
    [string]$Server = 'msbadmin@192.168.5.9',
    [switch]$Deploy
)

$ErrorActionPreference = 'Stop'

# Never infer the repository from the current PowerShell directory.
$Primary = 'C:\lor\ImportExport\MSB-Main'
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

# This tool release must retain the exact PR478 accepted application target.
$ReleaseSource = (& git -C $Primary show "$($ReleaseSha):Setup/Acceptance/setup_478_local_calendar_release.py")
if ($LASTEXITCODE -ne 0 -or
    -not ($ReleaseSource -join "`n").Contains('e1d5c9d9d5ef5a8c59f0381ea559d240aed1c30b')) {
    throw 'STOP: Release profile is missing the approved PR478 target.'
}

$Review = Join-Path ([System.IO.Path]::GetTempPath()) ('MSB478-release-' + [guid]::NewGuid().ToString('N'))
$Bundle = Join-Path ([System.IO.Path]::GetTempPath()) ('MSB478-bundle-' + [guid]::NewGuid().ToString('N'))
$Remote = '/tmp/' + (Split-Path -Leaf $Bundle)
$OwnReview = $false
try {
    & git -C $Primary worktree add --detach $Review $ReleaseSha
    if ($LASTEXITCODE -ne 0) { throw 'STOP: Isolated release worktree could not be created.' }
    $OwnReview = $true

    New-Item -ItemType Directory -Path $Bundle | Out-Null
    & python (Join-Path $Review 'Setup\Acceptance\setup_478_transport.py') $Review $Bundle
    if ($LASTEXITCODE -ne 0) { throw 'STOP: Exact committed-byte transport failed.' }

    Write-Host 'Release authority: #122 / Server Management database-change runbook'
    Write-Host "Exact tooling: $ReleaseSha"
    Write-Host 'Accepted application: df5aedd897aa967e1c567dd9d53e40da1712f308'
    Write-Host 'Merged Setup target: e1d5c9d9d5ef5a8c59f0381ea559d240aed1c30b'
    Write-Host 'Migration: Setup/Database/079_fix_setup_local_calendar_boundaries.sql'
    Write-Host 'Production remains ONLINE during preflight.'
    if ($Deploy) {
        Write-Host 'AUTHORIZED DATABASE-CHANGING RELEASE: controller freeze, snapshot, migration, validation, ONLINE.'
    } else {
        Write-Host 'PREFLIGHT ONLY: no maintenance entry and no Production mutation.'
    }

    & scp -r $Bundle "$($Server):/tmp/"
    if ($LASTEXITCODE -ne 0) { throw 'STOP: Single bundle transfer failed.' }

    $Mode = ''
    if ($Deploy) { $Mode = '--deploy' }
    # Foreground SSH owns the console and sudo prompt; no background launch.
    $Command = "sudo -v && timeout --foreground --signal=TERM 2400s python3 '$Remote/setup_478_local_calendar_release.py' '$Remote/setup_478_local_calendar_release.json' $Mode"
    & ssh -tt -o ServerAliveInterval=15 -o ServerAliveCountMax=3 $Server $Command
    if ($LASTEXITCODE -ne 0) {
        throw "HOLD: Release runner returned $LASTEXITCODE. Retain remote report; do not retry or change maintenance state."
    }
    if ($Deploy) {
        Write-Host 'PR478 REMOTE RUNNER PASS — retain snapshot and report; protected live check remains.'
    } else {
        Write-Host 'PR478 PREFLIGHT PASS — Production unchanged.'
    }
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
