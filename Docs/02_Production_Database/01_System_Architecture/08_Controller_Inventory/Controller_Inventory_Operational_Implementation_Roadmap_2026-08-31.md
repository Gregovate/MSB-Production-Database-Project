# Controller Inventory Operational Implementation Roadmap — 2026-08-31

| Item | Value |
|---|---|
| Status | ACTIVE IMPLEMENTATION ROADMAP |
| Issue | #110 |
| Permanent database authority | `ref.controller*` |
| Primary user experience | Wiring System / Controller Inventory browser |
| Authentication / authorization authority | Directus login/session/Manager policy |
| Operational Controller editing | Browser-native Controller Management |
| Delete policy | No normal Controller Inventory delete |

## Purpose

This roadmap controls the work after successful permanent Controller Inventory bootstrap.

The permanent Controller subsystem is installed in production and the initial physical inventory has been promoted. Stage-aware browsing and the first permanent Controller/FieldWiring integration are also accepted. The remaining work is now the authenticated Manager workflow: Add/Edit Controller, governed current programmed configuration, Controller-to-Display assignment management, shelf/AVAILABLE inventory, label request/printing integration, and final operator procedures.

## Current Accepted Production State

Production contains:

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

Accepted production application checkpoint:

```text
checkout                    84d6f06e16c43ebb0f6aa21273b999af7f6d455b
FieldWiring                  V0.3.1 / postgres / healthy
Procedures                   V0.1.0 / postgres / healthy
combined live regression     183 passed in 2.39s
```

Accepted read-side capabilities now include:

- Stage/Sub-stage-aware Controller browse/filter;
- free-text Stage-match confirmation;
- programmed LOR Network / First UID / UID Count / calculated range / management IP visibility and search;
- current Display assignments and Stage context;
- firmware history and label state;
- permanent Controller ID/model context in FieldWiring;
- Controller Inventory -> Field Wiring links;
- Field Wiring -> Controller Inventory cross-links.

The original stage bootstrap objects are temporary engineering scaffolding and are not operational Controller Inventory authority.

## Authority Boundary

```text
Controller Inventory / Controller browser
    permanent physical controller identity
    controller model/status/firmware/location/notes
    current programmed Network/UID/IP facts
    current physical Controller-to-Display relationships
    optional wiring_source_display_id for duplicated-channel copies
    operational Manager UX

LOR / Parser V7 / LOR2DB
    current wiring topology
    expected show Network / Unit ID / channels / universes
    Preview / Scene / Display wiring definitions

FieldWiring
    combines permanent controller identity with current LOR wiring
    technician-facing read experience

Directus
    login / identity / role-policy authority
    optional simple one-table/reference maintenance only

PostgreSQL
    constraints / audit / data integrity / final authority
```

No Controller Inventory workflow may rewrite LOR wiring topology.

## Access Model

All MSB production users receive read access to Controller Inventory.

Managers receive operational capability through the Controller browser:

```text
CREATE                 yes
READ                   yes
UPDATE                  yes
ASSIGN / UNASSIGN      yes
DELETE Controller       no normal workflow
```

The browser must reuse the existing Directus identity/session/Manager policy authority. Every write request must verify Manager authorization server-side.

Do not make the existing read-only `fieldwiring_app` PostgreSQL role broadly writable merely to expose browser edit controls.

Do not deep-link Managers to Directus as the required Controller editing workflow. The Directus multi-table relationship experiment was rejected after live testing and cleanup.

## Closed Directus Relationship Experiment

Directus remains useful for authentication/authorization and simple single-table maintenance, but it is not the Controller operational editor.

The attempted Directus Controller reverse workspaces were removed after causing item-detail failures around the legitimate composite relationship model. Accepted cleanup preserved:

```text
ref.controller_display PRIMARY KEY (controller_id, display_id)
194 Controller/Display assignment rows
172 firmware-history rows
```

Validation returned:

```text
DIRECTUS CONTROLLER SIMPLIFICATION: PASS
```

Do not resume O2M Directus relationship-workspace work or introduce a surrogate `controller_display_id` merely for Directus compatibility.

## Workstream 1 — Controller Inventory Browser — READ SIDE ACCEPTED

The browser is the primary day-to-day Controller Inventory experience.

Accepted browse/search capabilities include:

- Controller ID;
- Display name / Display ID;
- Stage / Sub-stage;
- model;
- status;
- assignment state;
- serial number;
- current physical location;
- programmed Network/UID/IP context;
- firmware verification state.

Stage remains derived through the current physical relationship:

```text
ref.controller
    -> ref.controller_display
        -> ref.display
            -> ref.stage
```

Do not add redundant `stage_id` to `ref.controller` merely for browsing.

An unassigned `AVAILABLE` controller has no Stage until assigned.

## Workstream 2 — Authenticated Browser-Native Controller Maintenance — NEXT

The immediate implementation phase is the Manager write boundary in the existing Controller browser.

Required flow:

```text
Controller Detail
    -> Manager authorization resolved from existing Directus identity/session
    -> Edit Controller
       OR Add Controller
    -> server verifies Manager permission on every write
    -> PostgreSQL constraints/audit remain final authority
```

Required governed controls include:

- model lookup;
- status lookup;
- physical location lookup;
- firmware/version lookup constrained by accepted model/firmware rules;
- serial number;
- hardware revision;
- year deployed / first-known-use evidence;
- physical and firmware verification state/notes;
- general notes;
- current LOR Network;
- First UID as operator-facing uppercase hexadecimal;
- UID Count as ordinary decimal count;
- calculated UID range from generated `lor_uid_end`;
- management IP;
- programmed-configuration verification state/source note;
- label flags/status including `print_label`.

Model/UID rules remain enforced in PostgreSQL. The UI should prevent obvious invalid choices and present model capacity, but database constraints are final authority.

Add Controller must support a newly discovered shelf controller with zero Display assignments. The permanent `controller_id` is PostgreSQL-generated and is never user-entered.

## Workstream 3 — Controller ↔ Display Assignment Workbench — NEXT

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

## Workstream 4 — FieldWiring Permanent Controller Resolver — FIRST PASS ACCEPTED

The accepted permanent resolver contract is:

```text
physical controller = ref.controller.controller_id
physical Display     = ref.controller_display.display_id
wiring Display       = COALESCE(
    ref.controller_display.wiring_source_display_id,
    ref.controller_display.display_id
)
```

FieldWiring now shows permanent Controller ID/model context and provides Controller Inventory cross-links where permanent relationships resolve the physical controller.

Detailed Network/UID/channel/universe data remain LOR/V7 authority.

Remaining presentation-family-specific temporary mappings/fallbacks must remain isolated until each real case is covered by permanent Controller Inventory evidence and regression accepted. Do not remove a fallback merely because the first permanent resolver integration is working.

## Workstream 5 — Labels and Scan

Permanent Controller identity uses:

```text
CTRL:<controller_id>
```

`ref.controller` already contains the established label-state fields, including `label_required`, `print_label`, cached print count/time, and label template reference.

The Controller browser must expose label state and a controlled Manager Request/Print Label action. The existing `print_label` request flag may be made Manager-editable before the external label-service rework is complete.

Actual printer handoff must use the established MSB labeling subsystem rather than creating a separate Controller printing mechanism.

New shelf controllers must be able to receive permanent Controller IDs and labels before they are assigned to a Display.

Controller scan integration is a later operational step after the label/assignment workflow is accepted.

## Workstream 6 — Plain-English Operator Procedures

Operator procedures are required before Controller Inventory is considered operationally complete.

Do not write final procedures from an unfinished Manager UI. Build and accept the working system first, then write plain-English procedures against the actual screens and behavior.

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
- maintain current Network/UID/IP configuration;
- request/print a controller label;
- open current Field Wiring from a controller;
- handle a duplicated-channel `wiring_source_display_id` case;
- identify when a controller has no current LOR wiring and should not appear in FieldWiring.

Procedures must use normal operator language and screenshots/examples from the accepted production interface. Engineering terms such as junction-table row, FK, resolver provider, or LOR UUID belong in engineering documentation, not ordinary operator instructions.

## Active Implementation Sequence

The active sequence is now:

1. implement browser-native Directus-authenticated Manager identity/authorization boundary;
2. add **Edit Controller** to the existing Controller detail experience;
3. add **Add Controller** for permanent unassigned shelf stock;
4. add controlled maintenance of model/status/location/firmware/verification/current programmed Network/UID/IP facts;
5. make `print_label` Manager-editable using the existing label contract;
6. add Controller ↔ Display assignment/reassignment/unassignment workbench;
7. validate real shelf-stock/reassignment lifecycle with physical controllers;
8. complete the actual label-service handoff when its separate contract is ready;
9. complete production acceptance and shared FieldWiring/Procedures regression testing;
10. write and accept plain-English operator procedures.

Each deployed change must preserve the existing shared FieldWiring/Procedures runtime regression gate.

## Documentation Rule

Material Controller Inventory findings must be written into the repository as they are accepted. Issue comments are useful implementation history but are not a substitute for durable architecture/operations documentation.

Whenever FieldWiring behavior changes because of Controller Inventory, both the Controller Inventory integration documentation and Wiring System handoff/current-state documentation must be updated in the same workstream.

Do not leave a changed architecture decision, accepted production checkpoint, known limitation, or exact resume point only in conversation history or Issue comments. Update the controlled documents before subsequent work depends on it.

When the UI/workflow becomes accepted, operator procedures must be created before the work is closed.
