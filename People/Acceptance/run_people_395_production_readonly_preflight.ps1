# #395 pre-mutation readiness only. No Production writes, restart, migration, or maintenance transition.
# Runs one bounded foreground SSH command and prints the server-owned final result block.
param(
    [string]$Server = 'msbadmin@192.168.5.9',
    [string]$TargetSha = '6122d7923c2a07eb6b278225cf71cafc4704d349'
)

$ErrorActionPreference = 'Stop'
$expectedBranch = 'issue-395-production-deployment-readiness'
$scriptName = 'people_395_production_readonly_preflight.sh'
$repo = (& git rev-parse --show-toplevel).Trim()
if ($LASTEXITCODE -ne 0 -or -not $repo) {
    throw 'STOP: not inside the MSB Production Database repository.'
}

$branch = (& git -C $repo branch --show-current).Trim()
if ($LASTEXITCODE -ne 0 -or $branch -ne $expectedBranch) {
    throw "STOP: expected current preflight engineering branch $expectedBranch, actual $branch"
}
$dirty = & git -C $repo status --porcelain
if ($LASTEXITCODE -ne 0 -or $dirty) {
    throw 'STOP: local repository is not clean.'
}

# Refresh remote authority; never merge/change local source inside this wrapper.
& git -C $repo fetch origin main $expectedBranch
if ($LASTEXITCODE -ne 0) { throw 'STOP: git remote refresh failed.' }
$remoteMain = (& git -C $repo ls-remote origin refs/heads/main)
if ($LASTEXITCODE -ne 0) { throw 'STOP: remote main cannot be verified.' }
$remoteMainSha = ($remoteMain -split '\s+')[0]
if ($remoteMainSha -ne $TargetSha) {
    throw "STOP: main is no longer exact approved target $TargetSha (current $remoteMainSha)."
}

# Contract-test the preflight tool before any server contact.
& python -m pytest -q -p no:cacheprovider People/Acceptance/test_people_395_production_readonly_preflight_contract.py
if ($LASTEXITCODE -ne 0) { throw 'STOP: read-only preflight tooling contract tests failed.' }

$source = Join-Path $repo "People\Acceptance\$scriptName"
if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
    throw "STOP: missing versioned preflight server script: $source"
}

$stamp = Get-Date -Format 'yyyyMMddTHHmmss'
$bundleName = "msb-people-395-production-preflight-$stamp"
$localBundle = Join-Path $env:TEMP $bundleName
$remoteBundle = "/tmp/$bundleName"
$remoteCode = 255

try {
    New-Item -ItemType Directory -Path $localBundle -ErrorAction Stop | Out-Null
    $linux = [System.IO.File]::ReadAllText($source)
    $linux = $linux.Replace("`r`n", "`n").Replace("`r", "`n")
    $noBom = [System.Text.UTF8Encoding]::new($false)
    [System.IO.File]::WriteAllText((Join-Path $localBundle $scriptName), $linux, $noBom)

    Write-Host 'Read-only People #395 Production readiness (no mutations)'
    Write-Host "Approved target: $TargetSha"
    Write-Host "Temporary upload: $remoteBundle"
    & scp -r $localBundle "${Server}:/tmp/"
    if ($LASTEXITCODE -ne 0) { throw 'STOP: SCP preflight bundle transfer failed.' }

    $runner = "$remoteBundle/$scriptName"
    $command = "chmod 700 '$remoteBundle' '$runner' && bash -n '$runner' && timeout --foreground --signal=TERM 1200s bash '$runner' '$TargetSha'"
    # Interactive SSH owns the console. Do not pipe it or background sudo.
    & ssh -tt -o ServerAliveInterval=15 -o ServerAliveCountMax=3 $Server $command
    $remoteCode = $LASTEXITCODE
    if ($remoteCode -ne 0) {
        throw "STOP: read-only Production readiness returned $remoteCode. Copy only the remote #395 RESULT block."
    }
}
finally {
    Remove-Item -LiteralPath $localBundle -Recurse -Force -ErrorAction SilentlyContinue
}
