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

A raw LOR Unit ID or Unit-ID range is **not** a permanent controller identity.

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

The existing spreadsheet must be reviewed as the current source artifact before the PostgreSQL schema is designed so existing controller types, network relationships, and other tracked metadata are not lost.

## 5. Deployment History

Controllers may move between displays or installations. The system should preserve deployment history rather than overwriting prior assignments.

Future integration should relate permanent controller identity to:

- displays
- physical/site location where relevant
- current LOR Unit ID / base-address or Unit-ID range used for the deployment
- physical output numbering/capability
- Wiring System
- Network Infrastructure
- Work Orders and repair history

## 6. Configuration Boundary

Controller inventory may retain technical metadata needed for inventory, lookup, history, diagnostics, and field use.

However, **LOR remains authoritative for show topology and wiring configuration**, including controller/channel/network assignments used by the show. The Controller Inventory subsystem must not become a competing topology-authoring system.

The current V7 LOR-derived data already carries `string_type`, which FieldWiring can use to distinguish conventional `Traditional` LOR hookup from `RGB` Pixie/pixel hookup. Controller Inventory is not required merely to detect that distinction.

Controller Inventory is required for a different responsibility: identifying the **actual physical controller asset** and authoritatively relating its current LOR addressing to its numbered physical outputs.

That distinction is particularly important for Pixie controllers. One physical Pixie may own several contiguous LOR Unit IDs—one logical address per RGB output—so FieldWiring must not treat every Unit ID as a separate physical controller. The physical controller record/deployment relationship must eventually provide the grouping authority.

For a conventional A/C controller, physical Output 1-16 maps directly to the LOR channel/output number. For Pixie 2/4/8/16 controllers, one physical controller has 2/4/8/16 numbered RGB outputs while LOR may use a Unit-ID range across those outputs.

See [FieldWiring Physical Controller / Output Presentation Contract](../09_Wiring_System/FieldWiring_Physical_Controller_Output_Presentation_Contract.md).

## 7. Duplicate LOR Address Ranges Are Valid

FieldWiring engineering review exposed a critical physical-controller requirement: **LOR Unit IDs are not unique physical-controller identifiers.**

The Church RGB Candy Cane installation intentionally uses two separate Pixie 4 physical controllers with the same LOR Unit-ID range:

```text
Pixie A -> 21-24
Pixie B -> 21-24
```

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
- network + Unit ID/range must not be assumed to be a unique physical-controller key;
- deployment/history relationships must be able to associate distinct controller assets with identical LOR address ranges;
- physical output/port mapping must remain tied to the correct controller asset/deployment relationship; and
- valid duplicated addressing must not be treated automatically as a reconciliation error.

This requirement is planning guidance only. The current spreadsheet and real controller inventory must still be inspected before any PostgreSQL schema is designed.

## 8. Physical Output Models

Controller Inventory must be able to distinguish controller families whose physical hookup differs even when LOR addressing is valid for both.

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
```

The Church acceptance examples currently include:

- RGB Tree — one Pixie 16, logical Unit IDs `30-3F`, physical Outputs 1-16;
- Left/Right RGB Crosses — one Pixie 2 per Cross, logical ranges `42-43` and `44-45`, physical Outputs 1-2; and
- eight RGB Candy Canes — two Pixie 4 controllers intentionally sharing Unit IDs `21-24`.

FieldWiring uses current LOR `string_type` to distinguish Traditional versus RGB presentation, but Controller Inventory is needed to identify the actual physical controller asset, model, output count, and deployment mapping when LOR topology alone is insufficient.

## 9. Maintenance and Repair History

The subsystem should eventually support controller repair and maintenance history, parts or actions performed, test results where appropriate, responsible people, and Work Order relationships.

Historical maintenance records must be preserved rather than replaced by only the latest state.

## 10. Labeling Requirements

Controller labels should support durable physical identification and technical lookup. The planning direction includes human-readable identity plus machine-readable codes compatible with the shared Labeling and Scanning subsystem.

The field-facing controller label should allow a volunteer to identify the physical controller without needing to interpret its current hexadecimal LOR Unit ID or Unit-ID range.

The final barcode/QR layout and scan route must follow the current LabelPrintService and application architecture rather than obsolete Directus URL assumptions.

## 11. Related Systems

- [Labeling and Scanning](../07_Labeling_and_Scanning/README.md)
- [Wiring System](../09_Wiring_System/README.md)
- [FieldWiring Physical Controller / Output Presentation Contract](../09_Wiring_System/FieldWiring_Physical_Controller_Output_Presentation_Contract.md)
- [Network Infrastructure](../10_Network_Infrastructure/README.md)
- [Work Orders](../06_Work_Orders/README.md)

## 12. Current Open Work

Before database implementation:

1. inventory the current spreadsheet structure and controller types;
2. identify current permanent versus deployment-specific fields;
3. identify network and wiring relationships;
4. identify how conventional A/C, Pixie 2, Pixie 4, Pixie 8, Pixie 16, DMX, DumbRGB, and other controller classes are represented in the current inventory source;
5. document current cases where LOR Unit IDs/ranges are intentionally reused by more than one physical controller;
6. define a permanent controller identity that preserves existing useful identifiers without depending on LOR Unit ID uniqueness;
7. define how one physical controller is related to its current LOR Unit ID or Unit-ID range and numbered physical outputs;
8. design lifecycle/deployment history without overwriting evidence;
9. define how physical controller/output assignments enrich FieldWiring without competing with LOR topology; and
10. reconcile controller labeling with the current LabelPrintService.
