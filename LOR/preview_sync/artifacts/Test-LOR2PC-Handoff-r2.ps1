# Test-LOR2PC-Handoff.ps1 - read-only transport probe. Source: 96f3bb1153d9b09330b9a075710ae42d793ff7cd
# No installation, registry edits, preview reads/writes, or source promotion.
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$LogFolder=Join-Path $env:LOCALAPPDATA ('MSB\LOR2PC-Diagnostics\'+[guid]::NewGuid().ToString('N'))
function Invoke-SyncEvents {}
function Write-HandoffTrace {
    param([string]$Event, [int]$Port = 0, [string]$Reason = '', [string]$ExceptionType = '', [int]$SourceLine = 0)
    # Fixed event/reason codes only: never record nonce, URL, headers, cookies,
    # source document, email or credentials. Preserve evidence across attempts.
    [void][IO.Directory]::CreateDirectory($LogFolder)
    $record = [ordered]@{ timestamp = [DateTime]::UtcNow.ToString('o'); event = $Event; port = $Port; reason = $Reason; exception_type = $ExceptionType; line = $SourceLine }
    $line = ($record | ConvertTo-Json -Compress) + [Environment]::NewLine
    [IO.File]::AppendAllText((Join-Path $LogFolder 'browser-handoff.log'), $line, (New-Object Text.UTF8Encoding($false)))
}

function Receive-BrowserSource {
    $listener = New-Object Net.Sockets.TcpListener([Net.IPAddress]::Loopback, 0)
    $listener.Start()
    $port = $listener.LocalEndpoint.Port
    $nonce = [guid]::NewGuid().ToString('N') + [guid]::NewGuid().ToString('N')
    $origin = 'https://my.sheboyganlights.org'
    $deadline = [DateTime]::UtcNow.AddSeconds(120)
    $connections = 0; $preflights = 0; $rejections = 0
    try {
        Write-HandoffTrace -Event 'LISTENING' -Port $port
        Start-Process ($origin + '/lor2db/pc/#port=' + $port + '&nonce=' + $nonce)
        while ([DateTime]::UtcNow -lt $deadline) {
            Invoke-SyncEvents
            if (-not $listener.Pending()) { Start-Sleep -Milliseconds 100; continue }
            $client = $listener.AcceptTcpClient()
            $connections++
            $reason = 'reader-init'
            try {
                Write-HandoffTrace -Event 'CONNECTED' -Port $port
                $stream = $client.GetStream(); $stream.ReadTimeout = 5000; $stream.WriteTimeout = 5000
                $reader = New-Object IO.StreamReader($stream, [Text.Encoding]::UTF8, $false, 4096, $true)
                $reason = 'request-line'
                $first = $reader.ReadLine(); $headers = @{}; $total = 0
                if ($null -eq $first) { throw 'Empty browser connection.' }
                while ($true) {
                    $reason = 'header-read'
                    $line = $reader.ReadLine()
                    if ($null -eq $line) { throw 'Incomplete browser handoff.' }
                    $total += $line.Length
                    if ($total -gt 8192) { throw 'Browser handoff headers too large.' }
                    if ($line -eq '') { break }
                    # IndexOf/Substring avoid framework-dependent Split overload
                    # selection under Windows PowerShell 5.1. Split only at the
                    # first colon; URI/header values may contain more colons.
                    $reason = 'header-separator'
                    $separator = $line.IndexOf([char]':')
                    if ($separator -le 0) { throw 'Invalid handoff header.' }
                    $name = $line.Substring(0, $separator)
                    $reason = 'header-duplicate'
                    if ($headers.ContainsKey($name)) { throw 'Duplicate handoff header.' }
                    $headers[$name] = $line.Substring($separator + 1).Trim()
                }
                $reason = 'origin'
                if ($headers['Origin'] -cne $origin) { throw 'Untrusted browser origin.' }
                $reason = 'host'
                if ($headers['Host'] -cne ('127.0.0.1:' + $port)) { throw 'Untrusted browser host.' }
                $reason = 'method-or-nonce'
                if ($first -notin @("OPTIONS /$nonce HTTP/1.1", "POST /$nonce HTTP/1.1")) { throw 'Untrusted browser request.' }
                $reason = 'body-size-type-or-read'
                $body = $null
                if ($first.StartsWith('POST ')) {
                    $length = 0
                    if (-not [int]::TryParse($headers['Content-Length'], [ref]$length) -or $length -le 0 -or $length -gt 2097152 -or
                        $headers.ContainsKey('Transfer-Encoding') -or $headers['Content-Type'] -notmatch '^text/plain') { throw 'Invalid browser document size/type.' }
                    # Browser sends ASCII JSON so HTTP byte count equals character count.
                    $chars = New-Object char[] $length; $read = 0
                    while ($read -lt $length) { $count = $reader.Read($chars, $read, $length - $read); if ($count -le 0) { throw 'Truncated browser document.' }; $read += $count }
                    $body = -join $chars
                }
                $reason = 'response-write'
                $reply = "HTTP/1.1 200 OK`r`nAccess-Control-Allow-Origin: $origin`r`nAccess-Control-Allow-Methods: POST, OPTIONS`r`nAccess-Control-Allow-Headers: Content-Type`r`nAccess-Control-Allow-Private-Network: true`r`nContent-Length: 0`r`nConnection: close`r`n`r`n"
                $bytes = [Text.Encoding]::ASCII.GetBytes($reply); $stream.Write($bytes, 0, $bytes.Length)
                if ($null -ne $body) {
                    Write-HandoffTrace -Event 'DOCUMENT_RECEIVED' -Port $port
                    return $body
                }
                $preflights++
                Write-HandoffTrace -Event 'PREFLIGHT_REPLIED' -Port $port
            } catch {
                $rejections++
                Write-HandoffTrace -Event 'REQUEST_REJECTED' -Port $port -Reason $reason -ExceptionType ($_.Exception.GetType().FullName) -SourceLine $_.InvocationInfo.ScriptLineNumber
                Write-Verbose 'Rejected or incomplete loopback request.'
            }
            finally { $client.Close() }
        }
        Write-HandoffTrace -Event 'TIMEOUT' -Port $port -Reason ('connections=' + $connections + ';preflights=' + $preflights + ';rejections=' + $rejections)
        throw 'Browser handoff timed out. This does not establish a sign-in failure. Retain browser-handoff.log from the diagnostic folder and the browser error. No preview update was authorized.'
    } finally {
        $listener.Stop()
        Write-HandoffTrace -Event 'STOPPED' -Port $port
    }
}


Write-Host 'Opening the protected MSB page for a read-only browser handoff test.'
Write-Host ('Diagnostic folder: '+$LogFolder)
try {
    $received=Receive-BrowserSource
    $document=$received | ConvertFrom-Json
    Write-Host 'HANDOFF RECEIVED. This proves transport only; source/master validation and PC synchronization were not run.'
} catch {
    Write-Host ('HANDOFF HOLD: '+$_.Exception.Message)
    exit 2
} finally {
    Write-Host ('Return this log: '+(Join-Path $LogFolder 'browser-handoff.log'))
}
