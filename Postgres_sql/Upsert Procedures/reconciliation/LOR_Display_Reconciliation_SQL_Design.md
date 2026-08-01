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
| 2026-08-01 | GAL / OpenAI | Consolidated the final reconciliation model: incremental record/group-level processing, automatic latest-completed-ingest capture, persistent stage preview/scene bindings, permanent display identity independent of assignment context, operator-controlled missing-display lifecycle handling, subprop and DMX snapshot transfer, and plain-language committed-result reporting. |
| 2026-07-31 | GAL / OpenAI | Replaced the zero-blocker production gate with deterministic automatic matching, row-level quarantine, and passed-with-exceptions promotion. |
| 2026-07-31 | GAL / OpenAI | Recast resolution choices as operator-facing business actions, added explicit renamed/rebuilt reassociation, and documented the legacy work-order UUID foreign-key dependency found during run 36 validation. |
| 2026-07-31 | GAL / OpenAI | Corrected the V7 source rule so musical-only displays enter reconciliation through Master Musical Preview scene membership, while background candidates remain preferred. |
| 2026-07-31 | GAL / OpenAI | Defined status authority, bidirectional status discrepancies, same-snapshot status correction, occurrence evidence, and classification precedence. |
| 2026-07-31 | GAL / OpenAI | Added the permanent display identity contract and validated the design against the repository schema export and current P2. |
| 2026-07-31 | GAL / OpenAI | Initial reconciliation architecture based on the V7 scene-aware snapshot ingest. |

## Status and Scope

Design draft only. No P1, P2, reconciliation object, or production database object may be changed until this design has been reviewed and approved.

This document defines the intended reconciliation behavior and the preflight/result classifications required before implementation. It does not authorize production DDL or procedure changes.

## Purpose

Define the PostgreSQL design required to reconcile one complete LOR snapshot against permanent production stage and display identities while allowing valid independent changes to advance even when unrelated candidates contain source defects.

The design must preserve:

- `ref.stage.stage_id` as the permanent physical-stage identity.
- `ref.display.display_id` as the permanent physical-display identity.
- Stable LOR preview and scene bindings without making mutable names or stage numbers part of identity.
- Incremental, record/group-level reconciliation with isolated blocking.
- Complete snapshot transfer of scenes, props, subprops, and DMX channels.
- Plain-language reporting of committed changes and blocked candidates.
- `lor_snap.preview_wiring_fieldonly_v6` as the current FormView compatibility contract.

## Reconciliation Execution Context

### Latest-completed-ingest capture

Each parser run creates a complete new LOR snapshot. The reconciliation entry point must automatically select and capture the latest completed ingest once, at the beginning of execution.

The captured `import_run_id` is internal execution and audit context. It is not selected, supplied, or interpreted by a Directus user.

The entry point must:

1. Start a reconciliation run.
2. Select the latest completed ingest according to the authoritative completion state in `lor_snap.import_run`.
3. Store that `import_run_id` in the reconciliation control row.
4. Pass that stored value internally through preflight, P1, P2, promotion, validation, and reporting.
5. Never recalculate `max(import_run_id)` or otherwise rediscover the latest run after capture.

Lower-level procedures may accept the captured `import_run_id` as an internal parameter from the orchestrator. They must not require an operator to enter it and must not select it independently.

A newly completed ingest that appears while reconciliation is running is ignored by that execution and becomes eligible for the next reconciliation run.

## Incremental Reconciliation Model

An ingest does not have to be completely error-free before valid changes can be applied.

Every reconciliation run re-evaluates every candidate or inseparable logical group in the captured snapshot:

- Valid records or groups are upserted.
- Defective records or groups are blocked individually.
- Existing production data remains unchanged for blocked records or groups.
- An error affecting one candidate must not block unrelated valid changes.
- A run-level failure is reserved for structural conditions that make safe row/group isolation impossible.
- Corrections are made in LOR or the importer.
- A new complete parse and ingest is created.
- The next reconciliation evaluates all candidates again.
- Previously blocked records pass normally once corrected.
- Previously successful records may be processed again through idempotent upserts.

The purpose of preflight is to prevent defective source data from corrupting production data, not to require a perfect ingest before anything can advance.

## Logical Group Boundaries

Some records must be evaluated and promoted together because partial application would create invalid state.

Initial inseparable logical groups are:

- One physical stage plus all LOR preview/scene bindings being resolved for that stage during the run.
- One physical display plus its selected identity match and its stage/preview/scene association changes.
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

The Stage 39-to-Stage 40 Parade Float case is the required validation example. When the stable LOR binding resolves to the existing physical stage, reconciliation must preserve `ref.stage.stage_id` while updating the stage key and descriptive metadata.

## Stage-to-LOR Bindings

PostgreSQL requires a persistent stage-to-LOR binding structure. The proposed object is `ref.stage_lor_binding`.

### Binding identity rules

- Standalone or background preview binding: `preview_id` identifies the persistent LOR binding.
- Scene binding inside a shared preview: `preview_id + scene_id` identifies the persistent LOR binding.
- Preview name and scene name are mutable metadata.
- Multiple preview or scene bindings may resolve to the same physical stage.
- A Master Musical Preview `preview_id` alone cannot identify one physical stage.
- A scene in a shared preview must never be resolved by scene name alone.

### Proposed `ref.stage_lor_binding`

| Column | Type | Purpose |
|---|---|---|
| `stage_lor_binding_id` | bigint identity PK | Permanent binding row identity |
| `stage_id` | bigint FK | Permanent physical stage identity |
| `preview_id` | text not null | Stable LOR preview UUID |
| `scene_id` | text nullable | Stable LOR scene UUID; null for preview-level binding |
| `preview_name` | text nullable | Current mutable preview name |
| `scene_name` | text nullable | Current mutable scene name |
| `active_flag` | boolean not null | Current binding state |
| audit columns | timestamps/operator/run | Creation and change history |

Required uniqueness:

- One active preview-level binding per `preview_id` where `scene_id is null`.
- One active scene binding per `(preview_id, scene_id)` where `scene_id is not null`.

P1 must resolve the physical stage and upsert its binding rows together as one logical group. It must not update stage metadata while leaving the corresponding binding unresolved or contradictory.

## Scene Identity and Membership

A scene is an LOR workspace/view representation, not itself a physical park location.

- `preview_id + scene_id` identifies the persistent LOR scene.
- Scene name is mutable metadata.
- Prop-to-scene membership is mutable assignment context.
- A display can move between scenes within the same preview without changing display identity.
- Scene membership and physical-stage assignment must be synchronized as associations, not embedded in display identity.

The Master Musical Preview may contain many scenes that resolve through separate bindings to different physical stages. Its preview UUID alone provides shared preview context only.

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

`ref.display.display_name` is mutable human-facing metadata. `ref.display.lor_prop_id` is the current LOR prop UUID association, not the permanent database identity.

The underlying LOR prop UUID is stronger identity evidence than the parser's preview-qualified composite `lor_prop_id`. The preview portion is mutable assignment context and cannot define permanent display identity.

No production relational table may use an LOR prop UUID or preview-qualified composite identifier as the permanent display key.

### Display match evidence

The preflight may use the following evidence in descending order of strength, subject to uniqueness and conflict checks:

1. Existing current LOR prop UUID association resolves uniquely to one `display_id`.
2. Unique normalized physical display name resolves to one `display_id`.
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

Background or standalone previews provide preview-level stage context through their persistent preview bindings.

Props in the Master Musical Preview obtain stage context through scene membership and the matching `(preview_id, scene_id)` stage binding. The Master Musical Preview `preview_id` alone cannot assign a stage.

When the same physical display appears in both a background preview and the Master Musical Preview, those are occurrences or associations of one display, not separate physical display candidates.

## Missing Active Displays and Lifecycle Decisions

An active PostgreSQL display missing from the captured LOR snapshot must generate an operator alert.

Absence alone must not cause P2 or any automatic reconciliation procedure to infer a lifecycle decision or modify `ref.display.display_status_id`.

The operator may decide to:

- Mark the display `RETIRED`.
- Mark the display `RECYCLED`.
- Restore it to LOR if its absence was an LOR error.
- Defer the decision while preserving the existing production record.

Restoration to LOR is one possible resolution, not the default required action.

Until the operator makes a lifecycle decision, the missing display is classified as blocked or deferred for lifecycle handling. Its existing production row remains unchanged, while unrelated valid changes may still commit.

A non-active display that appears in LOR must also generate an operator alert. Reconciliation must not automatically reactivate it or automatically require deletion from LOR. The operator determines whether the PostgreSQL status is wrong, the LOR occurrence is wrong, or the decision should be deferred.

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

A source prop and its subprop/DMX snapshot rows form one transfer group for structural validation. A broken parent relationship blocks that transfer group and is reported. It does not create or delete a physical display identity.

## SPARE Handling

Confirmed and inferred SPARE rows must not be inserted into `ref.display`.

A required SPARE comment that is missing, blank, or insufficient to identify the intended spare is a blocking source defect for that SPARE group. It must be reported rather than silently omitted.

P2 must not insert, update, or delete records in `ref.spare_channel`.

Any future synchronization of `ref.spare_channel` requires a separate approved design and procedure outside P2.

## FormView Compatibility

FormView remains the current method used to obtain the field wiring view needed for park setup. The effect of LOR V7 on the standalone application still requires separate validation.

`lor_snap.preview_wiring_fieldonly_v6` remains unchanged. The `_v6` suffix is the established production object name and does not authorize replacement or removal during reconciliation work.

## Reconciliation Control and Audit Objects

### `ops.lor_reconciliation_run`

One execution-control row per reconciliation attempt.

| Column | Type | Purpose |
|---|---|---|
| `lor_reconciliation_run_id` | bigint identity PK | Reconciliation execution identity |
| `import_run_id` | bigint FK | Automatically captured latest completed ingest |
| `status` | text | `RUNNING`, `COMPLETED`, `COMPLETED_WITH_BLOCKS`, or `FAILED` |
| `started_at` | timestamptz | Execution start |
| `completed_at` | timestamptz nullable | Execution end |
| `structural_failure_count` | integer | Run-level unsafe failures |
| `blocked_group_count` | integer | Isolated blocked candidates/groups |
| audit columns | actor/application | Execution origin |

The control row is created by the reconciliation entry point. Directus users do not select or edit `import_run_id`.

### `ops.lor_reconciliation_result`

Append-only result detail for actual execution outcomes.

| Column | Type | Purpose |
|---|---|---|
| `lor_reconciliation_result_id` | bigint identity PK | Result row identity |
| `lor_reconciliation_run_id` | bigint FK | Reconciliation execution |
| `import_run_id` | bigint FK | Captured snapshot context |
| `entity_type` | text | `STAGE`, `STAGE_BINDING`, `DISPLAY`, `DISPLAY_ASSOCIATION`, `SUBPROP_TRANSFER`, `DMX_TRANSFER`, `SPARE`, or `RUN` |
| `entity_key` | text nullable | Human-readable or source key |
| `result_class` | text | `ADDED`, `UPDATED`, `UNCHANGED`, `BLOCKED`, `DEFERRED`, or `FAILED` |
| `reason_code` | text nullable | Controlled technical classification |
| `message` | text not null | Plain-language committed result or blocker description |
| `committed_flag` | boolean not null | Whether the described production/snapshot mutation committed |
| `created_at` | timestamptz | Result time |

Result rows must describe what actually committed. A proposed change that did not commit cannot be reported as `ADDED` or `UPDATED`.

### `ops.lor_reconciliation_action`

Append-only audit record for operator decisions that resolve or defer blocked candidates.

Initial action types include:

- `REASSOCIATE_STAGE_BINDING`.
- `REASSOCIATE_DISPLAY`.
- `SET_RETIRED`.
- `SET_RECYCLED`.
- `RESTORE_TO_LOR_REQUIRED`.
- `CORRECT_SOURCE_REQUIRED`.
- `DEFER`.
- `EXCLUDE_NONPHYSICAL`.

Operator actions preserve decision history. They do not convert mutable source identifiers into permanent production identities.

## Required Preflight Checks

Preflight runs against the captured `import_run_id` and produces a classification for every candidate or logical group before promotion.

### Run-level structural checks

These conditions fail the reconciliation run because safe isolation cannot be trusted:

- Captured ingest does not exist or is not marked completed.
- Required snapshot tables for the captured run are missing or inaccessible.
- Snapshot rows cannot be scoped unambiguously by `import_run_id`.
- Required uniqueness or foreign-key structure needed to isolate candidates is absent or violated globally.
- Reconciliation control cannot persist the captured run context.
- Reporting or transaction control fails such that committed outcomes cannot be audited accurately.

### Stage and binding checks

For each stage logical group:

- Preview-level binding uses a nonblank stable `preview_id`.
- Scene binding uses nonblank `preview_id` and `scene_id`.
- A shared preview is not treated as one physical stage without scene context.
- One binding identity does not resolve to multiple physical stages.
- One proposed stage update does not collide with another production stage key after normalization.
- Renumbering or renaming through an existing stable binding preserves `ref.stage.stage_id`.
- New stage candidates have sufficient canonical metadata for insertion.
- All bindings assigned to the group can be committed together.

### Display identity checks

For each display logical group:

- Physical display comment is present and nonblank unless the row is handled as SPARE or approved nonphysical data.
- LOR prop UUID evidence is present where required.
- One LOR prop UUID does not resolve to multiple physical display names in the same captured snapshot.
- One normalized physical display name does not resolve to multiple LOR prop UUIDs without explicit occurrence evidence showing the same physical prop.
- Production UUID and normalized-name matches each resolve to no more than one `display_id`.
- UUID and name evidence do not resolve to different existing displays.
- Moving stage, preview, or scene associations does not create a new `display_id`.
- Required stage binding exists or is being promoted in the same safe execution before the display association is written.
- A missing active production display is classified for operator lifecycle handling, not automatically changed.
- A non-active display found in LOR is classified for operator review, not automatically reactivated.

### Scene and association checks

- Every scene row has a valid parent preview in the same captured run.
- Every scene membership has valid parent scene and prop rows in the same captured run.
- `(preview_id, scene_id)` is used for scene identity.
- Scene name changes update metadata without changing scene identity.
- Membership changes are treated as association updates.
- One membership does not assign the same occurrence to contradictory physical stages through conflicting bindings.

### Subprop and DMX transfer checks

- Source row counts are recorded for the captured run.
- Every subprop has a valid parent prop in the same captured run.
- Every DMX channel row has a valid parent prop in the same captured run.
- Parent-child checks use `import_run_id` plus source identifiers.
- Duplicate source keys or malformed channel ranges are classified and reported.
- Transfer failures do not create persistent `ref` identities.

### SPARE checks

- Confirmed and inferred SPARE rows are excluded from `ref.display` candidates.
- Required SPARE comments are present and usable.
- Missing required comments block the SPARE group and produce an operator-readable message.
- No P2 operation targets `ref.spare_channel`.

## Result Classifications

### Committed result classes

| Class | Meaning |
|---|---|
| `ADDED` | A new production identity, binding, or association was committed. |
| `UPDATED` | Existing production metadata, binding, or association changed and committed. |
| `UNCHANGED` | Candidate was valid and idempotent processing found no production change. |

### Non-committed result classes

| Class | Meaning |
|---|---|
| `BLOCKED` | A source or identity defect prevented this candidate/group from changing production. Existing production data remained unchanged. |
| `DEFERRED` | An operator deliberately postponed the decision. Existing production data remained unchanged. |
| `FAILED` | A structural or transaction failure prevented trustworthy safe execution. |

### Required technical reason codes

Initial reason codes must include at least:

- `EXACT_MATCH`.
- `STAGE_METADATA_CHANGED`.
- `STAGE_BINDING_ADDED`.
- `STAGE_BINDING_UPDATED`.
- `STAGE_BINDING_CONFLICT`.
- `DISPLAY_NAME_CHANGED_SAME_UUID`.
- `DISPLAY_UUID_CHANGED_SAME_NAME`.
- `DISPLAY_REASSOCIATION_REQUIRED`.
- `NEW_DISPLAY`.
- `DISPLAY_ASSOCIATION_CHANGED`.
- `ACTIVE_DISPLAY_MISSING_FROM_LOR`.
- `NONACTIVE_DISPLAY_PRESENT_IN_LOR`.
- `DUPLICATE_LOR_UUID`.
- `DUPLICATE_LOR_NAME`.
- `DUPLICATE_PRODUCTION_UUID`.
- `DUPLICATE_PRODUCTION_NAME`.
- `CONFLICTING_IDENTITY_EVIDENCE`.
- `MISSING_DISPLAY_COMMENT`.
- `MISSING_STAGE_BINDING`.
- `SCENE_PARENT_MISSING`.
- `SCENE_MEMBERSHIP_PARENT_MISSING`.
- `SUBPROP_PARENT_MISSING`.
- `DMX_PARENT_MISSING`.
- `DMX_CHANNEL_RANGE_INVALID`.
- `SPARE_EXCLUDED`.
- `SPARE_COMMENT_MISSING`.
- `OPERATOR_DEFERRED`.
- `STRUCTURAL_FAILURE`.

A technical reason code supports filtering and cleanup workflows. The accompanying message must remain understandable without database expertise.

## Plain-Language Run Report

Every reconciliation execution must produce a simple report of committed results and blocked candidates.

Examples:

- `ADDED: Display "Parade Float Trailer" added to Stage 40.`
- `ADDED: Inventory item "Power Supply A" added to the database.`
- `UPDATED: Stage 10 added scene "Wiring View".`
- `BLOCKED: Display "Tree 7" was not added because required inventory item "Controller B" is missing.`
- `BLOCKED: Active display "Snowman 3" is missing from LOR. Production status was not changed.`
- `DEFERRED: Missing display "Arch 5" remains active until the operator decides whether it was retired, recycled, or omitted from LOR.`
- `SUMMARY: 3 added, 2 updated, 547 unchanged, 2 blocked, 0 deferred.`

The summary counts must be calculated from persisted result rows after all candidate transactions finish.

The report must not label a proposed or rolled-back mutation as committed. Blocked and deferred rows must state that existing production data was preserved when that fact matters to the operator.

The report output must support follow-up cleanup work orders by preserving entity type, entity key, reason code, and message.

## Promotion Semantics

1. The reconciliation entry point automatically captures the latest completed ingest.
2. Preflight classifies all candidate groups for that captured run.
3. Run-level structural failure stops promotion and reports `FAILED`.
4. Valid stage groups and stage bindings are promoted first.
5. Valid display identity groups are promoted next.
6. Valid scene and display-association changes are promoted after their parent stage/display identities exist.
7. Subprop and DMX snapshot transfers are validated and recorded without creating persistent physical identities.
8. Each candidate/group is committed atomically and independently where safe.
9. Blocked or deferred candidates remain unchanged in production.
10. The final report is generated from actual persisted outcomes.

A valid snapshot remains historical evidence even when some candidates are blocked. Reconciliation must never delete or roll back the completed ingest merely because candidate-level defects were found.

## Conflict With Current P1 and P2

Current production and repository procedures must be reviewed only after this design is approved.

Required future changes include:

- P1 must use the internally captured run context supplied by the orchestrator.
- P1 must resolve physical stages through persistent preview/scene bindings and upsert each stage plus its bindings as one logical group.
- P2 must use the internally captured run context supplied by the orchestrator.
- P2 must preserve permanent `display_id` across stage, preview, scene, controller, container, and channel changes.
- P2 must process valid display groups even when unrelated groups are blocked.
- P2 must not infer lifecycle changes from absence.
- P2 must not write `ref.spare_channel`.
- Neither procedure may independently select the latest ingest.

No P1 or P2 code change is authorized by this document revision alone.

## Work-Order Identity Boundary

`ops.work_order` may reference a display only through `display_id -> ref.display.display_id` and a stage only through `stage_id -> ref.stage.stage_id`.

LOR prop UUIDs, preview UUIDs, scene UUIDs, and preview-qualified composite identifiers are source-system metadata. They must not be used as permanent work-order foreign keys.

Any legacy work-order UUID dependency must be migrated separately after UUID-only rows are safely mapped to permanent identities.

## Required Implementation Order After Design Approval

1. Confirm this design against current production table definitions, constraints, status values, and ingest completion semantics.
2. Define the reconciliation entry point and automatic latest-completed-ingest capture transaction.
3. Implement read-only preflight views/functions and validate classifications against a captured V7 snapshot.
4. Implement `ref.stage_lor_binding` and test Stage 39-to-40 identity preservation in a disposable database.
5. Implement reconciliation run, result, and action audit objects.
6. Implement stage-group promotion with rollback tests.
7. Implement display-group promotion with rollback tests.
8. Implement scene and membership association synchronization.
9. Validate subprop and DMX snapshot transfer checks and reporting.
10. Implement plain-language report generation from committed result rows.
11. Revise P1 and P2 only after the preceding objects and tests are approved.
12. Test the complete workflow against a disposable or restored database before production use.

## Immediate Validation Needed Before Executable DDL

Confirm from the live production database and current importer:

- Exact `lor_snap.import_run` completion columns and the authoritative definition of a completed ingest.
- Current columns, constraints, indexes, and triggers on `ref.stage` and `ref.display`.
- Current P1 and P2 definitions installed in production.
- Existing persistent stage-to-preview or stage-to-scene mapping objects, if any.
- Actual preview, scene, prop, subprop, and DMX uniqueness constraints in `lor_snap`.
- Actual names and IDs in `ref.display_status`.
- Whether any production UUID or normalized display name currently maps to multiple identities.
- Current actor/audit trigger requirements for new `ops` and `ref` objects.
- Any legacy work-order columns or foreign keys that still reference LOR UUIDs.
- The exact source rule used by the V7 ingest to distinguish completed, failed, and partial imports.
