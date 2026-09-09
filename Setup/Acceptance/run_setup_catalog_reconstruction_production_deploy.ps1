param(
    [string]$Server = 'msbadmin@192.168.5.9'
)

$ErrorActionPreference = 'Stop'

$AcceptedTargetSha = '19239e3584a66913ecaa5f0406434be54618c303'
$repo = (git rev-parse --show-toplevel).Trim()
if (-not $repo) {
    throw 'Run this wrapper from an MSB-Production-Database-Project checkout.'
}

$dirty = git -C $repo status --porcelain
if ($LASTEXITCODE -ne 0) {
    throw 'Unable to verify local Git worktree status.'
}
if ($dirty) {
    throw "Local worktree is not clean.`n$dirty"
}

& git -C $repo cat-file -e "${AcceptedTargetSha}^{commit}"
if ($LASTEXITCODE -ne 0) {
    throw "Accepted Setup catalog target is not available locally: $AcceptedTargetSha"
}

$serverScript = Join-Path $repo 'Setup\Acceptance\setup_catalog_reconstruction_production_deploy_server.sh'
if (-not (Test-Path -LiteralPath $serverScript -PathType Leaf)) {
    throw "Required Production deployment runner is missing: $serverScript"
}

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$bundleName = "msb-setup-catalog-production-$stamp"
$localBundle = Join-Path $env:TEMP $bundleName
$remoteRoot = "/tmp/$bundleName"
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)

Write-Host '========== SETUP CATALOG RECONSTRUCTION PRODUCTION DEPLOYMENT =========='
Write-Host "Server:              $Server"
Write-Host "Accepted target SHA: $AcceptedTargetSha"
Write-Host "Remote bundle:       $remoteRoot"
Write-Host 'Authority: Gregovate/MSB-Server-Management — docs/server/Production_Database_Change_Deployment_Runbook.md'
Write-Host 'Procedure: exact accepted target + migrations 023/024 + bounded Setup service promotion'
Write-Host 'This is the explicit Production mutation step approved after disposable and browser acceptance.'
Write-Host

try {
    New-Item -ItemType Directory -Path $localBundle -Force | Out-Null

    $serverText = [System.IO.File]::ReadAllText($serverScript)
    $serverText = $serverText.Replace("`r`n", "`n").Replace("`r", "`n")
    $localServer = Join-Path $localBundle 'setup_catalog_reconstruction_production_deploy_server.sh'
    [System.IO.File]::WriteAllText($localServer, $serverText, $utf8NoBom)

    & scp -r $localBundle "${Server}:/tmp/"
    if ($LASTEXITCODE -ne 0) {
        throw "SCP Production deployment bundle upload failed with exit code $LASTEXITCODE"
    }

    & ssh -tt $Server "bash -n '$remoteRoot/setup_catalog_reconstruction_production_deploy_server.sh' && chmod 700 '$remoteRoot/setup_catalog_reconstruction_production_deploy_server.sh' && timeout --signal=TERM 1800s bash '$remoteRoot/setup_catalog_reconstruction_production_deploy_server.sh'"
    $remoteExit = $LASTEXITCODE
    if ($remoteExit -ne 0) {
        throw "Setup catalog Production deployment failed with exit code $remoteExit. Use the retained Setup_Catalog_Reconstruction_Production_Deploy report named in the output."
    }

    Write-Host
    Write-Host 'SETUP CATALOG RECONSTRUCTION PRODUCTION WRAPPER: PASS'
}
finally {
    Remove-Item -LiteralPath $localBundle -Recurse -Force -ErrorAction SilentlyContinue
}
