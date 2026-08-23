# FieldWiring Server Deployment Reconnaissance Addendum — 2026-08-21

| Document control | Value |
|---|---|
| Status | RECONNAISSANCE ADDENDUM — laptop process evidence and documentation-governance comparison |
| Parent | `FieldWiring_Server_Deployment_Reconnaissance_2026-08-21.md` |
| Production-change status | NONE |

## Purpose

Record new durable evidence gathered after the initial repository reconnaissance without changing production architecture or runtime.

## Laptop Google Drive Evidence

Read-only PowerShell inspection on the FieldWiring acceptance laptop found the following relevant processes/services:

```text
GoogleDriveFS.exe
  C:\Program Files\Google\Drive File Stream\129.0.1.0\GoogleDriveFS.exe
  two running processes observed

GoogleDriveFS listener
  ::1:7679
  loopback-only listener

GoodSync Server
  service: GsServer
  process listener: 127.0.0.1:11000 and 127.0.0.1:33333

Synology Drive VSS Service x64
  running Windows service
```

### What this establishes

- Google Drive for desktop / Drive File Stream is installed and running on the laptop.
- Its observed TCP listener is local-loopback only; this evidence does not show the laptop exposing Google Drive content as a network file service usable by FieldWiring production.
- GoodSync Server is also present, but the supplied evidence does not show that it owns the `G:` drive or the Display Folders hierarchy.
- Synology Drive VSS support is present, but the supplied evidence does not establish a Synology Drive synchronization relationship for Display Folders.

### What is not yet proven

The supplied process/service/listener evidence strongly supports Google Drive for desktop as the likely provider behind the laptop's Google Shared Drive access, but it does not by itself bind the Windows `G:` drive letter to GoogleDriveFS.

Direct `G:` drive evidence is still required from commands such as:

```powershell
Get-PSDrive G | Format-List *
Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='G:'" |
    Select-Object DeviceID, DriveType, ProviderName, VolumeName
Get-Volume -DriveLetter G |
    Format-List DriveLetter, FileSystem, FileSystemLabel, Path, HealthStatus
```

Do not document `G:` ownership as a proven fact until the drive-specific evidence is captured.

## Laptop Production-Dependency Conclusion

Nothing in the supplied listener inventory indicates an existing laptop-hosted network service that should be reused as the production FieldWiring image source.

Even if the `G:` attribution is confirmed as Google Drive for desktop, the laptop process must remain a development/engineering access mechanism only. Production must independently obtain read-only access to the authoritative Display Folders hierarchy.

## Documentation Governance Drift

A comparison of the two repositories shows that the reusable `System_Documentation/Standards` copy in `Gregovate/MSB-Server-Management` is materially behind the current standards in `Gregovate/MSB-Production-Database-Project`.

### Production Database current standards include

```text
Document_Control_Standard.md
Documentation_Maintenance_Rule.md
Documentation_Standards.md
Linking_and_Navigation_Standard.md
Markdown_Style_Guide.md
Operational_SOP_Standard.md
Prompt_Guidelines.md
README.md
README_Portal_Standard.md
Revision_History_Standard.md
System_Boundary_and_Repository_Ownership_Standard.md
```

### Server Management currently lacks or trails important standards

Observed examples:

- `Document_Control_Standard.md` in Server Management is an empty placeholder while the Production Database copy is populated.
- `Documentation_Maintenance_Rule.md` is absent from Server Management.
- `Operational_SOP_Standard.md` is absent from Server Management.
- `System_Boundary_and_Repository_Ownership_Standard.md` is absent from Server Management.
- `Documentation_Standards.md`, `Linking_and_Navigation_Standard.md`, `Prompt_Guidelines.md`, and `README_Portal_Standard.md` are older/shorter Server Management revisions than the current Production Database copies.

## Governing Rule During FieldWiring Deployment Work

Until the reusable standards are deliberately reconciled, use the current reusable standards in the Production Database repository as the documentation-framework baseline for this cross-repository FieldWiring deployment work.

Continue to apply Server Management's project-specific live-runtime rules where they address server-specific behavior, including:

- inspect live runtime before assuming repository procedures match production;
- treat `/opt/...` as deployed runtime rather than interchangeable repository source;
- gather evidence before production changes;
- preserve rollback capability;
- keep secrets out of Git; and
- update the responsible repository after an approved runtime change.

Do not blindly overwrite Server Management standards with Production Database project-specific rules. The Production Database repository explicitly distinguishes reusable cross-project standards from Production Database-only project rules.

## Repository-Ownership Implication for FieldWiring

The current `System_Boundary_and_Repository_Ownership_Standard` confirms the intended split:

### Production Database repository owns

- FieldWiring authority/integration contract;
- PostgreSQL identities and relationships;
- LOR/LOR2DB authority boundary;
- FieldWiring read contract;
- scan-to-FieldWiring identity/context behavior; and
- cross-system dependency/failure boundaries.

### Server Management repository owns

- actual deployed server runtime record;
- service/process management;
- installation paths and service account;
- internal listener/port;
- Synology mount/synchronization details;
- proxy configuration;
- protected configuration locations;
- health/restart/rollback/recovery procedures; and
- operational infrastructure dependencies.

This split should be preserved. Server Management must not become a competing source for FieldWiring business/data rules, while the Production Database repository must not become a duplicate server-operations manual.

## Documentation Maintenance Requirement

The current Production Database `Documentation_Maintenance_Rule.md` requires durable reverse-engineering discoveries to be promoted from conversation into the responsible repository documentation.

This addendum records the current laptop and cross-repository governance discoveries. Once live `msb-prod-db` and Synology evidence is collected, the resulting actual runtime facts must be recorded in the responsible Server Management deployment/runbook documentation rather than left only in the Production Database reconnaissance notes.
