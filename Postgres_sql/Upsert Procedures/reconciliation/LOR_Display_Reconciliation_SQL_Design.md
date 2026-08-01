# LOR Display Reconciliation SQL Design

- **Repository Path:** `Postgres_sql/Upsert Procedures/reconciliation/LOR_Display_Reconciliation_SQL_Design.md`
- **Document Type:** Database design specification
- **Status:** Design draft; not approved for production implementation
- **Owner:** MSB Database Administrator
- **Initial Release:** 2026-07-31
- **Current Revision:** 2026-07-31

## Revision History

| Date | Author | Change |
|---|---|---|
| 2026-07-31 | GAL / OpenAI | Initial reconciliation architecture based on the V7 scene-aware snapshot ingest. |
| 2026-07-31 | GAL / OpenAI | Added the permanent display identity contract and validated the design against the repository schema export and current P2. |
| 2026-07-31 | GAL / OpenAI | Defined status authority, bidirectional status discrepancies, same-snapshot status correction, occurrence evidence, and classification precedence. |
| 2026-07-31 | GAL / OpenAI | Corrected the V7 source rule so musical-only displays enter reconciliation through Master Musical Preview scene membership, while background candidates remain preferred. |
| 2026-07-31 | GAL / OpenAI | Recast resolution choices as operator-facing business actions, added explicit renamed/rebuilt reassociation, and documented the legacy work-order UUID foreign-key dependency found during run 36 validation. |
| 2026-07-31 | GAL / OpenAI | Replaced the zero-blocker production gate with deterministic automatic matching, row-level quarantine, and passed-with-exceptions promotion. |

## Status and Scope

Design draft only. The database objects and revised P2 described here are not yet implemented or approved for production.

## Purpose

Define the PostgreSQL objects required to classify one immutable LOR snapshot
against permanent production display identities before controlled promotion.

The design must preserve:

- `ref.display.display_id` as the permanent physical-display identity.
- `ref.display.lor_prop_id` as the current LOR `propClass_id` UUID associated with that display.
- Automatic promotion for deterministic identity matches and explicit operator
  review for ambiguous identity, destructive status changes, exclusions, and
  LOR-side corrections.
- `lor_snap.preview_wiring_fieldonly_v6` exactly as the existing FormView compatibility contract.
- The Master Musical Preview and its scene membership for future P3 without treating its lack of one preview-level stage ID as an unassigned-display error.

## Non-Negotiable Display Identity Contract

- `ref.display.display_id` is the permanent database identity and the foreign key used by relational tables.
- `ref.display.display_name` is the meaningful human-facing identity.
- `ref.display.lor_prop_id` is only the current LOR UUID association stored in `ref.display`.
- No other production relational table may use `lor_prop_id` as the permanent display identity.
- A display rename or LOR UUID change must preserve `display_id`.
- Reconciliation may change the name or current UUID association automatically
  only when deterministic rules identify exactly one permanent display.
- P2 must not guess. It may apply an audited deterministic match from a matching
  UUID or unique normalized name.

The repository schema export confirms that `display_id` is the primary key of `ref.display`. It also contains unique enforcement for the normalized display name and `lor_prop_id`, while downstream label, test-session, and work-order relationships use `display_id`. These constraints support the intended identity model; they do not replace preflight review.

## Confirmed Source Rules

### Display reconciliation source

Physical display reconciliation first uses props in authoritative
stage/background previews:

- `lor_snap.props.import_run_id = selected import_run_id`
- matching `lor_snap.previews.import_run_id = selected import_run_id`
- matching `lor_snap.previews.id = lor_snap.props.preview_id`
- preview `stage_id` is present and canonical
- physical display name is `btrim(props.lor_comment)`
- `props.lor_comment` must be nonblank after trimming before the prop may enter
  display reconciliation
- `props.name` is a LOR prop/channel or wiring name and must never be used as a
  fallback physical-display identity
- a null, empty, or whitespace-only `props.lor_comment` identifies a wiring-only
  prop for reconciliation purposes; it is omitted from the physical-display
  candidate set rather than classified as a new or excluded display

The join must include `import_run_id`. Joining only on `preview_id` can mix the selected prop run with repeated preview identities from historical runs.

For a normalized display name absent from every background-preview candidate in
the selected run, reconciliation must also accept the corresponding Master
Musical Preview prop through `scene_lor_props`. Its effective stage ID is
`coalesce(scene_lor_props.scene_stage_id, scenes.stage_id)`. Every join remains
scoped to the selected `import_run_id`.

### Master Musical Preview

The Master Musical Preview is the fallback identity source for displays that
exist only there in V7. It is not allowed to create a second candidate when the
same normalized display name already has a background-preview candidate.

Master Musical Preview props must not be counted as unassigned merely because the preview itself has no single `stage_id`.

### Status authority

`ref.display.display_status_id` is PostgreSQL-owned. LOR does not supply, infer, or overwrite display status.

- Display names and new physical displays flow one way from LOR to `ref.display` through controlled reconciliation.
- An existing `display_id` and `display_name` are not directly edited in PostgreSQL.
- Status is deliberately editable in `ref.display` and may be corrected without changing the immutable LOR snapshot.
- P2 must never set an existing display back to `ACTIVE` merely because the display is present in LOR.
- Status comparisons must resolve status meaning through `ref.display_status`; they must not depend on hard-coded numeric IDs.

When status and LOR presence disagree, either side may be wrong:

| Current condition | Approved correction | New parser run and ingest required? |
|---|---|---:|
| Non-active PostgreSQL display is still present in LOR | Remove it from every reported preview/scene | Yes |
| Non-active PostgreSQL display is still present in LOR, but PostgreSQL status is wrong | Correct only `ref.display.display_status_id` | No |
| Active PostgreSQL display is missing from LOR | Restore it to the appropriate LOR preview/scene | Yes |
| Active PostgreSQL display is missing from LOR, but it was intentionally retired/recycled | Correct only `ref.display.display_status_id` | No |

After a PostgreSQL-only status correction, reconciliation is recomputed against the same `import_run_id`. The existing snapshot remains valid because none of its source data changed.

### FormView

*IMPORTANT* Formview is the only current method to obtain the wiring view needed for park setup. We do not know how version 7 affects that stand-alone program as of 2026-07-31. The views are preserved but likely the stand alone program is still pointing to the now obsolete v6 sqlite database. Until this is fixed, or replaced from the database, the field wiring no longer is functional!

`lor_snap.preview_wiring_fieldonly_v6` remains unchanged. The `_v6` suffix is the established production object name, not a signal that the view is obsolete.

## Conflict With Current P2

The current `ref.p2_upsert_display_from_latest_lor()` performs identity decisions automatically:

1. Same UUID: updates `display_name` and other LOR-owned fields.
2. Same display name with a different UUID: replaces `ref.display.lor_prop_id`.
3. Neither UUID nor name found: inserts a new `ACTIVE` display.

Those operations currently lack explicit classification, evidence, and audit.
P2 must be revised after reconciliation is implemented; the deterministic cases
themselves are valid when they are unambiguous and audited.

The revised P2 must:

- Accept an explicit approved `import_run_id`; it must not rediscover `max(import_run_id)`.
- Refuse to run unless structural validation and classification are complete for
  that exact run.
- Update LOR-owned operational attributes for deterministic safe or explicitly
  approved UUID-to-`display_id` mappings.
- Route approved spare channels to `ref.spare_channel`.
- Automatically apply same-UUID renames, unique same-name UUID relinks, and
  genuinely new unique displays when classification evidence is unambiguous.
- Never infer an ambiguous reassociation or destructive status change.

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

- `RENAME_DISPLAY`
- `UPDATE_LOR_UUID`
- `REASSOCIATE_DISPLAY`
- `ADD_NEW_DISPLAY`
- `SET_RETIRED`
- `SET_RECYCLED`
- `EXCLUDE_NONPHYSICAL`
- `FLAG_LOR_CORRECTION`
- `DEFER`

`DEFER` quarantines that display and its dependent assignment. It blocks the
whole run only when safe row-level isolation is not possible.

`EXACT_MATCH` does not create an operator action. It is an automatically validated condition: the selected snapshot UUID and normalized name already resolve to the same single `display_id`. Requiring hundreds of acceptance records for unchanged displays would add noise without protecting identity.

### Operator-facing decisions

The production approval interface must describe the physical-display decision,
not require the operator to reason about database classifications or UUIDs.
UUIDs remain available as supporting technical evidence.

| Operator choice | Database action |
|---|---|
| Keep this display; update its LOR link | Preserve `display_id` and `display_name`; replace `lor_prop_id` |
| Rename this display | Preserve `display_id` and `lor_prop_id`; replace `display_name` |
| This is an existing display with a new name and LOR link | Preserve the selected `display_id`; replace both `display_name` and `lor_prop_id` |
| Add this as a new display | Insert one new `ref.display` identity from the selected snapshot candidate |
| Mark this display recycled/retired | Preserve `display_id`; change only the PostgreSQL-owned status |
| Correct LOR and ingest again | Make no mutation for this candidate; quarantine it and continue safe unrelated records |
| Defer | Make no mutation for this candidate; quarantine it and its dependent assignment |

`REASSOCIATE_DISPLAY` is the explicit resolution for a renamed or rebuilt prop
where both the human-facing name and LOR UUID changed. The diagnostic view
necessarily reports this as one new LOR candidate plus one missing production
display. The approval interface must combine the two rows into one decision
after the operator selects the existing `display_id`; it must not require two
independent approvals or insert a duplicate display.

### 3. `ops.lor_reconciliation_run`

One control row per imported snapshot.

| Column | Type | Purpose |
|---|---|---|
| `import_run_id` | bigint PK/FK | Exact immutable snapshot |
| `status` | text | `PENDING`, `PASSED`, `PASSED_WITH_EXCEPTIONS`, or `FAILED` |
| `generated_at` | timestamptz | First preflight generation |
| `last_evaluated_at` | timestamptz | Latest evaluation |
| `passed_at` | timestamptz nullable | Gate approval time |
| `passed_by_person_id` | bigint nullable | Approving operator |
| `blocking_count` | integer | Cached summary for interface/reporting |
| `notes` | text nullable | Run-level explanation |

The result must be derived by a controlled function after recomputing live
classification. Operators must not directly edit it.

### 4. `lor_snap.v_display_reconciliation_source`

Run-aware canonical display candidates from authoritative background previews
plus V7 Master Musical Preview scene membership.

Background previews remain the preferred source when a normalized display name
exists there. A Master Musical Preview prop becomes the canonical candidate only
when that normalized display name has no background-preview candidate in the
same import run. Its stage context comes from `scene_lor_props.scene_stage_id`
or the matching `scenes.stage_id`. This permits musical-only displays to
participate in reconciliation without treating their second LOR occurrence as
a second physical display.

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

The view must detect rather than silently collapse conflicts within the chosen
canonical candidate set:

- one UUID associated with multiple display names in the selected run;
- one normalized display name associated with multiple UUIDs in the selected run;
- the same UUID appearing in multiple authoritative stage previews;
- duplicate stage/background preview coverage.

### 5. `lor_snap.v_display_lor_occurrence`

Run-aware evidence showing every location where a physical display occurs in LOR. This is supporting evidence for operator instructions; it does not replace the authoritative background-preview identity source.

Required output:

- `import_run_id`
- `lor_prop_id`
- normalized display name
- `preview_id`
- `preview_name`
- `preview_stage_id`
- `scene_id`, nullable
- `scene_name`, nullable
- `scene_stage_id`, nullable
- `location_type` (`PREVIEW` or `SCENE`)

Scene occurrence rows must join `scene_lor_props`, `scenes`, `props`, and `previews` using the selected `import_run_id` plus their run-scoped identifiers. The operator message for a non-active display still found in LOR must identify the human-facing display name and every applicable preview and scene location.

### 6. `ops.v_lor_display_reconciliation`

Bidirectional preflight detail for every imported run.

Required classifications:

| Code | Meaning | Blocking by default |
|---|---|---:|
| `EXACT_MATCH` | UUID and exact normalized name resolve to one display | No |
| `NAME_CHANGED_SAME_UUID` | UUID resolves uniquely but LOR name differs | Yes |
| `UUID_CHANGED_SAME_NAME` | Name resolves uniquely but UUID differs | Yes |
| `NAME_AND_UUID_CHANGED` | No safe unique identity match | Yes |
| `NEW_DISPLAY_CANDIDATE` | Unseen UUID and name | Yes |
| `NONACTIVE_DISPLAY_PRESENT_IN_LOR` | Existing non-active production display still occurs in one or more LOR previews/scenes | Yes |
| `ACTIVE_DISPLAY_MISSING_FROM_LOR` | Active production identity absent from source set | Yes |
| `DUPLICATE_LOR_UUID` | One UUID has conflicting candidates | Yes |
| `DUPLICATE_LOR_NAME` | One name has multiple UUID candidates | Yes |
| `DUPLICATE_PRODUCTION_UUID` | One UUID maps to multiple `display_id` values | Yes |
| `DUPLICATE_PRODUCTION_NAME` | One normalized production name maps to multiple `display_id` values | Yes |
| `EXCLUDED_NONPHYSICAL` | Active exact exclusion rule applies | No |
| `LOR_CORRECTION_REQUIRED` | Operator recorded that LOR must be corrected | Yes until corrected run |
| `DEFERRED` | Operator deferred the decision | Yes |

Both status classifications must use `ref.display_status`, not hard-coded status IDs. A PostgreSQL status correction changes the live classification when the view is queried again; no stored discrepancy row may continue blocking merely because it reflects the earlier status.

Required row structure:

| Column group | Required values |
|---|---|
| Snapshot identity | `import_run_id`, `lor_prop_id`, LOR display name, normalized LOR display name |
| Production identity | `display_id`, production display name, normalized production display name |
| Production status | `display_status_id`, `display_status_name`, derived active/non-active flag |
| Match evidence | UUID match count, normalized-name match count, matched-by-UUID `display_id`, matched-by-name `display_id` |
| Location evidence | preview/scene occurrence count and operator-readable location summary |
| Decision output | classification code, blocking flag, operator message, allowed resolution paths |

The view is live evidence, not a frozen work queue. Audit records preserve decisions and mutations; the classification view always recomputes from the immutable snapshot plus current `ref.display` state.

#### Classification precedence

Only one primary classification is emitted for a candidate at a time. Higher-risk ambiguity must override an apparent match.

1. Snapshot duplicate UUID/name or duplicate authoritative coverage.
2. Production duplicate UUID/name.
3. Active exclusion rule.
4. Existing non-active display still present in LOR.
5. UUID and name both resolve to the same `display_id` (`EXACT_MATCH`).
6. Same UUID with changed LOR name.
7. Same normalized name with changed LOR UUID.
8. Unseen UUID and unseen name (`NEW_DISPLAY_CANDIDATE`).
9. Remaining unsafe identity conflict (`NAME_AND_UUID_CHANGED`).

`ACTIVE_DISPLAY_MISSING_FROM_LOR` is generated by the reverse, production-to-snapshot side of the view after the candidate classifications. A display already represented by a higher-priority ambiguity must not also be presented as a simple missing-display correction.

#### Permitted resolutions for status discrepancies

- `NONACTIVE_DISPLAY_PRESENT_IN_LOR`
  - Flag LOR correction and block this run until a corrected snapshot is ingested; or
  - Set the appropriate PostgreSQL status through the audited status procedure, then reevaluate this same run.
- `ACTIVE_DISPLAY_MISSING_FROM_LOR`
  - Flag LOR correction and block this run until a corrected snapshot is ingested; or
  - Set the appropriate non-active PostgreSQL status through the audited status procedure, then reevaluate this same run.

### 7. `ops.f_lor_reconciliation_summary(import_run_id bigint)`

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

### 8. `ops.p_assert_lor_reconciliation_classified(import_run_id bigint)`

Database-enforced structural and classification assertion used by revised P1,
P2, and future P3 phases.

It must fail if:

- the run does not exist;
- the control row is not ready for promotion;
- live recomputation finds a structural failure or an exception that cannot be
  isolated safely;
- the approved run is no longer the run explicitly supplied to the procedure.

## Controlled Action Procedures

Each action procedure must lock and revalidate its target, update production data only when required, and insert the audit row in the same transaction.

Proposed procedures:

- `ops.p_lor_rename_display(...)`
- `ops.p_lor_update_uuid(...)`
- `ops.p_lor_add_display(...)`
- `ops.p_lor_set_display_status(...)`
- `ops.p_lor_exclude_nonphysical(...)`
- `ops.p_lor_flag_correction(...)`
- `ops.p_lor_defer(...)`
- `ops.p_lor_evaluate_gate(import_run_id)`

No procedure may select `max(import_run_id)` internally. The operator or calling application must supply the intended run.

Every mutating action must receive both the exact `import_run_id` and enough current evidence to prevent a stale-screen decision. At minimum, the procedure must re-read the snapshot candidate and the affected `ref.display` row under lock before applying the action. If the UUID, name, status, or `display_id` no longer matches the reviewed evidence, the procedure must fail without writing either the mutation or a successful action record.

### Work-order identity boundary confirmed during run 36

`ops.work_order` may reference a display only through the nullable permanent
key `display_id -> ref.display.display_id`. It may reference a stage only
through `stage_id -> ref.stage.stage_id`.

LOR prop UUIDs and preview UUIDs are source-system snapshot metadata. They must
not be stored on, or referenced by, a work order. The legacy
`ops.work_order.display_lor_prop_id` column, index, and foreign key must be
removed after any UUID-only legacy rows are safely mapped to `display_id`.

This boundary allows `ref.display.lor_prop_id` to be refreshed without touching
historical work orders. Resolution procedures must never update work orders as
part of an LOR UUID change.

## Classification and Promotion Semantics

The gate is tied to one explicit immutable snapshot, not to whichever run is newest when a procedure happens to execute.

1. Snapshot ingest commits successfully.
2. Read-only preflight classifies that exact `import_run_id`.
3. Exact matches pass automatically.
4. Deterministic same-UUID matches, same-UUID renames, unique same-name UUID
   relinks, and genuinely new unique displays are eligible automatically.
5. Ambiguous classifications require an operator action, an LOR correction
   followed by a new ingest, an approved exclusion, or documented deferment.
6. `ops.p_lor_evaluate_gate(import_run_id)` recomputes the live classifications.
   It returns `PASSED` when no exceptions remain, `PASSED_WITH_EXCEPTIONS` when
   isolated exceptions are quarantined, and `FAILED` for structural or unsafe
   cross-record inconsistencies.
7. The orchestrator receives the explicit `import_run_id`, promotes stage and
   scene definitions first, safe displays second, and scene assignments last.
8. A stored result alone is insufficient if production identity data changed
   afterward; classification must be revalidated at execution.

A valid snapshot remains historical evidence even when it is blocked. Reconciliation failure must never delete or roll back an already committed snapshot.

## Validated Repository Findings

- `ref.display.display_id` is the primary key.
- `ref.display.lor_prop_id` is uniquely constrained.
- A normalized display-name unique index exists on `upper(btrim(display_name))`.
- Snapshot preview identity is unique by `(import_run_id, id)`.
- Snapshot prop identity is unique by `(import_run_id, prop_id)`.
- `lor_snap.props` has a composite foreign key `(import_run_id, preview_id)` to `lor_snap.previews(import_run_id, id)`.
- Current P2 incorrectly joins props to previews using only `preview_id`; the revised source must use both key columns.
- Current P2 performs name changes, UUID replacement, new-display insertion, and
  ACTIVE-status assignment without the required deterministic classification and
  audit. Revised P2 may retain safe cases only through the classified workflow.
- `lor_snap.preview_wiring_fieldonly_v6` is the established FormView contract and must remain unchanged.

These findings come from the repository schema export and SQL files. They must still be checked against the live production definitions before DDL is approved.

## Required Implementation Order

1. Confirm this design against the current production table definitions and status values.
2. Implement the source view and read-only classification view first.
3. Test their classifications against the current V7 snapshot discrepancies.
4. Implement the run-control and audit tables.
5. Implement controlled action procedures one at a time with rollback tests.
6. Implement the classification summary and row-level promotion eligibility.
7. Add the summary call to `postgres_ingest_from_lor_sqlite_v7.py` after commit.
8. Revise P1 and P2 to accept an explicit classified `import_run_id`.
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
