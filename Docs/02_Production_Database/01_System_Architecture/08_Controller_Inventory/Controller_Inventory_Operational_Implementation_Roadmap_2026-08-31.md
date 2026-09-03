# Controller Inventory Operational Implementation Roadmap — 2026-08-31

| Item | Value |
|---|---|
| Status | V0.4.0 CORE DEPLOYED — FOLLOW-UP WORK REMAINS |
| Issue | #110 |
| Merged PR | #111 |
| Permanent database authority | `ref.controller*` |
| Primary user experience | Wiring System / Controller Inventory browser |
| Authentication | Cloudflare Access protected identity |
| Authorization | Existing Directus user / role / policy data |
| Operational Controller editing | Browser-native Controller Management |
| Delete policy | No normal Controller Inventory delete |
| Current production checkout | `72f5b7164f31753a33e5c2a9d83d9a7a6909a417` |
| FieldWiring production | `V0.4.0 / postgres / healthy` |

## Purpose

This roadmap controls the remaining Controller Inventory work after successful permanent Controller bootstrap and V0.4.0 production deployment.

The original roadmap expected Add/Edit/Assignment management to be future work. That phase is now complete and deployed. The remaining work is operational finishing: offline reports, lower-role acceptance, Controller physical label-service integration, operator procedures, and final PR reconciliation/merge preparation.

## Current Accepted Production State

Production contains:

```text
ref.controller_model
ref.controller_firmware_version
ref.controller_status
ref.controller
ref.controller_display
ref.controller_firmware_history
```

The initial bootstrap created 177 permanent physical Controller identities with IDs `1001` through `1177`.

Controller `1176` remains intentionally unassigned until its new 2026 Matrix Display exists through the normal Preview/LOR workflow.

Current production checkpoint:

```text
checkout                    72f5b7164f31753a33e5c2a9d83d9a7a6909a417
FieldWiring                  V0.4.0 / postgres / healthy
Procedures                   V0.1.0 / postgres / healthy
Controller fingerprint       578217bcb18e1291ceced673a3de3b27 unchanged
```

Durable production acceptance:

`Controller_V0.4.0_Production_Deployment_Acceptance_2026-09-03.md`

## Authority Boundary

```text
Cloudflare Access
    authenticates the protected browser user

Directus
    existing user / role / policy authorization data

Controller Inventory / Controller browser
    permanent physical Controller identity
    Controller model/status/firmware/location/notes
    current programmed Network / UID / IP facts
    current physical Controller-to-Display relationships
    planning and operational management UX

LOR / Parser V7 / LOR2DB
    authoritative current show wiring topology
    expected show Network / Unit ID / channels / universes
    Preview / Scene / Display wiring definitions

FieldWiring
    combines permanent Controller identity with current LOR/V7 wiring
    technician-facing read experience

PostgreSQL
    constraints / audit / narrow SECURITY DEFINER commands / final authority
```

No Controller Inventory workflow may rewrite LOR wiring topology.

There is no required Directus login redirect or cross-origin Directus browser-session bridge.

## Access Model

All MSB production users may browse Controller Inventory according to their approved read access.

Capability intent:

```text
Production Crew           browse + Print Label
Manager                   browse + Print Label + Controller management
Administrator             browse + Print Label + Controller management
MSB Browser / Read Only   browse only
```

Controller management includes:

```text
CREATE Controller             yes for Manager/Admin
READ Controller               yes
UPDATE Controller             yes for Manager/Admin
ASSIGN / REASSIGN / UNASSIGN  yes for Manager/Admin
DELETE Controller             no normal workflow
```

Every write request must recheck authorization server-side. UI button visibility is not security.

`fieldwiring_app` must remain least-privilege and must not receive broad direct DML on `ref.controller*`.

## Workstream 1 — Controller Inventory Browser — DEPLOYED

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
- firmware verification state;
- current assignments;
- firmware history;
- label state;
- FieldWiring cross-links.

Stage remains derived through the current physical relationship:

```text
ref.controller
    -> ref.controller_display
        -> ref.display
            -> ref.stage
```

Do not add redundant `stage_id` to `ref.controller` merely for browsing.

An unassigned `AVAILABLE` Controller may legitimately have no Stage.

## Workstream 2 — Browser-Native Controller Maintenance — DEPLOYED V0.4.0

The Manager/Admin maintenance workflow is now deployed and operator-accepted.

Accepted controls include:

- Add Controller with PostgreSQL-generated permanent ID;
- Edit Controller;
- model lookup;
- status lookup;
- physical location lookup;
- firmware/version lookup;
- serial number;
- hardware revision;
- year deployed;
- physical and firmware verification state/notes;
- general notes;
- current LOR Network;
- First UID in uppercase hexadecimal;
- UID Count in decimal;
- calculated UID range;
- management IP;
- programmed-configuration verification state/source note;
- label-required state;
- contextual help for non-obvious fields;
- unsaved-change protection.

The accepted physical meaning of `is_display_attached` is presented as:

```text
Physically Attached to Display
```

It means the physical Controller is mounted to, stored with, or normally moved with a Display. It is separate from logical Controller-to-Display assignments.

Model/UID rules remain enforced in PostgreSQL. The browser helps prevent obvious invalid values, but database constraints are final authority.

## Workstream 3 — Controller ↔ Display Assignment Workbench — DEPLOYED V0.4.0

The assignment workbench is now deployed and operator-accepted as part of V0.4.0.

It supports:

- current M:N Controller-to-Display relationships;
- assign one Controller to one or many Displays;
- assign one Display to one or many Controllers;
- reassign/move a relationship atomically;
- unassign without deleting the Controller asset;
- preserve other current assignments;
- optional `wiring_source_display_id` for reviewed duplicated-channel cases;
- Stage/Sub-stage context from the selected Display;
- assignment conflict/coverage context;
- intentional repeated Unit IDs/ranges;
- AVAILABLE -> DEPLOYED transition when chosen during assignment;
- final-unassign option to return DEPLOYED stock to AVAILABLE when operationally appropriate;
- no silent overwrite of REPAIR / RETIRED state.

Network/UID/IP remain mutable programmed facts and are never Controller identity.

## Workstream 4 — Controller Planning / LOR Comparison — DEPLOYED V0.4.0

The planning views compare current physical Controller programming and capacity against current LOR/V7 evidence without changing LOR authority.

Planning includes:

- Stage context;
- current Networks;
- model UID capacity;
- used and unused LOR UID evidence;
- compatible contiguous candidate blocks;
- current physical Controllers programmed on the same Network/UID range;
- repeated/shared address visibility;
- explicit SPARE evidence where attributable;
- Controller-vs-current-LOR comparison in assignment context.

The planner is advisory/operator-facing. PostgreSQL owns Controller facts; LOR/V7 owns show-required wiring.

## Workstream 5 — FieldWiring Permanent Controller Resolver — DEPLOYED

Accepted resolver contract:

```text
physical Controller = ref.controller.controller_id
physical Display    = ref.controller_display.display_id
wiring Display      = COALESCE(
    ref.controller_display.wiring_source_display_id,
    ref.controller_display.display_id
)
```

FieldWiring shows permanent Controller ID/model context and Controller Inventory cross-links where current physical relationships resolve the Controller.

Detailed Network/UID/channel/universe data remain LOR/V7 authority.

## Workstream 6 — Labels and Scan — PARTIAL

Permanent Controller identity uses:

```text
CTRL:<controller_id>
```

The browser Print Label command is deployed and sets the governed `ref.controller.print_label` request flag through the accepted narrow command boundary.

Browser presentation now uses a distinct print-action treatment and human-facing mapped operator attribution.

Still separate and incomplete:

- Controller physical print profile/template;
- Controller routing in the external LabelPrintService;
- physical Controller print acceptance;
- clearing the accidental pending CTRL 1001 request before Controller physical printing becomes active.

Do not build a second Controller print queue. Use the established MSB labeling subsystem.

## Workstream 7 — Offline / Printable Reports — REQUIRED NEXT

Controller Inventory needs physical/printable outputs for field work where Internet access may be unavailable.

Minimum accepted report set:

### Controller Firmware / Verification Worksheet

Include current Controller identity, model, Stage/Display assignment context, recorded firmware, firmware verification state, Network/UID or management IP, location, serial/hardware revision, and blank fields for observed firmware/action/verification date/person/notes.

### Stage / Display Controller List

Printable grouping by Stage/Sub-stage or selected Display with Controller IDs/models, assignment context, and programmed-address context.

### Verification / Exception Report

Printable list for firmware verification, physical verification, unknown location, unknown serial/hardware facts, and other outstanding verification states.

Every report must show generated-at/current-snapshot context so paper copies are not mistaken for permanent authority.

## Workstream 8 — Lower-Role Acceptance — REQUIRED

Administrator acceptance is complete for the V0.4.0 core.

Still verify in the protected production browser:

- Production Crew can browse and Print Label but cannot Add/Edit/Manage Assignments;
- MSB Browser / Read Only has browse-only behavior with no write actions;
- server-side negative paths remain fail-closed regardless of UI presentation.

## Workstream 9 — Plain-English Operator Procedures — REQUIRED

Now that the V0.4.0 UI is accepted and deployed, final operator procedures can be written against real screens instead of an unfinished design.

At minimum cover:

- find a Controller by ID, Display, or Stage;
- use planning/capacity screens;
- add a newly discovered shelf Controller;
- edit Controller physical/programmed facts;
- assign/reassign/unassign Displays;
- understand physical attachment versus logical assignment;
- record/verify firmware;
- change status/location;
- maintain current Network/UID/IP configuration;
- request a Controller label;
- open current Field Wiring from a Controller;
- handle duplicated-channel `wiring_source_display_id` cases;
- identify when a Controller has no current LOR wiring.

Procedures must use normal operator language. Engineering implementation terms belong in engineering documentation.

## Active Implementation Sequence

The remaining sequence after V0.4.0 production deployment is:

1. implement offline/printable Controller reports;
2. complete lower-role Production Crew / Read Only acceptance;
3. complete Controller physical label-service profile/template/routing work in the separate print-service workstream;
4. clear the accidental CTRL 1001 pending request before Controller physical printing is activated;
5. write and accept plain-English operator procedures against deployed V0.4.0;
6. reconcile remaining stale Controller docs/PR description as needed;
7. prepare draft PR #111 for review and eventual merge only under explicit approval.

Production deployment does not authorize merging `main`.

## Documentation Rule

Material Controller Inventory findings must be written into the repository as they are accepted. Issue comments are useful history but are not a substitute for durable architecture/operations documentation.

Whenever FieldWiring behavior changes because of Controller Inventory, both Controller Inventory and Wiring System documentation must be updated in the same workstream.

Do not leave an accepted production checkpoint, known limitation, or exact resume point only in conversation history.
