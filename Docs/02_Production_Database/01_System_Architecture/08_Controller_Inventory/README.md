# Controller Inventory

| Document control | Value |
|---|---|
| Status | PRODUCTION V0.4.0 DEPLOYED — CORE PLANNING / MAINTENANCE ACCEPTED |
| Issue | #110 |
| Draft PR | #111 |
| Permanent identity | `ref.controller.controller_id` |
| Permanent database | Installed on `msb-prod-db` |
| Current production checkout | `63be47f40be78f608416935ed0583287da9d90e6` |
| Immediate application rollback | `e9ab029a17067b38b34f9306069f54899925f73f` |
| FieldWiring production | `V0.4.0 / postgres / healthy` |
| Procedures production | `V0.1.0 / postgres / healthy` |
| Production deployment acceptance | [Controller V0.4.0 Production Deployment Acceptance — 2026-09-03](Controller_V0.4.0_Production_Deployment_Acceptance_2026-09-03.md) |
| Authentication / authorization | [Controller Management Authentication / Authorization Contract — 2026-08-31](Controller_Management_Authentication_Authorization_Contract_2026-08-31.md) |
| Management boundary | [Controller Management Application Boundary — 2026-08-31](Controller_Management_Application_Boundary_2026-08-31.md) |
| Programmed configuration | [Controller Current Programmed Configuration Contract — 2026-08-31](Controller_Current_Programmed_Configuration_Contract_2026-08-31.md) |
| Operational roadmap | [Controller Inventory Operational Implementation Roadmap — 2026-08-31](Controller_Inventory_Operational_Implementation_Roadmap_2026-08-31.md) |

Controller Inventory owns permanent physical Controller identity, current Controller-to-Display relationships, physical Controller facts, and the physical Controller's recorded current programmed configuration. LOR/V7 remains authoritative for current show wiring topology and what the show currently requires.

## Current Production State

Permanent production objects:

```text
ref.controller_model
ref.controller_firmware_version
ref.controller_status
ref.controller
ref.controller_display
ref.controller_firmware_history
```

Accepted permanent inventory remains 177 physical Controllers with IDs `1001` through `1177`. `ref.controller_display` keeps the legitimate composite key `(controller_id, display_id)`. Controller `1176` remains intentionally unassigned until its new Display exists through the normal LOR/Preview workflow.

Current V0.4.0 deployment checkpoint:

```text
checkout                    63be47f40be78f608416935ed0583287da9d90e6
rollback checkout           e9ab029a17067b38b34f9306069f54899925f73f
FieldWiring                  V0.4.0 / postgres / healthy
Procedures                   V0.1.0 / postgres / healthy
Controller fingerprint       578217bcb18e1291ceced673a3de3b27 unchanged
```

Validated rollback database archive:

```text
/home/msbadmin/backups/postgres/msb-pre-controller-setup-management-20260903T044324.dump
SHA256 702bcb71c776a1495fecef3e73ec39a35d75049e21b0c02f54a7ed2b65311a23
```

Production deployment report:

```text
/tmp/MSB_Controller_Setup_Management_Production_Deploy_20260903T044324.txt
```

## V0.4.0 Production Capability

The purpose-built Controller browser now provides the accepted operational core:

- Stage/Sub-stage-aware Controller browse/search;
- current Display assignments and Stage context;
- Controller/FieldWiring cross-links;
- current programmed LOR Network / First UID / UID Count / calculated UID range / management IP;
- Controller planning/capacity views using current LOR/V7 evidence;
- Add Controller;
- Edit Controller;
- assignment / reassignment / unassignment management;
- model/status/location/serial/hardware/year/verification/notes maintenance;
- firmware maintenance and verification state;
- `Physically Attached to Display` as a physical fact separate from logical assignments;
- contextual `?` help for non-obvious fields;
- unsaved-change protection;
- Controller label state and Print Label request action;
- distinct Print Label styling from Save Controller;
- human-facing operator attribution for label requests.

The grouped maintenance form and current planner presentation are operator-accepted for V0.4.0.

## Browser Write Boundary

Production command migrations now include:

```text
021_create_controller_browser_authorization_contract.sql
022_create_controller_label_request_command.sql
023_create_controller_management_commands.sql
024_harden_controller_assignment_capability.sql
```

The deployed security model is:

```text
Cloudflare Access authenticated email
    -> Directus user / role / policy authorization data
    -> server-side capability check
    -> narrow SECURITY DEFINER PostgreSQL command
    -> PostgreSQL validation / audit / final authority
```

`fieldwiring_app` remains a least-privilege application role. It does not receive broad direct `INSERT`, `UPDATE`, or `DELETE` on `ref.controller*` merely because browser management exists.

No Directus login redirect or cross-origin Directus browser-session bridge is required.

## Capability Matrix

```text
Production Crew           -> browse + Print Label
Manager                   -> browse + Print Label + Controller management
Administrator             -> browse + Print Label + Controller management
MSB Browser / Read Only   -> browse only
```

Controller management means Add/Edit Controller and Controller-to-Display assignment/reassignment/unassignment. There is no normal Controller DELETE workflow.

Button visibility is presentation only; every write rechecks authenticated identity and current authorization server-side.

## Permanent Identity and Relationship Rules

Permanent physical identity is only:

```text
ref.controller.controller_id
```

Accepted scan payload:

```text
CTRL:<controller_id>
```

Network, Unit ID/range, IP address, universe, Display, Stage, Scene, spreadsheet row, and LOR Prop UUID are mutable facts/evidence, not permanent Controller identity.

Controller-to-Display cardinality is many-to-many:

```text
one Controller -> zero, one, or many Displays
one Display    -> zero, one, or many Controllers
```

Intentional repeated addresses are valid. Never make Network + UID globally unique physical identity.

`ref.controller_display.wiring_source_display_id` remains the reviewed bridge for duplicated-channel physical copies whose LOR wiring is intentionally defined by another Display.

## Current Programmed Configuration

`ref.controller` records the physical Controller's **current programmed configuration**, including current `lor_network`, `lor_uid_start`, `lor_uid_count`, generated `lor_uid_end`, and management IP where applicable.

These are mutable operational facts, not identity. LOR/V7 remains authoritative for the show-required configuration. Setup/reconciliation compares physical recorded programming against current show requirements.

Fixed full-UID models remain governed by database rules, including:

```text
CCB100   = 2 UIDs
Pixie4D  = 4 UIDs
Pixie8D  = 8 UIDs
Pixie16D = 16 UIDs
```

## Stage and FieldWiring Integration

Do not add redundant `stage_id` to `ref.controller` merely for browsing. Stage context is derived through current Display relationships:

```text
ref.controller
    -> ref.controller_display
        -> ref.display
            -> ref.stage
```

Unassigned shelf Controllers may legitimately have zero assignments and no Stage.

Accepted FieldWiring resolver basis:

```text
physical Controller = ref.controller.controller_id
physical Display    = ref.controller_display.display_id
wiring Display      = COALESCE(
    ref.controller_display.wiring_source_display_id,
    ref.controller_display.display_id
)
```

Detailed Network/UID/channel/universe requirements remain LOR/V7 authority.

## Labels and Scan

Controller labels use permanent identity:

```text
CTRL:<controller_id>
```

The browser Print Label command sets the governed `ref.controller.print_label` request flag. The physical polling/print service remains a separate subsystem.

Current limitation: the external LabelPrintService does not yet have accepted Controller template/profile/routing support. Physical Controller label printing is therefore not considered complete simply because the browser request flag exists.

The accidental pending CTRL 1001 request must be cleared under a bounded production mutation procedure before Controller physical print routing becomes active.

## Directus Experiment — Closed

Do not resume the Directus Controller relationship workspace experiment. It caused item-detail failures around the legitimate composite relationship key.

Directus remains useful as authorization data and optional simple reference maintenance. It is not the Controller operational editor.

## Remaining Work After V0.4.0

The core Controller planning/maintenance system is deployed. Remaining work is narrower:

1. build offline/printable Controller reports:
   - firmware / verification worksheet;
   - Stage / Display Controller list;
   - verification / exception report;
2. complete external Controller label-service profile/template/routing work separately;
3. clear the accidental CTRL 1001 pending label request before physical Controller printing is enabled;
4. complete Production Crew and Read Only browser capability acceptance;
5. write and accept plain-English operator procedures against the deployed V0.4.0 screens;
6. reconcile final documentation and prepare draft PR #111 for review/merge.

PR #111 remains draft. Production deployment does **not** authorize merging `main`.

## Operator Procedures

Final plain-English procedures are still required. They must match the deployed screens and cover browsing, Stage lookup, shelf stock, Add/Edit, assignment/reassignment/unassignment, firmware/status/location/programmed configuration, labels, planning, and FieldWiring navigation.

Engineering terms such as junction-table rows, foreign keys, resolver providers, or LOR UUIDs belong in engineering documentation, not ordinary operator instructions.

## Read This First

For current work, read in this order:

1. [Controller V0.4.0 Production Deployment Acceptance — 2026-09-03](Controller_V0.4.0_Production_Deployment_Acceptance_2026-09-03.md)
2. [Controller V0.4.0 Disposable Browser Operator Acceptance — 2026-09-03](Controller_V0.4.0_Disposable_Browser_Operator_Acceptance_2026-09-03.md)
3. [Controller Management Authentication / Authorization Contract — 2026-08-31](Controller_Management_Authentication_Authorization_Contract_2026-08-31.md)
4. [Controller Management Application Boundary — 2026-08-31](Controller_Management_Application_Boundary_2026-08-31.md)
5. [Controller Current Programmed Configuration Contract — 2026-08-31](Controller_Current_Programmed_Configuration_Contract_2026-08-31.md)
6. [Controller Inventory Operational Implementation Roadmap — 2026-08-31](Controller_Inventory_Operational_Implementation_Roadmap_2026-08-31.md)
7. [Controller Inventory / FieldWiring Repeated-Address and Duplicated-Channel Cases — 2026-08-30](Controller_FieldWiring_Repeated_Address_and_Duplicated_Channel_Cases_2026-08-30.md)
8. Server Management `docs/server/Production_Database_Change_Deployment_Runbook.md` before any future production mutation.

Older bootstrap and Pre-DDL material remains historical evidence. Current production and active management/authentication documents control when older material conflicts.
