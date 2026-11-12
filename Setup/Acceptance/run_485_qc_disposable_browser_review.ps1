<# 
PR #485 current-Production disposable QC Check browser review.
- Exact commit; one temporary detached-source review branch; no Production writes.
- Uses EXISTING Setup acceptance runner, port 8898 and Server Management profile.
- Preserves any failed/dirty review worktree for diagnosis.
#>
param(
    [Parameter(Mandatory = $true)][string]$CandidateSha,
    [string]$ReviewerEmail = 'gliebig@sheboyganlights.org',
    [string]$PrimaryRepo = 'C:\Users\Greg\Github\MSB-Production-Database-Project'
)
$ErrorActionPreference = 'Stop'
$Ref = 'feature/122-perform-work-qc-finder-post483'
$ExpectedVersion = 'V0.3.114-qc-history'
if ($CandidateSha -cnotmatch '^[a-f0-9]{40}$') { throw 'HOLD: exact candidate SHA required.' }
if (-not (Test-Path -LiteralPath $PrimaryRepo -PathType Container)) { throw 'HOLD: MSB main worktree missing.' }
$Origin = (& git -C $PrimaryRepo remote get-url origin)
if ($LASTEXITCODE -ne 0 -or ([string]$Origin) -notmatch 'Gregovate/MSB-Production-Database-Project(?:\.git)?$') {
    throw 'HOLD: unexpected repository origin.'
}
# Discover registered worktrees before choosing a new review directory.
& git -C $PrimaryRepo worktree list --porcelain
if ($LASTEXITCODE -ne 0) { throw 'HOLD: worktree discovery failed.' }
# Fetch just this branch; do NOT switch, pull or overwrite the current checkout.
& git -C $PrimaryRepo fetch origin "+refs/heads/${Ref}:refs/remotes/origin/${Ref}"
if ($LASTEXITCODE -ne 0) { throw 'HOLD: candidate fetch failed.' }
$Remote = (& git -C $PrimaryRepo rev-parse "refs/remotes/origin/$Ref")
if ($LASTEXITCODE -ne 0 -or ([string]$Remote).Trim() -cne $CandidateSha) {
    throw 'HOLD: exact candidate differs from requested SHA.'
}
$Short = $CandidateSha.Substring(0,12)
$LocalBranch = "review/485-qc-$Short"
$Review = Join-Path $env:TEMP "MSB-QC485-$Short"
if (Test-Path -LiteralPath $Review) { throw "HOLD: review worktree path already exists: $Review" }
$wasCreated = $false
$cleanExit = $false
$start = (Get-Location).Path
try {
    & git -C $PrimaryRepo worktree add -b $LocalBranch $Review $CandidateSha
    if ($LASTEXITCODE -ne 0) { throw 'HOLD: local exact-SHA worktree creation failed.' }
    $wasCreated = $true
    Set-Location -LiteralPath $Review
    Write-Host "PR485 TEST CANDIDATE: $CandidateSha"
    Write-Host 'WRITABLE DISPOSABLE REVIEW: Scheduled Work / QC Check / QC Repairs Needed. All test writes go to the clone.'
    Write-Host 'Production unchanged; ordinary Production activity can continue.'
    & (Join-Path $Review 'Setup\Acceptance\run_setup_disposable_browser_preview.ps1') `
       -PreviewPort 8898 `
       -CandidateSha $CandidateSha `
       -TargetRef $Ref `
       -LocalReviewBranch $LocalBranch `
       -PreviewEmail $ReviewerEmail `
       -ExpectedVersion $ExpectedVersion `
       -MigrationPaths @('Setup/Database/081_add_unscheduled_setup_qc_findings.sql') `
       -ValidationPaths @('Setup/Acceptance/setup_122_qc_disposable_acceptance.sql') `
       -AllowConcurrentProductionWrites
    if (-not $?) { throw 'HOLD: disposable browser preview did not exit cleanly.' }
    $cleanExit = $true
} finally {
    Set-Location -LiteralPath $start
    if ($wasCreated -and $cleanExit) {
        $dirty = @(git -C $Review status --porcelain)
        $actual = (& git -C $Review rev-parse HEAD)
        if ($LASTEXITCODE -eq 0 -and ([string]$actual).Trim() -ceq $CandidateSha -and $dirty.Count -eq 0) {
            & git -C $PrimaryRepo worktree remove $Review
            if ($LASTEXITCODE -ne 0) { Write-Warning "Preserve review path for inspection: $Review" }
            else { & git -C $PrimaryRepo branch -D $LocalBranch | Out-Null }
        } else {
            Write-Warning "HOLD: preserving unexpected changed worktree: $Review"
        }
    } elseif ($wasCreated) {
        Write-Warning "HOLD: preserving test worktree for diagnostic review: $Review"
    }
}
