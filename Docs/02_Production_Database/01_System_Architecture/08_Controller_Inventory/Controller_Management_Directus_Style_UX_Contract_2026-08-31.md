# Controller Management Directus-Style UX Contract — 2026-08-31

| Item | Value |
|---|---|
| Status | ACTIVE IMPLEMENTATION CONTRACT |
| Issue | #110 |
| Primary maintenance experience | Controller Inventory management UI |
| Reference interaction model | Existing MSB Directus edit forms |
| Delete policy | No normal Controller delete |

## Purpose

The Controller Management experience should deliberately resemble the Directus edit screens already used for MSB operational maintenance rather than inventing a second administration paradigm.

Operators/managers should see one Controller record at a time, grouped into clear sections, with governed lookup controls, booleans rendered as switches, relationship sections rendered as related-item workspaces, and audit fields visible but read-only.

The Controller browser remains the normal discovery/browse experience. Management actions should open or transition into a form that feels consistent with Directus editing.

## Form structure

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
- Number of UIDs — decimal count
- Calculated UID Range — read-only presentation from generated `lor_uid_end`
- Management IP
- Programmed Configuration Verification State
- Programmed Configuration Verified At — read-only unless governed verification workflow requires otherwise
- Programmed Configuration Source Note

Model rules remain enforced in PostgreSQL. The UI should help the operator by showing model UID capacity and any fixed-count requirement before save.

### Physical / Operational State

- Current Location — controlled lookup to `ref.storage_location`
- Display Attached — boolean switch / tri-state only if Directus supports preserving NULL cleanly
- Controller Status — controlled lookup

Stage is not edited here. Stage remains derived from current Display assignments.

### Firmware

- Installed Firmware Version — controlled lookup constrained to the selected model
- Firmware Verification State
- Firmware Verified At
- Firmware Verified By — related person, normally workflow-controlled/read-only
- Firmware Verification Note
- Firmware History — related records from `ref.controller_firmware_history`

Raw firmware-version IDs must not be the normal operator experience.

### Display Assignments

Show current `ref.controller_display` relationships in a related-items section with:

- Display name / Display ID
- derived Stage / Sub-stage context
- wiring source Display when populated
- placement note
- relationship notes
- Open Field Wiring action when current wiring exists

Required actions:

- Assign Display
- Reassign / add additional Display
- Unassign relationship without deleting the Controller asset
- preserve many-to-many cardinality
- expose `wiring_source_display_id` only for reviewed duplicated-channel cases

The assignment workflow must never infer permanent physical identity from Network/UID.

### Labels

- Label Required — boolean switch
- Print Label — boolean switch / request flag
- Label Template — controlled lookup to existing `ref.label_template`
- Label Print Count — read-only
- Last Printed — read-only
- Last Printed By — read-only

The management UI may set `print_label = true` before the external label service rework is complete. Actual printer handoff remains a separate integration step and must use the established MSB label subsystem.

### Audit

Show but do not normally edit:

- Created At
- Created By
- Created By Person
- Updated At
- Updated By
- Updated By Person

Directus/user-aware audit behavior remains the established MSB hybrid audit contract.

## Add Controller

Add Controller should use the same section layout as Edit Controller.

Minimum practical creation flow:

1. choose Model;
2. choose Status, normally `AVAILABLE` for unassigned shelf stock;
3. record current programmed configuration when known;
4. record current physical location when known;
5. optionally record firmware/serial/hardware revision/year deployed;
6. keep zero Display assignments valid;
7. default `label_required = true` and expose `print_label` so a permanent `CTRL:<controller_id>` label can be requested.

The permanent `controller_id` remains PostgreSQL-generated and is never user-entered.

## Directus consistency rules

Use the same interaction patterns already established elsewhere in MSB Directus:

- human-readable relationship dropdowns instead of raw FK numbers;
- grouped form sections;
- read-only audit/system fields;
- boolean switches for boolean facts;
- normal Directus save/unsaved-change behavior;
- Manager policy can CREATE/READ/UPDATE;
- ordinary MSB read-only users remain READ-only;
- no normal Controller DELETE.

Do not center this maintenance workflow on dashboards.

## Relationship / metadata work required

The current Directus reconnaissance confirms the six Controller collections are registered and visible and the database role/policies already permit the intended CREATE/READ/UPDATE/no-DELETE model.

Remaining work is UI metadata and relationship configuration, including:

- configure `controller_model_id` as a model relation;
- configure `controller_status_id` as a status relation;
- configure `installed_firmware_version_id` as a firmware relation;
- configure `current_location_code` as a location relation;
- configure `label_template_id` as a label-template relation;
- configure person/audit references appropriately;
- surface programmed-configuration fields added after the original Controller metadata registration;
- configure `controller_display` as a usable related-items assignment workspace;
- organize field order/groups according to this contract.

## Acceptance

Controller Management is not complete until a Manager can perform, through the normal UI, all of the following without raw SQL:

- add an unassigned Controller;
- edit its model/status/location and physical facts;
- maintain its current Network/UID/IP programmed configuration;
- record/maintain firmware facts;
- set `print_label`;
- assign one or many Displays;
- unassign a Display relationship without deleting the Controller;
- open Field Wiring from an assignment;
- see audit fields updated through the established actor/audit system.
