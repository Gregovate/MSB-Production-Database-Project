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
Cloudflare Access
    -> authenticates the protected browser user

Directus
    -> current user / role / policy authorization data
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
- **Physically Attached to Display** — boolean/tri-state physical fact
- Controller Status — controlled lookup

`Physically Attached to Display` means whether the physical Controller is mounted to, normally stored with, or normally moved with a Display. It does **not** mean that the Controller has a current logical Display assignment. Logical assignments remain governed separately through `ref.controller_display` and the assignment workbench.

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
- Print Label — controlled request action
- Label Template — controlled lookup to existing `ref.label_template` when Controller printing is implemented
- Label Print Count — read-only
- Last Printed — read-only
- Last Printed By — read-only

The Controller Management UI may set `print_label = true` before the external label-service Controller route is complete. Actual printer handoff remains a separate integration step and must use the established MSB label subsystem.

**Print Label is a physical-output action and must be visually distinct from the blue Save Controller primary database-write action and from blue navigation actions such as Open Field Wiring.** Pending state must remain textually clear (`Print Requested` or equivalent); do not rely on color alone.

### Audit

Show but do not normally edit:

- Created At
- Created By
- Created By Person
- Updated At
- Updated By
- Updated By Person

Existing MSB user-aware audit behavior remains the governing contract. Human-facing success notices should identify the authenticated/mapped person rather than presenting the PostgreSQL administrative actor as the requester.

## Contextual Field Help

The production form should provide small `?` help controls beside **non-obvious** field labels rather than filling the form with permanent explanatory paragraphs.

Interaction requirements:

- hover/focus on desktop;
- click/tap on touch devices;
- keyboard accessible;
- one or two concise operator-facing sentences;
- do not expose database implementation details in ordinary help text.

Initial fields requiring contextual help include:

- Physically Attached to Display;
- Physical Verification;
- First UID / UID Count;
- Programmed Configuration Verification State;
- Programmed Configuration Source Note;
- Firmware Verification State;
- Wiring Source Display;
- Label Required.

Do not add help icons mechanically to obvious fields such as Serial Number merely for visual consistency.

## Add Controller

Add Controller uses the same browser-native section layout as Edit Controller.

Minimum practical creation flow:

1. choose Model;
2. choose Status, normally `AVAILABLE` for unassigned shelf stock;
3. record current programmed configuration when known;
4. record current physical location when known;
5. optionally record firmware/serial/hardware revision/year deployed;
6. keep zero Display assignments valid;
7. default `label_required = true` and expose the governed label request when its physical print route is operational.

The permanent `controller_id` remains PostgreSQL-generated and is never user-entered.

There must be only **one** Add Controller action in the Controller browse toolbar for an authorized Manager/Administrator. Duplicate rendering of that action is a UI defect, not a second workflow.

## Browser Consistency Rules

Use familiar MSB maintenance patterns where they improve usability:

- human-readable relationship dropdowns instead of raw FK numbers;
- grouped form sections;
- read-only audit/system fields;
- clear boolean controls;
- Save / Cancel behavior with unsaved-change protection;
- contextual `?` help for non-obvious operator concepts;
- Manager/Admin-only create/update/relationship commands;
- ordinary MSB users remain read-only;
- no normal Controller DELETE.

The live unsaved-change warning is accepted behavior and must be preserved.

These are interaction-pattern requirements, not a requirement to render the form inside Directus.

## Authentication / Authorization Rule

Cloudflare Access authenticates the protected browser user. The Controller backend resolves that trusted identity against current Directus user/role/policy authorization data and verifies Controller capability server-side on every write.

A visible or hidden Edit button is not the security boundary.

Do not make `fieldwiring_app` broadly writable merely to support the browser UI.

## Acceptance

Controller Management is not complete until an authorized Manager/Administrator can perform, through the browser-native Controller Management UI, all of the following without raw SQL and without relying on Directus for multi-table coordination:

- add an unassigned Controller;
- edit its model/status/location and physical facts;
- maintain its current Network/UID/IP programmed configuration;
- record/maintain firmware facts;
- request a Controller label through the governed path;
- assign one or many Displays;
- unassign a Display relationship without deleting the Controller;
- open Field Wiring from an assignment;
- see audit fields updated through the established actor/audit system.
