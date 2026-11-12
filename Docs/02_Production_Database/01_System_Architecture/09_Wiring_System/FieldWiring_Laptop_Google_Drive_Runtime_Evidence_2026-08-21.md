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

The operator also confirmed that this same general Google Drive for desktop access pattern exists on other Windows MSB systems, including the Show PC. That statement describes access to the Google filesystem; it does **not** mean those systems operate production workloads directly from Google Drive.

This client-side mechanism is useful for Windows operator/authoring systems, but it is **not** an acceptable FieldWiring production-server dependency. A phone or tablet browser must not require its own Google Drive mapping, and the FieldWiring server must not depend on any Windows workstation remaining online.

The server deployment may use the same authoritative Google Workspace / Shared Drive source only through a separately controlled server-side access mechanism.

## Show PC Operational Sync Boundary

The Show PC has its own Windows user/account context that maintains access to the Google `G:` filesystem.

Production show sequences are **not run from Google Drive**.

The Show PC operates from the local filesystem:

```text
C:\lor
```

The operator manually initiates an Allway Sync two-way synchronization between the local `C:\lor` working set and the applicable Google Drive location to move production show sequence changes back and forth.

Therefore the Show PC pattern is:

```text
Google Drive for desktop / G:
        <-> manually initiated Allway Sync
        <-> local C:\lor operational files
        -> show operation uses local files
```

This is an intentional reliability boundary: Google Drive is a synchronization/transfer repository for the Show PC workflow, not the live show-runtime filesystem.

### Relevance to FieldWiring

This is a useful operational precedent but must not be copied mechanically.

For FieldWiring:

- Google Shared Drive `Display Folders` remains the authoritative editable engineering-document repository;
- a server-local read-only copy could be a valid presentation/runtime strategy if it is deliberately designed and its freshness is controlled;
- FieldWiring must never use a two-way synchronization job because it has no authority to write engineering documents back to Google Drive;
- a manually initiated sync like the Show PC workflow would create an avoidable stale-document risk for a browser application expected to present current published wiring; and
- any server-side replica must have documented one-way synchronization, freshness/health evidence, failure behavior, and recovery ownership.

This precedent therefore keeps both architecture classes open for investigation:

1. direct read-only server access to Google Shared Drive; or
2. an independently maintained read-only server-local replica synchronized one-way from Google Drive.

No choice is made by this evidence alone.

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
          OR a deliberately maintained read-only server-local replica
```

Therefore the earlier candidate of reusing an existing Synology-side synchronized `Display Folders` tree is eliminated.

The next architecture investigation must compare direct read-only server access to Google Shared Drive against a controlled one-way local replica. Either mechanism must operate independently of Windows workstations and preserve the existing Stage/Sub-stage/Scene hierarchy, source-folder markers, published Wiring/PreviewBackground branches, filename/path evidence, and `SourceDocs` exclusions.

Do not introduce a Synology synchronization copy merely because Synology is already present in the web path. Likewise, do not assume direct live mounting is automatically superior merely because it avoids synchronization. The decision must compare operational reliability, currentness, recovery behavior, and dependency count against the actual server environment.

## Documentation Governance Note

During this reconnaissance, the Production Database repository's `System_Documentation/Standards/` was found to contain newer and more complete reusable standards than the corresponding copied standards in `MSB-Server-Management`.

For this work:

- current reusable documentation standards are taken from the Production Database repository's shared standards set;
- Production Database project rules remain authoritative for Production Database-specific governance; and
- `MSB-Server-Management` project rules remain authoritative for server-specific SSH/live-runtime and production-change handling.

Synchronizing the reusable standards into `MSB-Server-Management` is a separate documentation-maintenance task and should not be mixed into FieldWiring deployment changes.
