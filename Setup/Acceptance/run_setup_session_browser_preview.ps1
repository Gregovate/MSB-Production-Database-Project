param(
    [string]$Server = 'msbadmin@192.168.5.9',
    [int]$PreviewPort = 8794,
    [string]$PreviewEmail = 'gliebig@sheboyganlights.org'
)

$ErrorActionPreference = 'Stop'

$impl = Join-Path $PSScriptRoot 'run_setup_session_browser_preview_impl.ps1'
if (-not (Test-Path -LiteralPath $impl)) {
    throw "Setup browser preview implementation is missing: $impl"
}

# The implementation contains guarded multiline replacements against an LF-only
# Linux shell template. Normalize the implementation in memory so the behavior
# is identical whether Windows checked the tracked file out as CRLF or LF.
$text = [System.IO.File]::ReadAllText($impl)
$text = $text.Replace("`r`n", "`n").Replace("`r", "`n")

# Pin the detached application candidate without modifying the larger validated
# implementation file. This keeps launcher-only fixes outside the application
# candidate while still making the review reproducible.
$candidateSource = "$CandidateSha = 'c0b6e4342129516f2f9b344acd4331f4e068e23b'"
$candidateReplacement = "$CandidateSha = 'a3467b0228b3e8403cf42c3021bd519155b6c89d'"
if (-not $text.Contains($candidateSource)) {
    throw 'Setup browser preview implementation no longer contains the expected candidate SHA assignment.'
}
$text = $text.Replace($candidateSource, $candidateReplacement)

# The implementation normally derives Setup/Acceptance from its own file path.
# Because it is executed from memory here, supply the same directory explicitly.
$literalScriptDir = $PSScriptRoot.Replace("'", "''")
$sourceLine = '$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path'
$replacementLine = "`$ScriptDir = '$literalScriptDir'"
if (-not $text.Contains($sourceLine)) {
    throw 'Setup browser preview implementation no longer contains the expected ScriptDir initialization.'
}
$text = $text.Replace($sourceLine, $replacementLine)

$script = [scriptblock]::Create($text)
& $script -Server $Server -PreviewPort $PreviewPort -PreviewEmail $PreviewEmail
