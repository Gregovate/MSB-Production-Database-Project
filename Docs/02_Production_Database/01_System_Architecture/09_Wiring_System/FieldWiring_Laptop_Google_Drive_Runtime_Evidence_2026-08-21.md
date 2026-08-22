# FieldWiring Laptop Google Drive Runtime Evidence — 2026-08-21

| Document control | Value |
|---|---|
| Status | VERIFIED LAPTOP RUNTIME EVIDENCE — GoodSync relationship still under investigation |
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

This mechanism is user/laptop runtime state and is **not** an acceptable FieldWiring production dependency.

The server deployment may reuse the same Google Workspace authority/account concept only if a separately controlled server-side mechanism is deliberately established and documented. It must not depend on this laptop remaining logged in or online.

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

No evidence collected yet proves that GoodSync has a job whose source or destination includes:

```text
G:\Shared drives\Display Folders
```

or that it copies any part of that tree to the Synology.

Because `GsServer` runs as `LocalSystem` while the Google Drive virtual filesystem is associated with the interactive Google Drive for desktop account/session, do not assume the service can consume the same `G:` namespace. Verify configured GoodSync jobs directly.

### Synology Drive VSS Service

The machine also has:

```text
Name        : Synology Drive VSS Service x64
State       : Running
StartMode   : Auto
StartName   : LocalSystem
PathName    : "C:\Program Files (x86)\Synology\SynologyDrive\bin\vss-service-x64.exe
```

This proves the Synology Drive VSS support service is installed. It does **not** prove that Synology Drive is synchronizing Google `Display Folders` or that the Synology already has a current copy of that Shared Drive.

## Remaining Laptop Verification

The remaining useful laptop-side question is whether GoodSync or another installed sync component already references `Display Folders`.

Search configuration locations read-only and report filenames containing either of these strings:

```text
Display Folders
G:\Shared drives
```

Do not copy configuration contents, OAuth material, passwords, tokens, or other protected values into Git.

## Deployment Consequence

The laptop investigation no longer supports any architecture that serves production FieldWiring images through the laptop.

The server-side image-source decision remains between infrastructure that can independently maintain or mount the authoritative Google Shared Drive hierarchy, with the first candidate still being a verified Synology-side synchronized tree if one already exists.

## Documentation Governance Note

During this reconnaissance, the Production Database repository's `System_Documentation/Standards/` was found to contain newer and more complete reusable standards than the corresponding copied standards in `MSB-Server-Management`.

For this work:

- current reusable documentation standards are taken from the Production Database repository's shared standards set;
- Production Database project rules remain authoritative for Production Database-specific governance; and
- `MSB-Server-Management` project rules remain authoritative for server-specific SSH/live-runtime and production-change handling.

Synchronizing the reusable standards into `MSB-Server-Management` is a separate documentation-maintenance task and should not be mixed into FieldWiring deployment changes.
