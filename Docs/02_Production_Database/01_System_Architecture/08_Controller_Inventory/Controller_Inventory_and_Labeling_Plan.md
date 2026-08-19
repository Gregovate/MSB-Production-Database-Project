# MSB Controller Inventory and Labeling Plan

**Status:** Planning / engineering foundation  
**Purpose:** Define controller asset identity, inventory direction, lifecycle needs, deployment history, and labeling requirements.

## 1. Purpose

Controllers are complex technical assets that require unique identification, lifecycle tracking, configuration context, deployment history, repair history, and durable physical labeling.

This document preserves the current planning foundation for a dedicated Controller Inventory subsystem. The current authoritative inventory source remains outside PostgreSQL and must be reviewed before schema implementation.

## 2. Scope

Applies to electronic controller and related control hardware used by MSB, including lighting controllers, pixel controllers, power/control devices, network-related controller hardware, and custom control equipment where appropriate.

## 3. Permanent Identity

Each physical controller requires a stable MSB identity independent of its current deployment location or LOR assignment.

The planning convention uses:

```text
CTRL:<controller_key>
```

Example:

```text
CTRL:CL-042
```

The key must remain stable over the controller's lifetime.

A raw LOR Unit ID, DMX/E1.31 universe, universe range, or IP address is **not** a permanent controller identity.

## 4. Inventory Record Direction

A controller master record should support, at minimum:

- permanent controller identity
- controller type/classification
- manufacturer/model
- physical output count/capability where applicable
- serial number where available
- acquisition information
- lifecycle status
- notes

The current physical controller inventory remains outside PostgreSQL and must be reviewed before the PostgreSQL schema is designed so existing controller types, network relationships, labels, and deployment information are not lost.

## 5. Known Source Artifacts

### Current physical controller inventory

The current controller inventory source has not yet been inspected in this workstream. It is held separately and is expected later.

Do not finalize controller schema, permanent identities, or deployment mapping before that source is reviewed.

### Historical E1.31 / DMX addressing workbook

A user-supplied workbook:

```text
DMX Control Addressing.xlsx
```

was historically used to track E1.31/DMX universes, physical controller outputs, and IP addresses.

It contains useful physical-controller evidence, including:

```text
Mega Tree
    Alpha Pix / Flex48
    10.10.5.10
    Outputs 1-48 -> Universes 1-48

Mega Ball
    PixCon 16
    10.10.5.11
    Outputs 1-16 -> Universes 49-64

Mega Cube
    three PixCon 16 controllers
    10.10.5.12 / 10.10.5.13 / 10.10.5.14

Mega Star
    two PixCon 16 controllers
    10.10.5.15 / 10.10.5.16

Mt. Crumpit
    PixCon 16
    10.10.5.17
    Outputs 1-16 -> Universes 147-162

Northern Lights / PixieLink
    10.10.5.30
```

The workbook also contains historical configuration columns such as `IP 2023`, `IP 2024`, `Original Config`, and `2023 Config`.

Therefore it must be preserved as **engineering/configuration evidence**, not promoted automatically to current permanent-controller authority.

It should be reconciled with the current physical controller inventory when that source becomes available.

See [FieldWiring E1.31 Dense RGB Field Presentation Contract](../09_Wiring_System/FieldWiring_E131_Dense_RGB_Field_Presentation_Contract.md).

## 6. Deployment History

Controllers may move between displays or installations. The system should preserve deployment history rather than overwriting prior assignments.

Future integration should relate permanent controller identity to:

- displays
- physical/site location where relevant
- current LOR Unit ID / base-address or Unit-ID range used for the deployment
- DMX/E1.31 universe range where applicable
- controller-management IP address where applicable
- physical output numbering/capability
- Wiring System
- Network Infrastructure
- Work Orders and repair history

Configuration values such as IP address or universe range may change over time and must not replace permanent physical identity.

## 7. Configuration Boundary

Controller inventory may retain technical metadata needed for inventory, lookup, history, diagnostics, and field use.

However, **LOR remains authoritative for show topology and wiring configuration**, including controller/channel/network assignments used by the show. The Controller Inventory subsystem must not become a competing topology-authoring system.

The current V7 LOR-derived data already carries `string_type`, which FieldWiring can use to distinguish conventional `Traditional` LOR hookup from `RGB` Pixie/pixel hookup and, together with `device_type`, distinguish reviewed DMX/DumbRGB and E1.31 dense-RGB cases.

Controller Inventory is required for a different responsibility: identifying the **actual physical controller asset** and authoritatively relating its current LOR/DMX/E1.31 addressing to numbered physical outputs/ports.

That distinction is particularly important for Pixie and E1.31 controllers:

- one physical Pixie may own several contiguous LOR Unit IDs;
- more than one physical Pixie may intentionally reuse the same Unit-ID range;
- one physical E1.31 controller may serve many universes;
- one Display may require multiple physical E1.31 controllers; and
- compatibility-view `Controller` values may represent Unit IDs or universe addressing rather than physical controller boxes.

For a conventional A/C controller, physical Output 1-16 maps directly to the LOR channel/output number. For Pixie 2/4/8/16 controllers, one physical controller has 2/4/8/16 numbered RGB outputs while LOR may use a Unit-ID range across those outputs.

See:

- [FieldWiring Physical Controller / Output Presentation Contract](../09_Wiring_System/FieldWiring_Physical_Controller_Output_Presentation_Contract.md)
- [FieldWiring E1.31 Dense RGB Field Presentation Contract](../09_Wiring_System/FieldWiring_E131_Dense_RGB_Field_Presentation_Contract.md)

## 8. Duplicate RGB Addresses Are Valid and Informative

FieldWiring engineering review exposed two related requirements:

1. **LOR Unit IDs are not unique physical-controller identifiers.**
2. **When separate RGB Props in the same current wiring context reuse the same Unit ID, the duplication is positive evidence that another physical Pixie controller instance exists.**

The Church RGB Candy Cane installation intentionally uses two separate Pixie 4 physical controllers with the same LOR Unit-ID range:

```text
Pixie A -> 21-24
Pixie B -> 21-24
```

The repeated `21-24` block is the signal that the second physical controller exists.

This is deliberate so paired Candy Canes receive the same programmed signals:

```text
Candy Cane 01 and 05 -> Unit ID 21
Candy Cane 02 and 06 -> Unit ID 22
Candy Cane 03 and 07 -> Unit ID 23
Candy Cane 04 and 08 -> Unit ID 24
```

Therefore future Controller Inventory design must preserve these facts:

- permanent controller identity is independent of LOR Unit ID;
- the same Unit ID/range may be assigned to more than one physical controller in the same show design;
- duplicate RGB addresses can be used as evidence that multiple physical controller instances exist;
- duplicate addresses do not by themselves provide the permanent controller asset identity or always define the complete grouping/order;
- network + Unit ID/range must not be assumed to be a unique physical-controller key;
- deployment/history relationships must be able to associate distinct controller assets with identical LOR address ranges;
- physical output/port mapping must remain tied to the correct controller asset/deployment relationship; and
- valid duplicated addressing must not be treated automatically as a reconciliation error.

The current `17-Candyland-CL` musical data also contains repeated RGB Candy Cane Unit IDs, confirming that this is a general controller-model requirement rather than a Church-only exception.

This requirement is planning guidance only. The current physical inventory still must be inspected before any PostgreSQL schema is designed.

## 9. Physical Output Models

Controller Inventory must be able to distinguish controller families whose physical hookup differs even when LOR/DMX addressing is valid for all of them.

Current examples include:

```text
Traditional A/C controller
    one Unit ID
    physical outputs 1-16
    StartChannel maps directly to numbered output

Pixie 2
    physical RGB outputs 1-2

Pixie 4
    physical RGB outputs 1-4

Pixie 8
    physical RGB outputs 1-8

Pixie 16
    physical RGB outputs 1-16

AlphaPix / Flex48
    physical outputs 1-48
    many E1.31 universes

PixCon 16
    physical outputs 1-16
    E1.31 universe ranges assigned by deployment

DMX / DumbRGB network devices
    field hookup may be network/fixture oriented rather than numbered controller-output oriented
```

Current FieldWiring acceptance examples include:

- Church RGB Tree — one Pixie 16, logical Unit IDs `30-3F`, physical Outputs 1-16;
- Church Left/Right RGB Crosses — one Pixie 2 per Cross, physical Outputs 1-2;
- Church RGB Candy Canes — two Pixie 4 controllers intentionally sharing Unit IDs `21-24`;
- Candyland RGB Candy Canes — three Pixie 4 controllers intentionally repeating `21-24`;
- Who Forest — eight separated Pixie 8 controller blocks;
- Santa's Workshop — two separated Pixie 8 controller blocks;
- Mega Tree — one AlphaPix/Flex48 serving Universes 1-48;
- Mega Ball — one PixCon 16 serving Universes 49-64;
- Mega Cube — three PixCon 16 controllers;
- Mega Star — two PixCon 16 controllers; and
- Mt. Crumpit — one PixCon 16 mapped in the addressing workbook.

FieldWiring uses current topology/device metadata to choose the presentation family, but Controller Inventory is needed to identify the actual physical controller asset, model, output count, label, and authoritative deployment mapping.

## 10. Maintenance and Repair History

The subsystem should eventually support controller repair and maintenance history, parts or actions performed, test results where appropriate, responsible people, and Work Order relationships.

Historical maintenance records must be preserved rather than replaced by only the latest state.

## 11. Labeling Requirements

Controller labels should support durable physical identification and technical lookup. The planning direction includes human-readable identity plus machine-readable codes compatible with the shared Labeling and Scanning subsystem.

The field-facing controller label should allow a volunteer to identify the physical controller without needing to interpret its current hexadecimal LOR Unit ID, DMX universe, E1.31 universe range, or management IP address.

The final barcode/QR layout and scan route must follow the current LabelPrintService and application architecture rather than obsolete Directus URL assumptions.

## 12. Related Systems

- [Labeling and Scanning](../07_Labeling_and_Scanning/README.md)
- [Wiring System](../09_Wiring_System/README.md)
- [FieldWiring Physical Controller / Output Presentation Contract](../09_Wiring_System/FieldWiring_Physical_Controller_Output_Presentation_Contract.md)
- [FieldWiring E1.31 Dense RGB Field Presentation Contract](../09_Wiring_System/FieldWiring_E131_Dense_RGB_Field_Presentation_Contract.md)
- [Network Infrastructure](../10_Network_Infrastructure/README.md)
- [Work Orders](../06_Work_Orders/README.md)

## 13. Current Open Work

Before database implementation:

1. obtain and inspect the current physical controller inventory;
2. reconcile the current inventory with `DMX Control Addressing.xlsx` and other historical controller/addressing artifacts;
3. identify current permanent versus deployment-specific fields;
4. identify network and wiring relationships;
5. identify how conventional A/C, Pixie 2, Pixie 4, Pixie 8, Pixie 16, AlphaPix/Flex48, PixCon 16, DMX, DumbRGB, and other controller classes are represented in the current inventory source;
6. document current cases where LOR Unit IDs/ranges are intentionally reused by more than one physical controller;
7. define a permanent controller identity that preserves existing useful identifiers without depending on LOR Unit ID, universe, or IP-address uniqueness;
8. define how one physical controller is related to its current LOR Unit ID/range or DMX/E1.31 universe range and numbered physical outputs;
9. design lifecycle/deployment history without overwriting evidence;
10. define how physical controller/output assignments enrich FieldWiring without competing with LOR topology;
11. preserve historical configuration evidence such as prior IP/universe maps without treating it as the current controller master; and
12. reconcile controller labeling with the current LabelPrintService.
