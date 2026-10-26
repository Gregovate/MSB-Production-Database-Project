# Read-only laptop-to-existing-preview timings. No SSH, writes to an API, or deployment.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Net.Http
$handler = [System.Net.Http.HttpClientHandler]::new()
# Loopback must use the existing preview tunnel, never a system HTTP proxy.
$handler.UseProxy = $false
$handler.AllowAutoRedirect = $false
$client = [System.Net.Http.HttpClient]::new($handler)
$client.Timeout = [TimeSpan]::FromSeconds(90)
$rows = @()
$outDir = Join-Path $env:USERPROFILE 'Documents\MSB-Diagnostics'
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$stamp = [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssZ')
$report = Join-Path $outDir "Controller_Preview_Transport_$stamp.json"
try {
    foreach ($path in @('/api/controllers/1001', '/api/power', '/api/power?view=controller', '/api/power?view=controller')) {
        Write-Host "Measuring $path ..."
        $response = $null
        $timer = [Diagnostics.Stopwatch]::StartNew()
        try {
            $uri = 'http://localhost:8898/fieldwiring' + $path
            $response = $client.GetAsync($uri, [System.Net.Http.HttpCompletionOption]::ResponseHeadersRead).GetAwaiter().GetResult()
            $headersMs = $timer.ElapsedMilliseconds
            $response.EnsureSuccessStatusCode() | Out-Null
            $bytes = $response.Content.ReadAsByteArrayAsync().GetAwaiter().GetResult()
            $bodyMs = $timer.ElapsedMilliseconds
            [Text.Encoding]::UTF8.GetString($bytes) | ConvertFrom-Json | Out-Null
            $rows += [pscustomobject]@{
                path = $path
                status = [int]$response.StatusCode
                headers_ms = $headersMs
                body_transfer_ms = $bodyMs - $headersMs
                http_total_ms = $bodyMs
                powershell_json_parse_ms = $timer.ElapsedMilliseconds - $bodyMs
                bytes = $bytes.Length
            }
        }
        finally { if ($null -ne $response) { $response.Dispose() } }
    }
    $rows | Format-Table -AutoSize
}
finally {
    $client.Dispose()
    [pscustomobject]@{
        note = 'Laptop through existing localhost8898 preview tunnel; no proxy. JSON parse is PowerShell, not browser rendering. Partial rows retained on error.'
        rows = $rows
    } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $report -Encoding UTF8
    Write-Host "REPORT SAVED: $report"
}
