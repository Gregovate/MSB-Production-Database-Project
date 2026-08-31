# Controller Inventory Operational Implementation Roadmap — 2026-08-31

| Item | Value |
|---|---|
| Status | ACTIVE IMPLEMENTATION ROADMAP |
| Issue | #110 |
| Permanent database authority | `ref.controller*` |
| Primary user experience | Wiring System / Controller Inventory browser |
| Governed maintenance back-end | Directus |
| Delete policy | No normal Controller Inventory delete |

## Purpose

This roadmap controls the work after successful permanent Controller Inventory bootstrap. It replaces the obsolete assumption that Controller Inventory is still only a Pre-DDL exercise.

The permanent Controller subsystem is installed in production and the initial physical inventory has been promoted. The remaining work is operational integration: make Controller Inventory usable for normal browsing and manager maintenance, make FieldWiring consume permanent physical controller identity, support ongoing Controller-to-Display assignment, support newly discovered shelf stock, complete labeling, and produce plain-English operator procedures after the system is accepted.

## Current Accepted Production State

Production currently contains:

- `ref.controller_model`;
- `ref.controller_firmware_version`;
- `ref.controller_status`;
- `ref.controller`;
- `ref.controller_display`;
- `ref.controller_firmware_history`.

The initial bootstrap created 177 permanent physical controller identities with IDs `1001` through `1177`.

The initial Controller-to-Display reconstruction has been corrected for the accepted repeated-address and duplicated-channel cases documented in:

- `Controller_FieldWiring_Repeated_Address_and_Duplicated_Channel_Cases_2026-08-30.md`.

Controller `1176` is intentionally unassigned until its new 2026 Matrix Display exists through the normal Preview/LOR workflow.

The original stage bootstrap objects are temporary engineering scaffolding and are not operational Controller Inventory authority.

## Authority Boundary

```text
Controller Inventory
    permanent physical controller identity
    controller model/status/firmware/location/notes
    current physical Controller-to-Display relationships
    optional wiring_source_display_id for duplicated-channel copies

LOR / Parser V7 / LOR2DB
    current wiring topology
    Network / Unit ID / channels / universes
    Preview / Scene / Display wiring definitions

FieldWiring
    combines permanent controller identity with current LOR wiring
    technician-facing read experience

Directus
    governed manager maintenance back-end
```

No Controller Inventory workflow may rewrite LOR wiring topology.

## Access Model

All MSB production users receive read access to Controller Inventory.

Managers receive:

```text
CREATE  yes
READ    yes
UPDATE  yes
DELETE  no
```

Directus remains the governed maintenance back-end. The Wiring System browser is the preferred normal browsing experience.

Browser-native editing may be added only after the Wiring System has a trustworthy authenticated user/role identity that can distinguish Managers from ordinary production users. Do not make the existing read-only `fieldwiring_app` PostgreSQL role writable merely to expose browser edit controls.

An interim Manager-only Edit path may deep-link to the appropriate Directus record so Directus continues to enforce Manager permissions and unsaved-change behavior.

## Workstream 1 — Controller Inventory Browser

The browser must become the primary day-to-day Controller Inventory experience.

Required browse/search capabilities:

- Controller ID;
- Display name / Display ID;
- Stage / Sub-stage;
- model;
- status;
- assignment state;
- serial number;
- current physical location;
- firmware verification state.

Stage is derived through the current physical relationship:

```text
ref.controller
    -> ref.controller_display
        -> ref.display
            -> ref.stage
```

Do not add redundant `stage_id` to `ref.controller` merely for browsing.

A controller serving several Displays in one Stage appears once in that Stage result with its relevant Display assignments. A controller serving Displays in more than one Stage may legitimately appear when either Stage is selected.

An unassigned `AVAILABLE` controller has no Stage until assigned.

## Workstream 2 — Controller ↔ Display Assignment Workbench

A permanent assignment workbench is required. The initial bootstrap match-up was one-time reconstruction; future Controller Inventory must support ongoing physical inventory changes without manual junction-table edits.

The workbench must support:

- list/search unassigned controllers;
- add newly discovered shelf controllers as permanent assets with zero Display assignments;
- assign one controller to one or many Displays;
- assign one Display to one or many controllers;
- move/reassign a controller;
- unassign a controller from a Display without deleting the controller asset;
- show all current assignments before a change is committed;
- select `wiring_source_display_id` only for reviewed duplicated-channel cases;
- automatically show the selected Display's Stage/Sub-stage context;
- show conflicts/coverage when the controller or Display already has other assignments;
- preserve intentional repeated Unit IDs/ranges;
- never treat Network/UID as permanent identity.

Status behavior should support the operational lifecycle:

- an unassigned shelf controller is normally `AVAILABLE`;
- assigning an `AVAILABLE` controller may transition it to `DEPLOYED` through a controlled workflow;
- unassigning the final Display may allow a controller to return to `AVAILABLE` when operationally appropriate;
- `REPAIR` and `RETIRED` remain explicit states and must not be silently changed by assignment operations.

The workbench should be reachable from both directions:

```text
Controller detail
    -> Manage Display Assignments

Stage / Display browse
    -> Display
        -> Assigned Controllers
        -> Add / Change Controller
```

## Workstream 3 — FieldWiring Permanent Controller Resolver

FieldWiring currently still contains temporary physical-controller presentation rules such as inferred Pixie groups. Those rules were explicitly documented as a bridge until Controller Inventory became authoritative.

FieldWiring must now converge on the accepted permanent resolver contract:

```text
physical controller = ref.controller.controller_id
physical Display     = ref.controller_display.display_id
wiring Display       = COALESCE(
    ref.controller_display.wiring_source_display_id,
    ref.controller_display.display_id
)
```

FieldWiring must:

- show permanent `controller_id` and exact controller model when available;
- use `ref.controller_display` to distinguish physical controllers when Unit IDs/ranges repeat intentionally;
- stop using temporary labels such as `Pixie group 1/2/3` when permanent relationships resolve the case;
- eliminate false grouping-review states that Controller Inventory now resolves;
- use `wiring_source_display_id` for Glistening Grove and similar reviewed duplicated-channel copies;
- keep detailed Network/UID/channel/universe data from LOR/V7;
- not invent wiring for a Controller/Display that has no current approved LOR wiring and no reviewed wiring source.

The existing temporary named/grouping rules must remain isolated until each relevant presentation family has been migrated and regression accepted; do not remove a fallback before the permanent resolver covers its real cases.

## Workstream 4 — Controller Maintenance UX

Manager maintenance requires governed lookup controls rather than raw FK IDs.

Expected governed controls include:

- model lookup;
- status lookup;
- physical location lookup;
- firmware/version lookup constrained by the accepted model/firmware rules;
- serial number;
- hardware revision;
- year deployed / first-known-use evidence;
- verification state and notes;
- general notes;
- label flags/status.

The preferred end-state is a useful Wiring/Controller management experience with Manager-only edit capability. Directus remains the security/governance back-end and fallback maintenance console.

## Workstream 5 — Labels and Scan

Permanent Controller identity uses:

```text
CTRL:<controller_id>
```

The Controller browser must eventually expose label state and a controlled Request/Print Label action using the established MSB labeling subsystem rather than creating a separate print mechanism.

New shelf controllers must be able to receive permanent Controller IDs and labels before they are assigned to a Display.

Controller scan integration is a later operational step after the label/assignment workflow is accepted.

## Workstream 6 — Plain-English Operator Procedures

Operator procedures are required before Controller Inventory is considered operationally complete.

Do not write final procedures from an unfinished UI. Build and accept the working system first, then write plain-English procedures against the actual screens and behavior.

At minimum the final operator procedure set must cover:

- find a controller by ID, Display, or Stage;
- find all controllers used by a Stage;
- add a newly discovered shelf controller;
- assign a controller to a Display;
- assign multiple controllers to one Display;
- assign one controller to multiple Displays;
- move/reassign a controller;
- unassign a controller and return it to available stock when appropriate;
- record/verify firmware;
- change status/location;
- request/print a controller label;
- open current Field Wiring from a controller;
- handle a duplicated-channel `wiring_source_display_id` case;
- identify when a controller has no current LOR wiring and should not appear in FieldWiring.

Procedures must use normal operator language and screenshots/examples from the accepted production interface. Engineering terms such as junction-table row, FK, resolver provider, or LOR UUID belong in engineering documentation, not ordinary operator instructions.

## Implementation Sequence

The active sequence is:

1. bring Controller Inventory documentation forward to the installed production state;
2. add Stage-aware Controller browsing and richer search;
3. migrate FieldWiring physical-controller presentation to permanent Controller Inventory relationships in controlled, regression-tested increments;
4. add the Controller ↔ Display Assignment workbench;
5. add Manager edit navigation / authenticated edit capability;
6. complete label integration;
7. validate shelf-stock and reassignment lifecycle with real controllers;
8. complete production acceptance and regression testing;
9. write and accept plain-English operator procedures.

Each deployed change must preserve the existing shared FieldWiring/Procedures runtime regression gate.

## Documentation Rule

Material Controller Inventory findings must be written into the repository as they are accepted. Issue comments are useful implementation history but are not a substitute for durable architecture/operations documentation.

Whenever FieldWiring behavior changes because of Controller Inventory, both the Controller Inventory integration documentation and Wiring System handoff/current-state documentation must be updated in the same workstream.

When the UI/workflow becomes accepted, operator procedures must be created before the work is closed.
