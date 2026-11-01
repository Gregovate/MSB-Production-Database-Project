# Local desktop UI check only. No preview files, network, installation or apply.
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if (-not [Environment]::UserInteractive) { throw 'Run this in local Windows PowerShell, outside SSH.' }
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$source=[IO.File]::ReadAllText((Join-Path $PSScriptRoot 'Update_MSB_Previews.ps1'))
$tokens=$null;$errors=$null
$ast=[Management.Automation.Language.Parser]::ParseInput($source,[ref]$tokens,[ref]$errors)
if ($errors.Count) {throw ($errors|Out-String)}
foreach ($fn in $ast.FindAll({param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst]},$false)) {
    if ($fn.Name -in @('Get-ActionCounts','New-FocusReleaseTimer','Show-ReviewDialog')) { . ([scriptblock]::Create($fn.Extent.Text)) }
}
function Check($value,$name) {if (-not $value) {throw ('FAIL: '+$name)};Write-Output ('PASS: '+$name)}
$ApplicationVersion='1.1.3';$ApplicationReleaseDate='2026-11-01'
$script:VersionStatus=[pscustomobject]@{Latest='1.1.3'}
$catalogSource=[pscustomobject]@{AuthorityLabel='Disposable UI fixture'}
$row=[pscustomobject]@{Action='ADD_IN_CANDIDATE';Approved_Filename='Disposable preview.lorprev';Approved_Name='Disposable preview';Local_Revision='';Approved_Revision='1';Change_Summary='Display added: test only';Presentation_Details='';Database_Impact='';Review_Diff=''}
$build=[pscustomobject]@{Rows=@($row);UnmanagedCount=2}
$master=[pscustomobject]@{Records=@{}}
    $script:AppIcon=$null
    $uiCheck=[pscustomobject]@{Failure=$null;Checked=$false;Title="MSB PC Preview Updater $ApplicationVersion | $ApplicationReleaseDate | Review changes"}
    $uiTimer=New-Object System.Windows.Forms.Timer
    $uiTimer.Interval=100;$uiTimer.Tag=$uiCheck
    $uiTimer.Add_Tick({
        $dialog=@([System.Windows.Forms.Application]::OpenForms | Where-Object {$_.Text -eq $this.Tag.Title}) | Select-Object -First 1
        if ($null -eq $dialog) { return }
        $this.Stop()
        try {
            $all=New-Object 'System.Collections.Generic.List[System.Windows.Forms.Control]'
            $pending=New-Object 'System.Collections.Generic.Queue[System.Windows.Forms.Control]'
            $pending.Enqueue($dialog)
            while ($pending.Count) { $control=$pending.Dequeue();$all.Add($control);foreach ($child in $control.Controls) {$pending.Enqueue($child)} }
            $table=@($all | Where-Object {$_ -is [System.Windows.Forms.DataGridView]})[0]
            if ($table.Visible) {throw 'Routine grid is visible before operator chooses Show changes'}
            $link=@($all | Where-Object {$_.Text -eq 'Show changes'})[0]
            # Invoke the real event handler through the native control.
            $event=[System.Windows.Forms.LinkLabel].GetMethod('OnLinkClicked',[Reflection.BindingFlags]'Instance,NonPublic')
            $event.Invoke($link,@(([System.Windows.Forms.LinkLabelLinkClickedEventArgs]::new($link.Links[0])))) | Out-Null
            if (-not $table.Visible) {throw 'Show changes did not reveal the preview grid'}
            $this.Tag.Checked=$true
        } catch { $this.Tag.Failure=$_.Exception.Message }
        finally { $dialog.Close() }
    })
    try {
        $uiTimer.Start()
        $null=Show-ReviewDialog -AcceptedReport $catalogSource -Build $build -MasterRecords $master.Records -LocalPath '' -ExpectedOriginalHash '' -CandidatePath '' -ReportPath '' -CandidateHash ('a'*64) -ReviewOnly
    } finally {$uiTimer.Stop();$uiTimer.Dispose()}
    Check ($uiCheck.Checked -and -not $uiCheck.Failure) ('approval starts compact and Show changes expands safely: '+$uiCheck.Failure)
Write-Output 'PASS: local desktop UI check completed; no previews read or changed.'
