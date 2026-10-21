<# #447 isolated reviewer launcher. Source only; no Production mutation.
Invoked from ANY clean primary repository checkout. Creates one owned temporary
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
$remoteHead=(& git -C $root rev-parse "refs/remotes/origin/$branch").Trim()
if ($LASTEXITCODE -ne 0 -or $remoteHead -ne $CandidateSha) {
    throw "STOP: origin/$branch is $remoteHead, not authorized candidate $CandidateSha."
}
# Never take an existing branch away from another checkout, including another workstation worktree.
$registered=& git -C $root worktree list --porcelain
if ($LASTEXITCODE -ne 0) { throw 'STOP: cannot inspect worktree ownership.' }
if (@($registered | Where-Object { $_ -eq "branch refs/heads/$branch" }).Count -gt 0) {
    throw "STOP: branch $branch is already checked out in a worktree. Reuse or finish that owner; do not duplicate."
}
# Only create local branch if it is not already present; do not reset/rebase it.
& git -C $root show-ref --verify --quiet "refs/heads/$branch"
$existsLocal=($LASTEXITCODE -eq 0)
if ($existsLocal) {
    $localHead=(& git -C $root rev-parse "refs/heads/$branch").Trim()
    if ($LASTEXITCODE -ne 0 -or $localHead -ne $CandidateSha) {
        throw 'STOP: existing local feature branch has different history; do not move it.'
    }
}
$stamp=[DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfff')
$dir=Join-Path ([IO.Path]::GetTempPath()) "msb-447-review-$stamp-$PID"
$created=$false
try {
    if ($existsLocal) {
        & git -C $root worktree add -- $dir $branch
    } else {
        & git -C $root worktree add -b $branch -- $dir "refs/remotes/origin/$branch"
    }
    if ($LASTEXITCODE -ne 0) { throw 'STOP: isolated review worktree could not be created.' }
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
        if ($LASTEXITCODE -ne 0) { throw 'STOP: existing Work Orders disposable review failed.' }
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
