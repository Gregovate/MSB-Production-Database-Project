# LOR Production Promotion Pipeline Design

| Document control | Value |
|---|---|
| Repository path | `Postgres_sql/Upsert Procedures/01_LOR_Production_Promotion_Pipeline_Design.md` |
| Document type | Database design specification |
| Status | DRAFT — implementation and production validation required |
| Owner | MSB Database Administrator |
| Initial release | 2026-07-31 |
| Current revision | 2026-07-31 |

## Purpose

Define the controlled promotion of one approved, immutable LOR snapshot from
`lor_snap` into durable production reference data.

This specification documents the responsibilities currently embedded only in
P1 and P2, defines the missing P3 scene promotion, and establishes the final
execution model. After validation, operators must not manually run P1, P2, or
P3 in production. One orchestration procedure will enforce the reconciliation
gate and run the complete promotion in the correct order.

## Revision History

| Date | Author | Change |
|---|---|---|
| 2026-07-31 | GAL / OpenAI | Initial P1/P2/P3 and controlled-orchestration design for V7 scene-aware imports. |
| 2026-07-31 | GAL / OpenAI | Revised promotion to process stage/scene context first, promote independently safe displays, synchronize assignments last, and quarantine only affected exceptions. |

## Architectural Boundaries

The pipeline preserves four different concepts:

| Concept | Meaning | Authority |
|---|---|---|
| Snapshot preview | One imported LOR preview file | Immutable `lor_snap` import evidence |
| Stage | Durable physical park location | `ref.stage` |
| Display | Durable physical display identity | `ref.display` |
| Scene | LOR presentation/workspace view used to organize props and backgrounds | LOR snapshot, promoted for reporting through P3 |

A scene is not a stage and is not a display. A scene may supply stage context,
but it does not create a second physical-display identity.

## Non-Negotiable Controls

1. Every procedure accepts an explicit `import_run_id`. No promotion procedure
   may select `max(import_run_id)` for itself.
2. The exact run must have a completed reconciliation classification before
   promotion. Independently safe records may be promoted while unresolved records
   and their dependent assignments remain quarantined.
3. P1, P2, and P3 must be idempotent for the same approved run.
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
8. Each completed promotion records the selected run, start and completion
   timestamps, caller, result, procedure versions, promoted counts, skipped counts,
   and exception counts.

## Canonical Effective Stage Evidence

V7 has three source cases for associating a physical display with a stage:

1. A background preview with a canonical `previews.stage_id`.
2. A Master Musical Preview scene with effective stage key derived from
   `coalesce(scene_lor_props.scene_stage_id, scenes.stage_id)`.
3. A standalone stage-bearing preview, such as the Parade Float preview, with a
   canonical `previews.stage_id`.

Background and standalone stage-bearing previews define their stage directly.
The Parade Float preview is not a background preview and is not part of the
Master Musical Preview. The Master Musical Preview does not define one physical
stage for the entire preview; the assigned scene supplies the effective stage for
each display. Scene/stage context must therefore be processed before display
attributes. Conflicting stage evidence blocks only the affected scene, display,
and assignment unless the conflict shows that the source structure as a whole
cannot be trusted.

All joins among `previews`, `props`, `scenes`, and `scene_lor_props` must include
the selected `import_run_id` as well as their run-scoped LOR identifiers.

## P1 — Stage Promotion

### Proposed signature

```sql
call ref.p1_upsert_stage_from_lor(p_import_run_id => :import_run_id);
```

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

P1 owns only durable `ref.stage` promotion.

It will:

- Assert that structural preflight has completed for the supplied run.
- Discover normalized stage keys from both previews and populated scenes.
- Validate stage keys against the established canonical format.
- Preserve `stage_id` on every update.
- Preserve the established `stage_name`, `short_code`, `folder_name`, and
  `folder_path` for every existing production stage.
- Update only `park_order` and `sub_order` for existing stages.
- Use scene names only to discover the stage key from their leading numeric or
  numeric-letter prefix. A scene name does not need a stage short code and
  cannot initialize one.
- Insert a genuinely new stage only when one unambiguous stage-preview source
  name follows `<stage_key>-<stage_name>-<short_code>`, where `short_code` is
  exactly two letters and is preserved for channel naming and wiring.
- Accept the established standalone-preview form
  `Show Stage <stage_key>-<stage_name>-<short_code>` by removing only the exact
  `Show Stage ` prefix. For example, the Parade Float preview becomes
  `40-Parade Float Trailer-PF` for a new Stage 40 insertion.
- Never apply that normalization to `Show Background Stage ...` names.
- Leave an ambiguously named new stage unresolved so only that stage and its
  dependent scenes, displays, and assignments are withheld.
- Leave stages absent from the run unchanged.

P1 will not promote scenes, assign displays, change display status, or delete a
stage.

### Blocking conditions

- The run is not reconciliation-approved.
- A scene-derived stage ID is missing or noncanonical when it is required.
- A new stage key has no unambiguous stage-preview source containing its
  two-letter short code, or has more than one distinct canonical source name.
- A required parent/substage relationship is invalid.
- The selected run lacks required preview or scene source rows.

## P2 — Display Attribute and Spare-Channel Promotion

### Proposed signature

```sql
call ref.p2_promote_display_attributes_from_lor(p_import_run_id => :import_run_id);
```

### Existing behavior being replaced

The current `ref.p2_upsert_display_from_latest_lor`:

- Selects the latest run internally.
- Obtains stage only through `props.preview_id -> previews.stage_id`.
- Renames existing displays when UUID matches.
- Replaces a UUID association when normalized display name matches.
- Inserts unmatched displays as `ACTIVE`.
- Updates every matched display to `ACTIVE`.
- Routes inferred spare records to `ref.spare_channel`.

Those identity and status decisions are no longer permitted because they bypass
the audited reconciliation process.

### Revised responsibility

P2 updates LOR-owned operational attributes only after permanent identity has
already been approved.

It will:

- Assert that structural preflight and record classification have completed for
  the supplied run.
- Consume the same canonical V7 display source used by reconciliation.
- Resolve stage using background evidence first and scene evidence as fallback.
- Match or create physical displays through deterministic, audited reconciliation
  rules. Process only candidates classified as safe for automatic promotion or
  explicitly approved by an operator.
- Update `stage_id`, `string_type`, `color`, and other explicitly designated
  LOR-owned attributes.
- Route approved spare-channel candidates to `ref.spare_channel` without deleting
  or reclassifying a production display.
- Preserve `display_id` for every existing display. LOR-owned current values,
  including name, current LOR UUID, stage/location, controller, network, channel,
  wiring, and similar configuration, may be overwritten when the deterministic
  identity match is safe.

P2 may automatically apply deterministic cases: exact UUID match, same UUID with
a changed name, unique same-name UUID relink, and a genuinely new unique display.
Ambiguous identity, destructive status, merge, or uncertain reassociation decisions
remain quarantined for operator review. A blocked candidate does not block unrelated
safe candidates.

## P3 — Scene and Scene-Membership Promotion

### Proposed signature

```sql
call ref.p3_upsert_scene_membership_from_lor(p_import_run_id => :import_run_id);
```

### Production objects

#### `ref.lor_scene`

Durable current scene identity and presentation metadata.

| Column | Purpose |
|---|---|
| `lor_scene_id` | Surrogate production primary key |
| `scene_uuid` | LOR `scene_id`; identity within its parent preview |
| `preview_uuid` | Parent LOR preview identity |
| `stage_id` | Required FK to `ref.stage`, resolved from the effective stage key |
| `scene_name` | Human-facing scene name |
| `scene_section` | LOR section/group metadata |
| `background_file` | Scene-specific background reference |
| `h_scroll`, `v_scroll`, `zoom`, `create_grid_view` | Presentation metadata |
| `source_import_run_id` | Last approved snapshot that supplied the current row |
| `created_at`, `created_by`, `updated_at`, `updated_by` | Current-row audit metadata, not scene history |

The table name uses `lor_scene` to prevent a generic production “scene” concept
from being confused with physical stages or future non-LOR reporting views.

Required keys and constraints:

- Primary key: `lor_scene_id`.
- Unique current LOR identity: `(preview_uuid, scene_uuid)`. A `scene_uuid` must
  not be assumed globally unique outside its parent preview.
- Required foreign key: `stage_id` references `ref.stage(stage_id)`.
- `preview_uuid`, `scene_uuid`, and `scene_name` are required for every promoted
  production scene.

#### `ref.lor_scene_display`

Current scene assignment from a scene to permanent displays.

| Column | Purpose |
|---|---|
| `lor_scene_id` | FK to `ref.lor_scene` |
| `preview_uuid` | Parent preview identity duplicated to enforce one scene per display per preview |
| `display_id` | FK to permanent `ref.display.display_id` |
| `scene_prop_ordinal` | LOR ordering evidence |
| `scene_role` | Parsed membership role |
| `source` | Parser source classification |
| `source_import_run_id` | Approved snapshot that established this membership |
| `created_at`, `created_by`, `updated_at`, `updated_by` | Current-row audit metadata, not assignment history |

One preview may contain multiple scenes, and one scene may contain many displays.
One physical display/prop may be assigned to only one current scene within its
preview. The production model must therefore enforce one current assignment per
`(preview_uuid, display_id)`, while also preventing duplicate
`(lor_scene_id, display_id)` rows.

Because `preview_uuid` belongs to the parent scene, PostgreSQL cannot enforce the
first rule from `lor_scene_display` unless that value is also stored on the
assignment row. The table therefore includes `preview_uuid` as a required,
deliberately duplicated enforcement column with:

- Primary key: `(lor_scene_id, display_id)`.
- Unique constraint: `(preview_uuid, display_id)`.
- Supporting unique constraint on `ref.lor_scene(lor_scene_id, preview_uuid)`.
- Composite foreign key: `(lor_scene_id, preview_uuid)` references the matching
  scene identity in `ref.lor_scene`.
- Foreign key: `display_id` references `ref.display(display_id)`.
- `ON DELETE CASCADE` from `ref.lor_scene` so deleting a current scene removes
  its current assignments.

No separate production background table is required for the initial P3 design.
Scene background and viewport attributes belong to `ref.lor_scene`. Production
scene tables contain only the current state. The immutable `lor_snap.scenes` and
`lor_snap.scene_lor_props` rows retain source history for each import run without
turning the production tables into history tables.

### P3 responsibility

P3 will:

- Assert that structural preflight and record classification have completed for
  the supplied run.
- Validate that each eligible scene membership resolves to one snapshot prop and,
  for a physical display, one permanent `display_id`.
- Upsert current scene metadata by `(preview_uuid, scene_uuid)`.
- Resolve a scene's `stage_id` through the effective stage key and existing
  `ref.stage` row created or updated by P1.
- Quarantine a scene and its dependent assignments when one valid `stage_id`
  cannot be resolved; never insert a production scene with a null stage.
- Synchronize current membership for each eligible display using `display_id`,
  never `lor_prop_id`, as the durable relationship. Moving a display between
  scenes overwrites its current assignment without changing its identity.
- Delete obsolete assignments after eligible displays have been resolved to
  their authoritative current scenes.
- Delete a scene when it is absent from its authoritative current preview or
  when it has no current display assignments.
- Skip and report assignments whose scene or display is quarantined; continue
  with unrelated valid assignments.
- Preserve snapshot history in `lor_snap`; P3 changes only the current production
  projection.

### Current-state scene synchronization policy

LOR is authoritative for current scene definitions and assignments. P3 replaces
the current membership set for each authoritative preview atomically after P2
has resolved the eligible displays.

If a production scene no longer exists in that preview, P3 deletes its obsolete
assignments and deletes the scene. If a scene exists but is empty, P3 also deletes
it. Displays that still exist are assigned to their new current scenes from the
same run; neither the scene move nor deletion changes their permanent
`display_id`. A scene with the same UUID and changed metadata is updated in place.

No inactive scene or scene-assignment history is retained in production tables.
Prior imported definitions and memberships remain available only in the immutable
`lor_snap` snapshot tables.

## Controlled Orchestration

### Proposed procedure

```sql
call ops.p_promote_approved_lor_import(p_import_run_id => :import_run_id);
```

### Required processing sequence

1. Acquire an advisory lock preventing concurrent LOR promotions.
2. Verify the exact `lor_snap.import_run` exists and is immutable/complete.
3. Run structural validation and classify reconciliation candidates for that
   exact run. Structural failures stop the run; record-level exceptions are
   quarantined.
4. Refuse a run already promoted unless invoked in an explicitly supported
   idempotent verification mode.
5. Promote and verify stage definitions from background previews and Master
   Musical Preview scene evidence.
6. Resolve, validate, and upsert scene definitions so effective stage context
   exists before any display is processed. A temporarily upserted scene that has
   no eligible current assignment is removed during final synchronization.
7. Promote every independently safe display and spare-channel record; quarantine
   only ambiguous records.
8. Synchronize scene-to-display assignments after permanent `display_id` values
   are available. Skip assignments dependent on quarantined scenes or displays.
9. Verify promoted and skipped counts for stages, scenes, displays, spares, and
   assignments.
10. Write the completed promotion audit record.
11. Commit the controlled promotion result. Record-level exceptions produce
    `PASSED_WITH_EXCEPTIONS`; structural or transaction failures produce `FAILED`.

P3 may be implemented as two internal phases—scene definitions before P2 and
scene assignments after P2—or as two separately named procedures. The numbering
is less important than enforcing this dependency order.

### Execution permissions after validation

- Revoke direct `EXECUTE` on P1, P2, and P3 from normal operator roles.
- Grant those procedures only to the orchestrator owner/execution role.
- Grant operators `EXECUTE` only on `ops.p_promote_approved_lor_import`.
- Keep preflight and verification functions read-only and independently available.
- Emergency direct execution requires a documented database-administrator change
  process; it is not part of the routine production workflow.

The PowerShell/Python import runner may eventually invoke the orchestrator only
after structural validation and reconciliation classification are complete. It
must pass the explicit run ID returned by snapshot ingest; it must never
substitute “latest run.”

## Promotion Audit Object

Create `ops.lor_promotion_run` with at least:

- `lor_promotion_run_id` bigint identity primary key.
- `import_run_id` unique FK to `lor_snap.import_run`.
- reconciliation approval reference and timestamp.
- `started_at`, `completed_at`, `started_by`, and result.
- P1/P2/P3 version identifiers.
- stage, display, spare, scene, and membership inserted/updated/skipped counts.
- exception count and references to the unresolved exception manifest.
- verification summary and failure message.

Failed attempts may be logged outside the rolled-back promotion transaction by
the calling runner. A row marked completed must never survive a rolled-back
promotion.

## Required Validation Before Production Approval

1. Unit-test each procedure with an explicit historical test run.
2. Prove repeat execution against the same run produces no unintended changes.
3. Prove structural failure is rejected before unsafe writes.
4. Prove a record-level display exception does not prevent unrelated safe stage,
   scene, display, spare, or assignment promotion.
5. Prove a newer snapshot arriving during approval cannot change the selected
   run being promoted.
6. Prove background-preview stage evidence wins over matching musical-scene
   fallback evidence.
7. Prove conflicting scene/background stage assignments block the affected
   dependency chain without silently selecting a winner.
8. Prove scene membership resolves through permanent `display_id` after UUID and
   rename reconciliation.
9. Prove a missing display does not cause an implicit delete or status change,
   while an empty or removed scene and its obsolete assignments are deleted from
   the current production projection.
10. Compare final counts and representative wiring/scene reports with the known
    good run-36 reconciliation results.
11. Revoke direct procedure permissions only after the orchestrator and recovery
    process have been validated.

## Implementation Order

1. Approve this data model and current-state scene deletion policy.
2. Create DDL for `ref.lor_scene`, `ref.lor_scene_display`, and
   `ops.lor_promotion_run`.
3. Replace P1 with the explicit-run, preview-plus-scene implementation.
4. Replace P2 with the explicit-run, reconciliation-safe implementation.
5. Implement P3.
6. Implement the orchestrator and verification functions.
7. Validate outside production, then perform a supervised production validation.
8. Revoke routine direct execution of P1/P2/P3 and make the orchestrator the only
   normal production entry point.

## Related Documents

- `00_LOR_Production_Import_and_Reconciliation_Procedure.md`
- `reconciliation/LOR_Display_Reconciliation_SQL_Design.md`
