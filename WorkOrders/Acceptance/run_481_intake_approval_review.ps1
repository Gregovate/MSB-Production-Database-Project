param(
  [string]$ReviewerEmail = 'gliebig@sheboyganlights.org',
  [string]$Server = 'msbadmin@192.168.5.9'
)
$ErrorActionPreference = 'Stop'
# The primary MSB repository is an explicit worksite, not the current directory.
$Primary = 'C:\lor\ImportExport\MSB-Main'
$Ref = 'feature/122-unified-ticket-setup-accountability-20261111'
if (-not (Test-Path -LiteralPath $Primary -PathType Container)) {
  throw "HOLD: primary MSB checkout not found: $Primary"
}
$Origin = (& git -C $Primary remote get-url origin).Trim()
if ($LASTEXITCODE -ne 0 -or $Origin -notmatch 'Gregovate/MSB-Production-Database-Project(?:\.git)?$') {
  throw 'HOLD: primary repository identity differs.'
}
& git -C $Primary fetch origin "+refs/heads/$($Ref):refs/remotes/origin/$($Ref)"
if ($LASTEXITCODE -ne 0) { throw 'HOLD: exact candidate fetch failed.' }
$Sha = (& git -C $Primary rev-parse "refs/remotes/origin/$Ref").Trim()
if ($LASTEXITCODE -ne 0 -or $Sha -notmatch '^[0-9a-f]{40}$') { throw 'HOLD: exact SHA unavailable.' }
$Review = Join-Path ([System.IO.Path]::GetTempPath()) ('MSB481-' + $Sha.Substring(0,12))
if (Test-Path -LiteralPath $Review) {
  throw "HOLD: existing review worktree path is occupied: $Review"
}
$Prior = (Get-Location).Path
$Created = $false
$Passed = $false
try {
  & git -C $Primary worktree add --detach $Review $Sha
  if ($LASTEXITCODE -ne 0) { throw 'HOLD: detached exact-SHA review not created.' }
  $Created = $true
  Set-Location -LiteralPath $Review
  Write-Host "PR481 exact candidate: $Sha"
  Write-Host 'Current Production unchanged: browser writes go to the disposable clone.'
  Write-Host 'Manager review: compare INTAKE-84/85/87 and optional wiring task.'
  & (Join-Path $Review 'WorkOrders\Acceptance\run_work_management_disposable_browser_preview.ps1') `
    -CandidateSha $Sha `
    -CandidateRef $Ref `
    -PreviewPort 8898 `
    -PreviewEmail $ReviewerEmail `
    -ApprovedReviewProfile `
    -V1Browser `
    -V1ReviewerRole Manager `
    -Server $Server
  if (-not $?) { throw 'HOLD: browser preview returned failure. Preserve candidate for recovery.' }
  $Passed = $true
} finally {
  Set-Location -LiteralPath $Prior
  if ($Created -and $Passed) {
    $Status = @(git -C $Review status --porcelain)
    $Head = (& git -C $Review rev-parse HEAD).Trim()
    if ($LASTEXITCODE -eq 0 -and $Head -eq $Sha -and $Status.Count -eq 0) {
      & git -C $Primary worktree remove $Review
      if ($LASTEXITCODE -ne 0) { Write-Warning "Preserve review worktree: $Review" }
    } else {
      Write-Warning "Preserve changed review worktree: $Review"
    }
  }
}
