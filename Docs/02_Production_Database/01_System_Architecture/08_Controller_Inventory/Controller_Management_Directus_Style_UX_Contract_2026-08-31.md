# Controller Management Directus-Style UX Contract — 2026-08-31

| Item | Value |
|---|---|
| Status | SUPERSEDED AS DIRECTUS IMPLEMENTATION — FIELD/UX REQUIREMENTS RETAINED |
| Issue | #110 |
| Current architecture authority | [Controller Management Application Boundary — 2026-08-31](Controller_Management_Application_Boundary_2026-08-31.md) |
| Primary maintenance experience | Browser-native Controller Inventory management UI |
| Reference interaction model | Familiar grouped edit-form patterns used in MSB |
| Delete policy | No normal Controller delete |

## Superseded Direction

This document originally described implementing the Controller operational workflow inside Directus. Live testing proved that approach unsuitable once the workflow crossed Controller facts, firmware, labels, and the many-to-many Controller-to-Display relationship.

The accepted architecture is now:

```text
Directus
    -> login / identity / Manager policy authority
    -> optional simple one-table/reference maintenance only

Controller Inventory browser
    -> Add / Edit Controller
    -> current programmed Network / UID / IP maintenance
    -> Assign / Reassign / Unassign Displays
    -> label request controls
    -> operational Controller workflow

PostgreSQL
    -> constraints / audit / data integrity / final authority
```

The attempted Directus `display_assignments` / `firmware_history` reverse workspaces were removed after causing Controller item-detail failures. The cleanup preserved the legitimate composite key:

```text
PRIMARY KEY (controller_id, display_id)
```

Do not resume Directus O2M relationship-workspace work or add a surrogate relationship ID solely for Directus compatibility.

The form structure and field requirements below remain useful as the browser-native Controller Management UX contract.

## Browser-Native Form Structure

### Identification

- Controller ID — read-only permanent identity, shown as `CTRL <controller_id>`
- Model — controlled lookup to `ref.controller_model`; never a raw integer FK
- Status — controlled lookup to `ref.controller_status`
- Hardware Revision
- Serial Number
- Year Deployed
- Physical Verification State
- Notes

### Current Programmed Configuration

This section records what the physical controller is currently programmed as. It is not permanent identity and does not replace LOR/V7 expected-show wiring authority.

- LOR Network
- First UID — operator-facing uppercase hexadecimal input
- Number of UIDs — ordinary decimal count
- Calculated UID Range — read-only presentation from generated `lor_uid_end`
- Management IP
- Programmed Configuration Verification State
- Programmed Configuration Verified At — read-only unless a governed verification workflow explicitly updates it
- Programmed Configuration Source Note

Model rules remain enforced in PostgreSQL. The UI should help the operator by showing model UID capacity and any fixed-count requirement before save.

### Physical / Operational State

- Current Location — controlled lookup to the accepted storage/location authority
- Display Attached — boolean/tri-state as required by the stored fact
- Controller Status — controlled lookup

Stage is not edited here. Stage remains derived from current Display assignments.

### Firmware

- Installed Firmware Version — controlled lookup constrained to the selected model
- Firmware Verification State
- Firmware Verified At
- Firmware Verified By — workflow-controlled/read-only where appropriate
- Firmware Verification Note
- Firmware History — presented from `ref.controller_firmware_history`

Raw firmware-version IDs must not be the normal operator experience.

### Display Assignments

Show current `ref.controller_display` relationships with:

- Display name / Display ID
- derived Stage / Sub-stage context
- wiring source Display when populated
- placement note
- relationship notes
- Open Field Wiring action when current wiring exists

Required browser-native actions:

- Assign Display
- Reassign / add additional Display
- Unassign relationship without deleting the Controller asset
- preserve many-to-many cardinality
- expose `wiring_source_display_id` only for reviewed duplicated-channel cases

The assignment workflow must never infer permanent physical identity from Network/UID.

### Labels

- Label Required — boolean control
- Print Label — boolean/request action
- Label Template — controlled lookup to existing `ref.label_template`
- Label Print Count — read-only
- Last Printed — read-only
- Last Printed By — read-only

The Controller Management UI may set `print_label = true` before the external label-service rework is complete. Actual printer handoff remains a separate integration step and must use the established MSB label subsystem.

### Audit

Show but do not normally edit:

- Created At
- Created By
- Created By Person
- Updated At
- Updated By
- Updated By Person

Existing MSB user-aware audit behavior remains the governing contract.

## Add Controller

Add Controller uses the same browser-native section layout as Edit Controller.

Minimum practical creation flow:

1. choose Model;
2. choose Status, normally `AVAILABLE` for unassigned shelf stock;
3. record current programmed configuration when known;
4. record current physical location when known;
5. optionally record firmware/serial/hardware revision/year deployed;
6. keep zero Display assignments valid;
7. default `label_required = true` and expose `print_label` so a permanent `CTRL:<controller_id>` label can be requested.

The permanent `controller_id` remains PostgreSQL-generated and is never user-entered.

## Browser Consistency Rules

Use familiar MSB maintenance patterns where they improve usability:

- human-readable relationship dropdowns instead of raw FK numbers;
- grouped form sections;
- read-only audit/system fields;
- clear boolean controls;
- Save / Cancel behavior with unsaved-change protection;
- Manager-only create/update/relationship commands;
- ordinary MSB users remain read-only;
- no normal Controller DELETE.

These are interaction-pattern requirements, not a requirement to render the form inside Directus.

## Authentication / Authorization Rule

The Controller browser must reuse the existing Directus login/session/Manager policy authority and verify Manager authorization server-side on every write.

A visible or hidden Edit button is not the security boundary.

Do not make `fieldwiring_app` broadly writable merely to support the browser UI.

## Acceptance

Controller Management is not complete until a Manager can perform, through the browser-native Controller Management UI, all of the following without raw SQL and without relying on Directus for multi-table coordination:

- add an unassigned Controller;
- edit its model/status/location and physical facts;
- maintain its current Network/UID/IP programmed configuration;
- record/maintain firmware facts;
- set `print_label`;
- assign one or many Displays;
- unassign a Display relationship without deleting the Controller;
- open Field Wiring from an assignment;
- see audit fields updated through the established actor/audit system.
