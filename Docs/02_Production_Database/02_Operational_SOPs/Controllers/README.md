# Controller Inventory Operational SOPs

These procedures are for people using the production **Controller Inventory** browser. They describe the deployed V0.4.0 screens in normal operator language and intentionally avoid database-engineering detail.

## What Do You Need To Do?

| I want to... | Go to |
|---|---|
| Find a Controller by ID, Display, Stage, model, serial number, or location | [Controller Inventory Operator Procedure](Controller_Inventory_Operator_Procedure.md#find-a-controller) |
| Review Controller details, assignments, firmware, or current programming | [Controller Inventory Operator Procedure](Controller_Inventory_Operator_Procedure.md#review-a-controller) |
| Check Stage/Network capacity before planning a Controller | [Controller Inventory Operator Procedure](Controller_Inventory_Operator_Procedure.md#plan-controller-capacity) |
| Add a newly discovered Controller to inventory | [Controller Inventory Operator Procedure](Controller_Inventory_Operator_Procedure.md#add-a-controller) |
| Edit a Controller's physical or programmed information | [Controller Inventory Operator Procedure](Controller_Inventory_Operator_Procedure.md#edit-a-controller) |
| Assign, replace, edit, or remove a Display assignment | [Controller Inventory Operator Procedure](Controller_Inventory_Operator_Procedure.md#manage-display-assignments) |
| Record physical, firmware, or programmed-configuration verification | [Controller Inventory Operator Procedure](Controller_Inventory_Operator_Procedure.md#record-verification) |
| Understand the current Controller Print Label limitation | [Controller Inventory Operator Procedure](Controller_Inventory_Operator_Procedure.md#controller-labels) |

## Current Production Version

```text
Controller Inventory / FieldWiring V0.4.0
Production checkout 63be47f40be78f608416935ed0583287da9d90e6
```

The operator screens were accepted in the disposable production-clone browser review and then deployed to production on 2026-09-03.

Screenshots are intentionally **not required for the first procedure revision**. Screenshot placeholders are included in the main procedure so current production screenshots can be added later without rewriting the instructions.

## Access

All authorized production users may browse Controller Inventory. Additional controls depend on the signed-in role:

- **Production Crew** — browse and Controller label request capability when that workflow is enabled;
- **Manager** — browse, Plan Capacity, Add/Edit Controller, and Manage Assignments;
- **Administrator** — same Controller management capabilities as Manager;
- **MSB Browser / Read Only** — browse only.

If a management button is not visible, do not work around it. The current signed-in role may not have permission for that action.

## Scope Boundary

Controller Inventory records the permanent physical Controller and its current physical/programmed facts. **LOR/V7 remains the authority for what the show requires.**

The browser's Controller **Print Label** action records the request in the Production Database. Polling, printer/template/media selection, physical printing, and successful finalization belong to `Gregovate/MSB_LabelPrintService`, not this application.

Printable/offline Controller reporting is deliberately deferred until the crew has used V0.4.0 long enough to identify what reports are actually useful. Do not design a report merely because one was previously proposed.

For engineering ownership and database behavior, use the [Controller Inventory architecture](../../01_System_Architecture/08_Controller_Inventory/README.md).
