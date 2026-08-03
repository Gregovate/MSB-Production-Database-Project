# LOR Production Import and Reconciliation Procedure

| Document control | Value |
|---|---|
| Repository path | `Postgres_sql/Upsert Procedures/00_LOR_Production_Import_and_Reconciliation_Procedure.md` |
| Document type | Controlled production procedure |
| Status | DRAFT — production execution remains blocked pending reconciliation implementation and validation |
| Owner / author | GAL |
| Initial release | 2026-07-31 |
| Current revision | 2026-08-02 |

## Purpose

This procedure defines the complete operator workflow for moving authoritative Light-O-Rama (LOR) preview data into the MSB production PostgreSQL database.

It is intended to prevent:

- stale or duplicate previews from entering an import;
- test or temporary previews from being treated as production data;
- display-name corrections from creating duplicate display records;
- changed LOR UUIDs from breaking an established display identity;
- new physical displays from being omitted from `ref.display`;
- dismantled or discarded displays from remaining `ACTIVE` without an explicit lifecycle decision;
- P1, P2, or P3 from running outside the controlled reconciliation workflow;
- a successful ingest from remaining unreconciled.

The parser and snapshot ingest do **not** update production reference data by themselves. Every successful latest ingest must enter reconciliation. Reconciliation is the mandatory gate between snapshot ingest and P1/P2/P3 production promotion.

## Revision History

| Date | Author | Revision |
|---|---|---|
| 2026-08-02 | GAL / OpenAI | Added the replacement-label report requirement for committed display-name changes; reconciliation records label work but does not print automatically. |
| 2026-08-02 | GAL / OpenAI | Defined the complete single-interface workflow: start import, run parser and protected ingest, automatically begin reconciliation, collect decisions, promote all passing candidates, block deferred or unresolved candidates, support finish or cancel, and generate a report in both cases. |
| 2026-08-01 | GAL / OpenAI | Defined the finished single-workflow operator experience, automatic latest-ingest capture, persistent reconciliation state, operator pause/resume, finish reconciliation, post-write validation, and timestamped HTML report publication. |
| 2026-07-31 | GAL / OpenAI | Revised the gate to promote independently safe records, quarantine only affected exceptions, and process stage/scene context before displays and scene assignments. |
| 2026-07-31 | GAL / OpenAI | Linked the full P1/P2/P3 promotion design and established controlled orchestration as the required final production execution model. |
| 2026-07-31 | GAL | Initial procedure draft. Documents authoritative-preview controls, V7 parsing, PostgreSQL ingest, reconciliation requirements, and the P1/P2/P3 gate. |

## Finished Production Workflow

The finished system is one controlled operator workflow, not a collection of unrelated scripts.

The operator uses one application action, provisionally named **Start LOR Production Import**. The final interface may be implemented as a Directus workflow button or another approved operator interface, but the behavior is the same.

```text
Start LOR Production Import
    -> run the V7 scene-aware parser
    -> run the password-protected PostgreSQL snapshot ingest
    -> automatically start reconciliation for the latest completed snapshot
    -> create the persistent reconciliation run
    -> build the stage, display, scene, and scene-membership candidate sets once
    -> run preflight checks and classifications
    -> prompt the operator only for candidates requiring decisions
    -> block deferred candidates and candidates without completed decisions
    -> promote every passing and approved candidate
    -> validate actual committed production results
    -> generate and publish the reconciliation report
    -> complete
```

If no operator decisions are required, the workflow continues automatically through promotion, validation, report publication, and completion.

If decisions are required, the workflow pauses in operator review. The operator records the applicable decision for each candidate and then chooses one of two workflow actions:

- **Finish Reconciliation** — promote every passing or approved candidate, leave deferred and unresolved candidates unchanged in production, validate the committed results, publish the report, and complete the reconciliation.
- **Cancel Reconciliation** — apply no production changes, delete the entire latest snapshot and its uncommitted reconciliation working state, publish a cancellation report, and close the reconciliation as `CANCELLED`.

The operator never selects or enters an `import_run_id`. The ingest and reconciliation workflow uses the latest completed snapshot created by that execution.

## Persistent Reconciliation Context

The production workflow must persist its reconciliation state because operator review and report publication may span multiple application requests and database connections.

The persistent context includes:

- reconciliation-run identity;
- captured latest-snapshot `import_run_id`;
- workflow status and timestamps;
- stage candidates;
- display candidates;
- scene candidates;
- scene-display membership candidates;
- operator decisions and defer reasons;
- blocked and unresolved candidates;
- actual committed results;
- validation results;
- generated report path and publication timestamp.

The candidate sets are built once and reused throughout the workflow. P1, P2, P3, validation, and reporting do not independently rerun the identity-resolution comparison or select a different ingest.

Session-local temporary tables may be used during development or inside one atomic operation, but they are not the finished production workflow state.

Completed reconciliation decisions, committed results, and report references remain as audit history. Snapshot retention is separate: retained snapshots are immutable while they exist, but older snapshots may be removed under the approved `lor_snap` retention process.

## Document Boundaries

This document defines the operator-facing production procedure.

The persistent orchestration and promotion architecture is defined in:

`Postgres_sql/Upsert Procedures/01_LOR_Production_Promotion_Pipeline_Design.md`

The detailed stage, display, scene, classification, operator-decision, and report rules are defined in:

`Postgres_sql/Upsert Procedures/reconciliation/LOR_Display_Reconciliation_SQL_Design.md`

The three documents describe one workflow at different levels and must not define competing execution paths. A design change crossing these boundaries requires all affected documents to be updated before implementation continues.

## Current Implementation Status

| Procedure component | Status |
|---|---|
| Master PC and preview-folder controls | Procedure defined; automated manifest validation not yet implemented |
| `parse_props_v7_scene_parser.py` | Implemented and under V7 validation |
| `postgres_run_ingest_v7.ps1` | Implemented and tested |
| Latest-ingest preflight scripts | Implemented for development/testing; not a production reconciliation interface |
| Persistent reconciliation-run and candidate tables | Designed; not implemented |
| Operator decision interface | Designed; not implemented |
| Finish and cancel workflow actions | Designed; not implemented |
| P1 | Legacy procedure exists; reconciliation-safe replacement not implemented |
| P2 | Legacy procedure exists; reconciliation-safe replacement not implemented |
| P3 | Scene and scene-membership promotion is designed but not implemented |
| Controlled single-interface workflow | Required production entry point; designed but not implemented |
| Timestamped HTML report publication | Required for completed and cancelled reconciliations; not implemented |

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
- Access to the approved operator interface for starting, reviewing, finishing, or cancelling reconciliation.

## Status and Identity Rules

### Display Identity Contract

- `display_id` is the permanent database identity and the foreign key used by relational tables.
- `display_name` is the meaningful human-facing identity.
- `lor_prop_id` is only the current LOR association stored in `ref.display`.
- No other production relational tables may depend on `lor_prop_id`.
- A display rename or LOR UUID change must preserve `display_id`.

This contract is enforced by reconciliation classification. Unresolved identity exceptions block only the affected display and its dependent assignments when they can be isolated safely. They do not prevent unrelated valid records from being promoted.

### Display Status

`ref.display_status` is the authoritative status lookup table. `ref.display.display_status_id` is the foreign key to that lookup.

Current rules:

| Status ID | Status | Meaning |
|---:|---|---|
| 1 | `ACTIVE` | Complete physical display currently eligible for the show and active operational lists |
| 2 | `RETIRED` | Complete, identifiable display still physically exists but is not currently in use |
| 3 | `RECYCLED` | Display identity no longer physically exists because it was dismantled, repurposed, or discarded |

- New physical displays are created with status `ACTIVE` only after an explicit approved new-display decision.
- A status must be selected from `ref.display_status`; the interface must not manufacture status values.
- Missing from one LOR import does not automatically change a display's status.
- Status changes require an explicit operator decision and audit record.
- No display record is deleted as part of reconciliation.

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

- exactly one current background preview per expected stage;
- every current authoritative standalone stage preview, including the Parade Float preview;
- exactly one current Master Musical Preview;
- no duplicate-stage previews;
- no older revisions;
- no test previews;
- no temporary, recovery, experimental, or troubleshooting previews;
- no unrelated previews.

> **Hard stop:** If there is any doubt about which preview is current, stop and resolve the authoritative source before starting the workflow.

### 2. Validate the Preview Set

Create and review a preview manifest before starting the production import. Until automated manifest validation exists, this review is manual.

Validate:

- every expected background and standalone stage preview is present;
- no stage-bearing preview is duplicated unintentionally;
- the Master Musical Preview is present exactly once;
- preview names and stage IDs are correct;
- no filename or preview metadata indicates an old or test copy;
- comment fields come from the intended current preview;
- preview UUID or revision changes are understood;
- the preview set was exported from the designated Master PC.

> **Hard stop:** Missing, duplicate, stale, test, or questionable previews must be resolved before continuing.

### 3. Start LOR Production Import

From the approved operator interface, select **Start LOR Production Import**.

The interface starts one controlled workflow. The operator does not separately choose a snapshot or reconciliation run.

The workflow must:

1. run the V7 scene-aware parser against the validated master export folder;
2. stop if parser errors, collisions, missing previews, duplicate preview identities, or other blocking conditions are detected;
3. run the password-protected PostgreSQL snapshot ingest using the successful parser output;
4. stop if the ingest fails or produces implausible counts;
5. create a new latest snapshot in `lor_snap`;
6. automatically start reconciliation for that latest snapshot.

Password handling must remain protected. The operator may be prompted for the PostgreSQL password by the secured runner, but the password is never stored in the reconciliation records or report.

### 4. Automatically Start Reconciliation

Immediately after a successful ingest, the workflow must:

1. create one persistent reconciliation-run row;
2. capture the latest completed snapshot created by the workflow;
3. persist its `import_run_id` on the reconciliation run;
4. build the stage, display, scene, and scene-membership candidate sets once;
5. run structural checks, classifications, and production comparisons;
6. separate candidates into passing, decision-required, blocked, and deferred states;
7. continue automatically when no operator decisions are required;
8. pause and display the decision interface when operator decisions are required.

The operator does not enter an ingest number.

### 5. Review Candidates Requiring Decisions

Exact matches and other candidates requiring no operator action are not shown as decisions and are not listed as production changes in the final report.

Typical operator decisions include:

| Condition | Operator decision | Production result |
|---|---|---|
| Changed LOR name, same established UUID | Approve rename | Preserve `display_id`; update approved LOR-derived fields |
| Same exact display name, changed LOR UUID | Approve UUID relink | Preserve `display_id` and name; update `lor_prop_id` internally |
| Name and UUID both changed | Reassociate after investigation | Preserve selected existing `display_id` |
| Confirmed new physical display | Add new display | Create new `display_id` as `ACTIVE` |
| Active production display missing from LOR | Retire, recycle, restore-to-LOR, or defer | Preserve existing `display_id` |
| Non-active display appears in LOR | Correct status, correct LOR, or defer | No automatic reactivation |
| Nonphysical LOR helper | Exclude | Do not create `ref.display` |
| LOR source data is wrong | Cancel reconciliation | Delete latest snapshot; correct source and run again |
| Information is insufficient | Defer with reason | Leave production unchanged for the affected candidate |

For each decision-required candidate, the operator may:

- approve the applicable production action;
- defer the candidate and record a reason;
- leave the decision unresolved temporarily while reviewing other candidates;
- cancel the entire reconciliation.

A deferred candidate or a candidate without a completed decision is blocked from production promotion. It does not block unrelated passing or approved candidates.

### 6. Finish Reconciliation

When the operator selects **Finish Reconciliation**, the workflow must:

1. reopen the same persistent reconciliation run;
2. verify that the captured latest snapshot and persisted candidate sets remain valid;
3. treat every deferred candidate and every candidate without a completed decision as blocked from production promotion;
4. apply all passing candidates that require no operator decision;
5. apply all completed approved decisions;
6. apply approved P1 stage changes;
7. apply approved scene definitions needed for current stage context;
8. apply approved P2 display identity, metadata, and lifecycle changes;
9. apply approved P3 scene-display membership changes;
10. leave blocked, deferred, and unresolved production rows unchanged;
11. persist actual committed result messages;
12. perform post-write validation;
13. generate and publish the completed reconciliation report;
14. store the report path or URL and publication timestamp;
15. mark the reconciliation complete.

Normal operators do not run P1, P2, or P3 directly.

### 7. Cancel Reconciliation

When the operator selects **Cancel Reconciliation**, the workflow must:

1. stop the reconciliation before any production promotion occurs;
2. apply no production changes;
3. mark the reconciliation run `CANCELLED`;
4. record the operator, cancellation timestamp, and cancellation reason;
5. delete the entire latest snapshot used by the cancelled reconciliation from `lor_snap`;
6. delete or invalidate the uncommitted candidate and decision working state tied to that snapshot;
7. generate and publish a cancellation report;
8. store the report path or URL and publication timestamp;
9. close the workflow.

After cancellation, the source problem is corrected and the operator starts a new LOR Production Import. The new ingest becomes the latest snapshot and begins a new reconciliation.

Cancellation is an all-or-nothing workflow outcome. A cancelled reconciliation never performs partial production promotion.

### 8. Perform Post-Write Validation

For a finished reconciliation, confirm:

- every phase used the same captured latest snapshot and reconciliation run;
- renamed or relinked displays retained their permanent `display_id`;
- stage changes retained permanent `stage_id` where required;
- new displays were created only from approved new-display candidates;
- status changes were explicitly approved and use `ref.display_status`;
- nonphysical and SPARE rows did not create `ref.display` rows;
- scene identity uses `(preview_uuid, scene_uuid)`;
- scene membership uses permanent `display_id`;
- blocked, deferred, and unresolved rows remained unchanged;
- actual committed counts match the persisted result records.

A validation failure prevents the reconciliation run from being marked complete and must be reported accurately.

### 9. Generate and Publish the Reconciliation Report

A timestamped HTML report is generated and published for both workflow outcomes:

- completed reconciliation;
- cancelled reconciliation.

#### Completed reconciliation report

The completed report must include:

```text
Production Results

  Added......................n
  Updated....................n
  Reassociated...............n
  Status Changes.............n
  Replacement Labels.........n

Operator Review

  Blocked....................n
  Deferred...................n
  Unresolved.................n
```

Every committed display-name change must appear in a replacement-label detail
section with the permanent `display_id`, old and new display names, old and new
stages, reconciliation run, and reason. Reconciliation records this required
work but does not automatically print a label.

Exact matches are excluded because no production change occurred.

The detail section must include plain-language messages and enough metadata for follow-up work. The report must describe actual committed results, not proposed changes.

#### Cancellation report

The cancellation report must include:

- reconciliation-run identity;
- deleted latest-snapshot `import_run_id`;
- operator;
- cancellation timestamp;
- cancellation reason;
- parser and ingest summary available before cancellation;
- candidate counts available before cancellation;
- confirmation that no production promotion occurred;
- confirmation that the latest snapshot was deleted.

The report path or URL and publication timestamp must be stored on the reconciliation run before the workflow is closed.

The operator interface must provide a clickable link to the published report.

## Stop Conditions Summary

Stop the workflow immediately if:

- the computer is not the verified Master PC;
- the preview set may not have been fully transferred from the previous Master PC;
- a required preview or the Master Musical Preview is missing;
- the folder contains an older, test, temporary, recovery, or unexplained preview;
- parser errors or identity collisions are unresolved;
- snapshot-ingest row counts are implausible or the ingest fails;
- structural preflight cannot safely isolate candidate groups;
- persistent reconciliation state cannot be created or retained;
- a proposed identity change cannot be tied confidently to one permanent identity and is not deferred or cancelled;
- post-write validation fails;
- report generation or publication fails.

## Required Production Interface

The operator-facing application must provide:

- one **Start LOR Production Import** action that launches the parser, protected ingest, latest-snapshot capture, and reconciliation;
- decision screens only for candidates requiring operator action;
- explicit approve and defer actions;
- one **Finish Reconciliation** action;
- one **Cancel Reconciliation** action;
- automatic promotion of passing candidates;
- blocking of deferred and unresolved candidates without blocking unrelated passing work;
- persistent candidate and decision state;
- database-enforced dependency ordering;
- post-write validation;
- timestamped HTML report generation and internal publication for completed and cancelled reconciliations;
- a clickable report link;
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

## Related Documents and Navigation

This controlled procedure is one part of a three-document set:

- **Operator procedure — this document:** `00_LOR_Production_Import_and_Reconciliation_Procedure.md`
- **Production-promotion architecture:** `01_LOR_Production_Promotion_Pipeline_Design.md`
- **Reconciliation SQL engineering design:** `reconciliation/LOR_Display_Reconciliation_SQL_Design.md`

Use the pipeline design to understand the architecture and procedure boundaries. Use the reconciliation SQL design when building or modifying the database implementation. All three documents must remain synchronized.
