# Controller Inventory E1.31 IP Current-State Correction — 2026-08-20

| Item | Value |
|---|---|
| Status | OPERATOR-CONFIRMED CORRECTION |
| Subsystem owner | Controller Inventory |
| Consumer | FieldWiring |
| Scope | Dense RGB / E1.31 controller-management IP information |
| Schema status | No PostgreSQL schema or migration authorized by this finding |

## Purpose

This correction records that the IP addresses previously documented in FieldWiring / E1.31 engineering material are **not correct current controller IP addresses**.

The current physical controller inventory review will establish the correct current IP information where IP is operationally required.

## Supersession Rule

Any IP address currently present in older FieldWiring, Controller Inventory, or `DMX Control Addressing.xlsx` discussion must be treated as one of the following until the Controller Inventory review is complete:

- historical configuration evidence;
- stale planning/configuration evidence; or
- unverified source evidence.

It must **not** be treated as current authoritative controller configuration.

This includes previously documented `10.10.5.x` and `192.168.5.x` values associated with dense RGB / E1.31 controller examples.

Do not use those values to:

- identify a permanent physical controller;
- resolve a FieldWiring controller context;
- infer controller count;
- determine the current controller assignment;
- populate a current FieldWiring field instruction; or
- create PostgreSQL uniqueness/identity rules.

## Authority Boundary

The current approved LOR/V7 snapshot remains authoritative for current show topology, universe/channel relationships, Display wiring, and addressing represented by LOR.

Controller Inventory will provide permanent physical controller identity and the reviewed **current controller assignment/configuration facts** that LOR does not own. Current management IP, where useful, belongs to that reviewed current-state controller information.

IP address remains configuration data, not permanent controller identity.

## Dense RGB Physical Controller Facts Unaffected

This IP correction does **not** change the operator-confirmed physical-controller grouping recorded for FieldWiring:

```text
Mega Tree       -> 1 × 48-output AlphaPix
Mega Ball       -> 1 × PixCon16
Mega Cube       -> 1 × 48-output AlphaPix
Whoville Matrix -> 1 × PixCon16
Mega Star       -> 2 × PixCon16
```

Those are physical-controller facts. The current IP values for those controllers are pending the Controller Inventory review.

## FieldWiring Requirement

FieldWiring browser acceptance should proceed without depending on current controller IP values.

Normal field presentation should use the accepted physical controller context and physical outputs/ports. Raw IP information, once corrected and available from Controller Inventory, belongs in engineering/troubleshooting detail unless a specific operational workflow requires it.

The future Controller Inventory resolver may expose current IP as metadata, but `ctrl_id` must remain independent of IP and FieldWiring must continue to function if the IP changes.

## Source Preservation

Do not delete or silently rewrite older workbook/document evidence merely because its IP values are stale or incorrect for the present configuration.

Preserve those values as source/history evidence where already recorded, but clearly defer current-state IP authority to the completed Controller Inventory review.

## Related Documents

- [Controller Inventory Current-State / FieldWiring Integration Plan — 2026-08-20](Controller_Inventory_Current_State_FieldWiring_Integration_Plan_2026-08-20.md)
- [Controller Inventory and Labeling Plan](Controller_Inventory_and_Labeling_Plan.md)
- [FieldWiring Dense RGB Physical Controller Map — 2026-08-20](../09_Wiring_System/FieldWiring_Dense_RGB_Physical_Controller_Map_2026-08-20.md)
- [FieldWiring E1.31 Dense RGB Field Presentation Contract](../09_Wiring_System/FieldWiring_E131_Dense_RGB_Field_Presentation_Contract.md)
- [FieldWiring / Controller Inventory Handoff — 2026-08-20](../09_Wiring_System/FieldWiring_Controller_Inventory_Handoff_2026-08-20.md)
