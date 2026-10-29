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
# Load the production pattern instead of keeping a divergent test copy.
Invoke-Expression (@($source -split "`n" | Where-Object { $_.StartsWith('$PreviewBlockPattern =') })[0])
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

# Content explanations use actual XML, independently of Revision metadata.
$before='<PreviewClass id="review" Name="Trees" Revision="99"><PropClass id="keep" Name="Flood" Channel="1" /></PreviewClass>'
$after='<PreviewClass id="review" Name="Trees" Revision="1"><PropClass id="keep" Name="Flood" Channel="2" />'
for ($i=0;$i -lt 8;$i++) { $after += '<PropClass id="new'+$i+'" Name="RGB '+$i+'" />' }
$after+='</PreviewClass>'
$details=[MSBPreviewSemantic]::DescribeChanges($before,$after)
Check (([regex]::Matches($details,'Added item:')).Count -eq 8 -and $details.Contains('Channel: "1" -> "2"')) 'review explains actual added props and channel changes'
Check (-not $details.Contains('Revision')) 'review does not use Revision as a substantive change'
Check ([MSBPreviewSemantic]::DescribeChanges($before,$before.Replace('Revision="99"','Revision="1"')) -eq '') 'revision-only review has no content differences'
$ordered='<PreviewClass id="review" Name="Trees"><Scene id="a" /><Scene id="b" /></PreviewClass>'
$reordered='<PreviewClass id="review" Name="Trees"><Scene id="b" /><Scene id="a" /></PreviewClass>'
Check ([MSBPreviewSemantic]::DescribeChanges($ordered,$reordered).Contains('Changed item order')) 'review exposes item reordering'
Check ([MSBPreviewSemantic]::DescribeChanges($after,$before).Contains('Removed item:')) 'review exposes removed props'
function Test-DeploymentIdentity {return $script:fakeDeployment}
$script:fakeDeployment=[pscustomobject]@{VerifiedMetadataHash=('a'*64);source_commit=('b'*40);apply_enabled=$true}
Assert-ReviewedDeployment -ExpectedHash ('a'*64) -ExpectedCommit ('b'*40)
$script:fakeDeployment.apply_enabled=$false
Blocks {Assert-ReviewedDeployment -ExpectedHash ('a'*64) -ExpectedCommit ('b'*40)} 'revoked apply permission blocks after review'
$script:fakeDeployment.apply_enabled=$true
Blocks {Assert-ReviewedDeployment -ExpectedHash ('c'*64) -ExpectedCommit ('b'*40)} 'changed release metadata blocks after review'
Blocks {Assert-ReviewedDeployment -ExpectedHash ('a'*64) -ExpectedCommit ('c'*40)} 'changed source commit blocks after review'

# Revision alignment is optional metadata normalization, not content authority.
$alignment=Join-Path $fixture 'alignment-local.xml'
$alignmentCandidate=Join-Path $fixture 'alignment-candidate.xml'
$alignmentReport=Join-Path $fixture 'alignment.csv'
$revisionRaw=$raw.Replace('Revision="57"','Revision="900"')
[IO.File]::WriteAllText($alignment,"<root>$personal$revisionRaw</root>")
$originalAlignmentHash=Get-FileSha256 $alignment
$defaultPlan=Build-SyncCandidate $master.Records $alignment $null
Check ((Get-ActionCounts $defaultPlan.Rows).RevisionOnly -eq 1 -and $defaultPlan.Candidate.Contains('Revision="900"')) 'default preserves local Revision and takes no content action'
$plan=New-ReviewPlan -MasterRecords $master.Records -LocalPath $alignment -ExpectedOriginalHash $originalAlignmentHash -CandidatePath $alignmentCandidate -ReportPath $alignmentReport -MatchMasterRevision
Check ((Get-ActionCounts $plan.Build.Rows).AlignRevision -eq 1 -and (Get-ActionCounts $plan.Build.Rows).Replace -eq 0) 'explicit alignment is classified as metadata, not replacement'
Check ($plan.Build.Candidate.Contains($personal) -and -not $plan.Build.Candidate.Contains('Revision="900"')) 'alignment preserves unmanaged bytes and matches accepted master Revision'
$alignedRaw=[regex]::Match($plan.Build.Candidate,$PreviewBlockPattern,$RegexOptions).NextMatch().Value
Check ((Get-PreviewRecord $alignedRaw 'aligned').SemanticHash -eq (Get-PreviewRecord $revisionRaw 'original').SemanticHash) 'alignment proves substantive content hash unchanged'
$diff=[MSBPreviewSemantic]::UnifiedDiff($revisionRaw,$raw)
Check (($diff -split "`r?`n").Count -eq 2 -and $diff.Contains('- Preview Revision') -and $diff.Contains('+ Preview Revision')) 'revision-only diff contains only the two metadata lines'
Blocks {[MSBPreviewSemantic]::MatchMasterRevision($before,$after)} 'different substantive content cannot be normalized as revision-only'
Check ([MSBPreviewSemantic]::UnifiedDiff($before,$after).Contains('+ Added item:') -and [MSBPreviewSemantic]::UnifiedDiff($before,$after).Contains('- Preview /')) 'unified diff exposes local and master values and added props'
$commentBefore='<PreviewClass id="p" Name="Stage"><Scene id="s1" Name="Scene A"/><PropClass id="a" Name="Channel A" Comment="Display A" StringType="DumbRGB"/></PreviewClass>'
$commentAfter=$commentBefore.Replace('Display A','Display B').Replace('Scene A','Scene B').Replace('DumbRGB','RGB')
$impact=[MSBPreviewSemantic]::ImpactNotes($commentBefore,$commentAfter)
Check ($impact.Contains('Display names (Comment)') -and $impact.Contains('Scenes / scene membership') -and $impact.Contains('Wiring /')) 'review prioritizes display identity, scenes and parser-relevant string settings'
[IO.File]::AppendAllText($alignment,' ')
Blocks {New-ReviewPlan -MasterRecords $master.Records -LocalPath $alignment -ExpectedOriginalHash $originalAlignmentHash -CandidatePath $alignmentCandidate -ReportPath $alignmentReport -MatchMasterRevision} 'local edit blocks candidate rebuild during review'

[IO.File]::WriteAllText($alignment,"<root>$personal$revisionRaw</root>")
$revisionInstall=Install-Candidate -CandidatePath $alignmentCandidate -LivePath $alignment -ExpectedOriginalHash $originalAlignmentHash -ExpectedCandidateHash $plan.CandidateHash
Check ((Get-FileSha256 $revisionInstall.BackupPath) -eq $originalAlignmentHash) 'revision-only apply retains exact original backup'
$repeatAlignment=Build-SyncCandidate -MasterRecords $master.Records -LocalPath $alignment -ProgressWindow $null -MatchMasterRevision
$repeatCounts=Get-ActionCounts $repeatAlignment.Rows
Check ($repeatCounts.Add -eq 0 -and $repeatCounts.Replace -eq 0 -and $repeatCounts.AlignRevision -eq 0) 'revision alignment second run has no additions replacements or metadata changes'

# Evidence must exist before review and survive cancellation/new launches.
$LogFolder=Join-Path $fixture 'logs'
$ApplicationVersion='test'; $ApplicationReleaseDate='2026-10-28'; $script:SourceCommit='test-commit'; $script:SessionLogPath=$null
$logReport=[pscustomobject]@{RunId=32;Path='report';EvidenceId='evidence';ImportRunId=74;SourceFolder=$folder;SourceManifestSha256=$master.SourceStateSha256}
$firstLog=Write-SharedLog -Report $logReport -Build $build -Result 'REVIEW_PREPARED' -OriginalHash 'original' -CandidateHash 'candidate'
$reportCopy=[IO.Path]::ChangeExtension($firstLog,'.csv')
Check ((Test-Path $firstLog) -and (Test-Path $reportCopy) -and ([IO.File]::ReadAllText($firstLog)).Contains('REVIEW_PREPARED')) 'summary and complete CSV exist before review closes'
$exported=@(Import-Csv -LiteralPath $reportCopy)
Check ($exported.Count -eq $build.Rows.Count -and $exported[0].Review_Diff -ceq $build.Rows[0].Review_Diff) 'retained report includes exact multiline review diff'
$cancelLog=Write-SharedLog -Report $logReport -Build $build -Result 'CANCELLED'
$text=[IO.File]::ReadAllText($firstLog)
Check ($cancelLog -eq $firstLog -and $text.Contains('REVIEW_PREPARED') -and $text.Contains('CANCELLED')) 'cancel appends to same run without losing prepared evidence'
$script:SessionLogPath=$null
$nextLog=Write-SharedLog -Report $logReport -Build $build -Result 'REVIEW_PREPARED'
Check ($nextLog -ne $firstLog -and (Test-Path $reportCopy)) 'next launch retains prior run evidence under unique name'

# Root viewing preferences are local; all authored descendants remain controlled.
$viewMaster='<PreviewClass id="view" Name="View" Revision="58" Brightness="20" LastSelectedSceneId=""><Scene id="s" Name="Scene"/><PropClass id="prop" Comment="HW-Flood-01" MasterDimmable="True" Brightness="100" ChannelGrid="Regular,1C,1,3"/></PreviewClass>'
$viewLocal=$viewMaster.Replace('Brightness="20"','Brightness="0"').Replace('LastSelectedSceneId=""','LastSelectedSceneId="s"')
$viewRecords=@{view=(Get-PreviewRecord $viewMaster 'View.lorprev')}
$viewPath=Join-Path $fixture 'view.xml'
[IO.File]::WriteAllText($viewPath,"<root>$personal$viewLocal</root>")
$viewBuild=Build-SyncCandidate -MasterRecords $viewRecords -LocalPath $viewPath -ProgressWindow $null
Check ($viewBuild.Rows[0].Action -eq 'NOOP' -and $viewBuild.Candidate -ceq [IO.File]::ReadAllText($viewPath)) 'presentation-only differences preserve exact local bytes and require no replacement'
Check ($viewBuild.Rows[0].Presentation_Details.Contains('Brightness') -and $viewBuild.Rows[0].Presentation_Details.Contains('LastSelectedSceneId') -and $viewBuild.Rows[0].Review_Diff -eq '') 'presentation differences are reported separately from controlled diff'
$editedView=$viewLocal.Replace('MasterDimmable="True"','MasterDimmable="False"')
[IO.File]::WriteAllText($viewPath,"<root>$personal$editedView</root>")
$viewBuild=Build-SyncCandidate -MasterRecords $viewRecords -LocalPath $viewPath -ProgressWindow $null
$merged=[regex]::Matches($viewBuild.Candidate,$PreviewBlockPattern,$RegexOptions)[1].Value
Check ($viewBuild.Rows[0].Action -eq 'REPLACE_IN_CANDIDATE' -and $viewBuild.Rows[0].Review_Diff.Contains('MasterDimmable')) 'real prop master-dimming change still requires reviewed replacement'
Check ($merged.Contains('Brightness="0"') -and $merged.Contains('LastSelectedSceneId="s"') -and $merged.Contains('MasterDimmable="True"') -and $viewBuild.Candidate.Contains($personal)) 'content replacement preserves local preferences and unmanaged bytes while installing accepted prop settings'
[IO.File]::WriteAllText($viewPath,$viewBuild.Candidate)
$viewRepeat=Build-SyncCandidate -MasterRecords $viewRecords -LocalPath $viewPath -ProgressWindow $null
Check ((Get-ActionCounts $viewRepeat.Rows).Replace -eq 0 -and (Get-ActionCounts $viewRepeat.Rows).Add -eq 0) 'repeat with retained viewing preferences requires zero additions and replacements'
$descendant=$viewMaster.Replace('Brightness="100"','Brightness="50"')
Check ((Get-PreviewRecord $descendant 'child').SemanticHash -ne (Get-PreviewRecord $viewMaster 'master').SemanticHash) 'descendant brightness remains controlled'
$sceneEdit=$viewLocal.Replace('Name="Scene"','Name="Different Scene"')
Check ((Get-PreviewRecord $sceneEdit 'scene').SemanticHash -ne (Get-PreviewRecord $viewMaster 'master').SemanticHash) 'scene definition change remains controlled despite selected-scene preference exclusion'
$absent='<PreviewClass id="view" Name="View" Revision="58"><Scene id="s" Name="Scene"/><PropClass id="prop" Comment="HW-Flood-01" MasterDimmable="False" Brightness="100" ChannelGrid="Regular,1C,1,3"/></PreviewClass>'
$absentMerge=[MSBPreviewSemantic]::PreservePresentation($absent,$viewMaster)
Check (-not $absentMerge.Contains('Brightness="20"') -and -not $absentMerge.Contains('LastSelectedSceneId=')) 'missing local preference attributes remain absent during replacement'
$alignedView=[MSBPreviewSemantic]::MatchMasterRevision($viewLocal.Replace('Revision="58"','Revision="99"'),$viewMaster)
Check ($alignedView.Contains('Revision="58"') -and $alignedView.Contains('Brightness="0"') -and $alignedView.Contains('LastSelectedSceneId="s"')) 'optional Revision alignment preserves local viewing preferences'
Blocks {[MSBPreviewSemantic]::PreservePresentation($viewLocal.Replace('id="view"','id="other"'),$viewMaster)} 'preference merge blocks mismatched preview identity'
$viewFolder=Join-Path $fixture 'view-master';[void][IO.Directory]::CreateDirectory($viewFolder)
$viewFile=Join-Path $viewFolder 'View.lorprev';[IO.File]::WriteAllText($viewFile,$viewMaster)
$digestBefore=(Get-MasterRecords -Folder $viewFolder -ProgressWindow $null).SourceStateSha256
[IO.File]::WriteAllText($viewFile,$viewLocal)
$digestAfter=(Get-MasterRecords -Folder $viewFolder -ProgressWindow $null).SourceStateSha256
Check ($digestBefore -ne $digestAfter) 'accepted-master byte digest still detects presentation edits to master'

# New catalog acceptance is distinct from the inherited database baseline.
$script:BrowserSourceForTest=$null
function Receive-BrowserSource { return $script:BrowserSourceForTest }
$CurrentSourceUrl='https://example.org/current-source'
$doc=[ordered]@{schema_version=2;status='ACCEPTED';validation='PASSED';acceptance_kind='PREVIEW_CATALOG';catalog_policy='MSB_PREVIEW_CATALOG_V1';database_baseline_evidence_id=('a'*64);published_by='publisher@example.org';published_at='2026-10-28T12:00:00Z';source_manifest_sha256=('b'*64);evidence_id=('c'*64);report_sha256=('d'*64);source_sqlite_sha256=('e'*64);run_id=32;import_run_id=74;preview_count=1;lor_version='6.6.12';source_folder=(Join-Path $fixture 'Database Previews V6.6.12');report_url='https://example.org/report';previews=@(@{filename='Test.lorprev';preview_id='test';name='Test';revision='58'})}
$script:BrowserSourceForTest=$doc|ConvertTo-Json -Depth 8
$catalogSource=Get-CurrentAcceptedSource
Check ($catalogSource.RunId -eq 32 -and $catalogSource.EvidenceId -eq ('c'*64) -and $catalogSource.AuthorityLabel.Contains('catalog') -and $catalogSource.Rows[0].Revision -eq '58') 'accepted preview catalog uses independent evidence and updated inventory with database baseline label'
$doc.catalog_policy='UNKNOWN';$script:BrowserSourceForTest=$doc|ConvertTo-Json -Depth 8
Blocks {Get-CurrentAcceptedSource} 'unknown catalog acceptance policy blocks'
$doc.catalog_policy='MSB_PREVIEW_CATALOG_V1';$doc.database_baseline_evidence_id='';$script:BrowserSourceForTest=$doc|ConvertTo-Json -Depth 8
Blocks {Get-CurrentAcceptedSource} 'catalog without database baseline evidence blocks'

$shortSummary=[MSBPreviewSemantic]::ProgrammerSummary($viewMaster,$viewMaster.Replace('Regular,1C,1,3','Aux A,1D,4,6').Replace('MasterDimmable="True"','MasterDimmable="False"'))
Check ($shortSummary.Contains('Network/channel assignment changed: 1') -and $shortSummary.Contains('Dimming settings changed: 1') -and -not $shortSummary.Contains('ChannelGrid')) 'programmer summary describes wiring and dimming without XML attribute dump'
$shortAddition=[MSBPreviewSemantic]::ProgrammerSummary('<PreviewClass id="view" Name="View"/>',$viewMaster)
Check ($shortAddition.Contains('Display/prop added: 1') -and $shortAddition.Contains('HW-Flood-01')) 'programmer summary identifies added display by its Comment label'

# Adam's valid library includes self-closing section-heading previews. The old
# scanner consumed a heading together with the next populated preview.
$emptyHead='<PreviewClass id="section" Name="Section heading" Revision="1" />'
$following='<PreviewClass id="following" Name="Following preview" Revision="2"><Scene Name="Keep" /></PreviewClass>'
$emptyLast="<PreviewClass Name='Final heading' id = 'last' Revision='3'/>"
$emptyLibrary='<root>'+ $emptyHead + $following + $emptyLast + '</root>'
[IO.File]::WriteAllText($local,$emptyLibrary)
$emptyBuild=Build-SyncCandidate @{} $local $null
Check ($emptyBuild.LocalCount -eq 3 -and $emptyBuild.Candidate -ceq $emptyLibrary) 'self-closing headings remain separate and unchanged before and after populated preview'
$withAddition=Build-SyncCandidate $master.Records $local $null
Check ($withAddition.Candidate.Contains($emptyHead) -and $withAddition.Candidate.Contains($following) -and $withAddition.Candidate.Contains($emptyLast) -and (Get-ActionCounts $withAddition.Rows).Add -eq 1) 'adding controlled preview preserves empty headings and adjacent populated preview'

# Optional private uploaded fixture stays outside the repository. Never install
# the candidate or modify the programmer's original file during regression.
if ($env:MSB_ADAM_LIBRARY_FIXTURE) {
    $adamPath=$env:MSB_ADAM_LIBRARY_FIXTURE
    $adamHash=Get-FileSha256 $adamPath
    $adam=Build-SyncCandidate @{} $adamPath $null
    Check ($adam.LocalCount -eq 140) 'actual Adam library scans all 140 previews'
    $adamOriginal=[IO.File]::ReadAllText($adamPath)
    Check ($adam.Candidate -ceq $adamOriginal) 'actual Adam library remains text-identical with zero controlled changes'
    $adamAdd=Build-SyncCandidate $master.Records $adamPath $null
    Check ((Get-ActionCounts $adamAdd.Rows).Add -eq 1 -and $adamAdd.UnmanagedCount -eq 140) 'actual Adam library accepts synthetic controlled addition and preserves all 140 existing previews'
    Check ((Get-FileSha256 $adamPath) -ceq $adamHash) 'actual Adam fixture original bytes never modified'
}
