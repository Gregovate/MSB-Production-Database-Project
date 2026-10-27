<# WO419-W01. Work Management current-clone browser preview workstation wrapper.
Requires a reviewed #419 Server Management port profile and exact candidate SHA.
No Production database mutations or Directus Flow actions. #>
param(
    [string]$Server = 'msbadmin@192.168.5.9',
    [Parameter(Mandatory=$true)][string]$CandidateSha,
    [Parameter(Mandatory=$true)][int]$PreviewPort,
    [Parameter(Mandatory=$true)][string]$PreviewEmail,
    [switch]$ApprovedReviewProfile,
    [switch]$V1Validation,
    [switch]$V1Browser,
    [ValidateSet('Manager','Crew')][string]$V1ReviewerRole = 'Manager'
)
$ErrorActionPreference = 'Stop'
$Ref = 'fix/work-orders-identity-reconciliation'
if (-not $ApprovedReviewProfile) { throw 'HOLD: #419 Server Management review profile not approved.' }
if ($V1Validation -and $V1Browser) { throw 'HOLD: choose V1 SQL validation OR native V1 browser review, not both.' }
if ($CandidateSha -cnotmatch '^[a-f0-9]{40}$') { throw 'HOLD: exact 40-hex SHA required.' }
if ($PreviewPort -ne 8898) { throw 'HOLD: only proposed sequential 8898 is known.' }
if ($PreviewEmail -notmatch '^[A-Za-z0-9._%+\-]+@sheboyganlights\.org$') { throw 'HOLD: existing MSB reviewer email required.' }
if ($Server -ne 'msbadmin@192.168.5.9') { throw 'HOLD: unexpected SSH host.' }
$Repo = (& git rev-parse --show-toplevel).Trim()
if ($LASTEXITCODE -ne 0 -or -not $Repo) { throw 'HOLD: MSB repository checkout required.' }
# Isolated #447 launcher uses a detached exact-SHA worktree. In Windows
# PowerShell, an empty native-command result is $null, so never call .Trim()
# on git branch --show-current without checking the result first.
$BranchOutput = & git -C $Repo branch --show-current
if ($LASTEXITCODE -ne 0) { throw 'HOLD: unable to resolve candidate branch.' }
$Branch = if ($null -eq $BranchOutput) { '' } else { ([string]$BranchOutput).Trim() }
if ($Branch -ne '' -and $Branch -ne $Ref) {
    throw "HOLD: expected branch $Ref or detached exact-SHA review, got '$Branch'."
}
$Head = (& git -C $Repo rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or $Head -ne $CandidateSha) { throw "HOLD: candidate SHA mismatch: $Head." }
$Dirty = & git -C $Repo status --porcelain
if ($LASTEXITCODE -ne 0 -or $Dirty) { throw 'HOLD: clean candidate checkout required.' }
if (@(Get-NetTCPConnection -LocalPort $PreviewPort -State Listen -ErrorAction SilentlyContinue).Count -gt 0) {
    throw "HOLD: local port $PreviewPort occupied. Do not stop other reviews."
}
$Runner = Join-Path $Repo 'WorkOrders\Acceptance\work_management_disposable_browser_preview_server.sh'
if (-not (Test-Path -LiteralPath $Runner)) { throw 'HOLD: Work Management runner missing.' }
$Source = [System.IO.File]::ReadAllText($Runner)
$Source = $Source.Replace([string][char]13, '')
$Stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$Name = "msb-wo419-preview-$Stamp-$PID.sh"
$Local = Join-Path ([System.IO.Path]::GetTempPath()) $Name
$Remote = "/tmp/$Name"
[System.IO.File]::WriteAllText($Local, $Source, (New-Object System.Text.UTF8Encoding($false)))
try {
    $Hash = (Get-FileHash -LiteralPath $Local -Algorithm SHA256).Hash.ToLowerInvariant()
    Write-Host "WO419 exact candidate: $CandidateSha"
    Write-Host "Reviewer: $PreviewEmail; registered port: $PreviewPort"
    Write-Host 'Keep the SSH tunnel open until remote BROWSER REVIEW READY and browser review completion.'
    & scp -q $Local ($Server + ':' + $Remote)
    if ($LASTEXITCODE -ne 0) { throw 'HOLD: SCP upload failed.' }
    # This is the established Setup acceptance reconnect lifecycle applied to
    # the SAME pinned #419 runner, not a competing server runner or port.
    # On SSH exit 75/255 do not throw away the uploaded verified script.
    # A resume must prove the exact saved SHA, owner, port, clone, worktree
    # and healthy application before it can reconnect; it never restores
    # a second database or changes the application candidate.
    # Bash syntax must survive PowerShell -> ssh -> remote shell quoting.
    # Avoid cut -d ' ' quoting: sha256sum's 64 leading hex bytes are stable.
    $RemotePrefix = ('chmod 700 "{0}"; hash=$(sha256sum "{0}"); hash="${{hash:0:64}}"; ' +
        'if [ "$hash" != "{1}" ]; then echo "HOLD: runner digest mismatch"; exit 50; fi; ') -f $Remote, $Hash
    $StartCommand = $RemotePrefix + ((
        'timeout --foreground --signal=TERM 28800s bash "{0}" "{1}" "{2}" "{3}" "{4}" start; ' +
        'rc=$?; if [ "$rc" -eq 0 ]; then rm -f "{0}"; fi; exit "$rc"'
    ) -f $Remote, $CandidateSha, $PreviewPort, $PreviewEmail, $Ref)
    # Same exact runner, clone, port and pinned SHA. The V1 validation option
    # executes the candidate SQL on an ephemeral restored database, never
    # starts a Flask listener and finishes with normal owner-verified teardown.
    $ValidationCommand = $RemotePrefix + ((
        'timeout --foreground --signal=TERM 28800s bash "{0}" "{1}" "{2}" "{3}" "{4}" validate_v1; ' +
        'rc=$?; if [ "$rc" -eq 0 ]; then rm -f "{0}"; fi; exit "$rc"'
    ) -f $Remote, $CandidateSha, $PreviewPort, $PreviewEmail, $Ref)
    $V1RoleMode = if ($V1ReviewerRole -eq 'Crew') { 'start_v1_crew' } else { 'start_v1_manager' }
    $V1BrowserCommand = $RemotePrefix + ((
        'timeout --foreground --signal=TERM 28800s bash "{0}" "{1}" "{2}" "{3}" "{4}" {5}; ' +
        'rc=$?; if [ "$rc" -eq 0 ]; then rm -f "{0}"; fi; exit "$rc"'
    ) -f $Remote, $CandidateSha, $PreviewPort, $PreviewEmail, $Ref, $V1RoleMode)
    $ResumeCommand = $RemotePrefix + ((
        'timeout --foreground --signal=TERM 28800s bash "{0}" "{1}" "{2}" "{3}" "{4}" resume; ' +
        'rc=$?; if [ "$rc" -eq 0 ]; then rm -f "{0}"; fi; exit "$rc"'
    ) -f $Remote, $CandidateSha, $PreviewPort, $PreviewEmail, $Ref)
    $Tunnel = '{0}:127.0.0.1:{0}' -f $PreviewPort
    $mode = 'start'
    $reconnectAttempts = 0
    $maxReconnectAttempts = 12
    while ($true) {
        $RemoteCommand = if ($V1Validation) { $ValidationCommand } elseif ($mode -eq 'resume') { $ResumeCommand } elseif ($V1Browser) { $V1BrowserCommand } else { $StartCommand }
        & ssh -tt -o ServerAliveInterval=15 -o ServerAliveCountMax=3 -L $Tunnel $Server $RemoteCommand
        $remoteExit = $LASTEXITCODE
        if ($remoteExit -eq 0) {
            if ($V1Validation) {
                Write-Host 'WO419 V1 disposable SQL validation: CLEAN EXIT' -ForegroundColor Green
            } elseif ($V1Browser) {
                Write-Host 'WO419 V1 native browser tunnel: CLEAN EXIT' -ForegroundColor Green
            } else {
                Write-Host 'WO419 workstation browser tunnel: CLEAN EXIT'
            }
            break
        }
        if ($V1Validation) {
            throw "HOLD: V1 SQL validation returned $remoteExit. Preserve report. Do not start a browser or silently retry."
        }
        if ($remoteExit -notin @(75, 255)) {
            throw "HOLD: remote $mode returned $remoteExit. Preserve original report/clone and inspect exact ownership before another preview."
        }
        $mode = 'resume'
        $reconnectAttempts += 1
        if ($reconnectAttempts -gt $maxReconnectAttempts) {
            throw "HOLD: SSH reconnect retries exhausted; the exact remote review MAY still be preserved. Inspect ownership, do NOT launch a new clone."
        }
        # Never indiscriminately stop a local listener, even if process name
        # is ssh. This is a shared sequential port with Setup/#88/#171.
        $listeners = @(Get-NetTCPConnection -LocalPort $PreviewPort -State Listen -ErrorAction SilentlyContinue)
        if ($listeners.Count -gt 0) {
            throw "HOLD: local port $PreviewPort remains occupied during reconnect. Inspect listener ownership; no process stopped."
        }
        Write-Warning "SSH transport lost. Reconnecting to exact preserved Work Orders review ($reconnectAttempts/$maxReconnectAttempts); no new clone or application startup."
        Start-Sleep -Seconds 2
    }
}
finally { Remove-Item -LiteralPath $Local -Force -ErrorAction SilentlyContinue }

