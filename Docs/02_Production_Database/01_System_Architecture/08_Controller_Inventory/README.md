# Controller Inventory

| Document control | Value |
|---|---|
| Status | ACTIVE PRE-DDL ENGINEERING WORK |
| Current authority | [Engineering Acceptance Baseline — 2026-08-29](Controller_Inventory_Engineering_Acceptance_Baseline_2026-08-29.md) |
| PostgreSQL implementation | Not yet installed |

This subsystem defines permanent physical controller/device identity and the accepted physical relationships needed to interpret the current LOR/V7 wiring in field terms.

## Read This First

The current Controller Inventory engineering authority is:

- [Controller Inventory Engineering Acceptance Baseline — 2026-08-29](Controller_Inventory_Engineering_Acceptance_Baseline_2026-08-29.md)

That baseline records the accepted identity model, grouping process, spreadsheet boundary, FieldWiring consumer requirements, current Pre-DDL resume point, and DDL gate.

Older planning/audit documents in this folder remain useful evidence. When an older document conflicts with the current acceptance baseline, the current acceptance baseline controls until the older document is brought forward.

## Current Phase

Controller Inventory is still in **Pre-DDL physical-grouping reconstruction and fit testing**.

No Controller Inventory PostgreSQL tables or migrations are authorized yet.

The active engineering question is whether the proposed physical groupings and relationship model can explain the real current LOR wiring across conventional A/C, Pixie, repeated-address, E1.31, multi-Display, multi-controller, and unresolved physical-copy cases without turning LOR addressing into permanent identity.

## Authority Boundary

```text
LOR / V7
    -> current wiring, Network, UID, channels/outputs,
       universes, Preview/Scene/Display relationships, SPARE state

Controller Inventory engineering
    -> physical-controller grouping interpretation built from
       LOR wiring + family behavior + known field evidence

future PostgreSQL Controller Inventory
    -> permanent physical controller/device identity
       accepted Production Database-owned physical relationships

FieldWiring
    -> technician-facing consumer
```

LOR wiring remains read-only to Controller Inventory.

## Permanent Identity

The accepted permanent identity is only:

```text
ref.controller.controller_id
```

`controller_id` is PostgreSQL-generated, analogous to `ref.display.display_id`.

Accepted scan payload:

```text
CTRL:<controller_id>
```

Do **not** create `controller_key`, `CL-###`, or another parallel permanent identity.

Network, UID/range, IP, universe, Display, Stage, Scene, COM port, workbook row, and LOR Prop identity are not permanent controller identity.

## Physical Relationship

Controller-to-Display is many-to-many:

```text
one controller -> zero, one, or many Displays
one Display    -> zero, one, or many controllers
```

Intentional repeated addresses are valid. Network + UID/range or Network + UID + channel must never be globally unique physical-controller identity.

## Working Spreadsheet Boundary

The current `Controller Inventory & Testing 2026(...)` spreadsheet is a **temporary engineering grouping worksheet**.

It is not an authoritative physical inventory and it is not a future operational dependency.

It is the best current attempt to assemble physical groupings from authoritative LOR wiring, controller-family behavior, model/capability evidence, location clues, and known field facts before the complete physical inventory is presented/verified.

The final `For What` column was deliberately added to define or distinguish the proposed physical grouping/use context. It must be interpreted as grouping evidence, not incidental notes.

Accepted grouping decisions and corrected assumptions must be promoted into controlled engineering documentation as the review proceeds. They must not remain only in chat or only in the spreadsheet.

After PostgreSQL Controller Inventory is implemented, the maintained physical inventory/grouping workflow belongs in PostgreSQL and its controlled application/workflow. The spreadsheet becomes historical bootstrap evidence only.

## Important Boundaries

### No deployment-assignment history requirement

Controller assignment is current-state data. V1 does not require historical Stage, Scene, Display, UID, network, IP, universe, or deployment relationship rows.

### Firmware history is retained

Firmware history follows permanent `controller_id` and must use model-compatible firmware authority.

### Repairs belong to Work Orders

Repairs, troubleshooting, parts replacement, and maintenance belong in the Work Order system linked to `controller_id`.

### Exact models remain distinct

Generic family/classification is useful, but exact models must remain distinct. `PixCon16` and `Pixie-16` are not interchangeable.

### Managed-device scope is broader than output controllers

Directors, Easy Light Linkers, InputPup, PixieLink, ServoDog, and other managed show-control devices may receive permanent inventory identity even when no Display assignment is required.

## FieldWiring Integration

FieldWiring is a consumer of Controller Inventory and does not own its schema.

The durable consumer contract is:

- [FieldWiring / Controller Inventory Handoff — 2026-08-20](../09_Wiring_System/FieldWiring_Controller_Inventory_Handoff_2026-08-20.md)

FieldWiring continues to obtain detailed current wiring from LOR/V7. Controller Inventory eventually supplies permanent physical controller identity, model/capability, accepted current physical grouping/assignment, duplicate-address distinction, and enough physical output/port context for FieldWiring to turn LOR wiring into technician-facing hookup instructions.

## Current Working Evidence / Resume Point

Current active Pre-DDL evidence:

```text
Controller Inventory & Testing 2026(6).xlsx
lor_output_v7_scene(20260829-194137).db
Parser V7.0.11 / LOR 6.6.10
```

Two known corrections are newer than those exact uploaded artifacts:

- the obsolete `HW-EventTrafficRight-01 / Regular / UID 08 / CTB32LG3` spreadsheet row has already been removed from the current working spreadsheet;
- current LOR corrected `42 10-09 SPARE` to `Regular / UID 10 / channel 9`; the uploaded SQLite predates that correction.

Do not reopen those two items merely because they remain visible in the uploaded comparison artifacts.

## Branch Boundary

The older `docs/controller-inventory-v1-review` branch contains valuable reconnaissance but diverged materially from current `main` while other production work continued.

Do not continue ordinary Controller Inventory edits directly on that stale branch. Reconcile valid findings into fresh work based on current `main` so newer accepted Production Database and FieldWiring changes are preserved.

## Related Engineering Evidence

- [Engineering Acceptance Baseline — 2026-08-29](Controller_Inventory_Engineering_Acceptance_Baseline_2026-08-29.md)
- [Controller Inventory and Labeling Plan](Controller_Inventory_and_Labeling_Plan.md) — older planning foundation; identity examples may be superseded by the current acceptance baseline
- [Controller Inventory Current-State / FieldWiring Integration Plan — 2026-08-20](Controller_Inventory_Current_State_FieldWiring_Integration_Plan_2026-08-20.md)
- [Controller Inventory Current Assignment Cardinality — 2026-08-20](Controller_Inventory_Current_Assignment_Cardinality_2026-08-20.md)
- [Controller Inventory 2025 Source Audit — 2026-08-19](Controller_Inventory_2025_Source_Audit_2026-08-19.md)
- [HWY-42 Address Ambiguity — 2026-08-20](Controller_Inventory_LOR_Address_Ambiguity_HWY42_2026-08-20.md)
- [E1.31 IP Current-State Correction — 2026-08-20](Controller_Inventory_E131_IP_Current_State_Correction_2026-08-20.md)
- [FieldWiring / Controller Inventory Handoff](../09_Wiring_System/FieldWiring_Controller_Inventory_Handoff_2026-08-20.md)
- [Labeling and Scanning](../07_Labeling_and_Scanning/README.md)
- [Wiring System](../09_Wiring_System/README.md)
- [Network Infrastructure](../10_Network_Infrastructure/README.md)
- [Work Orders](../06_Work_Orders/README.md)

## DDL Gate

Do not design or install final Controller Inventory DDL from spreadsheet row shape or conversation assumptions.

Continue the grouping/fit test, promote material accepted findings into the controlled acceptance baseline as they are established, and only move to DDL when the physical identity/relationship model has been demonstrated against the real system and the remaining implementation decisions are explicit.
