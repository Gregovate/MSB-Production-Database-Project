# Disposable functions-only tests. No UI, network, G: or real LOR library.
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$source = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'Update_MSB_Previews.ps1'))
$tokens = $null; $errors = $null
$ast = [Management.Automation.Language.Parser]::ParseInput($source, [ref]$tokens, [ref]$errors)
if ($errors.Count) { throw ($errors | Out-String) }
foreach ($match in [regex]::Matches($source, "(?s)Add-Type -ReferencedAssemblies .*? -TypeDefinition @'\r?\n(.*?)\r?\n'@")) {
    # Core uses framework references; 5.1 uses the production reference lists.
    if ($PSVersionTable.PSEdition -eq 'Core') { Add-Type -TypeDefinition $match.Groups[1].Value }
    else { . ([scriptblock]::Create($match.Value)) }
}
foreach ($fn in $ast.FindAll({param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst]}, $false)) { . ([scriptblock]::Create($fn.Extent.Text)) }
$PreviewBlockPattern = '<PreviewClass\b[^>]*\bid=["''](?<id>[^"'']+)["''][^>]*>.*?</PreviewClass>'
$RegexOptions = [Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [Text.RegularExpressions.RegexOptions]::Singleline
function Check($value, $name) { if (-not $value) { throw "FAIL: $name" }; Write-Output "PASS: $name" }
function Blocks($action, $name) { $blocked=$false; try { & $action } catch { $blocked=$true }; Check $blocked $name }
$fixture = Join-Path ([IO.Path]::GetTempPath()) ('msb299-' + [guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($fixture)
$folder = Join-Path $fixture 'master'; [void][IO.Directory]::CreateDirectory($folder)
$raw = '<PreviewClass id="managed" Name="Rotary-Trees" Revision="57"><Scene Name="HW-Flood" /></PreviewClass>'
[IO.File]::WriteAllText((Join-Path $folder 'Rotary.lorprev'), $raw, (New-Object Text.UTF8Encoding($false)))
# A stale extraction CSV is historical evidence and must have no effect.
[IO.File]::WriteAllText((Join-Path $folder '_MSB_CONTROLLED_PREVIEW_MANIFEST.csv'), 'stale invalid historical digest')
$master = Get-MasterRecords -Folder $folder -ProgressWindow $null
Check ($master.SourceStateSha256 -ceq 'f0b1d09d14ed4e5438f010e8fb69c096339dd97f4a44acbbee3cb6859d61fe18') 'captured-byte digest matches Python parser canonical algorithm'
$accepted = [pscustomobject]@{RunId=32; SourceManifestSha256=$master.SourceStateSha256; Rows=@([pscustomobject]@{Filename='Rotary.lorprev'; PreviewId='managed'; PreviewName='Rotary-Trees'; Revision='57'})}
Test-MasterAgainstReport $accepted $master $null
Check $true 'accepted new content is not vetoed by stale extraction CSV'
$accepted.SourceManifestSha256 = 'a'*64
Blocks { Test-MasterAgainstReport $accepted $master $null } 'older source digest rejects newer content'
$accepted.SourceManifestSha256 = ''
Blocks { Test-MasterAgainstReport $accepted $master $null } 'missing digest blocks without timestamp fallback'
$accepted.SourceManifestSha256 = $master.SourceStateSha256
$accepted.Rows[0].PreviewId='wrong'
Blocks { Test-MasterAgainstReport $accepted $master $null } 'wrong accepted identity blocks'
$accepted.Rows[0].PreviewId='managed'
[IO.File]::AppendAllText((Join-Path $folder 'Rotary.lorprev'), ' ')
Check ([MSBSourceManifest]::Compute($folder) -ne $master.SourceStateSha256) 'post-acceptance source edit changes digest'
$local = Join-Path $fixture 'LORPreviews.xml'; $candidate=Join-Path $fixture 'candidate.xml'
$personal='<PreviewClass id="personal" Name="Personal" Revision="1"><Scene Name="Keep" /></PreviewClass>'
[IO.File]::WriteAllText($local, "<root>$personal</root>")
$before=Get-FileSha256 $local
$build=Build-SyncCandidate $master.Records $local $null
Check ((Get-ActionCounts $build.Rows).Add -eq 1 -and $build.Candidate.Contains($personal)) 'clean PC adds controlled set and preserves personal fragment'
Write-CandidateFile $build $candidate
$argsInstall=@{CandidatePath=$candidate; LivePath=$local; ExpectedOriginalHash=$before; ExpectedCandidateHash=(Get-FileSha256 $candidate)}
[IO.File]::AppendAllText($local, ' ')
Blocks { Install-Candidate @argsInstall } 'local changed during review blocks'
[IO.File]::WriteAllText($local, "<root>$personal</root>")
[IO.File]::AppendAllText($candidate, ' ')
Blocks { Install-Candidate @argsInstall } 'candidate changed during review blocks'
Write-CandidateFile $build $candidate
# The test does not inspect actual processes; guard behavior needs Windows acceptance.
function Assert-LightORamaClosed {}
$installed=Install-Candidate @argsInstall
Check ((Get-FileSha256 $installed.BackupPath) -eq $before) 'backup preserves original bytes'
$again=Build-SyncCandidate $master.Records $local $null
$counts=Get-ActionCounts $again.Rows
Check ($counts.Add -eq 0 -and $counts.Replace -eq 0) 'second run ADD 0 REPLACE 0'
Write-Output "Disposable evidence: $fixture"

$revisionOnly=[IO.File]::ReadAllText($local).Replace('Revision="57"', 'Revision="900"')
[IO.File]::WriteAllText($local, $revisionOnly)
$revisionBuild=Build-SyncCandidate $master.Records $local $null
Check ((Get-ActionCounts $revisionBuild.Rows).RevisionOnly -eq 1) 'higher local Revision alone is NOOP'
[IO.File]::WriteAllText($local, $revisionOnly.Replace('HW-Flood', 'old content'))
$replaceBuild=Build-SyncCandidate $master.Records $local $null
Check ((Get-ActionCounts $replaceBuild.Rows).Replace -eq 1 -and $replaceBuild.Candidate.Contains($personal)) 'substantive replacement ignores revision rank and preserves unmanaged'
[IO.File]::WriteAllText($local, $revisionOnly.Replace('</root>', $raw + '</root>'))
Blocks { Build-SyncCandidate $master.Records $local $null } 'duplicate controlled identity blocks'
[IO.File]::WriteAllText($local, '<root><PreviewClass id="personal" Name="Rotary-Trees" Revision="1"><Scene /></PreviewClass></root>')
Blocks { Build-SyncCandidate $master.Records $local $null } 'same controlled name with different local identity blocks'
