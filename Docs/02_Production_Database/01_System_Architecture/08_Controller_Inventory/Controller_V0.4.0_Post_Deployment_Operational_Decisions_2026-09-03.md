# Controller V0.4.0 Post-Deployment Operational Decisions — 2026-09-03

| Item | Value |
|---|---|
| Status | ACCEPTED OPERATIONAL DECISIONS |
| Issue | #110 |
| Production application | FieldWiring / Controller Inventory V0.4.0 |
| Production checkout | `63be47f40be78f608416935ed0583287da9d90e6` |

## Purpose

Record the accepted Controller Inventory decisions made immediately after successful V0.4.0 production deployment so follow-up work does not drift back into speculative design.

## 1. Controller physical printing belongs to LabelPrintService

The Controller browser owns the governed request action and Production Database request state. It does not own PRINT-SERVER polling, Brother printer behavior, template/media/profile selection, physical printing, or successful physical-print finalization.

Accepted ownership boundary:

```text
Controller Inventory / Production Database
    -> operator requests Controller label
    -> governed ref.controller print request state

Gregovate/MSB_LabelPrintService
    -> poll pending Controller requests
    -> resolve Controller label profile/template/media/printer
    -> preflight
    -> print
    -> finalize successful request / print history
```

The existing print-service tracking home is:

```text
Gregovate/MSB_LabelPrintService
Issue #14 — V4 label-service work
```

Do not implement Controller polling in the Controller browser repository and do not create a second competing print queue.

## 2. Plain-English Controller operator procedures are required now

V0.4.0 planning and maintenance screens are accepted and deployed, so operator procedures should now describe the real production screens rather than waiting for another UI redesign.

Current operator-procedure authority:

```text
Docs/02_Production_Database/02_Operational_SOPs/Controllers/README.md
Docs/02_Production_Database/02_Operational_SOPs/Controllers/Controller_Inventory_Operator_Procedure.md
```

The first revision is intentionally usable without screenshots. Screenshot placeholders are included and current production screenshots may be added later.

## 3. Controller reporting is intentionally deferred

Do not implement the previously proposed offline/printable Controller reports yet.

Reason:

> The crew should use V0.4.0 in normal production work first so reporting requirements come from actual field/maintenance needs rather than engineering guesses.

The earlier report concepts remain design history only; they are not an active implementation requirement at this checkpoint.

Resume reporting work only after real users identify specific useful outputs such as a grouping, worksheet, exception list, or offline field reference. Capture those requirements from use before choosing report format or columns.

## Current Follow-Up Boundary

Active follow-up work after this checkpoint is:

1. use V0.4.0 in production and collect operator feedback;
2. add screenshots to the Controller operator procedure when convenient;
3. complete Controller polling/physical-print integration in `MSB_LabelPrintService`;
4. complete remaining role-specific acceptance for Production Crew and MSB Browser / Read Only as needed;
5. define Controller reporting only after real crew use establishes the need;
6. reconcile PR #111 for eventual main-merge review separately.

These decisions do not authorize merging PR #111 or modifying `main`.
