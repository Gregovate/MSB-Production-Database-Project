# LOR Production Import and Reconciliation Procedure

| Document control | Value |
|---|---|
| Repository path | `Postgres_sql/Upsert Procedures/00_LOR_Production_Import_and_Reconciliation_Procedure.md` |
| Document type | Controlled production procedure |
| Status | DRAFT — production execution remains blocked pending reconciliation implementation and validation |
| Owner / author | GAL |
| Initial release | 2026-07-31 |
| Current revision | 2026-07-31 |

## Purpose

This procedure controls the complete process for moving authoritative Light-O-Rama (LOR) preview data into the MSB production PostgreSQL database.

It is intended to prevent:

- Stale or duplicate previews from entering an import.
- Test or temporary previews from being treated as production data.
- Display-name corrections from creating duplicate display records.
- Changed LOR UUIDs from breaking an established display identity.
- New physical displays from being omitted from `ref.display`.
- Dismantled or discarded displays from remaining `ACTIVE`.
- P1, P2, or P3 from running against unresolved import discrepancies.

The parser and snapshot ingest do **not** update production reference data by themselves. Reconciliation is a mandatory gate between snapshot ingest and P1/P2/P3.

## Revision History

| Date | Author | Revision |
|---|---|---|
| 2026-07-31 | GAL | Initial procedure draft. Documents authoritative-preview controls, V7 parsing, PostgreSQL ingest, reconciliation requirements, and the P1/P2/P3 gate. |
| 2026-07-31 | GAL / OpenAI | Linked the full P1/P2/P3 promotion design and established controlled orchestration as the required final production execution model. |
| 2026-07-31 | GAL / OpenAI | Revised the gate to promote independently safe records, quarantine only affected exceptions, and process stage/scene context before displays and scene assignments. |

## Current Implementation Status

| Procedure component | Status |
|---|---|
| Master PC and preview-folder controls | Procedure defined; automated manifest validation not yet implemented |
| `parse_props_v7_scene_parser.py` | Implemented and under V7 validation |
| `postgres_run_ingest_v7.ps1` | Implemented and tested |
| Reconciliation preflight/report | Under development |
| P1 | Legacy procedure exists; V7 explicit-run replacement is designed but not implemented |
| P2 | Legacy procedure exists; reconciliation-safe explicit-run replacement is designed but not implemented |
| P3 | Scene and scene-membership promotion is designed but not implemented |
| Controlled orchestrator | Required final production entry point; designed but not implemented |

Do not represent an under-development component as production-ready.

## Authoritative Source Policy

### Designated Master PC

Only one computer may be designated as the authoritative **LOR Master PC**.

All production preview editing must be performed from the authoritative preview set on that computer. Copies on other computers are not authoritative unless the Master PC role has been formally transferred using this procedure.

Record the current Master PC before beginning:

| Field | Value |
|---|---|
| Computer name | |
| Operator | |
| LOR version | |
| Date verified | |
| Master preview folder | |

### Transferring the Master PC Role

Before editing previews on a replacement computer:

1. Stop production preview editing on the existing Master PC.
2. Export every current production preview from the existing Master PC.
3. Transfer the complete authoritative preview set to the replacement computer.
4. Import every preview into LOR on the replacement computer.
5. Verify that every expected background preview, every authoritative standalone
   stage preview, and the Master Musical Preview were transferred.
6. Compare preview names, stage IDs, UUIDs, revisions, and modified dates where available.
7. Resolve every missing, duplicate, older, or uncertain preview.
8. Record the replacement computer as the new Master PC.
9. Only then resume production preview or scene editing.

> **Hard stop:** Do not edit the new master preview set if the transfer from the previous Master PC is incomplete or uncertain.

## Required Inputs

- Authoritative LOR previews from the designated Master PC.
- Exactly one current production background preview for every expected stage.
- Every current authoritative standalone stage preview, including the Parade
  Float preview.
- Exactly one current Master Musical Preview.
- Current `parse_props_v7_scene_parser.py`.
- Current `postgres_run_ingest_v7.ps1` and its associated PostgreSQL ingest SQL.
- Access to the production PostgreSQL database.
- Current P1 and P2 procedures copied from the production database.
- A database operator identity for reconciliation audit records.

## Status and Identity Rules

### Display Identity Contract

- `display_id` is the permanent database identity and the foreign key used by relational tables.
- `display_name` is the meaningful human-facing identity.
- `lor_prop_id` is only the current LOR UUID association stored in `ref.display`.
- No other production relational tables may depend on `lor_prop_id`.
- A display rename or LOR UUID change must preserve `display_id`.

This contract is enforced by reconciliation classification. Unresolved identity
exceptions quarantine only the affected display and its dependent assignments
when they can be isolated safely. They do not prevent unrelated valid records
from being promoted.

### Display Status

`ref.display_status` is the authoritative status lookup table. `ref.display.display_status_id` is the foreign key to that lookup.

Current rules:

| Status ID | Status | Meaning |
|---:|---|---|
| 1 | `ACTIVE` | Complete physical display currently eligible for the show and active operational lists |
| 2 | `RETIRED` | Complete, identifiable display still physically exists but is not currently in use |
| 3 | `RECYCLED` | Display identity no longer physically exists because it was dismantled, repurposed, or discarded |

- New physical displays are created with status `ACTIVE`.
- A status must be selected from `ref.display_status`; the interface must not manufacture status values.
- Missing from one LOR import does not automatically change a display's status.
- Status changes require an explicit operator decision and audit record.
- No display record is deleted as part of reconciliation.

Examples already established:

- Discarded PVC Igloos: `RECYCLED`.
- QV `Making`, `Spirits`, and `Bright`: `RECYCLED` because the lights were removed and their frames returned to reusable material inventory. The finished displays no longer exist.

### Permanent Production Identity

`ref.display.display_id` is the permanent production identity.

- A display-name correction must preserve `display_id`.
- An LOR UUID correction must preserve `display_id`.
- A status change must preserve `display_id`.
- Historical relationships must remain attached to the same `display_id`.
- A genuinely new physical display receives a new `display_id`.
- A future display built from recycled materials receives a new display record and new `display_id`.

### LOR UUID Mapping

The LOR `propClass_id` UUID is a strong identity signal, but it is not infallible. Testing confirmed that an LOR UUID can change while the display comment/name remains unchanged.

The persistent relationship to maintain is:

```text
LOR propClass_id UUID -> ref.display.display_id
```

UUID evidence must be combined with the display name, previous imports, preview/stage context, and operator review.

## Procedure

### 1. Prepare a Clean Master Export Folder

1. Confirm the computer is the designated LOR Master PC.
2. Create or empty the folder used for this production export.
3. Export every current production background preview to that folder.
4. Export every current authoritative standalone stage preview, including the
   Parade Float preview, to that folder.
5. Export the current Master Musical Preview to that folder.
6. Do not copy forward files from a previous export merely because they appear to be missing.
7. Investigate a missing preview at its authoritative source.

The folder must contain:

- Exactly one current background preview per expected stage.
- Every current authoritative standalone stage preview, including the Parade
  Float preview.
- Exactly one current Master Musical Preview.
- No duplicate-stage previews.
- No older revisions.
- No test previews.
- No temporary, recovery, experimental, or troubleshooting previews.
- No unrelated previews.

> **Hard stop:** If there is any doubt about which preview is current, stop and resolve the authoritative source before parsing.

### 2. Validate the Preview Set

Create and review a preview manifest before running the parser. Until automated manifest validation exists, this review is manual.

Record at least:

| Stage | Preview name | Preview UUID | Revision | LOR version | Modified date | Result |
|---|---|---|---:|---|---|---|
| | | | | | | |

Validate:

- Every expected background and standalone stage preview is present.
- No stage-bearing preview is duplicated unintentionally. A standalone preview
  is not an error merely because another preview or scene resolves to the same
  stage; its role must be understood and authoritative.
- The Master Musical Preview is present exactly once.
- Preview names and stage IDs are correct.
- No filename or preview metadata indicates an old or test copy.
- Comment fields come from the intended current preview.
- Preview UUID or revision changes are understood.
- The preview set was exported from the designated Master PC.

> **Hard stop:** Missing, duplicate, stale, test, or questionable previews must be resolved before continuing.

### 3. Run the V7 Scene-Aware Parser

Run:

```powershell
python .\parsers\experimental\parse_props_v7_scene_parser.py
```

When prompted:

1. Select the intended V7 scene-aware SQLite output database.
2. Select the validated master export folder.
3. Confirm the parser reports the expected number of previews.
4. Review all errors, collisions, and warnings.
5. Preserve the console output with the import work record.

Expected result:

- The parser completes successfully.
- The expected previews are processed.
- Scene-aware data is written to the SQLite snapshot.
- Any collision or validation reports are reviewed.

> **Hard stop:** Do not ingest a parser output with unexplained errors, missing previews, duplicate preview identities, or unresolved collisions affecting production identity.

### 4. Run the PostgreSQL V7 Snapshot Ingest

Run:

```powershell
.\postgres_run_ingest_v7.ps1
```

Confirm:

- A new `lor_snap.import_run` record is created.
- The run has a unique `import_run_id`.
- Previews, scenes, props, subprops, DMX channels, and scene membership are ingested.
- The runner reports successful completion.
- Row counts are plausible compared with the parser output and previous known-good run.
- The run summary is saved with the work record.

Record:

| Field | Value |
|---|---|
| `import_run_id` | |
| Run date/time | |
| SQLite source | |
| Preview count | |
| Scene count | |
| Prop count | |
| Subprop count | |
| DMX-channel count | |
| Scene-LOR-prop count | |
| Warnings | |

The snapshot ingest is immutable historical evidence. Corrections to production reference data occur through reconciliation, not by rewriting the imported snapshot.

### 5. Run the Reconciliation Preflight

The reconciliation preflight is mandatory and must run against the selected `import_run_id` before P1, P2, or P3.

The report must compare in both directions:

1. LOR display/comment names that do not resolve to an eligible production display.
2. `ACTIVE` production displays that do not appear in the current LOR snapshot.

Existing-display selection must use `ref.display` joined to `ref.display_status`. Normal matching and missing-display review must be based on `ACTIVE` records, while still permitting an operator to inspect historical `RETIRED` or `RECYCLED` identities when investigating a conflict.

#### Required Reconciliation Outcomes

| Condition | Required operator action | Production identity result |
|---|---|---|
| Exact name and expected UUID | Accept exact match | Preserve `display_id`, name, and UUID mapping |
| Changed LOR name, same established UUID | Acknowledge and update production display name | Preserve `display_id`; audit old and new name |
| Same exact display name, changed LOR UUID | Acknowledge and update PostgreSQL UUID mapping | Preserve `display_id` and name; audit old and new UUID |
| Name and UUID both changed | Investigate manually | Do not guess or create automatically |
| Confirmed new physical display | Add new display | Create new `ref.display` record as `ACTIVE` |
| Active production display missing from LOR but still complete and stored | Retire if appropriate | Change status to `RETIRED`; preserve `display_id` |
| Display dismantled, repurposed, or discarded | Recycle | Change status to `RECYCLED`; preserve `display_id` |
| Nonphysical LOR helper such as `PHANTOM` | Exclude from display reconciliation | Record explicit exclusion rule; do not create display |
| LOR comment/name is wrong and production is correct | Flag LOR correction | Do not change production identity; correct LOR and repeat parser/ingest as required |
| Identity remains uncertain | Defer with reason | Leave unresolved; do not allow silent action |

#### Rename Production Display

Use only after validating that the LOR record and existing production display are the same physical identity.

The action must:

- Display the current and proposed names.
- Display the permanent `display_id`.
- Display UUID and preview/stage evidence.
- Require operator confirmation and reason.
- Update only the correct production name field.
- Preserve `display_id`, status, inventory relationships, and history.
- Write an audit record.

#### Update LOR UUID Mapping

Use when the display name still exactly identifies the existing production display but the LOR `propClass_id` has changed.

The action must:

- Display the unchanged display name and permanent `display_id`.
- Display the old and new UUIDs.
- Require operator confirmation and reason.
- Update the persistent PostgreSQL UUID association.
- Preserve `display_id`, display name, status, inventory relationships, and history.
- Write an audit record.

#### Add New Display

Use only for a confirmed new physical display.

The action must:

- Prefill the LOR display name, preview/stage context, and UUID where available.
- Require all mandatory `ref.display` data rather than inventing missing values.
- Create the display with the `ACTIVE` status resolved through `ref.display_status`.
- Create a permanent new `display_id`.
- Store the LOR UUID relationship.
- Write an audit record tied to the selected import run.

#### Retire or Recycle Existing Display

Missing from LOR is evidence for review, not automatic proof of status.

- Use `RETIRED` only when the complete, identifiable physical display still exists.
- Use `RECYCLED` when the display no longer exists as that display.
- Preserve the permanent `display_id` and all history.
- Record the effective date, reason, operator, prior status, new status, and import run.
- Permit controlled multi-select actions when several confirmed displays share the same resolution and reason.

#### Exclude Nonphysical LOR Record

Use for layout helpers, phantom props, and other LOR objects that are not physical production displays.

The exclusion must be explicit, persistent, auditable, and narrow enough that it does not hide a future legitimate display accidentally.

#### Flag LOR Correction

Use when the production database is correct but the LOR comment/name is wrong.

1. Record the required LOR correction.
2. Do not alter the correct production display.
3. Correct the authoritative preview on the Master PC.
4. Re-export the affected authoritative preview into a newly cleaned export folder.
5. Rerun validation, parsing, and ingest as required to create a corrected snapshot run.
6. Reconcile against the corrected `import_run_id`.

#### Required Audit Data

Every reconciliation action must record:

- `import_run_id`.
- Action type.
- `display_id`, when applicable.
- LOR preview, stage, display/comment name, and UUID evidence.
- Previous value.
- New value.
- Reason.
- Operator.
- Timestamp.

### 6. Classify Safe Records and Exceptions

Rerun the reconciliation report after each action or controlled batch. Every
candidate must be classified as one of the following:

- Resolved.
- Explicitly excluded by an approved persistent rule.
- Formally deferred with a reason and with an approved policy that permits the deferment.

A deferred identity conflict with reliable row-level isolation is withheld from
display promotion along with its scene assignment. Unrelated safe records may
continue. Whole-run rejection is reserved for structural failures or inconsistencies
that make row-level isolation unsafe.

Required run results are:

| Result | Meaning |
|---|---|
| `PASSED` | All eligible records promoted; no unresolved exceptions remain |
| `PASSED_WITH_EXCEPTIONS` | Safe records promoted; isolated unresolved records and their dependencies were withheld |
| `FAILED` | Structural, source-integrity, or transaction failure made safe isolation impossible |

Record the passing preflight result:

| Field | Value |
|---|---|
| `import_run_id` | |
| Preflight completed by | |
| Completion date/time | |
| New displays added | |
| Names corrected | |
| UUID mappings corrected | |
| Displays retired | |
| Displays recycled | |
| Exclusions recorded | |
| Safe/promotable count | |
| Unresolved/deferred count | |
| Dependent assignment count withheld | |

### 7. Promote the Approved Run

The final production workflow will not instruct an operator to run P1, P2, and
P3 separately. After implementation and validation, the operator will invoke one
controlled orchestration procedure with the explicitly approved `import_run_id`.

The orchestrator will:

- Reassert structural validation and reconciliation classification for that exact
  run.
- Promote stage definitions first.
- Promote scene definitions second so Master Musical Preview displays have stage
  context.
- Promote every independently safe display and spare-channel record.
- Synchronize scene assignments last, after permanent `display_id` values exist.
- Withhold only assignments dependent on quarantined scenes or displays.
- Roll back on structural or transaction failure, not merely because isolated
  reconciliation exceptions exist.
- Record promoted, skipped, and exception counts.

Direct execution of P1, P2, or P3 is permitted only during development and
supervised validation. Once the pipeline is approved, normal production roles
will receive execution permission only on the orchestrator.

The full design is maintained in:

`Postgres_sql/Upsert Procedures/01_LOR_Production_Promotion_Pipeline_Design.md`

#### P1 responsibility

- Promote durable stages from background-preview evidence plus scene-derived
  fallback evidence.
- Preserve permanent `stage_id` values.
- Never delete stages missing from one run.

#### P2 responsibility

- Update deterministic safe or explicitly approved displays' LOR-owned current
  attributes.
- Resolve stage through background evidence first and scene evidence as fallback.
- Route approved spare-channel data.
- Automatically handle exact UUID matches, same-UUID renames, unique same-name
  UUID relinks, and genuinely new unique displays.
- Quarantine ambiguous identity or destructive status decisions for operator
  review without blocking unrelated records.

#### P3 responsibility

- Promote current LOR scene metadata into `ref.lor_scene`.
- Promote scene membership into `ref.lor_scene_display` using permanent
  `display_id` relationships.
- Preserve the distinction between scenes, physical stages, and displays.
- Enforce one current scene per display within its preview. A preview may contain
  multiple scenes, and each scene may contain many displays.
- Treat scene assignment as LOR-owned current placement: a move overwrites the
  assignment without changing `display_id`.
- Delete obsolete scene assignments and delete scenes that are empty or no
  longer exist in their authoritative preview.
- Keep prior scene definitions and memberships only in immutable `lor_snap`
  snapshots; production scene tables contain current state only.

P3 does not yet exist, and the revised P1/P2/orchestrator are not yet implemented.
This section is therefore a design requirement, not a production instruction.

### 8. Perform Final Validation

After the controlled stage, scene-definition, display, and scene-assignment phases:

- Confirm every procedure used the approved snapshot/import run.
- Confirm unresolved reconciliation items and dependent assignments were withheld
  and reported, not silently bypassed.
- Confirm renamed displays retained their original `display_id`.
- Confirm corrected UUID mappings retained their original `display_id`.
- Confirm new physical displays were created as `ACTIVE`.
- Confirm recycled displays have status `RECYCLED` and remain in historical records.
- Confirm retired displays have status `RETIRED` and remain in physical inventory reporting.
- Confirm nonphysical LOR records did not create `ref.display` records.
- Confirm stages and scenes were updated only by their designated procedures.
- Preserve parser output, ingest summary, reconciliation audit, procedure output, and validation results.

## Stop Conditions Summary

Stop the workflow immediately if:

- The computer is not the verified Master PC.
- The preview set may not have been fully transferred from the previous Master PC.
- A stage preview or the Master Musical Preview is missing.
- More than one preview represents the same stage.
- The folder contains an older, test, temporary, recovery, or unexplained preview.
- Parser errors or identity collisions are unresolved.
- Snapshot-ingest row counts are implausible or the ingest fails.
- A proposed rename or UUID change cannot be tied confidently to one permanent `display_id`.
- A UUID maps to multiple production displays without an established explanation.
- Multiple UUIDs map unexpectedly to one display.
- A structural or source-integrity error prevents safe row-level isolation.
- P1 or P2 validation fails.
- P3 has not yet been implemented and approved for production use.

## Future Automation Requirements

The following controls should be automated:

- Expected-preview manifest and stage coverage.
- Duplicate-stage and duplicate-preview detection.
- Identification of old, test, temporary, and unexpected preview files.
- Comparison of preview UUID, revision, and metadata with the last approved import.
- Bidirectional LOR-to-`ACTIVE`-display reconciliation.
- Controlled buttons/forms for rename, UUID correction, add, retire, recycle, exclude, flag LOR correction, and defer.
- Full reconciliation audit history.
- Database-enforced structural validation and row-level reconciliation
  classification tied to `import_run_id`.
- One explicit-run orchestration procedure that enforces the stage → scene
  definitions → safe displays → scene assignments order.
- Production permissions that prevent routine manual execution of P1/P2/P3.
- Post-procedure verification report.

## Related Files and Objects

- `parse_props_v7_scene_parser.py`
- `postgres_run_ingest_v7.ps1`
- `lor_snap.import_run`
- `ref.display`
- `ref.display_status`
- `ref.stage`
- Current production P1 procedure
- Current production P2 procedure
- Future P3 scene-reference procedure
- `01_LOR_Production_Promotion_Pipeline_Design.md`
