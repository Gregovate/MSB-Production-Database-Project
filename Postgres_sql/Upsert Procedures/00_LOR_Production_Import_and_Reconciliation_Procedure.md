# LOR Production Import and Reconciliation Procedure

| Document control | Value |
|---|---|
| Repository path | `Postgres_sql/Upsert Procedures/00_LOR_Production_Import_and_Reconciliation_Procedure.md` |
| Document type | Controlled production procedure |
| Status | ACTIVE — manual reconciliation validated; operator application deployment remains pending |
| Owner / author | GAL |
| Initial release | 2026-07-31 |
| Current revision | 2026-08-05 |

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
| 2026-08-05 | GAL / OpenAI | Implemented the secured preflight backend, restricted operator authorization, persisted-decision endpoints, final-review concurrency check, Cancel, and retry-safe Finish/report publication. Deployment and Run 4 acceptance remain pending. |
| 2026-08-04 | GAL / OpenAI | Activated the validated manual workflow, linked the executable runbook, and updated implementation status through report publication and evaluation/index support. |
| 2026-08-03 | GAL / OpenAI | Corrected reconciliation exception counters and report problems to use current effective logical-group state; frozen blocking flags remain audit evidence after operator resolution and are not reported as current exceptions. |
| 2026-08-03 | GAL / OpenAI | Added the no-op production-write contract: evaluated-but-unchanged rows must not be updated, their audit fields must remain intact, and they must not appear as report changes. |
| 2026-08-03 | GAL / OpenAI | Defined the operator-facing reconciliation report contract, including the internal NAS publication folder, report access, immutable timestamped filenames, source-preview manifest, completed/cancelled status, readable change tables, reason codes, replacement-label instructions, and failure handling. |
| 2026-08-03 | GAL / OpenAI | Recorded installed and rollback-validated P1/stage-preservation layers and added the repository implementation plus rollback validation for reconciliation-safe P2. Reconciliation Run 1 remains development state and is prohibited from production promotion. |
| 2026-08-02 | GAL / OpenAI | Implemented the repository DDL for persistent stage-to-LOR bindings, frozen stage candidates/groups, unified reconciliation start, and reconciliation-gated P1. Installation and rollback validation remain required before any production stage promotion. |
| 2026-08-02 | GAL / OpenAI | Implemented the repository DDL for the persistent reconciliation run, frozen display candidates, generic logical groups, append-only group decisions, atomic reassociation assignments, and operator review views. Production installation and live validation remain required; the UI and promotion procedures remain unimplemented. |
| 2026-08-02 | GAL / OpenAI | Added the replacement-label report requirement for committed display-name changes; reconciliation records label work but does not print automatically. |
| 2026-08-02 | GAL / OpenAI | Defined the complete single-interface workflow: start import, run parser and protected ingest, automatically begin reconciliation, collect decisions, promote all passing candidates, block deferred or unresolved candidates, support finish or cancel, and generate a report in both cases. |
| 2026-08-01 | GAL / OpenAI | Defined the finished single-workflow operator experience, automatic latest-ingest capture, persistent reconciliation state, operator pause/resume, finish reconciliation, post-write validation, and timestamped HTML report publication. |
| 2026-07-31 | GAL / OpenAI | Revised the gate to promote independently safe records, quarantine only affected exceptions, and process stage/scene context before displays and scene assignments. |
| 2026-07-31 | GAL / OpenAI | Linked the full P1/P2/P3 promotion design and established controlled orchestration as the required final production execution model. |
| 2026-07-31 | GAL | Initial procedure draft. Documents authoritative-preview controls, V7 parsing, PostgreSQL ingest, reconciliation requirements, and the P1/P2/P3 gate. |

## Current Manual Workflow and Future Operator Interface

The active executable procedure is:

`Postgres_sql/Upsert Procedures/02_LOR_Manual_Reconciliation_Runbook.md`

It contains the exact SQL and PowerShell commands, decision templates, result checks, production-write warning, publication sequence, and recovery rules. Until the application interface exists, it is the authoritative execution sequence.

The application workflow described below remains the intended replacement for those manual commands. It must call the same installed boundaries and preserve the same safeguards.

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
| Master PC and preview-folder controls | Procedure defined; parser/ingest blocking checks active; complete operator application remains pending |
| `parse_props_v7_scene_parser.py` | Implemented and production exercised through V7.0.7 |
| `postgres_run_ingest_v7.ps1` | Implemented and tested |
| Latest-ingest capture and frozen preflight | Installed and production validated; manual operation documented in `02_LOR_Manual_Reconciliation_Runbook.md` |
| Persistent reconciliation-run and display-candidate tables | Installed and live-validated from `reconciliation/0014_create_lor_reconciliation_decision_layer.sql` on 2026-08-02 |
| Persistent stage candidate and binding tables | Installed from `0015` and rollback-validated by `11`; multi-preview metadata preservation installed from `0016` and rollback-validated by `12` |
| Persistent scene and scene-membership candidate tables | Installed from `0018` and rollback-validated by `14` |
| Operator decision database contract | Installed and live-validated for append-only group decisions, atomic reassociation assignments, `DEFER`, and review views on 2026-08-02; application interface remains pending |
| Operator decision application interface | Designed; not implemented |
| Finish and cancel workflow actions | Installed from `0019`, rollback-validated by `15`, and Finish production-validated through Run 3; `0026`/`22` counter correction installed and passed |
| P1 | Installed, rollback-validated, and executed only through controlled Finish |
| P2 | Installed from `0017` and rollback-validated by `13`; legacy procedure remains prohibited |
| P3/P4 | Installed from `0018` and rollback-validated by `14`; these remain internal engine phases |
| Controlled manual workflow | Active and documented in `02_LOR_Manual_Reconciliation_Runbook.md` |
| Controlled single-interface application | Designed; not implemented |
| Timestamped HTML report publication | Installed and production validated; immutable publication, evaluation copies, and generated report index are implemented |

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
- Access to the SQL client and report publisher required by the active manual runbook.

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

### 3. Run the Current Manual Procedure

Until the operator application exists, follow the complete sequence in:

`Postgres_sql/Upsert Procedures/02_LOR_Manual_Reconciliation_Runbook.md`

Do not reconstruct commands from this policy overview or run P1–P4 directly.

### 3A. Future Start LOR Production Import Interface

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

### 4. Future Automatic Start Reconciliation

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

#### Unchanged-record contract

Reconciliation may evaluate a production record without changing it. Evaluation alone is never authority to issue an `UPDATE`.

For every existing production row, the promotion phase must compare only the business fields it is authorized to maintain. Null-safe comparisons must use `IS DISTINCT FROM` or equivalent logic. An `UPDATE` is permitted only when at least one authorized business field will actually change.

If all authorized business fields are unchanged:

- no `UPDATE` statement may be issued for that row;
- `updated_at`, `updated_by`, and `updated_by_person_id` must retain their existing values;
- existing `created_*` audit values must retain their existing values;
- no production result may classify the row as changed;
- the row must not appear in a final-report change table.

A reconciliation run that evaluates every display, stage, scene, or membership must therefore update only the subset with real approved changes. Post-write validation must fail if an unchanged row receives new audit values or a reported change result.


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

#### Secured preflight screen pending deployment

The reusable operator screen is published under:

`https://my.sheboyganlights.org/lor2db/preflight/?run={reconciliation_run_id}`

It presents each persisted preflight check and its frozen evidence on the left,
with **Accept**, **Change**, and **Defer** controls on the same line. Accept is
available only when the engine proposes one unambiguous production action.
Every saved selection is recorded through the installed append-only decision
functions by a same-origin authenticated backend; browser state is never the
record of authority.

After all required decisions are recorded, **Continue** opens a final review of
only accepted or changed-and-approved production actions. Deferred items are
excluded. **Back to Review** returns without writing production. **Proceed**
requires a second confirmation and is the only screen action that may invoke
Finish. **Cancel Reconciliation** also requires confirmation and a reason and
never invokes Finish.

The browser template and implemented backend live in `tools/lor_preflight/`.
Until that backend is deployed and validated with Run 4, use the manual SQL
runbook.

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

A reconciliation remains in `REPORTING` until its report is generated, published, and linked to the reconciliation run. Report generation failure does not falsely mark the run complete or cancelled.

#### Report location and operator access

Reports are published as immutable, timestamped HTML files in:

```text
\\192.168.5.4\web\my\lor2db\reports
```

The `reconciliation-reports` folder must be created before the reporting layer is placed in service.

The normal operator opens the report from the clickable report link in Directus. An administrator may open the same file through Windows File Explorer at the NAS path above. A published report is an audit record and must not be overwritten. If regeneration is required after a publication failure, the publisher creates a new file and records the final published path.

The filename must contain the reconciliation completion or cancellation timestamp and the reconciliation-run identity. The exact filename pattern will be finalized with the publisher implementation.

#### Required source manifest

Every completed or cancelled report must identify exactly what source material produced the snapshot:

- source preview-folder name and captured path;
- preview filename;
- LOR preview name;
- preview revision;
- parser execution timestamp;
- captured `import_run_id` and reconciliation-run identity.

The scene-aware parser currently stores preview name and revision in SQLite, but it does not persist the selected source folder or original filename as reconciliation audit metadata. The preview merger's manifest is not available because that merger does not run during reconciliation.

Therefore the production workflow must be corrected before report implementation:

1. the parser records the selected source-folder evidence and one manifest row for every parsed `.lorprev` file;
2. the ingest transfers that manifest into the captured snapshot;
3. reconciliation freezes the manifest in reconciliation-owned audit rows before Finish or Cancel;
4. report publication reads the frozen audit copy, not live source files and not snapshot rows that cancellation may delete.

#### Status shown to the operator

The report must show one of these user-facing statuses prominently:

- **Completed** — all eligible work committed and no exceptions remain;
- **Completed with Exceptions** — eligible work committed while deferred, blocked, or unresolved items remained unchanged;
- **Canceled** — no production promotion occurred and the captured snapshot was removed.

#### Completed or completed-with-exceptions report

The report begins with a concise run summary and then uses readable tables. Every change or follow-up row includes a technical reason code and a plain-language reason.

Required sections are:

1. **Display Name Changes**
   - permanent `display_id`;
   - before display name;
   - after display name;
   - before and after stage when applicable;
   - reason code and plain-language reason;
   - operator instruction: **Print replacement label**.

2. **Other Display Changes**
   - new displays, lifecycle/status changes, and other committed user-visible display changes;
   - before and after values where applicable;
   - reason code and plain-language reason.

3. **Stage Changes**
   - permanent `stage_id`;
   - before and after user-visible stage values;
   - reason code and plain-language reason.

4. **Scene Changes**
   - preview and scene names;
   - before and after user-visible scene or stage assignment values;
   - membership additions and removals summarized clearly;
   - reason code and plain-language reason.

5. **Items Deferred for Further Investigation**
   - deferred, blocked, and unresolved items that remained unchanged;
   - entity type and user-visible identity;
   - required follow-up;
   - reason code and plain-language reason.

6. **Validation Results**
   - post-write validation outcome and relevant counts.

Exact matches are excluded because no production change occurred. Backend-only LOR UUID/link changes are not shown to operators and must not appear as a report change.

The report describes actual committed results only. Proposed changes that did not commit belong only in the follow-up table.

#### Cancellation report

A cancelled report includes:

- prominent **Canceled** status;
- reconciliation-run identity and captured `import_run_id`;
- operator, cancellation timestamp, and cancellation reason;
- frozen source manifest;
- candidate counts available before cancellation;
- confirmation that no production promotion occurred;
- confirmation that the captured snapshot was deleted;
- deleted row counts by snapshot table;
- validation/audit result.

Cancellation report generation must not depend on the deleted `lor_snap` rows.

#### Terminal transition

After successful publication, the publisher stores the immutable file path, clickable URL, publication timestamp, and final report result. It then changes:

- a successful Finish run from `REPORTING` to `COMPLETED` or `COMPLETED_WITH_EXCEPTIONS`; or
- a successful Cancel run from `REPORTING` to `CANCELLED`.

If generation, filesystem publication, link storage, or final transition fails, the run remains `REPORTING` with a recorded failure. The operator must be able to retry publication without rerunning P1-P4 or cancellation.

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

This controlled procedure is one part of the controlled documentation set:

- **Production policy — this document:** `00_LOR_Production_Import_and_Reconciliation_Procedure.md`
- **Executable manual runbook:** `02_LOR_Manual_Reconciliation_Runbook.md`
- **Production-promotion architecture:** `01_LOR_Production_Promotion_Pipeline_Design.md`
- **Reconciliation SQL engineering design:** `reconciliation/LOR_Display_Reconciliation_SQL_Design.md`

Use the pipeline design to understand the architecture and procedure boundaries. Use the reconciliation SQL design when building or modifying the database implementation. All three documents must remain synchronized.
