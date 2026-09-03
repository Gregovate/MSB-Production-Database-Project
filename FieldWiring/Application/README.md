# FieldWiring Application

Status: **PRODUCTION-OPERATIONAL — CONTROLLER INVENTORY INTEGRATION ACTIVE**

This folder contains the browser-based FieldWiring application and the read-side Controller Inventory browser experience.

## Current State

FieldWiring is production-operational at:

```text
https://my.sheboyganlights.org/fieldwiring/
```

Current accepted production checkpoint:

```text
checkout                    84d6f06e16c43ebb0f6aa21273b999af7f6d455b
FieldWiring health/version  {"data_mode":"postgres","status":"ok","version":"V0.3.1"}
Procedures health/version   {"data_mode":"postgres","status":"ok","version":"V0.1.0"}
combined live regression    183 passed in 2.39s
```

Accepted production state includes:

- live read-only PostgreSQL backend;
- systemd-hosted FieldWiring service operational on `192.168.5.9:8790`;
- persistent read-only Google `Display Folders` filesystem operational;
- protected Synology reverse proxy operational;
- desktop and phone acceptance passed;
- Display search repaired and production-tested;
- existing Display Scan hub exposes the independent **Field Wiring** action;
- FormView remains available as fallback/reference;
- task-neutral Stage/Sub-stage/Scene resolver in `field_context_resolver.py` shared with Procedures;
- Stage-aware Controller Inventory browse/search;
- visible free-text Stage search confirmation in Controller Inventory;
- current programmed Controller Network/UID/IP facts visible in Controller Inventory;
- permanent Controller ID/model context shown in FieldWiring where governed Controller relationships resolve the physical device;
- FieldWiring -> Controller Inventory return/cross-link navigation;
- Controller Inventory -> Field Wiring links from Display assignments;
- privacy-safe pathname-only analytics contract for FieldWiring;
- Procedures analytics asset versioning included in the shared accepted checkout.

For current engineering/recovery state, start with:

- `Docs/02_Production_Database/01_System_Architecture/08_Controller_Inventory/README.md`
- `Docs/02_Production_Database/01_System_Architecture/08_Controller_Inventory/Controller_Management_Application_Boundary_2026-08-31.md`
- `Docs/02_Production_Database/01_System_Architecture/09_Wiring_System/FieldWiring_Controller_Inventory_Handoff_2026-08-20.md`
- `Docs/02_Production_Database/01_System_Architecture/09_Wiring_System/FieldWiring_Shared_Structured_Scope_Resolver_Extraction_2026-08-22.md`
- `Docs/02_Production_Database/01_System_Architecture/07_Labeling_and_Scanning/FieldWiring_Scan_Integration_Engineering_Handoff_2026-08-22.md`
- `Docs/02_Production_Database/01_System_Architecture/09_Wiring_System/README.md`

## Authority Chain

The FieldWiring application remains read-only and preserves:

```text
LOR -> Parser V7 -> LOR2DB -> PostgreSQL -> FieldWiring
```

Permanent identities are:

```text
Display     ref.display.display_id
Controller  ref.controller.controller_id
```

LOR/V7 remains authoritative for current wiring topology, channels, universes, and expected show addressing.

Controller Inventory owns permanent physical Controller identity, current Controller-to-Display relationships, and current programmed Controller facts.

FieldWiring consumes those authorities for technician-facing presentation. It must not create a competing topology or asset-identity system.

## Controller Management Boundary

The current Controller browser is the accepted read-side foundation for future Controller Management.

Directus is **not** the Controller operational editor. Directus remains the shared login/identity/Manager-policy authority and may still be used for simple one-table/reference maintenance.

The next Controller Management phase belongs in the browser-native Controller experience:

```text
Controller Detail
    -> authenticated Manager check
    -> Edit Controller / Add Controller
    -> current programmed Network / UID / IP maintenance
    -> Assign / Reassign / Unassign Displays
    -> label request action
    -> PostgreSQL validation / audit
```

Do not make the existing `fieldwiring_app` PostgreSQL role broadly writable merely to add management controls. The Manager write path must have a separate governed server-side authorization/write boundary.

See:

`Docs/02_Production_Database/01_System_Architecture/08_Controller_Inventory/Controller_Management_Application_Boundary_2026-08-31.md`

## Application Structure

```text
backend.py
    Flask host / routes / health

repository.py
    PostgreSQL production repository
    SQLite development-snapshot repository

controller_inventory.py
    permanent Controller Inventory read queries
    Stage/search/filter/detail/assignments/firmware context

wiring_controller_inventory.py
    attaches permanent Controller context to current wiring rows
    starts from governed Controller-to-Display relationships
    uses Network/UID only to distinguish already-assigned physical controllers

wiring.py
    top-level wiring package assembler

wiring_data.py
    normal current wiring/context loader

wiring_dmx_source.py
    V7.0.11+ atomic DMX source-detail adapter with scope guard

wiring_presentation.py
    A/C / Pixie / DMX family classification and physical presentation

wiring_dumbrgb.py
    CR50 / DumbRGB fixture annotation

wiring_e131.py
    reviewed E1.31 presentation mappings/fallbacks where governed permanent partitioning is incomplete

field_context_resolver.py
    task-neutral marked Stage/Sub-stage/Scene structured-scope resolver
    shared infrastructure for FieldWiring and Procedure callers

wiring_images.py
    FieldWiring adapter after scope resolution
    selects Wiring branch, enumerates wiring/context images, and safely serves images

controllers.html / controllers.js
    Controller Inventory browse/detail UI

static/controllers_search_context.js
    visible free-text Stage-match confirmation without silently changing explicit Stage filter

static/controllers_detail_extras.js
    Controller detail additions including label state and permanent deep-link behavior

fieldwiring.js
    Display/Stage lookup landing page

wiring.js
    base wiring renderer / image controls / Engineering Details / Controller Inventory return navigation
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

Procedures consumes `field_context_resolver.resolve_structured_scope(...)` as a second caller rather than copying the resolver algorithm or reusing FieldWiring's Wiring-specific adapter.

## Shared Resolver Production Acceptance

The shared resolver extraction remains accepted infrastructure. It was originally deployed at:

```text
21e9e3b1889289806ccb116b3a546cfcd129fae4
```

That historical deployment closed the resolver architecture gate. Current production is later and controlled by the `84d6f06...` checkpoint above.

## Permanent Controller Resolver Contract

FieldWiring uses the permanent relationship basis:

```text
physical controller = ref.controller.controller_id
physical Display     = ref.controller_display.display_id
wiring Display       = COALESCE(
    ref.controller_display.wiring_source_display_id,
    ref.controller_display.display_id
)
```

For AC/Pixie rows, current programmed Network/UID may distinguish which already-assigned physical Controller applies. Addressing is never permanent identity.

For DMX/E1.31 families, current Controller assignment context can be shown even where a fully governed universe-to-physical-controller partition is not yet available. Do not claim an exact physical split without governed evidence.

Temporary named/family-specific mappings must remain centralized and replaceable until permanent Controller evidence covers their real cases and regression is accepted.

## Current Presentation Families

```text
LOR + Traditional -> A/C controller / numbered output
LOR + RGB         -> Pixie controller / numbered RGB output
DMX + DumbRGB     -> DMX fixture/network presentation
DMX + RGB         -> E1.31 dense RGB presentation
```

Permanent Controller Inventory context now supplements these presentation families where resolved.

## Production Data Mode

Production uses:

```text
FIELDWIRING_DATABASE_DSN=<least-privilege read-only PostgreSQL DSN>
FIELDWIRING_DRIVE_ROOT=<server-visible read-only Display Folders root>
FIELDWIRING_TIMEZONE=America/Chicago
```

Production must not use `FIELDWIRING_DEV_SNAPSHOT`.

Current accepted FieldWiring health payload:

```json
{"data_mode":"postgres","status":"ok","version":"V0.3.1"}
```

## Development Snapshot Mode

Development/engineering may use an explicit read-only snapshot:

```text
FIELDWIRING_DEV_SNAPSHOT=C:\path\to\fieldwiring_snapshot.db
FIELDWIRING_DRIVE_ROOT=G:\Shared drives\Display Folders
```

The SQLite snapshot is an engineering fixture only and must not become the production data source.

Controller Inventory permanent tables are PostgreSQL production authority; development snapshot behavior must not invent Controller identities when those tables are absent.

## Development / Test

From the repository virtual environment:

```powershell
python -m pip install -r .\FieldWiring\Application\requirements-dev.txt
python -m pytest .\FieldWiring\Application .\Procedures\Application -q
```

The shared FieldWiring + Procedures test gate is required because both applications consume shared resolver/runtime code.

Current accepted live combined result:

```text
183 passed in 2.39s
```

## Accepted FieldWiring Marker Contract

The production-aligned marker rule is:

```text
<resolved Stage / Sub-stage / Scene root>  marker required
Wiring                                     marker required
PreviewBackground                          marker required when used for controlled same-scope context
Wiring\BackgroundStage                     NO separate marker
Wiring\MusicalStage                        NO separate marker
SourceDocs                                  excluded / no marker
```

The marker on `Wiring` guards the selected `BackgroundStage` or `MusicalStage` child branch.

The Procedure system has a separate deeper marker contract. Do not add separate markers to production `BackgroundStage` / `MusicalStage` folders merely to imitate Procedure task/image marker rules.

## Display Deep-Link Contract

The accepted Display QR integration uses:

```text
/fieldwiring/wiring.html?display_id=<permanent display_id>
```

The scan hub passes only permanent `display_id`.

Do not pass Stage, Preview, Scene, LOR UUID, controller address, Google Drive path, or import-run identity from the physical QR/scan hub.

## Controller Deep-Link / Cross-Link Contract

The Controller Inventory browser is addressable by permanent Controller identity and FieldWiring may link back to it when the physical Controller is resolved.

FieldWiring should present permanent Controller context in human-usable form, including `CTRL <controller_id>` and model context, without promoting current Network/UID into identity.

Controller Inventory current Display assignments provide **Open Field Wiring** actions back into the Display wiring view.

This bidirectional navigation is part of the accepted read-side workflow.

## Existing Display QR Dependency

The deployed Display Scan hub exists as a Directus endpoint extension on `msb-prod-db` and is separately owned/deployed according to the Scan/runtime documentation.

Public Scan route:

```text
https://my.sheboyganlights.org/scan/
```

The hub resolves permanent `display_id` and provides independent Display, Testing, Field Wiring, Container, and Work Order actions.

FieldWiring availability must not become a prerequisite for the other Scan actions.

## Server Runtime Boundary

Application/business source remains in this repository.

Server runtime details — systemd service, persistent Display Folders mount, Synology reverse proxies, deployment/restart/recovery, Directus scan-extension runtime, and runtime hashes — belong in `Gregovate/MSB-Server-Management`.

Do not copy secrets or protected runtime configuration into either repository.

## Current Open Work / Resume Development

The old shared-resolver and basic Controller-browser gates are closed. Do not resume from those historical starting points.

Current development priority is Controller Management:

1. browser-native authenticated Manager identity/authorization boundary reusing Directus login/session/Manager policy;
2. Edit Controller from the existing Controller detail pane;
3. Add Controller for permanent shelf/unassigned stock;
4. governed model/status/location/firmware/verification/current Network/UID/IP maintenance;
5. Manager-editable `print_label` request state;
6. Controller ↔ Display assignment/reassignment/unassignment workbench;
7. real shelf-stock/reassignment acceptance;
8. remaining permanent-Controller replacement of temporary FieldWiring presentation mappings only when governed evidence fully covers the real cases;
9. actual Controller label-service handoff when its separate contract is ready;
10. plain-English operator procedures after the accepted UI exists.

Every deployed application change must preserve the shared FieldWiring + Procedures regression gate and keep the controlled Controller/Wiring handoffs current during the work.
