# MSB LOR Preview Sync - Production Candidate v1.0.0
# Programmer-facing MASTER -> LOCAL synchronization tool.
#
# Normal operators launch this through:
#   Update your PC Previews to LOR Master Files (Windows shortcut)
#
# The script:
# - discovers the latest published COMPLETED LOR2DB reconciliation report from the authoritative LOR2DB report archive;
# - validates the exact versioned master folder recorded by that report and blocks post-run source drift;
# - compares controlled previews by PreviewClass.id and substantive content;
# - ignores revision-only differences;
# - preserves all personal/unmanaged PreviewClass blocks byte-for-byte;
# - requires acknowledgement before overwriting substantively different local MSB previews;
# - backs up the local LORPreviews.xml before apply;
# - atomically replaces the local file only after validation.
#
# It does NOT update the versioned master folder and does NOT change LOR2DB state.

[CmdletBinding()]
param(
    [string]$Root = '',
    [string]$LocalXml = 'C:\lor\CommonData\LORPreviews.xml',
    [string]$ReportArchive = '\\192.168.5.4\web\my\lor2db\reports',
    [switch]$AuditOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Resolve the script root after parameter binding. Windows PowerShell 5.1 can
# evaluate $PSScriptRoot as empty when it is used as a parameter default under
# some launcher paths, which makes Join-Path fail before the UI starts.
if ([string]::IsNullOrWhiteSpace($Root)) {
    $Root = $PSScriptRoot
}
if ([string]::IsNullOrWhiteSpace($Root) -and $MyInvocation.MyCommand.Path) {
    $Root = Split-Path -Parent $MyInvocation.MyCommand.Path
}
if ([string]::IsNullOrWhiteSpace($Root)) {
    throw 'The MSB Preview Update could not determine its shared-folder location.'
}

$ScriptPath = $PSCommandPath
if ([string]::IsNullOrWhiteSpace($ScriptPath)) {
    $ScriptPath = $MyInvocation.MyCommand.Path
}
if ([string]::IsNullOrWhiteSpace($ScriptPath)) {
    throw 'The MSB Preview Update could not determine its program-file path.'
}

if ([string]::IsNullOrWhiteSpace($LocalXml)) {
    throw 'The local Light-O-Rama preview-library path is empty.'
}
$localParent = Split-Path -Parent $LocalXml
if ([string]::IsNullOrWhiteSpace($localParent)) {
    throw "The local Light-O-Rama preview-library folder could not be determined: $LocalXml"
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

# Compile the semantic PreviewClass reader once per launch. It implements the
# same comparison contract as the original PowerShell code: root Revision is
# ignored, attributes are compared independent of ordering, whitespace-only
# text is ignored, and all substantive element/text content is hashed.
Add-Type -ReferencedAssemblies @('System.Xml.dll','System.Core.dll') -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Security.Cryptography;
using System.Text;
using System.Xml;

public sealed class MSBPreviewInfo
{
    public string PreviewId { get; set; }
    public string Name { get; set; }
    public string Revision { get; set; }
    public string SemanticHash { get; set; }
}

public static class MSBPreviewSemantic
{
    private static void AddToken(StringBuilder builder, string kind, string value)
    {
        if (value == null) value = "";
        builder.Append(kind);
        builder.Append(':');
        builder.Append(value.Length);
        builder.Append(':');
        builder.Append(value);
        builder.Append(';');
    }

    private static void AddNode(XmlNode node, StringBuilder builder, bool isRoot)
    {
        AddToken(builder, "E", node.LocalName);

        if (node.Attributes != null)
        {
            List<XmlAttribute> attrs = new List<XmlAttribute>();
            foreach (XmlAttribute attr in node.Attributes)
            {
                if (isRoot && String.Equals(attr.LocalName, "Revision", StringComparison.OrdinalIgnoreCase))
                    continue;
                attrs.Add(attr);
            }
            attrs.Sort((a, b) => StringComparer.Ordinal.Compare(a.Name, b.Name));

            foreach (XmlAttribute attr in attrs)
            {
                AddToken(builder, "A", attr.LocalName);
                AddToken(builder, "V", attr.Value);
            }
        }

        foreach (XmlNode child in node.ChildNodes)
        {
            if (child.NodeType == XmlNodeType.Element)
            {
                AddNode(child, builder, false);
            }
            else if (child.NodeType == XmlNodeType.Text || child.NodeType == XmlNodeType.CDATA)
            {
                string value = child.Value ?? "";
                if (!String.IsNullOrWhiteSpace(value))
                    AddToken(builder, "T", value);
            }
        }

        AddToken(builder, "X", node.LocalName);
    }

    private static string Sha256(string value)
    {
        using (SHA256 sha = SHA256.Create())
        {
            byte[] bytes = Encoding.UTF8.GetBytes(value);
            byte[] digest = sha.ComputeHash(bytes);
            StringBuilder result = new StringBuilder(digest.Length * 2);
            foreach (byte b in digest)
                result.Append(b.ToString("x2"));
            return result.ToString();
        }
    }

    public static MSBPreviewInfo Parse(string raw, string source)
    {
        XmlDocument doc = new XmlDocument();
        doc.PreserveWhitespace = true;
        doc.LoadXml(raw);

        XmlElement node = doc.DocumentElement;
        if (node == null || !String.Equals(node.LocalName, "PreviewClass", StringComparison.Ordinal))
            throw new InvalidOperationException("Preview fragment is not PreviewClass: " + source);

        string id = node.GetAttribute("id");
        if (String.IsNullOrEmpty(id)) id = node.GetAttribute("ID");
        if (String.IsNullOrEmpty(id)) id = node.GetAttribute("Id");
        if (String.IsNullOrEmpty(id))
            throw new InvalidOperationException("PreviewClass has no id/ID/Id: " + source);

        StringBuilder builder = new StringBuilder();
        AddNode(node, builder, true);

        return new MSBPreviewInfo {
            PreviewId = id.ToLowerInvariant(),
            Name = node.GetAttribute("Name"),
            Revision = node.GetAttribute("Revision"),
            SemanticHash = Sha256(builder.ToString())
        };
    }
}
'@

Add-Type -ReferencedAssemblies @('System.Core.dll') -TypeDefinition @'
using System;
using System.IO;
using System.Security.Cryptography;
using System.Text;

public static class MSBSourceManifest
{
    private static string Sha256File(string path)
    {
        using (FileStream stream = File.OpenRead(path))
        using (SHA256 sha = SHA256.Create())
        {
            byte[] digest = sha.ComputeHash(stream);
            StringBuilder output = new StringBuilder(digest.Length * 2);
            foreach (byte value in digest) output.Append(value.ToString("x2"));
            return output.ToString();
        }
    }

    private static string JsonString(string value)
    {
        StringBuilder output = new StringBuilder();
        output.Append('"');
        foreach (char ch in value)
        {
            switch (ch)
            {
                case '\\': output.Append("\\\\"); break;
                case '"': output.Append("\\\""); break;
                case '\b': output.Append("\\b"); break;
                case '\f': output.Append("\\f"); break;
                case '\n': output.Append("\\n"); break;
                case '\r': output.Append("\\r"); break;
                case '\t': output.Append("\\t"); break;
                default:
                    if (ch < 0x20) output.Append("\\u" + ((int)ch).ToString("x4"));
                    else output.Append(ch);
                    break;
            }
        }
        output.Append('"');
        return output.ToString();
    }

    public static string Compute(string folder)
    {
        string[] files = Directory.GetFiles(folder, "*.lorprev", SearchOption.TopDirectoryOnly);
        Array.Sort(files, delegate(string left, string right)
        {
            return StringComparer.OrdinalIgnoreCase.Compare(Path.GetFileName(left), Path.GetFileName(right));
        });

        StringBuilder payload = new StringBuilder();
        payload.Append('[');
        for (int index = 0; index < files.Length; index++)
        {
            if (index > 0) payload.Append(',');
            payload.Append("{\"filename\":");
            payload.Append(JsonString(Path.GetFileName(files[index])));
            payload.Append(",\"sha256\":\"");
            payload.Append(Sha256File(files[index]));
            payload.Append("\"}");
        }
        payload.Append(']');

        using (SHA256 sha = SHA256.Create())
        {
            byte[] digest = sha.ComputeHash(Encoding.UTF8.GetBytes(payload.ToString()));
            StringBuilder output = new StringBuilder(digest.Length * 2);
            foreach (byte value in digest) output.Append(value.ToString("x2"));
            return output.ToString();
        }
    }
}
'@

# Prevent repeated double-clicks from starting multiple writers against the
# same candidate/report files. An exclusive file handle is held for the entire
# lifetime of this PowerShell process. Windows releases it automatically if the
# process exits or crashes, so there is no stale-lock cleanup problem.
$script:InstanceLockStream = $null
$instanceLockFolder = Join-Path $env:LOCALAPPDATA 'MSB'
$instanceLockPath = Join-Path $instanceLockFolder 'LORPreviewUpdate.instance.lock'

try {
    if (-not (Test-Path -LiteralPath $instanceLockFolder -PathType Container)) {
        [void][System.IO.Directory]::CreateDirectory($instanceLockFolder)
    }

    $script:InstanceLockStream = [System.IO.File]::Open(
        $instanceLockPath,
        [System.IO.FileMode]::OpenOrCreate,
        [System.IO.FileAccess]::ReadWrite,
        [System.IO.FileShare]::None
    )
}
catch [System.IO.IOException] {
    [void][System.Windows.Forms.MessageBox]::Show(
        "MSB Preview Update is already starting or open on this PC.`r`n`r`nPlease use the existing window.",
        'MSB Preview Update',
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Information
    )
    exit 0
}
catch {
    [void][System.Windows.Forms.MessageBox]::Show(
        "MSB Preview Update could not create its single-instance safety lock.`r`n`r`n" +
        $_.Exception.Message + "`r`n`r`nNothing was changed.",
        'MSB Preview Update Blocked',
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    )
    exit 2
}

$AppIconPath = Join-Path $Root 'MSB Preview Update Tree v2.ico'
$script:AppIcon = $null
if (Test-Path -LiteralPath $AppIconPath -PathType Leaf) {
    try {
        $script:AppIcon = New-Object System.Drawing.Icon($AppIconPath)
    }
    catch {
        $script:AppIcon = $null
    }
}

$LogFolder = Join-Path $Root 'logs'
$DeploymentPath = Join-Path $Root 'DEPLOYMENT.json'
$ApplicationVersion = '1.0.0'
$CandidateXml = Join-Path $localParent 'LORPreviews.MSB_SYNC_CANDIDATE.xml'
$CandidateCsv = Join-Path $localParent 'LORPreviews.MSB_SYNC_REPORT.csv'

$PreviewBlockPattern = '<PreviewClass\b[^>]*\bid=["''](?<id>[^"'']+)["''][^>]*>.*?</PreviewClass>'
$RegexOptions = [System.Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [System.Text.RegularExpressions.RegexOptions]::Singleline

function Show-Message {
    param(
        [Parameter(Mandatory=$true)][string]$Text,
        [string]$Title = 'MSB LOR Preview Update',
        [System.Windows.Forms.MessageBoxIcon]$Icon = [System.Windows.Forms.MessageBoxIcon]::Information
    )

    # Give native MessageBox dialogs the same tree/star taskbar identity as the
    # main forms instead of exposing the generic PowerShell icon.
    $owner = New-Object System.Windows.Forms.Form
    $owner.Text = $Title
    $owner.ShowInTaskbar = $true
    $owner.StartPosition = 'CenterScreen'
    $owner.Size = New-Object System.Drawing.Size(1,1)
    $owner.Opacity = 0
    if ($null -ne $script:AppIcon) {
        $owner.Icon = $script:AppIcon
    }

    try {
        $owner.Show()
        $owner.Activate()
        [System.Windows.Forms.Application]::DoEvents()
        [void][System.Windows.Forms.MessageBox]::Show(
            $owner,
            $Text,
            $Title,
            [System.Windows.Forms.MessageBoxButtons]::OK,
            $Icon
        )
    }
    finally {
        $owner.Close()
        $owner.Dispose()
    }
}

function Get-CleanHtmlText {
    param([string]$Value)
    $withoutTags = [regex]::Replace($Value, '<[^>]+>', '')
    return [System.Net.WebUtility]::HtmlDecode($withoutTags).Trim()
}

function Read-AcceptedReport {
    param([Parameter(Mandatory=$true)][string]$Path)

    $text = Get-Content -LiteralPath $Path -Raw -Encoding UTF8

    # Only immutable published reports with a successful final lifecycle are
    # accepted. CANCELLED, exception, evaluation and unfinished evidence must
    # never become a PC-sync authority.
    if ($text -notmatch '<body\b[^>]*data-report-outcome=["'']COMPLETED["'']') {
        return $null
    }
    if ($text -notmatch '(?is)<td>\s*COMPLETED\s*</td>\s*<td>\s*PASSED\s*</td>') {
        return $null
    }

    $runMatch = [regex]::Match(
        $text,
        'LOR Production Reconciliation Report\s*(?:\u2014|-)\s*Run\s+(\d+)',
        [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
    )
    $sourceMatch = [regex]::Match(
        $text,
        '<strong>\s*Source folder:\s*</strong>\s*([^<]+)',
        [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
    )
    $generatedMatch = [regex]::Match(
        $text,
        '<p\s+class=["'']meta["'']>\s*Generated\s+([^<\u00b7]+)',
        [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
    )
    $manifestMatch = [regex]::Match(
        $text,
        '<strong>\s*Source manifest SHA-256:\s*</strong>\s*([a-fA-F0-9]{64})',
        [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
    )
    $sectionMatch = [regex]::Match(
        $text,
        '<h2>\s*3\.\s*Source Preview Files\s*</h2>(.*?)(?=<h2>\s*4\.)',
        $RegexOptions
    )

    if (-not $runMatch.Success -or -not $sourceMatch.Success -or -not $sectionMatch.Success) {
        return $null
    }

    $tableMatch = [regex]::Match($sectionMatch.Groups[1].Value, '<table\b[^>]*>(.*?)</table>', $RegexOptions)
    if (-not $tableMatch.Success) {
        return $null
    }

    $rows = @()
    foreach ($rowMatch in [regex]::Matches($tableMatch.Groups[1].Value, '<tr\b[^>]*>(.*?)</tr>', $RegexOptions)) {
        $cells = @()
        foreach ($cellMatch in [regex]::Matches($rowMatch.Groups[1].Value, '<t[dh]\b[^>]*>(.*?)</t[dh]>', $RegexOptions)) {
            $cells += Get-CleanHtmlText $cellMatch.Groups[1].Value
        }

        if ($cells.Count -lt 5) { continue }
        if ($cells[0] -ieq 'Preview filename') { continue }

        $rows += [pscustomobject]@{
            Filename    = $cells[0]
            Revision    = $cells[1]
            PreviewName = $cells[2]
            Stage       = $cells[3]
            Brightness  = $cells[4]
        }
    }

    if ($rows.Count -eq 0) {
        return $null
    }

    $generatedUtc = $null
    if ($generatedMatch.Success) {
        $generatedText = [System.Net.WebUtility]::HtmlDecode($generatedMatch.Groups[1].Value).Trim()
        $parsedGenerated = [datetimeoffset]::MinValue
        if ([datetimeoffset]::TryParse(
            $generatedText,
            [System.Globalization.CultureInfo]::InvariantCulture,
            [System.Globalization.DateTimeStyles]::AssumeUniversal,
            [ref]$parsedGenerated
        )) {
            $generatedUtc = $parsedGenerated.UtcDateTime
        }
    }

    return [pscustomobject]@{
        Path                 = $Path
        RunId                = [int]$runMatch.Groups[1].Value
        SourceFolder         = [System.Net.WebUtility]::HtmlDecode($sourceMatch.Groups[1].Value).Trim()
        SourceManifestSha256 = $(if ($manifestMatch.Success) { $manifestMatch.Groups[1].Value.ToLowerInvariant() } else { '' })
        GeneratedUtc         = $generatedUtc
        Rows                 = $rows
    }
}

function Get-LatestAcceptedReport {
    param([Parameter(Mandatory=$true)][string]$Folder)

    if (-not (Test-Path -LiteralPath $Folder -PathType Container)) {
        throw (
            "The authoritative LOR2DB report archive is not available on this PC:`r`n" +
            "$Folder`r`n`r`nThe updater will not fall back to an old copied report."
        )
    }

    $accepted = @()
    foreach ($file in @(Get-ChildItem -LiteralPath $Folder -Filter 'lor-reconciliation-*-run-*.html' -File)) {
        if ($file.Name -match '-evaluation\.html$') {
            continue
        }
        if ($file.Name -notmatch '^lor-reconciliation-\d{8}-\d{6}-run-\d+\.html$') {
            continue
        }

        $report = Read-AcceptedReport -Path ([string]$file.FullName)
        if ($null -ne $report) {
            $accepted += $report
        }
    }

    if ($accepted.Count -eq 0) {
        throw "No published COMPLETED/PASSED LOR2DB reconciliation reports were found in:`r`n$Folder"
    }

    return $accepted | Sort-Object RunId -Descending | Select-Object -First 1
}

function Add-Token {
    param(
        [Parameter(Mandatory=$true)][System.Text.StringBuilder]$Builder,
        [Parameter(Mandatory=$true)][string]$Kind,
        [AllowNull()][string]$Value
    )

    if ($null -eq $Value) { $Value = '' }
    [void]$Builder.Append($Kind)
    [void]$Builder.Append(':')
    [void]$Builder.Append($Value.Length)
    [void]$Builder.Append(':')
    [void]$Builder.Append($Value)
    [void]$Builder.Append(';')
}

function Add-SemanticNode {
    param(
        [Parameter(Mandatory=$true)][System.Xml.XmlNode]$Node,
        [Parameter(Mandatory=$true)][System.Text.StringBuilder]$Builder,
        [bool]$IsRoot = $false
    )

    Add-Token $Builder 'E' $Node.LocalName

    if ($Node.Attributes) {
        $attrs = @($Node.Attributes | Sort-Object Name)
        foreach ($attr in $attrs) {
            if ($IsRoot -and $attr.LocalName -ieq 'Revision') {
                continue
            }
            Add-Token $Builder 'A' $attr.LocalName
            Add-Token $Builder 'V' $attr.Value
        }
    }

    foreach ($child in @($Node.ChildNodes)) {
        if ($child.NodeType -eq [System.Xml.XmlNodeType]::Element) {
            Add-SemanticNode $child $Builder $false
        }
        elseif ($child.NodeType -in @(
            [System.Xml.XmlNodeType]::Text,
            [System.Xml.XmlNodeType]::CDATA
        )) {
            $value = [string]$child.Value
            if (-not [string]::IsNullOrWhiteSpace($value)) {
                Add-Token $Builder 'T' $value
            }
        }
    }

    Add-Token $Builder 'X' $Node.LocalName
}

function Get-Sha256String {
    param([Parameter(Mandatory=$true)][string]$Text)

    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
        return ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-', '').ToLowerInvariant()
    }
    finally {
        $sha.Dispose()
    }
}

function Get-FileSha256 {
    param([Parameter(Mandatory=$true)][string]$Path)
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Test-DeploymentIdentity {
    if (-not (Test-Path -LiteralPath $DeploymentPath -PathType Leaf)) {
        throw "MSB Preview Sync deployment identity is missing:`r`n$DeploymentPath"
    }

    try {
        $deployment = Get-Content -LiteralPath $DeploymentPath -Raw -Encoding UTF8 | ConvertFrom-Json
    }
    catch {
        throw "MSB Preview Sync deployment identity could not be read:`r`n$DeploymentPath"
    }

    $version = [string]$deployment.version
    $expectedHash = [string]$deployment.updater_sha256
    if ($version -ne $ApplicationVersion) {
        throw "MSB Preview Sync deployment version mismatch. Expected $ApplicationVersion; found $version."
    }
    if ($expectedHash -notmatch '^[a-fA-F0-9]{64}$') {
        throw 'MSB Preview Sync deployment identity does not contain a valid updater SHA-256.'
    }

    $actualHash = Get-FileSha256 -Path $ScriptPath
    if ($actualHash -ne $expectedHash.ToLowerInvariant()) {
        throw (
            "MSB Preview Sync program files do not match the controlled deployment.`r`n" +
            "Expected: $($expectedHash.ToLowerInvariant())`r`nActual:   $actualHash"
        )
    }

    if ($deployment.report_archive) {
        $configuredArchive = [string]$deployment.report_archive
        if ($configuredArchive -ne $ReportArchive) {
            throw (
                "MSB Preview Sync report archive mismatch.`r`n" +
                "Deployment: $configuredArchive`r`nProgram:    $ReportArchive"
            )
        }
    }

    return $deployment
}

function Get-RunningLorProcesses {
    $names = @('LORSequencer','LORSequenceEditor')
    $found = @()
    foreach ($name in $names) {
        $found += @(Get-Process -Name $name -ErrorAction SilentlyContinue)
    }
    return @($found)
}

function Assert-LightORamaClosed {
    $running = @(Get-RunningLorProcesses)
    if ($running.Count -gt 0) {
        $processNames = @($running | Select-Object -ExpandProperty ProcessName -Unique) -join ', '
        throw (
            "Light-O-Rama is still running on this PC ($processNames).`r`n`r`n" +
            "Close Light-O-Rama and run the update again."
        )
    }
}

function Get-PreviewRecord {
    param(
        [Parameter(Mandatory=$true)][string]$Raw,
        [Parameter(Mandatory=$true)][string]$Source
    )

    $info = [MSBPreviewSemantic]::Parse($Raw, $Source)

    return [pscustomobject]@{
        PreviewId    = $info.PreviewId
        Name         = $info.Name
        Revision     = $info.Revision
        SemanticHash = $info.SemanticHash
        Raw          = $Raw
        Source       = $Source
    }
}

function Remove-XmlDeclaration {
    param([string]$Text)
    $withoutBom = $Text.TrimStart([char]0xFEFF)
    return [regex]::Replace($withoutBom, '^\s*<\?xml[^>]*\?>\s*', '', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase).Trim()
}

function Get-MasterRecords {
    param(
        [Parameter(Mandatory=$true)][string]$Folder,
        [AllowNull()]$ProgressWindow
    )

    if (-not (Test-Path -LiteralPath $Folder -PathType Container)) {
        throw "Master preview folder is not available on this PC:`r`n$Folder"
    }

    $files = @(Get-ChildItem -LiteralPath $Folder -Filter '*.lorprev' -File | Sort-Object Name)
    if ($files.Count -eq 0) {
        throw "No .lorprev files were found in the master folder:`r`n$Folder"
    }

    $sourceStateSha256 = [MSBSourceManifest]::Compute($Folder)
    $latestWriteUtc = ($files | Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 1).LastWriteTimeUtc

    $records = @{}
    $fileMap = @{}
    $fileRecords = @{}
    $index = 0

    foreach ($file in $files) {
        $index += 1
        if ($null -ne $ProgressWindow) {
            Set-StartupStatus -Window $ProgressWindow -Text (
                "Reading approved master preview {0} of {1}: {2}" -f $index, $files.Count, $file.Name
            )
        }

        # Read each controlled master file exactly once. The raw fragment is
        # retained for candidate construction and semantic comparison.
        $raw = Remove-XmlDeclaration (Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8)
        $record = Get-PreviewRecord -Raw $raw -Source ([string]$file.FullName)

        if ($records.ContainsKey($record.PreviewId)) {
            throw "Duplicate controlled PreviewID $($record.PreviewId) in master folder."
        }

        $key = $file.Name.ToLowerInvariant()
        $records[$record.PreviewId] = $record
        $fileMap[$key] = $file.FullName
        $fileRecords[$key] = $record
    }

    return [pscustomobject]@{
        Records           = $records
        Files             = $fileMap
        FileRecords       = $fileRecords
        Count             = $files.Count
        SourceStateSha256 = $sourceStateSha256
        LatestWriteUtc    = $latestWriteUtc
    }
}

function Test-MasterAgainstReport {
    param(
        [Parameter(Mandatory=$true)]$Report,
        [Parameter(Mandatory=$true)]$Master,
        [AllowNull()]$ProgressWindow
    )

    if ($Report.Rows.Count -ne $Master.Count) {
        throw "The master folder count does not match LOR2DB Run $($Report.RunId).`nReport: $($Report.Rows.Count)`nFolder: $($Master.Count)"
    }

    $reportNames = @{}
    foreach ($row in $Report.Rows) {
        $reportNames[$row.Filename.ToLowerInvariant()] = $row
    }

    $missing = @($reportNames.Keys | Where-Object { -not $Master.Files.ContainsKey($_) })
    $extra = @($Master.Files.Keys | Where-Object { -not $reportNames.ContainsKey($_) })

    if ($missing.Count -gt 0 -or $extra.Count -gt 0) {
        throw "The master folder file list does not match LOR2DB Run $($Report.RunId).`nMissing: $($missing -join ', ')`nExtra: $($extra -join ', ')"
    }

    $index = 0
    foreach ($row in $Report.Rows) {
        $index += 1
        if ($null -ne $ProgressWindow) {
            Set-StartupStatus -Window $ProgressWindow -Text (
                "Checking Run {0} evidence {1} of {2}: {3}" -f $Report.RunId, $index, $Report.Rows.Count, $row.Filename
            )
        }

        $key = $row.Filename.ToLowerInvariant()
        $record = $Master.FileRecords[$key]

        if ($null -eq $record) {
            throw "The parsed master record was not retained for $($row.Filename)."
        }

        if ($record.Name -ne $row.PreviewName) {
            throw "Preview name mismatch for $($row.Filename).`nReport: $($row.PreviewName)`nFile: $($record.Name)"
        }

        if ($record.Revision -ne $row.Revision) {
            throw "Revision mismatch for $($row.Filename).`r`nReport: $($row.Revision)`r`nFile: $($record.Revision)"
        }
    }

    # Newer report framework versions publish the parser's exact source-manifest
    # SHA-256. When present, this is the strongest source-integrity gate.
    if (-not [string]::IsNullOrWhiteSpace([string]$Report.SourceManifestSha256)) {
        if ($Master.SourceStateSha256 -ne $Report.SourceManifestSha256) {
            throw (
                "The live master folder no longer matches the exact source bytes accepted by LOR2DB Run $($Report.RunId).`r`n" +
                "Accepted manifest: $($Report.SourceManifestSha256)`r`n" +
                "Current manifest:  $($Master.SourceStateSha256)"
            )
        }
    }
    elseif ($null -ne $Report.GeneratedUtc) {
        # Legacy reports such as Run 32 predate publication of the source-manifest
        # digest. For those reports, block any .lorprev file modified after the
        # immutable report was generated. Filename/name/revision checks above are
        # still mandatory. Future reports use the exact digest gate instead.
        $latestAllowed = $Report.GeneratedUtc.AddMinutes(5)
        if ($Master.LatestWriteUtc -gt $latestAllowed) {
            throw (
                "The master preview folder contains a file modified after LOR2DB Run $($Report.RunId) was completed.`r`n`r`n" +
                "Latest master modification (UTC): $($Master.LatestWriteUtc.ToString('u'))`r`n" +
                "Run report generated (UTC):       $($Report.GeneratedUtc.ToString('u'))`r`n`r`n" +
                "Run a new LOR2DB parser/ingest/reconciliation before updating this PC."
            )
        }
    }
}

function Get-NewlineStyle {
    param([string]$Text)
    if ($Text.Contains("`r`n")) { return "`r`n" }
    return "`n"
}

function Add-IndentToFragment {
    param(
        [string]$Fragment,
        [string]$Indent,
        [string]$Newline
    )

    $normalized = $Fragment.Replace("`r`n", "`n").Replace("`r", "`n")
    $lines = $normalized -split "`n", -1

    if ($lines.Count -le 1) { return $Fragment }

    $result = @($lines[0])
    for ($i = 1; $i -lt $lines.Count; $i++) {
        $result += ($Indent + $lines[$i])
    }
    return ($result -join $Newline)
}

function Build-SyncCandidate {
    param(
        [Parameter(Mandatory=$true)]$MasterRecords,
        [Parameter(Mandatory=$true)][string]$LocalPath,
        [AllowNull()]$ProgressWindow
    )

    if (-not (Test-Path -LiteralPath $LocalPath -PathType Leaf)) {
        throw "Local LOR preview library was not found:`n$LocalPath"
    }

    $bytes = [System.IO.File]::ReadAllBytes($LocalPath)
    $hadBom = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
    $localText = [System.Text.Encoding]::UTF8.GetString($bytes)
    if ($hadBom -and $localText.Length -gt 0 -and $localText[0] -eq [char]0xFEFF) {
        $localText = $localText.Substring(1)
    }

    [xml]$parsedLocal = $localText
    $topLevelCount = @($parsedLocal.DocumentElement.ChildNodes | Where-Object { $_.LocalName -eq 'PreviewClass' }).Count

    $matches = [regex]::Matches($localText, $PreviewBlockPattern, $RegexOptions)
    if ($matches.Count -ne $topLevelCount) {
        throw "Preview scan mismatch in local LORPreviews.xml. Raw blocks=$($matches.Count), parsed top-level previews=$topLevelCount"
    }

    $localById = @{}
    foreach ($match in $matches) {
        $previewId = $match.Groups['id'].Value.ToLowerInvariant()
        if (-not $localById.ContainsKey($previewId)) {
            $localById[$previewId] = @()
        }
        $localById[$previewId] += [pscustomobject]@{
            Start = $match.Index
            End   = $match.Index + $match.Length
            Raw   = $match.Value
        }
    }

    foreach ($previewId in $MasterRecords.Keys) {
        if ($localById.ContainsKey($previewId) -and @($localById[$previewId]).Count -ne 1) {
            throw "Duplicate controlled PreviewID found locally: $previewId"
        }
    }

    $unmanagedIds = @($localById.Keys | Where-Object { -not $MasterRecords.ContainsKey($_) })
    $unmanagedBefore = @{}
    foreach ($previewId in $unmanagedIds) {
        $unmanagedBefore[$previewId] = @($localById[$previewId] | ForEach-Object { Get-Sha256String $_.Raw })
    }

    $newline = Get-NewlineStyle $localText
    $rows = @()
    $replacements = @()
    $additions = @()

    $approvedRecords = @($MasterRecords.Values | Sort-Object Name)
    $compareIndex = 0
    foreach ($approved in $approvedRecords) {
        $compareIndex += 1
        if ($null -ne $ProgressWindow) {
            Set-StartupStatus -Window $ProgressWindow -Text (
                "Comparing this PC with master preview {0} of {1}: {2}" -f $compareIndex, $approvedRecords.Count, $approved.Name
            )
        }

        $previewId = $approved.PreviewId

        if (-not $localById.ContainsKey($previewId)) {
            $rows += [pscustomobject]@{
                Action                 = 'ADD_IN_CANDIDATE'
                Preview_ID             = $previewId
                Approved_Name          = $approved.Name
                Local_Name             = ''
                Approved_Revision      = $approved.Revision
                Local_Revision         = ''
                Approved_Semantic_Hash = $approved.SemanticHash
                Local_Semantic_Hash    = ''
            }
            $additions += $approved.Raw
            continue
        }

        $block = @($localById[$previewId])[0]
        $localRecord = Get-PreviewRecord -Raw $block.Raw -Source $LocalPath

        if ($localRecord.SemanticHash -eq $approved.SemanticHash) {
            if ($localRecord.Revision -eq $approved.Revision) {
                $action = 'NOOP'
            }
            else {
                $action = 'NOOP_REVISION_ONLY'
            }
        }
        else {
            $action = 'REPLACE_IN_CANDIDATE'
            $lineStart = $localText.LastIndexOf("`n", [Math]::Max(0, $block.Start - 1)) + 1
            $indent = $localText.Substring($lineStart, $block.Start - $lineStart)
            $replacement = Add-IndentToFragment $approved.Raw $indent $newline
            $replacements += [pscustomobject]@{
                Start = $block.Start
                End = $block.End
                Raw = $replacement
            }
        }

        $rows += [pscustomobject]@{
            Action                 = $action
            Preview_ID             = $previewId
            Approved_Name          = $approved.Name
            Local_Name             = $localRecord.Name
            Approved_Revision      = $approved.Revision
            Local_Revision         = $localRecord.Revision
            Approved_Semantic_Hash = $approved.SemanticHash
            Local_Semantic_Hash    = $localRecord.SemanticHash
        }
    }

    $candidate = $localText

    foreach ($replacement in @($replacements | Sort-Object Start -Descending)) {
        $candidate = $candidate.Substring(0, $replacement.Start) + $replacement.Raw + $candidate.Substring($replacement.End)
    }

    if ($additions.Count -gt 0) {
        $close = [regex]::Match($candidate, '</root\s*>\s*$', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
        if (-not $close.Success) {
            throw 'Could not locate closing </root> while adding controlled previews.'
        }

        $first = [regex]::Match($candidate, $PreviewBlockPattern, $RegexOptions)
        if ($first.Success) {
            $lineStart = $candidate.LastIndexOf("`n", [Math]::Max(0, $first.Index - 1)) + 1
            $childIndent = $candidate.Substring($lineStart, $first.Index - $lineStart)
        }
        else {
            $childIndent = '  '
        }

        $inserted = ''
        foreach ($fragment in $additions) {
            $normalized = $fragment.Replace("`r`n", "`n").Replace("`r", "`n")
            $lines = $normalized -split "`n", -1
            $indented = @($childIndent + $lines[0])
            for ($i = 1; $i -lt $lines.Count; $i++) {
                $indented += ($childIndent + $lines[$i])
            }
            $inserted += ($indented -join $newline) + $newline
        }

        $candidate = $candidate.Substring(0, $close.Index) + $inserted + $candidate.Substring($close.Index)
    }

    # Validate the candidate after every change.
    [xml]$candidateXml = $candidate
    $candidateMatches = [regex]::Matches($candidate, $PreviewBlockPattern, $RegexOptions)
    $candidateById = @{}
    foreach ($match in $candidateMatches) {
        $previewId = $match.Groups['id'].Value.ToLowerInvariant()
        if (-not $candidateById.ContainsKey($previewId)) { $candidateById[$previewId] = @() }
        $candidateById[$previewId] += $match.Value
    }

    $candidateCheckIndex = 0
    foreach ($approved in $MasterRecords.Values) {
        $candidateCheckIndex += 1
        if ($null -ne $ProgressWindow -and (($candidateCheckIndex -eq 1) -or ($candidateCheckIndex % 5 -eq 0))) {
            Set-StartupStatus -Window $ProgressWindow -Text (
                "Verifying the safe merged result {0} of {1}..." -f $candidateCheckIndex, $MasterRecords.Count
            )
        }

        if (-not $candidateById.ContainsKey($approved.PreviewId)) {
            throw "Candidate is missing controlled PreviewID $($approved.PreviewId): $($approved.Name)"
        }
        if (@($candidateById[$approved.PreviewId]).Count -ne 1) {
            throw "Candidate contains duplicate controlled PreviewID $($approved.PreviewId): $($approved.Name)"
        }
        $candidateRecord = Get-PreviewRecord -Raw (@($candidateById[$approved.PreviewId])[0]) -Source 'candidate'
        if ($candidateRecord.SemanticHash -ne $approved.SemanticHash) {
            throw "Candidate controlled content does not match master: $($approved.Name)"
        }
    }

    $unmanagedAfter = @{}
    foreach ($previewId in $unmanagedIds) {
        if (-not $candidateById.ContainsKey($previewId)) {
            throw "Candidate lost unmanaged PreviewID $previewId"
        }
        $unmanagedAfter[$previewId] = @($candidateById[$previewId] | ForEach-Object { Get-Sha256String $_ })
    }

    foreach ($previewId in $unmanagedIds) {
        $before = @($unmanagedBefore[$previewId]) -join '|'
        $after = @($unmanagedAfter[$previewId]) -join '|'
        if ($before -ne $after) {
            throw "Candidate changed unmanaged PreviewID $previewId"
        }
    }

    return [pscustomobject]@{        Candidate      = $candidate
        HadBom         = $hadBom
        Rows           = $rows
        LocalCount     = $matches.Count
        UnmanagedCount = $unmanagedIds.Count
    }
}

function Write-CandidateFile {
    param($Build, [string]$Path)

    $data = [System.Text.Encoding]::UTF8.GetBytes($Build.Candidate)
    if ($Build.HadBom) {
        $bom = [byte[]](0xEF,0xBB,0xBF)
        $combined = New-Object byte[] ($bom.Length + $data.Length)
        [Array]::Copy($bom, 0, $combined, 0, $bom.Length)
        [Array]::Copy($data, 0, $combined, $bom.Length, $data.Length)
        $data = $combined
    }
    [System.IO.File]::WriteAllBytes($Path, $data)
}

function Write-ActionReport {
    param($Rows, [string]$Path)
    $Rows | Export-Csv -LiteralPath $Path -NoTypeInformation -Encoding UTF8
}

function Get-ActionCounts {
    param($Rows)
    return [pscustomobject]@{
        Noop = @($Rows | Where-Object Action -eq 'NOOP').Count
        RevisionOnly = @($Rows | Where-Object Action -eq 'NOOP_REVISION_ONLY').Count
        Replace = @($Rows | Where-Object Action -eq 'REPLACE_IN_CANDIDATE').Count
        Add = @($Rows | Where-Object Action -eq 'ADD_IN_CANDIDATE').Count
    }
}


function Set-StartupStatus {
    param(
        [Parameter(Mandatory=$true)]$Window,
        [Parameter(Mandatory=$true)][string]$Text
    )

    if ($null -ne $Window.Tag) {
        $Window.Tag.Text = $Text
    }

    $Window.Refresh()
    [System.Windows.Forms.Application]::DoEvents()
    Start-Sleep -Milliseconds 1
}


function Prepare-SyncWithStartup {
    $script:StartupPrepared = $null
    $script:StartupException = $null

    $form = New-Object System.Windows.Forms.Form
    $form.Text = 'Update your PC Previews to LOR Master Files'
    $form.StartPosition = 'CenterScreen'
    $form.Size = New-Object System.Drawing.Size(580, 215)
    $form.MinimumSize = $form.Size
    $form.MaximumSize = $form.Size
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false
    $form.FormBorderStyle = 'FixedDialog'
    $form.ShowInTaskbar = $true
    $form.Add_Shown({
        $this.TopMost = $true
        $this.Activate()
        $this.BringToFront()

        $bringForwardTimer = New-Object System.Windows.Forms.Timer
        $bringForwardTimer.Interval = 750
        $bringForwardTimer.Add_Tick({
            $this.Stop()
            $form.TopMost = $false
            $this.Dispose()
        })
        $bringForwardTimer.Start()
    })
    $form.TopMost = $true
    if ($null -ne $script:AppIcon) {
        $form.Icon = $script:AppIcon
    }

    $title = New-Object System.Windows.Forms.Label
    $title.Text = 'Starting MSB Preview Update...'
    $title.Font = New-Object System.Drawing.Font(
        'Segoe UI',
        15,
        [System.Drawing.FontStyle]::Bold
    )
    $title.AutoSize = $true
    $title.Location = New-Object System.Drawing.Point(24, 22)
    [void]$form.Controls.Add($title)

    $status = New-Object System.Windows.Forms.Label
    $status.Text = 'Starting...'
    $status.Font = New-Object System.Drawing.Font('Segoe UI', 10)
    $status.AutoSize = $false
    $status.Size = New-Object System.Drawing.Size(520, 48)
    $status.Location = New-Object System.Drawing.Point(26, 68)
    [void]$form.Controls.Add($status)

    $progress = New-Object System.Windows.Forms.ProgressBar
    $progress.Style = [System.Windows.Forms.ProgressBarStyle]::Marquee
    $progress.MarqueeAnimationSpeed = 28
    $progress.Location = New-Object System.Drawing.Point(28, 130)
    $progress.Size = New-Object System.Drawing.Size(510, 20)
    [void]$form.Controls.Add($progress)

    $form.Tag = $status

    $form.Add_Shown({
        try {
            $this.Activate()
            $this.BringToFront()
            [System.Windows.Forms.Application]::DoEvents()

            Set-StartupStatus -Window $this -Text 'Verifying the controlled MSB Preview Sync deployment...'
            $deployment = Test-DeploymentIdentity

            Set-StartupStatus -Window $this -Text 'Finding the latest published COMPLETED LOR2DB reconciliation...'
            $accepted = Get-LatestAcceptedReport -Folder $ReportArchive

            Set-StartupStatus -Window $this -Text (
                "Loading the approved LOR master preview set from Run {0}..." -f $accepted.RunId
            )
            $master = Get-MasterRecords -Folder ([string]$accepted.SourceFolder) -ProgressWindow $this

            Set-StartupStatus -Window $this -Text (
                "Checking the live master folder against frozen Run {0} evidence..." -f $accepted.RunId
            )
            Test-MasterAgainstReport -Report $accepted -Master $master -ProgressWindow $this

            Set-StartupStatus -Window $this -Text (
                "Comparing {0} controlled previews with this PC..." -f $master.Records.Count
            )
            $originalHash = Get-FileSha256 -Path $LocalXml
            $build = Build-SyncCandidate -MasterRecords $master.Records -LocalPath $LocalXml -ProgressWindow $this

            Set-StartupStatus -Window $this -Text 'Preparing and freezing the update review...'
            Write-CandidateFile -Build $build -Path $CandidateXml
            Write-ActionReport -Rows $build.Rows -Path $CandidateCsv
            $candidateHash = Get-FileSha256 -Path $CandidateXml

            $script:StartupPrepared = [pscustomobject]@{
                Accepted       = $accepted
                ReportHash     = Get-FileSha256 -Path $accepted.Path
                Master         = $master
                Build          = $build
                Deployment     = $deployment
                OriginalHash   = $originalHash
                CandidateHash  = $candidateHash
                SourceStateHash = $master.SourceStateSha256
            }
        }
        catch {
            $script:StartupException = $_
        }
        finally {
            $this.Hide()
            [System.Windows.Forms.Application]::DoEvents()
            $this.Close()
        }
    })

    [void]$form.ShowDialog()
    $form.Dispose()

    if ($null -ne $script:StartupException) {
        throw $script:StartupException
    }

    if ($null -eq $script:StartupPrepared) {
        throw 'The startup preparation did not return a sync result.'
    }

    return $script:StartupPrepared
}


function Show-ReviewDialog {
    param(
        [Parameter(Mandatory=$true)]$AcceptedReport,
        [Parameter(Mandatory=$true)]$Build
    )

    $counts = Get-ActionCounts $Build.Rows
    $changed = @($Build.Rows | Where-Object { $_.Action -in @('REPLACE_IN_CANDIDATE','ADD_IN_CANDIDATE') })

    $form = New-Object System.Windows.Forms.Form
    $form.Text = 'Update your PC Previews to LOR Master Files'
    $form.StartPosition = 'CenterScreen'
    $form.Size = New-Object System.Drawing.Size(760, 640)
    $form.MinimumSize = New-Object System.Drawing.Size(700, 560)

    $form.ShowInTaskbar = $true
    if ($null -ne $script:AppIcon) {
        $form.Icon = $script:AppIcon
    }
    $title = New-Object System.Windows.Forms.Label
    $title.Text = 'MSB LOR Preview Update'
    $title.Font = New-Object System.Drawing.Font('Segoe UI', 16, [System.Drawing.FontStyle]::Bold)
    $title.AutoSize = $true
    $title.Location = New-Object System.Drawing.Point(18, 16)
    $form.Controls.Add($title)

    $summary = New-Object System.Windows.Forms.Label
    $summary.Text = (
        "Accepted LOR2DB Run: {0}`r`nMaster source: {1}`r`n`r`n" +
        "Controlled previews: {2}`r`nAlready current: {3}`r`n" +
        "Revision-only differences (no action): {4}`r`n" +
        "Will be replaced: {5}`r`nWill be added: {6}`r`n" +
        "Personal/unmanaged previews preserved: {7}"
    ) -f $AcceptedReport.RunId, $AcceptedReport.SourceFolder, $Build.Rows.Count, $counts.Noop, $counts.RevisionOnly, $counts.Replace, $counts.Add, $Build.UnmanagedCount
    $summary.AutoSize = $true
    $summary.Location = New-Object System.Drawing.Point(20, 55)
    $summary.Font = New-Object System.Drawing.Font('Segoe UI', 10)
    $form.Controls.Add($summary)

    $listLabel = New-Object System.Windows.Forms.Label
    $listLabel.Text = 'Controlled MSB previews that will change:'
    $listLabel.AutoSize = $true
    $listLabel.Location = New-Object System.Drawing.Point(20, 195)
    $listLabel.Font = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)
    $form.Controls.Add($listLabel)

    $box = New-Object System.Windows.Forms.TextBox
    $box.Multiline = $true
    $box.ReadOnly = $true
    $box.ScrollBars = 'Vertical'
    $box.Font = New-Object System.Drawing.Font('Consolas', 9)
    $box.Location = New-Object System.Drawing.Point(20, 220)
    $box.Size = New-Object System.Drawing.Size(700, 230)
    $box.Anchor = 'Top,Left,Right,Bottom'

    if ($changed.Count -eq 0) {
        $box.Text = 'No controlled MSB previews need to be added or replaced.'
    }
    else {
        $lines = @()
        foreach ($row in $changed) {
            if ($row.Action -eq 'ADD_IN_CANDIDATE') {
                $lines += "ADD      $($row.Approved_Name)"
            }
            else {
                $lines += "REPLACE  $($row.Approved_Name)    local rev $($row.Local_Revision) -> master rev $($row.Approved_Revision)"
            }
        }
        $box.Text = $lines -join "`r`n"
    }
    $form.Controls.Add($box)

    $closedCheck = New-Object System.Windows.Forms.CheckBox
    $closedCheck.Text = 'I have closed Light-O-Rama on this PC.'
    $closedCheck.AutoSize = $true
    $closedCheck.Location = New-Object System.Drawing.Point(22, 470)
    $closedCheck.Anchor = 'Left,Bottom'
    $form.Controls.Add($closedCheck)

    $overwriteCheck = New-Object System.Windows.Forms.CheckBox
    $overwriteCheck.Text = 'I understand that different local MSB previews listed above will be replaced by the approved master. A backup will be created first.'
    $overwriteCheck.AutoSize = $false
    $overwriteCheck.Size = New-Object System.Drawing.Size(690, 45)
    $overwriteCheck.Location = New-Object System.Drawing.Point(22, 500)
    $overwriteCheck.Anchor = 'Left,Right,Bottom'
    if ($counts.Replace -eq 0) {
        $overwriteCheck.Checked = $true
        $overwriteCheck.Enabled = $false
    }
    $form.Controls.Add($overwriteCheck)

    $cancel = New-Object System.Windows.Forms.Button
    $cancel.Text = 'Cancel'
    $cancel.Size = New-Object System.Drawing.Size(110, 34)
    $cancel.Location = New-Object System.Drawing.Point(480, 550)
    $cancel.Anchor = 'Right,Bottom'
    $cancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $form.Controls.Add($cancel)

    $update = New-Object System.Windows.Forms.Button
    $update.Text = 'Update PC Previews'
    $update.Size = New-Object System.Drawing.Size(140, 34)
    $update.Location = New-Object System.Drawing.Point(600, 550)
    $update.Anchor = 'Right,Bottom'
    $update.Enabled = $false
    $form.Controls.Add($update)

    $refreshButton = {
        $update.Enabled = ($closedCheck.Checked -and $overwriteCheck.Checked)
    }
    $closedCheck.add_CheckedChanged($refreshButton)
    $overwriteCheck.add_CheckedChanged($refreshButton)
    & $refreshButton

    $update.Add_Click({
        $form.Tag = 'APPLY'
        $form.Close()
    })

    $form.AcceptButton = $update
    $form.CancelButton = $cancel
    [void]$form.ShowDialog()

    return ($form.Tag -eq 'APPLY')
}

function Install-Candidate {
    param(
        [Parameter(Mandatory=$true)][string]$CandidatePath,
        [Parameter(Mandatory=$true)][string]$LivePath,
        [Parameter(Mandatory=$true)][string]$ExpectedOriginalHash,
        [Parameter(Mandatory=$true)][string]$ExpectedCandidateHash
    )

    if ((Get-FileSha256 -Path $LivePath) -ne $ExpectedOriginalHash) {
        throw 'The local LOR preview library changed after the review was prepared. Nothing was installed. Close LOR and run the updater again.'
    }
    if ((Get-FileSha256 -Path $CandidatePath) -ne $ExpectedCandidateHash) {
        throw 'The reviewed MSB preview candidate changed after the review was prepared. Nothing was installed. Run the updater again.'
    }

    $stamp = Get-Date -Format 'yyyyMMdd-HHmmssfff'
    $backupFolder = Join-Path (Split-Path -Parent $LivePath) 'MSB_Preview_Sync_Backups'
    New-Item -ItemType Directory -Path $backupFolder -Force | Out-Null

    $backup = Join-Path $backupFolder ("LORPreviews.before-msb-sync-{0}.xml" -f $stamp)
    $installing = "$LivePath.msb-sync-installing-$stamp"
    Copy-Item -LiteralPath $CandidatePath -Destination $installing -Force

    $installingHash = Get-FileSha256 -Path $installing
    if ($installingHash -ne $ExpectedCandidateHash) {
        Remove-Item -LiteralPath $installing -Force -ErrorAction SilentlyContinue
        throw 'The staged installation copy does not match the reviewed candidate. Nothing was installed.'
    }

    try {
        [System.IO.File]::Replace($installing, $LivePath, $backup)
    }
    catch {
        if (Test-Path -LiteralPath $installing) {
            Remove-Item -LiteralPath $installing -Force -ErrorAction SilentlyContinue
        }
        throw
    }

    # File.Replace captured the exact displaced original. If a race occurred
    # between the final precheck and replacement, restore those displaced bytes.
    $backupHash = Get-FileSha256 -Path $backup
    if ($backupHash -ne $ExpectedOriginalHash) {
        Copy-Item -LiteralPath $backup -Destination $LivePath -Force
        throw (
            "The local LOR preview library changed during installation. The displaced file was restored.`r`n" +
            "Expected original: $ExpectedOriginalHash`r`nCaptured original: $backupHash"
        )
    }

    $installedHash = Get-FileSha256 -Path $LivePath
    if ($installedHash -ne $ExpectedCandidateHash) {
        Copy-Item -LiteralPath $backup -Destination $LivePath -Force
        throw (
            "Installed preview-library verification failed. The original file was restored.`r`n" +
            "Expected installed: $ExpectedCandidateHash`r`nActual installed:   $installedHash"
        )
    }

    return [pscustomobject]@{
        BackupPath    = $backup
        BackupHash    = $backupHash
        InstalledHash = $installedHash
    }
}

function Write-SharedLog {
    param(
        $Report,
        $Build,
        [string]$Result,
        [string]$Backup = '',
        [string]$SourceStateHash = '',
        [string]$OriginalHash = '',
        [string]$CandidateHash = '',
        [string]$InstalledHash = ''
    )

    New-Item -ItemType Directory -Path $LogFolder -Force | Out-Null
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $safeUser = ($env:USERNAME -replace '[^A-Za-z0-9_.-]', '_')
    $safeComputer = ($env:COMPUTERNAME -replace '[^A-Za-z0-9_.-]', '_')
    $path = Join-Path $LogFolder ("sync-{0}-{1}-{2}.txt" -f $safeComputer, $safeUser, $stamp)
    $counts = Get-ActionCounts $Build.Rows

    @(
        'MSB LOR Preview Sync'
        "Application version: $ApplicationVersion"
        "Timestamp: $(Get-Date -Format o)"
        "Computer: $env:COMPUTERNAME"
        "User: $env:USERNAME"
        "Result: $Result"
        "LOR2DB Run: $($Report.RunId)"
        "Published report: $($Report.Path)"
        "Master folder: $($Report.SourceFolder)"
        "Frozen source manifest: $($Report.SourceManifestSha256)"
        "Observed source state: $SourceStateHash"
        "Controlled previews: $($Build.Rows.Count)"
        "NOOP: $($counts.Noop)"
        "Revision-only: $($counts.RevisionOnly)"
        "Replaced: $($counts.Replace)"
        "Added: $($counts.Add)"
        "Unmanaged/personal preserved: $($Build.UnmanagedCount)"
        "Original local SHA-256: $OriginalHash"
        "Candidate SHA-256: $CandidateHash"
        "Installed SHA-256: $InstalledHash"
        "Backup: $Backup"
    ) | Set-Content -LiteralPath $path -Encoding UTF8

    return $path
}

try {
    $prepared = Prepare-SyncWithStartup
    $accepted = $prepared.Accepted
    $master = $prepared.Master
    $build = $prepared.Build
    $counts = Get-ActionCounts -Rows $build.Rows

    if ($counts.Replace -eq 0 -and $counts.Add -eq 0) {
        $logPath = Write-SharedLog -Report $accepted -Build $build -Result 'CURRENT' `
            -SourceStateHash $prepared.SourceStateHash -OriginalHash $prepared.OriginalHash `
            -CandidateHash $prepared.CandidateHash
        Show-Message (
            "Your MSB previews are already current.`r`n`r`n" +
            "Accepted LOR2DB Run: $($accepted.RunId)`r`n" +
            "Master source: $($accepted.SourceFolder)`r`n" +
            "Controlled previews: $($build.Rows.Count)`r`n" +
            "Revision-only differences ignored: $($counts.RevisionOnly)`r`n" +
            "Personal/unmanaged previews preserved: $($build.UnmanagedCount)"
        ) 'Update your PC Previews to LOR Master Files' ([System.Windows.Forms.MessageBoxIcon]::Information)
        exit 0
    }

    if ($AuditOnly) {
        $null = Write-SharedLog -Report $accepted -Build $build -Result 'AUDIT_ONLY' `
            -SourceStateHash $prepared.SourceStateHash -OriginalHash $prepared.OriginalHash `
            -CandidateHash $prepared.CandidateHash
        Show-Message (
            "Your PC needs an MSB preview update.`r`n`r`n" +
            "Accepted LOR2DB Run: $($accepted.RunId)`r`n" +
            "Will replace: $($counts.Replace)`r`n" +
            "Will add: $($counts.Add)`r`n" +
            "Personal/unmanaged previews preserved: $($build.UnmanagedCount)`r`n`r`n" +
            "Audit-only mode did not change your PC."
        ) 'MSB Preview Audit' ([System.Windows.Forms.MessageBoxIcon]::Warning)
        exit 0
    }

    $approved = Show-ReviewDialog -AcceptedReport $accepted -Build $build
    if (-not $approved) {
        $null = Write-SharedLog -Report $accepted -Build $build -Result 'CANCELLED' `
            -SourceStateHash $prepared.SourceStateHash -OriginalHash $prepared.OriginalHash `
            -CandidateHash $prepared.CandidateHash
        exit 0
    }

    # Recheck every moving boundary immediately before the write. A new
    # reconciliation, source edit, local LOR save or candidate edit invalidates
    # the review instead of silently installing stale work.
    Test-DeploymentIdentity | Out-Null
    Assert-LightORamaClosed

    $latestNow = Get-LatestAcceptedReport -Folder $ReportArchive
    if ($latestNow.RunId -ne $accepted.RunId) {
        throw (
            "A newer accepted LOR2DB reconciliation became available while this review was open.`r`n`r`n" +
            "Reviewed Run: $($accepted.RunId)`r`nLatest Run:   $($latestNow.RunId)`r`n`r`n" +
            "Run the updater again so the PC uses the newest accepted source."
        )
    }
    if ($latestNow.SourceFolder -ne $accepted.SourceFolder) {
        throw 'The accepted master-source folder changed while this review was open. Run the updater again.'
    }
    if ((Get-FileSha256 -Path $accepted.Path) -ne $prepared.ReportHash) {
        throw 'The immutable LOR2DB report changed while this review was open. Nothing was installed.'
    }

    $sourceStateNow = [MSBSourceManifest]::Compute($accepted.SourceFolder)
    if ($sourceStateNow -ne $prepared.SourceStateHash) {
        throw (
            "The controlled LOR master folder changed while this review was open.`r`n`r`n" +
            "Nothing was installed. Run LOR2DB if the change is intentional, then run this updater again."
        )
    }

    if ((Get-FileSha256 -Path $LocalXml) -ne $prepared.OriginalHash) {
        throw 'The local LOR preview library changed while this review was open. Nothing was installed. Close LOR and run the updater again.'
    }
    if ((Get-FileSha256 -Path $CandidateXml) -ne $prepared.CandidateHash) {
        throw 'The reviewed candidate changed while this review was open. Nothing was installed. Run the updater again.'
    }

    $install = Install-Candidate -CandidatePath $CandidateXml -LivePath $LocalXml `
        -ExpectedOriginalHash $prepared.OriginalHash -ExpectedCandidateHash $prepared.CandidateHash

    $logPath = Write-SharedLog -Report $accepted -Build $build -Result 'APPLIED' `
        -Backup $install.BackupPath -SourceStateHash $prepared.SourceStateHash `
        -OriginalHash $prepared.OriginalHash -CandidateHash $prepared.CandidateHash `
        -InstalledHash $install.InstalledHash

    Show-Message (
        "MSB preview update completed successfully.`r`n`r`n" +
        "Controlled previews updated from LOR2DB Run $($accepted.RunId).`r`n" +
        "Replaced: $($counts.Replace)`r`n" +
        "Added: $($counts.Add)`r`n" +
        "Personal/unmanaged previews preserved: $($build.UnmanagedCount)`r`n`r`n" +
        "Backup created:`r`n$($install.BackupPath)`r`n`r`n" +
        "You may open Light-O-Rama now."
    ) 'Update Complete' ([System.Windows.Forms.MessageBoxIcon]::Information)
}

catch {
    $message = $_.Exception.Message
    try {
        New-Item -ItemType Directory -Path $LogFolder -Force | Out-Null
        $detailPath = Join-Path $LogFolder 'powershell-error-latest.log'
        @(
            "MSB Preview Update PowerShell diagnostic"
            "Timestamp: $(Get-Date -Format o)"
            "Message: $message"
            "Exception: $($_.Exception.GetType().FullName)"
            "Position: $($_.InvocationInfo.PositionMessage)"
            "Stack: $($_.ScriptStackTrace)"
        ) | Set-Content -LiteralPath $detailPath -Encoding UTF8
    }
    catch {
        $detailPath = Join-Path $Root 'powershell-error-latest.log'
    }

    Show-Message (
        "The MSB preview update was BLOCKED.`r`n`r`n$message`r`n`r`n" +
        "Nothing was intentionally changed.`r`n`r`nDiagnostic log:`r`n$detailPath"
    ) 'MSB Preview Update Blocked' ([System.Windows.Forms.MessageBoxIcon]::Error)
    # Exit code 20 means the PowerShell program already displayed the operator error.
    # The hidden launcher must not show a second duplicate error dialog.
    exit 20
}