# LOR Display Reconciliation SQL Design

- **Repository Path:** `Postgres_sql/Upsert Procedures/reconciliation/LOR_Display_Reconciliation_SQL_Design.md`
- **Document Type:** Database design specification
- **Status:** Approved design under implementation; P1-P4 and Finish/Cancel installed and rollback-validated; reporting layer pending
- **Owner:** MSB Database Administrator
- **Initial Release:** 2026-07-31
- **Current Revision:** 2026-08-03

## Revision History

| Date | Author | Change |
|---|---|---|
| 2026-08-03 | GAL / OpenAI | Corrected the attempt lifecycle: every Start creates an independent evaluation, an interrupted review attempt is frozen and reported as `SUPERSEDED` instead of blocking later work, multiple attempts may evaluate the same ingest, prior decisions are history only, and normal Finish requires deliberate terminal outcomes for every decision-required group. |
| 2026-08-03 | GAL / OpenAI | Defined reconciliation-owned source-manifest evidence and the operator-facing HTML report contract: NAS publication folder, immutable timestamped files, completed/cancelled statuses, readable change and exception tables, reason codes, replacement-label instruction, UUID suppression, and retry-safe terminal publication. |
| 2026-08-03 | GAL / OpenAI | Made no-op suppression part of the production-write contract: authorized business fields require null-safe comparison, unchanged rows retain all audit values, and validation/reporting must reject false changes. |
| 2026-08-03 | GAL / OpenAI | Added `0019` atomic Finish/Cancel lifecycle and rollback validation `15`. Finish executes and validates P1/P3/P2/P4 before advancing to `REPORTING`; Cancel records its audit and atomically removes the captured snapshot before advancing to `REPORTING`. Terminal status remains gated by report publication. |
| 2026-08-03 | GAL / OpenAI | Added `0018` frozen scene and scene-membership candidates, reconciliation-safe P3/P4 current-state promotion, guarded obsolete-row removal, and rollback validation `14`. Installation and database validation remain pending; Run 1 must not be promoted. |
| 2026-08-03 | GAL / OpenAI | Recorded installed and rollback-validated `0015`/`0016` stage layers and added reconciliation-safe P2 migration `0017` with rollback validation `13`. Run 1 is development state and must not be promoted. |
| 2026-08-02 | GAL / OpenAI | Implemented `0015` and validation query `11`: persistent stage-to-LOR bindings, frozen stage candidates and atomic groups, unified reconciliation start, exact captured-source revalidation, and reconciliation-gated P1. No P1 production write has been authorized or executed. |
| 2026-08-02 | GAL / OpenAI | Implemented the persistent display-decision foundation in `0014`: reconciliation-run capture, frozen display candidates, generic connected identity groups, append-only group actions, complete reassociation mappings, result storage, and Directus-ready review views. Added validation query `10`; no promotion writes are enabled. |
| 2026-08-02 | GAL / OpenAI | Removed `color` from reconciliation authority because RGB props legitimately supply no single color; added committed display-name changes to the replacement-label report contract. |
| 2026-08-02 | GAL / OpenAI | Corrected the preflight candidate interface after the production raw-ID migration: every display candidate now retains scoped `source_prop_id` for exact captured-row revalidation while `lor_prop_id` carries only the preview-independent `raw_prop_id` proposed for `ref.display`. |
| 2026-08-02 | GAL / OpenAI | Recorded completion of the one-time production `ref.display.lor_prop_id` migration using ingest Run 42: all 1,050 rows now store instance-qualified `raw_prop_id`; zero preview prefixes, blanks, duplicates, or ACTIVE identities missing from the captured ingest remained after commit. Marked the legacy P2 source as incompatible and non-runnable pending the reconciliation engine prerequisites. |
| 2026-08-02 | GAL / OpenAI | Documented the verified moved-display stale-UUID failure found in ingest Run 41 and cleared in Run 42: renamed or hidden vacated channels remain parseable and may retain the moved display's PropClass UUID. Added the mandatory cross-name/cross-preview `raw_prop_id` collision check and source-correction requirement. |
| 2026-08-02 | GAL / OpenAI | Corrected the LOR identity mapping: preview-scoped `prop_id` identifies the exact captured occurrence, while unscoped `raw_prop_id` is the LOR association stored in `ref.display.lor_prop_id` and remains independent of preview movement. |
| 2026-08-02 | GAL / OpenAI | Added the mandatory P2 defense-in-depth check against raw `lor_snap.props.lor_comment`: null, empty, and whitespace-only comments are never valid display names and must be rejected before every `ref.display` insert or update, even if parser or reconciliation filtering fails upstream. Automatic SPARE, PHANTOM, and blank-comment exclusions remain out of the operator report unless production already violates the rule. |
| 2026-08-02 | GAL / OpenAI | Defined the complete reconciliation engine required by the approved operator procedure and promotion architecture: one-interface start, automatic latest-snapshot capture, P1/P2/P3/P4 boundaries, Finish and Cancel behavior, SPARE and PHANTOM exclusion, exact `ref.display` write authority, read-only 01-09 scripts, completed/cancelled reporting, and controlled snapshot retention management. |
| 2026-08-01 | GAL / OpenAI | Aligned the reconciliation design with the end-to-end production workflow and promotion-pipeline design: persistent reconciliation execution context, single evaluation of the captured ingest, operator pause/resume, existing `ref.lor_scene` and `ref.lor_scene_display` production objects, committed-result reporting, and timestamped HTML publication. |
| 2026-08-01 | GAL / OpenAI | Consolidated the final reconciliation model: incremental record/group-level processing, automatic latest-completed-ingest capture, persistent stage preview/scene bindings, permanent display identity independent of assignment context, operator-controlled missing-display lifecycle handling, subprop and DMX snapshot transfer, and plain-language committed-result reporting. |
| 2026-07-31 | GAL / OpenAI | Replaced the zero-blocker production gate with deterministic automatic matching, row-level quarantine, and passed-with-exceptions promotion. |
| 2026-07-31 | GAL / OpenAI | Recast resolution choices as operator-facing business actions, added explicit renamed/rebuilt reassociation, and documented the legacy work-order UUID foreign-key dependency found during run 36 validation. |
| 2026-07-31 | GAL / OpenAI | Corrected the V7 source rule so musical-only displays enter reconciliation through Master Musical Preview scene membership, while background candidates remain preferred. |
| 2026-07-31 | GAL / OpenAI | Defined status authority, bidirectional status discrepancies, same-snapshot status correction, occurrence evidence, and classification precedence. |
| 2026-07-31 | GAL / OpenAI | Added the permanent display identity contract and validated the design against the repository schema export and current P2. |
| 2026-07-31 | GAL / OpenAI | Initial reconciliation architecture based on the V7 scene-aware snapshot ingest. |

## Status and Scope

This document defines the SQL-engine implementation contract for the V7 production import and reconciliation workflow.

It defines:

- reconciliation-run creation and state transitions;
- latest-snapshot capture;
- persisted candidate construction;
- identity resolution and classifications;
- operator decisions, including defer and cancel;
- P1, P2, P3, and P4 promotion boundaries;
- committed-result and validation records;
- completed and cancelled reports;
- controlled deletion of old `lor_snap` snapshots.

It does not replace the operator procedure or the production-promotion architecture.

The operator procedure is:

`Postgres_sql/Upsert Procedures/00_LOR_Production_Import_and_Reconciliation_Procedure.md`

The production-promotion architecture is:

`Postgres_sql/Upsert Procedures/01_LOR_Production_Promotion_Pipeline_Design.md`

The three documents define one workflow and must remain synchronized.

## Purpose

Define the PostgreSQL engine required to reconcile the latest completed LOR snapshot against permanent production identities, apply all safe and approved changes, isolate blocked and deferred candidates, support cancellation, and produce a complete published report.

The design must preserve:

- `ref.stage.stage_id` as the permanent physical-stage identity;
- `ref.display.display_id` as the permanent physical-display identity;
- persistent scene identity in `ref.lor_scene`;
- current scene membership in `ref.lor_scene_display`;
- complete source snapshots in `lor_snap` while retained;
- record- and group-level isolation;
- exact production-column ownership;
- complete auditability of decisions and committed outcomes.

## End-to-End Engine Entry

The operator-facing interface provides one **Start LOR Production Import** action.

That action invokes the secured external runner, which performs:

```text
Start LOR Production Import
    -> run V7 scene-aware parser
    -> validate parser completion
    -> run password-protected PostgreSQL ingest
    -> create latest completed snapshot
    -> call reconciliation start entry point
```

The database does not run the parser executable directly. The secured runner calls the database only after parser and ingest success.

The reconciliation start entry point shall:

1. acquire the reconciliation start lock;
2. identify the latest completed `lor_snap.import_run`;
3. create one persistent reconciliation-run row;
4. store the captured `import_run_id`;
5. build all candidate working sets once;
6. run structural checks and classifications;
7. continue automatically if no decisions are required;
8. otherwise move the run to operator review.

The operator never selects or enters an `import_run_id`.

Every Start request creates a new reconciliation attempt, even when another
attempt evaluated the same captured ingest. Before the new attempt is built,
any interrupted review-stage attempt is frozen and closed as `SUPERSEDED`.
Its undecided groups are reported as incomplete at supersession; they are not
silently converted to `DEFER` or inherited by the new attempt.

## Reconciliation Run State Model

The implementation shall support at least these logical states:

- `STARTING`
- `PARSING`
- `INGESTING`
- `PREFLIGHT`
- `AWAITING_DECISIONS`
- `PROMOTING`
- `VALIDATING`
- `REPORTING`
- `COMPLETED`
- `COMPLETED_WITH_EXCEPTIONS`
- `CANCELLED`
- `SUPERSEDED`
- `FAILED`

Exact stored values may be finalized during DDL implementation, but every state transition must be explicit, auditable, and valid only from an allowed prior state.

## Latest Snapshot Capture and Lifecycle

Each successful ingest creates a complete snapshot identified by `import_run_id`.

At reconciliation start, the engine captures the latest completed snapshot once. That captured run remains fixed through candidate construction, decisions, promotion, validation, and reporting.

A later ingest does not alter an already-running reconciliation. It becomes the latest snapshot for the next reconciliation.

An unfinished review attempt never blocks a later Start. The later attempt
reevaluates the latest completed ingest against production as it exists at that
time. A previously deferred, rejected, or undecided issue disappears when the
source or production correction resolves it and appears again when it remains.
Prior actions remain visible as audit history but have no decision authority in
the later attempt. Repeated attempts against unchanged source and production
must produce the same candidate classifications.

Snapshot rows are immutable while retained. Corrections create a new ingest; existing snapshot rows are not edited to represent corrected source data.

Snapshots exist primarily to support:

- reconciliation of the latest LOR state;
- latest-versus-previous diff reporting;
- recent parser and ingest troubleshooting.

`lor_snap` is not the permanent business-history archive. Permanent history is maintained through reconciliation actions, committed results, validation records, and published reports.

## Persistent Reconciliation Objects

### `ops.lor_reconciliation_run`

One row per reconciliation attempt.

Required logical fields include:

- reconciliation-run identity;
- captured `import_run_id`;
- status;
- started, paused, resumed, completed, cancelled, and failed timestamps as applicable;
- actor and application identity;
- structural failure count;
- blocked, deferred, and unresolved counts;
- validation state;
- report path, URL, and publication timestamp;
- cancellation reason when applicable.
- supersession timestamp, reason, and later reconciliation-run identity when
  an interrupted attempt is replaced.

### Persisted Candidate Working Sets

The engine shall persist separate evaluated candidate sets for:

- stage candidates;
- display candidates;
- scene candidates;
- scene-display membership candidates.

Every candidate row must retain:

- reconciliation-run identity;
- captured `import_run_id`;
- source keys;
- source evidence;
- proposed production identity;
- classification;
- blocking state;
- operator message;
- required decision type;
- resolution state;
- approved action, when present.

Display candidates must retain both identity layers without conflating them:

- `source_prop_id` is the preview-scoped `lor_snap.props.prop_id` of the exact
  canonical captured source occurrence used for write-time revalidation; and
- `lor_prop_id` is the complete instance-qualified `raw_prop_id` proposed as
  the current `ref.display.lor_prop_id` association.

Candidate sets are built once and reused by operator review, P1-P4, validation, and reporting.

### `ops.lor_reconciliation_action`

Append-only operator-decision record.

Initial candidate-level action types include:

- `RENAME_DISPLAY`
- `UPDATE_LOR_LINK`
- `REASSOCIATE_DISPLAY`
- `ADD_NEW_DISPLAY`
- `SET_RETIRED`
- `SET_RECYCLED`
- `RESTORE_TO_LOR_REQUIRED`
- `CORRECT_SOURCE_REQUIRED`
- `EXCLUDE_NONPHYSICAL`
- `DEFER`

`CANCEL_RECONCILIATION` is a run-level action, not a display-candidate action.

### `ops.lor_reconciliation_result`

Append-only result detail for:

- committed production outcomes;
- blocked candidates;
- deferred candidates;
- unresolved required decisions;
- validation outcomes;
- cancellation outcomes;
- report publication.

A result row must retain the reconciliation run, captured ingest, entity type/key, result class, reason code, plain-language message, committed flag, and timestamp.

A proposed change that did not commit must never be reported as `ADDED`, `UPDATED`, `REASSOCIATED`, or `STATUS_CHANGED`.

## Single-Evaluation Principle

The reconciliation engine evaluates the captured snapshot once per reconciliation run.

No downstream phase may:

- select `max(import_run_id)`;
- rediscover the latest run;
- rebuild an independent identity interpretation;
- bypass persisted decisions;
- infer a write from fresh comparison logic during promotion.

P1-P4, validation, and reporting consume the persisted reconciliation rows.

## Incremental Reconciliation Model

Every candidate or inseparable logical group is evaluated independently.

- Passing candidates advance automatically.
- Approved decisions advance.
- Blocked candidates remain unchanged in production.
- Deferred candidates remain unchanged in production.
- Every decision-required group must have a deliberate terminal operator
  outcome before **Finish Reconciliation** may begin promotion.
- Blocked, rejected, and deferred outcomes do not prevent unrelated passing
  candidates from promotion after every required decision is terminal.
- Run-level failure is reserved for structural conditions that prevent safe isolation or trustworthy auditing.

The operator ends review by selecting either:

- **Finish Reconciliation**, or
- **Cancel Reconciliation**.

## Finish Reconciliation

When **Finish Reconciliation** is selected, the engine shall:

1. reopen the same reconciliation run;
2. verify the captured ingest and persisted candidates;
3. reject Finish if any decision-required group lacks a terminal outcome;
4. preserve every blocked, rejected, or deferred production row unchanged;
5. execute all passing and approved work in dependency order;
6. run post-write validation;
7. persist actual results;
8. generate and publish the HTML report;
9. mark the run `COMPLETED` or `COMPLETED_WITH_EXCEPTIONS`.

The atomic database Finish entry point performs steps 1-7 and advances the
run to `REPORTING`. Only the report publisher may perform steps 8-9 and assign
a terminal completed status.

## Cancel Reconciliation

When **Cancel Reconciliation** is selected, the engine shall:

1. stop before any production promotion;
2. record the cancellation actor, timestamp, and reason;
3. confirm that no P1-P4 production writes committed;
4. delete the entire captured latest snapshot from `lor_snap` as one unit;
5. delete all child snapshot rows belonging to that `import_run_id`;
6. retain the reconciliation control, action, and result audit records;
7. generate and publish a cancelled-run HTML report;
8. mark the reconciliation run `CANCELLED`.

The atomic database Cancel entry point performs steps 1-6 and advances the run
to `REPORTING` with `cancelled_at` and the cancellation reason populated. Only
the report publisher may perform steps 7-8 and assign terminal `CANCELLED`.

Cancellation must never partially delete a snapshot and must never cascade into `ref`, `ops`, or other production data.

After cancellation, the source problem is corrected and a new parser/ingest run creates the next latest snapshot.

## Logical Group Boundaries

Initial inseparable logical groups are:

- one physical stage plus its selected preview/scene evidence;
- one physical display plus its selected identity and assignment evidence;
- one scene plus its resolved stage;
- one scene-display membership plus its scene and permanent `display_id`;
- one source prop plus its source-owned subprops and DMX rows;
- one SPARE, PHANTOM, or unnamed-source candidate plus the evidence required to classify it.

A defect blocks only its group unless a shared structural defect prevents deterministic isolation.

## Physical Stage Identity

`ref.stage.stage_id` is permanent.

Stage key, stage number, stage name, folder name, preview name, and scene name are mutable metadata and must not define permanent stage identity.

The Stage 39-to-Stage 40 Parade Float case is the required validation example: stable source evidence must preserve `stage_id` while approved mutable metadata changes.

## Stage and Scene Resolution

### Dedicated Preview Rule

For a standalone or background preview, the preview's canonical `StageID` is authoritative for the physical stage.

Subordinate scenes do not override the dedicated preview's stage.

### Shared Preview Rule

For the Master Musical Preview or another shared preview, stage context is resolved from scene evidence.

Persistent scene identity is:

```text
preview_id + scene_id
```

The effective scene stage resolves to the permanent production `stage_id`.

### Production Scene Objects

`ref.lor_scene` stores current persistent scene identity and resolved stage.

`ref.lor_scene_display` stores current scene membership by permanent `display_id`.

A scene rename does not create a new scene identity. A display move changes an association, not display identity.

## Permanent Display Identity

`ref.display.display_id` is permanent and is the only production relational identity for a physical display.

Display identity is independent of stage, preview, scene, container, controller, network, and channel assignment.

`ref.display.display_name` is mutable human-facing metadata.

`ref.display.lor_prop_id` is the current LOR association and is not a permanent relational key.

### Production Identity Migration Baseline

The one-time production identity migration was completed and independently
verified against captured ingest Run 42 on 2026-08-02.

- all 1,050 `ref.display` rows were preserved;
- every preview-scoped `preview_id:` prefix was removed;
- every stored value is now the complete instance-qualified `raw_prop_id`;
- no blank or duplicate `lor_prop_id` values remained; and
- no ACTIVE production identity was missing from Run 42.

Four Run 42 absences were already-RECYCLED displays
`PB-PVCIgloo-01` through `PB-PVCIgloo-04`; they retained their permanent
`display_id` and historical `lor_prop_id` values and required no lifecycle
change.

The pre-migration P2 source is therefore incompatible with the live identity
contract and must not be installed or executed. Its replacement must follow
the implementation order in this design and consume only persisted,
operator-approved reconciliation actions.

No production relational table may use a prop UUID, preview UUID, scene UUID, or preview-qualified composite identifier as the permanent display foreign key.

## Confirmed Display Source Rules

Physical display reconciliation uses LOR props from the captured ingest only.

Every snapshot join must include `import_run_id` plus the relevant source identifier.

The physical display name is:

```text
btrim(lor_snap.props.lor_comment)
```

`props.name` is not a fallback physical-display identity.

The engine must classify source rows by the raw captured `lor_snap.props.lor_comment`, not only by a normalized downstream view.

A null, empty, or whitespace-only `lor_comment`:

- does not provide a valid physical display name;
- is classified as `INVALID_UNNAMED_SOURCE` or an equivalent nonphysical exclusion;
- never creates a display candidate requiring operator review;
- never creates or updates `ref.display`;
- remains out of the reconciliation report when the rule is being followed;
- becomes a blocking production defect only if that raw source row is already associated with an existing `ref.display` row.

## SPARE, PHANTOM, Blank Comment, and Nonphysical Exclusion

SPARE, PHANTOM, null/blank-comment props, and other confirmed nonphysical helpers must never create or update a row in `ref.display`.

The display candidate classification shall distinguish at least:

- `PHYSICAL_DISPLAY`
- `SPARE`
- `PHANTOM`
- `NONPHYSICAL_HELPER`
- `INVALID_UNNAMED_SOURCE`

Only `PHYSICAL_DISPLAY` candidates are eligible for P2.

P2 must reject any SPARE, PHANTOM, NONPHYSICAL, `INVALID_UNNAMED_SOURCE`, or otherwise unconfirmed physical candidate.

No insert, update, UUID relink, rename, stage change, metadata change, or lifecycle change may target `ref.display` for those classifications.

These automatic rule-following exclusions are not operator decisions and do not belong in the reconciliation report. Only a violation already present in production is reported.

P2 must not insert, update, or delete `ref.spare_channel`. Any future spare-channel synchronization requires a separate approved design.

## Exact P2 Write Authority

`lor_snap.props` and `ref.display` are not matching schemas.

For an existing `ref.display` row, ordinary approved LOR promotion may modify only these mapped fields:

| Source evidence | `ref.display` target |
|---|---|
| `lor_snap.props.raw_prop_id` / approved current LOR association | `lor_prop_id` |
| `btrim(lor_snap.props.lor_comment)` | `display_name` |
| approved effective stage resolved from preview/scene evidence | `stage_id` |
| `lor_snap.props.string_type` | `string_type` |

`ref.display.color` is production-maintained metadata and is not reconciled
from LOR. RGB props legitimately have no single LOR color, so a null source
color must never clear or replace the production value.

Before every insert or update, P2 must independently re-read the raw captured prop row by both `import_run_id` and `prop_id` and enforce:

```sql
NULLIF(btrim(lor_snap.props.lor_comment), '') IS NOT NULL
```

This is a final database write guard, not a replacement for parser or reconciliation filtering. A candidate that fails this assertion is rejected even if its persisted classification incorrectly marked it as physical.

`lor_snap.props.prop_id` is the preview-scoped snapshot occurrence key used to
re-read that exact captured row. It is not written to `ref.display.lor_prop_id`.
The unscoped `lor_snap.props.raw_prop_id` is the LOR identity evidence stored as
the current `ref.display.lor_prop_id` association. Moving a prop between
previews must not change its LOR identity merely because its scoped `prop_id`
changes.

### Moved-Display Stale UUID Hazard

Moving a physical display to a different preview or controller does not by
itself remove the display's former LOR identity from the vacated channels.
Renaming an old channel to `SPARE` or hiding it is not sufficient. Hidden
channels are still present in the preview data and remain eligible for parser
extraction.

This failure was verified during the 2026 reconciliation preflight:

- `IT-Olaf` was moved from Stage 13 Winter Wonderland controller `3E`,
  channels `01-05`, to Stage 14 Icicle Tunnel controller `3F`, channels
  `11-15`;
- the former `WW 3E-01` channel was renamed `SPARE` and hidden but retained
  Olaf's original PropClass UUID;
- the parser uses the lowest channel as the identity source when constructing
  the multi-channel prop, so the stale UUID caused `SPARE` and `IT-Olaf` to
  share one `raw_prop_id` in ingest Run 41;
- deleting and recreating `WW 3E-01`, then ingesting the corrected preview as
  Run 42, removed the collision.

Therefore, when a display is moved:

1. the obsolete prop/channel definition at the former assignment must be
   deleted;
2. any vacated channel that must remain documented as a spare must be recreated
   as a new visible SPARE channel so it receives a new LOR identity;
3. merely renaming or hiding the former channel is prohibited;
4. reconciliation preflight must detect a `raw_prop_id` associated with more
   than one distinct nonblank `lor_comment` or with conflicting preview
   evidence;
5. any collision blocks the affected identity group and requires source-preview
   correction followed by a new parser run and ingest. Reconciliation must not
   guess which name or preview owns the UUID.

The operator check is mandatory because the second occurrence may represent
another physical display, not only a SPARE channel.

P2 must never derive `display_name` from `props.name` or another fallback column.

`display_status_id` may change only through an explicit lifecycle decision.

All other production- or Directus-maintained fields must remain unchanged, including:

- `display_id`;
- `inventory_type`;
- `designer_id`;
- `theme_id`;
- `frame_id`;
- `container_id`;
- `year_built`;
- `amps_measured`;
- `est_light_count`;
- `dumb_controller`;
- `notes`;
- `label_required`;
- `created_at` and `created_by`;
- `created_by_person_id`;
- `updated_by_person_id`.

### No-op suppression and audit-field preservation

Candidate evaluation is not a production write. P1-P4 must not issue an `UPDATE` merely because an existing row participated in reconciliation, matched a candidate, or was approved.

Each promotion statement must:

1. compare only the business fields that phase is authorized to maintain;
2. use null-safe `IS DISTINCT FROM` comparisons, or an exactly equivalent predicate;
3. execute an `UPDATE` only when at least one authorized business field will receive a different value;
4. leave `created_at`, `created_by`, and `created_by_person_id` unchanged on every update;
5. leave `updated_at`, `updated_by`, and `updated_by_person_id` unchanged when no authorized business value changes;
6. allow the established actor/audit mechanism to update the `updated_*` fields only for a row receiving a real approved business change;
7. persist a production result only for an actual insert, update, reassociation, status change, or authorized deletion.

The rule applies to stages, displays, scenes, and scene-display memberships. Same-run idempotency means the second execution produces the same projected result set but performs no additional production writes and causes no audit-field churn.

Rollback and post-write validation must compare pre-write and post-write business values and audit fields. Validation fails if an unchanged production row has different `updated_*` values, if a no-op is persisted as a production change, or if a no-op appears in a final-report change table.

Wiring, controller, network, and channel data are not authorized P2 writes to `ref.display` under this design.

## Missing and Nonactive Display Lifecycle Decisions

An active production display missing from the captured snapshot requires operator review.

Absence alone must not change status.

Allowed outcomes include:

- `RETIRED`;
- `RECYCLED`;
- restore to LOR;
- defer.

A nonactive production display appearing in LOR also requires review. It must not be automatically reactivated.

Status meaning is resolved through `ref.display_status`, not hard-coded IDs.

## P1-P4 Promotion Phases

The reconciliation engine produces four internal promotion phases.

### P1 — Stage Promotion

Consumes approved stage candidates and writes `ref.stage`.

P1 preserves existing `stage_id`, applies only approved mutable metadata, does not delete physical stages, and does not assign displays.

### P2 — Display Promotion

Consumes only approved or automatically passing `PHYSICAL_DISPLAY` candidates and writes `ref.display` within the exact write-authority contract above.

P2 preserves `display_id`, does not guess identity, does not process SPARE, PHANTOM, blank-comment, or other nonphysical candidates, and does not write `ref.spare_channel`.

Immediately before each write, P2 revalidates the raw captured prop and rejects a null, empty, or whitespace-only `lor_comment`. This assertion is mandatory even when the persisted candidate passed upstream checks.

### P3 — Scene Definition Promotion

Consumes approved scene candidates and writes `ref.lor_scene`.

P3 preserves persistent `(preview_uuid, scene_uuid)` identity, resolves the approved `stage_id`, updates current scene metadata, and may remove obsolete/empty current scene projections only when the authoritative candidate set makes that removal safe.

### P4 — Scene-Display Membership Promotion

Consumes approved membership candidates and writes `ref.lor_scene_display`.

P4 requires both:

- a resolved production scene from P3; and
- a permanent production `display_id` from P2.

P4 never creates display identity. It synchronizes current membership and may remove obsolete assignments only when safe and approved by the candidate set.

### Required Dependency Order

```text
P1 — stages
    -> P3 — scene definitions
    -> P2 — displays
    -> P4 — scene-display memberships
    -> post-write validation
    -> report publication
```

P1-P4 are internal engine phases. Operators do not run them directly.

## Read-Only Development Scripts 01-09

The existing reconciliation scripts `01` through `09` are development preflight and validation scripts.

They may:

- `SELECT` from `lor_snap`, `ref`, `ops`, and PostgreSQL catalog metadata;
- return result grids;
- validate projected classifications and writes.

They may not:

- `INSERT`;
- `UPDATE`;
- `DELETE`;
- call P1, P2, P3, P4, or another write procedure;
- create production decisions;
- alter production state.

Production candidate builders shall be new controlled database objects implementing the validated logic. Write behavior must never be hidden inside scripts 01-09.

Script `09_current_p2_projected_write_validation.sql` must inspect raw `lor_snap.props.lor_comment` directly. It must not rely solely on `lor_snap.v_display_reconciliation_source` or another normalized view that may already omit invalid unnamed rows.

## Required Preflight Checks

### Run-Level Structural Checks

Run-level failure occurs when safe isolation or trustworthy auditing cannot be guaranteed, including:

- captured ingest missing or incomplete;
- required snapshot tables inaccessible;
- rows not safely scoped by `import_run_id`;
- global uniqueness or relationship failures preventing deterministic candidate isolation;
- reconciliation state not persistable;
- report or transaction controls unable to record committed truth.

### Stage and Scene Checks

- dedicated preview stage evidence is canonical;
- shared-preview scenes resolve by `(preview_id, scene_id)`;
- one scene does not resolve to multiple stages;
- stage metadata changes preserve `stage_id`;
- scene metadata changes preserve scene identity;
- scene parent rows exist in the same captured run.

### Display Checks

- raw `lor_snap.props.lor_comment` is inspected directly;
- physical display comment is present and usable;
- null, empty, and whitespace-only comments are excluded before candidate promotion;
- no fallback to `props.name` is permitted;
- production UUID and exact-name evidence resolve uniquely;
- UUID and name evidence do not resolve to different displays;
- one `raw_prop_id` is not associated with multiple distinct nonblank display
  comments or conflicting preview occurrences;
- hidden rows are included in identity-collision checks because hidden LOR
  channels remain parseable source objects;
- a moved display's vacated channels do not retain the display's former UUID;
- stage/preview/scene movement does not create a new display identity;
- parent stage exists or is approved in the same run;
- missing active and present nonactive displays require review;
- SPARE, PHANTOM, blank-comment, and nonphysical candidates are excluded from P2;
- excluded rows appear in the operator report only when an existing production association violates the rule;
- P2 independently repeats the raw-comment and nonphysical checks before writing.

### Membership Checks

- parent scene and prop rows exist in the captured run;
- membership resolves through permanent `display_id`;
- blocked or deferred displays do not receive unsafe assignment changes;
- membership changes are association changes only.

### Subprop and DMX Checks

Subprops and DMX channels remain source-owned snapshot data.

- row counts are recorded;
- parent prop relationships are validated within the same `import_run_id`;
- they are not physical display identities;
- they do not create independent `ref` identities under this design.

## Result Classifications

### Production Results

- `ADDED`
- `UPDATED`
- `REASSOCIATED`
- `STATUS_CHANGED`

Exact matches are excluded because no production change occurred.

### Operator Review Results

- `BLOCKED`
- `DEFERRED`
- `UNRESOLVED`

### Run Results

- `COMPLETED`
- `COMPLETED_WITH_EXCEPTIONS`
- `CANCELLED`
- `FAILED`

Every result includes a technical reason code and plain-language operator message.

## Reconciliation Source Manifest

Reporting cannot depend on the preview merger because reconciliation does not run it. The scene-aware parser already captures preview name and revision in SQLite, but the current parser/ingest contract does not preserve the selected preview-folder path or original preview filename as reconciliation-owned audit evidence.

The reporting implementation therefore requires:

- parser-run metadata containing the selected source-folder path and folder name;
- one parser manifest row per parsed `.lorprev` file;
- original preview filename, parsed preview name, preview revision, preview identity, and parser timestamp;
- ingest transfer of that metadata into `lor_snap`, scoped by `import_run_id`;
- a frozen reconciliation-owned manifest copied at reconciliation start or before any cancellation deletion;
- immutable use of that frozen manifest by both completed and cancelled reports.

The report publisher must not inspect the live preview folder after reconciliation. It must not reconstruct the manifest from whatever files happen to exist later. A cancelled run deletes its captured snapshot before report publication, so the frozen reconciliation-owned copy is mandatory.

## HTML Report Contract

Every reconciliation attempt produces one immutable, timestamped HTML report.

### Publication location

The internal NAS publication folder is:

```text
\\192.168.5.4\web\my\committees\production\reconciliation-reports
```

The `reconciliation-reports` folder must be created before deployment. Normal operators open the published URL from Directus. Administrators may open the same report through the NAS path.

A filename contains at least the terminal-event timestamp and reconciliation-run identity. Publication never overwrites an existing audit report. The publisher stores the final file path, clickable URL, and publication timestamp on the reconciliation run.

### Data authority

The report is generated from:

- frozen source-manifest audit rows;
- persisted reconciliation actions;
- actual committed results;
- deferred, blocked, and unresolved exception results;
- post-write validation results;
- cancellation and snapshot-deletion audit results.
- supersession lineage plus incomplete-at-supersession results.

The publisher does not rerun reconciliation or recompute identity decisions. Proposed changes that did not commit are never reported as committed changes.

Automatic rule-following exclusions do not belong in the report. SPARE, PHANTOM, blank-comment, and confirmed nonphysical helper rows are omitted unless they expose an existing production defect.

Backend-only LOR UUID/link changes are not user-facing changes and must not be mentioned in the operator report.

### User-facing status

The report shows one of these statuses prominently:

- **Completed**
- **Completed with Exceptions**
- **Canceled**
- **Superseded**

`Completed with Exceptions` applies whenever valid work committed while deferred, blocked, or unresolved items remained unchanged.

`Superseded` applies when a later Start closes an interrupted review attempt.
Its report distinguishes deliberate deferrals and rejected changes from groups
that were still undecided when superseded. No superseded result is described as
a committed production change.

### Required report header

Both completed and cancelled reports include:

- user-facing final status;
- reconciliation-run identity and captured `import_run_id`;
- operator and relevant timestamps;
- source preview-folder name and captured path;
- preview filename, preview name, and revision for every parsed preview;
- parser/ingest summary counts.

### Completed report tables

Completed and completed-with-exceptions reports contain these simple, readable tables:

1. **Display Name Changes**
   - permanent `display_id`;
   - before and after display name;
   - before and after stage where applicable;
   - technical reason code and plain-language reason;
   - fixed instruction: **Preprint replacement label**.

2. **Other Display Changes**
   - new displays and user-visible status/lifecycle changes;
   - before and after values where applicable;
   - technical reason code and plain-language reason.

3. **Stage Changes**
   - permanent `stage_id`;
   - before and after user-visible values;
   - technical reason code and plain-language reason.

4. **Scene Changes**
   - preview and scene names;
   - before and after scene metadata or stage assignment;
   - readable membership additions/removals;
   - technical reason code and plain-language reason.

5. **Items Deferred for Further Investigation**
   - deferred, blocked, and unresolved items;
   - user-visible identity and entity type;
   - required follow-up;
   - technical reason code and plain-language reason.

6. **Validation Results**
   - post-write validation state and relevant counts.

Exact matches are excluded. Every production table reports actual committed outcomes, while noncommitted proposals appear only in the follow-up table.

### Cancelled report

A cancelled report includes:

- **Canceled** status;
- operator, cancellation timestamp, and reason;
- the frozen source manifest;
- candidate counts captured before deletion;
- confirmation that no production promotion occurred;
- confirmation that the captured snapshot was deleted;
- deleted counts by snapshot table;
- cancellation validation/audit result.

Cancellation reporting reads reconciliation-owned audit data and cannot depend on deleted `lor_snap` rows.

### Publication and terminal state

Atomic Finish and Cancel advance a run to `REPORTING`. Only successful report publication may assign the terminal status:

- Finish becomes `COMPLETED` or `COMPLETED_WITH_EXCEPTIONS`;
- Cancel becomes `CANCELLED`.

If HTML generation, filesystem publication, URL storage, or terminal transition fails, the run remains `REPORTING` with the failure recorded. Publication can be retried without rerunning P1-P4 and without repeating snapshot deletion.

## Snapshot Retention Management

The operator interface shall provide a separate **Manage Old Snapshots** action.

It shall allow the operator to review and delete old `lor_snap` ingest runs by:

- selecting runs from a list;
- filtering by date range;
- using a default eligibility threshold such as older than the latest five completed ingests.

The review list shall show at least:

- `import_run_id`;
- ingest timestamp;
- ingest notes;
- source row counts;
- reconciliation status;
- report link;
- deletion eligibility.

Hard protections:

- the latest completed ingest cannot be deleted through routine retention management;
- the immediately previous ingest used for diff reporting cannot be deleted;
- an ingest referenced by an active reconciliation cannot be deleted;
- one snapshot must be deleted as a complete unit;
- no deletion may cascade into `ref`, `ops`, or other production data.

The operator must confirm the selected runs, count, and date range before deletion.

Every deletion shall create an audit record containing actor, timestamp, selected `import_run_id` values, reason, and per-table deleted row counts.

Cancellation deletion and routine retention deletion may use the same protected internal snapshot-delete procedure, but with different authorization and audit reasons.

## FormView Compatibility

`lor_snap.preview_wiring_fieldonly_v6` remains the current FormView compatibility contract.

The `_v6` suffix is the established production object name and does not authorize replacement or removal during V7 reconciliation implementation.

## Work-Order Identity Boundary

`ops.work_order` may reference a display only through `display_id -> ref.display.display_id` and a stage only through `stage_id -> ref.stage.stage_id`.

LOR UUIDs and preview-qualified identifiers are source metadata, not permanent work-order foreign keys.

Any legacy UUID dependency requires a separate controlled migration.

## Required Implementation Order After Approval

Current implementation checkpoint: the display decision layer in `0014` and
`10` is installed and validated. Reconciliation-safe P1 in `0015` and the
multi-preview preservation action in `0016` are installed and rollback-
validated by `11` and `12`. Reconciliation-safe P2 in `0017` is installed and
rollback-validated by `13`. Migration `0018` implements frozen scene and
scene-membership candidates plus internal P3/P4; installation and rollback
validation `14` passed against development Run 1. Migration `0019` revision v2 implements the controlled atomic Finish/Cancel
database lifecycle and is installed and rollback-validated by `15`. Run 1 remains
development state and must not be committed. P1-P4 remain internal and may not
be called directly.

1. Validate this design against the current production schema and ingest completion semantics.
2. Implement reconciliation-run, candidate, action, result, validation, report, and snapshot-deletion audit objects.
3. Implement the secured start entry point called after successful parser and ingest execution.
4. Convert validated 01-09 logic into new persistent candidate builders.
5. Validate candidate classifications against the latest V7 snapshot, including raw null/blank-comment exclusions.
6. Implement reconciliation-safe P1.
7. Implement P3 scene definition promotion.
8. Implement reconciliation-safe P2 with exact write authority and independent raw-comment/SPARE/PHANTOM/nonphysical write guards.
9. Implement P4 scene-display membership promotion.
10. Implement Finish and Cancel reconciliation paths.
11. Implement post-write validation.
12. Implement completed and cancelled HTML report generation/publication.
13. Implement protected snapshot-retention management.
14. Test the complete workflow against a disposable or restored database before production use.

## Immediate Validation Required Before Executable DDL

Confirm from the live production database and importer:

- exact `lor_snap.import_run` completion semantics;
- all child tables that must be deleted for one snapshot;
- current columns, constraints, indexes, and triggers on `ref.stage`, `ref.display`, `ref.lor_scene`, and `ref.lor_scene_display`;
- current P1 and P2 definitions installed in production;
- snapshot uniqueness constraints;
- current status lookup values;
- current actor/audit trigger requirements;
- any legacy LOR UUID foreign keys;
- exact PHANTOM source markers used by the V7 parser;
- whether the parser currently excludes null/blank `lor_comment` rows and how that behavior is tested;
- internal web-server report path and URL rules.

## Related Documents and Navigation

This engineering design is one part of the three-document V7 production-import contract:

1. **Operator procedure — how the workflow is used**  
   `../00_LOR_Production_Import_and_Reconciliation_Procedure.md`

2. **Promotion architecture — how the workflow fits together**  
   `../01_LOR_Production_Promotion_Pipeline_Design.md`

3. **Reconciliation SQL design — how the engine is built**  
   `LOR_Display_Reconciliation_SQL_Design.md`

Changes crossing operator workflow, production architecture, or SQL-engine boundaries require all affected documents to be updated and reviewed before implementation continues.
