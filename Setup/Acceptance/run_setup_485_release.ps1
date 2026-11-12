param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[0-9a-f]{40}$')]
    [string]$ReleaseSha,
    [string]$Server = 'msbadmin@192.168.5.9',
    [switch]$Deploy
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

# This tool release must retain the exact PR485 accepted application target.
$ReleaseSource = (& git -C $Primary show "$($ReleaseSha):Setup/Acceptance/setup_485_release.py")
if ($LASTEXITCODE -ne 0 -or
    -not ($ReleaseSource -join "`n").Contains('3f281e49bf44a5d64a3be5e43f71319f59c8c27f')) {
    throw 'STOP: Release profile is missing the approved PR485 target.'
}

$Review = Join-Path ([System.IO.Path]::GetTempPath()) ('MSB485-release-' + [guid]::NewGuid().ToString('N'))
$Bundle = Join-Path ([System.IO.Path]::GetTempPath()) ('MSB485-bundle-' + [guid]::NewGuid().ToString('N'))
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
    & python (Join-Path $Review 'Setup\Acceptance\setup_485_transport.py') $Review $Bundle
    if ($LASTEXITCODE -ne 0) { throw 'STOP: Exact committed-byte transport failed.' }

    Write-Host 'Release authority: #122 / Server Management database-change runbook'
    Write-Host "Exact tooling: $ReleaseSha"
    Write-Host 'Accepted application: 3f281e49bf44a5d64a3be5e43f71319f59c8c27f'
    Write-Host 'Exact Setup source target: 3f281e49bf44a5d64a3be5e43f71319f59c8c27f'
    Write-Host 'Migration: Setup/Database/081_add_unscheduled_setup_qc_findings.sql'
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
    $Command = "sudo -v && timeout --foreground --signal=TERM 2400s env PYTHONDONTWRITEBYTECODE=1 python3 '$Remote/setup_485_release.py' '$Remote/setup_485_release.json' $Mode && rm -- '$Remote/setup_485_release.py' '$Remote/setup_485_release.json' '$Remote/setup_478_local_calendar_release.py' '$Remote/setup_maintenance_deploy.py' && rmdir -- '$Remote'"
    & ssh -tt -o ServerAliveInterval=15 -o ServerAliveCountMax=3 $Server $Command
    if ($LASTEXITCODE -ne 0) {
        throw "HOLD: Release runner returned $LASTEXITCODE. Retain remote report; do not retry or change maintenance state."
    }
    if ($Deploy) {
        Write-Host 'PR485 REMOTE RUNNER PASS — retain snapshot and report; protected live check remains.'
    } else {
        Write-Host 'PR485 PREFLIGHT PASS — Production unchanged.'
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
