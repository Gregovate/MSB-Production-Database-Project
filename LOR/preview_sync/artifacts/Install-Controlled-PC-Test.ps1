[CmdletBinding()]
param([string]$TargetPath = 'G:\Shared drives\MSB Database\UserPreviewStaging\LOR2DB_2PC_Sync', [switch]$NoDialog)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$expectedArchiveHash = '32c3c0c8025ca1cd0fa9f3d2e8cd9d666f3b13ad70f556afc95dd46e04a2c024'
$applicationCommit = '9f2f971f9650d7a4413886ce20a43a5d74b093d4'
$expectedReportHash = '5ea35295371319cbc06be4d084a3cc4e5d347298a11f7117bf05b063b29de837'
$reportName = 'lor-reconciliation-20261004-195521-run-29.html'
$archivePath = Join-Path $PSScriptRoot 'LOR2DB_2PC_Sync_SOURCE_v0.2.7.zip'
$realTarget = 'G:\Shared drives\MSB Database\UserPreviewStaging\LOR2DB_2PC_Sync'
$resolvedTarget = [IO.Path]::GetFullPath($TargetPath).TrimEnd('\')
$testPrefix = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot 'installer-test')).TrimEnd('\')
if ($resolvedTarget -ne $realTarget -and $resolvedTarget -ne $testPrefix -and -not $resolvedTarget.StartsWith($testPrefix + '\', [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Installer target must be the governed G: deployment or a disposable installer-test directory.'
}
$stage = Join-Path ([IO.Path]::GetTempPath()) ('msb-install-' + [guid]::NewGuid().ToString('N'))
$rollback = $null
$changed = @()
$prior = @{}
$complete = $false
try {
    if ((Get-FileHash -LiteralPath $archivePath).Hash -ne $expectedArchiveHash) { throw 'Committed archive hash mismatch; deployment blocked.' }
    Expand-Archive -LiteralPath $archivePath -DestinationPath $stage
    $reportFolder = Join-Path $resolvedTarget 'LOR2DB_Reports'
    $targetReport = Join-Path $reportFolder $reportName
    $suppliedReport = Join-Path $PSScriptRoot $reportName
    $reportSource = if (Test-Path -LiteralPath $targetReport) { $targetReport } else { $suppliedReport }
    if ((Get-FileHash -LiteralPath $reportSource).Hash -ne $expectedReportHash) { throw 'Run 29 report differs from the tested report; deployment blocked.' }
    $names = @('Update_MSB_Previews.ps1','MSB Preview Update Tree v2.ico','VERSION.txt','DEPLOYMENT.json','CONTROLLED_PC_TEST.txt','Update your PC Previews to LOR Master Files.lnk')
    $metadata = [ordered]@{
        version = '0.2.7'; commit = $applicationCommit; issue = 299; pr = 300
        # Application gate identifies this as the same laptop-tested candidate.
        status = 'LAPTOP_ACCEPTANCE'; intended_use = 'CONTROLLED_MULTI_PC_TEST_NOT_GENERAL_ROLLOUT'
        archive_sha256 = $expectedArchiveHash
        script_sha256 = (Get-FileHash -LiteralPath (Join-Path $stage 'Update_MSB_Previews.ps1')).Hash
        report_sha256 = $expectedReportHash; installed_at = (Get-Date -Format o)
        files = @{}
    }
    @'
MSB PREVIEW SYNC - CONTROLLED PC TEST ONLY
1. Save a separate copy of C:\lor\CommonData\LORPreviews.xml.
2. Close LOR Sequencer.
3. Double-click Update your PC Previews to LOR Master Files.
4. Review the complete change list, especially Master Musical Preview.
5. Tick both acknowledgements and click Update PC Previews only if approved.
6. Save the success/backup information; reopen LOR and check your previews.
7. Close LOR and run again; require Already Current with no additions/replacements.
Personal previews are preserved. The controlled master and Production are not changed.
The large Master Musical comparison can pause. Let it finish; do not repeatedly launch.
Report any blocked/error result to Greg. Do not improvise recovery or general rollout.
Greg: preserve logs and record each PC's results under #299/#300.
'@ | Set-Content -LiteralPath (Join-Path $stage 'CONTROLLED_PC_TEST.txt') -Encoding ASCII
    New-Item -ItemType Directory -Path $resolvedTarget -Force | Out-Null
    $rollback = Join-Path $resolvedTarget ('deployment-backups\' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff') + '-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $rollback -Force | Out-Null
    foreach ($name in $names) {
        $targetFile = Join-Path $resolvedTarget $name
        $prior[$name] = Test-Path -LiteralPath $targetFile
        if ($prior[$name]) { Copy-Item -LiteralPath $targetFile -Destination (Join-Path $rollback $name) -ErrorAction Stop }
    }
    foreach ($name in @('Update_MSB_Previews.ps1','MSB Preview Update Tree v2.ico','VERSION.txt','CONTROLLED_PC_TEST.txt')) {
        $sourceFile = Join-Path $stage $name
        $targetFile = Join-Path $resolvedTarget $name
        $changed += $name
        Copy-Item -LiteralPath $sourceFile -Destination $targetFile -Force
        $hash = (Get-FileHash -LiteralPath $targetFile).Hash
        if ($hash -ne (Get-FileHash -LiteralPath $sourceFile).Hash) { throw "Deployment hash mismatch: $name" }
        $metadata.files[$name] = $hash
    }
    $shell = New-Object -ComObject WScript.Shell
    $shortcutPath = Join-Path $resolvedTarget 'Update your PC Previews to LOR Master Files.lnk'
    $changed += 'Update your PC Previews to LOR Master Files.lnk'
    $link = $shell.CreateShortcut($shortcutPath)
    $link.TargetPath = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $link.Arguments = '-NoLogo -NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File "' + (Join-Path $resolvedTarget 'Update_MSB_Previews.ps1') + '"'
    $link.WorkingDirectory = $resolvedTarget
    $link.IconLocation = (Join-Path $resolvedTarget 'MSB Preview Update Tree v2.ico') + ',0'
    $link.Description = 'MSB Preview Sync v0.2.7 - Controlled PC Acceptance'
    $link.WindowStyle = 7
    $link.Save()
    $metadata.files['Update your PC Previews to LOR Master Files.lnk'] = (Get-FileHash -LiteralPath $shortcutPath).Hash
    if (-not (Test-Path -LiteralPath $targetReport)) {
        New-Item -ItemType Directory -Path $reportFolder -Force | Out-Null
        $changed += 'LOR2DB_Reports\' + $reportName
        $prior['LOR2DB_Reports\' + $reportName] = $false
        Copy-Item -LiteralPath $suppliedReport -Destination $targetReport
        if ((Get-FileHash -LiteralPath $targetReport).Hash -ne $expectedReportHash) { throw 'Installed report hash mismatch.' }
    }
    $changed += 'DEPLOYMENT.json'
    $metadata.backup_folder = $rollback
    $metadata | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $resolvedTarget 'DEPLOYMENT.json') -Encoding ASCII
    $complete = $true
    $message = "Controlled PC test installed from commit $applicationCommit.`r`n`r`nFolder: $resolvedTarget`r`nPrevious application files: $rollback`r`n`r`nProgrammers use the tree-icon shortcut: Update your PC Previews to LOR Master Files.`r`n`r`nNo local previews or Production files were changed by installation."
    Write-Output $message
    if (-not $NoDialog) { Add-Type -AssemblyName System.Windows.Forms; [void][Windows.Forms.MessageBox]::Show($message,'MSB Test Deployment Complete') }
} catch {
    $failure = $_.Exception.Message
    $restoreErrors = @()
    foreach ($name in @($changed | Select-Object -Unique)) {
        try {
            $targetFile = Join-Path $resolvedTarget $name
            if ($prior[$name]) { Copy-Item -LiteralPath (Join-Path $rollback $name) -Destination $targetFile -Force }
            elseif (Test-Path -LiteralPath $targetFile) { Remove-Item -LiteralPath $targetFile -Force }
        } catch { $restoreErrors += $_.Exception.Message }
    }
    $message = "Deployment failed: $failure`r`nRollback errors: $($restoreErrors -join '; ')`r`nBackup: $rollback`r`nDo not start PC updates until Greg reviews this failure."
    if (-not $NoDialog) { Add-Type -AssemblyName System.Windows.Forms; [void][Windows.Forms.MessageBox]::Show($message,'MSB Deployment Blocked') }
    throw $message
} finally {
    # The temporary staging directory is retained for inspection; no recursive deletion.
}
