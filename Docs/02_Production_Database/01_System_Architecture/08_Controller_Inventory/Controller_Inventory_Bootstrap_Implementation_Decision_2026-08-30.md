# Controller Inventory Bootstrap Implementation Decision — 2026-08-30

| Document control | Value |
|---|---|
| Status | CURRENT EXPERIMENTAL IMPLEMENTATION DECISION |
| Subsystem | Controller Inventory |
| Issue | #110 |
| Identity state | EXPERIMENTAL / RESETTABLE |
| Permanent label printing | BLOCKED until identity acceptance |

## Purpose

This document records the accepted implementation boundary for reconstructing the initial Controller Inventory before allocating permanent `controller_id` values.

It supplements the Controller Inventory Engineering Acceptance Baseline and Application/Backfill Framework. Where earlier Pre-DDL text assumed the first reconstruction would occur directly inside `ref.controller*`, this focused implementation decision controls for the initial bootstrap workflow.

## Current Bootstrap Source Set

The current source set is:

```text
Controller Inventory & Testing 2026(7).xlsx
lor_output_v7_scene(20260830-185521).db
Parser V7.0.11 / LOR 6.6.10
```

The current workbook contains:

```text
177 physical controller rows
177 deployed/assigned controllers
0 known spare/available controller rows
```

Therefore an unresolved workbook row is a deployed-controller review problem. It must not be classified as `AVAILABLE` merely because its permanent Display relationship is unresolved.

Current source reconciliation found:

```text
177 total controller candidates
152 direct/current V7 Display-name matches
25 candidates requiring review
172 recorded firmware versions
5 firmware values requiring verification
```

The five firmware values requiring verification are source values such as blank, `???`, or `New`. These are not firmware versions and must not be inserted into the controlled firmware catalog.

## Existing `stage` Schema Is the Bootstrap Manipulation Boundary

The Production Database already uses `stage.*` as the raw/reconstruction layer for prior PostgreSQL migrations, including objects such as:

```text
stage.display_sheet_raw
stage.location_raw_full
stage.pallet_raw_2026
```

Controller Inventory follows that existing pattern.

Temporary Controller reconstruction belongs in:

```text
stage.controller_bootstrap
stage.controller_bootstrap_display
stage.v_controller_bootstrap_review
```

These objects may hold source names, spreadsheet row numbers, current LOR Network/UID evidence, model/firmware evidence, Stage/Scene text, Park Location text, `For What` grouping evidence, V7 match evidence, reviewed permanent Display relationships, derived first-deployment year, review state, and proposed bootstrap order.

None of those staging fields is permanent physical controller identity.

## Permanent Controller Identity

Permanent physical identity remains only:

```text
ref.controller.controller_id
```

The first permanent Controller ID is:

```text
1001
```

The `stage` schema does not allocate a real Controller ID. It may expose a review-only value:

```text
proposed_controller_id = 1000 + bootstrap_order
```

This exists only so the complete initial order can be reviewed before permanent insertion.

## Deployment-Year Backfill

The initial physical controller list contains current assignment and UID evidence but does not carry a reliable Controller first-deployment year.

The Production Database already contains:

```text
ref.display.year_built
```

For the initial bootstrap, `year_deployed` is derived from the reviewed permanent `display_id` relationship.

Default rule:

```text
one controller -> one Display
    year_deployed = assigned Display year_built

one controller -> multiple Displays
    year_deployed = earliest supportable assigned Display year_built
```

An operator may override this only as an explicit reviewed fact.

`year_deployed` means first-known controller deployment/use. It is not manufacturing year.

## Initial Controller-ID Ordering

Before any permanent Controller rows are inserted, every physical controller candidate is reviewed in `stage.*` and the complete initial order is prepared.

The deterministic ordering is:

```text
1. year_deployed ascending
2. current Network evidence
3. current UID/address evidence
4. source workbook row / staging identity as final tie-breaker
```

The purpose is only to give the initial Controller number range a useful rough oldest-to-newest pattern.

The ID does not encode year, UID, Stage, Display, or any other mutable configuration fact.

Repeated Network/UID values remain valid and do not collapse physical controllers.

## Permanent Promotion Gate

The initial workbook bootstrap is batch-only.

Individual staging rows do not allocate `controller_id` values. Ordinary Add Controller is not used to bypass the initial batch order while the initial reconstruction is open.

Before promotion:

```text
all physical candidates = READY or explicitly SKIPPED
all READY rows = permanent Display relationship resolved
all READY rows = model resolved
all READY rows = year_deployed resolved/reviewed
bootstrap_order = contiguous 1..N
proposed_controller_id = reviewed
ref.controller = empty
```

The controlled promotion:

```text
restarts empty ref.controller identity at 1001
inserts READY rows in bootstrap_order
verifies every PostgreSQL-generated ID equals 1000 + bootstrap_order
promotes permanent controller-to-Display relationships
promotes only recorded firmware versions
rolls back the complete transaction on any mismatch
```

The browser application intentionally does not expose this promotion action.

## Controller-to-Display Relationship

Permanent Controller-to-Display remains many-to-many:

```text
one controller -> zero, one, or many Displays
one Display    -> zero, one, or many controllers
```

Initial staging may automatically suggest/link only an unambiguous exact Display-name match. The 25 current nonmatching rows remain review work; they are not silently corrected.

Additional Display relationships may be added during review for physical groups that serve multiple Displays.

## Glistening Grove / Wiring-Source Review

A staging candidate may carry one reviewed:

```text
WIRING_SOURCE -> permanent display_id
```

where the physical controller-bearing Display does not carry its own current LOR wiring.

This is specifically intended to fit-test cases such as Glistening Grove non-wired physical copies.

Do not infer the wiring source from a name suffix.

## Firmware Bootstrap Rule

Known firmware from the workbook is preserved as text and remains model-specific.

Only source values classified:

```text
RECORDED
```

are inserted into `ref.controller_firmware_version` and initial firmware history.

Values classified:

```text
UNKNOWN_OR_VERIFY
```

remain unknown and do not block creation of the physical Controller identity after the rest of the candidate is accepted.

## Label Integration

`ref.controller` mirrors the existing Display label-state fields:

```text
label_required
print_label
label_print_count_cached
label_print_last_at_cached
label_print_last_by_cached_id
label_template_id
```

`label_template_id` references the existing Production Database authority:

```text
ref.label_template.label_template_id
```

Do not invent a Controller-specific label-template table, `label_id`, or `label_type_id`.

While Controller identity remains resettable/experimental:

```text
print_label = false
physical CTRL:<controller_id> printing = blocked
```

Once the identity set is explicitly accepted, Controller IDs are permanent and are never reset/reused.

## Physical Location Boundary

Controller Inventory consumes the existing:

```text
ref.location.location_code
```

for current physical storage/location where applicable.

Workbook `Park Location` remains bootstrap/deployment evidence and must not be mistaken for a competing `ref.location` authority.

Current physical location, permanent Display assignment, Stage context, and LOR Network/UID/IP/universe are separate mutable facts.

## Application Boundary

The initial Controller bootstrap workbench edits only the temporary `stage.controller_bootstrap*` reconstruction and reads permanent `ref.display`/Controller catalog identities.

The workbench supports:

- review queue;
- permanent Display search/relationship assignment;
- M:N Display relationships;
- reviewed wiring-source relationship;
- model selection;
- derived/operator-reviewed `year_deployed`;
- READY / REVIEW_REQUIRED / SKIPPED state;
- blocker enforcement; and
- review-only proposed 1001+ ordering.

Permanent promotion remains a separately reviewed operator SQL gate.

## Experimental Reset Boundary

Until Controller identity is explicitly accepted, Controller-owned experimental rows may be reset if:

- no Controller label has been requested/printed; and
- no external production subsystem has created a required FK dependency on `ref.controller`.

Resetting Controller Inventory must never modify existing `ref.display`, `ref.stage`, `ref.location`, `ref.label_template`, `lor_snap.*`, P1/P2, FieldWiring, or other production-owned data.

## Rule Established

> Use the existing `stage.*` migration schema to reconstruct, manipulate, and review all 177 currently deployed controller candidates before allocating permanent identity. Derive first-known `year_deployed` from reviewed permanent Display relationships and prepare the complete rough oldest-to-newest proposed 1001+ order in staging. Only after the complete set is accepted may one controlled all-or-nothing promotion allow PostgreSQL to generate `ref.controller.controller_id` beginning at 1001. Permanent Controller labels remain blocked until that identity set is explicitly accepted.
