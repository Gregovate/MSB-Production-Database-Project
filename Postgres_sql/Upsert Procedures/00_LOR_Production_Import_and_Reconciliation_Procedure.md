# LOR Production Import and Reconciliation Procedure

| Document control | Value |
|---|---|
| Repository path | `Postgres_sql/Upsert Procedures/00_LOR_Production_Import_and_Reconciliation_Procedure.md` |
| Document type | Controlled production procedure |
| Status | DRAFT — production execution remains blocked pending reconciliation implementation and validation |
| Owner / author | GAL |
| Initial release | 2026-07-31 |
| Current revision | 2026-08-01 |

## Purpose

This procedure controls the complete process for moving authoritative Light-O-Rama (LOR) preview data into the MSB production PostgreSQL database.

It is intended to prevent:

- Stale or duplicate previews from entering an import.
- Test or temporary previews from being treated as production data.
- Display-name corrections from creating duplicate display records.
- Changed LOR UUIDs from breaking an established display identity.
- New physical displays from being omitted from `ref.display`.
- Dismantled or discarded displays from remaining `ACTIVE`.
- P1, P2, or P3 from running outside the controlled reconciliation workflow.

The parser and snapshot ingest do **not** update production reference data by themselves. Reconciliation is a mandatory gate between snapshot ingest and P1/P2/P3.

## Revision History

| Date | Author | Revision |
|---|---|---|
| 2026-08-01 | GAL / OpenAI | Defined the finished single-workflow operator experience, automatic latest-ingest capture, persistent reconciliation state, operator pause/resume, finish reconciliation, post-write validation, and timestamped HTML report publication. |
| 2026-07-31 | GAL / OpenAI | Revised the gate to promote independently safe records, quarantine only affected exceptions, and process stage/scene context before displays and scene assignments. |
| 2026-07-31 | GAL / OpenAI | Linked the full P1/P2/P3 promotion design and established controlled orchestration as the required final production execution model. |
| 2026-07-31 | GAL | Initial procedure draft. Documents authoritative-preview controls, V7 parsing, PostgreSQL ingest, reconciliation requirements, and the P1/P2/P3 gate. |

## Finished Production Workflow

The finished system is one controlled operator workflow, not a collection of unrelated scripts.

The operator initiates the production import once. The workflow then performs:

```text
Start LOR Production Import
    -> run the V7 scene-aware parser
    -> run the password-protected PostgreSQL snapshot ingest
    -> automatically capture the latest completed ingest
    -> create the persistent reconciliation run
    -> build the stage, display, scene, and scene-membership working sets once
    -> run preflight and classifications
    -> pause only when operator decisions are required
    -> apply approved P1/P2/P3 changes
    -> validate actual committed production results
    -> generate a timestamped HTML reconciliation report
    -> publish the report to the internal web server
    -> mark reconciliation complete
```

If preflight requires no operator decisions, the workflow continues automatically through promotion, validation, report publication, and completion.

If decisions are required, the workflow pauses in operator review. The operator records approve, add, rename/relink, reassociate, lifecycle-status, source-correction, exclude, block, or defer decisions as applicable. The operator then invokes **Finish Reconciliation** to resume the same persistent reconciliation run.

The workflow does not ask the operator to select or enter an `import_run_id`. The database captures the latest completed ingest once and uses that same captured run through preflight, decisions, P1, P2, P3, validation, and reporting.

A newer ingest created while reconciliation is paused does not replace the captured ingest. It becomes eligible for the next reconciliation workflow.

## Persistent Reconciliation Context

The production workflow must persist its reconciliation state because operator review and report publication may span multiple database connections and application requests.

The persistent context includes:

- reconciliation-run identity;
- captured `import_run_id`;
- workflow status and timestamps;
- stage candidates;
- display candidates;
- scene candidates;
- scene-display membership candidates;
- operator decisions and defer reasons;
- blocked candidates;
- actual committed results;
- validation results;
- generated report path and publication timestamp.

The candidate working sets are built once and reused throughout the workflow. P1, P2, P3, validation, and reporting do not independently rerun the expensive identity-resolution comparison.

Session-local temporary tables may be used during development but are not the finished production state. The persistent reconciliation rows remain available through completion and afterward as audit history unless a separate approved retention process archives them.

## Document Boundaries

This document defines the operator-facing production procedure.

The persistent orchestration and promotion architecture is defined in:

`Postgres_sql/Upsert Procedures/01_LOR_Production_Promotion_Pipeline_Design.md`

The detailed stage, display, scene, classification, operator-decision, and report rules are defined in:

`Postgres_sql/Upsert Procedures/reconciliation/LOR_Display_Reconciliation_SQL_Design.md`

The three documents describe one workflow at different levels and must not define competing execution paths.

## Current Implementation Status

| Procedure component | Status |
|---|---|
| Master PC and preview-folder controls | Procedure defined; automated manifest validation not yet implemented |
| `parse_props_v7_scene_parser.py` | Implemented and under V7 validation |
| `postgres_run_ingest_v7.ps1` | Implemented and tested |
| Latest-ingest preflight scripts | Implemented for development/testing; conversion to persistent candidate builders required |
| Persistent reconciliation-run and candidate tables | Designed; not implemented |
| P1 | Legacy procedure exists; reconciliation-safe replacement not implemented |
| P2 | Legacy procedure exists; reconciliation-safe replacement not implemented |
| P3 | Scene and scene-membership promotion is designed but not implemented |
| Controlled start/finish workflow | Required final production entry point; designed but not implemented |
| Timestamped HTML report publication | Required; not implemented |

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
5. Verify that every expected background preview, every authoritative standalone stage preview, and the Master Musical Preview were transferred.
6. Compare preview names, stage IDs, UUIDs, revisions, and modified dates where available.
7. Resolve every missing, duplicate, older, or uncertain preview.
8. Record the replacement computer as the new Master PC.
9. Only then resume production preview or scene editing.

> **Hard stop:** Do not edit the new master preview set if the transfer from the previous Master PC is incomplete or uncertain.

## Required Inputs

- Authoritative LOR previews from the designated Master PC.
- Exactly one current production background preview for every expected stage.
- Every current authoritative standalone stage preview, including the Parade Float preview.
- Exactly one current Master Musical Preview.
- Current `parse_props_v7_scene_parser.py`.
- Current `postgres_run_ingest_v7.ps1` and its associated PostgreSQL ingest SQL.
- Access to the production PostgreSQL database.
- A database operator identity for reconciliation audit records.

## Status and Identity Rules

### Display Identity Contract

- `display_id` is the permanent database identity and the foreign key used by relational tables.
- `display_name` is the meaningful human-facing identity.
- `lor_prop_id` is only the current LOR association stored in `ref.display`.
- No other production relational tables may depend on `lor_prop_id`.
- A display rename or LOR UUID change must preserve `display_id`.

This contract is enforced by reconciliation classification. Unresolved identity exceptions quarantine only the affected display and its dependent assignments when they can be isolated safely. They do not prevent unrelated valid records from being promoted.

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
4. Export every current authoritative standalone stage preview, including the Parade Float preview, to that folder.
5. Export the current Master Musical Preview to that folder.
6. Do not copy forward files from a previous export merely because they appear to be missing.
7. Investigate a missing preview at its authoritative source.

The folder must contain:

- Exactly one current background preview per expected stage.
- Every current authoritative standalone stage preview, including the Parade Float preview.
- Exactly one current Master Musical Preview.
- No duplicate-stage previews.
- No older revisions.
- No test previews.
- No temporary, recovery, experimental, or troubleshooting previews.
- No unrelated previews.

> **Hard stop:** If there is any doubt about which preview is current, stop and resolve the authoritative source before parsing.

### 2. Validate the Preview Set

Create and review a preview manifest before running the parser. Until automated manifest validation exists, this review is manual.

Validate:

- Every expected background and standalone stage preview is present.
- No stage-bearing preview is duplicated unintentionally.
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

> **Hard stop:** Do not ingest parser output with unexplained errors, missing previews, duplicate preview identities, or unresolved collisions affecting production identity.

### 4. Run the Password-Protected PostgreSQL Snapshot Ingest

Run:

```powershell
.\postgres_run_ingest_v7.ps1
```

Confirm:

- A new `lor_snap.import_run` record is created.
- The run has a unique `import_run_id`.
- Previews, scenes, props, subprops, DMX channels, and scene membership are ingested.
- The runner reports successful completion.
- Row counts are plausible compared with parser output and the previous known-good run.
- The run summary is saved with the work record.

The snapshot ingest is immutable historical evidence. Corrections to production reference data occur through reconciliation, not by rewriting the imported snapshot.

### 5. Start Reconciliation and Capture the Ingest

Immediately after successful ingest, the controlled workflow starts reconciliation.

The database must:

1. Create one persistent reconciliation-run row.
2. Automatically capture the latest completed ingest.
3. Persist that `import_run_id` on the reconciliation run.
4. Build the stage, display, scene, and scene-membership candidate working sets once.
5. Run structural checks and classifications.
6. Continue automatically or pause for operator review.

The operator does not enter an ingest number.

### 6. Review Only the Candidates Requiring Decisions

Every candidate is classified independently. Exact matches require no operator action and are not listed as production changes in the final report.

Typical operator decisions include:

| Condition | Operator decision | Production identity result |
|---|---|---|
| Changed LOR name, same established UUID | Approve rename | Preserve `display_id`; audit old and new name |
| Same exact display name, changed LOR UUID | Approve UUID relink | Preserve `display_id` and name |
| Name and UUID both changed | Reassociate after investigation | Preserve selected existing `display_id` |
| Confirmed new physical display | Add new display | Create new `display_id` as `ACTIVE` |
| Active production display missing from LOR | Retire, recycle, restore-to-LOR, or defer | Preserve existing `display_id` |
| Non-active display appears in LOR | Correct status, correct LOR, or defer | No automatic reactivation |
| Nonphysical LOR helper | Exclude | Do not create `ref.display` |
| LOR source data is wrong | Require source correction | Production remains unchanged; new ingest required |
| Information is insufficient | Defer with reason | Production remains unchanged |

Blocked or deferred items do not prevent unrelated approved items from advancing.

### 7. Finish Reconciliation

After all required operator decisions are recorded, invoke **Finish Reconciliation**.

The finish phase must:

1. Reopen the same persistent reconciliation run.
2. Verify the captured ingest has not changed.
3. Verify every required decision is resolved or explicitly deferred.
4. Apply approved P1 stage changes.
5. Apply approved scene definitions needed for current stage context.
6. Apply approved P2 display identity, metadata, and lifecycle changes.
7. Apply approved P3 scene-display membership changes.
8. Leave blocked and deferred production rows unchanged.
9. Persist actual committed result messages.

Normal operators do not run P1, P2, or P3 directly.

### 8. Perform Post-Write Validation

Confirm:

- Every phase used the same captured ingest and reconciliation run.
- Renamed or relinked displays retained their permanent `display_id`.
- Stage changes retained permanent `stage_id` where required.
- New displays were created only from approved new-display candidates.
- Status changes were explicitly approved and use `ref.display_status`.
- Nonphysical and SPARE rows did not create `ref.display` rows.
- Scene identity uses `(preview_uuid, scene_uuid)`.
- Scene membership uses permanent `display_id`.
- Blocked and deferred rows remained unchanged.
- Actual committed counts match the persisted result records.

A validation failure prevents the reconciliation run from being marked complete and must be reported accurately.

### 9. Generate and Publish the HTML Report

Generate one timestamped HTML document from persisted reconciliation results and publish it to the internal web server.

The report must include:

```text
Production Results

  Added......................n
  Updated....................n
  Reassociated...............n
  Status Changes.............n

Operator Review

  Blocked....................n
  Deferred...................n
```

Exact matches are excluded because no production change occurred.

The detail section must include plain-language messages and enough metadata for follow-up cleanup work orders. The report must describe actual committed results, not proposed changes.

Store the report path and publication timestamp on the reconciliation run before marking it complete.

## Stop Conditions Summary

Stop the workflow immediately if:

- The computer is not the verified Master PC.
- The preview set may not have been fully transferred from the previous Master PC.
- A required preview or the Master Musical Preview is missing.
- The folder contains an older, test, temporary, recovery, or unexplained preview.
- Parser errors or identity collisions are unresolved.
- Snapshot-ingest row counts are implausible or the ingest fails.
- Structural preflight cannot safely isolate candidate groups.
- Persistent reconciliation state cannot be created or retained.
- A proposed identity change cannot be tied confidently to one permanent identity and is not explicitly deferred.
- Post-write validation or report publication fails.

## Future Automation Requirements

The final operator-facing application should provide:

- one **Start LOR Production Import** action that launches parser, protected ingest, capture, and preflight;
- controlled review screens only for candidates requiring decisions;
- one **Finish Reconciliation** action when review is complete;
- automatic promotion when no review is required;
- persistent candidate and decision state;
- database-enforced dependency ordering;
- post-write validation;
- timestamped HTML report generation and internal publication;
- permissions preventing routine direct execution of P1/P2/P3.

## Related Files and Objects

- `parse_props_v7_scene_parser.py`
- `postgres_run_ingest_v7.ps1`
- `lor_snap.import_run`
- `ref.display`
- `ref.display_status`
- `ref.stage`
- `ref.lor_scene`
- `ref.lor_scene_display`
- `01_LOR_Production_Promotion_Pipeline_Design.md`
- `reconciliation/LOR_Display_Reconciliation_SQL_Design.md`
