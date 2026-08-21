# FieldWiring Release Candidate Handoff and Development Runbook — 2026-08-21

| Document control | Value |
|---|---|
| Status | RELEASE CANDIDATE — laptop/browser acceptance complete; server/tablet/phone deployment pending |
| Sub-project | FieldWiring |
| Current branch | `agent/fieldwiring-engineering-recovery` |
| Production database snapshot proven | Run 51 |
| Parser / ingest | V7.0.11 / V0.4.2 |
| Owner | MSB Database Administrator |

## Purpose

This is the resume point for the FieldWiring application. It records the current architecture, code ownership, data contracts, accepted presentation behavior, development workflow, deployment boundary, and known limitations so future work does not require reconstructing the system from conversation history.

Use this document first when making FieldWiring application changes.

## Current Release-Candidate State

FieldWiring is a read-only browser application intended to replace the practical field-wiring outcome of FormView without changing LOR authority or permanent Production Database identity.

The current release candidate has been exercised on a Windows laptop against a verified SQLite engineering export of production PostgreSQL Run 51 and the live mapped Display Folders tree.

Proven current production data state:

```text
import_run_id          51
parser_version         V7.0.11
ingest_script_version  V0.4.2
current DMX rows       508
```

The Run 51 FieldWiring engineering snapshot was exported from `msb-prod-db`, passed SQLite `integrity_check`, and was SHA-256 verified after transfer to the laptop.

The V7.0.11 DMX source-detail contract is complete in the current snapshot:

```text
raw_prop_id
channel_name
channel_grid_row_number
```

with 508/508 rows populated and valid.

## Authority and Identity

Production authority remains:

```text
LOR
  -> Parser V7
  -> LOR2DB ingest/reconciliation
  -> PostgreSQL Production Database
  -> FieldWiring read-only presentation
```

Permanent Display identity is always:

```text
ref.display.display_id
```

For DMX source rows, the permanent identity path is:

```text
dmx row prop_id
  -> current canonical Prop
  -> canonical Prop raw_prop_id
  -> ref.display.lor_prop_id
  -> ref.display.display_id
```

`dmx.raw_prop_id` is source PropClass provenance only. It is not permanent Display or controller identity.

FieldWiring must not create controller identity from network name, IP address, Unit ID, universe, Channel Name, Display Name, or Channel Grid Row Number.

## Application Entry Points

Application source:

```text
FieldWiring/Application/
```

Local development entry:

```text
backend.py
```

Browser pages:

```text
/               lookup / Stage browse
/wiring         resolved FieldWiring workspace
/api/health     health/status
/api/displays   Display search
/api/stages     Stage/Scene browse data
/api/wiring     resolved wiring package
/api/wiring/image
                guarded published-image delivery
```

Current application version string remains `V0.2.0`; do not treat that string alone as the complete release-history mechanism.

## Code Map — Where to Change What

### `backend.py`

Flask host and HTTP routes. Chooses one repository mode from environment.

Do not put wiring interpretation here.

### `repository.py`

Production PostgreSQL and development SQLite data-access implementations.

Production sessions are read-only. The application must not write PostgreSQL.

### `wiring.py`

Top-level package assembler.

Sequence is intentionally:

```text
resolve Display/Stage/Preview/Scene context
  -> load normal current wiring data
  -> replace legacy DMX rows with V7.0.11 atomic DMX source rows
  -> apply physical presentation families
  -> apply DumbRGB fixture annotation
  -> apply reviewed E1.31 physical mappings
  -> resolve images
  -> build browser package + provenance
```

Change orchestration here only when a new presentation/data layer genuinely belongs in that pipeline.

### `wiring_data.py`

Loads the established current wiring/context data. The legacy compatibility wiring view remains useful for non-DMX behavior and FormView parity.

Do not rewrite `preview_wiring_*_v6` to carry new FieldWiring-only semantics.

### `wiring_dmx_source.py`

V7.0.11+ atomic DMX source adapter.

This is the FieldWiring-specific richer DMX read path. It replaces compatibility-view DMX rows in the resolved package with rows carrying:

```text
source_raw_prop_id
channel_name
channel_grid_row_number
start_universe
start_channel
end_channel
```

On V7.0.11+ it fails closed if the required source detail is unavailable.

### `wiring_presentation.py`

Core physical-presentation classification and A/C/Pixie grouping.

Current families:

```text
LOR + Traditional -> AC
LOR + RGB         -> PIXIE
DMX + DumbRGB     -> DUMBRGB
DMX + RGB         -> E131
other DMX         -> DMX
```

Also contains the reviewed A/C/Pixie grouping patterns recovered during FormView replacement.

### `wiring_dumbrgb.py`

DMX/DumbRGB fixture presentation metadata.

Current CR50 contract preserves three atomic RGB source rows per physical 5-channel fixture and annotates them for one technician-facing fixture instruction.

It never fabricates the two intentionally omitted CR50 function channels.

### `wiring_e131.py`

Centralized reviewed **temporary** E1.31 controller/output resolver.

This file is the current location for accepted physical mappings until Controller Inventory provides permanent controller identity/current-assignment data.

Current explicit mappings:

```text
TR-MegaTreeRGBTree
  Mega Tree Controller
  AlphaPix / Flex48
  Universes 1-48 -> Outputs 1-48

TR-MegaTreeRGBBall
  Mega Ball Controller
  PixCon 16
  Universes 49-64 -> Outputs 1-16

FT-MegaStar
  Mega Star Controller 1
  PixCon 16
  Universes 113-128 -> Outputs 1-16

FT-MegaStar
  Mega Star Controller 2
  PixCon 16
  Universes 129-140 -> Outputs 1-12
```

Unreviewed dense-RGB cases stay visibly unresolved. Do not generalize a formula merely because an address range appears contiguous.

RGB pixel count is derived only from a valid exact channel span divisible by three:

```text
(end_channel - start_channel + 1) / 3
```

### `wiring_images.py`

Guarded same-scope image resolver and image-delivery path safety.

Rules include:

- published `Wiring\BackgroundStage` / `Wiring\MusicalStage` images are supplemental wiring images;
- same-scope `PreviewBackground` may be shown only as context when no wiring image exists;
- a resolved Scene must not borrow a parent Stage wiring image merely because its own wiring image is absent;
- `SourceDocs` is not an application image source;
- source-folder markers remain part of the acceptance boundary.

### Browser layer

`wiring.js` — base workspace renderer, image navigation, split divider, Engineering Details.

`wiring_e131.js` — E1.31 technician table:

```text
OUTPUT / PORT
CHANNEL / DISPLAY SECTION
UNIVERSE
PIXELS
CHANNEL RANGE
```

`wiring_dumbrgb.js` — DMX/DumbRGB technician table:

```text
FIXTURE / CHANNEL
UNIVERSE
DMX START ADDRESS
RGB CHANNELS
```

`wiring_disclosure.js` — collapsible controller/presentation cards. First group opens initially; later groups may start collapsed. Print expands all groups.

`wiring_workspace_focus.js` + `wiring_workspace_focus.css` — shared laptop/desktop image/hookup workspace. Presets keep both panels visible:

```text
More Image   ~68 / 32
Balanced     ~50 / 50
More Hookup  ~30 / 70
```

The divider remains available for a custom split. `Hide Image` is the only control that removes the image.

`wiring_sticky_context.css` — long-list controller/column context rules. Mobile intentionally avoids consuming excessive permanent vertical space.

## Accepted Field Behavior

### A/C

Group by addressed controller context and show numbered physical output/plug. Shared rows on one output remain visible rather than being collapsed away.

### Pixie

Translate reviewed LOR Unit-ID patterns into physical Pixie output numbers. Do not teach Unit ID as if it were the physical plug number.

### E1.31 dense RGB

Where a reviewed temporary physical map exists, group by physical controller and show output/section/universe/pixel count/channel range.

Universe is addressing, not controller identity.

### DMX / DumbRGB / CR50

Northern Lights is the acceptance case.

Current real shape:

```text
66 fixtures
198 atomic RGB source rows
Universe 145: 32 fixtures
Universe 146: 34 fixtures
```

Each fixture is a physical 5-channel CR50 but only its three RGB channels are intentionally present in LOR.

Example:

```text
fixture start 1  -> RGB 1-3; channels 4-5 intentionally omitted
fixture start 6  -> RGB 6-8; channels 9-10 intentionally omitted
fixture start 11 -> RGB 11-13; channels 14-15 intentionally omitted
```

No pixel count is shown for CR50.

## Image UX

Laptop/desktop current baseline:

- image and Field Hookup share one bounded work area;
- presets bias the split while keeping both visible;
- divider remains draggable;
- wiring groups are independently collapsible;
- normal wiring images have no redundant `WIRING IMAGE` badge;
- context-only images keep a conspicuous `NO WIRING IMAGE AVAILABLE · CONTEXT IMAGE — NOT WIRING` warning;
- Engineering Details remains separately collapsible.

Phone/tablet acceptance is the next device-level UX gate.

## Development Mode

Install development requirements from the repository virtual environment:

```powershell
python -m pip install -r .\FieldWiring\Application\requirements-dev.txt
```

Run all application tests:

```powershell
python -m pytest .\FieldWiring\Application -q
```

Local verified-snapshot example:

```powershell
$env:FIELDWIRING_DEV_SNAPSHOT = 'C:\lor\FieldWiring-Snapshots\fieldwiring_snapshot_run_51_20260821T204440Z.db'
$env:FIELDWIRING_DRIVE_ROOT = 'G:\Shared drives\Display Folders'
python .\FieldWiring\Application\backend.py
```

Open:

```text
http://127.0.0.1:8790/
```

The SQLite snapshot is an engineering fixture only. Production must not run from an exported SQLite snapshot.

## Production Mode

Production mode uses:

```text
FIELDWIRING_DATABASE_DSN=<least-privilege read-only PostgreSQL DSN>
FIELDWIRING_DRIVE_ROOT=<server-visible read-only Display Folders root>
FIELDWIRING_TIMEZONE=America/Chicago
```

Do not deploy a PostgreSQL password into browser code or a static Synology directory.

The backend must use a dedicated least-privilege read-only database role.

## Important Server Image-Path Boundary

The currently accepted laptop resolver uses the Windows mapped root:

```text
G:\Shared drives\Display Folders
```

PostgreSQL Stage `folder_path` and LOR `BackgroundFile` evidence may also contain Windows paths.

A Linux production server does **not** automatically have that path. Before server deployment is accepted, the server must have a controlled read-only representation of the current Display Folders tree and FieldWiring must prove that stored Windows path evidence resolves deterministically to that server-visible root.

Do not solve this by copying random images into the application directory or by silently weakening the same-scope marker rules.

The actual server mount/synchronization mechanism must be established from the live infrastructure and documented in the server deployment record.

## Existing Display Scan Integration

Do not create another QR route.

The deployed Directus scan extension already resolves:

```text
/scan/DISP/:key
```

using permanent `display_id` and presents the Display task hub.

The intended integration is one new **Field Wiring** action on that existing hub, passing the already-resolved permanent Display identity into the FieldWiring application.

See:

- `../07_Labeling_and_Scanning/Deployed_Display_Scan_Runtime_Boundary.md`
- `FieldWiring_Server_Deployment_and_Scan_Integration_Plan_2026-08-21.md`

## Merge Gate

Before merging this feature branch to `main`:

1. bring current `main` into `agent/fieldwiring-engineering-recovery`;
2. resolve documentation conflicts deliberately rather than discarding either side;
3. run `python -m pytest .\FieldWiring\Application -q`;
4. run the parser/LOR2DB tests affected by any merge conflict if those files changed during integration;
5. smoke-test the laptop application against the verified Run 51 fixture;
6. verify the branch is no longer behind `main`;
7. merge through the normal repository PR/merge workflow.

At the time this document was written, the branch was 291 commits ahead of `main` and 8 commits behind it. Those 8 `main` commits are primarily current Google Drive/Display-folder documentation and must be integrated before merge.

## Known Open Work After Merge

- production server deployment;
- server-visible read-only Display Folders/image path;
- least-privilege production DB role/grant validation for FieldWiring;
- same-origin protected public route under `my.sheboyganlights.org`;
- add **Field Wiring** to the existing Display scan hub;
- tablet/phone acceptance;
- Controller Inventory replacement of temporary reviewed E1.31 controller mappings;
- Mega Cube / Whoville Matrix compact CustomGrid expansion remains a separate parser-materialization limitation; do not fabricate missing rows in FieldWiring;
- future plug/channel-label request integration through the existing LabelPrintService;
- offline/self-contained field copy remains a later accepted requirement, not part of this browser release candidate.

## FormView Cutover Rule

Merging FieldWiring code to `main` is **not** the same as retiring FormView.

Keep FormView as the fallback/reference until server deployment, scan integration, and field tablet/phone acceptance are explicitly completed.
