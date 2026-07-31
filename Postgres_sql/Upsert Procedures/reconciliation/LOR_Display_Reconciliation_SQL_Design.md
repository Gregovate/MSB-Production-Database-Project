# LOR Display Reconciliation SQL Design

## Status

Design draft only. The database objects and revised P2 described here are not yet implemented or approved for production.

## Purpose

Define the PostgreSQL objects required to reconcile one immutable LOR snapshot with permanent production display identities before P1, P2, or P3 may run.

The design must preserve:

- `ref.display.display_id` as the permanent physical-display identity.
- `ref.display.lor_prop_id` as the current LOR `propClass_id` UUID associated with that display.
- Explicit operator review for display-name changes, UUID changes, new displays, status changes, exclusions, and LOR-side corrections.
- `lor_snap.preview_wiring_fieldonly_v6` exactly as the existing FormView compatibility contract.
- The Master Musical Preview and its scene membership for future P3 without treating its lack of one preview-level stage ID as an unassigned-display error.

## Confirmed Source Rules

### Display reconciliation source

Physical display reconciliation is driven by props in authoritative stage/background previews:

- `lor_snap.props.import_run_id = selected import_run_id`
- matching `lor_snap.previews.import_run_id = selected import_run_id`
- matching `lor_snap.previews.id = lor_snap.props.preview_id`
- preview `stage_id` is present and canonical
- display name is `coalesce(nullif(btrim(props.lor_comment), ''), props.name)`

The join must include `import_run_id`. Joining only on `preview_id` can mix the selected prop run with repeated preview identities from historical runs.

### Master Musical Preview

The Master Musical Preview is not a second authoritative source of physical display identity. Its stage context is scene-based and is reserved for future P3 scene-reference processing.

Master Musical Preview props must not be counted as unassigned merely because the preview itself has no single `stage_id`.

### FormView

*IMPORTANT* Formview is the only current method to obtain the wiring view needed for park setup. We do not know how version 7 affects that stand-alone program as of 2026-07-31. The views are preserved but likely the stand alone program is still pointing to the now obsolete v6 sqlite database. Until this is fixed, or replaced from the database, the field wiring no longer is functional!

`lor_snap.preview_wiring_fieldonly_v6` remains unchanged. The `_v6` suffix is the established production object name, not a signal that the view is obsolete.

## Conflict With Current P2

The current `ref.p2_upsert_display_from_latest_lor()` performs identity decisions automatically:

1. Same UUID: updates `display_name` and other LOR-owned fields.
2. Same display name with a different UUID: replaces `ref.display.lor_prop_id`.
3. Neither UUID nor name found: inserts a new `ACTIVE` display.

Those operations bypass the required operator decisions. P2 must be revised after reconciliation is implemented.

The revised P2 must:

- Accept an explicit approved `import_run_id`; it must not rediscover `max(import_run_id)`.
- Refuse to run unless that exact run has passed reconciliation.
- Update LOR-owned operational attributes only for already approved UUID-to-`display_id` mappings.
- Route approved spare channels to `ref.spare_channel`.
- Never rename a display, replace a UUID mapping, insert a new display, or change a display status by inference.

## Proposed Database Objects

### 1. `ref.lor_display_exclusion`

Persistent, narrowly scoped rules for nonphysical LOR props.

| Column | Type | Purpose |
|---|---|---|
| `lor_display_exclusion_id` | bigint identity PK | Permanent exclusion-rule identity |
| `lor_prop_id` | text, nullable | Exact LOR UUID scope |
| `display_name_normalized` | text, nullable | Optional exact normalized-name scope |
| `preview_id` | text, nullable | Optional preview scope |
| `reason` | text, not null | Required explanation |
| `active_flag` | boolean, not null | Allows controlled retirement of a rule |
| audit columns | timestamps/operator | Creation and change history |

At least one of `lor_prop_id`, `display_name_normalized`, or `preview_id` must be populated. Broad wildcard exclusions are not allowed.

### 2. `ops.lor_reconciliation_action`

Append-only audit record for every operator decision.

| Column | Type | Purpose |
|---|---|---|
| `lor_reconciliation_action_id` | bigint identity PK | Action identity |
| `import_run_id` | bigint FK | Exact snapshot being reconciled |
| `action_type` | text | Controlled action code |
| `display_id` | bigint nullable FK | Permanent display identity when applicable |
| `lor_prop_id_before` | text nullable | Previous mapped UUID |
| `lor_prop_id_after` | text nullable | Approved UUID |
| `display_name_before` | text nullable | Previous production name |
| `display_name_after` | text nullable | Approved production name |
| `display_status_id_before` | integer nullable | Previous status |
| `display_status_id_after` | integer nullable | Approved status |
| `preview_id` | text nullable | LOR evidence |
| `preview_stage_id` | text nullable | LOR stage evidence |
| `reason` | text not null | Required operator explanation |
| `acted_at` | timestamptz not null | Decision timestamp |
| operator audit columns | operator identity | Person responsible |

Initial controlled action codes:

- `ACCEPT_EXACT_MATCH`
- `RENAME_DISPLAY`
- `UPDATE_LOR_UUID`
- `ADD_NEW_DISPLAY`
- `SET_RETIRED`
- `SET_RECYCLED`
- `EXCLUDE_NONPHYSICAL`
- `FLAG_LOR_CORRECTION`
- `DEFER`

`DEFER` remains blocking until a separate policy explicitly permits otherwise.

### 3. `ops.lor_reconciliation_run`

One control row per imported snapshot.

| Column | Type | Purpose |
|---|---|---|
| `import_run_id` | bigint PK/FK | Exact immutable snapshot |
| `status` | text | `PENDING`, `BLOCKED`, or `PASSED` |
| `generated_at` | timestamptz | First preflight generation |
| `last_evaluated_at` | timestamptz | Latest evaluation |
| `passed_at` | timestamptz nullable | Gate approval time |
| `passed_by_person_id` | bigint nullable | Approving operator |
| `blocking_count` | integer | Cached summary for interface/reporting |
| `notes` | text nullable | Run-level explanation |

`PASSED` must be derived by a controlled function after recomputing the live preflight. Operators must not directly edit this value.

### 4. `lor_snap.v_display_reconciliation_source`

Run-aware canonical display candidates from authoritative stage/background previews.

Required output:

- `import_run_id`
- `preview_id`
- `preview_stage_id`
- `preview_name`
- `lor_prop_id`
- `display_name`
- normalized display name
- prop metadata required by P2 (`string_type`, `color`)
- `is_spare`
- `is_excluded`

The view must detect rather than silently collapse:

- one UUID associated with multiple display names in the selected run;
- one normalized display name associated with multiple UUIDs in the selected run;
- the same UUID appearing in multiple authoritative stage previews;
- duplicate stage/background preview coverage.

### 5. `ops.v_lor_display_reconciliation`

Bidirectional preflight detail for every imported run.

Required classifications:

| Code | Meaning | Blocking by default |
|---|---|---:|
| `EXACT_MATCH` | UUID and exact normalized name resolve to one display | No |
| `NAME_CHANGED_SAME_UUID` | UUID resolves uniquely but LOR name differs | Yes |
| `UUID_CHANGED_SAME_NAME` | Name resolves uniquely but UUID differs | Yes |
| `NAME_AND_UUID_CHANGED` | No safe unique identity match | Yes |
| `NEW_DISPLAY_CANDIDATE` | Unseen UUID and name | Yes |
| `ACTIVE_DISPLAY_MISSING_FROM_LOR` | Active production identity absent from source set | Yes |
| `DUPLICATE_LOR_UUID` | One UUID has conflicting candidates | Yes |
| `DUPLICATE_LOR_NAME` | One name has multiple UUID candidates | Yes |
| `DUPLICATE_PRODUCTION_UUID` | One UUID maps to multiple `display_id` values | Yes |
| `EXCLUDED_NONPHYSICAL` | Active exact exclusion rule applies | No |
| `LOR_CORRECTION_REQUIRED` | Operator recorded that LOR must be corrected | Yes until corrected run |
| `DEFERRED` | Operator deferred the decision | Yes |

An `ACTIVE_DISPLAY_MISSING_FROM_LOR` comparison must use `ref.display_status`, not a hard-coded status ID.

### 6. `ops.f_lor_reconciliation_summary(import_run_id bigint)`

Read-only summary called after the snapshot transaction commits.

It returns at least:

- exact `import_run_id`
- total candidate displays
- exact matches
- excluded items
- blocking discrepancies by classification
- total blocking count
- gate status

The Python ingest prints this result and stops. A blocking count does not roll back or delete the valid snapshot.

### 7. `ops.p_assert_lor_reconciliation_passed(import_run_id bigint)`

Database-enforced gate used by revised P1, P2, and future P3.

It must fail if:

- the run does not exist;
- the control row is not `PASSED`;
- live recomputation finds a blocking discrepancy;
- the approved run is no longer the run explicitly supplied to the procedure.

## Controlled Action Procedures

Each action procedure must lock and revalidate its target, update production data only when required, and insert the audit row in the same transaction.

Proposed procedures:

- `ops.p_lor_accept_exact_match(...)`
- `ops.p_lor_rename_display(...)`
- `ops.p_lor_update_uuid(...)`
- `ops.p_lor_add_display(...)`
- `ops.p_lor_set_display_status(...)`
- `ops.p_lor_exclude_nonphysical(...)`
- `ops.p_lor_flag_correction(...)`
- `ops.p_lor_defer(...)`
- `ops.p_lor_evaluate_gate(import_run_id)`

No procedure may select `max(import_run_id)` internally. The operator or calling application must supply the intended run.

## Required Implementation Order

1. Confirm this design against the current production table definitions and status values.
2. Implement the source view and read-only classification view first.
3. Test their classifications against the current V7 snapshot discrepancies.
4. Implement the run-control and audit tables.
5. Implement controlled action procedures one at a time with rollback tests.
6. Implement the pass/fail summary and database gate.
7. Add the summary call to `postgres_ingest_from_lor_sqlite_v7.py` after commit.
8. Revise P1 and P2 to accept an explicit approved `import_run_id`.
9. Test P1/P2 against a disposable or restored database before production use.
10. Design P3 separately for scene reference data.

## Immediate Validation Queries Needed From Production

Before executable DDL is finalized, confirm:

- Current columns, constraints, and triggers on `ref.display`.
- Whether any production UUID currently maps to more than one `display_id`.
- Whether any normalized production display name is duplicated.
- Actual names and IDs in `ref.display_status`.
- Current actor/audit trigger requirements for new `ops` and `ref` objects.
- Whether `ref.display.lor_prop_id` is the only persistent UUID mapping or whether a mapping-history object already exists outside the schema export.
- Current P1 and P2 definitions installed in production match the repository copies.

