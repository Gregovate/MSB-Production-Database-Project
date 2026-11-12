# FieldWiring Server Deployment Reconnaissance — 2026-08-21

| Document control | Value |
|---|---|
| Status | RECONNAISSANCE — repository evidence recorded; live runtime verification still required |
| Sub-project | FieldWiring |
| Production Database repository baseline | `main` after PR #29 merge, commit `17d0aed42cebe1c1386c515856268e607663b1b1` |
| Production backend host | `msb-prod-db` / `192.168.5.9` |
| Public site | `https://my.sheboyganlights.org/` |
| Existing Display scan runtime | `/opt/directus/extensions/directus-extension-scan/` on `msb-prod-db` |
| Server-management repository | `Gregovate/MSB-Server-Management` |
| Production-change status | NONE — no deployment, schema, service, proxy, scan, or database change made |

## Purpose

This document is the repository-side reconnaissance checkpoint for moving the accepted FieldWiring browser release candidate off the development laptop and into the existing protected MSB server environment.

It supplements, but does not replace:

- `FieldWiring_Release_Candidate_Handoff_and_Development_Runbook_2026-08-21.md`;
- `FieldWiring_Server_Deployment_and_Scan_Integration_Plan_2026-08-21.md`;
- `../07_Labeling_and_Scanning/Deployed_Display_Scan_Runtime_Boundary.md`;
- `../../../../FieldWiring/Application/README.md`; and
- the separate `Gregovate/MSB-Server-Management` repository.

The purpose of this checkpoint is to separate facts already confirmed from Git-controlled material from facts that still require read-only inspection of the laptop, `msb-prod-db`, and the Synology before a deployment architecture is finalized.

## Non-Negotiable Deployment Boundaries

The current requirements remain:

- FieldWiring must run from server infrastructure and must not depend on the operator laptop or Flask development server.
- Production data must come from live PostgreSQL through a dedicated least-privilege read-only role.
- The existing Display QR identity and Directus Display task hub must be preserved.
- Field Wiring is an additive task destination from the already-resolved permanent `ref.display.display_id`.
- Manual browser lookup by Display and Stage/Scene must remain available without a scan.
- Published wiring/context images must be resolved from the authoritative Display Folders hierarchy without depending on a Windows `G:` mapping on the operator laptop.
- Source-folder marker, Scene/Stage scope, `SourceDocs` exclusion, and context-only-image warning rules must remain unchanged.
- FormView remains the production fallback/reference until server, scan, tablet, and phone acceptance is complete.

## Repository-Confirmed Current State

### FieldWiring application

The application already has separate production and development repository modes.

Production mode uses:

```text
FIELDWIRING_DATABASE_DSN=<read-only PostgreSQL DSN>
FIELDWIRING_DRIVE_ROOT=<server-visible Display Folders root>
FIELDWIRING_TIMEZONE=America/Chicago
```

`PostgresRepository` sets each PostgreSQL connection to a read-only session. This application-level protection does not replace the requirement for a dedicated least-privilege PostgreSQL role.

The current browser already supports:

- Display search;
- typed permanent Display ID / `DISP:<id>` resolution;
- Stage browse;
- Scene/context browse; and
- opening the resolved Field Wiring package.

Therefore manual lookup is an existing FieldWiring capability that should be preserved during deployment rather than replaced by a second lookup application.

### Existing Display scan runtime

The existing Display QR route is a deployed Directus endpoint extension on `msb-prod-db`:

```text
/opt/directus/extensions/directus-extension-scan/
```

Repository documentation identifies current routes including:

```text
/scan/
/scan/DISP/:key
/scan/DISP/:key/test
/scan/DISP/:key/container
/scan/DISP/:key/work-orders
```

The hub already resolves permanent `ref.display.display_id`.

The FieldWiring integration must therefore be the smallest additive change to this existing hub. The scan extension must not become dependent on FieldWiring availability for its existing destinations.

The current repository documentation does **not** identify a deployed Procedures action on this hub. The new requirement that the task menu include Procedures as applicable must be reconciled against the live extension and the current Procedures application/runtime before any scan-hub change is designed.

### Proven server/browser deployment pattern

`MSB-Server-Management` documents the current LOR Preflight deployment pattern:

```text
browser
  -> protected my.sheboyganlights.org on Synology Web Station
  -> same-origin Synology nginx proxy
  -> Gunicorn service on msb-prod-db
  -> PostgreSQL
```

Verified Preflight locations from the current documentation include:

```text
backend host       192.168.5.9
backend install    /opt/lor-preflight
systemd service    lor-preflight-api.service
backend listener   192.168.5.9:8784
Synology web root  /volume1/web/my
```

The documented Synology custom nginx include is:

```text
/usr/local/etc/nginx/conf.d/44755fe6-c616-423e-a026-028752779047/user.conf
```

This is a proven deployment pattern, not proof that FieldWiring should be installed before current listeners, paths, authentication, and Synology configuration are rechecked live.

### Existing Linux-to-Synology mounted-filesystem pattern

`MSB-Server-Management/scripts/backup_to_nas.sh` confirms that `msb-prod-db` already depends on a mounted Synology share for backup replication:

```text
Synology share: \\192.168.5.4\db_server_backups\msb-prod-db
Linux mount:    /mnt/db_server_backups
```

The script verifies the mount with `mountpoint` before use.

This establishes that a controlled Linux-to-Synology filesystem mount is already an operational pattern in the environment.

It does **not** prove that the Google Shared Drive `Display Folders` tree is currently synchronized to the Synology or exposed through a suitable NAS share. That must be checked live before selecting an image-access mechanism.

## Confirmed Deployment Compatibility Gaps

These are application/deployment gaps visible directly in the merged source. They are not reasons to redesign the data model.

### 1. Windows-path evidence is not yet translated to a Linux server root

The current image resolver accepts a configurable `FIELDWIRING_DRIVE_ROOT`, but stored Stage `folder_path` and LOR Preview/Scene `BackgroundFile` evidence is still converted directly to `Path(...)` and tested with filesystem `.exists()` behavior.

On Windows, that works with evidence such as:

```text
G:\Shared drives\Display Folders\...
```

On Linux, mounting the same logical tree at a path such as `/mnt/...` does not make `G:\...` a valid Linux filesystem path.

Therefore server deployment needs a small deterministic path-root translation layer that:

1. recognizes stored paths under the canonical Windows Display Folders root;
2. strips only that canonical root;
3. maps the remaining relative path beneath `FIELDWIRING_DRIVE_ROOT`;
4. preserves the original stored path as provenance/evidence;
5. keeps all existing source-marker, Scene/Stage scope, and `SourceDocs` rules unchanged; and
6. fails visibly if the path cannot be translated safely.

Do not rewrite stored PostgreSQL path evidence merely to make Linux deployment easier.

### 2. The browser is not currently route-prefix aware

The accepted application currently uses root-absolute browser routes including:

```text
/api/displays
/api/stages
/api/wiring
/api/wiring/image
/wiring
```

The planned public route is under:

```text
/fieldwiring/
```

A simple reverse proxy of the unmodified browser application under `/fieldwiring/` would therefore allow browser requests to escape the intended prefix unless the public routing arrangement compensates for it.

Before deployment, choose and test one controlled approach:

- make FieldWiring browser/application URLs prefix-aware; or
- deliberately split static/public paths and API proxy paths in the Synology configuration, following the established same-origin principle.

Do not create unrelated root-level `/api` or `/wiring` public routes merely to avoid fixing the deployment boundary.

### 3. Gunicorn is not currently in FieldWiring runtime requirements

`FieldWiring/Application/requirements.txt` currently contains Flask, psycopg2-binary, and tzdata, but not Gunicorn.

If the production service follows the existing Preflight Gunicorn pattern, the runtime dependency and invocation must be explicitly controlled and documented before installation.

### 4. Dedicated FieldWiring PostgreSQL grants are not yet defined in the repository

The application enforces read-only sessions, but no repository-defined `fieldwiring` production role/grant artifact was found during this reconnaissance.

Before deployment, enumerate the exact relations consumed by the current application and grant only required `USAGE`/`SELECT` access. Do not grant write or DDL privileges as a deployment shortcut.

## Laptop `G:` Provider — Not Yet Verified

Repository evidence proves that the laptop acceptance environment can read:

```text
G:\Shared drives\Display Folders
```

It does not identify which Windows process/service provides `G:` or whether another local service is already exposing that tree.

This must be checked on the laptop rather than inferred.

Read-only inspection should identify:

- the `G:` drive provider/type;
- whether Google Drive for desktop, rclone, another sync client, or another provider owns it;
- whether the provider is a user-session desktop process or a Windows service;
- whether any local HTTP/file-serving service is already exposing Display Folders; and
- whether any existing cloud authorization model is reusable for a server-side solution without reusing laptop-local state.

A laptop desktop-sync process is not itself an acceptable production server dependency. At most, its access/account model may provide useful evidence for selecting an independent server-side read-only mechanism.

## Server Image-Source Candidates to Verify — No Selection Yet

The image architecture must be selected from live evidence.

### Candidate A — Synology holds a current synchronized Display Folders tree

If the Synology already has a reliable synchronized representation of the Google Shared Drive `Display Folders` hierarchy, this is the first candidate to evaluate because:

- Synology is already part of the protected web/runtime environment;
- `msb-prod-db` already uses a mounted Synology share for another operational purpose; and
- the FieldWiring service could receive read-only filesystem access without making the laptop a dependency.

Required verification includes sync source, sync direction, freshness, exact NAS path, ownership/permissions, Shared Drive behavior, preservation of names/markers, and failure behavior.

### Candidate B — Dedicated server-side Google Drive synchronization/mount

If the Synology does not already maintain the required tree, evaluate a dedicated server-side read-only Google Drive synchronization/mount mechanism on the appropriate host.

This would be a new server dependency and therefore requires explicit documentation of:

- software/service ownership;
- authorization source without storing secrets in Git;
- Shared Drive selection;
- local mount/sync path;
- read-only behavior;
- startup/recovery;
- freshness monitoring; and
- backup/rollback boundaries.

No mechanism is selected by this reconnaissance document.

### Rejected deployment shortcuts

Do not accept any of the following as the production image architecture:

- dependence on the operator laptop remaining online;
- dependence on a Windows `G:` mapping on the server;
- ad-hoc copying of selected images into the FieldWiring application directory;
- weakening source-folder marker or `SourceDocs` exclusions;
- using Google Drive path/URL as Display identity; or
- embedding image/document identity into physical Display QR labels.

## Live Read-Only Inspection Required Before Architecture Decision

### Laptop

Collect the `G:` provider and local service/process inventory.

Suggested PowerShell evidence:

```powershell
Get-PSDrive G | Format-List *

Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='G:'" |
    Select-Object DeviceID, DriveType, ProviderName, VolumeName

Get-Volume -DriveLetter G |
    Format-List DriveLetter, FileSystem, FileSystemLabel, Path, HealthStatus

Get-CimInstance Win32_Service |
    Where-Object {
        $_.Name -match 'Google|Drive|rclone|sync' -or
        $_.DisplayName -match 'Google|Drive|rclone|sync' -or
        $_.PathName -match 'Google|DriveFS|rclone'
    } |
    Select-Object Name, DisplayName, State, StartMode, PathName

Get-CimInstance Win32_Process |
    Where-Object {
        $_.Name -match 'GoogleDriveFS|rclone|drive|sync' -or
        $_.CommandLine -match 'GoogleDriveFS|rclone|Display Folders'
    } |
    Select-Object ProcessId, Name, ExecutablePath, CommandLine

Get-NetTCPConnection -State Listen |
    Sort-Object LocalPort |
    Select-Object LocalAddress, LocalPort, OwningProcess,
        @{n='Process';e={(Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue).ProcessName}}
```

Do not copy OAuth tokens, credentials, or protected configuration into the repository.

### `msb-prod-db`

Read-only runtime inventory should confirm:

```bash
hostnamectl
ip -br addr
sudo ss -ltnp
systemctl --type=service --state=running
sudo docker ps
findmnt
df -hT
sudo systemctl status lor-preflight-api.service
curl -i http://192.168.5.9:8784/health
```

Then inspect without editing:

- `/opt/directus/extensions/directus-extension-scan/`;
- the Directus container mounts/network relationship;
- current mounted NAS shares and mount definitions;
- available internal ports;
- existing service-account conventions; and
- current PostgreSQL role/grant patterns.

### Synology / `my.sheboyganlights.org`

Read-only inspection should confirm:

- current Web Station document root;
- active nginx service UUID/include;
- current `my.sheboyganlights.org` proxy locations;
- Cloudflare/protected-origin assumptions;
- installed synchronization packages/services;
- whether Google Shared Drive `Display Folders` is already synchronized anywhere on the NAS;
- the exact NAS path and update/failure behavior if it exists; and
- whether a dedicated read-only share can be exposed to `msb-prod-db` without granting write access.

The existing Preflight nginx include must be treated as live evidence and compared with repository documentation before any proxy edit.

### Directus Display scan extension

Before proposing the task-menu change, inspect and record:

- source files and/or built `dist/index.js`;
- package/build method if present;
- current route definitions;
- current Display lookup and permanent `display_id` resolution;
- current Testing, Container, Work Order, and Display actions;
- whether any Procedures action/runtime already exists but is not documented;
- backup/rollback procedure; and
- exact Directus reload/restart procedure.

Do not modify or restart Directus during this reconnaissance pass.

## Provisional Deployment Shape — Subject to Live Verification

The existing documentation and Preflight deployment make this the leading architecture to validate, not yet the approved installation:

```text
QR scan --------------------+
                            |
Manual Display/Stage/Scene -+--> protected my.sheboyganlights.org
                                      |
                                      +--> existing Directus Display task hub
                                      |       -> Field Wiring action uses display_id
                                      |
                                      +--> /fieldwiring/
                                              |
                                              v
                                      Synology same-origin proxy
                                              |
                                              v
                                      FieldWiring Gunicorn service
                                      on msb-prod-db
                                              |
                            +-----------------+------------------+
                            |                                    |
                            v                                    v
                    live PostgreSQL                    read-only current
                    least-privilege                    Display Folders tree
```

The QR and manual lookup paths must converge on the same current Production Database identity/context rules.

## Acceptance Sequence After Reconnaissance

No acceptance gate begins until the live inspection above is documented.

1. **Document current runtime** in the responsible Production Database and Server Management records, including the scan extension and chosen image-source dependency.
2. **Resolve deployment compatibility gaps** in a development/test branch: Linux path-root translation, `/fieldwiring/` prefix behavior, production WSGI dependency/configuration, and exact least-privilege read contract.
3. **Install internal backend only** on `msb-prod-db` with no public cutover, then verify health and `data_mode=postgres`.
4. **Validate live PostgreSQL read-only behavior** with representative A/C, Pixie, E1.31, DMX/DumbRGB, Stage, Scene, and no-image/context-image cases.
5. **Validate server image parity** against the accepted laptop behavior, including source markers and Scene-specific no-parent-borrow rules.
6. **Publish behind the existing protected origin** and verify prefix/static/API/image behavior through the Synology proxy.
7. **Test laptop, tablet, and phone** from the normal protected URL in portrait/landscape where applicable.
8. **Add Field Wiring to the existing Display scan hub** only after the standalone public route is stable. Preserve all existing actions and verify that a FieldWiring outage does not disable them.
9. **Reconcile the Procedures task-menu requirement** with the actual Procedures subsystem/runtime; do not implement procedure ownership inside FieldWiring.
10. **Keep FormView available** throughout field acceptance and rollback testing.

## Go/No-Go Criteria Before Field Cutover

FieldWiring is not ready to replace FormView until all of the following are proven:

- production health reports PostgreSQL mode, never the development SQLite snapshot;
- a dedicated read-only database role is in use and its grants are documented;
- no normal request depends on the operator laptop or a Windows `G:` drive mapping;
- the current published Display Folders source is available read-only on the server;
- Windows path evidence maps deterministically to the server root without rewriting authority data;
- representative wiring images match the accepted laptop scope behavior;
- `/fieldwiring/` works correctly as a protected same-origin route;
- manual Display/Stage/Scene lookup works from laptop, tablet, and phone;
- the existing Display QR still resolves the same permanent `display_id` and existing task actions;
- Field Wiring is an additive task action only;
- Procedures ownership/routing is defined by its responsible subsystem;
- rollback can remove/disable FieldWiring without changing physical QR labels or PostgreSQL/LOR data; and
- FormView remains immediately available during the acceptance period.

## Documentation Ownership Going Forward

### MSB Production Database repository

Record:

- FieldWiring application behavior and deployment contract;
- identity/context rules;
- read-model expectations;
- path translation behavior;
- scan-to-FieldWiring contract; and
- application tests/acceptance results.

### MSB-Server-Management repository

Record the verified deployed runtime, including:

- actual FieldWiring install path;
- service account;
- virtual environment and dependencies;
- systemd/Gunicorn unit and internal port;
- environment-file location without secret values;
- PostgreSQL credential-source location;
- Display Folders synchronization/mount mechanism and mount path;
- Synology proxy configuration and protected-origin assumptions;
- scan-extension backup/rebuild/restart procedure;
- service health checks;
- startup/recovery behavior;
- update/restart/rollback commands; and
- backup/recovery requirements.

No production deployment should be considered complete until this runtime record exists.
