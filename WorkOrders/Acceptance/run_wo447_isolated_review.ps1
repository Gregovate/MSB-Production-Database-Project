<# #447 isolated reviewer launcher. Source only; no Production mutation.
Invoked from ANY clean primary repository checkout. Creates one owned temporary detached
local worktree for the exact reviewed feature branch, then invokes the EXISTING
Work Orders disposable preview and removes only that worktree on clean exit.
Never opens VS Code, never switches the caller's branch.
#>
param(
    [Parameter(Mandatory=$true)][string]$CandidateSha,
    [Parameter(Mandatory=$true)][string]$PreviewEmail,
    [ValidateSet('Manager','Crew')][string]$V1ReviewerRole='Manager',
    [int]$PreviewPort=8898
)
$ErrorActionPreference='Stop'
$branch='fix/work-orders-identity-reconciliation'
$root=(& git rev-parse --show-toplevel).Trim()
if ($LASTEXITCODE -ne 0 -or -not $root) { throw 'STOP: invoke inside an MSB repository checkout.' }
if ($CandidateSha -cnotmatch '^[a-f0-9]{40}$') { throw 'STOP: exact candidate SHA required.' }
if ($PreviewPort -ne 8898) { throw 'STOP: only existing approved port 8898 permitted.' }
if (git -C $root status --porcelain) { throw 'STOP: calling checkout has uncommitted changes.' }
$startingHead=(& git -C $root rev-parse HEAD).Trim()
$startingBranch=(& git -C $root branch --show-current).Trim()
& git -C $root fetch origin $branch
if ($LASTEXITCODE -ne 0) { throw 'STOP: remote feature branch fetch failed.' }
# Fetch an exact feature head without creating or moving any local branch.
$remoteHead=(& git -C $root ls-remote origin "refs/heads/$branch")
if ($LASTEXITCODE -ne 0 -or -not $remoteHead) { throw 'STOP: cannot verify remote candidate ref.' }
$remoteSha=($remoteHead -split '\s+')[0]
if ($remoteSha -ne $CandidateSha) {
    throw "STOP: remote candidate $remoteSha differs from reviewed $CandidateSha."
}
& git -C $root cat-file -e "$CandidateSha^{commit}"
if ($LASTEXITCODE -ne 0) { throw 'STOP: exact candidate object unavailable locally.' }
$stamp=[DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfff')
$dir=Join-Path ([IO.Path]::GetTempPath()) "msb-447-review-$stamp-$PID"
$created=$false
try {
    & git -C $root worktree add --detach -- $dir $CandidateSha
    if ($LASTEXITCODE -ne 0) { throw 'STOP: isolated detached review worktree could not be created.' }
    $created=$true
    $actual=(& git -C $dir rev-parse HEAD).Trim()
    if ($LASTEXITCODE -ne 0 -or $actual -ne $CandidateSha) {
        throw 'STOP: isolated worktree does not match exact approved candidate.'
    }
    Write-Host "Review worktree: $dir"
    Write-Host "Exact candidate: $actual"
    Write-Host 'No VS Code window or primary branch switch was made.'
    Push-Location $dir
    try {
        & (Join-Path $dir 'WorkOrders/Acceptance/run_work_management_disposable_browser_preview.ps1') `
          -CandidateSha $CandidateSha -PreviewPort $PreviewPort `
          -PreviewEmail $PreviewEmail -ApprovedReviewProfile -V1Browser `
          -V1ReviewerRole $V1ReviewerRole
        if (-not $?) { throw 'STOP: existing Work Orders disposable review failed.' }
    } finally { Pop-Location }
} finally {
    if ($created) {
        $dirty=& git -C $dir status --porcelain
        if ($LASTEXITCODE -eq 0 -and -not $dirty) {
            & git -C $root worktree remove -- $dir
            if ($LASTEXITCODE -ne 0) {
                Write-Warning "Review worktree retained; inspect safely: $dir"
            } else {
                Write-Host "PASS: owned temporary local worktree removed: $dir"
            }
        } else {
            Write-Warning "Review worktree retained due to changes or unavailable status: $dir"
        }
    }
    $endHead=(& git -C $root rev-parse HEAD).Trim()
    $endBranch=(& git -C $root branch --show-current).Trim()
    if ($endHead -ne $startingHead -or $endBranch -ne $startingBranch) {
        Write-Warning 'STOP: caller checkout changed unexpectedly; investigate before next task.'
    } else {
        Write-Host "PASS: calling checkout unchanged ($startingBranch $startingHead)"
    }
}
