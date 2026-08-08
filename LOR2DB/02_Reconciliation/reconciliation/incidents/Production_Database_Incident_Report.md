# Production Database Incident Report
## Unauthorized `ref.display` Modifications During V7 Reconciliation Development

**Project:** MSB Production Database  
**Subsystem:** LOR Snapshot Reconciliation (P2)  
**Date of Incident:** 2026-07-31  
**Date of Investigation:** 2026-08-01  
**Status:** Open Investigation  
**Severity:** High (Production Data Integrity)

---

# Executive Summary

During assisted V7 reconciliation development, SQL created and supplied through the project workflow was executed as directed and modified ref.display before the documented operator decision gate. The operator did not independently invoke P2 or approve the resulting insert, update, or lifecycle actions.

The production database currently contains modifications that were **not reviewed through the documented operator decision gate** and **were not accompanied by a reconciliation report**.

Although the modifications are recoverable through manual review, the event demonstrates that the current implementation does **not** fully enforce the documented production workflow.

This incident prompted suspension of further P2 development until the production reconciliation architecture can be completed correctly.

---

# Background

The original reconciliation process was developed before the production PostgreSQL database existed.

At that time the objective was primarily to synchronize LOR data with spreadsheet-based inventory.

Since then the MSB Production Database has evolved into a complete production management system.

`ref.display` is now the permanent identity table for the physical display inventory and is referenced by numerous production systems including:

- Containers
- Testing
- Work Orders
- Label Printing
- GPS
- Wiring Documentation
- Maintenance
- Future Directus applications

Because of this evolution, reconciliation can no longer be treated as a simple import.

The permanent production identity (`display_id`) must always be preserved.

---

# Documented Design Intent

The reconciliation design intentionally separates the process into two phases.

## Phase 1

Read-only reconciliation.

No production data changes.

Generate candidate classifications.

Require operator decisions.

---

## Phase 2

Apply only approved decisions.

Generate reconciliation report.

Update production.

---

The documented workflow specifically requires:

> Production changes are not performed until operator review has completed.

Typical documented operator decisions include:

| Condition | Operator Decision |
|-----------|-------------------|
| Rename | Approve rename |
| UUID change | Approve UUID reassociation |
| New display | Approve creation |
| Missing production display | Retire / Recycle / Restore / Defer |
| Nonphysical helper | Exclude |
| Incorrect LOR data | Correct LOR then re-import |
| Insufficient information | Defer |

---

# Expected Architecture

The intended workflow is:

```text
LOR Parser
      ↓
Snapshot Ingest
      ↓
01 Context
02 Stage Validation
03 Summary
04 Action Report
05 Integrity
06 Scene Validation
07 Scene Display Validation
08 Production Identity Gate
      ↓
Operator Decisions
      ↓
P2 Promotion
      ↓
Validation
      ↓
HTML Reconciliation Report
```

The production gate was designed to become the mandatory authorization point before any writes occur.

---

# Incident Description

During testing on **2026-07-31**, production records within `ref.display` were modified before the documented gate process was completed.

The changes occurred at:

```text
2026-07-31 17:08:34.408 -0500
```

The changes included both inserts and updates.

No reconciliation report exists documenting the changes.

No operator approval record exists documenting the decisions.

---

# Confirmed Production Inserts

The following production rows were inserted.

| Display ID | Display Name |
|------------|--------------|
|1113|QV-StationSign-02|
|1114|WW-ClarkGriswold|
|1115|WW-FreeFrosty-Spotlight|
|1116|WW-UncleLouis-Flying|
|1117|WW-UncleLouis-Standing|

Characteristics:

- Created simultaneously
- Created by `msbadmin`
- No production metadata
- No containers
- No testing
- No labels
- No downstream production references

These displays should have appeared as **new display candidates** requiring operator approval.

Instead they already existed in `ref.display`.

---

# Confirmed Production Updates

Investigation identified nineteen existing production rows whose audit timestamp was updated during the same execution window.

These rows include, but are not limited to:

- HW-WaitTime15Min
- WW-CousinEddie
- WW-FlickPole
- SW-StarRGB-RH
- WA-MegaCube-Scaffold
- PB-Igloo-CR50-01
- PB-Igloo-CR50-02
- PB-Igloo-CR50-03
- PB-Igloo-CR50-04
- PB-PVCIgloo-01
- PB-PVCIgloo-02
- PB-PVCIgloo-03
- PB-PVCIgloo-04
- FE-ArrowRight-2CH-01
- FE-TuneRadio-2CH-01
- FE-TuneRadio-2CH-02
- FE-TuneRadio-2CH-03
- SW-GiftBag
- WW-Condor

The complete before/after field-level changes remain under investigation.

---

# Confirmed Lifecycle Changes

The following production displays currently have lifecycle status:

```text
RECYCLED
```

- PB-PVCIgloo-01
- PB-PVCIgloo-02
- PB-PVCIgloo-03
- PB-PVCIgloo-04

These lifecycle changes were not preceded by documented reconciliation decisions.

Whether these lifecycle changes were ultimately correct is separate from the procedural issue.

The issue is that the documented approval process was bypassed.

---

# Impact

Once the five new displays existed in `ref.display`, subsequent reconciliation validation reported them as existing production displays.

As a result:

- New-display detection no longer functioned correctly.
- Identity gate validation produced misleading results.
- Production baseline integrity could no longer be assumed.
- Manual investigation became necessary.

---

# Root Cause

Responsible file:
03_apply_run36_approved_resolutions.sql

Execution:
2026-07-31 17:08:34.408 -0500

Affected production rows:
24

Unauthorized lifecycle changes:
4

Unauthorized new display inserts:
5

---

# Lessons Learned

This incident reinforces the need for the reconciliation documentation to remain the governing specification.

The implementation must never be allowed to bypass documented workflow simply because SQL is capable of doing so.

Documentation is not supplementary.

Documentation defines the permitted behavior.

---

# Architectural Corrections

The following rules are now considered mandatory.

## Rule 1

P2 shall never determine production identity.

Identity decisions are made only during reconciliation.

---

## Rule 2

P2 shall never discover new displays.

It consumes only approved reconciliation decisions.

---

## Rule 3

P2 shall never update production records that are absent from the approved decision set.

---

## Rule 4

Only LOR-owned shared fields may be updated.

Examples include:

- `lor_prop_id`
- `display_name`
- `stage_id`
- `string_type`
- `color`

Production-owned metadata shall remain unchanged.

---

## Rule 5

Permanent production identity shall always be preserved.

`display_id` shall never change.

All downstream relationships remain attached to the existing production row.

---

## Rule 6

Lifecycle changes require explicit operator approval.

Displays shall never be automatically:

- Activated
- Retired
- Recycled
- Restored

---

## Rule 7

New displays require explicit approval.

Creation of new production rows shall occur only after operator approval.

---

## Rule 8

The identity gate is mandatory.

No production writes occur before completion of the gate.

---

## Rule 9

Every reconciliation shall generate a permanent report.

The report becomes the audit record for:

- Approved changes
- Deferred changes
- Blocked changes
- Production updates
- Final validation

---

# Current Resolution

The current production database will be treated as the operational baseline going forward.

Further effort will focus on preventing future unauthorized writes rather than attempting to reconstruct historical state.

Legacy P2 logic will not be considered production-ready.

The reconciliation workflow will instead be rebuilt around the documented production identity gate and operator approval process.

---

# Conclusion

The investigation demonstrated that the existing implementation does not yet enforce the documented reconciliation architecture.

Although the production database remains recoverable, the incident confirms the necessity of completing the production identity gate before any future production promotion procedures are enabled.

This event ultimately validates the design direction of the V7 reconciliation project.

The production documentation will continue to serve as the governing specification from which all future SQL procedures and validation scripts are derived.

# Lasting Design Changes Resulting from This Incident

• Production reconciliation is a gated workflow, not an automated import.

• All reconciliation scripts (01–09) are read-only.

• No SQL prior to the promotion phase may modify ref.display.

• P2 is no longer an "upsert" procedure. It is a promotion procedure that
  executes only operator-approved reconciliation decisions.

• New displays are never created automatically.

• Display lifecycle changes (ACTIVE, RECYCLED, RETIRED, etc.) always require
  explicit operator approval.

• The reconciliation report becomes the permanent audit record for every
  production promotion.

• LOR remains the source of truth for LOR-owned fields only.

• ref.display remains the source of truth for production identity and
  production metadata.