# MSB LOR Parser launcher
#
# Purpose:
#   Run the current parser copy from its proposed LOR-side home while leaving
#   the existing parser under LOR2DB/01_Ingest untouched during validation.
#
# This launcher intentionally contains no parser or ingest logic.

$ErrorActionPreference = 'Stop'

$RepoRoot = $PSScriptRoot
$ParserPath = Join-Path $RepoRoot 'Docs\01_LOR_System\02_Data_Extraction\Parser\parse_props_v7_scene_parser.py'

if (-not (Test-Path -LiteralPath $ParserPath -PathType Leaf)) {
    Write-Error "Parser not found: $ParserPath"
    exit 2
}

$PythonCommand = Get-Command python -ErrorAction SilentlyContinue
if (-not $PythonCommand) {
    Write-Error "Python was not found in the current PowerShell environment. Activate the project virtual environment and try again."
    exit 3
}

Write-Host "[INFO] Parser: $ParserPath"
Write-Host "[INFO] Python: $($PythonCommand.Source)"

& $PythonCommand.Source $ParserPath @args
$ParserExitCode = $LASTEXITCODE

if ($null -eq $ParserExitCode) {
    $ParserExitCode = 0
}

exit $ParserExitCode
