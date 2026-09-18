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
| Status | PRODUCTION — accepted and activated 2026-09-17; steady-state automatic retention is active |

## Purpose

Keep `lor_snap` as bounded disposable operational storage without discarding the
durable LOR2DB reconciliation, operator-decision, validation, or report history.

The raw snapshot is intentionally **not** the permanent business-history archive.
Current-state provenance such as `ref.lor_scene.source_import_run_id` remains a
useful identifier even after the corresponding raw snapshot is pruned.

This runbook governs the completed initial historical cleanup and the active
steady-state automatic snapshot-retention contract installed by
`0042_decouple_snapshot_provenance_and_add_retention.sql`.

## Safety boundary

Retention has two operating modes:

1. **initial deployment / historical cleanup** — install the retention database
   contract, run a reviewed dry run, create a validated rollback archive, and
   perform the first bulk prune as a separately approved Production mutation;
2. **steady-state automatic retention** — the immutable reconciliation report
   first records the complete bounded-retention plan that exists before report
   publication finishes; after that report is successfully published and the
   run is terminal, the LOR2DB backend invokes the fixed-policy automatic
   retention procedure.

The initial historical cleanup completed on 2026-09-17 before backend V0.6.3
automatic retention was activated. The initial-rollout gates below remain the
governed deployment/recovery record; routine operation follows **Routine future
use**.

Migration `0042` itself does **not** delete snapshots. The automatic entry point
is parameterless, always keeps the newest five completed snapshots, and aborts
without deleting anything if the retention plan contains any `BLOCK` row.

The immutable report is the durable historical record of the retention state at
report time. Report framework V0.7.0 records both the detailed `KEEP` set and the
complete pre-cleanup `KEEP` / `PRUNE` / `BLOCK` inventory before automatic
retention runs. Those report rows remain after eligible raw snapshots are later
removed.

Never use an ad-hoc command such as:

```sql
DELETE FROM lor_snap.import_run WHERE import_run_id < ...;
```

The governed manual prune procedure must decide eligibility from current database
state and must receive the exact reviewed candidate ID set. The normal
steady-state application path must use only the fixed-policy automatic procedure.

## Governing retention policy

Default:

```text
KEEP
  newest 5 completed lor_snap imports
  + any import captured by a non-terminal reconciliation

PRUNE
  recognized legacy pre-completion-tracking snapshots not otherwise protected
  + older completed snapshots not otherwise protected

BLOCK
  NULL-completion snapshots that do not match the recognized legacy profile
  and therefore require operator review
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

A recognized legacy pre-completion-tracking snapshot has
`ingest_completed_at IS NULL` and also lacks every modern ingest marker used by
the retention classifier:

```text
parser_version
ingest_script_version
ingest_started_at
preview_count
scene_count
prop_count
sub_prop_count
dmx_channel_count
scene_lor_prop_count
```

This narrow legacy rule exists for the historical snapshots created before the
current atomic ingest-completion contract. A future or otherwise unexpected
NULL-completion row carrying any of those modern markers remains `BLOCK`, not
`PRUNE`. Non-terminal reconciliation protection takes precedence over both
classifications.

Terminal reconciliation/audit/report rows remain in `ops`; pruning removes the
raw snapshot only.

## Required database objects

Migration `0042` installs:

```text
ops.f_lor_snapshot_retention_plan(integer)
ops.p_prune_lor_snapshots(bigint[], integer)
ops.p_run_lor_snapshot_retention()
```

The plan function is read-only. `ops.p_prune_lor_snapshots(...)` is the guarded
administrative/manual recovery path and is not executable by `PUBLIC` or the
normal LOR2DB application role.

`ops.p_run_lor_snapshot_retention()` is the fixed-policy application entry point.
It uses the default keep count of five, refuses to proceed when any `BLOCK` row
exists, derives the current PRUNE set itself, and delegates deletion through the
guarded prune procedure. `PUBLIC` cannot execute it.

The LOR2DB application role receives only the two #186 permissions required by
the application/report workflow through the reviewed grant script:

```text
EXECUTE ops.f_lor_snapshot_retention_plan(integer)   read-only report evidence
EXECUTE ops.p_run_lor_snapshot_retention()           fixed-policy cleanup
```

It still cannot execute the arbitrary-ID administrative
`ops.p_prune_lor_snapshots(...)` procedure.

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

## Production acceptance and activation record

Issue #186 completed its governed Production rollout on 2026-09-17.

```text
Accepted candidate SHA:  c536243f64ef17d37aadf56300a0932881cac579
Migration / validation:  0042 / 37
Initial prune:           54 raw snapshots deleted
Retained working set:    {60,61,62,63,64}
Raw snapshot rows:       252120 -> 26866
Logical dump bytes:      16737949 -> 8061378 (51.84% reduction)
Backend:                 V0.6.3
Report framework:        V0.7.0
Browser frontend:        V0.5.4 (preflight.js?v=0.5.4)
Implementation PR:       #203
Merge commit:            0a8214a7cc03cb4ee018b719bba248a5c6ff573d
Public smoke:            PASS
```

The initial database contract installation, explicit 54-snapshot prune, backend
activation, Synology frontend activation, and public authenticated smoke check
all completed successfully. Durable reconciliation/current-state fingerprints
were unchanged by the prune and backend activation. Rollback archives/backups
were retained as recorded on Issue #186.

## Gate 1 — disposable current-Production acceptance

The initial Production installation used the exact accepted candidate SHA and
passed the reusable current-Production clone standard owned by
`MSB-Server-Management`. Requalification of this contract must use the same
standard.

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
- recognized legacy pre-completion-tracking snapshots are classified `PRUNE`;
- any NULL-completion row with modern ingest markers is classified `BLOCK`;
- the automatic entry point refuses to prune while any `BLOCK` row exists;
- intentionally wrong/stale expected prune IDs are rejected before deletion;
- an unexpected future FK to `lor_snap.import_run` is rejected before deletion;
- a real destructive prune succeeds through the fixed-policy automatic retention
  entry point on the disposable clone;
- latest completed ingest is unchanged;
- `ref.lor_scene` / `ref.lor_scene_display` content is unchanged;
- durable reconciliation/frozen evidence is unchanged;
- legacy reconciliation action evidence is unchanged;
- the report framework can read the governed retention-plan function and render
  a complete pre-cleanup snapshot inventory without direct raw-table access;
- at least one historical report can still be rendered from frozen evidence
  after its raw snapshot is pruned;
- a second automatic retention call is a no-op;
- the pruned disposable logical dump is smaller than the source Production dump;
- Production fingerprint and live shared checkout remain unchanged.

A disposable PASS does not authorize Production mutation.

## Gate 2 — install the database retention contract in Production

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
8. apply migration `0042`;
9. run validation `37`;
10. apply the reviewed `LOR2DB/Application/grant_lor_preflight_app.sql` grant
    update so `lor_preflight_app` can execute the read-only retention plan for
    report evidence and the fixed-policy automatic retention entry point, while
    still being unable to execute the arbitrary-ID manual prune procedure;
11. validate least privilege and Production invariants;
12. retain the rollback archive and deployment report.

During the initial rollout, backend V0.6.3, report publisher V0.7.0, and
preflight.js V0.5.4 were intentionally held until the reviewed historical cleanup
completed. That sequencing completed successfully on 2026-09-17.

### Mandatory stop after installation

After migration `0042`, validation `37`, and the reviewed grant update pass,
**stop before pruning**.

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
- legacy NULL-completion rows are `PRUNE` only with reason
  `LEGACY_PRE_COMPLETION_TRACKING_SNAPSHOT`;
- any other NULL-completion row is `BLOCK` with reason
  `INCOMPLETE_INGEST_REQUIRES_REVIEW`;
- every `BLOCK` row has been understood;
- proposed PRUNE IDs are reasonable for the current Production date/state;
- latest completed ingest matches the LOR2DB dashboard/current snapshot;
- no unrelated Production change is in progress that would invalidate the plan.

If anything is unexpected, stop. Do not substitute a hand-edited ID list.

## Gate 4 — fresh rollback archive immediately before initial prune

The one-time historical snapshot deletion is destructive. Even if migration
deployment already created a rollback archive, create and validate a **fresh
post-migration, pre-prune** custom-format PostgreSQL archive immediately before
this first bulk prune.

This extra per-prune archive requirement applies to the initial bulk cleanup and
to later manual recovery prunes. It is not performed after every successful
reconciliation once fixed-policy automatic steady-state retention is activated.

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

## Gate 5 — controlled initial Production prune

Re-run the dry-run query immediately before the write. The exact candidate set
must still equal the reviewed array.

Filename/comment for DBeaver history:

```text
#186 — governed LOR snapshot initial prune — PRODUCTION WRITE
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
zero unexplained BLOCK rows
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

## Gate 7 — activate automatic steady-state retention

Activate automatic retention only after Gates 2 through 6 have completed and the
historical backlog has been reduced to the intended bounded working set.

Because #186 changes the deployed backend, report contents, and operator-visible
failure handling, the exact accepted candidate must also complete the applicable
pre-production browser review before live application activation.

Deploy the accepted candidate's LOR2DB application/report unit together:

```text
backend.py                               V0.6.3
publish_lor_reconciliation_report.py     V0.7.0
preflight.js                             V0.5.4
index.html                               references preflight.js?v=0.5.4
grant_lor_preflight_app.sql              V0.3.3
```

Restart/validate the LOR preflight service using the normal Production
application deployment authority. Confirm its health endpoint reports backend
V0.6.3 and that the browser receives the current V0.5.4 script.

Steady-state sequence:

```text
Finish / report retry / cancellation report
-> report publisher captures ops.f_lor_snapshot_retention_plan(5)
-> immutable report contains retained snapshots + full pre-cleanup inventory
-> publisher commits REPORTING -> terminal status
-> backend calls ops.p_run_lor_snapshot_retention()
-> newest five completed snapshots + all non-terminal captures remain
```

The report therefore preserves the exact snapshot state that existed before the
post-report cleanup, including snapshots that are deleted immediately afterward.

`ops.p_run_lor_snapshot_retention()` is intentionally parameterless. The
application cannot supply snapshot IDs or lower the keep count.

If the automatic plan contains any `BLOCK` row or encounters another fail-closed
dependency, automatic deletion does not occur. The already-published report and
terminal reconciliation remain successful. The backend logs the cleanup failure
and returns a non-fatal warning to the browser. Review the retention plan and use
the manual administrative gates in this runbook only when intervention is
actually required.

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

If the manual prune procedure raises before commit, the `CALL` transaction rolls
back; do not improvise a replacement `DELETE`.

If post-prune validation discovers a material defect after the initial manual
deletion committed, stop further LOR2DB writes and use the validated
**post-migration, pre-prune** rollback archive according to the Production
Database recovery/deployment authority. Record the failure on #186 before
retrying.

A steady-state automatic-retention failure is different: the published report
and terminal reconciliation are already committed and remain valid. The backend
must not convert that completed business operation into a failure. Investigate
the logged retention warning and the dry-run plan; use the manual recovery path
only if intervention is required.

## Routine future use

Production acceptance is complete. Normal retention is automatic; the operator
does not need to remember a periodic cleanup task.

```text
successful report publication
-> immutable report records the pre-cleanup retention state
-> reconciliation becomes terminal
-> backend invokes fixed-policy automatic retention
-> no warning: cleanup is complete or there was nothing eligible
-> warning: reconciliation/report remain complete; investigate retention only
   when needed
```

The manual dry-run / backup / exact-ID prune path remains the administrative
fallback for exceptional recovery or reviewed intervention. Do not perform
manual pruning merely because the database or backup "looks large". The
governed plan remains the authority for which snapshots are disposable.
