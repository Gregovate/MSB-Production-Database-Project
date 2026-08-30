# LOR Reconciliation SQL

This directory contains the scene-aware LOR reconciliation design, current
production procedure definitions, immutable installation history, validation,
operator queries, and incident evidence. SQL files are separated by purpose so
an operator does not have to guess whether a file installs objects, validates a
change, or merely reports evidence.

## Directory map

| Path | Contents | Execution rule |
|---|---|---|
| `current_procedures/` | Canonical standalone P1, P2, P3, and P4 definitions matching the latest accepted migration chain | Inspection or explicitly authorized repair only; these files do not call promotion |
| `migrations/` | Immutable installation history `0011` through `0041` | Run only the specifically authorized next migration; never rerun the folder as a batch |
| `validation/` | Validation `10` through `36` | Follow each file's header; several are transaction-wrapped rollback tests |
| `operator_queries/preflight/` | Read-only latest-ingest reports `01` through `09` | Run individually; no operator-supplied `import_run_id` |
| `incidents/` | Production incident report and its incident-specific forensic SQL | Historical evidence; not part of routine reconciliation |

The root Markdown files are this index and the current design specification.

## Current Stage Root Authority

For current P1 Stage/Sub-stage name, path, and LOR2DB application-access behavior, use:

[Stage Root Authority and Path Synchronization](Stage_Root_Authority_and_Path_Synchronization.md)

That document is the current authority for the migrations 0039/0040 Stage-root contract and migration 0041 least-privilege application grant. Where older design text describes earlier P1 naming, `folder_path`, or application-role behavior, the focused Stage-root contract controls.

Key current rules are:

- permanent `stage_id` is preserved;
- governed Stage/Sub-stage `stage_name` and `folder_name` are the exact Google Drive root basename, including Stage/Sub-stage key and terminal short code;
- current `folder_path` may be synchronized from the reconciliation run's frozen LOR path evidence only when exactly one governed root matches the permanent Stage identity;
- Stage path synchronization does not enumerate or search Google Drive;
- held/special rows `12,39,40,90-94` remain outside the automatic governed-root repair;
- `lor_preflight_app` has explicit execute permission on `ops.f_lor_governed_stage_roots(bigint,text)` while `PUBLIC` remains revoked;
- browser-facing database changes must be acceptance-tested under the real least-privilege application role, not only as `msbadmin`.

## Current promotion procedures

| Phase | Database object | Canonical file | Definition lineage |
|---|---|---|---|
| P1 | `ref.p1_promote_stage_from_reconciliation(bigint)` | `current_procedures/P1_stage_promotion.sql` | Migration `0039` establishes governed Stage/Sub-stage root naming authority; migration `0040` preserves that P1 and adds exact-one-governed-root synchronization of existing `folder_path` values |
| P2 | `ref.p2_promote_display_from_reconciliation(bigint)` | `current_procedures/P2_display_promotion.sql` | Migration `0035` resolves P1-created stages by source key and refuses unresolved/null stage assignments |
| P3 | `ref.p3_promote_scene_from_reconciliation(bigint)` | `current_procedures/P3_scene_promotion.sql` | Full definition from `0018`, then no-op correction from `0029 v4` |
| P4 | `ref.p4_promote_scene_display_from_reconciliation(bigint)` | `current_procedures/P4_scene_display_promotion.sql` | Full definition from `0018`, then no-op correction from `0029 v4` |

The canonical files are the readable current source. The migrations remain the
audit trail and must not be edited to make them look current.

`ops.p_finish_lor_reconciliation(bigint,text)` is installed by `0019` and
corrected by `0029 v4`. It remains part of the lifecycle controller rather than
a P1-P4 phase, so it is documented in migration history and is not duplicated
inside `current_procedures/`.

## Authoritative non-promotion replacements

Some later migrations replace functions created earlier. The later definition
is authoritative for the named object only.

| Database object | Originally installed | Current definition | Validation |
|---|---|---|---|
| `ops.f_build_lor_reconciliation_stage_candidates(bigint)` | `migrations/0015_create_reconciliation_safe_p1_stage_promotion.sql` | `migrations/0023_use_preview_manifest_for_stage_bindings.sql` | `validation/19_preview_manifest_stage_binding_validation.sql` |
| `ops.f_lor_governed_stage_roots(bigint,text)` | `migrations/0039_repair_stage_folder_authority.sql` | `migrations/0039_repair_stage_folder_authority.sql` + explicit `lor_preflight_app` grant in `0041` | `validation/34_stage_folder_authority_validation.sql`, `validation/35_stage_folder_path_sync_validation.sql`, `validation/36_lor_preflight_governed_root_grant_validation.sql` |
| `lor_snap.v_display_reconciliation_source` | `migrations/0011_create_lor_display_reconciliation_preflight_v7.sql` | `migrations/0038_allow_spare_to_display_activation.sql` | `validation/33_spare_to_display_activation_validation.sql` |
| `ops.v_lor_display_reconciliation` | `migrations/0011_create_lor_display_reconciliation_preflight_v7.sql` | `migrations/0038_allow_spare_to_display_activation.sql` | `validation/33_spare_to_display_activation_validation.sql` |
| `ops.f_start_lor_display_reconciliation(text)` | `migrations/0014_create_lor_reconciliation_decision_layer.sql` | `migrations/0038_allow_spare_to_display_activation.sql` | `validation/33_spare_to_display_activation_validation.sql` |

## Operator preflight suite

The secured LOR2DB website is the normal preflight and decision interface. Run
files in `operator_queries/preflight/` individually in numeric order only when
an authorized engineering investigation or manual recovery requires SQL
evidence. They select the latest committed ingest and do not call P1, P2, P3,
P4, or Finish.

1. `01_latest_ingest_context.sql`
2. `02_latest_ingest_p1_stage_preflight.sql`
3. `03_latest_ingest_p2_summary.sql`
4. `04_latest_ingest_p2_action_report.sql`
5. `05_latest_ingest_integrity_checks.sql`
6. `06_latest_ingest_scene_preflight.sql`
7. `07_latest_ingest_scene_display_preflight.sql`
8. `08_latest_ingest_p2_display_identity_gate.sql`
9. `09_current_p2_projected_write_validation.sql`

`incidents/08a_unapproved_ref_display_insert_forensics.sql`
is retained only as incident evidence. It is not step 8A of the normal workflow.

## Migration and validation status

The current installed migration chain is `0011` through `0041`.

Migration `0029` must be revision
`2026-08-05-true-noop-reconciliation-writes-v4`; its corresponding validation
is `validation/25_true_noop_reconciliation_write_validation.sql`. Migration
`0032` adds the safe stage-authority actions and is paired with
`validation/27_safe_stage_authority_and_cancel_terminal_validation.sql`. It
also guarantees that `CANCELLED` runs receive `completed_at` and backfills any
older cancelled audit row where that terminal timestamp is missing.
Migration `0033` applies operator-approved canonical StageID/substage changes
without replacing permanent stage identity, records accepted StageID aliases
for stable bindings, exposes every frozen decision-group member, and is paired
with `validation/28_complete_stage_decision_evidence_validation.sql`.
Migration `0034` synchronizes effective counters and decision-state readiness
after every persisted action, repairs already-open runs whose saved decisions
and lifecycle diverged, and is paired with
`validation/29_decision_readiness_sync_validation.sql`.
Migration `0035` repairs the Stage 05/05a collapse without changing captured
snapshot or frozen candidate evidence. It establishes the general rule that
simultaneous source keys such as `NN` and `NNa` are distinct permanent stages,
not a rename of one stage. It also prevents P2 from clearing a production
`stage_id` when a source key cannot be resolved. Validate it with
`validation/30_distinct_substage_and_stage_assignment_validation.sql`.
Migration `0036` completes the incident repair by moving the existing Mega Star
permanent Scene from Stage 05 to the distinct Stage 05a identity. It changes no
snapshot or frozen reconciliation evidence and is paired with
`validation/31_complete_stage05a_scene_repair_validation.sql`.
Migration `0037` adds grouped-DMX source-row detail without changing permanent
Display identity and is paired with
`validation/32_dmx_source_detail_validation.sql`.
Migration `0038` supports both normal channel lifecycle directions: placing a
SPARE into service as a physical Display and returning a recycled Display
channel to SPARE. SPARE/PHANTOM evidence remains excluded and cannot contribute
to physical UUID/name duplicate counts, occurrence evidence, identity
components, physical decision groups, or non-active Display classifications. It
is paired with `validation/33_spare_to_display_activation_validation.sql`.
Migration `0039` makes the governed Google Drive Stage/Sub-stage root the
permanent naming authority. Existing accepted `stage_name` and `folder_name`
values were repaired to the exact root basename; future `ADD_NEW_STAGE` requires
one frozen governed root. It is paired with
`validation/34_stage_folder_authority_validation.sql`.
Migration `0040` synchronizes an existing governed Stage/Sub-stage
`folder_path` only from exactly one frozen governed LOR root that matches the
permanent Stage name/folder identity. It performs no Google Drive search and is
paired with `validation/35_stage_folder_path_sync_validation.sql`.
Migration `0041` restores the missing least-privilege LOR2DB application grant
for the governed-root resolver. It grants `EXECUTE` only to `lor_preflight_app`,
keeps `PUBLIC` revoked, and is paired with
`validation/36_lor_preflight_governed_root_grant_validation.sql`, which exercises
the actual Stage-review view under `SET LOCAL ROLE lor_preflight_app`.

Migrations 0039 through 0041 were production deployed and validated on 2026-08-30. See
[Stage Root Authority and Path Synchronization](Stage_Root_Authority_and_Path_Synchronization.md)
for the acceptance record, Run 18 recovery, and rollback artifacts.

Do not infer that a numbered validation is harmless from its filename alone.
Read its header. In particular,
`validation/10_persistent_operator_decision_rollback_validation.sql` is the historical
rollback validation paired with the initial persistent decision layer and is
not an installation script.

## Safety boundaries

- Preflight remains read-only.
- Start captures the latest committed ingest internally and freezes evidence.
- Operators and Directus users do not select `import_run_id`.
- Contradictory stage evidence cannot expose an approval action.
- Main and substage source keys (`NN` and `NNa`) retain separate permanent
  stage identities, bindings, and display assignments.
- Governed Stage/Sub-stage names come from exact frozen root path evidence, not descriptive LOR Preview/Scene names.
- Existing governed `folder_path` is synchronized only when exactly one frozen governed root matches the permanent `stage_name` and `folder_name` identity.
- P1 does not enumerate or recursively search Google Drive to discover a moved Stage/Sub-stage.
- Browser-facing database objects must be validated under the real least-privilege application role before production approval.
- Captured `lor_snap` rows and frozen reconciliation candidates are never
  rewritten to repair a production-reference defect.
- A new permanent stage is inserted only by P1 after an explicit, evidence-
  gated `ADD_NEW_STAGE` decision.
- P1-P4 are internal and execute only through authorized Finish processing.
- A new ingest ID alone is not a production-data change.
- Numbered migrations are retained as audit history even when later migrations
  supersede specific object definitions.
