# Test-InstallerPrerequisites.ps1 — functions-only disposable validation; no registry/UI.
$ErrorActionPreference = 'Stop'
$tokens=$null; $errors=$null
$path=Join-Path $PSScriptRoot 'Install-LOR2PC-Launcher.ps1'
$ast=[Management.Automation.Language.Parser]::ParseFile($path,[ref]$tokens,[ref]$errors)
if ($errors.Count) { throw 'Installer syntax invalid' }
$function=$ast.Find({param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Assert-MSBLocalLibrary'},$true)
Invoke-Expression $function.Extent.Text
$script:present=$false
function Test-Path { param($LiteralPath,$PathType)
    if ($LiteralPath -cne 'C:\LOR\CommonData\LORPreviews.xml' -or $PathType -ne 'Leaf') { throw 'Unexpected data-folder test' }
    return $script:present
}
$blocked=$false
try { Assert-MSBLocalLibrary } catch {
    $blocked=$true
    if ($_.Exception.Message -notlike '*MSB requires Light-O-Rama to use C:\LOR*') { throw }
}
if (-not $blocked) { throw 'Missing required library did not block' }
$script:present=$true
Assert-MSBLocalLibrary
Write-Host 'PASS: missing required C:\LOR library blocks; existing required library accepted (functions-only)'
