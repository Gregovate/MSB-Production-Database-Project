# MSB LOR operator-runner launcher
#
# Purpose:
#   Install, pair, start, and inspect the restricted Windows/G-drive runner
#   used by the authenticated LOR2DB website.
#
# Security:
#   The shared bearer token is generated once and stored with Windows DPAPI.
#   It is never printed or accepted as a command-line argument. PairServer
#   transfers it through SSH to a mode-0600 pending file for root installation.
#   The PostgreSQL ingest password is also stored with account-bound DPAPI and
#   is available only to the managed runner and fixed ingest child process. It
#   is never returned to the browser, Linux API, runner state, console output,
#   or command line.

[CmdletBinding()]
param(
    [ValidateSet('Install', 'ConfigureIngest', 'PairServer', 'Start', 'Stop', 'Status')]
    [string]$Action = 'Status',

    [ValidateSet('OfficeInteractive', 'PrintServerUnattended')]
    [string]$DeploymentProfile,

    [string]$RunnerHost,
    [ValidateRange(1, 65535)]
    [int]$Port = 8791,

    [string]$Server = 'msbadmin@192.168.5.9',

    [string]$StateFile = 'G:\Shared drives\MSB Database\LOR Version Reviews\runner-state.json',

    [switch]$RotateToken
)

$ErrorActionPreference = 'Stop'
if (-not $DeploymentProfile) {
    if ($env:COMPUTERNAME -ieq 'PRINT-SERVER') {
        $DeploymentProfile = 'PrintServerUnattended'
    }
    else {
        $DeploymentProfile = 'OfficeInteractive'
    }
}
if (-not $RunnerHost) {
    if ($DeploymentProfile -eq 'PrintServerUnattended') {
        $RunnerHost = '192.168.5.56'
    }
    else {
        $RunnerHost = '192.168.5.55'
    }
}
$TaskName = 'MSB LOR Operator Runner'
$RepoRoot = $PSScriptRoot
$RunnerPath = Join-Path $RepoRoot `
    'Docs\01_LOR_System\02_Data_Extraction\Parser\lor_operator_runner.py'
$ParserPath = Join-Path $RepoRoot `
    'Docs\01_LOR_System\02_Data_Extraction\Parser\parse_props_v7_scene_parser.py'
$CheckerPath = Join-Path $RepoRoot `
    'Docs\01_LOR_System\02_Data_Extraction\Parser\lor_version_checker.py'
$IngestPath = Join-Path $RepoRoot `
    'LOR2DB\01_Ingest\postgres_ingest_from_lor_sqlite_v7.py'
$PythonPath = Join-Path $RepoRoot '.venv\Scripts\python.exe'
$SecretRoot = Join-Path $env:LOCALAPPDATA 'MSB\LORRunner'
$SecretPath = Join-Path $SecretRoot 'runner-token.dpapi'
$IngestSecretPath = Join-Path $SecretRoot 'postgres-ingest-password.dpapi'
$ServiceLogPath = Join-Path $SecretRoot 'runner-service.log'
$PendingRemotePath = '~/.msb-lor-runner-token.pending'
$ProductionSqlitePath =
    'G:\Shared drives\MSB Database\database\lor_output_v7_scene.db'
$ReadinessTimeoutSeconds = 600
$ReadinessInitialDelaySeconds = 2
$ReadinessMaxDelaySeconds = 30

function Write-ServiceLog {
    param([Parameter(Mandatory = $true)][string]$Message)

    New-Item -ItemType Directory -Force -Path $SecretRoot | Out-Null
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    Add-Content `
        -LiteralPath $ServiceLogPath `
        -Value "[$timestamp] $Message" `
        -Encoding UTF8
}

function Get-TokenFingerprint {
    param([Parameter(Mandatory = $true)][string]$Token)

    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes("Bearer $Token")
        $digest = $sha.ComputeHash($bytes)
        return (-join ($digest | ForEach-Object { $_.ToString('x2') })).Substring(0, 16)
    }
    finally {
        $sha.Dispose()
    }
}

function New-RunnerToken {
    $bytes = New-Object byte[] 32
    $generator = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    try {
        $generator.GetBytes($bytes)
        return -join ($bytes | ForEach-Object { $_.ToString('x2') })
    }
    finally {
        $generator.Dispose()
    }
}

function Set-SecretAcl {
    param([Parameter(Mandatory = $true)][string]$Path)

    $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    $acl = New-Object System.Security.AccessControl.FileSecurity
    $acl.SetAccessRuleProtection($true, $false)
    $acl.AddAccessRule(([System.Security.AccessControl.FileSystemAccessRule]::new(
        $identity,
        [System.Security.AccessControl.FileSystemRights]::FullControl,
        [System.Security.AccessControl.AccessControlType]::Allow
    )))
    $acl.AddAccessRule(([System.Security.AccessControl.FileSystemAccessRule]::new(
        'NT AUTHORITY\SYSTEM',
        [System.Security.AccessControl.FileSystemRights]::FullControl,
        [System.Security.AccessControl.AccessControlType]::Allow
    )))
    Set-Acl -LiteralPath $Path -AclObject $acl
}

function Save-ProtectedToken {
    param([Parameter(Mandatory = $true)][string]$Token)

    if ($Token -notmatch '^[0-9a-fA-F]{64}$') {
        throw 'Runner token must contain exactly 64 hexadecimal characters.'
    }
    New-Item -ItemType Directory -Force -Path $SecretRoot | Out-Null
    $secureToken = ConvertTo-SecureString -String $Token -AsPlainText -Force
    $encrypted = ConvertFrom-SecureString -SecureString $secureToken
    Set-Content -LiteralPath $SecretPath -Value $encrypted -Encoding ASCII -NoNewline
    Set-SecretAcl -Path $SecretPath
}

function Read-ProtectedToken {
    if (-not (Test-Path -LiteralPath $SecretPath -PathType Leaf)) {
        throw "Runner is not installed. Protected token was not found: $SecretPath"
    }
    $encrypted = (Get-Content -LiteralPath $SecretPath -Raw).Trim()
    $secureToken = ConvertTo-SecureString -String $encrypted
    $pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureToken)
    try {
        $token = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer)
    }
    finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer)
    }
    if ($token -notmatch '^[0-9a-fA-F]{64}$') {
        throw 'Protected runner token is invalid or belongs to another Windows account.'
    }
    return $token
}

function Save-ProtectedIngestCredential {
    param(
        [Parameter(Mandatory = $true)]
        [Security.SecureString]$Credential
    )

    if ($Credential.Length -eq 0) {
        throw 'PostgreSQL ingest password cannot be blank.'
    }
    New-Item -ItemType Directory -Force -Path $SecretRoot | Out-Null
    $encrypted = ConvertFrom-SecureString -SecureString $Credential
    Set-Content `
        -LiteralPath $IngestSecretPath `
        -Value $encrypted `
        -Encoding ASCII `
        -NoNewline
    Set-SecretAcl -Path $IngestSecretPath
}

function Read-ProtectedIngestCredential {
    if (-not (Test-Path -LiteralPath $IngestSecretPath -PathType Leaf)) {
        throw 'PostgreSQL ingest credential is not configured.'
    }
    $encrypted = (Get-Content -LiteralPath $IngestSecretPath -Raw).Trim()
    $secureCredential = ConvertTo-SecureString -String $encrypted
    $pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR(
        $secureCredential
    )
    try {
        $credential = [Runtime.InteropServices.Marshal]::PtrToStringBSTR(
            $pointer
        )
    }
    finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer)
    }
    if (-not $credential) {
        throw 'Protected PostgreSQL ingest credential is invalid.'
    }
    return $credential
}

function Assert-RunnerPrerequisites {
    foreach ($requiredPath in @(
        $StateFile,
        $RunnerPath,
        $ParserPath,
        $CheckerPath,
        $IngestPath,
        $PythonPath
    )) {
        if (-not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) {
            throw "Required runner file was not found: $requiredPath"
        }
    }
    $state = Get-Content -LiteralPath $StateFile -Raw | ConvertFrom-Json
    if (-not $state.current_lor_version -or -not $state.current_preview_folder) {
        throw 'Existing runner state does not identify the approved Current LOR source.'
    }
    if (-not (Test-Path -LiteralPath $state.current_preview_folder -PathType Container)) {
        throw "Approved Current LOR folder is unavailable: $($state.current_preview_folder)"
    }
    if (-not (Test-Path -LiteralPath $state.current_manifest_path -PathType Leaf)) {
        throw "Approved Current LOR manifest is unavailable: $($state.current_manifest_path)"
    }
    return $state
}

function Wait-RunnerPrerequisites {
    <#
    PRINT-SERVER depends on Google Drive for Desktop mounting G: after the
    interactive Print Service Autologon session begins. The Scheduled Task
    must not fail permanently merely because it starts before DriveFS has
    finished mounting the approved LOR paths.

    Local deployment files are checked once and fail immediately. G:-backed
    runtime prerequisites are retried with bounded exponential backoff.
    #>

    foreach ($requiredLocalPath in @(
        $RunnerPath,
        $ParserPath,
        $CheckerPath,
        $IngestPath,
        $PythonPath
    )) {
        if (-not (Test-Path -LiteralPath $requiredLocalPath -PathType Leaf)) {
            throw "Required local runner file was not found: $requiredLocalPath"
        }
    }

    if ($DeploymentProfile -ne 'PrintServerUnattended') {
        return (Assert-RunnerPrerequisites)
    }

    $deadline = [DateTime]::UtcNow.AddSeconds($ReadinessTimeoutSeconds)
    $delaySeconds = $ReadinessInitialDelaySeconds
    $attempt = 0
    $lastFailure = $null

    while ([DateTime]::UtcNow -lt $deadline) {
        $attempt++
        try {
            $state = Assert-RunnerPrerequisites

            $sqliteDirectory = Split-Path -Parent $ProductionSqlitePath
            if (-not (
                Test-Path -LiteralPath $sqliteDirectory -PathType Container
            )) {
                throw (
                    'Production SQLite destination is unavailable: ' +
                    $sqliteDirectory
                )
            }

            if ($attempt -gt 1) {
                Write-ServiceLog (
                    "Readiness passed on attempt $attempt after waiting for " +
                    'Google Drive/runtime prerequisites.'
                )
            }

            return $state
        }
        catch {
            $lastFailure = $_.Exception.Message
            Write-ServiceLog (
                "Readiness attempt $attempt waiting ${delaySeconds}s: " +
                $lastFailure
            )

            Start-Sleep -Seconds $delaySeconds
            $delaySeconds = [Math]::Min(
                $delaySeconds * 2,
                $ReadinessMaxDelaySeconds
            )
        }
    }

    $message = (
        'Runner prerequisites were not ready within ' +
        "${ReadinessTimeoutSeconds}s. Last failure: $lastFailure"
    )

    Write-ServiceLog "READINESS TIMEOUT: $message"
    throw $message
}


function Test-AuthenticatedHealth {
    param([Parameter(Mandatory = $true)][string]$Token)

    $request = [System.Net.HttpWebRequest]::Create(
        "http://${RunnerHost}:$Port/health"
    )
    $request.Method = 'GET'
    $request.Proxy = $null
    $request.Timeout = 5000
    $request.Headers.Add('Authorization', "Bearer $Token")
    $response = $null
    try {
        $response = $request.GetResponse()
        $reader = New-Object System.IO.StreamReader($response.GetResponseStream())
        try {
            return ($reader.ReadToEnd() | ConvertFrom-Json)
        }
        finally {
            $reader.Dispose()
        }
    }
    finally {
        if ($response) {
            $response.Dispose()
        }
    }
}

function Assert-DeploymentIdentity {
    if ($DeploymentProfile -ne 'PrintServerUnattended') {
        return
    }

    if ($env:COMPUTERNAME -ine 'PRINT-SERVER') {
        throw (
            'PrintServerUnattended may be installed or started only on ' +
            'PRINT-SERVER.'
        )
    }
    $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    if ($identity -ine 'PRINT-SERVER\Print Service') {
        throw (
            'PrintServerUnattended must run as ' +
            "PRINT-SERVER\Print Service; current identity is $identity."
        )
    }
}

function Install-ScheduledRunner {
    $account = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    $arguments = "-NoProfile -WindowStyle Hidden " +
        "-ExecutionPolicy Bypass -File `"$PSCommandPath`" " +
        "-Action Start -DeploymentProfile $DeploymentProfile " +
        "-RunnerHost $RunnerHost -Port $Port " +
        "-StateFile `"$StateFile`""
    $taskAction = New-ScheduledTaskAction `
        -Execute 'powershell.exe' `
        -Argument $arguments `
        -WorkingDirectory $RepoRoot
    $settings = New-ScheduledTaskSettingsSet `
        -StartWhenAvailable `
        -AllowStartIfOnBatteries `
        -DontStopIfGoingOnBatteries `
        -RestartCount 3 `
        -RestartInterval (New-TimeSpan -Minutes 1) `
        -ExecutionTimeLimit ([TimeSpan]::Zero) `
        -MultipleInstances IgnoreNew

    if ($DeploymentProfile -eq 'PrintServerUnattended') {
        $trigger = New-ScheduledTaskTrigger -AtStartup
        $trigger.Delay = 'PT1M'
        $taskCredential = Get-Credential `
            -UserName $account `
            -Message 'Enter the PRINT-SERVER Print Service Windows password'
        if (-not $taskCredential) {
            throw 'Windows task credential entry was cancelled.'
        }
        $taskPassword = $taskCredential.GetNetworkCredential().Password
        if ([string]::IsNullOrWhiteSpace($taskPassword)) {
            throw 'Windows task password cannot be blank.'
        }
        try {
            Register-ScheduledTask `
                -TaskName $TaskName `
                -Action $taskAction `
                -Trigger $trigger `
                -User $account `
                -Password $taskPassword `
                -RunLevel Highest `
                -Settings $settings `
                -Description 'Restricted unattended LOR2DB runner on PRINT-SERVER; isolated from MSB Label Service.' `
                -Force | Out-Null
        }
        finally {
            Remove-Variable taskPassword -ErrorAction SilentlyContinue
            Remove-Variable taskCredential -ErrorAction SilentlyContinue
        }
    }
    else {
        $trigger = New-ScheduledTaskTrigger -AtLogOn -User $account
        $principal = New-ScheduledTaskPrincipal `
            -UserId $account `
            -LogonType Interactive `
            -RunLevel Limited
        Register-ScheduledTask `
            -TaskName $TaskName `
            -Action $taskAction `
            -Trigger $trigger `
            -Principal $principal `
            -Settings $settings `
            -Description 'Restricted LOR2DB runner; requires the Office user logon and G: drive.' `
            -Force | Out-Null
    }
}

function Stop-InstalledRunner {
    $state = Get-Content -LiteralPath $StateFile -Raw | ConvertFrom-Json
    if ($state.parser_activity -and $state.parser_activity.status -eq 'RUNNING') {
        throw 'The LOR parser is running. Wait for it to finish before reinstalling the runner.'
    }
    if ($state.ingest_activity -and $state.ingest_activity.status -eq 'RUNNING') {
        throw 'The PostgreSQL ingest is running. Wait for it to finish before reinstalling the runner.'
    }

    $existingTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if ($existingTask -and $existingTask.State -eq 'Running') {
        Stop-ScheduledTask -TaskName $TaskName
        Start-Sleep -Seconds 2
    }

    $listeners = @(
        Get-NetTCPConnection `
            -LocalPort $Port `
            -State Listen `
            -ErrorAction SilentlyContinue
    )
    $listenerProcessIds = @(
        $listeners | Select-Object -ExpandProperty OwningProcess -Unique
    )
    foreach ($listenerProcessId in $listenerProcessIds) {
        $process = Get-CimInstance Win32_Process `
            -Filter "ProcessId = $listenerProcessId" `
            -ErrorAction SilentlyContinue
        $commandLine = [string]$process.CommandLine
        $isManagedRunner = $process -and `
            ($process.Name -ieq 'python.exe') -and `
            ($commandLine.IndexOf(
                $RunnerPath,
                [System.StringComparison]::OrdinalIgnoreCase
            ) -ge 0) -and `
            ($commandLine -match '(?i)(?:^|\s)serve(?:\s|$)') -and `
            ($commandLine -match "(?i)--host\s+$([regex]::Escape($RunnerHost))(?:\s|$)") -and `
            ($commandLine -match "(?i)--port\s+$Port(?:\s|$)")
        if (-not $isManagedRunner) {
            throw (
                "Port $Port is held by PID $listenerProcessId, " +
                'which is not the managed LOR runner. No process was stopped.'
            )
        }
        Stop-Process -Id $listenerProcessId -Force
        Write-Host (
            '[INFO] Stopped existing managed runner process ' +
            "(PID $listenerProcessId)."
        )
    }

    foreach ($attempt in 1..10) {
        $remaining = Get-NetTCPConnection `
            -LocalPort $Port `
            -State Listen `
            -ErrorAction SilentlyContinue
        if (-not $remaining) {
            return
        }
        Start-Sleep -Milliseconds 500
    }
    throw "Port $Port did not become available after stopping the managed runner."
}

function Start-InstalledRunner {
    param([Parameter(Mandatory = $true)][string]$Token)

    $existingTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if (-not $existingTask) {
        throw "Scheduled Task is not installed: $TaskName"
    }
    Start-ScheduledTask -TaskName $TaskName
    $lastError = $null
    foreach ($attempt in 1..10) {
        Start-Sleep -Seconds 1
        try {
            $health = Test-AuthenticatedHealth -Token $Token
            Write-Host "[OK] Local authenticated health: $($health.status) $($health.version)"
            return
        }
        catch {
            $lastError = $_.Exception.Message
        }
    }
    throw "Runner task did not pass local health within 10 seconds: $lastError"
}

switch ($Action) {
    'Install' {
        Assert-DeploymentIdentity
        Assert-RunnerPrerequisites | Out-Null
        Stop-InstalledRunner
        $pairingRequired = $false
        if ((Test-Path -LiteralPath $SecretPath) -and -not $RotateToken) {
            $token = Read-ProtectedToken
            Write-Host '[INFO] Existing protected runner token retained.'
        }
        else {
            $token = New-RunnerToken
            Save-ProtectedToken -Token $token
            $pairingRequired = $true
            Write-Host '[OK] New runner token generated and protected with Windows DPAPI.'
        }
        if (Test-Path -LiteralPath $IngestSecretPath -PathType Leaf) {
            Write-Host '[INFO] Existing protected PostgreSQL ingest credential retained.'
        }
        else {
            Write-Host '[SETUP] Enter the PostgreSQL msbadmin password once for web ingest.'
            $secureIngestCredential = Read-Host `
                'PostgreSQL ingest password' `
                -AsSecureString
            Save-ProtectedIngestCredential `
                -Credential $secureIngestCredential
            Write-Host '[OK] PostgreSQL ingest credential protected with Windows DPAPI.'
            Remove-Variable secureIngestCredential -ErrorAction SilentlyContinue
        }
        Install-ScheduledRunner
        Write-Host "[OK] Scheduled Task installed: $TaskName"
        Write-Host "[OK] Deployment profile: $DeploymentProfile"
        Write-Host "[OK] Task account: $([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)"
        Write-Host "[OK] Credential fingerprint: $(Get-TokenFingerprint -Token $token)"
        Start-InstalledRunner -Token $token
        if ($pairingRequired) {
            Write-Host '[NEXT] Run: .\run_lor_runner.ps1 -Action PairServer'
        }
        else {
            Write-Host '[OK] Existing server pairing remains valid; PairServer is not required.'
        }
        Remove-Variable token -ErrorAction SilentlyContinue
    }

    'ConfigureIngest' {
        Assert-DeploymentIdentity
        Assert-RunnerPrerequisites | Out-Null
        $secureIngestCredential = Read-Host `
            'Enter the PostgreSQL msbadmin password for web ingest' `
            -AsSecureString
        Save-ProtectedIngestCredential -Credential $secureIngestCredential
        Remove-Variable secureIngestCredential -ErrorAction SilentlyContinue
        Stop-InstalledRunner
        $token = Read-ProtectedToken
        Start-InstalledRunner -Token $token
        Write-Host '[OK] PostgreSQL ingest credential updated and runner restarted.'
        Remove-Variable token -ErrorAction SilentlyContinue
    }

    'PairServer' {
        $token = Read-ProtectedToken
        $ssh = Get-Command ssh -ErrorAction SilentlyContinue
        if (-not $ssh) {
            throw 'Windows OpenSSH client was not found.'
        }
        Write-Host "[INFO] Transferring protected pairing material to $Server through SSH."
        $token | & $ssh.Source $Server `
            "umask 077; cat > $PendingRemotePath"
        if ($LASTEXITCODE -ne 0) {
            throw 'SSH pairing transfer failed; the Linux API environment was not changed.'
        }
        Write-Host '[OK] Pairing token transferred to a mode-0600 pending file.'
        Write-Host "[OK] Credential fingerprint: $(Get-TokenFingerprint -Token $token)"
        Write-Host '[NEXT] From the repository root on msb-prod-db, run:'
        Write-Host (
            'sudo python3 LOR2DB/Application/install_lor_runner_pairing.py ' +
            "--runner-url http://${RunnerHost}:$Port"
        )
        Remove-Variable token -ErrorAction SilentlyContinue
    }

    'Start' {
        Write-ServiceLog "Start requested for ${RunnerHost}:$Port."
        try {
            Assert-DeploymentIdentity
            $state = Wait-RunnerPrerequisites
            Write-ServiceLog (
                "Prerequisites passed for approved LOR " +
                "$($state.current_lor_version)."
            )
            $listener = Get-NetTCPConnection `
                -LocalPort $Port `
                -State Listen `
                -ErrorAction SilentlyContinue
            if ($listener) {
                throw "Port $Port already has a listener; a second runner was not started."
            }
            $token = Read-ProtectedToken
            $ingestCredential = Read-ProtectedIngestCredential
            $env:LOR_RUNNER_TOKEN = $token
            $env:LOR_INGEST_PG_PASSWORD = $ingestCredential
            $env:LOR_PREVIEW_PARENT = 'G:\Shared drives\MSB Database'
            $env:LOR_SQLITE_OUTPUT = $ProductionSqlitePath
            $env:LOR_RUNNER_REPORTS_ROOT =
                'G:\Shared drives\MSB Database\LOR Version Reviews'
            $env:LOR_PARSER_PATH = $ParserPath
            $env:LOR_CHECKER_PATH = $CheckerPath
            $env:LOR_INGEST_PATH = $IngestPath
            $env:PYTHONUNBUFFERED = '1'
            Write-ServiceLog (
                "Starting runner V1.6.0; profile=$DeploymentProfile; " +
                "credential fingerprint=" +
                "$(Get-TokenFingerprint -Token $token)."
            )
            # BaseHTTPRequestHandler writes normal HTTP access records to
            # stderr. Windows PowerShell converts redirected native stderr to
            # ErrorRecord objects; the global Stop preference would otherwise
            # terminate this healthy long-running process after its first
            # request. The native process exit code remains authoritative.
            $savedErrorActionPreference = $ErrorActionPreference
            try {
                $ErrorActionPreference = 'Continue'
                & $PythonPath -u $RunnerPath serve `
                    --state-file $StateFile `
                    --host $RunnerHost `
                    --port $Port 2>&1 | Tee-Object -FilePath $ServiceLogPath -Append
                $runnerExitCode = $LASTEXITCODE
            }
            finally {
                $ErrorActionPreference = $savedErrorActionPreference
            }
            Write-ServiceLog "Runner process exited with code $runnerExitCode."
            exit $runnerExitCode
        }
        catch {
            $failure = $_.Exception.Message
            Write-ServiceLog "START FAILED: $failure"
            Write-Error $failure
            exit 1
        }
        finally {
            Remove-Item Env:\LOR_RUNNER_TOKEN -ErrorAction SilentlyContinue
            Remove-Item Env:\LOR_INGEST_PG_PASSWORD -ErrorAction SilentlyContinue
            Remove-Variable token -ErrorAction SilentlyContinue
            Remove-Variable ingestCredential -ErrorAction SilentlyContinue
        }
    }

    'Stop' {
        Assert-RunnerPrerequisites | Out-Null
        Stop-InstalledRunner
        Write-Host '[OK] Managed LOR runner is stopped and its port is free.'
    }

    'Status' {
        Write-Host "Task: $TaskName"
        Write-Host "Deployment profile: $DeploymentProfile"
        Write-Host "Runner endpoint: http://${RunnerHost}:$Port"
        $task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
        if ($task) {
            Write-Host "Scheduled Task state: $($task.State)"
            Write-Host "Scheduled Task user: $($task.Principal.UserId)"
            Write-Host "Scheduled Task logon type: $($task.Principal.LogonType)"
            Write-Host "Scheduled Task run level: $($task.Principal.RunLevel)"
        }
        else {
            Write-Host 'Scheduled Task state: NOT INSTALLED'
        }
        if (-not (Test-Path -LiteralPath $SecretPath -PathType Leaf)) {
            Write-Host 'Protected token: NOT INSTALLED'
            exit 3
        }
        $token = Read-ProtectedToken
        Write-Host 'Protected token: AVAILABLE'
        if (Test-Path -LiteralPath $IngestSecretPath -PathType Leaf) {
            Write-Host 'Protected PostgreSQL ingest credential: AVAILABLE'
        }
        else {
            Write-Host 'Protected PostgreSQL ingest credential: NOT CONFIGURED'
        }
        Write-Host "Credential fingerprint: $(Get-TokenFingerprint -Token $token)"
        try {
            $health = Test-AuthenticatedHealth -Token $token
            Write-Host "Runner health: $($health.status)"
            Write-Host "Runner version: $($health.version)"
        }
        catch {
            Write-Host "Runner health: OFFLINE OR REJECTED - $($_.Exception.Message)"
            if (Test-Path -LiteralPath $ServiceLogPath -PathType Leaf) {
                Write-Host "Recent runner log: $ServiceLogPath"
                Get-Content -LiteralPath $ServiceLogPath -Tail 10
            }
            exit 4
        }
        finally {
            Remove-Variable token -ErrorAction SilentlyContinue
        }
    }
}
