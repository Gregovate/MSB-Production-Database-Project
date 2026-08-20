# MSB Controller Inventory and Labeling Plan

**Status:** Planning / engineering foundation  
**Purpose:** Define controller asset identity, inventory direction, lifecycle needs, current assignment, and labeling requirements.

## 1. Purpose

Controllers are complex technical assets that require unique identification, lifecycle tracking, configuration context, current assignment, repair history, and durable physical labeling.

This document preserves the planning foundation for a dedicated Controller Inventory subsystem.

The 2025 working controller inventory source has now been inspected directly. It is useful source evidence, but it is not a finished/current 2026 permanent asset register and must be reconciled with current LOR/V7 topology and E1.31 addressing evidence before PostgreSQL schema implementation.

See [Controller Inventory 2025 Source Audit — 2026-08-19](Controller_Inventory_2025_Source_Audit_2026-08-19.md).

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

A raw LOR Unit ID, Unit-ID range, DMX/E1.31 universe, universe range, IP address, Display assignment, or Park Location is **not** a permanent controller identity.

The inspected 2025 inventory reinforces this requirement because its `Controller ID (HEX)` field contains single IDs, ranges, paired IDs, `IP`, and blanks.

## 4. Current Source Artifacts

### 2025 Controller Inventory / Firmware source

Inspected files:

```text
Controller Inventory & Firmware 2025 - Inventory.csv
Controller Inventory & Firmware 2025 - Lookup Table.csv
```

The inventory carries:

```text
Tested By
Complete
Display ID
Network
Changes
Model
Firmware
Controller ID (HEX)
Controller Type
Park Location
For What
```

The lookup table carries model, description, channel count, retail, and latest-firmware reference data.

The 2025 inventory is incomplete relative to current 2026 topology. Most populated rows remain marked incomplete, several current RGB controllers are absent, E1.31 rows include older configuration/IP evidence, and there is no durable physical-controller asset key.

### Historical / current E1.31 addressing evidence

`DMX Control Addressing.xlsx` records universe, physical output, and IP mapping history/current planning for dense E1.31 Displays.

It includes useful controller grouping evidence for Mega Tree, Mega Ball, Mega Cube, Mega Star, Mt. Crumpit, and Northern Lights/PixieLink.

This workbook is configuration evidence, not permanent controller identity. It contains multiple configuration eras and must be reconciled with the 2025 inventory and current V7 topology.

Historical material in source artifacts may remain preserved as engineering evidence. That does **not** create a requirement for Controller Inventory to maintain historical deployment relationships in PostgreSQL.

### Current LOR / V7 topology

Current V7/PostgreSQL remains authoritative for the current show topology and controller/network/channel assignments used by FieldWiring.

Controller Inventory must enrich that topology with physical asset identity rather than compete with it.

## 5. Inventory Record Direction

A controller master record should support, at minimum:

- permanent controller identity;
- controller type/classification;
- manufacturer/model;
- physical output count/capability where applicable;
- serial number where available;
- acquisition information;
- lifecycle status; and
- notes.

Current assignment relationships should carry the values needed to identify how each physical controller is assigned in the **current approved LOR/V7 snapshot**, such as:

- Stage/Scene/Display assignment;
- Park Location;
- LOR Unit ID / Unit-ID range;
- DMX/E1.31 universe range;
- controller-management IP address;
- physical output/port assignment; and
- network relationship.

FieldWiring does **not** require a deployment-history relationship model. When a controller assignment changes, the current assignment can be reconciled/updated to the current approved snapshot. Older LOR snapshots and preserved source artifacts remain available as engineering evidence; Controller Inventory does not need to duplicate them as historical deployment rows merely for FieldWiring.

The inspected source also demonstrates the need for controlled model normalization. Source variants include `Pixicon-16`, `Pixiecon 16`, `PixCon16`, `Pixie-16`, `Pixie16D`, `32LD-G3`, and broad labels such as `Coro`/`CORO`.

Do not silently normalize source evidence. Define an explicit model-reference mapping later.

## 6. Configuration Boundary

**LOR remains authoritative for show topology and wiring configuration.** Controller Inventory must not become a competing topology-authoring system.

Current topology/device metadata allows FieldWiring to choose the appropriate presentation family:

```text
Traditional LOR
    -> conventional A/C controller / physical outputs

LOR + RGB
    -> Pixie controller / physical RGB outputs

DMX + DumbRGB
    -> DMX network / fixture hookup

DMX + RGB
    -> reviewed dense E1.31 pixel-controller hookup
```

Controller Inventory supplies the physical asset identity and **current assignment mapping** needed to turn raw addressing into human field instructions.

## 7. Duplicate RGB Addresses Are Valid and Informative

LOR Unit IDs are not unique physical-controller identifiers.

Current Church and Candyland RGB Candy Cane patterns intentionally reuse the same Unit-ID ranges on multiple physical Pixie controllers. Duplicate RGB Unit IDs across separate Props are positive evidence that more than one physical controller instance exists, but the duplicate address alone does not provide the permanent controller identity.

The current assignment design must therefore allow distinct controller assets to carry identical Unit-ID ranges when that is how the current show snapshot is programmed.

Do not define `network + Unit ID/range` as a unique physical-controller key.

## 8. Physical Output Models / Current Acceptance Examples

Controller Inventory must represent controller families whose field hookup differs materially.

Current examples include:

```text
Traditional A/C
    physical Outputs 1-16

Pixie 2
    RGB Outputs 1-2

Pixie 4
    RGB Outputs 1-4

Pixie 8
    RGB Outputs 1-8

Pixie 16
    RGB Outputs 1-16

PixCon 16
    E1.31 physical Outputs 1-16

AlphaPix / Flex48-style controller
    E1.31 physical Outputs 1-48
```

Current FieldWiring evidence includes:

- Church Tree — one Pixie 16;
- Church Crosses — Pixie 2 controllers;
- Church/Candyland Candy Canes — repeated Pixie 4 address blocks;
- Who Forest — eight Pixie 8 controller blocks;
- Santa's Workshop — two current Pixie 8 Tree blocks in V7;
- Mega Tree — one 48-output AlphaPix/Flex48-style controller;
- Mega Ball — one PixCon 16;
- Mega Cube — three PixCon 16 controllers;
- Mega Star — two PixCon 16 controllers; and
- Mt. Crumpit — one PixCon 16 in the addressing evidence.

## 9. 2025 Source Reconciliation Findings

The inspected 2025 inventory materially helps, but it does not fully match current 2026 topology.

Important findings:

- Who Forest contains eight explicit `Pixie8` inventory rows with ranges `50-57` through `88-8F`, strongly confirming the eight physical controller blocks;
- Who Forest Tree 4 is recorded on `Aux-F` in the 2025 inventory while current V7 shows `Aux-I`; preserve this as a review item;
- current Santa's Workshop Pixie 8 Tree controllers are not represented in the 2025 inventory;
- current Church Pixie 16 / Pixie 2 / repeated Pixie 4 controllers are absent;
- current Candyland repeated Pixie 4 controllers are absent;
- Mega Star is absent from the 2025 E1.31 inventory rows;
- Mega Cube is represented by one aggregate `48` row even though current physical evidence identifies three PixCon controllers; and
- older `192.168.5.x` E1.31 IP evidence appears in the 2025 inventory while `DMX Control Addressing.xlsx` carries newer `10.10.5.x` configuration evidence.

These are reconciliation findings, not permission to rewrite either source.

## 10. Maintenance and Repair History

The subsystem should eventually support controller repair and maintenance history, parts/actions performed, test results, responsible people, and Work Order relationships.

Historical maintenance and firmware evidence must be preserved rather than overwritten by only the latest state.

This maintenance/repair history is separate from controller deployment assignment. No historical deployment-relationship requirement is implied by this section.

## 11. Labeling Requirements

Controller labels should support durable physical identification and technical lookup.

The field-facing label should allow a volunteer to identify the physical controller without needing to interpret its current hexadecimal Unit ID, universe, or IP address.

The final barcode/QR layout and scan route must follow the current LabelPrintService and application architecture.

## 12. Related Systems

- [Controller Inventory 2025 Source Audit — 2026-08-19](Controller_Inventory_2025_Source_Audit_2026-08-19.md)
- [Labeling and Scanning](../07_Labeling_and_Scanning/README.md)
- [Wiring System](../09_Wiring_System/README.md)
- [FieldWiring Physical Controller / Output Presentation Contract](../09_Wiring_System/FieldWiring_Physical_Controller_Output_Presentation_Contract.md)
- [FieldWiring E1.31 Dense RGB Field Presentation Contract](../09_Wiring_System/FieldWiring_E131_Dense_RGB_Field_Presentation_Contract.md)
- [Network Infrastructure](../10_Network_Infrastructure/README.md)
- [Work Orders](../06_Work_Orders/README.md)

## 13. Current Open Work

Before PostgreSQL controller implementation:

1. preserve the 2025 inventory and lookup table as source artifacts;
2. reconcile them against current 2026 V7/LOR topology;
3. reconcile E1.31 inventory rows with `DMX Control Addressing.xlsx`;
4. identify current additions/removals and resolve source conflicts;
5. normalize controller model/reference terminology without altering source evidence;
6. define a permanent controller identity independent of Unit ID, universe, IP, Display, and location;
7. define **current assignment relationships** for the current approved snapshot, including current addressing, network, physical output, and location;
8. preserve duplicate-address and source-evidence conflicts without creating a deployment-history requirement;
9. define the current-state read relationship consumed by FieldWiring; and
10. reconcile controller labeling with the current LabelPrintService.

No PostgreSQL controller schema change is authorized until this reconciliation demonstrates the required permanent identity and current-assignment fields. A historical deployment relationship model is not required for FieldWiring.
