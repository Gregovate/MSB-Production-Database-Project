# LOR Production Promotion Pipeline Design

| Document control | Value |
|---|---|
| Repository path | `Postgres_sql/Upsert Procedures/01_LOR_Production_Promotion_Pipeline_Design.md` |
| Document type | Database design specification |
| Status | DRAFT — implementation and production validation required |
| Owner | MSB Database Administrator |
| Initial release | 2026-07-31 |
| Current revision | 2026-08-02 |

## Purpose

Define the controlled promotion of approved changes from the latest completed
LOR snapshot in `lor_snap` into durable production reference data.

This specification documents the responsibilities currently embedded only in
P1 and P2, defines the missing P3 scene promotion, and establishes the final
execution model. After validation, operators must not manually run P1, P2, or
P3 in production. One controlled workflow will enforce the reconciliation gate,
retain one persistent execution context, and run the complete promotion in the
correct order.

The operator-facing production procedure is defined in
`00_LOR_Production_Import_and_Reconciliation_Procedure.md`. Detailed stage,
display, scene, classification, operator-decision, and report rules are defined
in `reconciliation/LOR_Display_Reconciliation_SQL_Design.md`.

## Revision History

| Date | Author | Change |
|---|---|---|
| 2026-08-02 | GAL / OpenAI | Implemented the reconciliation-safe P1 repository layer: stable `ref.stage_lor_binding` identities, frozen stage candidates and atomic groups, unified display/stage start, captured-source revalidation, and an internal P1 that consumes only approved persisted groups. Installation and rollback validation remain required. |
| 2026-08-02 | GAL / OpenAI | Recorded the repository implementation of the persistent display-decision foundation: captured reconciliation runs, frozen display candidates, data-derived atomic groups, append-only actions, complete reassociation mappings, and read-only operator views. Installation and live validation remain prerequisites to promotion work. |
| 2026-08-02 | GAL / OpenAI | Removed `color` from LOR-owned P2 fields because RGB props have no single source color; added committed display-name changes to the replacement-label report requirements. |
| 2026-08-02 | GAL / OpenAI | Defined P2 as the final database guard against SPARE, PHANTOM, null, empty, and whitespace-only `lor_comment` values; removed stale authorization for wiring/controller/network/channel writes to `ref.display`; and limited ordinary P2 writes to the approved LOR-owned fields. |
| 2026-08-01 | GAL / OpenAI | Added the three-document navigation contract linking the operator procedure, promotion pipeline design, and reconciliation SQL design. |
| 2026-08-01 | GAL / OpenAI | Defined the latest-snapshot lifecycle, cancellation of reconciliation for an invalid ingest, optional removal of rejected snapshots, and short-term snapshot retention for current-versus-previous comparison. |
| 2026-08-01 | GAL / OpenAI | Defined the persistent reconciliation execution context, automatic latest-completed-ingest capture, single-evaluation working sets, operator pause/resume, committed-result reporting, and the handoff from the operator procedure to P1/P2/P3 promotion. |
| 2026-07-31 | GAL / OpenAI | Revised promotion to process stage/scene context first, promote independently safe displays, synchronize assignments last, and quarantine only affected exceptions. |
| 2026-07-31 | GAL / OpenAI | Initial P1/P2/P3 and controlled-orchestration design for V7 scene-aware imports. |

## Relationship to the Production Procedure

The production import is one stateful workflow even though parser, ingest,
preflight, operator review, promotion, validation, and reporting are separate
implementation phases.

The finished operator experience is:

```text
Start LOR Production Import
    -> parser
    -> password-protected snapshot ingest
    -> capture latest completed ingest
    -> build persistent reconciliation working sets
    -> automatic preflight
    -> operator review only when required
    -> apply approved changes
    -> validate committed results
    -> generate and publish timestamped HTML report
    -> complete
```

If no operator decisions are required, the workflow continues automatically
through promotion, validation, report publication, and completion. If review is
required, the workflow pauses without losing its captured ingest or evaluated
candidates. The operator later resumes the same reconciliation execution rather
than starting a new comparison.

## Latest Snapshot Lifecycle

The reconciliation workflow begins with the **latest completed LOR snapshot** in
`lor_snap`.

Each successful ingest creates a new snapshot identified by a unique
`import_run_id`. Snapshot rows are immutable while that snapshot exists: an
existing snapshot is not edited to represent corrected source data. A corrected
parser run or ingest creates a new snapshot.

The operational purpose of snapshot retention is to support:

- reconciliation against the latest LOR state;
- comparison of the latest snapshot with the immediately previous snapshot;
- validation and troubleshooting of recent parser and ingest activity.

`lor_snap` is not intended to be the permanent business-history archive for all
LOR imports. Durable history is maintained through reconciliation decisions,
committed promotion results, and published reconciliation reports. Older
snapshots may be removed under an approved retention process after they are no
longer needed for current-versus-previous comparison or troubleshooting.

If the latest snapshot is found to be invalid before promotion, the operator may
cancel the reconciliation execution. Examples include:

- selecting the wrong preview folder;
- using the wrong parser or parser version;
- running from the wrong computer;
- ingesting an incomplete or incorrect preview set;
- discovering corrupted or otherwise unreliable source data.

A cancelled reconciliation must not promote any production changes. Candidate
rows and decisions associated with the rejected snapshot must not be reused for
a later ingest. The invalid snapshot may be removed through the approved
administrative workflow, the source problem corrected, and a new ingest run. The
new successful ingest then becomes the latest snapshot and starts a new
reconciliation execution.

## Persistent Reconciliation Execution Context

Each production execution creates one persistent reconciliation-run record. The
entry point automatically captures the latest completed `lor_snap.import_run`
once and stores its `import_run_id` on that reconciliation run. That captured
latest snapshot remains fixed for the execution unless the operator cancels the
reconciliation and starts a new execution against a later ingest.

Directus users do not select, enter, or interpret `import_run_id`. Lower-level
procedures receive the stored value internally from the orchestrator and must not
rediscover the latest run independently.

The persistent context must retain, at minimum:

- the reconciliation-run identity;
- the captured `import_run_id`;
- execution status and timestamps;
- stage candidates and binding results;
- display identity and lifecycle candidates;
- scene candidates;
- scene-display membership candidates;
- operator decisions, including defer decisions;
- committed actions and post-write validation results;
- the generated report path and publication timestamp.

These rows remain available until promotion, validation, report generation, and
report publication are complete. They remain afterward as audit history unless a
separate approved retention process archives them.

Temporary tables may be used during development or inside one atomic database
operation, but session-local temporary tables are not the production workflow
state. The production workflow may span separate Directus requests, database
connections, operator decisions, and report-generation steps.

## Single-Evaluation Principle

The captured ingest is evaluated once per reconciliation execution.

The expensive identity-resolution and classification work is persisted once and
reused by:

- P1 stage processing;
- P2 display processing;
- P3 scene processing;
- P3 scene-display membership processing;
- operator-review screens;
- promotion validation;
- the final HTML report.

No downstream phase may independently rebuild its own interpretation of the
snapshot or reselect the latest ingest. This prevents inconsistent decisions,
reduces repeated query cost, and guarantees that operator review, production
writes, validation, and reporting describe the same evaluated source state.

## Architectural Boundaries

The pipeline preserves four different concepts:

| Concept | Meaning | Authority |
|---|---|---|
| Snapshot preview | One imported LOR preview file in the latest or retained snapshot | Immutable while retained in `lor_snap` |
| Stage | Durable physical park location | `ref.stage` |
| Display | Durable physical display identity | `ref.display` |
| Scene | LOR presentation/workspace view used to organize props and backgrounds | LOR snapshot, promoted for reporting through P3 |

A scene is not a stage and is not a display. A scene may supply stage context,
but it does not create a second physical-display identity.

## Non-Negotiable Controls

1. The reconciliation entry point automatically captures the latest completed
   ingest once. Lower-level procedures receive that captured `import_run_id`
   internally and may not select `max(import_run_id)` for themselves.
2. The captured run must have a completed reconciliation classification before
   promotion. Independently safe records may be promoted while unresolved records
   and their dependent assignments remain quarantined or deferred.
3. P1, P2, and P3 must be idempotent for the same approved reconciliation run.
4. Structural validation and each promotion phase run under controlled transaction
   boundaries. A structural failure rolls back the affected promotion attempt;
   record-level reconciliation exceptions do not roll back unrelated safe work.
5. Existing `stage_id` and `display_id` values are permanent.
6. Missing snapshot data never causes an automatic delete, retirement, recycle,
   or other destructive status change to a durable stage or display identity.
   Production scenes and scene assignments are current-state projections and are
   synchronized from the authoritative preview set, including deletion of empty
   or removed scenes and obsolete assignments.
7. Direct production execution of P1, P2, and P3 is removed from the normal
   operator role after validation. Only the orchestrator receives operator-facing
   execution permission.
8. Each completed promotion records the captured ingest, reconciliation run,
   start and completion timestamps, caller, result, procedure versions, promoted
   counts, blocked/deferred counts, validation results, and report location.
9. Final reporting is generated from persisted committed-result records. It must
   not rerun the comparison and infer what probably changed after the fact.
10. P2 is the final write boundary protecting `ref.display`. Before every insert
    or update, P2 must independently verify the raw captured
    `lor_snap.props.lor_comment`. A null, empty, or whitespace-only comment is
    never a physical display name and must be rejected even if parser or
    reconciliation classification failed upstream.

## Canonical Effective Stage Evidence

V7 has three source cases for associating a physical display with a stage:

1. A background preview with a canonical `previews.stage_id`.
2. A Master Musical Preview scene with effective stage key derived from
   `coalesce(scene_lor_props.scene_stage_id, scenes.stage_id)`.
3. A standalone stage-bearing preview, such as the Parade Float preview, with a
   canonical `previews.stage_id`.

Background and standalone stage-bearing previews define their stage directly.
Scenes inside a dedicated preview are subordinate workspace views and do not
override that preview's stage assignment. The Master Musical Preview does not
define one physical stage for the entire preview; its scene supplies effective
stage context for each display. Scene/stage context must therefore be processed
before display attributes.

All joins among `previews`, `props`, `scenes`, and `scene_lor_props` must include
the captured `import_run_id` as well as their run-scoped LOR identifiers.

## P1 — Stage Promotion

### Internal signature

```sql
call ref.p1_promote_stage_from_reconciliation(
    p_lor_reconciliation_run_id => p_reconciliation_run_id
);
```

The procedure resolves the captured `import_run_id` from the persisted
reconciliation run. Neither value is an operator prompt.

### Existing behavior being replaced

The current `ref.p1_upsert_stage_from_latest_lor`:

- Selects `max(lor_snap.import_run.import_run_id)` internally.
- Reads only `lor_snap.previews`.
- Derives a normalized `stage_key`, stage name, folder name, park order, and
  sub-order.
- Upserts `ref.stage` by `stage_key`.
- Does not delete stages.

That source rule is incomplete for the Master Musical Preview because the
preview no longer carries an individual musical-stage identity.

### Revised responsibility

P1 consumes the persisted stage candidates and approved stage decisions for the
reconciliation run. It owns durable `ref.stage` promotion and the associated
persistent LOR scene/stage projection required by the approved design.

It will:

- Assert that structural preflight has completed for the reconciliation run.
- Consume the already-evaluated stage and scene evidence rather than recalculating it.
- Validate stage keys against the established canonical format.
- Preserve `stage_id` on every update.
- Apply only approved metadata and binding changes.
- Leave blocked or deferred stage groups unchanged.
- Leave stages absent from the run unchanged.

P1 will not assign displays, infer display status, or delete a physical stage.

### Blocking conditions

- The reconciliation run is not ready for promotion.
- Required stage evidence is missing, contradictory, or noncanonical.
- A new stage lacks enough authoritative metadata to create a valid production row.
- A required parent/substage relationship is invalid.
- The persisted stage candidate does not match the captured ingest.

## P2 — Display Promotion

### Internal signature

```sql
call ref.p2_promote_display_attributes_from_lor(p_import_run_id => p_captured_import_run_id);
```

The orchestrator supplies the captured value and reconciliation-run context.

### Existing behavior being replaced

The current `ref.p2_upsert_display_from_latest_lor`:

- Selects the latest run internally.
- Obtains stage only through `props.preview_id -> previews.stage_id`.
- Falls back from a null or blank `props.lor_comment` to `props.name` when
  constructing `display_name`.
- Renames existing displays when UUID matches.
- Replaces a UUID association when normalized display name matches.
- Inserts unmatched displays as `ACTIVE`.
- Updates every matched display to `ACTIVE`.
- Routes inferred spare records to `ref.spare_channel`.

Those identity, naming, status, and spare-routing decisions are no longer
permitted because they bypass the audited reconciliation process and can create
nonphysical rows in `ref.display`.

### Revised responsibility

P2 consumes persisted display candidates and approved operator decisions. It does
not perform a second identity investigation during promotion.

It will:

- Assert that structural preflight and candidate classification completed for the
  reconciliation run.
- Process only deterministic safe candidates or explicit approved decisions.
- Preserve `display_id` for every existing display.
- Re-read the matching raw captured `lor_snap.props` row using both
  `import_run_id` and `prop_id` immediately before the write.
- Reject the candidate when `NULLIF(btrim(lor_comment), '') IS NULL`.
- Reject SPARE, PHANTOM, nonphysical-helper, and otherwise unconfirmed physical
  candidates even if an upstream parser or reconciliation defect allowed one to
  reach P2.
- Apply only these ordinary LOR-owned fields:
  - `lor_prop_id`;
  - `display_name` from `btrim(lor_snap.props.lor_comment)`;
  - approved resolved `stage_id`;
  - `string_type`.
- Preserve `ref.display.color` as production-maintained metadata; a null LOR
  color, including the expected null for RGB props, never clears it.
- Create a genuinely new display only from an approved new-display candidate.
- Apply `display_status_id` only from an explicit operator lifecycle decision
  resolved through `ref.display_status`.
- Leave blocked or deferred display groups unchanged.
- Never insert or update `ref.display` from `props.name` as a fallback name.
- Never insert, update, or delete `ref.spare_channel` as part of P2.

Every other production- or Directus-owned `ref.display` column remains unchanged.
Wiring, controller, network, channel, container, design, inventory, and other
production metadata are outside ordinary P2 authority.

A blocked candidate does not block unrelated safe candidates.

## P3 — Scene and Scene-Membership Promotion

### Internal signature

```sql
call ref.p3_upsert_scene_membership_from_lor(p_import_run_id => p_captured_import_run_id);
```

### Production objects

P3 uses the existing production objects created for the V7 scene model:

- `ref.lor_scene`
- `ref.lor_scene_display`

`ref.lor_scene` stores the current persistent LOR scene identity
`(preview_uuid, scene_uuid)`, current presentation metadata, and its resolved
physical `stage_id`.

`ref.lor_scene_display` stores current scene membership by permanent
`display_id`. A scene move updates an association and never creates a new display
identity.

### P3 responsibility

P3 consumes persisted scene and scene-display candidates for the reconciliation
run. It will:

- upsert approved scene rows;
- associate each scene with the approved permanent `stage_id`;
- synchronize approved memberships using `display_id`;
- reassociate moved displays without changing `display_id`;
- remove obsolete current memberships only when the authoritative captured
  snapshot and approved candidate set make that removal safe;
- remove obsolete/empty production scenes according to the approved current-state
  synchronization policy;
- leave blocked or deferred scenes and dependent memberships unchanged;
- preserve source evidence for the retained snapshot; snapshot retention is governed by the approved `lor_snap` lifecycle policy.

## Controlled Orchestration

### Proposed entry points

The final application presents one start action and, only when review is needed,
one finish/resume action. Internally these may call separate procedures so the
workflow can pause safely.

Illustrative internal procedures:

```sql
call ops.p_start_lor_reconciliation();
call ops.p_finish_lor_reconciliation(p_lor_reconciliation_run_id => :run_id);
```

`p_start_lor_reconciliation` must:

1. Acquire a lock preventing concurrent production reconciliation starts.
2. Verify parser/ingest prerequisites supplied by the secured external runner.
3. Capture the latest completed ingest exactly once.
4. Create the persistent reconciliation-run row.
5. Build and persist stage, display, scene, and membership candidates once.
6. Persist structural checks and classifications.
7. Continue automatically when no operator decisions are required, or set the
   run to an operator-review status and stop cleanly.

`p_finish_lor_reconciliation` must:

1. Verify the same reconciliation run and captured ingest remain authoritative
   for this execution.
2. Verify every required decision is resolved or explicitly deferred.
3. Apply approved P1/P2/P3 changes in dependency order.
4. Persist actual committed results.
5. Run post-write validation against the committed state.
6. Generate the timestamped HTML reconciliation report from persisted results.
7. Publish the report to the internal web server.
8. Store the report path/publication timestamp and mark the run complete.

If no review is required, the start procedure or calling application may invoke
the finish phase immediately so the operator experiences one uninterrupted run.

### Required processing order

1. Capture ingest and build the persistent reconciliation context.
2. Validate and apply stage decisions.
3. Upsert approved scene definitions needed for stage context.
4. Apply approved display identity, metadata, and lifecycle decisions.
5. Synchronize approved scene-display memberships.
6. Validate committed production state.
7. Persist committed-result counts and plain-language messages.
8. Generate and publish the report.

Record-level exceptions produce a completed run with blocked/deferred items when
safe isolation is preserved. Structural or transaction failures produce `FAILED`.

### Execution permissions after validation

- Revoke direct `EXECUTE` on P1, P2, and P3 from normal operator roles.
- Grant those procedures only to the orchestrator owner/execution role.
- Grant the operator-facing application only the controlled start, decision, and
  finish operations required by the workflow.
- Keep diagnostic preflight and verification reports read-only.
- Emergency direct execution requires a documented database-administrator change
  process; it is not part of routine production operation.

The secured PowerShell/Python runner owns parser and snapshot-ingest execution.
The database workflow owns capture of the resulting latest completed ingest and
all subsequent reconciliation state.

## Promotion and Reconciliation Audit Objects

The final schema must include a persistent reconciliation-run control row and
persistent child rows for evaluated candidates, operator decisions, committed
results, validation, and report publication.

The exact table split is defined in the reconciliation SQL design, but the
pipeline requires these logical capabilities:

- one reconciliation execution identity;
- one captured `import_run_id` per execution;
- persisted stage candidates;
- persisted display candidates;
- persisted scene candidates;
- persisted scene-display candidates;
- append-only operator decisions;
- append-only committed-result messages;
- post-write validation results;
- report file path and publication state.

A row reported as `ADDED`, `UPDATED`, `REASSOCIATED`, or `STATUS_CHANGED` must
represent an actual committed production change. Exact matches are not included
in the change report. Blocked and deferred candidates appear in the operator
review section with enough metadata for follow-up work.

## Required Validation Before Production Approval

1. Prove the start operation captures the latest completed ingest once.
2. Prove a newer ingest arriving during review cannot silently change the captured run, while allowing the operator to cancel the reconciliation and start a new execution against the new latest snapshot.
3. Prove candidate working sets are built once and reused by review, promotion,
   validation, and reporting.
4. Prove repeat execution against the same reconciliation run is idempotent.
5. Prove structural failure is rejected before unsafe writes.
6. Prove a record-level exception does not prevent unrelated safe promotion.
7. Prove dedicated preview stage evidence cannot be overridden by a subordinate
   scene name.
8. Prove Master Musical Preview scene evidence resolves the correct stage.
9. Prove scene membership resolves through permanent `display_id`.
10. Prove a missing display does not cause an implicit delete or status change.
11. Prove blocked/deferred candidates preserve existing production rows.
12. Prove P2 independently rejects SPARE, PHANTOM, null, empty, and
    whitespace-only raw `lor_comment` values before every `ref.display` write.
13. Prove the HTML report is generated from actual committed results and excludes
    exact matches and automatic rule-following exclusions.
14. Revoke direct procedure permissions only after the orchestrator and recovery
    process have been validated.

## Implementation Order

1. Approve the persistent reconciliation-run and candidate data model.
2. Implement the start/capture/build-candidates phase.
3. Convert existing preflight SQL into persisted candidate builders and read-only
   diagnostic reports over one reconciliation run.
4. Install and validate the repository implementation of reconciliation-safe P1.
5. Replace P2 with the reconciliation-run-aware implementation and independent
   raw-comment/nonphysical write guard.
6. Implement P3 against `ref.lor_scene` and `ref.lor_scene_display`.
7. Implement finish/promotion, committed-result capture, validation, and HTML
   report publication.
8. Validate outside production, then perform supervised production validation.
9. Revoke routine direct execution of P1/P2/P3 and make the controlled workflow
   the only normal production entry point.

## Related Documents and Navigation

These three documents define one controlled workflow from different perspectives
and must remain synchronized:

| Document | Role | Navigation |
|---|---|---|
| `00_LOR_Production_Import_and_Reconciliation_Procedure.md` | Operator-facing procedure: how the workflow is started, reviewed, completed, validated, and reported | [Open the production procedure](00_LOR_Production_Import_and_Reconciliation_Procedure.md) |
| `01_LOR_Production_Promotion_Pipeline_Design.md` | Production-promotion architecture: why the workflow exists, where the LOR-to-production handoff occurs, and what P1/P2/P3 are allowed to do | Current document |
| `reconciliation/LOR_Display_Reconciliation_SQL_Design.md` | Engineering design maintained with the reconciliation SQL: candidate classification, decision controls, validation contracts, and reporting implementation | [Open the reconciliation SQL design](reconciliation/LOR_Display_Reconciliation_SQL_Design.md) |

The production procedure and reconciliation SQL design must link back to this
document and to each other. A design change that affects more than one layer
requires all affected documents to be updated together before implementation
continues.
