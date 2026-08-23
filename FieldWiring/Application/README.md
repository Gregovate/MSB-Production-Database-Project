# FieldWiring Application

Status: **production-operational — shared resolver architecture accepted; extraction deployment pending**

This folder contains the browser-based FieldWiring application.

## Current State

FieldWiring is production-operational at:

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
- existing Display Scan hub exposes the independent **Field Wiring** action;
- FormView remains available as fallback/reference.

Accepted engineering state:

- the proven Stage/Sub-stage/Scene resolver has been extracted from `wiring_images.py` into task-neutral `field_context_resolver.py`;
- complete FieldWiring regression suite passed: `54 passed in 1.01s`;
- a live candidate using production PostgreSQL + mounted Google files matched the production resolver output for Display `312`;
- production deployment of the extraction is still a separate server-management step.

For current engineering/recovery state, start with:

- `Docs/02_Production_Database/01_System_Architecture/09_Wiring_System/FieldWiring_Shared_Structured_Scope_Resolver_Extraction_2026-08-22.md`
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

field_context_resolver.py
    task-neutral marked Stage/Sub-stage/Scene structured-scope resolver
    shared infrastructure for FieldWiring and future Procedure callers

wiring_images.py
    FieldWiring adapter after scope resolution
    selects Wiring branch, enumerates wiring/context images, and safely serves images

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

## Shared Structured-Scope Boundary

`field_context_resolver.py` owns only the common hierarchy decision:

```text
current Stage / Scene / Preview facts
    + controlled path evidence
    + marked Display Folders hierarchy
        -> fixed marked Stage/Sub-stage/Scene scope_root
```

It preserves the production resolver behavior for path translation, marked-root validation, stale-path recovery, bounded Scene matching, ambiguity rejection, `SourceDocs` protection, and visible warning behavior.

After that common result is fixed, `wiring_images.py` owns the FieldWiring-specific branch:

```text
scope_root
    -> Wiring/MusicalStage
       OR Wiring/BackgroundStage
    -> direct wiring images
    -> same-scope PreviewBackground context when allowed
```

Future Procedure work must consume `field_context_resolver.resolve_structured_scope(...)` as a second caller rather than copy the resolver algorithm or reuse FieldWiring's Wiring-specific adapter.

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

## Accepted FieldWiring Marker Contract

The production-aligned marker rule is:

```text
<resolved Stage / Sub-stage / Scene root>  marker required
Wiring                                     marker required
PreviewBackground                          marker required when used for controlled same-scope context
Wiring\BackgroundStage                     NO separate marker
Wiring\MusicalStage                        NO separate marker
SourceDocs                                 excluded / no marker
```

The marker on `Wiring` guards the selected `BackgroundStage` or `MusicalStage` child branch.

`field_context_resolver.py` validates the structured root; `wiring_images.py` then checks the `Wiring` root and controlled `PreviewBackground` when applicable. There is no FieldWiring child-marker enforcement gap.

The future Procedure system has a separate deeper marker contract. Do not add separate markers to production `BackgroundStage` / `MusicalStage` folders merely to imitate Procedure task/image marker rules.

## Display Deep-Link Contract

The accepted Display QR integration uses:

```text
/fieldwiring/wiring.html?display_id=<permanent display_id>
```

Important distinction:

- `fieldwiring.js` powers the landing/search page and does **not** consume `display_id` from the landing-page URL.
- `wiring.js` consumes `display_id`, forwards it to `api/wiring`, and renders the resolved package.
- `wiring.py`/`repository.py` re-resolve the current Stage/Preview/Scene context from PostgreSQL.

The scan hub passes only permanent `display_id`.

Do not pass Stage, Preview, Scene, LOR UUID, controller address, Google Drive path, or import-run identity from the physical QR/scan hub.

## Existing Display QR Dependency

The deployed Display Scan hub exists as a Directus endpoint extension on `msb-prod-db`:

```text
/opt/directus/extensions/directus-extension-scan/
```

Git-controlled Scan application source is preserved under:

```text
Scan/directus-extension-scan/
```

Public Scan route:

```text
https://my.sheboyganlights.org/scan/
```

The hub resolves permanent `display_id` and provides independent Display, Testing, Field Wiring, Container, and Work Order actions.

Accepted action:

```text
Field Wiring
    -> /fieldwiring/wiring.html?display_id=<display_id>
```

No FieldWiring API call is required merely to render the Scan hub. FieldWiring availability must not become a prerequisite for the other Scan actions.

Directus administrative destinations use the established public Directus origin:

```text
https://db.sheboyganlights.org/
```

The final accepted Scan runtime artifact SHA-256 is:

```text
b4f6c27f4880a8eaf8a90d8d55c7939c5bd190645dca9329344a86c3175cb20f
```

## Scan Integration Acceptance

Accepted checks include:

- public `/scan/` HTTP 200 and no-slash redirect;
- manual `DISP:141` -> `TC-ChristmasHippo`;
- correct Directus Display record;
- correct assigned Container;
- positive Display Test Session redirect using `QV-SHRStocking`;
- Work Orders = 0 disabled state;
- correct FieldWiring package for `TC-ChristmasHippo`;
- phone camera initialization/live preview.

Physical QR decode and positive one/multiple Work Order cases were unavailable during acceptance and remain explicit deferred regression cases.

## Server Runtime Boundary

Application/business source remains in this repository.

Server runtime details — systemd service, persistent Display Folders mount, Synology reverse proxies, deployment/restart/recovery, Directus scan-extension runtime, and runtime hashes — belong in `Gregovate/MSB-Server-Management`.

Do not copy secrets or protected runtime configuration into either repository.

## Current Open Work

FieldWiring Scan Integration is closed as accepted production work.

The shared structured-scope resolver extraction is architecture accepted and awaiting its controlled production checkout/service update.

Separate future work includes:

- Controller Inventory replacement of temporary E1.31 presentation mappings;
- deferred Scan regression cases when suitable examples are available;
- plug/channel-label request integration;
- offline/self-contained field copy;
- separate FormView retirement decision.

## Resume Development

Before further FieldWiring application changes, read the current Wiring/Scan handoffs plus `FieldWiring_Shared_Structured_Scope_Resolver_Extraction_2026-08-22.md` and refresh from current `main`.

Procedure engineering may now consume the accepted shared resolver as a second caller. It must not create an independent Display/Stage/Scene resolver or copy `wiring_images.py` task behavior.
