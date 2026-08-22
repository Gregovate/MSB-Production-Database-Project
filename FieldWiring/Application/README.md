# FieldWiring Application

Status: **production-operational — Display scan-hub integration in progress**

This folder contains the browser-based FieldWiring application.

## Current State

FieldWiring is production-operational as of 2026-08-22 at:

```text
https://my.sheboyganlights.org/fieldwiring/
```

Accepted production state:

- live read-only PostgreSQL backend;
- systemd-hosted service operational on `192.168.5.9:8790`;
- persistent read-only Google `Display Folders` filesystem operational;
- protected Synology reverse proxy operational;
- desktop and phone acceptance passed;
- Display search repaired and production-tested;
- FormView remains available as fallback/reference.

The remaining active milestone is adding **Field Wiring** to the existing permanent Display QR task hub.

For current engineering work, start with:

- `Docs/02_Production_Database/01_System_Architecture/07_Labeling_and_Scanning/FieldWiring_Scan_Integration_Engineering_Handoff_2026-08-22.md`
- `Docs/02_Production_Database/01_System_Architecture/07_Labeling_and_Scanning/Deployed_Display_Scan_Runtime_Boundary.md`
- `Docs/02_Production_Database/01_System_Architecture/09_Wiring_System/README.md`

## Authority Chain

The application is read-only and preserves:

```text
LOR -> Parser V7 -> LOR2DB -> PostgreSQL -> FieldWiring
```

Permanent Display identity is:

```text
ref.display.display_id
```

FieldWiring must not create a competing topology or asset-identity system.

## Application Structure

```text
backend.py
    Flask host / routes / health

repository.py
    PostgreSQL production repository
    SQLite development-snapshot repository

wiring.py
    top-level package assembler

wiring_data.py
    normal current wiring/context loader

wiring_dmx_source.py
    V7.0.11+ atomic DMX source-detail adapter

wiring_presentation.py
    A/C / Pixie / DMX family classification and physical presentation

wiring_dumbrgb.py
    CR50 / DumbRGB fixture annotation

wiring_e131.py
    reviewed temporary E1.31 physical controller/output mappings

wiring_images.py
    guarded same-scope image resolver and image delivery

fieldwiring.js
    Display/Stage lookup landing page

wiring.js
    base wiring renderer / image controls / Engineering Details

wiring_e131.js
    E1.31 technician table

wiring_dumbrgb.js
    DMX/DumbRGB technician table

wiring_disclosure.js
    collapsible controller/presentation cards

wiring_sticky_context.css
    long-list controller/table header behavior

wiring_workspace_focus.js
wiring_workspace_focus.css
    shared image + Field Hookup desktop/laptop workspace
```

## Current Presentation Families

```text
LOR + Traditional -> A/C controller / numbered output
LOR + RGB         -> Pixie controller / numbered RGB output
DMX + DumbRGB     -> DMX fixture/network presentation
DMX + RGB         -> E1.31 dense RGB presentation
```

Current reviewed temporary E1.31 mappings remain presentation recovery evidence and are not permanent Controller Inventory identity.

## Production Data Mode

Production uses:

```text
FIELDWIRING_DATABASE_DSN=<least-privilege read-only PostgreSQL DSN>
FIELDWIRING_DRIVE_ROOT=<server-visible read-only Display Folders root>
FIELDWIRING_TIMEZONE=America/Chicago
```

Production must not use `FIELDWIRING_DEV_SNAPSHOT`.

Current accepted health payload:

```json
{"data_mode":"postgres","status":"ok","version":"V0.2.0"}
```

## Development Snapshot Mode

Development/engineering may use an explicit read-only snapshot:

```text
FIELDWIRING_DEV_SNAPSHOT=C:\path\to\fieldwiring_snapshot.db
FIELDWIRING_DRIVE_ROOT=G:\Shared drives\Display Folders
```

The SQLite snapshot is an engineering fixture only and must not become the production data source.

## Development / Test

From the repository virtual environment:

```powershell
python -m pip install -r .\FieldWiring\Application\requirements-dev.txt
python -m pytest .\FieldWiring\Application -q
```

Local development example:

```powershell
$env:FIELDWIRING_DEV_SNAPSHOT = 'C:\path\to\fieldwiring_snapshot.db'
$env:FIELDWIRING_DRIVE_ROOT = 'G:\Shared drives\Display Folders'
python .\FieldWiring\Application\backend.py
```

Open:

```text
http://127.0.0.1:8790/
```

## Display Deep-Link Contract

The current Display QR integration must use:

```text
/fieldwiring/wiring.html?display_id=<permanent display_id>
```

Important distinction:

- `fieldwiring.js` powers the landing/search page and does **not** consume `display_id` from the landing-page URL.
- `wiring.js` consumes `display_id`, forwards it to `api/wiring`, and renders the resolved package.
- `wiring.py`/`repository.py` re-resolve the current Stage/Preview/Scene context from PostgreSQL.

The scan hub should therefore pass only permanent `display_id`.

Do not pass Stage, Preview, Scene, LOR UUID, controller address, Google Drive path, or import-run identity from the physical QR/scan hub.

## Existing Display QR Dependency

The deployed Display QR hub already exists in the Directus scan extension on `msb-prod-db`:

```text
/opt/directus/extensions/directus-extension-scan/
```

The current scan hub resolves permanent `display_id` and already provides independent Display, Testing, Container, and Work Order actions.

FieldWiring must remain a downstream consumer. The scan hub must not depend on FieldWiring availability to render or operate its other actions.

Current intended action:

```text
Field Wiring
    -> /fieldwiring/wiring.html?display_id=<display_id>
```

No FieldWiring backend change is required merely to support this link.

## Server Runtime Boundary

Application/business source remains in this repository.

Server runtime details — systemd service, persistent Display Folders mount, Synology reverse proxy, deployment/restart/recovery, and Directus scan-extension runtime — belong in `Gregovate/MSB-Server-Management`.

Do not copy secrets or protected runtime configuration into either repository.

## Current Open Work

- recover/preserve the accepted current Directus scan implementation in Git-controlled source/deployment form;
- add the independent Field Wiring action to `/scan/DISP/:key`;
- regression-test all existing scan routes and camera/manual scanning;
- test a real permanent Display QR into FieldWiring;
- update both repository handoffs after acceptance;
- keep FormView available until a separate cutover decision.

## Resume Development

1. Read `FieldWiring_Scan_Integration_Engineering_Handoff_2026-08-22.md`.
2. Read the current Labeling/Scanning and Wiring README handoffs.
3. Read the matching MSB-Server-Management Directus/FieldWiring runtime handoffs.
4. Preserve/recover the accepted current camera-enabled scan implementation in Git.
5. Make the minimal Field Wiring action change only.
6. Run the complete scan regression/acceptance matrix.
7. Update both repository handoffs before closing the work.

After this scan integration is accepted, Setup/Deployment becomes the next separate engineering project. Its expected high-volume Container/Location scanning should be designed from the actual setup-day workflow rather than by refactoring FieldWiring-specific code.
