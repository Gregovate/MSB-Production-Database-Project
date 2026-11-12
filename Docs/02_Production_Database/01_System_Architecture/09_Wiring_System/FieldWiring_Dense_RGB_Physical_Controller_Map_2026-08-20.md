# FieldWiring Dense RGB Physical Controller Map — 2026-08-20

| Item | Value |
|---|---|
| Status | OPERATOR-CONFIRMED ENGINEERING FINDING |
| Sub-project | FieldWiring |
| Scope | Dense RGB / E1.31 physical controller grouping |
| Schema status | No PostgreSQL schema or migration authorized by this finding |

## Purpose

This finding records the operator-confirmed physical controller layout for the principal dense RGB Displays currently under FieldWiring acceptance. It supersedes earlier FieldWiring assumptions where those assumptions conflict with the physical configuration described here.

The current LOR/V7 snapshot remains authoritative for universe/channel topology. This document supplies the physical-controller grouping that LOR cannot encode directly.

## Confirmed Physical Controller Map

```text
Mega Tree
    1 physical HolidayCoro AlphaPix Flex 48-output system
    48 ribbons around the tree
    one physical controller output per ribbon

Mega Ball
    1 physical PixCon16 controller

Mega Cube
    1 physical HolidayCoro AlphaPix Flex 48-output system

Whoville Matrix
    1 physical PixCon16 controller

Mega Star
    2 physical PixCon16 controllers
```

Operator-confirmed inventory count for the AlphaPix Flex systems:

```text
2 total HolidayCoro AlphaPix Flex 48-output systems
    1 -> Mega Tree
    1 -> Mega Cube
```

The two Flex systems are the two previously described 48-output AlphaPix controller contexts; they are not additional controllers.

## Important Correction — Mega Cube

Earlier FieldWiring E1.31 documentation interpreted the addressing workbook as evidence for three physical PixCon16 controllers for Mega Cube.

That interpretation is superseded by operator-confirmed physical knowledge:

```text
Mega Cube -> one HolidayCoro AlphaPix Flex 48-output system
```

The older addressing workbook rows/IP entries remain preserved as source/configuration evidence. They must not be deleted or silently rewritten, but FieldWiring must not use them to present Mega Cube as three physical controllers.

This is another example of why physical-controller count cannot be derived mechanically from universe blocks, compatibility rows, IP rows, or spreadsheet grouping.

## Mega Tree / Mega Cube Pattern

Mega Tree and Mega Cube both demonstrate the same important dense-RGB rule:

```text
many E1.31 universe/addressing rows
        -> one physical HolidayCoro AlphaPix Flex 48-output system
```

For Mega Tree, the 48 physical outputs correspond to the 48 ribbons around the tree.

For Mega Cube, the physical controller is likewise one AlphaPix Flex 48-output system. Detailed output-to-section mapping continues to come from the current LOR/V7 topology plus reviewed controller-side configuration evidence; this finding does not invent missing physical port assignments.

## PixCon16 Dense RGB Cases

The current physical PixCon16 cases confirmed here are:

```text
Mega Ball       -> 1 PixCon16
Whoville Matrix -> 1 PixCon16
Mega Star       -> 2 PixCon16
```

Mega Star therefore remains a valid example of one Display using multiple physical controllers.

Mega Ball and Whoville Matrix are examples of one dense RGB Display using one physical PixCon16 while spanning multiple E1.31 universe/channel relationships.

## Naming Reconciliation Note — Whoville Matrix

The existing `FieldWiring_E131_Dense_RGB_Field_Presentation_Contract.md` currently contains a section titled `Mt. Crumpit Matrix` whose V7 `lor_comment` is recorded as `WV-WhoMatrix`.

This finding records the operator term **Whoville Matrix** and the confirmed physical controller fact of one PixCon16.

Do not silently assume or rewrite Stage/Display naming solely from this note. The current V7 Display/Scene identity and naming should be reconciled against the repository/current snapshot separately. The physical controller fact is confirmed regardless of that naming cleanup.

## FieldWiring Presentation Consequence

FieldWiring should eventually present these dense RGB Displays using physical-controller contexts rather than universe numbers as controller identities:

```text
Mega Tree
    HolidayCoro AlphaPix Flex 48-output system
    Outputs 1-48

Mega Ball
    PixCon16
    physical outputs as resolved from current topology/controller configuration

Mega Cube
    HolidayCoro AlphaPix Flex 48-output system
    Outputs 1-48 / current resolved connections

Whoville Matrix
    PixCon16
    physical outputs as resolved from current topology/controller configuration

Mega Star
    PixCon16 controller 1
    PixCon16 controller 2
```

Temporary FieldWiring labels may be used until permanent Controller Inventory `ctrl_id` values are available. Those labels are presentation placeholders, not permanent hardware identity.

## Controller Inventory Handoff

The future Controller Inventory resolver should replace temporary dense-RGB physical-controller labels with permanent `ctrl_id` values without changing the FieldWiring browser presentation model.

The eventual resolver must support:

- one physical controller spanning many E1.31 universes;
- one Display using more than one physical controller;
- exact controller model/capability distinct from universe/IP addressing;
- current assignment only, reconciled to the current approved LOR/V7 snapshot;
- controller-side E1.31-to-physical-port configuration where required for field hookup; and
- Display/component/output relationships supplied from LOR/V7 where available rather than duplicated unnecessarily in Controller Inventory.

## Supersession Rule

Where this document conflicts with earlier FieldWiring assumptions about physical controller count/model for Mega Cube or the listed dense RGB Displays, this operator-confirmed finding controls the FieldWiring recovery design until newer authoritative physical evidence is documented.

## Related Documents

- [FieldWiring E1.31 Dense RGB Field Presentation Contract](FieldWiring_E131_Dense_RGB_Field_Presentation_Contract.md)
- [FieldWiring / Controller Inventory Handoff — 2026-08-20](FieldWiring_Controller_Inventory_Handoff_2026-08-20.md)
- [FieldWiring Controller Inventory Design Rationale — 2026-08-20](FieldWiring_Controller_Inventory_Design_Rationale_2026-08-20.md)
- [Controller Inventory Current-State / FieldWiring Integration Plan — 2026-08-20](../08_Controller_Inventory/Controller_Inventory_Current_State_FieldWiring_Integration_Plan_2026-08-20.md)
