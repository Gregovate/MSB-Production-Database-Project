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

[CmdletBinding()]
param(
    [ValidateSet('Install', 'PairServer', 'Start', 'Status')]
    [string]$Action = 'Status',

    [string]$RunnerHost = '192.168.5.55',
    [ValidateRange(1, 65535)]
    [int]$Port = 8791,

    [string]$Server = 'msbadmin@192.168.5.9',

    [string]$StateFile = 'G:\Shared drives\MSB Database\LOR Version Reviews\runner-state.json',

    [switch]$RotateToken
)

$ErrorActionPreference = 'Stop'
$TaskName = 'MSB LOR Operator Runner'
$RepoRoot = $PSScriptRoot
$RunnerPath = Join-Path $RepoRoot `
    'Docs\01_LOR_System\02_Data_Extraction\Parser\lor_operator_runner.py'
$ParserPath = Join-Path $RepoRoot `
    'Docs\01_LOR_System\02_Data_Extraction\Parser\parse_props_v7_scene_parser.py'
$CheckerPath = Join-Path $RepoRoot `
    'Docs\01_LOR_System\02_Data_Extraction\Parser\lor_version_checker.py'
$PythonPath = Join-Path $RepoRoot '.venv\Scripts\python.exe'
$SecretRoot = Join-Path $env:LOCALAPPDATA 'MSB\LORRunner'
$SecretPath = Join-Path $SecretRoot 'runner-token.dpapi'
$ServiceLogPath = Join-Path $SecretRoot 'runner-service.log'
$PendingRemotePath = '~/.msb-lor-runner-token.pending'

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

function Assert-RunnerPrerequisites {
    foreach ($requiredPath in @(
        $StateFile,
        $RunnerPath,
        $ParserPath,
        $CheckerPath,
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

function Install-ScheduledRunner {
    $account = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" " +
        "-Action Start -RunnerHost $RunnerHost -Port $Port " +
        "-StateFile `"$StateFile`""
    $taskAction = New-ScheduledTaskAction `
        -Execute 'powershell.exe' `
        -Argument $arguments `
        -WorkingDirectory $RepoRoot
    $trigger = New-ScheduledTaskTrigger -AtLogOn -User $account
    $principal = New-ScheduledTaskPrincipal `
        -UserId $account `
        -LogonType Interactive `
        -RunLevel Limited
    $settings = New-ScheduledTaskSettingsSet `
        -StartWhenAvailable `
        -AllowStartIfOnBatteries `
        -DontStopIfGoingOnBatteries `
        -RestartCount 3 `
        -RestartInterval (New-TimeSpan -Minutes 1) `
        -ExecutionTimeLimit ([TimeSpan]::Zero) `
        -MultipleInstances IgnoreNew
    Register-ScheduledTask `
        -TaskName $TaskName `
        -Action $taskAction `
        -Trigger $trigger `
        -Principal $principal `
        -Settings $settings `
        -Description 'Restricted LOR2DB parser/version-check runner; requires Greg logon and G: drive.' `
        -Force | Out-Null
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
        Assert-RunnerPrerequisites | Out-Null
        $existingTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
        if ($existingTask -and $existingTask.State -eq 'Running') {
            Stop-ScheduledTask -TaskName $TaskName
            Start-Sleep -Seconds 1
        }
        $listener = Get-NetTCPConnection `
            -LocalPort $Port `
            -State Listen `
            -ErrorAction SilentlyContinue
        if ($listener) {
            throw "Port $Port is already in use. Stop the manually started runner first."
        }
        if ((Test-Path -LiteralPath $SecretPath) -and -not $RotateToken) {
            $token = Read-ProtectedToken
            Write-Host '[INFO] Existing protected runner token retained.'
        }
        else {
            $token = New-RunnerToken
            Save-ProtectedToken -Token $token
            Write-Host '[OK] New runner token generated and protected with Windows DPAPI.'
        }
        Install-ScheduledRunner
        Write-Host "[OK] Scheduled Task installed for logged-in account: $TaskName"
        Write-Host "[OK] Credential fingerprint: $(Get-TokenFingerprint -Token $token)"
        Start-InstalledRunner -Token $token
        Write-Host '[NEXT] Run: .\run_lor_runner.ps1 -Action PairServer'
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
        Write-Host 'sudo python3 LOR2DB/Application/install_lor_runner_pairing.py'
        Remove-Variable token -ErrorAction SilentlyContinue
    }

    'Start' {
        Write-ServiceLog "Start requested for ${RunnerHost}:$Port."
        try {
            $state = Assert-RunnerPrerequisites
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
            $env:LOR_RUNNER_TOKEN = $token
            $env:LOR_PREVIEW_PARENT = 'G:\Shared drives\MSB Database'
            $env:LOR_SQLITE_OUTPUT =
                'G:\Shared drives\MSB Database\database\lor_output_v7_scene.db'
            $env:LOR_RUNNER_REPORTS_ROOT =
                'G:\Shared drives\MSB Database\LOR Version Reviews'
            $env:LOR_PARSER_PATH = $ParserPath
            $env:LOR_CHECKER_PATH = $CheckerPath
            $env:PYTHONUNBUFFERED = '1'
            Write-ServiceLog (
                "Starting runner V1.3.0; credential fingerprint=" +
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
            Remove-Variable token -ErrorAction SilentlyContinue
        }
    }

    'Status' {
        Write-Host "Task: $TaskName"
        $task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
        if ($task) {
            Write-Host "Scheduled Task state: $($task.State)"
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
