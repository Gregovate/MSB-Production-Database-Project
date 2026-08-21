# Controller Inventory E1.31 IP Current-State Correction — 2026-08-20

| Item | Value |
|---|---|
| Status | OPERATOR-CONFIRMED CORRECTION, narrowed by newer 2026-08-21 LOR configuration evidence |
| Subsystem owner | Controller Inventory |
| Consumer | FieldWiring |
| Scope | Dense RGB / E1.31 controller-management and routing IP information |
| Schema status | No PostgreSQL schema or migration authorized by this finding |

## Purpose

This correction originally recorded that IP addresses previously documented in older FieldWiring / E1.31 engineering material were **not reliable current controller IP addresses**.

That warning remains valid for older workbook/document values unless they are corroborated by newer authoritative evidence.

On 2026-08-21, the operator supplied screenshots of the current LOR E1.31 Controller setup. Those screenshots now establish current **LOR-configured target IPs** for the named controller definitions documented in:

- [FieldWiring E1.31 LOR Controller Definitions — 2026-08-21](../09_Wiring_System/FieldWiring_E131_LOR_Controller_Definitions_2026-08-21.md)

Therefore this correction must no longer be read as a blanket rejection of every `10.10.5.x` value. It applies to older/unverified values, not to newer operator-supplied current LOR routing configuration.

## Supersession / Authority Rule

Any IP address present only in older FieldWiring, Controller Inventory, or `DMX Control Addressing.xlsx` discussion must be treated as one of the following until corroborated:

- historical configuration evidence;
- stale planning/configuration evidence; or
- unverified source evidence.

It must **not** be treated as current authoritative controller configuration merely because the number appears in an older source.

The 2026-08-21 LOR screenshots are newer evidence and establish the current LOR-side target values for their named definitions.

That still does not authorize using IP address to:

- identify a permanent physical controller;
- create PostgreSQL uniqueness/identity rules; or
- substitute for Controller Inventory `ctrl_id`.

## LOR Routing IP vs Physical Controller Identity

The architecture now distinguishes:

```text
LOR E1.31 target IP
    -> current routing/configuration fact in LOR

physical controller current network state
    -> reviewed operational fact

Controller Inventory ctrl_id
    -> permanent physical identity
```

These may correspond operationally, but they are not the same identity concept.

The Open/Close Sign provides an explicit example: LOR contains a configured E1.31 target for the new 2026 controller context, while the operator states the physical installation is not yet complete.

Therefore an LOR target IP proves routing configuration, not completed physical installation.

## Authority Boundary

The current approved LOR/V7 snapshot remains authoritative for current show topology, universe/channel relationships, Display wiring, and addressing represented by LOR.

The current LOR E1.31 controller definitions provide the routing relationship from universe ranges to named controller contexts and target IPs.

Controller Inventory will provide permanent physical controller identity and the reviewed **current controller assignment/configuration facts** that LOR does not own.

IP address remains mutable configuration data, not permanent controller identity.

## Dense RGB Physical Controller Facts Unaffected

This IP correction does **not** change the operator-confirmed physical-controller grouping recorded for FieldWiring:

```text
Mega Tree       -> 1 HolidayCoro AlphaPix Flex 48-output system
Mega Ball       -> 1 PixCon16
Mega Cube       -> 1 HolidayCoro AlphaPix Flex 48-output system
Whoville Matrix -> 1 PixCon16
Mega Star       -> 2 PixCon16
```

Those are physical-controller facts.

## FieldWiring Requirement

Normal FieldWiring presentation should continue to use the accepted physical controller context and physical outputs/ports when known.

Current LOR target IP information belongs primarily in engineering/troubleshooting detail unless a field workflow specifically requires it.

The future Controller Inventory resolver may expose current IP as metadata, but `ctrl_id` must remain independent of IP and FieldWiring must continue to function if the IP changes.

## Source Preservation

Do not delete or silently rewrite older workbook/document evidence merely because its IP values are stale or superseded.

Preserve those values as source/history evidence where already recorded, but clearly distinguish them from the newer 2026-08-21 current LOR E1.31 configuration evidence.

## Related Documents

- [FieldWiring E1.31 LOR Controller Definitions — 2026-08-21](../09_Wiring_System/FieldWiring_E131_LOR_Controller_Definitions_2026-08-21.md)
- [Controller Inventory Current-State / FieldWiring Integration Plan — 2026-08-20](Controller_Inventory_Current_State_FieldWiring_Integration_Plan_2026-08-20.md)
- [Controller Inventory and Labeling Plan](Controller_Inventory_and_Labeling_Plan.md)
- [FieldWiring Dense RGB Physical Controller Map — 2026-08-20](../09_Wiring_System/FieldWiring_Dense_RGB_Physical_Controller_Map_2026-08-20.md)
- [FieldWiring E1.31 Dense RGB Field Presentation Contract](../09_Wiring_System/FieldWiring_E131_Dense_RGB_Field_Presentation_Contract.md)
- [FieldWiring / Controller Inventory Handoff — 2026-08-20](../09_Wiring_System/FieldWiring_Controller_Inventory_Handoff_2026-08-20.md)
