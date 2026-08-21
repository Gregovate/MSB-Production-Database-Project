# MSB Controller Inventory and Labeling Plan

**Status:** Planning / engineering foundation  
**Purpose:** Define permanent controller asset identity, model/capability data, current snapshot assignment, firmware history, and labeling requirements.

## 1. Purpose

Controllers require unique permanent identification, accurate hardware/model information, current configuration context, firmware tracking, Work Order linkage when repair is needed, and durable physical labeling.

This document preserves the planning foundation for a dedicated Controller Inventory subsystem.

The 2025 working controller inventory source has now been inspected directly. It is useful source evidence, but it is not a finished/current 2026 permanent asset register and must be reconciled with current LOR/V7 topology and E1.31 addressing evidence before PostgreSQL schema implementation.

See [Controller Inventory 2025 Source Audit — 2026-08-19](Controller_Inventory_2025_Source_Audit_2026-08-19.md).

For the current FieldWiring integration direction, see [Controller Inventory Current-State / FieldWiring Integration Plan — 2026-08-20](Controller_Inventory_Current_State_FieldWiring_Integration_Plan_2026-08-20.md).

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
- generic controller type/classification;
- manufacturer and exact model;
- generation or hardware revision where applicable;
- physical output count/capability where applicable;
- serial number where available;
- current lifecycle/status such as Active, Spare, Needs Repair, or Retired;
- optional acquisition information when actually known;
- optional first-known-use information when supportable; and
- notes.

Unknown purchase or original deployment dates for older controllers should remain unknown rather than being guessed. A Display build year may be useful as evidence for a later `First Known Use Year`, but it must not be represented as a purchase date.

### Current assignment direction

Controller assignment is current-state data associated with the **current approved LOR/V7 snapshot**.

Do not manually duplicate Stage/Scene/Display/output relationships that the current snapshot already derives when the physical controller can be associated with a unique current address.

For a unique LOR address, the physical Controller Inventory fact may be conceptually as simple as:

```text
CL-017
Network: Regular
Unit ID: 41
```

The current LOR/V7 snapshot then provides the current Displays and wiring/output relationships using that address.

Current controller evidence may include, as applicable:

- current LOR Network;
- current Unit ID / Unit-ID range;
- current E1.31 controller/IP context;
- current universe/address range when needed for reconciliation;
- Stage/Scene or another simple physical-context description; and
- a distinguishing Display/group only when duplicate addressing or another ambiguity requires it.

The eventual current-assignment relationship must also make it possible to determine which approved LOR/V7 snapshot it was reconciled against. No specific PostgreSQL column or table is authorized yet.

FieldWiring does **not** require a deployment-history relationship model. When a controller assignment changes, the current assignment can be reconciled/updated to the newly approved snapshot. Older LOR snapshots and preserved source artifacts remain available as engineering evidence.

The inspected source demonstrates the need for controlled model normalization. Source variants include `Pixicon-16`, `Pixiecon 16`, `PixCon16`, `Pixie-16`, `Pixie16D`, `32LD-G3`, and broad labels such as `Coro`/`CORO`.

Do not silently normalize source evidence. Define an explicit model-reference mapping after physical/model review.

`PixCon16` and `Pixie-16` are different devices and must never be normalized into one exact model merely because the names look similar.

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

Controller Inventory supplies the permanent physical asset identity and current association needed to turn raw addressing into human field instructions.

## 7. Duplicate Addresses Are Valid and Need a Distinguishing Group

LOR Unit IDs are not unique physical-controller identifiers.

Current Church and Candyland RGB Candy Cane patterns intentionally reuse the same Unit-ID ranges on multiple physical Pixie controllers. The duplicate address proves that address alone cannot identify the physical controller.

The current assignment design must therefore allow distinct controller assets to carry identical Unit-ID ranges when that is how the current show snapshot is programmed.

During source cleanup, record one additional plain-language distinguishing group when needed, for example:

```text
CL-042 | 21-24 | Candy Canes 1-4
CL-043 | 21-24 | Candy Canes 5-8
CL-044 | 21-24 | Candy Canes 9-12
```

The eventual PostgreSQL representation of that distinction must be designed from the reviewed source data rather than assumed in advance.

Do not define `network + Unit ID/range` as a unique physical-controller key or create a rule that prohibits intentional repeated addresses.

## 8. Physical Output Models / Current Acceptance Examples

Controller Inventory must represent controller families whose field hookup differs materially.

Current examples include:

```text
Traditional A/C
    physical Outputs 1-16 where applicable

Pixie 2
    RGB Outputs 1-2

Pixie 4
    RGB Outputs 1-4

Pixie 8
    RGB Outputs 1-8

Pixie 16
    RGB Outputs 1-16

PixCon16
    separate intelligent pixel-controller model; physical output capability must remain model-specific

AlphaPix / Flex48-style controller
    dense E1.31 controller context; exact model/capability must be verified from physical/source evidence
```

Current FieldWiring evidence includes:

- Church Tree — one Pixie 16;
- Church Crosses — Pixie 2 controllers;
- Church/Candyland Candy Canes — repeated Pixie 4 address blocks;
- Who Forest — eight Pixie 8 controller blocks;
- Santa's Workshop — two current Pixie 8 Tree blocks in V7;
- Mega Tree — one 48-output dense E1.31 controller context in the current evidence;
- Mega Ball — one PixCon16 context;
- Mega Cube — three PixCon16 controllers;
- Mega Star — two PixCon16 controllers; and
- Mt. Crumpit — one PixCon16 in the addressing evidence.

Exact controller models must be verified where current source terminology conflicts.

## 9. 2025 Source Reconciliation Findings

The inspected 2025 inventory materially helps, but it does not fully match current 2026 topology.

Important findings:

- Who Forest contains eight explicit `Pixie8` inventory rows with ranges `50-57` through `88-8F`, strongly confirming the eight physical controller blocks;
- Who Forest Tree 4 is recorded on `Aux-F` in the 2025 inventory while current V7 shows `Aux-I`; preserve this as a review item;
- current Santa's Workshop Pixie 8 Tree controllers are not represented in the 2025 inventory;
- current Church Pixie 16 / Pixie 2 / repeated Pixie 4 controllers are absent;
- current Candyland repeated Pixie 4 controllers are absent;
- Mega Star is absent from the 2025 E1.31 inventory rows;
- Mega Cube is represented by one aggregate `48` row even though current physical evidence identifies three PixCon16 controllers; and
- older `192.168.5.x` E1.31 IP evidence appears in the 2025 inventory while `DMX Control Addressing.xlsx` carries newer `10.10.5.x` configuration evidence.

These are reconciliation findings, not permission to rewrite either source.

## 10. Firmware History and Work Order Boundary

Firmware is the controller-specific history that Controller Inventory should preserve.

A firmware update/verification record should eventually be able to identify:

- permanent controller identity;
- firmware version;
- install or verification date;
- person who installed or verified it;
- optional notes; and
- optional Work Order reference where the firmware change was part of repair/troubleshooting.

The lookup table's `Latest Firmware` value is model-reference information and must not overwrite or substitute for the version actually installed on a physical controller.

Repairs, troubleshooting, parts replacement, maintenance actions, testing associated with a repair, and repair resolution belong in the existing Work Order subsystem. Controller Inventory should link the permanent controller asset to the applicable Work Orders rather than maintaining a second repair-history system.

## 11. Labeling Requirements

Controller labels should support durable physical identification and technical lookup.

The field-facing label should allow a volunteer to identify the physical controller without needing to interpret its current hexadecimal Unit ID, universe, or IP address.

The final barcode/QR layout and scan route must follow the current LabelPrintService and application architecture.

## 12. FieldWiring Integration Direction

FieldWiring is a consumer of Controller Inventory and does not own the Controller Inventory schema.

While Controller Inventory source data is being reviewed, FieldWiring may continue using isolated, operator-confirmed temporary controller groupings for known physical cases. These are presentation/recovery rules, not permanent controller identities.

FieldWiring should keep those rules behind a replaceable controller-resolution boundary so the browser can later consume an authoritative PostgreSQL Controller Inventory read contract without redesigning the presentation layer.

The future interface is expected to provide enough information to determine:

- permanent physical controller identity;
- exact model/family and physical output capability;
- current address/controller context;
- the distinguishing group when identical addresses are intentionally reused; and
- which approved LOR/V7 snapshot the mapping was reconciled against.

See [Controller Inventory Current-State / FieldWiring Integration Plan — 2026-08-20](Controller_Inventory_Current_State_FieldWiring_Integration_Plan_2026-08-20.md).

## 13. Related Systems

- [Controller Inventory Current-State / FieldWiring Integration Plan — 2026-08-20](Controller_Inventory_Current_State_FieldWiring_Integration_Plan_2026-08-20.md)
- [Controller Inventory 2025 Source Audit — 2026-08-19](Controller_Inventory_2025_Source_Audit_2026-08-19.md)
- [FieldWiring / Controller Inventory Handoff — 2026-08-20](../09_Wiring_System/FieldWiring_Controller_Inventory_Handoff_2026-08-20.md)
- [Labeling and Scanning](../07_Labeling_and_Scanning/README.md)
- [Wiring System](../09_Wiring_System/README.md)
- [FieldWiring Physical Controller / Output Presentation Contract](../09_Wiring_System/FieldWiring_Physical_Controller_Output_Presentation_Contract.md)
- [FieldWiring E1.31 Dense RGB Field Presentation Contract](../09_Wiring_System/FieldWiring_E131_Dense_RGB_Field_Presentation_Contract.md)
- [Network Infrastructure](../10_Network_Infrastructure/README.md)
- [Work Orders](../06_Work_Orders/README.md)

## 14. Current Open Work

Before PostgreSQL controller implementation:

1. preserve the 2025 inventory and lookup table as source artifacts;
2. reconcile them against current 2026 V7/LOR topology;
3. reconcile E1.31 inventory rows with `DMX Control Addressing.xlsx`;
4. identify current additions/removals and resolve source conflicts;
5. normalize controller model/reference terminology without altering source evidence;
6. define permanent controller identity independent of Unit ID, universe, IP, Display, and location;
7. identify the current address/context for each physical controller;
8. identify distinguishing Display/groups only for intentional duplicate-address or ambiguous controller contexts;
9. define current-snapshot provenance/currentness requirements;
10. define and review the minimum current-state read interface consumed by FieldWiring;
11. define firmware history requirements; and
12. reconcile controller labeling with the current LabelPrintService.

No PostgreSQL Controller Inventory schema change is authorized until this reconciliation demonstrates the required permanent identity and minimum current-assignment fields.
