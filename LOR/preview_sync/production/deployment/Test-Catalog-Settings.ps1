# Functions-only configuration proof; never runs a real task or reads DPAPI.
$ErrorActionPreference='Stop'
$source=Join-Path $PSScriptRoot '..\..\..\..\run_lor_runner.ps1'
$tokens=$null;$errors=$null
$ast=[Management.Automation.Language.Parser]::ParseFile((Resolve-Path $source),[ref]$tokens,[ref]$errors)
if($errors.Count){throw ($errors|Out-String)}
$fn=$ast.Find({param($node)$node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Set-CatalogEnvironment'},$true)
. ([scriptblock]::Create($fn.Extent.Text))
$root=Join-Path ([IO.Path]::GetTempPath()) ('msb299-settings-'+[guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($root)
try {
    $env:LOR_CATALOG_PUBLISHERS='ambient@example.org';$env:LOR_CATALOG_ROOT='ambient'
    Set-CatalogEnvironment $root
    if($env:LOR_CATALOG_PUBLISHERS -or $env:LOR_CATALOG_ROOT){throw 'Ambient catalog authority leaked'}
    $path=Join-Path $root 'catalog-settings.json'
    @{schema_version=1;enabled=$true;publishers=@('Publisher@example.org')}|ConvertTo-Json|Set-Content $path
    $blocked=$false;try{Set-CatalogEnvironment $root}catch{$blocked=$true}
    if(-not $blocked){throw 'Missing evidence directory accepted'}
    [void][IO.Directory]::CreateDirectory((Join-Path $root 'preview-catalog'))
    # Linux verifies shape/environment only; native Windows ACL proof remains a gate.
    if([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT){
        Set-CatalogEnvironment $root
        if($env:LOR_CATALOG_PUBLISHERS -cne 'publisher@example.org'){throw 'Publisher settings not loaded'}
    }
    @{schema_version=1;enabled=$false;publishers=@()}|ConvertTo-Json|Set-Content $path
    Set-CatalogEnvironment $root
    if($env:LOR_CATALOG_PUBLISHERS -or $env:LOR_CATALOG_ROOT){throw 'Disabled configuration retained authority'}
    Write-Output 'PASS: explicit per-profile settings, ambient authority cleared, missing directory blocks, disabled clears; native ACL test pending'
} finally {Remove-Item $root -Recurse -Force;Remove-Item Env:\LOR_CATALOG_ROOT,Env:\LOR_CATALOG_PUBLISHERS -ErrorAction SilentlyContinue}
