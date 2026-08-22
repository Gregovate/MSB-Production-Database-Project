# Controller Inventory

This subsystem documents the permanent inventory of physical controller hardware and the current controller assignment needed to interpret the current approved LOR/V7 wiring snapshot.

## Current State

Controller inventory remains spreadsheet-based and has not yet been implemented as a PostgreSQL subsystem.

The **current working review source** is:

```text
Controller Inventory & Testing 2026.xlsx
```

Supporting engineering evidence remains:

```text
Controller Inventory & Firmware 2025 - Inventory.csv
Controller Inventory & Firmware 2025 - Lookup Table.csv
DMX Control Addressing.xlsx
current approved LOR/V7 PostgreSQL snapshot
```

The 2026 workbook materially improves current physical-controller coverage, including current Pixie and E1.31 rows that were missing from the 2025 source, but it is still under review and does not yet contain permanent `CL-###` identities.

Start with [Controller Inventory 2026 Source Audit — 2026-08-22](Controller_Inventory_2026_Source_Audit_2026-08-22.md).

## Design Intent

Create durable physical controller identities and a current assignment relationship that can be reconciled to the current approved LOR/V7 snapshot.

Controller Inventory supplies the physical-controller fact that LOR cannot represent. LOR/LOR2DB remains authoritative for current show topology, addressing, Stage/Scene/Display relationships, and detailed wiring rows.

## Current/Future Responsibilities

- permanent controller identity (`CL-###` / `CTRL:<controller_key>` label contract)
- exact manufacturer/model plus understandable controller classification
- physical output/port capability
- serial number where available
- current controller status
- current controller address/context needed to associate the physical controller with current LOR/V7 topology
- distinguishing current group information when multiple physical controllers intentionally share the same Unit ID/range
- firmware update history
- labeling/scanning relationships
- Work Order linkage for repairs/maintenance
- FieldWiring read/interface relationship

## Important Boundaries

### Current assignment only

Controller assignment is current-state data. Controller Inventory does not need to preserve prior Stage, Scene, Display, Unit-ID, network, IP, universe, or deployment assignments as historical relationship rows.

Older LOR snapshots and source artifacts remain available as engineering evidence.

### Repairs belong to Work Orders

Repairs, troubleshooting, parts replacement, maintenance actions, and repair resolution belong in the Work Order system and should link to the permanent controller asset. Controller Inventory does not need a competing repair-history subsystem.

### Firmware history is retained

Firmware updates are controller-specific history worth preserving. The system should retain firmware version, install/verification date, responsible person, and optional notes/Work Order reference.

### Do not duplicate LOR relationships unnecessarily

For a controller with a unique current Network + Unit ID/range, the current approved LOR/V7 snapshot already identifies the Displays and output relationships using that address. The inventory team does not need to manually recreate those Display assignments.

When multiple physical controllers intentionally share the same address, record one additional distinguishing group, for example:

```text
CL-042 | 21-24 | Candy Canes 1-4
CL-043 | 21-24 | Candy Canes 5-8
CL-044 | 21-24 | Candy Canes 9-12
```

Do not define `network + Unit ID/range` as a unique physical-controller identity.

### Exact controller models remain distinct

Generic classifications are useful, but exact models must be preserved. `PixCon16` and Pixie-16 are different devices and must never be normalized into one model.

## FieldWiring Integration

FieldWiring is a read-only consumer of Controller Inventory; it does not own the Controller Inventory schema.

The current FieldWiring release candidate documents two explicit temporary replacement targets:

- `FieldWiring/Application/wiring_presentation.py` — reviewed temporary A/C/Pixie physical grouping rules;
- `FieldWiring/Application/wiring_e131.py` — reviewed temporary E1.31 controller/output mappings.

Those temporary rules may remain while source review continues, but they must stay replaceable by the eventual PostgreSQL Controller Inventory read contract rather than becoming permanent named Display/Scene architecture.

See:

- [Controller Inventory Current-State / FieldWiring Integration Plan](Controller_Inventory_Current_State_FieldWiring_Integration_Plan_2026-08-20.md)
- [FieldWiring Release Candidate Handoff and Development Runbook](../09_Wiring_System/FieldWiring_Release_Candidate_Handoff_and_Development_Runbook_2026-08-21.md)

## Related Systems

- [Controller Inventory 2026 Source Audit — 2026-08-22](Controller_Inventory_2026_Source_Audit_2026-08-22.md)
- [Controller Inventory and Labeling Plan](Controller_Inventory_and_Labeling_Plan.md)
- [Controller Inventory Current-State / FieldWiring Integration Plan](Controller_Inventory_Current_State_FieldWiring_Integration_Plan_2026-08-20.md)
- [Controller Inventory 2025 Source Audit — historical source](Controller_Inventory_2025_Source_Audit_2026-08-19.md)
- [FieldWiring Release Candidate Handoff and Development Runbook](../09_Wiring_System/FieldWiring_Release_Candidate_Handoff_and_Development_Runbook_2026-08-21.md)
- [Labeling and Scanning](../07_Labeling_and_Scanning/README.md)
- [Wiring System](../09_Wiring_System/README.md)
- [Network Infrastructure](../10_Network_Infrastructure/README.md)
- [Work Orders](../06_Work_Orders/README.md)

## Resume Development

Do not design the final PostgreSQL schema from assumptions.

The next work is source/data reconciliation: establish permanent physical controller identity, normalize confirmed model terminology, reconcile current addressing against the approved LOR/V7 snapshot, distinguish intentional duplicate-address controllers, resolve the 2026 workbook conflicts identified in the source audit, and review the minimum FieldWiring current-assignment interface.

No PostgreSQL Controller Inventory tables or migrations are authorized until that review is accepted.
