# Disposable wrapper execution with fake SCP/SSH. Never contacts a real host.
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
Add-Type -AssemblyName System.IO.Compression
$fixture=Join-Path ([IO.Path]::GetTempPath()) ('msb299-catalog-wrapper-'+[guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($fixture)
$folder=Join-Path $fixture 'Database Previews V6.6.12';[void][IO.Directory]::CreateDirectory($folder)
$file=Join-Path $folder 'Test.lorprev';[IO.File]::WriteAllText($file,'copied source bytes')
$original=(Get-FileHash $file -Algorithm SHA256).Hash
Copy-Item (Join-Path $PSScriptRoot 'Review-LOR2PC-Catalog.ps1') $fixture
Copy-Item (Join-Path $PSScriptRoot 'review_clone.sh') $fixture
@{source_commit=('a'*40);files=@{'review_clone.sh'=(Get-FileHash (Join-Path $fixture 'review_clone.sh') -Algorithm SHA256).Hash}} | ConvertTo-Json -Depth 3 | Set-Content (Join-Path $fixture 'SOURCE.json')
$global:MSBCatalogWrapperTest=[pscustomobject]@{Scp=0;Ssh=0;Zip=''}
function global:Read-Host { return 'fixture@example.org' }
function global:scp {
    $global:MSBCatalogWrapperTest.Scp++
    $global:MSBCatalogWrapperTest.Zip=[string]$args[0]
    $stream=[IO.File]::OpenRead($args[0])
    $zip=New-Object IO.Compression.ZipArchive($stream,[IO.Compression.ZipArchiveMode]::Read)
    try {
        if ($zip.Entries.Count -ne 1 -or $zip.Entries[0].FullName -ne 'Test.lorprev') {throw 'Wrong copied source set'}
        $reader=New-Object IO.StreamReader($zip.Entries[0].Open())
        try {if ($reader.ReadToEnd() -cne 'copied source bytes') {throw 'Copied source differs'}} finally {$reader.Dispose()}
    } finally {$zip.Dispose();$stream.Dispose()}
    $global:LASTEXITCODE=0
}
function global:ssh {
    $global:MSBCatalogWrapperTest.Ssh++
    if ('-tt' -notin $args -or '-L' -notin $args -or '8898:127.0.0.1:8898' -notin $args) {throw 'Expected foreground SSH with registered tunnel'}
    $global:LASTEXITCODE=0
}
try {
    & (Join-Path $fixture 'Review-LOR2PC-Catalog.ps1') -MasterFolder $folder
    if ($global:MSBCatalogWrapperTest.Scp -ne 1 -or $global:MSBCatalogWrapperTest.Ssh -ne 1) {throw 'Expected one transfer and one execution session'}
    if (Test-Path $global:MSBCatalogWrapperTest.Zip) {throw 'Temporary local ZIP not removed'}
    if ((Get-FileHash $file -Algorithm SHA256).Hash -cne $original) {throw 'Input source mutated'}
    Write-Output 'PASS: copied master bytes preserved, exactly one fake SCP/foreground SSH, local temporary ZIP cleaned'
} finally {
    Remove-Item Function:\Read-Host,Function:\scp,Function:\ssh -Force -ErrorAction SilentlyContinue
    Remove-Variable MSBCatalogWrapperTest -Scope Global -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $fixture -Recurse -Force
}
