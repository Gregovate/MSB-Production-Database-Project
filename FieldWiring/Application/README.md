# FieldWiring Application

Status: **release candidate — server/tablet/phone deployment pending**

This folder contains the browser-based FieldWiring application.

For the complete recovery/development handoff, start with:

- `Docs/02_Production_Database/01_System_Architecture/09_Wiring_System/FieldWiring_Release_Candidate_Handoff_and_Development_Runbook_2026-08-21.md`
- `Docs/02_Production_Database/01_System_Architecture/09_Wiring_System/FieldWiring_Server_Deployment_and_Scan_Integration_Plan_2026-08-21.md`

## Current proven baseline

The current application has been exercised on a laptop against a SHA-verified SQLite engineering export of production PostgreSQL Run 51:

```text
import_run_id          51
parser_version         V7.0.11
ingest_script_version  V0.4.2
current DMX rows       508
```

The application is read-only and preserves the authority chain:

```text
LOR -> Parser V7 -> LOR2DB -> PostgreSQL -> FieldWiring
```

Permanent Display identity is `ref.display.display_id`.

## Application structure

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

wiring.js
    base browser renderer / image controls / Engineering Details

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

## Current presentation families

```text
LOR + Traditional -> A/C controller / numbered output
LOR + RGB         -> Pixie controller / numbered RGB output
DMX + DumbRGB     -> DMX fixture/network presentation
DMX + RGB         -> E1.31 dense RGB presentation
```

Current reviewed temporary E1.31 mappings are centralized in `wiring_e131.py` for:

- Mega Tree — AlphaPix / Flex48, Universes 1-48 -> Outputs 1-48;
- Mega Ball — PixCon 16, Universes 49-64 -> Outputs 1-16;
- Mega Star Controller 1 — PixCon 16, Universes 113-128 -> Outputs 1-16;
- Mega Star Controller 2 — PixCon 16, Universes 129-140 -> Outputs 1-12.

These mappings are presentation recovery evidence, not permanent Controller Inventory identity.

Northern Lights is the current DMX/DumbRGB acceptance case: 66 CR50 fixtures represented by 198 atomic RGB source rows. The normal technician table groups three RGB rows into one fixture instruction without fabricating the two intentionally omitted CR50 function channels.

## Current browser UX baseline

Desktop/laptop:

- image + Field Hookup remain visible together in one shared work area;
- `More Image`, `Balanced`, and `More Hookup` presets bias the split;
- divider remains draggable for a custom split;
- `Hide Image` is the only control that removes the image;
- controller/presentation cards are independently collapsible;
- normal wiring images do not show a redundant badge;
- context-only images retain the conspicuous `NO WIRING IMAGE AVAILABLE · CONTEXT IMAGE — NOT WIRING` warning;
- Engineering Details remains collapsible.

Tablet/phone field acceptance is the next device-level gate.

## Data modes

### Production

```text
FIELDWIRING_DATABASE_DSN=<least-privilege read-only PostgreSQL DSN>
FIELDWIRING_DRIVE_ROOT=<server-visible read-only Display Folders root>
FIELDWIRING_TIMEZONE=America/Chicago
```

Production must not set `FIELDWIRING_DEV_SNAPSHOT`.

### Development snapshot

```text
FIELDWIRING_DEV_SNAPSHOT=C:\path\to\fieldwiring_snapshot.db
FIELDWIRING_DRIVE_ROOT=G:\Shared drives\Display Folders
```

The SQLite snapshot is an engineering fixture only.

## Development/test environment

From the repository virtual environment:

```powershell
python -m pip install -r .\FieldWiring\Application\requirements-dev.txt
python -m pytest .\FieldWiring\Application -q
```

Run locally:

```powershell
$env:FIELDWIRING_DEV_SNAPSHOT = 'C:\lor\FieldWiring-Snapshots\fieldwiring_snapshot_run_51_20260821T204440Z.db'
$env:FIELDWIRING_DRIVE_ROOT = 'G:\Shared drives\Display Folders'
python .\FieldWiring\Application\backend.py
```

Open:

```text
http://127.0.0.1:8790/
```

Health:

```text
GET /api/health
```

Expected development mode includes:

```json
{"data_mode":"sqlite-dev","status":"ok","version":"V0.2.0"}
```

## Production image-path warning

The accepted laptop resolver currently sees the source tree through:

```text
G:\Shared drives\Display Folders
```

A Linux production server does not automatically have that path. Before server deployment is accepted, establish a controlled read-only server-visible Display Folders tree and prove deterministic translation from stored Windows `folder_path` / `BackgroundFile` evidence to that server root.

Do not copy ad-hoc images into the application directory or weaken the same-scope/source-marker rules to make deployment easier.

## Existing Display QR dependency

The deployed Display QR hub already exists in the Directus scan extension on `msb-prod-db` and resolves permanent `display_id`.

FieldWiring must not create a second QR identity or scan engine.

The intended integration is one new **Field Wiring** action on the existing `/scan/DISP/:key` hub, passing only the already-resolved permanent `display_id` into the FieldWiring application.

## Merge/deployment state

Merging FieldWiring to `main` is appropriate after the feature branch is brought current with `main` and the full tests pass again.

At the release-candidate checkpoint the branch was 291 commits ahead of `main` and 8 commits behind it, so update the branch before merging.

Merging code is not the same as production cutover. Keep FormView available until:

1. FieldWiring is deployed on the server using live read-only PostgreSQL;
2. the server can resolve the approved Display Folders/image source;
3. the protected public route is working;
4. tablet/phone testing is accepted;
5. the existing Display scan hub exposes Field Wiring successfully.
