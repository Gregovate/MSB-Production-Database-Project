# LOR Snapshot Retention Runbook

| Document control | Value |
|---|---|
| Document type | Production database maintenance runbook |
| System | LOR2DB / `lor_snap` |
| Owning issue | #186 |
| Application/database owner | `Gregovate/MSB-Production-Database-Project` |
| Runtime/deployment authority | `Gregovate/MSB-Server-Management` |
| Disposable acceptance authority | `docs/server/PostgreSQL_Disposable_Acceptance_Standard.md` |
| Production deployment authority | `docs/server/Production_Database_Change_Deployment_Runbook.md` |
| Default retention | newest 5 completed snapshots + any non-terminal reconciliation capture |
| Status | CANDIDATE — requires #186 disposable acceptance and explicit Production approval before first live prune |

## Purpose

Keep `lor_snap` as bounded disposable operational storage without discarding the
durable LOR2DB reconciliation, operator-decision, validation, or report history.

The raw snapshot is intentionally **not** the permanent business-history archive.
Current-state provenance such as `ref.lor_scene.source_import_run_id` remains a
useful identifier even after the corresponding raw snapshot is pruned.

This runbook governs routine administrative snapshot retention after migration
`0042_decouple_snapshot_provenance_and_add_retention.sql` is accepted and
installed.

## Safety boundary

Normal retention has two distinct write boundaries:

1. **install/upgrade the retention database contract** using the Production
   Database Change Deployment Runbook; and
2. **prune reviewed snapshots** only after a fresh retention dry run and a
   separately validated rollback archive immediately before deletion.

Do not combine these into an unreviewed one-shot script.

The retention migration itself does **not** delete snapshots.

Never use an ad-hoc command such as:

```sql
DELETE FROM lor_snap.import_run WHERE import_run_id < ...;
```

The governed prune procedure must decide eligibility from current database state
and must receive the exact reviewed candidate ID set.

## Governing retention policy

Default:

```text
KEEP
  newest 5 completed lor_snap imports
  + any import captured by a non-terminal reconciliation

BLOCK
  incomplete ingest rows requiring review

PRUNE
  older completed snapshots not otherwise protected
```

Non-terminal reconciliation states are:

```text
STARTING
PREFLIGHT
AWAITING_DECISIONS
READY_TO_FINISH
PROMOTING
VALIDATING
REPORTING
```

Terminal reconciliation/audit/report rows remain in `ops`; pruning removes the
raw snapshot only.

## Required database objects

Migration `0042` installs:

```text
ops.f_lor_snapshot_retention_plan(integer)
ops.p_prune_lor_snapshots(bigint[], integer)
```

The plan function is read-only. The procedure is administrative and is not
executable by `PUBLIC` or the normal LOR2DB application role.

Migration `0042` also removes only the retention-locking foreign keys from:

```text
ref.lor_scene.source_import_run_id
ref.lor_scene_display.source_import_run_id
ops.lor_reconciliation_action_legacy.import_run_id   (when legacy table exists)
```

The values remain unchanged as provenance.

Internal snapshot ownership relationships remain enforced for:

```text
lor_snap.previews
lor_snap.scenes
lor_snap.props
lor_snap.sub_props
lor_snap.dmx_channels
lor_snap.scene_lor_props
```

## Gate 1 — disposable current-Production acceptance

Before Production installation, the exact candidate SHA must pass the reusable
current-Production clone standard owned by `MSB-Server-Management`.

Production database access during this gate is strictly:

```text
pg_dump + SELECT only
```

All migration, FK, and prune writes occur only inside the disposable clone.

From a clean local checkout on the exact #186 branch/candidate:

```powershell
.\LOR2DB\02_Reconciliation\reconciliation\acceptance\run_lor_snapshot_retention_disposable_acceptance.ps1 `
    -CandidateSha '<exact-candidate-sha>' `
    -TargetRef 'agent/lor2db-186-snapshot-retention'
```

The disposable gate must prove at minimum:

- exact candidate LOR2DB regression passes;
- current Production custom-format dump restores successfully into the isolated
  `postgis/postgis:16-3.5` disposable container;
- migration `0042` installs only on the disposable clone;
- validation `37` passes;
- newest-five protection works;
- non-terminal reconciliation protection works;
- intentionally wrong/stale expected prune IDs are rejected before deletion;
- an unexpected future FK to `lor_snap.import_run` is rejected before deletion;
- a real destructive prune succeeds on the disposable clone;
- latest completed ingest is unchanged;
- `ref.lor_scene` / `ref.lor_scene_display` content is unchanged;
- durable reconciliation/frozen evidence is unchanged;
- legacy reconciliation action evidence is unchanged;
- at least one historical report can still be rendered from frozen evidence
  after its raw snapshot is pruned;
- a second prune is a no-op;
- the pruned disposable logical dump is smaller than the source Production dump;
- Production fingerprint and live shared checkout remain unchanged.

A disposable PASS does not authorize Production mutation.

## Gate 2 — install migration 0042 in Production

**Authority:** `Gregovate/MSB-Server-Management` —
`docs/server/Production_Database_Change_Deployment_Runbook.md`

Follow that runbook exactly for the accepted candidate SHA. In particular:

1. verify the exact live checkout and clean worktree;
2. verify Production health before mutation;
3. capture read-only Production invariants;
4. verify target ancestry;
5. run detached candidate regression;
6. create and validate the custom-format rollback archive **before mutation**;
7. run database preflight;
8. apply **only** migration `0042`;
9. run validation `37`;
10. validate least privilege and Production invariants;
11. advance/restart shared application checkout/services only when the accepted
    candidate actually changes those deployed sources;
12. retain rollback archive and deployment report.

### Mandatory stop after installation

After migration `0042` and validation `37` pass, **stop before pruning**.

Installation and destructive retention are intentionally separate inspected
Production mutations.

## Gate 3 — Production retention dry run

Run as the governed administrative database actor.

Filename/comment for DBeaver history:

```text
#186 — LOR snapshot retention dry run — READ ONLY
```

```sql
SELECT
    p.import_run_id,
    p.run_ts,
    p.ingest_completed_at,
    p.completed_recency_rank,
    p.lor_reconciliation_run_id,
    p.reconciliation_status,
    p.retention_disposition,
    p.retention_reason,
    p.preview_rows,
    p.scene_rows,
    p.prop_rows,
    p.sub_prop_rows,
    p.dmx_channel_rows,
    p.scene_lor_prop_rows,
    p.total_snapshot_rows
FROM ops.f_lor_snapshot_retention_plan(5) AS p
ORDER BY p.import_run_id DESC;
```

Then capture the exact proposed prune array:

```sql
SELECT coalesce(
           array_agg(p.import_run_id ORDER BY p.import_run_id),
           ARRAY[]::bigint[]
       ) AS exact_prune_ids
FROM ops.f_lor_snapshot_retention_plan(5) AS p
WHERE p.retention_disposition = 'PRUNE';
```

### Dry-run review requirements

Do not proceed unless all are true:

- newest five completed snapshots are `KEEP`;
- every non-terminal reconciliation capture is `KEEP`;
- no expected current/open run is marked `PRUNE`;
- every `BLOCK` row has been understood;
- proposed PRUNE IDs are reasonable for the current Production date/state;
- latest completed ingest matches the LOR2DB dashboard/current snapshot;
- no unrelated Production change is in progress that would invalidate the plan.

If anything is unexpected, stop. Do not substitute a hand-edited ID list.

## Gate 4 — fresh rollback archive immediately before prune

Snapshot deletion is destructive. Even if migration deployment already created a
rollback archive, create and validate a **fresh post-migration, pre-prune**
custom-format PostgreSQL archive immediately before the prune.

Use the rollback archive contract from the Production Database Change Deployment
Runbook:

```bash
sudo docker exec msb-postgres \
  pg_dump -U msbadmin -d msb -Fc > "$BACKUP_FILE"

test -s "$BACKUP_FILE"
sha256sum "$BACKUP_FILE"
sudo docker exec -i msb-postgres pg_restore --list < "$BACKUP_FILE" >/dev/null
```

Record the archive path, size, and SHA-256 in the Production retention evidence.

If archive creation or validation fails, stop before pruning.

## Gate 5 — controlled Production prune

Re-run the dry-run query immediately before the write. The exact candidate set
must still equal the reviewed array.

Filename/comment for DBeaver history:

```text
#186 — governed LOR snapshot prune — PRODUCTION WRITE
```

Call the procedure with the **exact array produced by the reviewed dry run**:

```sql
CALL ops.p_prune_lor_snapshots(
    ARRAY[/* exact reviewed import_run_id values */]::bigint[],
    5
);
```

Do not substitute a range predicate or manually add/remove IDs.

The procedure recomputes the plan under an advisory transaction lock. If the
current PRUNE set differs from the reviewed array, it raises and deletes nothing.
It also aborts before deletion if a new unexpected FK references
`lor_snap.import_run`.

## Gate 6 — post-prune validation

Immediately run:

```sql
SELECT
    p.import_run_id,
    p.completed_recency_rank,
    p.lor_reconciliation_run_id,
    p.reconciliation_status,
    p.retention_disposition,
    p.retention_reason,
    p.total_snapshot_rows
FROM ops.f_lor_snapshot_retention_plan(5) AS p
ORDER BY p.import_run_id DESC;
```

Expected:

```text
zero PRUNE rows
newest five completed snapshots remain
all non-terminal reconciliation captures remain
latest completed import_run_id is unchanged
```

Also verify:

```sql
SELECT count(*) AS retained_import_runs
FROM lor_snap.import_run;

SELECT
    count(*) AS scene_provenance_without_raw_snapshot
FROM ref.lor_scene AS s
LEFT JOIN lor_snap.import_run AS ir
  ON ir.import_run_id = s.source_import_run_id
WHERE ir.import_run_id IS NULL;

SELECT
    count(*) AS membership_provenance_without_raw_snapshot
FROM ref.lor_scene_display AS sd
LEFT JOIN lor_snap.import_run AS ir
  ON ir.import_run_id = sd.source_import_run_id
WHERE ir.import_run_id IS NULL;
```

Nonzero provenance-without-raw-snapshot counts are expected after decoupling and
are not broken references; the numeric provenance remains intentionally durable.

Then verify:

- LOR2DB dashboard loads and identifies the same latest snapshot;
- report archive loads;
- at least one older reconciliation report opens normally;
- current Scene/Display behavior remains normal;
- no open reconciliation state changed unexpectedly.

## Dump-size evidence

Capture a post-prune custom-format logical dump size and compare it with the
pre-prune rollback archive or disposable-acceptance baseline. Record both sizes
on #186 / the acceptance record.

The objective is to reduce repeated logical backup/clone payload. Physical table
files do not need to shrink immediately for this issue to pass.

## Vacuum policy

Do **not** run `VACUUM FULL` as routine snapshot retention. It rewrites and locks
relations and is not required to reduce future logical dump payload.

Ordinary autovacuum may reclaim dead space for reuse. A separate ordinary
`VACUUM (ANALYZE)` may be considered after the prune only if normal PostgreSQL
maintenance evidence warrants it; it is not required for the initial #186
retention acceptance.

## Failure / rollback

If migration installation fails, use the reviewed rollback behavior from the
Production Database Change Deployment Runbook and stop.

If the prune procedure raises before commit, the `CALL` transaction rolls back;
do not improvise a replacement `DELETE`.

If post-prune validation discovers a material defect after the deletion
committed, stop further LOR2DB writes and use the validated **post-migration,
pre-prune** rollback archive according to the Production Database recovery/
deployment authority. Record the failure on #186 before retrying.

## Routine future use

After #186 Production acceptance, normal periodic retention is:

```text
read runbook
-> fresh dry run
-> review exact PRUNE set
-> validated rollback archive
-> exact guarded CALL
-> post-prune validation
-> record evidence
```

Do not prune merely because the database or backup "looks large". The governed
plan is the authority for which snapshots are disposable at execution time.
