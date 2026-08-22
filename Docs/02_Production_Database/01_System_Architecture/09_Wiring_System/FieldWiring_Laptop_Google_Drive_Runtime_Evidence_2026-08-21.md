# FieldWiring Laptop Google Drive Runtime Evidence — 2026-08-21

| Document control | Value |
|---|---|
| Status | VERIFIED LAPTOP RUNTIME EVIDENCE — Google Drive client mechanism confirmed; no Synology Display Folders copy exists |
| Sub-project | FieldWiring |
| Host type | Windows development/operator laptop |
| Production-change status | NONE |

## Purpose

This note records read-only runtime evidence gathered on the current FieldWiring development/operator laptop to identify what provides access to the Google Shared Drive path used by the accepted laptop release candidate:

```text
G:\Shared drives\Display Folders
```

This is deployment reconnaissance only. The laptop must not become a production dependency.

## G: Drive Evidence

PowerShell reported:

```text
Name        : G
Root        : G:\
Provider    : Microsoft.PowerShell.Core\FileSystem
Description : gliebig@sheboyganlights.org - ...
```

`Win32_LogicalDisk` reported:

```text
DeviceID     : G:
DriveType    : 3
ProviderName :
VolumeName   : gliebig@sheboyganlights.org - ...
FileSystem   : FAT32
```

`fsutil fsinfo drivetype G:` reported:

```text
G: - Fixed Drive
```

`Get-Volume -DriveLetter G` returned no normal Windows volume record.

Taken together, this is consistent with a virtual filesystem mounted as a fixed drive rather than a conventional local disk or SMB mapped network drive.

## Google Drive for Desktop Runtime

Two active Google Drive File Stream processes were present:

```text
GoogleDriveFS.exe
C:\Program Files\Google\Drive File Stream\129.0.1.0\GoogleDriveFS.exe
```

The parent process command line was:

```text
"C:\Program Files\Google\Drive File Stream\129.0.1.0\GoogleDriveFS.exe" --startup_mode
```

The child process also identified version `129.0.1.0` and the parent crash-handler pipe.

The machine listener inventory showed:

```text
::1:7679 -> GoogleDriveFS
```

This listener is loopback-only. No evidence was found in the listener inventory that Google Drive for desktop exposes the Display Folders tree as a LAN-accessible file service.

### Current conclusion

The combined account-labeled virtual `G:` drive evidence and active Google Drive for desktop runtime establish Google Drive for desktop as the current laptop mechanism providing the Google Drive filesystem used by FieldWiring development.

The operator also confirmed that this is the established Windows-machine pattern beyond this laptop: Windows systems that use the protected MSB environment, including the Show PC, have Google Drive for desktop access mapped as `G:` to the Google filesystem.

This client-side mechanism is useful for Windows operator/authoring systems, but it is **not** an acceptable FieldWiring production-server dependency. A phone or tablet browser must not require its own Google Drive mapping, and the FieldWiring server must not depend on any Windows workstation remaining online.

The server deployment may use the same authoritative Google Workspace / Shared Drive source only through a separately controlled server-side access mechanism.

## Other Relevant Laptop Services

### GoodSync Server

The machine has:

```text
Name        : GsServer
DisplayName : GoodSync Server
State       : Running
StartMode   : Auto
StartName   : LocalSystem
PathName    : "C:\Program Files\Siber Systems\GoodSync\gs-server.exe" /service
```

Listener inventory showed:

```text
127.0.0.1:11000 -> gs-server
127.0.0.1:33333 -> gs-server
```

Both observed GoodSync listeners are loopback-only.

No configuration search was performed because the operator confirmed that the Synology does **not** consume or maintain the Google Shared Drive `Display Folders` tree today. GoodSync may have other unrelated responsibilities on the laptop, but there is no reason to continue treating it as a candidate FieldWiring image-delivery dependency unless separate evidence later establishes such a role.

### Synology Drive VSS Service

The machine also has:

```text
Name        : Synology Drive VSS Service x64
State       : Running
StartMode   : Auto
StartName   : LocalSystem
PathName    : "C:\Program Files (x86)\Synology\SynologyDrive\bin\vss-service-x64.exe
```

This proves the Synology Drive VSS support service is installed on the laptop. It does not mean that Synology Drive is synchronizing Google `Display Folders`.

The operator explicitly confirmed that the Synology does not currently consume or maintain that Google Shared Drive tree.

## Laptop Verification Closed for Image-Source Discovery

No further laptop PowerShell investigation is required to identify the current FieldWiring image-source mechanism.

The current Windows-side source path is established as:

```text
Google Shared Drive: Display Folders
        -> Google Drive for desktop
        -> G:\Shared drives\Display Folders
        -> Windows applications such as LOR / FieldWiring development
```

That path is a client/runtime convenience, not the future production web-server architecture.

## Deployment Consequence

The image-source problem is now narrower and explicit:

```text
Authoritative engineering documents
        = Google Shared Drive / Display Folders

Current Windows access
        = Google Drive for desktop / G:

Current Synology copy
        = none

Required FieldWiring production access
        = new controlled server-side read-only access to the authoritative Google Shared Drive
```

Therefore the earlier candidate of reusing an existing Synology-side synchronized `Display Folders` tree is eliminated.

The next architecture investigation must evaluate a deliberate server-side mechanism that can read the Google Shared Drive independently of Windows workstations. The mechanism must preserve the existing Stage/Sub-stage/Scene hierarchy, source-folder markers, published Wiring/PreviewBackground branches, filename/path evidence, and `SourceDocs` exclusions.

Do not introduce a Synology synchronization copy merely because Synology is already present in the web path unless that architecture is separately justified against direct server-side Google Drive access.

## Documentation Governance Note

During this reconnaissance, the Production Database repository's `System_Documentation/Standards/` was found to contain newer and more complete reusable standards than the corresponding copied standards in `MSB-Server-Management`.

For this work:

- current reusable documentation standards are taken from the Production Database repository's shared standards set;
- Production Database project rules remain authoritative for Production Database-specific governance; and
- `MSB-Server-Management` project rules remain authoritative for server-specific SSH/live-runtime and production-change handling.

Synchronizing the reusable standards into `MSB-Server-Management` is a separate documentation-maintenance task and should not be mixed into FieldWiring deployment changes.
