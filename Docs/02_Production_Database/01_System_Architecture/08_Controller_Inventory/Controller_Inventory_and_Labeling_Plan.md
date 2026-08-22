# MSB Controller Inventory and Labeling Plan

**Status:** Planning / engineering foundation  
**Purpose:** Define permanent controller asset identity, model/capability data, current snapshot assignment, firmware history, Work Order boundary, and labeling requirements.

## 1. Purpose

Controllers require unique permanent identification, accurate hardware/model information, current configuration context, firmware tracking, Work Order linkage when repair is needed, and durable physical labeling.

The current working review source is now:

```text
Controller Inventory & Testing 2026.xlsx
```

The older 2025 CSVs and `DMX Control Addressing.xlsx` remain supporting engineering evidence.

See:

- [Controller Inventory 2026 Source Audit — 2026-08-22](Controller_Inventory_2026_Source_Audit_2026-08-22.md)
- [Controller Inventory Current-State / FieldWiring Integration Plan](Controller_Inventory_Current_State_FieldWiring_Integration_Plan_2026-08-20.md)

No PostgreSQL controller schema is authorized until the 2026 working data has been reviewed and accepted.

## 2. Scope

Applies to electronic controller and related control hardware used by MSB, including lighting controllers, pixel controllers, power/control devices, network-related controller hardware, and custom control equipment where appropriate.

## 3. Permanent Identity

Each physical controller requires a stable MSB identity independent of its current location or LOR assignment.

The planning convention remains:

```text
CTRL:<controller_key>
```

Example:

```text
CTRL:CL-042
```

The key remains stable over the controller's lifetime.

The following are **not** permanent controller identity:

- LOR Unit ID;
- Unit-ID range;
- E1.31 universe/range;
- IP address;
- Display name;
- Stage/Scene;
- physical location; or
- spreadsheet row position.

The 2026 workbook reinforces this requirement because many physically separate controllers legitimately share addressing and some rows are otherwise identical until permanent asset identity is established.

## 4. Current Source Artifacts

### Current working inventory

`Controller Inventory & Testing 2026.xlsx` contains:

```text
Inventory
Lookup Table
Instructions to Update
```

The Inventory sheet currently contains 161 populated controller rows and includes current Pixie and E1.31 hardware that was missing from the older 2025 source.

The 2026 workbook is still a working review tool. Permanent controller keys have not yet been assigned and repeated rows cannot safely be deduplicated until the physical assets are distinguished.

### Prior inventory evidence

```text
Controller Inventory & Firmware 2025 - Inventory.csv
Controller Inventory & Firmware 2025 - Lookup Table.csv
```

These remain useful for comparison and historical evidence but are no longer the primary current working inventory.

### E1.31 addressing evidence

`DMX Control Addressing.xlsx` records useful universe/output/IP configuration evidence across multiple configuration eras.

It is addressing/configuration evidence, not permanent controller identity.

### Current LOR/V7 topology

The current approved LOR/V7 PostgreSQL snapshot remains authoritative for current show topology, wiring, Stage/Scene/Display context, Unit IDs, channel relationships, and DMX/E1.31 universe/channel rows.

Controller Inventory enriches that topology with permanent physical-controller identity and the minimum current physical assignment/context that LOR cannot represent.

## 5. Controller Master Direction

A permanent controller record is expected to need, at minimum:

- permanent controller identity;
- generic controller class;
- manufacturer;
- exact model;
- generation/hardware revision where applicable;
- physical output/port count/capability;
- serial number when available;
- current status such as Active, Spare, Needs Repair, or Retired;
- optional acquisition information when actually known;
- optional first-known-use information when supportable; and
- notes.

Unknown purchase or original deployment dates for older controllers should remain unknown rather than being guessed.

A Display build year may later support a `First Known Use Year`, but it must not be represented as a purchase date unless actual purchase evidence exists.

## 6. Model Normalization

A generic controller description is useful for people, but the exact hardware model must remain distinct.

For example:

```text
Generic class: Pixel Controller
Exact model:   PixCon16
```

`PixCon16` and Pixie-16 are different devices and must never be normalized into one exact model.

The current 2026 source still uses model labels that do not all have exact matches in the Lookup Table. Do not normalize similar names automatically. Confirm actual hardware/model first, then create the controlled model-reference mapping.

## 7. Current Assignment Direction

Controller assignment is current-state data associated with the **current approved LOR/V7 snapshot**.

The inventory team does **not** need to manually duplicate every Display/output relationship that LOR already provides.

For a unique LOR address, the physical inventory fact may be conceptually as simple as:

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
- current universe/address range when needed to associate physical E1.31 hardware;
- Stage/Scene or another simple physical-context description; and
- a distinguishing Display/group only when duplicate addressing or another ambiguity requires it.

The eventual assignment/read interface must also make it possible to determine which approved LOR/V7 snapshot the mapping was reconciled against.

No specific PostgreSQL table or column is authorized yet.

## 8. No Deployment History Requirement

FieldWiring does not require a controller deployment-history model.

When a controller assignment changes, its current assignment can be reconciled to the newly approved snapshot.

Older LOR snapshots and preserved source artifacts remain available as engineering evidence without duplicating historical Stage/Scene/Display/UID/IP/universe assignments into Controller Inventory.

## 9. Duplicate Addresses Are Valid

LOR Unit IDs are not unique physical-controller identifiers.

Current Church and Candyland RGB Candy Cane patterns intentionally reuse the same Unit-ID range on multiple physical Pixie controllers.

The 2026 workbook currently contains:

```text
Church      Aux-N  21-24  Pixie4  [two physical rows]
Candyland   Aux-A  21-24  Pixie4  [three physical rows]
```

Until permanent `CL-###` identities are assigned, duplicate-address controllers require one additional physical distinction, for example:

```text
Candy Canes 1-4
Candy Canes 5-8
Candy Canes 9-12
```

Do not define `network + Unit ID/range` as a unique key and do not automatically remove identical-looking source rows.

The same principle applies to A/C addresses that intentionally repeat commands: review repeated same-network/same-UID rows as intentional repeat versus actual conflict rather than prohibiting them automatically.

## 10. Physical Controller Families / Current Examples

The current 2026 source includes hardware examples such as:

```text
Traditional A/C controller families
Pixie2 / Pixie2D variants
Pixie4
Pixie8
Pixie16 source entry
PixCon16
AlphaPix Flex 48
CF50D
CMB24D
```

FieldWiring currently has reviewed temporary physical interpretations for several Pixie and E1.31 cases. Those interpretations are useful consumer evidence but do not create permanent controller identity.

The current release-candidate FieldWiring E1.31 temporary resolver explicitly includes:

```text
Mega Tree               AlphaPix / Flex48   Universes 1-48
Mega Ball               PixCon16            Universes 49-64
Mega Star Controller 1  PixCon16            Universes 113-128
Mega Star Controller 2  PixCon16            Universes 129-140
```

The 2026 workbook now contains physical inventory rows corresponding to all four contexts.

## 11. Current 2026 Reconciliation Items

The current source audit identifies several items that must remain unresolved until verified.

### Church

The workbook includes the Church Cross Pixie2 controllers and two repeated Pixie4 Candy Cane rows, but it does not yet identify the permanent physical Church Tree Pixie16 or the separate Tree Star controller context used by FieldWiring.

### Candyland Lollipops

The 2026 workbook records the Lollipop Pixie16 row on `Aux-B`, while current FieldWiring accepted LOR evidence expects the reviewed Lollipop pattern on `Aux C`.

Do not change either source by assumption. Reconcile against the approved LOR/V7 snapshot and physical controller.

### Who Forest

The 2026 workbook now records all eight Pixie8 ranges on `Aux-I`, including Tree 4. This is consistent with current FieldWiring topology and replaces the old 2025 working `Aux-F` value for current-review purposes.

### Santa's Workshop

The two current Pixie8 Tree controllers are now present at `Aux-D / 10-17` and `Aux-D / 18-1F`.

### Mega Cube

Do not continue treating the older three-PixCon interpretation as accepted current truth.

The 2026 workbook now records one `AlphaPix Flex 48` row at IP `10.10.5.12`, while that row also records `Controller Type = 16`.

This conflicts with older evidence and is internally inconsistent. Actual installed hardware/output capability must be physically confirmed.

FieldWiring currently leaves Mega Cube compact CustomGrid expansion unresolved rather than inventing missing physical rows.

## 12. Firmware History

Firmware is the controller-specific history Controller Inventory should preserve.

A firmware update/verification record should eventually identify:

- permanent controller identity;
- firmware version;
- install or verification date;
- person who installed or verified it;
- optional notes; and
- optional Work Order reference where the firmware change was part of repair/troubleshooting.

The Lookup Table's `Latest Firmware` value is model-reference information and must not overwrite or substitute for the version actually installed on a physical controller.

The 2026 workbook currently has firmware populated on 160 of 161 controller rows, making it a substantially better firmware-review source than the 2025 workbook.

## 13. Work Order Boundary

Repairs, troubleshooting, parts replacement, maintenance actions, testing associated with a repair, and repair resolution belong in the existing Work Order subsystem.

Controller Inventory should link the permanent controller asset to applicable Work Orders rather than maintaining a second repair-history system.

## 14. Labeling Requirements

Controller labels should support durable physical identification and technical lookup.

The field-facing label should identify the physical controller without requiring a volunteer to interpret its current hexadecimal Unit ID, universe, or IP address.

The final barcode/QR layout and scan route must follow the current LabelPrintService and application architecture.

## 15. FieldWiring Integration Direction

FieldWiring is a consumer of Controller Inventory and does not own the Controller Inventory schema.

The current release candidate deliberately isolates temporary physical interpretation in:

```text
FieldWiring/Application/wiring_presentation.py
FieldWiring/Application/wiring_e131.py
```

These temporary rules may remain while Controller Inventory data is being reviewed, but they must be replaceable by a PostgreSQL Controller Inventory read interface.

The future interface must provide enough information to determine:

- permanent physical controller identity;
- exact model/family and physical output capability;
- current address/controller context;
- a distinguishing group when identical addresses are intentionally reused;
- any reviewed physical output mapping basis that cannot be safely derived from LOR; and
- which approved LOR/V7 snapshot the current assignment was reconciled against.

Detailed current Display/output/universe/channel wiring remains LOR/V7 data.

See [Controller Inventory Current-State / FieldWiring Integration Plan](Controller_Inventory_Current_State_FieldWiring_Integration_Plan_2026-08-20.md).

## 16. Current Open Work

Before PostgreSQL implementation:

1. use the 2026 workbook as the current working inventory source;
2. preserve the 2025 CSVs and DMX workbook as supporting evidence;
3. establish one permanent physical controller identity per real controller;
4. distinguish repeated physical rows before any deduplication;
5. normalize confirmed model/reference terminology;
6. resolve the Church Tree/Star inventory gaps;
7. resolve Candyland Lollipop network evidence;
8. physically verify Mega Cube hardware/output capability;
9. normalize current network terminology such as `E1.31` / `E-1.31`;
10. review repeated A/C and pixel addresses as intentional repeat versus conflict;
11. define current-snapshot provenance/currentness requirements;
12. define and review the minimum FieldWiring read interface;
13. define firmware history requirements; and
14. reconcile controller labeling with the current LabelPrintService.

No PostgreSQL Controller Inventory schema change is authorized until these source/model/interface questions have been reviewed and accepted.

## Related Systems

- [Controller Inventory 2026 Source Audit — 2026-08-22](Controller_Inventory_2026_Source_Audit_2026-08-22.md)
- [Controller Inventory Current-State / FieldWiring Integration Plan](Controller_Inventory_Current_State_FieldWiring_Integration_Plan_2026-08-20.md)
- [Controller Inventory 2025 Source Audit — historical evidence](Controller_Inventory_2025_Source_Audit_2026-08-19.md)
- [FieldWiring Release Candidate Handoff and Development Runbook](../09_Wiring_System/FieldWiring_Release_Candidate_Handoff_and_Development_Runbook_2026-08-21.md)
- [Labeling and Scanning](../07_Labeling_and_Scanning/README.md)
- [Wiring System](../09_Wiring_System/README.md)
- [Network Infrastructure](../10_Network_Infrastructure/README.md)
- [Work Orders](../06_Work_Orders/README.md)
