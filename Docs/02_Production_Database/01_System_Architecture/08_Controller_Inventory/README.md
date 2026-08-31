# Controller Inventory

| Document control | Value |
|---|---|
| Status | PRODUCTION CORE INSTALLED — READ EXPERIENCE ACCEPTED — MANAGER WORKFLOW NEXT |
| Issue | #110 |
| Permanent identity | `ref.controller.controller_id` |
| Permanent database | Installed on `msb-prod-db` |
| Management boundary | [Controller Management Application Boundary — 2026-08-31](Controller_Management_Application_Boundary_2026-08-31.md) |
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

Current accepted production application checkpoint:

```text
checkout                    84d6f06e16c43ebb0f6aa21273b999af7f6d455b
FieldWiring                  V0.3.1 / postgres / healthy
Procedures                   V0.1.0 / postgres / healthy
combined live regression     183 passed in 2.39s
```

The working Controller/FieldWiring read experience now includes:

- Stage/Sub-stage-aware Controller browsing and richer text search;
- visible free-text Stage-match confirmation;
- current programmed LOR Network / First UID / UID Count / calculated range / management IP presentation;
- permanent Controller ID and model context in FieldWiring;
- FieldWiring -> Controller Inventory cross-links;
- Controller Inventory -> Field Wiring links from current Display assignments;
- firmware history and label-state presentation.

## Read This First

For current implementation work, read in this order:

1. [Controller Management Application Boundary — 2026-08-31](Controller_Management_Application_Boundary_2026-08-31.md)
2. [Controller Inventory Operational Implementation Roadmap — 2026-08-31](Controller_Inventory_Operational_Implementation_Roadmap_2026-08-31.md)
3. [Controller Inventory / FieldWiring Repeated-Address and Duplicated-Channel Cases — 2026-08-30](Controller_FieldWiring_Repeated_Address_and_Duplicated_Channel_Cases_2026-08-30.md)
4. [FieldWiring / Controller Inventory Handoff — 2026-08-20](../09_Wiring_System/FieldWiring_Controller_Inventory_Handoff_2026-08-20.md)
5. [Application, Backfill, and Operations Framework — 2026-08-30](Controller_Inventory_Application_Backfill_and_Operations_Framework_2026-08-30.md)

Older Pre-DDL/bootstrap documents remain historical design and evidence. When they conflict with current production state or the active management boundary, current production/management documents control.

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

The legitimate permanent relationship key remains:

```text
PRIMARY KEY (controller_id, display_id)
```

Do not replace it with a surrogate key merely to satisfy an administrative UI.

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

FieldWiring / Controller browser
    -> technician-facing read experience
    -> permanent Controller cross-links
    -> future Manager operational maintenance UX

Directus
    -> login / identity / Manager policy authority
    -> optional simple one-table/reference maintenance only

PostgreSQL
    -> constraints / audit / data integrity / final authority
```

Controller Inventory does not rewrite LOR wiring.

## Controller Management Direction

The **Wiring System / Controller Inventory browser** is the accepted operational Controller experience.

Directus is **not** the Controller operational editor. Live testing proved that the multi-table Controller workflow does not fit Directus reliably. The Directus relationship-workspace experiment was removed after it caused Controller item-detail failures; cleanup validation passed while preserving the composite Controller/Display key and all permanent data.

Directus remains valuable for authentication/authorization and for simple one-table/reference maintenance where appropriate.

Access model:

```text
All MSB production users: READ
Managers:                 CREATE + READ + UPDATE + relationship management
DELETE Controller:        no normal workflow
```

Manager controls must be implemented in the Controller browser and protected by server-side authenticated Manager checks. Do not make the existing read-only `fieldwiring_app` PostgreSQL role broadly writable merely to expose browser edit controls.

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

The accepted resolver basis is:

```text
physical controller = ref.controller.controller_id
physical Display     = ref.controller_display.display_id
wiring Display       = COALESCE(
    ref.controller_display.wiring_source_display_id,
    ref.controller_display.display_id
)
```

Permanent Controller context is now visible in FieldWiring and cross-links back to Controller Inventory. Detailed wiring/address facts remain LOR/V7 authority.

Temporary presentation rules may remain only where permanent Controller Inventory does not yet provide enough governed information for a specific presentation family. Do not remove a fallback until the real case is covered and regression accepted.

## Labels and Scan

Controller labels use permanent identity:

```text
CTRL:<controller_id>
```

No separate controller identity scheme is authorized. New shelf controllers must be able to receive permanent IDs and labels before they are assigned to Displays.

`ref.controller` already contains the established label fields, including `label_required`, `print_label`, cached print count/time, and label template reference.

The Controller Management UI must expose the existing `print_label` request state to Managers. Actual printer handoff remains a separate integration step and must use the established MSB labeling subsystem rather than creating a second printing mechanism.

## Operator Procedures

Plain-English operator procedures are required before the Controller Inventory system is considered operationally complete.

Final procedures must be written **after** the working Manager UI/workflow is accepted so they match real screens and behavior. They must cover normal browsing, Stage lookup, adding shelf stock, assignment/reassignment/unassignment, firmware/status/location maintenance, labels, and opening current Field Wiring.

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

The older [Directus-Style UX Contract](Controller_Management_Directus_Style_UX_Contract_2026-08-31.md) retains useful field/layout requirements but is superseded as an implementation mechanism by the active [Controller Management Application Boundary](Controller_Management_Application_Boundary_2026-08-31.md).

## Active Resume Point

Do **not** resume from the old Stage-browser backlog or the Directus relationship-editing experiment. Stage-aware browsing and the first permanent FieldWiring Controller integration are already accepted.

Immediate implementation sequence:

1. browser-native authenticated Manager boundary using the existing Directus login/session/Manager policy authority;
2. **Edit Controller** from the existing Controller detail pane;
3. **Add Controller** for new/unassigned shelf stock with PostgreSQL-generated permanent `controller_id`;
4. controlled model/status/location/firmware/verification/programmed-configuration fields;
5. governed current Network / First UID / UID Count / calculated range / management IP maintenance;
6. Manager-editable `print_label` request state;
7. Controller ↔ Display assignment/reassignment/unassignment workbench preserving M:N cardinality and reviewed `wiring_source_display_id` behavior;
8. real shelf-stock/reassignment acceptance;
9. actual label-service handoff when its separate contract is ready;
10. plain-English operator procedures after the accepted UI exists.

Every deployed application change must preserve the shared FieldWiring + Procedures regression gate and keep the cross-workstream documentation current during the work, not after the conversation ends.
