# LOR Production Promotion Pipeline Design

| Document control | Value |
|---|---|
| Repository path | `Postgres_sql/Upsert Procedures/LOR_Production_Promotion_Pipeline_Design.md` |
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
2. The exact run must have a passing reconciliation gate before promotion.
3. P1, P2, and P3 must be idempotent for the same approved run.
4. The orchestrator runs the gate and all three procedures in one transaction.
   Any failure rolls back the entire promotion.
5. Existing `stage_id` and `display_id` values are permanent.
6. Missing snapshot data never causes an automatic delete, retirement, recycle,
   or other destructive status change.
7. Direct production execution of P1, P2, and P3 is removed from the normal
   operator role after validation. Only the orchestrator receives operator-facing
   execution permission.
8. Each completed promotion records the selected run, start and completion
   timestamps, caller, result, procedure versions, and verification counts.

## Canonical Effective Stage Evidence

V7 has two ways to associate a physical display with a stage:

1. A stage/background preview with a canonical `previews.stage_id`.
2. A Master Musical Preview scene with effective stage key derived from
   `coalesce(scene_lor_props.scene_stage_id, scenes.stage_id)`.

Background-preview evidence is authoritative when it exists. Scene evidence is
the fallback for a stage or display absent from the background-preview candidate
set. Conflicting stage evidence is blocking; it must not be resolved by arbitrary
ordering.

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

- Assert the reconciliation gate for the supplied run.
- Build one canonical candidate per normalized stage key from both background
  previews and scenes.
- Prefer a canonical background-preview name for an existing stage key.
- Use a scene name as the fallback stage name when no background candidate exists.
- Validate stage keys against the established canonical format.
- Preserve `stage_id` on every update.
- Insert genuinely new stage keys and update LOR-owned naming/order attributes.
- Leave stages absent from the run unchanged.

P1 will not promote scenes, assign displays, change display status, or delete a
stage.

### Blocking conditions

- The run is not reconciliation-approved.
- A scene-derived stage ID is missing or noncanonical when it is required.
- One stage key has conflicting authoritative names that cannot be resolved by
  the background-first rule.
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

- Assert the reconciliation gate for the supplied run.
- Consume the same canonical V7 display source used by reconciliation.
- Resolve stage using background evidence first and scene evidence as fallback.
- Match a physical display only through the approved `lor_prop_id -> display_id`
  association established by reconciliation.
- Update `stage_id`, `string_type`, `color`, and other explicitly designated
  LOR-owned attributes.
- Route approved spare-channel candidates to `ref.spare_channel` without deleting
  or reclassifying a production display.
- Preserve `display_id`, `display_name`, `lor_prop_id`, and display status.

P2 will not infer a rename, UUID reassociation, new display, `ACTIVE` status, or
retirement/recycle decision. A canonical LOR candidate without one approved
production mapping is a blocking error even if its name appears to match.

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
| `scene_uuid` | LOR `scene_id`; unique current LOR identity |
| `preview_uuid` | Parent LOR preview identity |
| `stage_id` | Nullable FK to `ref.stage`, resolved from the effective stage key |
| `scene_name` | Human-facing scene name |
| `scene_section` | LOR section/group metadata |
| `background_file` | Scene-specific background reference |
| `h_scroll`, `v_scroll`, `zoom`, `create_grid_view` | Presentation metadata |
| `source_import_run_id` | Last approved snapshot that supplied the current row |
| audit columns | Creation and update history |

The table name uses `lor_scene` to prevent a generic production “scene” concept
from being confused with physical stages or future non-LOR reporting views.

#### `ref.lor_scene_display`

Current many-to-many membership from scenes to permanent displays.

| Column | Purpose |
|---|---|
| `lor_scene_id` | FK to `ref.lor_scene` |
| `display_id` | FK to permanent `ref.display.display_id` |
| `scene_prop_ordinal` | LOR ordering evidence |
| `scene_role` | Parsed membership role |
| `source` | Parser source classification |
| `source_import_run_id` | Approved snapshot that established this membership |
| audit columns | Creation and update history |

The logical unique key is `(lor_scene_id, display_id)`. If a future validated
case proves that one display can occur multiple times in one scene with distinct
roles, the key must be extended deliberately; duplicates must not be silently
collapsed now.

No separate production background table is required for the initial P3 design.
Scene background and viewport attributes belong to `ref.lor_scene`. The raw
historical scene and membership rows remain in `lor_snap.scenes` and
`lor_snap.scene_lor_props` for every import run.

### P3 responsibility

P3 will:

- Assert the reconciliation gate for the supplied run.
- Validate that every scene membership resolves to one snapshot prop and, for a
  physical display, one approved permanent `display_id`.
- Upsert current scene metadata by LOR scene UUID.
- Resolve a scene's `stage_id` through the effective stage key and existing
  `ref.stage` row created or updated by P1.
- Rebuild current membership for each scene present in the selected run using
  `display_id`, never `lor_prop_id`, as the durable relationship.
- Preserve snapshot history in `lor_snap`; P3 changes only the current production
  projection.

### Stale and missing scene policy

Membership is authoritative only within a scene included in the approved run.
For each included scene, P3 may replace its current membership set atomically.

A production scene missing from the selected run is not deleted automatically.
It is marked stale/inactive only after a separately approved policy is designed.
Until then, the orchestrator reports missing prior scenes as a review item and
blocks promotion if their absence is unexplained.

## Controlled Orchestration

### Proposed procedure

```sql
call ops.p_promote_approved_lor_import(p_import_run_id => :import_run_id);
```

### Required transaction sequence

1. Acquire an advisory lock preventing concurrent LOR promotions.
2. Verify the exact `lor_snap.import_run` exists and is immutable/complete.
3. Assert `ops.lor_reconciliation_run` is `PASSED` for that exact run and
   recompute the live blocking count.
4. Refuse a run already promoted unless invoked in an explicitly supported
   idempotent verification mode.
5. Call P1 with the explicit run ID.
6. Verify stage coverage and zero unresolved effective stage keys.
7. Call P2 with the same run ID.
8. Verify every physical candidate maps to one display and every approved spare
   maps to the correct spare-channel record.
9. Call P3 with the same run ID.
10. Verify scene counts, scene-to-stage mappings, and scene-display memberships.
11. Write the completed promotion audit record.
12. Commit. Any exception rolls back all P1/P2/P3 changes and the completion
    audit record.

### Execution permissions after validation

- Revoke direct `EXECUTE` on P1, P2, and P3 from normal operator roles.
- Grant those procedures only to the orchestrator owner/execution role.
- Grant operators `EXECUTE` only on `ops.p_promote_approved_lor_import`.
- Keep preflight and verification functions read-only and independently available.
- Emergency direct execution requires a documented database-administrator change
  process; it is not part of the routine production workflow.

The PowerShell/Python import runner may eventually invoke the orchestrator only
after reconciliation has passed. It must pass the explicit run ID returned by
snapshot ingest; it must never substitute “latest run.”

## Promotion Audit Object

Create `ops.lor_promotion_run` with at least:

- `lor_promotion_run_id` bigint identity primary key.
- `import_run_id` unique FK to `lor_snap.import_run`.
- reconciliation approval reference and timestamp.
- `started_at`, `completed_at`, `started_by`, and result.
- P1/P2/P3 version identifiers.
- stage, display, spare, scene, and membership inserted/updated counts.
- verification summary and failure message.

Failed attempts may be logged outside the rolled-back promotion transaction by
the calling runner. A row marked completed must never survive a rolled-back
promotion.

## Required Validation Before Production Approval

1. Unit-test each procedure with an explicit historical test run.
2. Prove repeat execution against the same run produces no unintended changes.
3. Prove an unapproved or blocking run is rejected before any writes.
4. Prove a failure in P2 or P3 rolls back P1 changes.
5. Prove a newer snapshot arriving during approval cannot change the selected
   run being promoted.
6. Prove background-preview stage evidence wins over matching musical-scene
   fallback evidence.
7. Prove conflicting scene/background stage assignments block.
8. Prove scene membership resolves through permanent `display_id` after UUID and
   rename reconciliation.
9. Prove a missing display or scene does not cause an implicit delete or status
   change.
10. Compare final counts and representative wiring/scene reports with the known
    good run-36 reconciliation results.
11. Revoke direct procedure permissions only after the orchestrator and recovery
    process have been validated.

## Implementation Order

1. Approve this data model and stale-scene policy.
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
- `01_MSB_Live_LOR_Import_Testing_Procedure.md`

