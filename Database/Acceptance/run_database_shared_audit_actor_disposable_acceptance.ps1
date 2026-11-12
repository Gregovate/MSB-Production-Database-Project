param(
    [string]$Server = 'msbadmin@192.168.5.9',
    [Parameter(Mandatory=$true)]
    [ValidatePattern('^[0-9a-f]{40}$')]
    [string]$CandidateSha,
    [string]$TargetRef = 'issue-122-b1a-task-finder'
)

$ErrorActionPreference = 'Stop'

if ($TargetRef -notmatch '^[A-Za-z0-9._/-]+$' -or $TargetRef.Contains('..')) {
    throw "Unsafe target ref: $TargetRef"
}

$repo = (& git rev-parse --show-toplevel).Trim()
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($repo)) {
    throw 'Run this command from the MSB-Production-Database-Project repository.'
}

$required = @(
    'Database/Basic_Query_Tools_Dev/Repair-SetActorOnUpdate-Attribution.sql',
    'Database/Acceptance/database_shared_audit_actor_disposable_validation.sql',
    'Database/Acceptance/database_shared_audit_actor_disposable_server.sh',
    'Setup/Application/test_shared_audit_actor_contract.py'
)

foreach ($path in $required) {
    & git -C $repo cat-file -e "${CandidateSha}:${path}" 2>$null
    if ($LASTEXITCODE -ne 0) {
        throw "Exact candidate $CandidateSha is missing required file: $path"
    }
}

$stamp = Get-Date -Format 'yyyyMMddTHHmmss'
$bundleName = "msb-database-audit-actor-$stamp"
$localBundle = Join-Path $env:TEMP $bundleName
$remoteBundle = "/tmp/$bundleName"

Remove-Item -LiteralPath $localBundle -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path $localBundle | Out-Null

try {
    $sourceRunner = Join-Path $repo 'Database/Acceptance/database_shared_audit_actor_disposable_server.sh'
    $runner = Join-Path $localBundle 'database_shared_audit_actor_disposable_server.sh'
    $text = [System.IO.File]::ReadAllText($sourceRunner)
    $text = $text -replace "`r`n", "`n"
    [System.IO.File]::WriteAllText($runner, $text, [System.Text.UTF8Encoding]::new($false))

    Write-Host '========== DATABASE-WIDE SHARED AUDIT ACTOR DISPOSABLE ACCEPTANCE =========='
    Write-Host 'Authority: MSB-Server-Management — PostgreSQL_Disposable_Acceptance_Standard.md'
    Write-Host "Server:        $Server"
    Write-Host "Candidate SHA: $CandidateSha"
    Write-Host "Target ref:    $TargetRef"
    Write-Host 'Production access: pg_dump + SELECT only.'
    Write-Host 'All repair and validation writes occur in the disposable current-Production clone.'
    Write-Host

    & scp -r $localBundle "${Server}:/tmp/"
    if ($LASTEXITCODE -ne 0) {
        throw "SCP database audit acceptance bundle upload failed with exit code $LASTEXITCODE"
    }

    $remoteRunner = "$remoteBundle/database_shared_audit_actor_disposable_server.sh"
    $remoteCommand = "chmod 700 '$remoteRunner' && bash -n '$remoteRunner' && timeout --foreground --signal=TERM 1800s bash '$remoteRunner' '$CandidateSha' '$TargetRef'"

    & ssh -tt -o ServerAliveInterval=15 -o ServerAliveCountMax=3 $Server $remoteCommand
    $remoteExit = $LASTEXITCODE
    if ($remoteExit -ne 0) {
        throw "Database-wide shared audit actor disposable acceptance failed with exit code $remoteExit. Review the retained remote report."
    }

    Write-Host
    Write-Host 'DATABASE-WIDE SHARED AUDIT ACTOR DISPOSABLE ACCEPTANCE: CLEAN EXIT'
}
finally {
    Remove-Item -LiteralPath $localBundle -Recurse -Force -ErrorAction SilentlyContinue
}
