# LOR Display Reconciliation SQL Design

- **Repository Path:** `Postgres_sql/Upsert Procedures/reconciliation/LOR_Display_Reconciliation_SQL_Design.md`
- **Document Type:** Database design specification
- **Status:** Design draft; not approved for production implementation
- **Owner:** MSB Database Administrator
- **Initial Release:** 2026-07-31
- **Current Revision:** 2026-08-01

## Revision History

| Date | Author | Change |
|---|---|---|
| 2026-08-01 | GAL / OpenAI | Aligned the reconciliation design with the end-to-end production workflow and promotion-pipeline design: persistent reconciliation execution context, single evaluation of the captured ingest, operator pause/resume, existing `ref.lor_scene` and `ref.lor_scene_display` production objects, committed-result reporting, and timestamped HTML publication. |
| 2026-08-01 | GAL / OpenAI | Consolidated the final reconciliation model: incremental record/group-level processing, automatic latest-completed-ingest capture, persistent stage preview/scene bindings, permanent display identity independent of assignment context, operator-controlled missing-display lifecycle handling, subprop and DMX snapshot transfer, and plain-language committed-result reporting. |
| 2026-07-31 | GAL / OpenAI | Replaced the zero-blocker production gate with deterministic automatic matching, row-level quarantine, and passed-with-exceptions promotion. |
| 2026-07-31 | GAL / OpenAI | Recast resolution choices as operator-facing business actions, added explicit renamed/rebuilt reassociation, and documented the legacy work-order UUID foreign-key dependency found during run 36 validation. |
| 2026-07-31 | GAL / OpenAI | Corrected the V7 source rule so musical-only displays enter reconciliation through Master Musical Preview scene membership, while background candidates remain preferred. |
| 2026-07-31 | GAL / OpenAI | Defined status authority, bidirectional status discrepancies, same-snapshot status correction, occurrence evidence, and classification precedence. |
| 2026-07-31 | GAL / OpenAI | Added the permanent display identity contract and validated the design against the repository schema export and current P2. |
| 2026-07-31 | GAL / OpenAI | Initial reconciliation architecture based on the V7 scene-aware snapshot ingest. |

## Status and Scope

Design draft only. No P1, P2, reconciliation object, or production database object may be changed until this design has been reviewed and approved.

This document defines the reconciliation engine: candidate construction, identity resolution, classifications, operator decisions, committed-result records, and reporting data.

The end-to-end operator procedure is defined in:

`Postgres_sql/Upsert Procedures/00_LOR_Production_Import_and_Reconciliation_Procedure.md`

The persistent promotion and orchestration architecture is defined in:

`Postgres_sql/Upsert Procedures/01_LOR_Production_Promotion_Pipeline_Design.md`

P1, P2, and P3 are phases inside that controlled workflow. They are not independent production processes.

## Purpose

Define the PostgreSQL design required to reconcile one complete LOR snapshot against permanent production stage and display identities while allowing valid independent changes to advance even when unrelated candidates contain source defects.

The design must preserve:

- `ref.stage.stage_id` as the permanent physical-stage identity.
- `ref.display.display_id` as the permanent physical-display identity.
- Persistent LOR scene identity through the existing `ref.lor_scene` object.
- Current scene membership through the existing `ref.lor_scene_display` object.
- Incremental, record/group-level reconciliation with isolated blocking.
- Complete snapshot transfer of scenes, props, subprops, and DMX channels.
- Plain-language reporting of committed changes and blocked/deferred candidates.
- `lor_snap.preview_wiring_fieldonly_v6` as the current FormView compatibility contract.

## Reconciliation Execution Context

### Latest-completed-ingest capture

Each parser run creates a complete new LOR snapshot. The reconciliation entry point must automatically select and capture the latest completed ingest once, at the beginning of execution.

The captured `import_run_id` is internal execution and audit context. It is not selected, supplied, or interpreted by a Directus user.

The entry point must:

1. Start a reconciliation run.
2. Select the latest completed ingest according to the authoritative completion state in `lor_snap.import_run`.
3. Store that `import_run_id` in the reconciliation control row.
4. Build and persist all candidate working sets from that captured ingest.
5. Pass the stored context internally through operator review, P1, P2, P3, validation, and reporting.
6. Never recalculate `max(import_run_id)` or otherwise rediscover the latest run after capture.

Lower-level procedures may accept the captured `import_run_id` and reconciliation-run identity as internal parameters from the orchestrator. They must not require an operator to enter either value and must not select the latest run independently.

A newly completed ingest that appears while reconciliation is running is ignored by that execution and becomes eligible for the next reconciliation run.

### Persistent workflow state

The reconciliation may pause for operator decisions and later resume through a different database connection. Therefore, session-local temporary tables are not the production workflow state.

The production workflow must persist:

- the captured ingest;
- stage candidates;
- display candidates;
- scene candidates;
- scene-display membership candidates;
- operator decisions;
- blocked and deferred items;
- committed results;
- validation results;
- report path and publication status.

These rows remain available until promotion, validation, report generation, and publication complete. They remain afterward as audit history unless an approved retention policy archives them.

### Single-evaluation principle

The expensive identity-resolution and classification work is performed once per reconciliation run and reused everywhere else.

P1, P2, P3, operator-review screens, post-write validation, and the final HTML report must consume the same persisted candidate rows. No downstream phase may independently rebuild a second interpretation of the captured snapshot.

## Incremental Reconciliation Model

An ingest does not have to be completely error-free before valid changes can be applied.

Every reconciliation run evaluates every candidate or inseparable logical group in the captured snapshot:

- Valid records or groups are upserted.
- Defective records or groups are blocked individually.
- Operator decisions are presented through controlled actions such as new display, rename/relink, reassociation, lifecycle status, source correction, exclusion, or defer.
- Existing production data remains unchanged for blocked or deferred records or groups.
- An error affecting one candidate must not block unrelated valid changes.
- A run-level failure is reserved for structural conditions that make safe row/group isolation impossible.
- LOR corrections require a new parse and ingest.
- PostgreSQL-only corrections or operator decisions may be re-evaluated against the same captured ingest when the source snapshot itself remains valid.
- The next complete ingest evaluates all candidates again.
- Previously blocked records pass normally once corrected.
- Previously successful records may be processed again through idempotent upserts.

The purpose of preflight is to prevent defective source data from corrupting production data, not to require a perfect ingest before anything can advance.

## Logical Group Boundaries

Some records must be evaluated and promoted together because partial application would create invalid state.

Initial inseparable logical groups are:

- One physical stage plus the preview/scene evidence being resolved for that stage.
- One physical display plus its selected identity match and its stage/preview/scene association changes.
- One scene plus its resolved physical stage.
- One scene-display membership plus its resolved scene and permanent `display_id`.
- One source prop plus its transferred subprops and DMX channel rows in the snapshot layer.
- One confirmed or inferred SPARE candidate plus the source evidence required to validate its comment.

A defect inside a group blocks that group only. It must not block independent groups unless a shared structural defect prevents deterministic isolation.

## Physical Stage Identity

`ref.stage.stage_id` is the permanent PostgreSQL identity of a physical park stage.

The following are mutable metadata and must not define permanent stage identity:

- Stage number or stage key.
- Stage name.
- Folder name.
- Preview name.
- Scene name.

A stable LOR preview or scene identity must allow a renamed or renumbered stage to retain the same `ref.stage.stage_id`.

The Stage 39-to-Stage 40 Parade Float case is the required validation example. When stable LOR evidence resolves to the existing physical stage, reconciliation must preserve `ref.stage.stage_id` while updating approved stage metadata.

## Stage and Scene Resolution

The production schema already contains the scene projection created by
`0012_create_lor_scene_production_tables.sql`:

- `ref.lor_scene`
- `ref.lor_scene_display`

No parallel `ref.stage_lor_binding` table is introduced by this design.

### Dedicated preview rule

For a standalone or background preview, the preview's canonical `StageID` is authoritative for the physical stage.

Scenes inside that dedicated preview are subordinate workspace views. Their names or numeric prefixes must not override or conflict with the dedicated preview's stage assignment.

### Shared preview rule

For the Master Musical Preview or another shared preview, the preview UUID alone cannot identify one physical stage.

The persistent scene identity is:

```text
preview_id + scene_id
```

The scene's approved effective stage evidence resolves the permanent `ref.stage.stage_id`, and `ref.lor_scene` stores that current relationship.

### Existing production scene objects

`ref.lor_scene` stores:

- persistent scene identity `(preview_uuid, scene_uuid)`;
- current mutable scene metadata;
- resolved permanent `stage_id`;
- source import audit metadata.

`ref.lor_scene_display` stores:

- current scene assignment by permanent `display_id`;
- parent `preview_uuid`;
- scene role/source/ordinal metadata;
- source import audit metadata.

Multiple scenes may resolve to the same physical stage. A scene rename does not create a new scene identity. A display move between scenes changes only the association.

## Permanent Display Identity

`ref.display.display_id` is the permanent physical-display identity and the foreign key used by production relational tables.

Display identity is independent of:

- Stage assignment.
- Preview assignment.
- Scene membership.
- Container assignment.
- Controller assignment.
- Channel assignment.

Moving a prop between scenes or moving a display between stages must not create a new physical display.

`ref.display.display_name` is mutable human-facing metadata. `ref.display.lor_prop_id` is the current LOR association, not the permanent database identity.

The underlying LOR prop UUID is stronger identity evidence than the parser's preview-qualified composite `lor_prop_id`. The preview portion is mutable assignment context and cannot define permanent display identity.

No production relational table may use an LOR prop UUID or preview-qualified composite identifier as the permanent display key.

### Display match evidence

The preflight may use the following evidence, subject to uniqueness and conflict checks:

1. Existing current LOR prop UUID association resolves uniquely to one `display_id`.
2. An identical physical display name resolves uniquely to one `display_id`.
3. Explicit audited operator reassociation identifies an existing `display_id` when both UUID and name changed.

P2 must not guess. Ambiguous evidence blocks only the affected display group.

## Confirmed Display Source Rules

Physical display reconciliation uses LOR props from the captured ingest only.

Every join across snapshot tables must include `import_run_id` plus the relevant source identifier. Joining only on `preview_id`, `prop_id`, or `scene_id` can mix historical snapshots.

The physical display name is `btrim(props.lor_comment)`.

- `props.name` is an LOR prop, channel, or wiring name and must not be used as fallback physical-display identity.
- A null, empty, or whitespace-only `props.lor_comment` does not provide a valid physical display name.
- Confirmed or inferred SPARE rows follow the separate SPARE rules below.
- Other unnamed physical candidates are blocked as source defects rather than silently inserted.

When the same physical display appears in multiple previews, those are occurrences or associations of one display, not separate physical display candidates.

## Missing Active Displays and Lifecycle Decisions

An active PostgreSQL display missing from the captured LOR snapshot must generate an operator alert.

Absence alone must not cause P2 or any automatic reconciliation procedure to infer a lifecycle decision or modify `ref.display.display_status_id`.

The operator may decide to:

- Mark the display `RETIRED`.
- Mark the display `RECYCLED`.
- Restore it to LOR if its absence was an LOR error.
- Defer the decision while preserving the existing production record.

Restoration to LOR is one possible resolution, not the default required action.

Until the operator makes a lifecycle decision, the missing display is blocked or deferred for lifecycle handling. Its existing production row remains unchanged, while unrelated valid changes may still commit.

A non-active display that appears in LOR must also generate an operator alert. Reconciliation must not automatically reactivate it or automatically require deletion from LOR.

Status meaning must be resolved through `ref.display_status`, not hard-coded numeric IDs.

## Subprops and DMX Channels

The parser output is a complete clean snapshot and rebuilds its source tables on every run.

Every ingest must transfer:

- `lor_snap.sub_props`.
- `lor_snap.dmx_channels`.

For the current design phase:

- Treat both as source-owned snapshot data.
- Validate row counts and parent relationships.
- Do not treat subprops as independent physical displays.
- Do not treat DMX channel rows as display identity.
- Do not create persistent `ref` identities for subprops or DMX channels until cross-run behavior has been studied.
- Their transfer must not alter the current P1/P2 display-reconciliation scope.

A broken parent relationship blocks that source transfer group and is reported. It does not create or delete a physical display identity.

## SPARE Handling

Confirmed and inferred SPARE rows must not be inserted into `ref.display`.

A required SPARE comment that is missing, blank, or insufficient to identify the intended spare is a blocking source defect for that SPARE group. It must be reported rather than silently omitted.

P2 must not insert, update, or delete records in `ref.spare_channel`.

Any future synchronization of `ref.spare_channel` requires a separate approved design and procedure outside P2.

## FormView Compatibility

FormView remains the current method used to obtain the field wiring view needed for park setup. The effect of LOR V7 on the standalone application still requires separate validation.

`lor_snap.preview_wiring_fieldonly_v6` remains unchanged. The `_v6` suffix is the established production object name and does not authorize replacement or removal during reconciliation work.

## Reconciliation Control, Candidate, and Audit Objects

### `ops.lor_reconciliation_run`

One persistent execution-control row per reconciliation attempt.

Required logical fields include:

- reconciliation-run identity;
- automatically captured `import_run_id`;
- status;
- start/completion timestamps;
- actor/application;
- structural failure count;
- blocked and deferred counts;
- validation state;
- report path and publication timestamp.

Directus users do not select or edit `import_run_id`.

### Persisted candidate working sets

The final implementation must persist one evaluated working set for each area:

- stage candidates;
- display candidates;
- scene candidates;
- scene-display membership candidates.

Exact table names may be finalized during DDL design, but every row must retain the reconciliation-run identity, captured `import_run_id`, source keys, proposed production identity, classification, blocking state, operator message, and resolution state.

These rows are built once and reused. They are not temporary report output.

### `ops.lor_reconciliation_action`

Append-only audit record for operator decisions that approve, resolve, correct, exclude, or defer candidates.

Initial action types include:

- `REASSOCIATE_DISPLAY`.
- `ADD_NEW_DISPLAY`.
- `RENAME_DISPLAY`.
- `UPDATE_LOR_LINK`.
- `SET_RETIRED`.
- `SET_RECYCLED`.
- `RESTORE_TO_LOR_REQUIRED`.
- `CORRECT_SOURCE_REQUIRED`.
- `DEFER`.
- `EXCLUDE_NONPHYSICAL`.

Operator actions preserve decision history. They do not convert mutable source identifiers into permanent production identities.

### `ops.lor_reconciliation_result`

Append-only result detail for actual committed outcomes, blocked candidates, deferred candidates, validation, and run completion.

A result row must retain:

- reconciliation-run identity;
- captured `import_run_id`;
- entity type and key;
- result class;
- technical reason code;
- plain-language message;
- committed flag;
- timestamp.

A proposed change that did not commit cannot be reported as `ADDED`, `UPDATED`, `REASSOCIATED`, or `STATUS_CHANGED`.

## Required Preflight Checks

Preflight runs against the captured `import_run_id` and produces one persisted classification for every candidate or logical group before promotion.

### Run-level structural checks

These conditions fail the reconciliation run because safe isolation cannot be trusted:

- Captured ingest does not exist or is not marked completed.
- Required snapshot tables for the captured run are missing or inaccessible.
- Snapshot rows cannot be scoped unambiguously by `import_run_id`.
- Required uniqueness or foreign-key structure needed to isolate candidates is absent or violated globally.
- Reconciliation control or candidate rows cannot be persisted reliably.
- Reporting or transaction control fails such that committed outcomes cannot be audited accurately.

### Stage and scene checks

- Dedicated preview stage evidence is canonical and cannot be overridden by subordinate scene text.
- Shared-preview scenes resolve by `(preview_id, scene_id)`.
- One scene identity does not resolve to multiple physical stages.
- A proposed stage update does not collide with another production stage key after normalization.
- Stage renumbering or renaming preserves `stage_id`.
- Every scene row has a valid parent preview in the same captured run.
- Scene metadata changes preserve scene identity.

### Display identity checks

- Physical display comment is present and nonblank unless handled as SPARE or approved nonphysical data.
- LOR prop UUID evidence is present where required.
- One LOR prop UUID does not resolve to multiple physical display names in the same captured snapshot.
- Production UUID and exact-name matches each resolve to no more than one `display_id`.
- UUID and name evidence do not resolve to different existing displays.
- Moving stage, preview, or scene associations does not create a new `display_id`.
- Required parent stage exists or is approved in the same execution.
- Missing active and present non-active displays are classified for operator review, not automatically changed.

### Scene membership checks

- Every membership has valid parent scene and prop rows in the same captured run.
- Membership resolves to one permanent `display_id` through the persisted display candidate mapping.
- One display has no more than one current scene within a preview.
- Membership changes are association changes, not identity changes.
- Blocked or deferred displays do not receive unsafe membership changes.

### Subprop and DMX checks

- Source row counts are recorded for the captured run.
- Every subprop and DMX row has a valid parent prop in the same captured run.
- Parent-child checks use `import_run_id` plus source identifiers.
- Duplicate source keys or malformed channel ranges are classified and reported.

### SPARE checks

- Confirmed and inferred SPARE rows are excluded from `ref.display` candidates.
- Required SPARE comments are present and usable.
- Missing required comments block the SPARE group and produce an operator-readable message.
- No P2 operation targets `ref.spare_channel`.

## Result Classifications

### Production results

| Class | Meaning |
|---|---|
| `ADDED` | A new production identity or association committed. |
| `UPDATED` | Existing production metadata committed with a changed value. |
| `REASSOCIATED` | Existing permanent identity committed to a different current stage/scene/source association. |
| `STATUS_CHANGED` | Explicit operator-approved lifecycle status committed. |

Exact matches are not included in the change report because no production change occurred.

### Operator review

| Class | Meaning |
|---|---|
| `BLOCKED` | A source or identity defect prevented this candidate/group from changing production. Existing production data remained unchanged. |
| `DEFERRED` | An operator deliberately postponed the decision. Existing production data remained unchanged. |

### Run failure

| Class | Meaning |
|---|---|
| `FAILED` | A structural or transaction failure prevented trustworthy safe execution. |

Technical reason codes support filtering and cleanup workflows. Every candidate must also carry a plain-language operator message.

## Plain-Language HTML Run Report

Every reconciliation execution must produce a timestamped HTML report and publish it to the internal web server.

The report is generated from persisted committed-result, blocked, and deferred rows. It must not rerun the comparison after promotion.

Required high-level sections include:

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

Exact matches are excluded from those sections.

Detailed messages must describe actual outcomes, for example:

- `ADDED: Display "Parade Float Trailer" added to Stage 40.`
- `UPDATED: Display "Tree 7" name corrected while preserving display_id 412.`
- `REASSOCIATED: Display "Welcome Sign" moved to scene "Entrance View".`
- `STATUS CHANGED: Display "PVC Igloo 2" changed from ACTIVE to RECYCLED.`
- `BLOCKED: Display "Tree 7" was not added because required inventory information is missing.`
- `DEFERRED: Missing display "Arch 5" remains unchanged until the operator determines its lifecycle state.`

The report must preserve enough metadata to create follow-up cleanup work orders.

## Promotion Semantics

1. Start the reconciliation workflow and automatically capture the latest completed ingest.
2. Build and persist all candidate working sets once.
3. Pause only when operator decisions are required.
4. Apply valid and approved stage changes.
5. Apply valid and approved display changes.
6. Apply valid and approved scene changes.
7. Apply valid and approved scene-display associations.
8. Validate committed production state.
9. Persist actual results.
10. Generate and publish the HTML report.
11. Mark the reconciliation run complete.

A valid snapshot remains historical evidence even when some candidates are blocked or deferred. Reconciliation must never delete or roll back the completed ingest merely because candidate-level defects were found.

## Conflict With Current P1 and P2

Current production and repository procedures must be reviewed only after this design is approved.

Required future changes include:

- P1 and P2 must consume the internally captured run and persisted candidate rows.
- P1 must preserve permanent `stage_id` and apply only approved stage/scene results.
- P2 must preserve permanent `display_id` across assignment changes.
- P2 must process valid display groups even when unrelated groups are blocked.
- P2 must not infer lifecycle changes from absence.
- P2 must not write `ref.spare_channel`.
- Neither procedure may independently select the latest ingest or rebuild its own identity analysis.

No P1 or P2 code change is authorized by this document revision alone.

## Work-Order Identity Boundary

`ops.work_order` may reference a display only through `display_id -> ref.display.display_id` and a stage only through `stage_id -> ref.stage.stage_id`.

LOR prop UUIDs, preview UUIDs, scene UUIDs, and preview-qualified composite identifiers are source-system metadata. They must not be used as permanent work-order foreign keys.

Any legacy work-order UUID dependency must be migrated separately after UUID-only rows are safely mapped to permanent identities.

## Required Implementation Order After Design Approval

1. Confirm this design against current production table definitions, constraints, status values, and ingest completion semantics.
2. Define persistent reconciliation-run, candidate, action, result, validation, and report-publication objects.
3. Implement automatic latest-completed-ingest capture.
4. Convert the current read-only preflight logic into candidate builders that run once per reconciliation execution.
5. Validate candidate classifications against the current V7 snapshot.
6. Revise P1 to consume approved stage/scene candidates.
7. Revise P2 to consume approved display candidates.
8. Implement P3 using `ref.lor_scene` and `ref.lor_scene_display`.
9. Implement post-write validation and timestamped HTML report publication.
10. Test the complete workflow against a disposable or restored database before production use.

## Immediate Validation Needed Before Executable DDL

Confirm from the live production database and current importer:

- Exact `lor_snap.import_run` completion columns and authoritative completed-ingest definition.
- Current columns, constraints, indexes, and triggers on `ref.stage`, `ref.display`, `ref.lor_scene`, and `ref.lor_scene_display`.
- Current P1 and P2 definitions installed in production.
- Actual preview, scene, prop, subprop, and DMX uniqueness constraints in `lor_snap`.
- Actual names and IDs in `ref.display_status`.
- Whether any production UUID or display name currently maps to multiple identities.
- Current actor/audit trigger requirements for new `ops` objects.
- Any legacy work-order columns or foreign keys that still reference LOR UUIDs.
- The exact source rule used by the V7 ingest to distinguish completed, failed, and partial imports.
