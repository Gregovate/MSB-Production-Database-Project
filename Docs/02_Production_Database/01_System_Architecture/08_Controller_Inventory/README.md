# Controller Inventory

| Document control | Value |
|---|---|
| Status | PRODUCTION CORE INSTALLED — OPERATIONAL INTEGRATION ACTIVE |
| Issue | #110 |
| Permanent identity | `ref.controller.controller_id` |
| Permanent database | Installed on `msb-prod-db` |
| Operational roadmap | [Controller Inventory Operational Implementation Roadmap — 2026-08-31](Controller_Inventory_Operational_Implementation_Roadmap_2026-08-31.md) |
| Repeated-address / duplicated-channel contract | [Accepted Cases — 2026-08-30](Controller_FieldWiring_Repeated_Address_and_Duplicated_Channel_Cases_2026-08-30.md) |

Controller Inventory owns permanent physical controller identity and current physical Controller-to-Display relationships. LOR/V7 remains authoritative for current show wiring topology, addressing, channels, universes, Preview/Scene context, and whether a Display has current approved wiring.

## Current Production State

The permanent Controller Inventory core is installed and populated in PostgreSQL:

```text
ref.controller_model
ref.controller_firmware_version
ref.controller_status
ref.controller
ref.controller_display
ref.controller_firmware_history
```

Initial accepted bootstrap state:

- 177 permanent physical controllers;
- controller IDs `1001` through `1177`;
- exact controller models normalized to accepted manufacturer terminology;
- firmware evidence preserved as `RECORDED_UNVERIFIED` or `UNKNOWN` pending powered setup verification;
- Controller-to-Display relationships corrected for accepted repeated-address and duplicated-channel cases;
- controller `1176` intentionally unassigned until the new 2026 Matrix Display exists through the normal Preview/LOR workflow.

The temporary `stage.controller_*` bootstrap objects were engineering scaffolding only and are not permanent authority.

## Read This First

For current implementation work, read:

1. [Controller Inventory Operational Implementation Roadmap — 2026-08-31](Controller_Inventory_Operational_Implementation_Roadmap_2026-08-31.md)
2. [Controller Inventory / FieldWiring Repeated-Address and Duplicated-Channel Cases — 2026-08-30](Controller_FieldWiring_Repeated_Address_and_Duplicated_Channel_Cases_2026-08-30.md)
3. [FieldWiring / Controller Inventory Handoff — 2026-08-20](../09_Wiring_System/FieldWiring_Controller_Inventory_Handoff_2026-08-20.md)
4. [Application, Backfill, and Operations Framework — 2026-08-30](Controller_Inventory_Application_Backfill_and_Operations_Framework_2026-08-30.md)

Older Pre-DDL documents remain historical design and evidence. When they conflict with the current installed production state or the operational roadmap, the current production/roadmap documents control.

## Permanent Identity and Relationships

Permanent physical identity is only:

```text
ref.controller.controller_id
```

Accepted scan payload:

```text
CTRL:<controller_id>
```

Network, Unit ID/range, IP address, universe, Display name, Stage, Scene, workbook row, and LOR Prop UUID are not permanent controller identity.

Controller-to-Display cardinality is many-to-many:

```text
one controller -> zero, one, or many Displays
one Display    -> zero, one, or many controllers
```

Intentional repeated addresses are valid. Network + Unit ID/range must never be globally unique physical identity.

`ref.controller_display.wiring_source_display_id` is the explicit bridge for reviewed duplicated-channel physical copies whose LOR wiring is intentionally defined by another Display.

## Authority Boundary

```text
Controller Inventory
    -> permanent controller identity
    -> model/status/firmware/location/notes
    -> current physical Controller-to-Display relationship

LOR / Parser V7 / LOR2DB
    -> current wiring topology
    -> Network / Unit ID / channels / universes
    -> Preview / Scene / Display wiring definitions

FieldWiring
    -> technician-facing combination of the two
```

Controller Inventory does not rewrite LOR wiring.

## Current User Experience Direction

The **Wiring System / Controller Inventory browser** is the preferred normal browsing experience.

Directus is the governed maintenance back-end.

Access model:

```text
All MSB production users: READ
Managers:                 CREATE + READ + UPDATE
DELETE:                   no normal workflow
```

The Controller browser is already deployed as a read-only first pass. Current active work is to make it operationally useful with Stage-aware browsing, permanent-controller FieldWiring integration, Controller-to-Display assignment management, shelf/AVAILABLE inventory, manager edit navigation, and label integration.

## Stage and Assignment Model

Do not add a redundant `stage_id` to `ref.controller` merely for browsing.

A controller's show Stage is derived through its current Display relationships:

```text
ref.controller
    -> ref.controller_display
        -> ref.display
            -> ref.stage
```

Unassigned shelf controllers may legitimately have zero Display assignments and no Stage. They remain permanent assets, normally with `AVAILABLE` status until assigned.

A permanent Controller ↔ Display Assignment workbench is required for ongoing operations. The initial bootstrap matching is not the long-term assignment workflow.

## FieldWiring Integration

FieldWiring must now migrate away from temporary inferred physical groups such as `Pixie group 1/2/3` where permanent Controller Inventory relationships resolve the physical device.

Accepted resolver basis:

```text
physical controller = ref.controller.controller_id
physical Display     = ref.controller_display.display_id
wiring Display       = COALESCE(
    ref.controller_display.wiring_source_display_id,
    ref.controller_display.display_id
)
```

Detailed wiring/address facts remain LOR/V7 authority.

## Labels and Scan

Controller labels use permanent identity:

```text
CTRL:<controller_id>
```

No separate controller identity scheme is authorized. New shelf controllers must be able to receive permanent IDs and labels before they are assigned to Displays.

Label printing/request integration remains active implementation work and must use the established MSB labeling subsystem.

## Operator Procedures

Plain-English operator procedures are required before the Controller Inventory system is considered operationally complete.

Final procedures must be written **after** the working UI/workflow is accepted so they match real screens and behavior. They must cover normal browsing, Stage lookup, adding shelf stock, assignment/reassignment/unassignment, firmware/status/location maintenance, labels, and opening current Field Wiring.

## Historical / Supporting Engineering Evidence

Useful historical and design evidence includes:

- [Engineering Acceptance Baseline — 2026-08-29](Controller_Inventory_Engineering_Acceptance_Baseline_2026-08-29.md)
- [Grouping Acceptance Register](Controller_Inventory_Grouping_Acceptance_Register.md)
- [Pre-DDL Design Details — 2026-08-29](Controller_Inventory_PreDDL_Design_Details_2026-08-29.md)
- [Application, Backfill, and Operations Framework — 2026-08-30](Controller_Inventory_Application_Backfill_and_Operations_Framework_2026-08-30.md)
- [Controller Inventory Current-State / FieldWiring Integration Plan — 2026-08-20](Controller_Inventory_Current_State_FieldWiring_Integration_Plan_2026-08-20.md)
- [Controller Inventory Current Assignment Cardinality — 2026-08-20](Controller_Inventory_Current_Assignment_Cardinality_2026-08-20.md)
- [HWY-42 Address Ambiguity — 2026-08-20](Controller_Inventory_LOR_Address_Ambiguity_HWY42_2026-08-20.md)
- [E1.31 IP Current-State Correction — 2026-08-20](Controller_Inventory_E131_IP_Current_State_Correction_2026-08-20.md)
- [FieldWiring / Controller Inventory Handoff](../09_Wiring_System/FieldWiring_Controller_Inventory_Handoff_2026-08-20.md)
- [Labeling and Scanning](../07_Labeling_and_Scanning/README.md)
- [Wiring System](../09_Wiring_System/README.md)
- [Work Orders](../06_Work_Orders/README.md)

## Active Resume Point

Continue from the operational roadmap, not from the old Pre-DDL gate.

Immediate implementation sequence:

1. Stage-aware Controller browsing and richer search;
2. FieldWiring permanent controller-ID resolver integration;
3. Controller ↔ Display assignment workbench;
4. Manager edit path and lookup-based maintenance UX;
5. label/scan integration;
6. real shelf-stock/reassignment acceptance;
7. plain-English operator procedures.

Every deployed application change must preserve the shared FieldWiring + Procedures regression gate and keep the cross-workstream documentation current.
