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
| `migrations/` | Immutable installation history `0011` through `0036` | Run only the specifically authorized next migration; never rerun the folder as a batch |
| `validation/` | Validation `10` through `31` | Follow each file's header; several are transaction-wrapped rollback tests |
| `operator_queries/preflight/` | Read-only latest-ingest reports `01` through `09` | Run individually; no operator-supplied `import_run_id` |
| `incidents/` | Production incident report and its incident-specific forensic SQL | Historical evidence; not part of routine reconciliation |

The root Markdown files are this index and the current design specification.

## Current promotion procedures

| Phase | Database object | Canonical file | Definition lineage |
|---|---|---|---|
| P1 | `ref.p1_promote_stage_from_reconciliation(bigint)` | `current_procedures/P1_stage_promotion.sql` | Migration `0035` distinguishes simultaneous main/substage keys, moves only the approved new-key bindings, and requires unanimous evidence for a true rename |
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

The current installation chain is `0011` through `0036`.
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
- Captured `lor_snap` rows and frozen reconciliation candidates are never
  rewritten to repair a production-reference defect.
- A new permanent stage is inserted only by P1 after an explicit, evidence-
  gated `ADD_NEW_STAGE` decision.
- P1-P4 are internal and execute only through authorized Finish processing.
- A new ingest ID alone is not a production-data change.
- Numbered migrations are retained as audit history even when later migrations
  supersede specific object definitions.
