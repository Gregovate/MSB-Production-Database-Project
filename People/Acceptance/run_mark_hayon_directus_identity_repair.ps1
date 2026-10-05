param(
    [string]$ApplicationRepo = 'C:\\lor\\ImportExport\\VSCode',
    [string]$Server = 'msbadmin@192.168.5.9'
)

$ErrorActionPreference = 'Stop'

$RepairRef = 'agent/people-identity-link-acceptance-gap-20260910'
$RepairSha = 'a4a633df4d49f8a30af9f226157986933d7b9a70'
$RepairPath = 'People/Acceptance/repair_mark_hayon_directus_identity_production.sh'
$RepairSha256 = 'A2EDFC5A48D6EEE772D752B2D0333B196A4DE7B22D10535E740206207FA40104'
$RemoteScript = '/tmp/msb-mark-hayon-identity-repair.sh'

$repo = (& git -C $ApplicationRepo rev-parse --show-toplevel).Trim()
if ($LASTEXITCODE -ne 0 -or -not $repo) {
    throw "ApplicationRepo is not a Git checkout: $ApplicationRepo"
}

Write-Host '========== MARK HAYON IDENTITY REPAIR =========='
Write-Host "Application repo: $repo"
Write-Host "Repair ref:       $RepairRef"
Write-Host "Repair SHA:       $RepairSha"
Write-Host "Repair artifact:  $RepairSha256"
Write-Host "Server:           $Server"
Write-Host

& git -C $repo fetch origin $RepairRef
if ($LASTEXITCODE -ne 0) {
    throw "Unable to fetch origin/$RepairRef"
}

& git -C $repo cat-file -e "${RepairSha}^{commit}"
if ($LASTEXITCODE -ne 0) {
    throw "Exact repair commit is not available locally: $RepairSha"
}

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$localRoot = Join-Path $env:TEMP "msb-mark-hayon-identity-$stamp"
$archive = Join-Path $localRoot 'repair.tar'
$extractRoot = Join-Path $localRoot 'extract'
$localScript = Join-Path $extractRoot $RepairPath

try {
    New-Item -ItemType Directory -Path $extractRoot -Force | Out-Null

    & git -c core.autocrlf=false -c core.eol=lf -C $repo archive --format=tar "--output=$archive" $RepairSha $RepairPath
    if ($LASTEXITCODE -ne 0) {
        throw 'Unable to materialize exact repository-owned repair artifact.'
    }

    & tar -xf $archive -C $extractRoot
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $localScript)) {
        throw 'Unable to extract exact repair artifact.'
    }

    $actualHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $localScript).Hash.ToUpperInvariant()
    if ($actualHash -ne $RepairSha256) {
        throw "STOP before server contact: repair SHA-256 mismatch. Expected $RepairSha256 but got $actualHash"
    }

    Write-Host 'Local exact-artifact gate: PASS'
    Write-Host

    & scp $localScript "${Server}:$RemoteScript"
    if ($LASTEXITCODE -ne 0) {
        throw 'SCP of repair artifact failed.'
    }

    $remoteCommand = "chmod 700 '$RemoteScript'; sudo '$RemoteScript'; rc=`$?; rm -f '$RemoteScript'; exit `$rc"
    & ssh -t $Server $remoteCommand
    $remoteExit = $LASTEXITCODE

    if ($remoteExit -ne 0) {
        throw "Mark identity repair stopped with exit code $remoteExit. Do not retry or improvise; preserve the displayed maintenance/rollback state."
    }

    Write-Host
    Write-Host 'MARK HAYON IDENTITY REPAIR WRAPPER: PASS'
}
finally {
    Remove-Item -LiteralPath $localRoot -Recurse -Force -ErrorAction SilentlyContinue
}
