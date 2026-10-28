# MSB LOR Preview Sync - Production Candidate v1.0.9
# Programmer-facing MASTER -> LOCAL synchronization tool.
#
# Normal operators launch this through:
#   Update your PC Previews to LOR Master Files (Windows shortcut)
#
# The script:
# - gets the latest COMPLETED source through the authenticated LOR2PC browser handoff;
# - validates the exact versioned master folder recorded by that report and blocks post-run source drift;
# - compares controlled previews by PreviewClass.id and substantive content;
# - preserves root background brightness/selected scene; ignores revision-only differences;
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
    [string]$CurrentSourceUrl = 'https://my.sheboyganlights.org/lor2db/preflight/api/current-source',
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
# same comparison contract as the original PowerShell code: root Revision and local viewing preferences are
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
    // PC comparison only. Accepted-source byte digest never uses this exclusion.
    // Match exact unqualified preference attributes; never ignore descendant
    // brightness/output fields, scene definitions, or prop dimming settings.
    private static bool IsLocalMetadata(XmlAttribute attr)
    {
        return String.Equals(attr.Name, "Revision", StringComparison.OrdinalIgnoreCase) ||
            attr.Name == "Brightness" || attr.Name == "LastSelectedSceneId";
    }

    public static string PresentationDetails(string local, string master)
    {
        XmlElement before = ReadReview(local), after = ReadReview(master);
        List<string> notes = new List<string>();
        foreach (string name in new string[] { "Brightness", "LastSelectedSceneId" }) {
            if (before.HasAttribute(name) != after.HasAttribute(name) || before.GetAttribute(name) != after.GetAttribute(name))
                notes.Add(name + ": PC " + (before.HasAttribute(name) ? ReviewValue(before.GetAttribute(name)) : "(absent)") +
                    "; master " + (after.HasAttribute(name) ? ReviewValue(after.GetAttribute(name)) : "(absent)") + "; local preference preserved.");
        }
        return String.Join(Environment.NewLine, notes.ToArray());
    }

    public static string PreservePresentation(string local, string master)
    {
        XmlElement before = ReadReview(local), after = ReadReview(master);
        if (before.GetAttribute("id") != after.GetAttribute("id"))
            throw new InvalidOperationException("Cannot merge preferences across different PreviewIDs.");
        foreach (string name in new string[] { "Brightness", "LastSelectedSceneId" }) {
            if (before.HasAttribute(name)) after.SetAttribute(name, before.GetAttribute(name));
            else after.RemoveAttribute(name);
        }
        string result = after.OuterXml;
        if (Parse(result, "preference merge").SemanticHash != Parse(master, "accepted merge").SemanticHash)
            throw new InvalidOperationException("Preference merge changed controlled content.");
        return result;
    }

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
                if (isRoot && IsLocalMetadata(attr))
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

    private static XmlElement ReadReview(string raw)
    {
        XmlDocument doc = new XmlDocument();
        doc.PreserveWhitespace = true;
        doc.XmlResolver = null;
        XmlReaderSettings settings = new XmlReaderSettings();
        settings.DtdProcessing = DtdProcessing.Prohibit;
        using (XmlReader reader = XmlReader.Create(new System.IO.StringReader(raw), settings))
            doc.Load(reader);
        return doc.DocumentElement;
    }

    private static string ReviewLabel(XmlElement node)
    {
        if (node.LocalName == "PropClass" && !String.IsNullOrWhiteSpace(node.GetAttribute("Comment")))
            return "Display " + node.GetAttribute("Comment");
        string name = node.GetAttribute("Name");
        return String.IsNullOrEmpty(name) ? node.LocalName : name;
    }

    private static SortedDictionary<string, XmlElement> ReviewChildren(XmlElement node)
    {
        SortedDictionary<string, XmlElement> children = new SortedDictionary<string, XmlElement>(StringComparer.Ordinal);
        Dictionary<string, int> seen = new Dictionary<string, int>(StringComparer.Ordinal);
        foreach (XmlNode child in node.ChildNodes)
        {
            XmlElement element = child as XmlElement;
            if (element == null) continue;
            string id = "";
            foreach (XmlAttribute attr in element.Attributes)
                if (String.Equals(attr.LocalName, "id", StringComparison.OrdinalIgnoreCase)) id = attr.Value;
            string key = element.Name + (id.Length == 0 ? "" : "[" + id + "]");
            int count;
            seen.TryGetValue(key, out count);
            seen[key] = count + 1;
            // Repeated identities/unnamed children are matched by occurrence;
            // this affects explanation only, never identity/content authority.
            children.Add(key + "#" + count, element);
        }
        return children;
    }

    private static SortedDictionary<string, string> ReviewAttributes(XmlElement node, bool root)
    {
        SortedDictionary<string, string> result = new SortedDictionary<string, string>(StringComparer.Ordinal);
        foreach (XmlAttribute attr in node.Attributes)
            if (!(root && IsLocalMetadata(attr)))
                result.Add(attr.Name, attr.Value);
        return result;
    }

    private static string ReviewValue(string value)
    {
        // Escape control characters so values cannot forge extra review lines.
        return value == null ? "(absent)" : "\"" + value.Replace("\\", "\\\\").Replace("\r", "\\r").Replace("\n", "\\n").Replace("\t", "\\t").Replace("\"", "\\\"") + "\"";
    }

    private static string ReviewText(XmlElement node)
    {
        StringBuilder result = new StringBuilder();
        foreach (XmlNode child in node.ChildNodes)
            if ((child.NodeType == XmlNodeType.Text || child.NodeType == XmlNodeType.CDATA) && !String.IsNullOrWhiteSpace(child.Value))
                AddToken(result, "T", child.Value);
        return result.ToString();
    }

    private static void DescribeItem(XmlElement item, string path, string action, List<string> lines, bool unified = false)
    {
        string prefix = unified ? (action == "Added item" ? "+ " : "- ") : "";
        lines.Add(prefix + action + ": " + path);
        foreach (KeyValuePair<string, string> attr in ReviewAttributes(item, false))
            lines.Add(prefix + "  " + attr.Key + " = " + ReviewValue(attr.Value));
        string text = ReviewText(item);
        if (text.Length > 0) lines.Add(prefix + "  Content = " + ReviewValue(text));
        foreach (XmlNode child in item.ChildNodes)
        {
            XmlElement element = child as XmlElement;
            if (element != null) DescribeItem(element, path + " / " + ReviewValue(ReviewLabel(element)), action, lines, unified);
        }
    }

    private static void CompareReview(XmlElement local, XmlElement master, string path, bool root, List<string> lines, bool unified = false)
    {
        SortedDictionary<string, string> before = ReviewAttributes(local, root), after = ReviewAttributes(master, root);
        SortedSet<string> attrs = new SortedSet<string>(before.Keys, StringComparer.Ordinal);
        attrs.UnionWith(after.Keys);
        foreach (string key in attrs)
        {
            string oldValue, newValue;
            before.TryGetValue(key, out oldValue); after.TryGetValue(key, out newValue);
            if (!String.Equals(oldValue, newValue, StringComparison.Ordinal)) {
                if (unified) {
                    lines.Add("- " + path + " / " + key + " = " + ReviewValue(oldValue));
                    lines.Add("+ " + path + " / " + key + " = " + ReviewValue(newValue));
                } else lines.Add("Changed: " + path + " / " + key + ": " + ReviewValue(oldValue) + " -> " + ReviewValue(newValue));
            }
        }
        string oldText = ReviewText(local), newText = ReviewText(master);
        if (oldText != newText) {
            if (unified) { lines.Add("- Content: " + path + " = " + ReviewValue(oldText)); lines.Add("+ Content: " + path + " = " + ReviewValue(newText)); }
            else lines.Add("Changed content: " + path + ": " + ReviewValue(oldText) + " -> " + ReviewValue(newText));
        }
        SortedDictionary<string, XmlElement> oldChildren = ReviewChildren(local), newChildren = ReviewChildren(master);
        SortedSet<string> keys = new SortedSet<string>(oldChildren.Keys, StringComparer.Ordinal);
        keys.UnionWith(newChildren.Keys);
        foreach (string key in keys)
        {
            XmlElement oldChild, newChild;
            bool had = oldChildren.TryGetValue(key, out oldChild), has = newChildren.TryGetValue(key, out newChild);
            string label = path + " / " + ReviewValue(ReviewLabel(has ? newChild : oldChild));
            if (!had) DescribeItem(newChild, label, "Added item", lines, unified);
            else if (!has) DescribeItem(oldChild, label, "Removed item", lines, unified);
            else CompareReview(oldChild, newChild, label, false, lines, unified);
        }
        // Hash authority includes child order; ID matching above must not hide it.
        List<string> oldOrder = new List<string>(), newOrder = new List<string>();
        foreach (XmlNode child in local.ChildNodes) if (child is XmlElement) { StringBuilder b = new StringBuilder(); AddNode(child, b, false); oldOrder.Add(Sha256(b.ToString())); }
        foreach (XmlNode child in master.ChildNodes) if (child is XmlElement) { StringBuilder b = new StringBuilder(); AddNode(child, b, false); newOrder.Add(Sha256(b.ToString())); }
        if (oldOrder.Count == newOrder.Count && String.Join("|", oldOrder.ToArray()) != String.Join("|", newOrder.ToArray()))
        {
            oldOrder.Sort(StringComparer.Ordinal); newOrder.Sort(StringComparer.Ordinal);
            if (String.Join("|", oldOrder.ToArray()) == String.Join("|", newOrder.ToArray()))
                lines.Add("Changed item order: " + path);
        }
    }

    public static string DescribeChanges(string local, string master)
    {
        List<string> lines = new List<string>();
        CompareReview(ReadReview(local), ReadReview(master), "Preview", true, lines);
        if (lines.Count == 0 && Parse(local, "local review").SemanticHash != Parse(master, "master review").SemanticHash)
            throw new InvalidOperationException("Content differs but review could not explain the difference. Update blocked.");
        return String.Join(Environment.NewLine, lines.ToArray());
    }

    private static string PropSignature(XmlElement root, params string[] attributes)
    {
        List<string> records = new List<string>();
        foreach (XmlNode child in root.SelectNodes(".//PropClass")) {
            XmlElement node = (XmlElement)child;
            StringBuilder b = new StringBuilder();
            AddToken(b, "id", node.GetAttribute("id"));
            foreach (string attr in attributes) if (node.HasAttribute(attr)) AddToken(b, attr, node.GetAttribute(attr));
            records.Add(b.ToString());
        }
        records.Sort(StringComparer.Ordinal);
        return String.Join("|", records.ToArray());
    }

    private static string SceneSignature(XmlElement root)
    {
        StringBuilder result = new StringBuilder(); string scene = "";
        foreach (XmlNode child in root.SelectNodes(".//*")) {
            XmlElement node = (XmlElement)child;
            if (node.LocalName.EndsWith("Scene", StringComparison.Ordinal)) {
                scene = node.GetAttribute("id");
                AddToken(result, "Scene", scene); AddToken(result, "Name", node.GetAttribute("Name"));
                foreach (KeyValuePair<string,string> attr in ReviewAttributes(node,false)) AddToken(result,attr.Key,attr.Value);
            } else if (node.LocalName == "PropClass" && scene.Length > 0) {
                AddToken(result, "Member", scene + ":" + node.GetAttribute("id"));
            }
        }
        return result.ToString();
    }

    public static string ImpactNotes(string local, string master)
    {
        XmlElement before = ReadReview(local), after = ReadReview(master);
        List<string> notes = new List<string>();
        if (before.GetAttribute("id") != after.GetAttribute("id") || before.GetAttribute("Name") != after.GetAttribute("Name")) notes.Add("Preview UUID / name");
        if (PropSignature(before) != PropSignature(after)) notes.Add("Prop UUIDs");
        if (PropSignature(before,"Comment") != PropSignature(after,"Comment")) notes.Add("Display names (Comment) / prop associations");
        if (SceneSignature(before) != SceneSignature(after)) notes.Add("Scenes / scene membership");
        if (PropSignature(before,"ChannelGrid","Name","DeviceType","StringType","DimmingCurveName","MasterPropId","Parm1") !=
            PropSignature(after,"ChannelGrid","Name","DeviceType","StringType","DimmingCurveName","MasterPropId","Parm1"))
            notes.Add("Wiring / channel names / device / string or master-link settings");
        if (notes.Count == 0) notes.Add("No changes detected in the identity, scene or wiring fields checked here. Inspect the full diff for other content changes.");
        return String.Join("; ", notes.ToArray());
    }

    public static string UnifiedDiff(string local, string master)
    {
        MSBPreviewInfo before = Parse(local, "local diff"), after = Parse(master, "master diff");
        List<string> lines = new List<string>();
        if (before.Revision != after.Revision) {
            lines.Add("- Preview Revision = " + ReviewValue(before.Revision));
            lines.Add("+ Preview Revision = " + ReviewValue(after.Revision));
        }
        if (before.SemanticHash != after.SemanticHash)
            CompareReview(ReadReview(local), ReadReview(master), "Preview", true, lines, true);
        return String.Join(Environment.NewLine, lines.ToArray());
    }

    public static string MatchMasterRevision(string local, string master)
    {
        MSBPreviewInfo before = Parse(local, "local revision"), accepted = Parse(master, "master revision");
        if (before.PreviewId != accepted.PreviewId || before.SemanticHash != accepted.SemanticHash)
            throw new InvalidOperationException("Revision alignment requires identical preview identity and content.");
        if (!System.Text.RegularExpressions.Regex.IsMatch(accepted.Revision, "^[0-9]+$"))
            throw new InvalidOperationException("Master Revision is not a usable numeric value.");
        XmlElement node = ReadReview(local);
        node.SetAttribute("Revision", accepted.Revision);
        string result = node.OuterXml;
        MSBPreviewInfo verified = Parse(result, "aligned revision");
        if (verified.PreviewId != before.PreviewId || verified.SemanticHash != before.SemanticHash || verified.Revision != accepted.Revision)
            throw new InvalidOperationException("Revision alignment changed substantive preview content.");
        return result;
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
using System.Collections.Generic;
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
        Dictionary<string,string> hashes = new Dictionary<string,string>();
        foreach (string path in Directory.GetFiles(folder, "*.lorprev", SearchOption.TopDirectoryOnly))
            hashes.Add(Path.GetFileName(path), Sha256File(path));
        return ComputeCaptured(hashes);
    }

    public static string ComputeCaptured(Dictionary<string,string> hashes)
    {
        string[] files = new List<string>(hashes.Keys).ToArray();
        // Python parser sorts by Unicode casefold. Limit this implementation to
        // ASCII filenames until cross-runtime Unicode ordering is proven.
        foreach (string name in files)
            foreach (char ch in name)
                if (ch > 127) throw new InvalidOperationException("Non-ASCII source filename requires supported canonical ordering.");
        Array.Sort(files, StringComparer.OrdinalIgnoreCase);

        StringBuilder payload = new StringBuilder();
        payload.Append('[');
        for (int index = 0; index < files.Length; index++)
        {
            if (index > 0) payload.Append(',');
            payload.Append("{\"filename\":");
            payload.Append(JsonString(Path.GetFileName(files[index])));
            payload.Append(",\"sha256\":\"");
            payload.Append(hashes[files[index]]);
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
$ApplicationVersion = '1.0.9'
$ApplicationReleaseDate = '2026-10-28'
$script:SessionLogPath = $null
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

function Invoke-SyncEvents {
    [Windows.Forms.Application]::DoEvents()
}

function Write-HandoffTrace {
    param([string]$Event, [int]$Port = 0, [string]$Reason = '', [string]$ExceptionType = '', [int]$SourceLine = 0)
    # Fixed event/reason codes only: never record nonce, URL, headers, cookies,
    # source document, email or credentials. Preserve evidence across attempts.
    [void][IO.Directory]::CreateDirectory($LogFolder)
    $record = [ordered]@{ timestamp = [DateTime]::UtcNow.ToString('o'); event = $Event; port = $Port; reason = $Reason; exception_type = $ExceptionType; line = $SourceLine }
    $line = ($record | ConvertTo-Json -Compress) + [Environment]::NewLine
    [IO.File]::AppendAllText((Join-Path $LogFolder 'browser-handoff.log'), $line, (New-Object Text.UTF8Encoding($false)))
}

function Receive-BrowserSource {
    $listener = New-Object Net.Sockets.TcpListener([Net.IPAddress]::Loopback, 0)
    $listener.Start()
    $port = $listener.LocalEndpoint.Port
    $nonce = [guid]::NewGuid().ToString('N') + [guid]::NewGuid().ToString('N')
    $origin = 'https://my.sheboyganlights.org'
    $deadline = [DateTime]::UtcNow.AddSeconds(120)
    $connections = 0; $preflights = 0; $rejections = 0
    try {
        Write-HandoffTrace -Event 'LISTENING' -Port $port
        Start-Process ($origin + '/lor2db/pc/#port=' + $port + '&nonce=' + $nonce)
        while ([DateTime]::UtcNow -lt $deadline) {
            Invoke-SyncEvents
            if (-not $listener.Pending()) { Start-Sleep -Milliseconds 100; continue }
            $client = $listener.AcceptTcpClient()
            $connections++
            $reason = 'reader-init'
            try {
                Write-HandoffTrace -Event 'CONNECTED' -Port $port
                $stream = $client.GetStream(); $stream.ReadTimeout = 5000; $stream.WriteTimeout = 5000
                $reader = New-Object IO.StreamReader($stream, [Text.Encoding]::UTF8, $false, 4096, $true)
                $reason = 'request-line'
                $first = $reader.ReadLine(); $headers = @{}; $total = 0
                if ($null -eq $first) { throw 'Empty browser connection.' }
                while ($true) {
                    $reason = 'header-read'
                    $line = $reader.ReadLine()
                    if ($null -eq $line) { throw 'Incomplete browser handoff.' }
                    $total += $line.Length
                    if ($total -gt 8192) { throw 'Browser handoff headers too large.' }
                    if ($line -eq '') { break }
                    # IndexOf/Substring avoid framework-dependent Split overload
                    # selection under Windows PowerShell 5.1. Split only at the
                    # first colon; URI/header values may contain more colons.
                    $reason = 'header-separator'
                    $separator = $line.IndexOf([char]':')
                    if ($separator -le 0) { throw 'Invalid handoff header.' }
                    $name = $line.Substring(0, $separator)
                    $reason = 'header-duplicate'
                    if ($headers.ContainsKey($name)) { throw 'Duplicate handoff header.' }
                    $headers[$name] = $line.Substring($separator + 1).Trim()
                }
                $reason = 'origin'
                if ($headers['Origin'] -cne $origin) { throw 'Untrusted browser origin.' }
                $reason = 'host'
                if ($headers['Host'] -cne ('127.0.0.1:' + $port)) { throw 'Untrusted browser host.' }
                $reason = 'method-or-nonce'
                if ($first -notin @("OPTIONS /$nonce HTTP/1.1", "POST /$nonce HTTP/1.1")) { throw 'Untrusted browser request.' }
                $reason = 'body-size-type-or-read'
                $body = $null
                if ($first.StartsWith('POST ')) {
                    $length = 0
                    if (-not [int]::TryParse($headers['Content-Length'], [ref]$length) -or $length -le 0 -or $length -gt 2097152 -or
                        $headers.ContainsKey('Transfer-Encoding') -or $headers['Content-Type'] -notmatch '^text/plain') { throw 'Invalid browser document size/type.' }
                    # Browser sends ASCII JSON so HTTP byte count equals character count.
                    $chars = New-Object char[] $length; $read = 0
                    while ($read -lt $length) { $count = $reader.Read($chars, $read, $length - $read); if ($count -le 0) { throw 'Truncated browser document.' }; $read += $count }
                    $body = -join $chars
                }
                $reason = 'response-write'
                $reply = "HTTP/1.1 200 OK`r`nAccess-Control-Allow-Origin: $origin`r`nAccess-Control-Allow-Methods: POST, OPTIONS`r`nAccess-Control-Allow-Headers: Content-Type`r`nAccess-Control-Allow-Private-Network: true`r`nContent-Length: 0`r`nConnection: close`r`n`r`n"
                $bytes = [Text.Encoding]::ASCII.GetBytes($reply); $stream.Write($bytes, 0, $bytes.Length)
                if ($null -ne $body) {
                    Write-HandoffTrace -Event 'DOCUMENT_RECEIVED' -Port $port
                    return $body
                }
                $preflights++
                Write-HandoffTrace -Event 'PREFLIGHT_REPLIED' -Port $port
            } catch {
                $rejections++
                Write-HandoffTrace -Event 'REQUEST_REJECTED' -Port $port -Reason $reason -ExceptionType ($_.Exception.GetType().FullName) -SourceLine $_.InvocationInfo.ScriptLineNumber
                Write-Verbose 'Rejected or incomplete loopback request.'
            }
            finally { $client.Close() }
        }
        Write-HandoffTrace -Event 'TIMEOUT' -Port $port -Reason ('connections=' + $connections + ';preflights=' + $preflights + ';rejections=' + $rejections)
        throw 'Browser handoff timed out. This does not establish a sign-in failure. Retain browser-handoff.log from the diagnostic folder and the browser error. No preview update was authorized.'
    } finally {
        $listener.Stop()
        Write-HandoffTrace -Event 'STOPPED' -Port $port
    }
}

function Get-CurrentAcceptedSource {
    # The #81 service selects the current completed run. No archive scanning,
    # copied report, static CSV or missing-hash fallback is permitted.
    $uri = [uri]$CurrentSourceUrl
    if ($uri.Scheme -ne 'https') { throw 'Accepted-source service requires HTTPS.' }
    # Browser retains its own Access session. Only the read-only source
    # document crosses a nonce-bound, temporary loopback handoff.
    $json = Receive-BrowserSource
    $doc = $json | ConvertFrom-Json
    if ($doc.schema_version -ne 1 -or $doc.status -cne 'COMPLETED' -or $doc.validation -cne 'PASSED' -or
        $doc.source_manifest_sha256 -cnotmatch '^[a-f0-9]{64}$' -or $doc.evidence_id -cnotmatch '^[a-f0-9]{64}$' -or
        $doc.report_sha256 -cnotmatch '^[a-f0-9]{64}$' -or $doc.source_sqlite_sha256 -cnotmatch '^[a-f0-9]{64}$' -or
        $doc.run_id -le 0 -or $doc.import_run_id -le 0 -or $doc.preview_count -le 0 -or
        @($doc.previews).Count -ne $doc.preview_count) { throw 'Accepted-source contract is incomplete or unsupported.' }
    if (-not [IO.Path]::IsPathRooted([string]$doc.source_folder) -or
        (Split-Path -Leaf $doc.source_folder) -cne ('Database Previews V' + $doc.lor_version)) {
        throw 'Accepted source is not the exact versioned master folder.'
    }
    $names = @{}; $ids = @{}; $rows = @()
    foreach ($item in $doc.previews) {
        if ([IO.Path]::GetFileName([string]$item.filename) -cne $item.filename -or
            $item.filename -notmatch '\.lorprev$' -or [string]::IsNullOrWhiteSpace($item.preview_id) -or
            [string]::IsNullOrWhiteSpace($item.name) -or $names.ContainsKey($item.filename) -or $ids.ContainsKey($item.preview_id)) {
            throw 'Accepted-source inventory contains invalid or duplicate identities.'
        }
        $names[$item.filename] = $true; $ids[$item.preview_id] = $true
        $rows += [pscustomobject]@{Filename=$item.filename; PreviewId=$item.preview_id; PreviewName=$item.name; Revision=[string]$item.revision}
    }
    return [pscustomobject]@{RunId=$doc.run_id; ImportRunId=$doc.import_run_id; Path=$doc.report_url;
        SourceFolder=$doc.source_folder; SourceManifestSha256=$doc.source_manifest_sha256;
        EvidenceId=$doc.evidence_id; Rows=$rows}
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
            if ($IsRoot -and ($attr.Name -ieq 'Revision' -or $attr.Name -ceq 'Brightness' -or $attr.Name -ceq 'LastSelectedSceneId')) {
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
        $metadataHash = Get-FileSha256 -Path $DeploymentPath
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

    if (-not $deployment.current_source_url -or $deployment.current_source_url -cne $CurrentSourceUrl) {
        throw 'Deployment accepted-source service identity is missing or mismatched.'
    }

    if ($deployment.apply_enabled -isnot [bool]) { throw 'Deployment apply permission must be an explicit boolean.' }
    if ($deployment.source_commit -cnotmatch '^[a-f0-9]{40}$') { throw 'Missing committed source identity.' }
    if ((Get-FileSha256 -Path $DeploymentPath) -cne $metadataHash) { throw 'Deployment metadata changed while being verified.' }
    $deployment | Add-Member -NotePropertyName VerifiedMetadataHash -NotePropertyValue $metadataHash
    $script:SourceCommit = $deployment.source_commit
    return $deployment
}

function Assert-ReviewedDeployment {
    param([string]$ExpectedHash, [string]$ExpectedCommit)
    $current = Test-DeploymentIdentity
    if ($current.VerifiedMetadataHash -cne $ExpectedHash -or $current.source_commit -cne $ExpectedCommit -or
        $current.apply_enabled -isnot [bool] -or -not $current.apply_enabled) {
        throw 'The reviewed release identity or apply permission changed. Nothing was installed.'
    }
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

    $capturedHashes = New-Object 'System.Collections.Generic.Dictionary[string,string]'


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
        $bytes = [IO.File]::ReadAllBytes($file.FullName)
        $sha = [Security.Cryptography.SHA256]::Create()
        try { $capturedHashes.Add($file.Name, ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-', '').ToLowerInvariant()) }
        finally { $sha.Dispose() }
        $raw = Remove-XmlDeclaration ([Text.Encoding]::UTF8.GetString($bytes).TrimStart([char]0xFEFF))
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
        SourceStateSha256 = [MSBSourceManifest]::ComputeCaptured($capturedHashes)
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

        if ($record.PreviewId -ine $row.PreviewId) { throw "Accepted PreviewID mismatch for $($row.Filename)." }

        if ($record.Name -cne $row.PreviewName) {
            throw "Preview name mismatch for $($row.Filename).`nReport: $($row.PreviewName)`nFile: $($record.Name)"
        }

        if ($record.Revision -ne $row.Revision) {
            throw "Revision mismatch for $($row.Filename).`r`nReport: $($row.Revision)`r`nFile: $($record.Revision)"
        }
    }

    if ([string]::IsNullOrWhiteSpace($Report.SourceManifestSha256) -or
        $Master.SourceStateSha256 -cne $Report.SourceManifestSha256) {
        throw "Master content does not match the frozen source digest accepted by LOR2DB Run $($Report.RunId)."
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
        [AllowNull()]$ProgressWindow,
        [switch]$MatchMasterRevision
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

    # Same-name/different-ID previews must be resolved deliberately, even if
    # one is personal. Never install an ambiguous controlled name.
    $controlledNames = @{}
    foreach ($record in $MasterRecords.Values) {
        if ($controlledNames.ContainsKey($record.Name)) { throw 'Duplicate controlled preview name.' }
        $controlledNames[$record.Name] = $record.PreviewId
    }
    foreach ($match in $matches) {
        $record = Get-PreviewRecord $match.Value $LocalPath
        if ($controlledNames.ContainsKey($record.Name) -and $controlledNames[$record.Name] -ne $record.PreviewId) {
            throw "Preview name belongs to a different local identity: $($record.Name)"
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
                Approved_Filename      = [IO.Path]::GetFileName($approved.Source)
                Approved_Name          = $approved.Name
                Local_Name             = ''
                Approved_Revision      = $approved.Revision
                Local_Revision         = ''
                Approved_Semantic_Hash = $approved.SemanticHash
                Local_Semantic_Hash    = ''
                Review_Details         = 'Add the complete accepted preview. It is not present on this PC.'
                Database_Impact        = 'New preview; review its display names, prop identities, scenes and wiring.'
                Review_Diff            = '+ Complete accepted preview (not present on this PC).'
                Presentation_Details   = ''
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
        }
        if ($MatchMasterRevision -and $action -eq 'NOOP_REVISION_ONLY') {
            $action = 'ALIGN_REVISION_IN_CANDIDATE'
        }
        if ($action -in @('REPLACE_IN_CANDIDATE','ALIGN_REVISION_IN_CANDIDATE')) {
            $replacementRaw = $(if ($action -eq 'ALIGN_REVISION_IN_CANDIDATE') { [MSBPreviewSemantic]::MatchMasterRevision($localRecord.Raw, $approved.Raw) } else { [MSBPreviewSemantic]::PreservePresentation($localRecord.Raw, $approved.Raw) })
            $lineStart = $localText.LastIndexOf("`n", [Math]::Max(0, $block.Start - 1)) + 1
            $indent = $localText.Substring($lineStart, $block.Start - $lineStart)
            if ($indent -notmatch '^\s*$') { $indent = '' }
            $replacement = Add-IndentToFragment $replacementRaw $indent $newline
            $replacements += [pscustomobject]@{
                Start = $block.Start
                End = $block.End
                Raw = $replacement
            }
        }

        $rows += [pscustomobject]@{
            Action                 = $action
            Preview_ID             = $previewId
            Approved_Filename      = [IO.Path]::GetFileName($approved.Source)
            Approved_Name          = $approved.Name
            Local_Name             = $localRecord.Name
            Approved_Revision      = $approved.Revision
            Local_Revision         = $localRecord.Revision
            Approved_Semantic_Hash = $approved.SemanticHash
            Local_Semantic_Hash    = $localRecord.SemanticHash
            Database_Impact        = $(if ($action -eq 'REPLACE_IN_CANDIDATE') { [MSBPreviewSemantic]::ImpactNotes($localRecord.Raw, $approved.Raw) } else { 'Preview identity and substantive content match the accepted master.' })
            Review_Diff            = $(if ($action -eq 'NOOP') { '' } else { [MSBPreviewSemantic]::UnifiedDiff($localRecord.Raw, $approved.Raw) })
            Presentation_Details   = [MSBPreviewSemantic]::PresentationDetails($localRecord.Raw, $approved.Raw)
            Review_Details         = $(if ($action -eq 'REPLACE_IN_CANDIDATE') { [MSBPreviewSemantic]::DescribeChanges($localRecord.Raw, $approved.Raw) } else { '' })
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
            if ($childIndent -notmatch '^\s*$') { $childIndent = '  ' }
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
        AlignRevision = @($Rows | Where-Object Action -eq 'ALIGN_REVISION_IN_CANDIDATE').Count
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
    $form.Text = "MSB PC Preview Updater $ApplicationVersion | $ApplicationReleaseDate"
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
    $title.Text = "Starting MSB Preview Update $ApplicationVersion..."
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
            $accepted = Get-CurrentAcceptedSource

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
                EvidenceId     = $accepted.EvidenceId
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


function New-ReviewPlan {
    param($MasterRecords, [string]$LocalPath, [string]$ExpectedOriginalHash,
          [string]$CandidatePath, [string]$ReportPath, [switch]$MatchMasterRevision)
    Assert-LightORamaClosed
    if ((Get-FileSha256 $LocalPath) -cne $ExpectedOriginalHash) { throw 'Local previews changed during review. Close LOR and restart the updater.' }
    $build = Build-SyncCandidate -MasterRecords $MasterRecords -LocalPath $LocalPath -ProgressWindow $null -MatchMasterRevision:$MatchMasterRevision
    if ((Get-FileSha256 $LocalPath) -cne $ExpectedOriginalHash) { throw 'Local previews changed while preparing the review.' }
    Write-CandidateFile -Build $build -Path $CandidatePath
    Write-ActionReport -Rows $build.Rows -Path $ReportPath
    return [pscustomobject]@{ Build = $build; CandidateHash = (Get-FileSha256 $CandidatePath) }
}

function Show-ReviewDialog {
    param($AcceptedReport, $Build, $MasterRecords, [string]$LocalPath, [string]$ExpectedOriginalHash,
          [string]$CandidatePath, [string]$ReportPath, [string]$CandidateHash, [switch]$ReviewOnly)
    $state = [pscustomobject]@{ Build=$Build; CandidateHash=$CandidateHash; Failed=$false; Approved=$false }
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "MSB PC Preview Updater $ApplicationVersion | $ApplicationReleaseDate | Review changes"
    $form.StartPosition = 'CenterScreen'
    $area = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
    $form.Size = New-Object System.Drawing.Size([Math]::Min(1080,[int]($area.Width*0.94)), [Math]::Min(800,[int]($area.Height*0.90)))
    $form.MinimumSize = New-Object System.Drawing.Size([Math]::Min(800,[int]($area.Width*0.85)), [Math]::Min(620,[int]($area.Height*0.80)))
    $form.ShowInTaskbar = $true
    if ($null -ne $script:AppIcon) { $form.Icon = $script:AppIcon }
    $layout = New-Object System.Windows.Forms.TableLayoutPanel
    $layout.Dock = 'Fill'; $layout.ColumnCount = 1; $layout.RowCount = 6
    $layout.Padding = New-Object System.Windows.Forms.Padding(14)
    foreach ($height in @(0,0,35,0,65,0)) {
        $style = New-Object System.Windows.Forms.RowStyle
        if ($height -eq 0) { $style.SizeType='AutoSize' } else { $style.SizeType='Percent'; $style.Height=$height }
        [void]$layout.RowStyles.Add($style)
    }
    $form.Controls.Add($layout)
    $title = New-Object System.Windows.Forms.Label
    $title.Text="Review MSB preview changes - v$ApplicationVersion ($ApplicationReleaseDate)"; $title.AutoSize=$true
    $title.Font=New-Object System.Drawing.Font('Segoe UI',16,[System.Drawing.FontStyle]::Bold)
    [void]$layout.Controls.Add($title,0,0)
    $summary = New-Object System.Windows.Forms.Label
    $summary.AutoSize=$true; $summary.Dock='Fill'; $summary.Margin=New-Object System.Windows.Forms.Padding(0,8,0,10)
    [void]$layout.Controls.Add($summary,0,1)
    $grid=New-Object System.Windows.Forms.DataGridView
    $grid.Dock='Fill'; $grid.ReadOnly=$true; $grid.AllowUserToAddRows=$false; $grid.AllowUserToDeleteRows=$false
    $grid.MultiSelect=$false; $grid.SelectionMode='FullRowSelect'; $grid.RowHeadersVisible=$false
    $grid.AutoSizeColumnsMode='Fill'; $grid.AllowUserToOrderColumns=$false
    foreach ($column in @(@('Filename','Preview file',65),@('Action','Proposed action',20),@('Local','PC Revision',8),@('Master','Master Revision',8))) {
        $index=$grid.Columns.Add([string]$column[0],[string]$column[1]); $grid.Columns[$index].FillWeight=[int]$column[2]
        $grid.Columns[$index].SortMode='NotSortable'
    }
    [void]$layout.Controls.Add($grid,0,2)
    $detailLabel=New-Object System.Windows.Forms.Label
    $detailLabel.AutoSize=$true; $detailLabel.Dock='Fill'; $detailLabel.Margin=New-Object System.Windows.Forms.Padding(0,8,0,4)
    [void]$layout.Controls.Add($detailLabel,0,3)
    $details=New-Object System.Windows.Forms.RichTextBox
    $details.Dock='Fill'; $details.ReadOnly=$true; $details.WordWrap=$false; $details.DetectUrls=$false
    $details.Font=New-Object System.Drawing.Font('Consolas',9)
    [void]$layout.Controls.Add($details,0,4)
    $bottom=New-Object System.Windows.Forms.FlowLayoutPanel
    $bottom.Dock='Fill'; $bottom.AutoSize=$true; $bottom.FlowDirection='TopDown'; $bottom.WrapContents=$false
    [void]$layout.Controls.Add($bottom,0,5)
    $align=New-Object System.Windows.Forms.CheckBox
    $align.AutoSize=$true; $align.Text='Match master Revision for previews with identical identity and content (metadata only).'
    $align.Checked=$false; [void]$bottom.Controls.Add($align)
    $closed=New-Object System.Windows.Forms.CheckBox
    $closed.AutoSize=$true; $closed.Text='I have closed Light-O-Rama on this PC.'; [void]$bottom.Controls.Add($closed)
    $ack=New-Object System.Windows.Forms.CheckBox
    $ack.AutoSize=$true; $ack.Text='I approve the listed changes. A backup will be created; personal previews will be preserved.'
    [void]$bottom.Controls.Add($ack)
    $buttons=New-Object System.Windows.Forms.FlowLayoutPanel
    $buttons.AutoSize=$true; $buttons.FlowDirection='LeftToRight'; [void]$bottom.Controls.Add($buttons)
    $cancel=New-Object System.Windows.Forms.Button
    $cancel.Text='Cancel'; $cancel.AutoSize=$true; $cancel.DialogResult='Cancel'; [void]$buttons.Controls.Add($cancel)
    $update=New-Object System.Windows.Forms.Button
    $update.Text=$(if ($ReviewOnly) { 'Review only' } else { 'Update PC Previews' })
    $update.AutoSize=$true; $update.Enabled=$false; [void]$buttons.Controls.Add($update)
    $reports=New-Object System.Windows.Forms.Button
    $reports.Text='Open report folder'; $reports.AutoSize=$true
    [void]$buttons.Controls.Add($reports)
    $reports.Add_Click({
        try { Start-Process -FilePath 'explorer.exe' -ArgumentList ('"{0}"' -f $LogFolder) -ErrorAction Stop | Out-Null }
        catch { Show-Message "Reports are saved in:`r`n$LogFolder" 'MSB Preview Reports' ([System.Windows.Forms.MessageBoxIcon]::Information) }
    })
    $refreshButtons={
        $counts=Get-ActionCounts $state.Build.Rows
        $update.Enabled=(-not $ReviewOnly -and -not $state.Failed -and $closed.Checked -and $ack.Checked -and
            ($counts.Add + $counts.Replace + $counts.AlignRevision -gt 0))
    }
    $showDetails={
        if ($grid.SelectedRows.Count -eq 0) { return }
        $row=$grid.SelectedRows[0].Tag
        if ($null -eq $row) { return }
        $detailLabel.Text=([string]$row.Approved_Filename)+' - '+([string]$row.Approved_Name)
        $details.Clear()
        $notes=[string]$row.Database_Impact
        $text='Database review: '+$notes+"`r`n`r`n--- This PC`r`n+++ Accepted master`r`n"+[string]$row.Review_Diff
        if ([string]::IsNullOrWhiteSpace([string]$row.Review_Diff)) { $text += 'No controlled-content differences.' }
        if (-not [string]::IsNullOrWhiteSpace([string]$row.Presentation_Details)) { $text += "`r`n`r`nLocal viewing preferences (no update required):`r`n" + $row.Presentation_Details }
        $details.Text=$text
        foreach ($match in [regex]::Matches($text,'(?m)^[+-].*$')) {
            $details.Select($match.Index,$match.Length)
            $details.SelectionColor=$(if ($match.Value.StartsWith('+')) { [Drawing.Color]::DarkGreen } else { [Drawing.Color]::DarkRed })
        }
        $details.Select(0,0); $details.ScrollToCaret()
    }
    $populate={
        $grid.Rows.Clear()
        $counts=Get-ActionCounts $state.Build.Rows
        $summary.Text=$(if ($ReviewOnly) { "REVIEW ONLY - apply disabled.`r`n" } else { '' }) +
            ("Accepted Run {0} | ADD {1} | REPLACE {2} | Match Revision {3} | Revision-only unchanged {4} | Personal preserved {5}" -f
             $AcceptedReport.RunId,$counts.Add,$counts.Replace,$counts.AlignRevision,$counts.RevisionOnly,$state.Build.UnmanagedCount)
        foreach ($row in @($state.Build.Rows | Sort-Object @{Expression={if ($_.Action -eq 'REPLACE_IN_CANDIDATE'){0}elseif($_.Action -eq 'ADD_IN_CANDIDATE'){1}elseif($_.Action -in @('NOOP_REVISION_ONLY','ALIGN_REVISION_IN_CANDIDATE')){2}else{3}}},Approved_Filename)) {
            $action=switch ($row.Action) {
                'REPLACE_IN_CANDIDATE' {'Replace content'}
                'ADD_IN_CANDIDATE' {'Add preview'}
                'ALIGN_REVISION_IN_CANDIDATE' {'Match Revision'}
                'NOOP_REVISION_ONLY' {'Revision only - no action'}
                'NOOP' {if ($row.Presentation_Details) {'Current - local preferences preserved'} else {'Current'}}
                default {'Current'}
            }
            $i=$grid.Rows.Add([object[]]@([string]$row.Approved_Filename,$action,[string]$row.Local_Revision,[string]$row.Approved_Revision))
            $grid.Rows[$i].Tag=$row
        }
        if ($grid.Rows.Count -gt 0) { $grid.Rows[0].Selected=$true }
        & $showDetails; & $refreshButtons
    }
    $grid.Add_SelectionChanged($showDetails)
    $closed.Add_CheckedChanged($refreshButtons); $ack.Add_CheckedChanged($refreshButtons)
    $align.Add_CheckedChanged({
        $update.Enabled=$false; $ack.Checked=$false
        try {
            $plan=New-ReviewPlan -MasterRecords $MasterRecords -LocalPath $LocalPath -ExpectedOriginalHash $ExpectedOriginalHash -CandidatePath $CandidatePath -ReportPath $ReportPath -MatchMasterRevision:$align.Checked
            $state.Build=$plan.Build; $state.CandidateHash=$plan.CandidateHash; $state.Failed=$false
            # Persist the rebuilt plan before presenting it or allowing approval.
            $null=Write-SharedLog -Report $AcceptedReport -Build $state.Build -Result 'REVIEW_REBUILT' -OriginalHash $ExpectedOriginalHash -CandidateHash $state.CandidateHash
            & $populate
        } catch {
            $state.Failed=$true; $details.Text=$_.Exception.Message
            $summary.Text='BLOCKED: the revised review could not be prepared. Cancel and restart.'
        }
        & $refreshButtons
    })
    $update.Add_Click({$state.Approved=$true;$form.Close()})
    $form.Add_Resize({
        $width=[Math]::Max(250,$form.ClientSize.Width-40)
        foreach ($control in @($summary,$detailLabel,$align,$ack)) { $control.MaximumSize=New-Object Drawing.Size($width,0) }
    })
    $form.CancelButton=$cancel
    # Request focus once after startup closes. Release topmost promptly so the
    # operator can switch applications normally; never poll or steal focus again.
    $focusTimer=New-Object System.Windows.Forms.Timer
    $focusTimer.Interval=350
    $focusTimer.Add_Tick({ $form.TopMost=$false; $focusTimer.Stop() })
    $form.Add_Shown({ $this.TopMost=$true; $this.BringToFront(); $this.Activate(); $focusTimer.Start() })
    $form.Add_FormClosed({ $focusTimer.Stop(); $focusTimer.Dispose() })
    & $populate
    [void]$form.ShowDialog(); $form.Dispose()
    return [pscustomobject]@{Approved=$state.Approved;Build=$state.Build;CandidateHash=$state.CandidateHash}
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

    $stamp = (Get-Date -Format 'yyyyMMdd-HHmmssfff') + '-' + [guid]::NewGuid().ToString('N')
    $backupFolder = Join-Path (Split-Path -Parent $LivePath) 'MSB_Preview_Sync_Backups'
    New-Item -ItemType Directory -Path $backupFolder -Force | Out-Null

    $backup = Join-Path $backupFolder ("LORPreviews.before-msb-sync-{0}.xml" -f $stamp)
    $installing = "$LivePath.msb-sync-installing-$stamp"
    Copy-Item -LiteralPath $CandidatePath -Destination $installing -Force

    [xml]$verifiedCandidate = [IO.File]::ReadAllText($installing)
    Assert-LightORamaClosed
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
    $stamp = (Get-Date -Format 'yyyyMMdd-HHmmssfff') + '-' + [guid]::NewGuid().ToString('N')
    $safeUser = ($env:USERNAME -replace '[^A-Za-z0-9_.-]', '_')
    $safeComputer = ($env:COMPUTERNAME -replace '[^A-Za-z0-9_.-]', '_')
    if ([string]::IsNullOrWhiteSpace($script:SessionLogPath)) {
        $script:SessionLogPath = Join-Path $LogFolder ("sync-{0}-{1}-{2}.txt" -f $safeComputer, $safeUser, $stamp)
    }
    $path = $script:SessionLogPath
    # Retain the complete reviewed diff with this run, independently of the
    # compatibility CSV in CommonData which the next launch will overwrite.
    $reportCopy = [IO.Path]::ChangeExtension($path, '.csv')
    $Build.Rows | Export-Csv -LiteralPath $reportCopy -NoTypeInformation -Encoding UTF8
    $counts = Get-ActionCounts $Build.Rows

    @(
        'MSB LOR Preview Sync'
        "Application version: $ApplicationVersion"
        'PC comparison policy: root Revision metadata; root Brightness/LastSelectedSceneId local preferences; all other content controlled'
        "Release date: $ApplicationReleaseDate"
        "Application commit: $script:SourceCommit"
        "Timestamp: $(Get-Date -Format o)"
        "Computer: $env:COMPUTERNAME"
        "User: $env:USERNAME"
        "Result: $Result"
        "LOR2DB Run: $($Report.RunId)"
        "Published report: $($Report.Path)"
        "Accepted evidence: $($Report.EvidenceId)"
        "Captured ingest: $($Report.ImportRunId)"
        "Master folder: $($Report.SourceFolder)"
        "Frozen source manifest: $($Report.SourceManifestSha256)"
        "Observed source state: $SourceStateHash"
        "Controlled previews: $($Build.Rows.Count)"
        "NOOP: $($counts.Noop)"
        "Revision-only unchanged: $($counts.RevisionOnly)"
        "Revisions matched: $($counts.AlignRevision)"
        "Replaced: $($counts.Replace)"
        "Added: $($counts.Add)"
        "Unmanaged/personal preserved: $($Build.UnmanagedCount)"
        "Original local SHA-256: $OriginalHash"
        "Candidate SHA-256: $CandidateHash"
        "Installed SHA-256: $InstalledHash"
        "Backup: $Backup"
        "Detailed report: $reportCopy"
        ''
    ) | Add-Content -LiteralPath $path -Encoding UTF8

    return $path
}

try {
    $prepared = Prepare-SyncWithStartup
    $accepted = $prepared.Accepted
    $master = $prepared.Master
    $build = $prepared.Build
    $counts = Get-ActionCounts -Rows $build.Rows

    if ($counts.Replace -eq 0 -and $counts.Add -eq 0 -and $counts.RevisionOnly -eq 0) {
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

    # Fail closed if durable evidence cannot be written. This happens before
    # opening the review, so closing/killing the UI cannot erase the initial plan.
    $null = Write-SharedLog -Report $accepted -Build $build -Result 'REVIEW_PREPARED' `
        -SourceStateHash $prepared.SourceStateHash -OriginalHash $prepared.OriginalHash `
        -CandidateHash $prepared.CandidateHash

    if ($AuditOnly -or -not $prepared.Deployment.apply_enabled) {
        $review = Show-ReviewDialog -AcceptedReport $accepted -Build $build -MasterRecords $master.Records -LocalPath $LocalXml -ExpectedOriginalHash $prepared.OriginalHash -CandidatePath $CandidateXml -ReportPath $CandidateCsv -CandidateHash $prepared.CandidateHash -ReviewOnly
        $null = Write-SharedLog -Report $accepted -Build $review.Build -Result 'AUDIT_ONLY' `
            -SourceStateHash $prepared.SourceStateHash -OriginalHash $prepared.OriginalHash `
            -CandidateHash $review.CandidateHash
        exit 0
    }

    $review = Show-ReviewDialog -AcceptedReport $accepted -Build $build -MasterRecords $master.Records -LocalPath $LocalXml -ExpectedOriginalHash $prepared.OriginalHash -CandidatePath $CandidateXml -ReportPath $CandidateCsv -CandidateHash $prepared.CandidateHash
    $build = $review.Build
    $counts = Get-ActionCounts $build.Rows
    $prepared.CandidateHash = $review.CandidateHash
    if (-not $review.Approved) {
        $null = Write-SharedLog -Report $accepted -Build $build -Result 'CANCELLED' `
            -SourceStateHash $prepared.SourceStateHash -OriginalHash $prepared.OriginalHash `
            -CandidateHash $prepared.CandidateHash
        exit 0
    }

    # Recheck every moving boundary immediately before the write. A new
    # reconciliation, source edit, local LOR save or candidate edit invalidates
    # the review instead of silently installing stale work.
    Assert-ReviewedDeployment -ExpectedHash $prepared.Deployment.VerifiedMetadataHash -ExpectedCommit $prepared.Deployment.source_commit
    Assert-LightORamaClosed

    $latestNow = Get-CurrentAcceptedSource
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
    if ($latestNow.EvidenceId -cne $prepared.EvidenceId) {
        throw 'Accepted LOR2DB source evidence changed during review. Nothing was installed.'
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

    Assert-ReviewedDeployment -ExpectedHash $prepared.Deployment.VerifiedMetadataHash -ExpectedCommit $prepared.Deployment.source_commit
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
        "Revision metadata matched: $($counts.AlignRevision)`r`n" +
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