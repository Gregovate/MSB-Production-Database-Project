# Disposable engine acceptance; never executes the updater's top-level UI/apply.
[CmdletBinding()]
param([string]$ArchiveName = 'LOR2DB_2PC_Sync_SOURCE_v0.2.1.zip', [string]$ExpectedSha256 = '5c518c89e328fbd3b18406f7aa51e604a56cc3acde7f5f30e067f60855e11198')
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archivePath = Join-Path $PSScriptRoot $ArchiveName
if ((Get-FileHash $archivePath -Algorithm SHA256).Hash -ne $ExpectedSha256) { throw 'Checkpoint archive hash mismatch' }
$archive = [IO.Compression.ZipFile]::OpenRead($archivePath)
try {
    $reader = New-Object IO.StreamReader($archive.GetEntry('Update_MSB_Previews.ps1').Open())
    try { $source = $reader.ReadToEnd() } finally { $reader.Dispose() }
} finally { $archive.Dispose() }
$tokens = $null; $parseErrors = $null
$ast = [Management.Automation.Language.Parser]::ParseInput($source, [ref]$tokens, [ref]$parseErrors)
if ($parseErrors.Count) { throw ($parseErrors | Out-String) }
$compiled = [regex]::Match($source, "(?s)Add-Type -TypeDefinition @'\r?\n(.*?)\r?\n'@").Groups[1].Value
# Execute the exact archive compiler statement, including reference arguments.
$compileStatement = $ast.Find({param($n) $n -is [Management.Automation.Language.CommandAst] -and $n.Extent.Text -match '^Add-Type -TypeDefinition'}, $true)
. ([scriptblock]::Create($compileStatement.Extent.Text))
foreach ($fn in $ast.FindAll({param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst]}, $false)) {
    . ([scriptblock]::Create($fn.Extent.Text))
}
$PreviewBlockPattern = '<PreviewClass\b[^>]*\bid=["''](?<id>[^"'']+)["''][^>]*>.*?</PreviewClass>'
$RegexOptions = [Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [Text.RegularExpressions.RegexOptions]::Singleline
$fixtureRoot = Join-Path ([IO.Path]::GetTempPath()) ('msb-sync-299-' + [guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($fixtureRoot)
function Assert-Check($condition, $label) { if (-not $condition) { throw "FAIL: $label" }; Write-Output "PASS: $label" }
$live = Join-Path $fixtureRoot 'LORPreviews.xml'
$candidatePath = Join-Path $fixtureRoot 'candidate.xml'
$personal = '<PreviewClass id="personal" Name="Personal" Revision="99"><Scene Name="Keep &amp; Preserve" /></PreviewClass>'
$local = "<root>`r`n  <PreviewClass id=`"managed`" Name=`"Managed`" Revision=`"2`"><Scene Name=`"Old`" /></PreviewClass>`r`n  $personal`r`n</root>"
[IO.File]::WriteAllText($live, $local, (New-Object Text.UTF8Encoding($true)))
$master = @{}
$record = Get-PreviewRecord '<PreviewClass id="managed" Name="Managed" Revision="3"><Scene Name="Approved" /></PreviewClass>' 'fixture'
$master[$record.PreviewId] = $record
$record = Get-PreviewRecord '<PreviewClass id="missing" Name="Missing" Revision="1"><Scene Name="New" /></PreviewClass>' 'fixture'
$master[$record.PreviewId] = $record
$before = (Get-FileHash $live).Hash
$build = Build-SyncCandidate -MasterRecords $master -LocalPath $live -ProgressWindow $null
$counts = Get-ActionCounts $build.Rows
Assert-Check ($counts.Replace -eq 1 -and $counts.Add -eq 1) 'controlled replacement and missing identity addition'
Assert-Check ($build.Candidate.Contains($personal)) 'unmanaged raw fragment preserved'
Assert-Check ((Get-FileHash $live).Hash -eq $before) 'comparison does not mutate input'
Write-CandidateFile -Build $build -Path $candidatePath
$backup = Install-Candidate -CandidatePath $candidatePath -LivePath $live
Assert-Check ((Get-FileHash $backup).Hash -eq $before) 'backup matches original bytes'
Assert-Check ((Get-FileHash $live).Hash -eq (Get-FileHash $candidatePath).Hash) 'disposable atomic install matches candidate'
$second = Build-SyncCandidate -MasterRecords $master -LocalPath $live -ProgressWindow $null
$counts = Get-ActionCounts $second.Rows
Assert-Check ($counts.Noop -eq 2 -and $counts.Replace -eq 0 -and $counts.Add -eq 0) 'second comparison is idempotent'
$revisionOnly = $second.Candidate.Replace('Revision="3"', 'Revision="800"')
[IO.File]::WriteAllText($live, $revisionOnly)
$revisionBuild = Build-SyncCandidate -MasterRecords $master -LocalPath $live -ProgressWindow $null
Assert-Check ((Get-ActionCounts $revisionBuild.Rows).RevisionOnly -eq 1) 'higher local revision alone does not choose a winner'
$duplicate = $revisionOnly.Replace('</root>', $master['managed'].Raw + '</root>')
[IO.File]::WriteAllText($live, $duplicate)
$blocked = $false
try { $null = Build-SyncCandidate -MasterRecords $master -LocalPath $live -ProgressWindow $null } catch { if ($_.Exception.Message -match 'Duplicate controlled') { $blocked = $true } else { throw } }
Assert-Check $blocked 'duplicate controlled identity blocks'
Write-Output "Disposable evidence retained at: $fixtureRoot"
Write-Output 'UI responsiveness, instance lock, live report/master validation, LOR reopen, and two-PC acceptance remain untested.'
