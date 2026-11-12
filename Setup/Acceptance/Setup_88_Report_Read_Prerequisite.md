# #88 Container Movement — read prerequisite

| Document control | Value |
|---|---|
| Status | PRODUCTION SERVER PASS 2026-10-08; protected browser check and archive identity transcription pending |
| Reviewed | 2026-10-08 America/Chicago |
| Owning issues | #88, #122 |
| Installed permission migration | `Setup/Database/071_grant_setup_container_type_report_read.sql` |
| Frozen grant/clone-artifact source | `6b04d1afff67e2b79a068316198ee7ad95a635f7` |
| Frozen source tree | `73a3454c4da0838a87a3fce117d7fc58039048ba` |
| Integration | PR #310 report; #312 prerequisite; #313/#314/#315 tooling; execution main `cc93378f6ad62f353c5994860ebd98dff54a86aa` |
| Exact migration blob | `1fd5de8f3de7665336e0eabead498e94ed915883` |
| Corrected disposable runner blob | `2025db912621f8258356cdb3e7f474ea0ca763f1`; separate tooling identity, not application/migration source |
| Application | Existing approved V0.3.50 / `6c44a082dd520b75881c50ad2ce78feb029ff87d`; unchanged |
| Current live proof | Server PASS: V0.3.50 / `6c44a082dd520b75881c50ad2ce78feb029ff87d`; previous source `cb0538022ed066ff90675e832daa1cd95488114a` |
| Production permission change / report installation | APPLIED; server PASS; protected browser PENDING |

## October 8 — Production server PASS

Greg supplied the completed combined runner receipt at 16:43 CDT:

```text
Setup #88: grant and report frozen validation PASS; returning to service
Setup #88: grant and report server PASS; protected browser check pending
PASS: grant and report server PASS; protected browser check pending; report: /home/msbadmin/setup-deployment-reports/Setup88Read-20261008T214153Z
```

The retained report began at 16:41:53 CDT. Greg noted “About 20 seconds”; the
timed phase was not specified. This is the actual terminal receipt, not an
engineering-only acceptance.
Under the pinned runner, final PASS follows current-clone acceptance, exact report
regression, controller ON/freeze/validated snapshot, migration 071, frozen row/ACL
preservation, exact Setup source promotion, controller OFF/ONLINE/unfenced service
proof, V0.3.50 health, deployed focused regression, application-role report reads,
clean source pins and owned worktree cleanup. It reports no rollback or failed
gate. Shared source remains `6dd05c4aa5ef8f50fe172145c3ae281cc245a101`.

The only Production SQL change is the two-column SELECT grant. Current Setup is
exact `6c44a082dd520b75881c50ad2ce78feb029ff87d`, not the newer tooling/docs main.
The report remains read-only; guided #309, migration 070, historical attachment
repair and takedown loading are not installed by this release.

Protected browser verification remains PENDING: refresh the normal Setup route,
confirm Client/server V0.3.50 and Updated 2026-10-08, open Material Status →
Container Movement, and verify fresh recorded/calculated destination evidence and
GPS feet. No test movements are needed. Do not rerun the grant/installer after
this successful receipt. Keep the report's `state.json`, `result.json`,
`snapshot.json` and `report-directory.txt`; archive path/hash and child-report
identity have not yet been transcribed from those artifacts. Final browser and
cross-repository runtime closeout remain open until that evidence is supplied.

## Failure and concrete correction

### 2026-10-08 14:50 CDT — disposable ACL export STOP

The combined runner stopped during ONLINE preflight, before controller ON,
Production migration or Setup source promotion. Retained deployment report:
`/home/msbadmin/setup-deployment-reports/Setup88Read-20261008T195058Z`.
Its child report is
`/home/msbadmin/setup-acceptance-reports/Setup_Disposable_Acceptance_20261008T195100.txt`.
The exact 6b04 candidate passed **716 Application tests / 2 skipped** and restored
the current-Production clone, then failed with `Production read ACL extraction
was empty` (exit 23). Disposable cleanup ran. Production Setup fingerprints
before/after both equal `9d6f8d09a129ba7cbd839c4286c8d8c0`; live Setup remained
`cb0538022ed066ff90675e832daa1cd95488114a` before/after.

This was a tooling defect, not evidence that Production has no application read
permissions. The shell redirected the host SQL file to `docker exec` without
`-i`; Docker did not forward stdin, so psql exited without executing the exporter.
The server standard already requires `docker exec -i` for host-file SQL input.
The corrected reusable shell keeps that flag. The combined launcher loads its
separately pinned Git blob and verifies exact bytes before execution; copying the
old shell from frozen 6b04 would repeat the failure. Candidate application,
migration and validation SQL still come from the original frozen artifacts.

Engineering acceptance: **809 full Setup passed / 1 optional native PostgreSQL
check skipped**; **61 targeted passed**. Executed shell transport tests prove
host-file delivery and clone replay, reproduce the old missing-flag failure, and
stop before replay on empty/failed SQL exports. Their Docker CLI double models
stdin attachment; this is not a real host/container acceptance claim. Runner
selection tests prove the corrected blob is used with the frozen candidate and
reject altered bytes. PostgreSQL/WASM exact migration, six report queries and
least-privilege proof PASS; shell syntax and diff whitespace checks PASS.

The old run is complete and failed before mutation. A new invocation is permitted
only from merged corrected tooling; it rechecks ONLINE/services/backups, exact
sources and missing-grant baseline, then reruns current-clone acceptance before
entering the existing single maintenance window. Do not resume the old process,
manually grant reads or alter maintenance. Actual host acceptance, installation
and protected browser verification remain pending.

### Original report read denial

The October 8 source-only installer correctly stopped before mutation when the
exact application-role query joined `ref.container_type`. Administrative fixture
acceptance had missed the real runtime read boundary. The retained attempt is
`/home/msbadmin/setup-deployment-reports/Setup88Report-20261008T151700Z/report.txt`.

The proposed migration's only persistent change is:

```sql
GRANT SELECT (container_type_id, container_type_name)
    ON TABLE ref.container_type TO fieldwiring_app;
```

This keeps live reference names authoritative and preserves the reviewed type
labels and Standalone/single-Display Pallet warnings. It creates no tables,
columns, functions or views, changes no field records, and grants no write
privileges. Additional type columns remain unreadable. Migration 070 belongs to
the separate guided-contents draft; this prerequisite does not depend on it.

## Engineering acceptance

`test_setup_88_report_read_privilege.mjs` creates an isolated PostgreSQL/WASM
database and a runtime role with the existing report reads but no Container-type
grant. It reproduces the exact denial, applies the actual proposed SQL, executes
all six statements extracted from the actual report source as `fieldwiring_app`
inside a read-only repeatable-read transaction, and checks Session scope,
Container-only observations, active Displays and attached/detached/unassigned
positions. It proves type records unchanged and rejects reads of an additional
private column plus INSERT, UPDATE, DELETE and TRUNCATE. PASS on October 8.

Engineering invocation uses an already installed `@electric-sql/pglite` module
via `PGLITE_MODULE` and Python via `PYTHON` (default python3). This does not require
Node on Greg's workstation. This synthetic proof is not current-Production-clone
acceptance and does not authorize Production mutation.

Full Setup after launcher integration: **787 passed / 1 optional native
PostgreSQL engineering check skipped**. The PostgreSQL/WASM test also executes
the actual committed SQL validation and ACL/row preservation queries. Twelve
new failure-path/ordering/transport tests pass. Focused report/application/installer and
isolated Current Location checks are retained. The only Application changes
since the reviewed report are documentation and the existing engineering ACL
batch-order contract; runtime/UI and source installer remain unchanged.

## Authorization and controlled launcher

At October 8 10:33 CDT Greg approved including this two-column read prerequisite
in the report deployment. Application runtime/UI bytes remain the reviewed
V0.3.50 source. The new permission prerequisite and launcher are separate
identities; the server still installs exact application `6c44a082`, not a newer
migration-bearing branch head. No visible workflow change is introduced by this
infrastructure prerequisite.

`run_setup_88_report_read_deploy.ps1` transfers one bundle and runs one bounded
foreground SSH session. It verifies clean merged main and committed transport
files. The server runner reuses `setup_maintenance_deploy.py` for command logging,
journaling, real controller access, current freeze checks and cleanup; both that
helper and the unchanged report installer are verified against pinned Git blobs.
No GitHub credential prompt or shared checkout promotion is permitted.

The controlled sequence is:

1. Healthy real ONLINE/controller/backup chain, exact clean live/shared source,
   stopped preview, missing type-read baseline, merged target and migration blob.
2. Existing reusable disposable acceptance runner, **once**, with actual Production
   schema/table/column SELECT replay. Earlier previews' blanket clone reads masked
   this dependency; permission-sensitive acceptance now opts into exact effective
   reads. Production remains ONLINE; no credentials or write grants are copied.
3. Current clone restore, full Application regression, migration 071 on the clone,
   and exact committed report/least-privilege validation. Cleanup before maintenance.
   Prepare the exact report worktree and run its full and isolated focused
   regressions, version and UI-date gates while Production is still ONLINE.
   Reuse the pinned helper's tests; no ONLINE fingerprint equality gate.
4. Recheck live state. Controller ON, current freeze proof, retained validated
   rollback snapshot, all ref/ops row hashes and Container-type ACL evidence.
5. Apply only verified migration 071. Exact report statements run READ ONLY as
   `fieldwiring_app`; all ref/ops rows and every unapproved type ACL must match.
6. After the grant validates, advance only Setup to `6c44a082` / V0.3.50 while
   the same controller fence remains active. Run deployed focused tests and exact
   role SELECTs. All ref/ops rows and unapproved type ACLs must still match the
   frozen baseline before OFF. Shared checkout stays pinned.
7. Controller OFF restores the services at the new Setup source. Require current
   ONLINE/unfenced/services, V0.3.50 health, isolated focused tests, real role
   SELECTs and exact clean source identities. Normal work may resume immediately;
   no frozen fingerprint comparison or operator pause crosses this boundary.
   Retain the source helper report directory and promotion state in every journal.

The disposable clone is restored once for this run. The later frozen rollback
snapshot is a Production recovery archive, not another disposable download or
restore. `-PreflightOnly` is available for diagnosis but is not a required extra
run; the authorized default completes the sequence above.

## Authority and failure boundary

Retrieved/read in this workstream:

- [Production Database Change Deployment Runbook](https://github.com/Gregovate/MSB-Server-Management/blob/main/docs/server/Production_Database_Change_Deployment_Runbook.md), blob `d307771d15baf27b0086b8c421c0c84146b74887`.
  The combined prerequisite/Setup promotion section is recorded by Server Management
  PR #67, updated blob `d185c0bf183b1d7d3a7cb5b432142f80e36de123`.
- [Production Database Maintenance Mode](https://github.com/Gregovate/MSB-Server-Management/blob/main/docs/server/Production_Database_Maintenance_Mode.md), blob `919da2182d6d211d789c213ab37b3bdb085f8208`.
- [PostgreSQL Disposable Acceptance Standard](https://github.com/Gregovate/MSB-Server-Management/blob/main/docs/server/PostgreSQL_Disposable_Acceptance_Standard.md).
- [Setup Source-Only Application Deployment Runbook](https://github.com/Gregovate/MSB-Server-Management/blob/main/docs/server/Setup_Source_Only_Application_Deployment_Runbook.md), blob `4d243cc8b0c712fd47a38b77ef0a83ac474bbf77`.
- [Runbook-First Production Rule](../../System_Documentation/Project_Rules/Runbook_First_Production_Rule.md).

This chat owns the window. Do not use the maintenance dashboard or another
Deployment chat while the runner is active. The server controller enforces the
write freeze for both grant and source promotion; no operator edit pause is
required before or after maintenance. No new browser preview is needed for an unchanged
reviewed UI; current-clone/permission checks are required.

Any failed maintenance/grant gate stops without automatic OFF, grant retry,
inverse SQL or database restore. Inspect the retained journal and controller
state. An interrupted psql command does not prove rollback; inspect actual ACLs.
Any frozen source-promotion or preservation failure also keeps maintenance
closed; it must not restart a writer or call the standalone source installer.
After OFF is proven, a failed live application check uses the existing source
rollback only after a fresh ONLINE/unfenced check and exact-source guard; the
approved read grant and legitimate new work remain. Do not restore a whole database
or revoke access that existed before this prerequisite.

## Workstation handoff after integration

From the confirmed clean laptop main checkout `C:\lor\ImportExport\VSCode`, pull
merged main and run `Setup/Acceptance/run_setup_88_report_read_deploy.ps1`.
Use this combined launcher, not a blind repeat of the failed source-only handoff.
On PASS, refresh protected Setup and confirm V0.3.50, Updated 2026-10-08, then
Material Status → Container Movement. On STOP, retain the printed report path;
do not rerun or change maintenance state.

Production installation is now supported by the server PASS receipt above.
Protected browser acceptance and archive path/hash transcription remain pending.
Closeout must retain the clone receipt, granted columns, ONLINE proof, actual app
SHA and report/browser result. Do not repeat the installed grant.

## October 8 11:04 CDT — workstation transport guard correction

The first combined-launcher attempt stopped in its local packaging guard with
`STOP: uncommitted file setup_maintenance_deploy.py` even though the checkout was
clean. No SCP/SSH, clone, maintenance entry, grant, or report install occurred.
The helper's committed blob has mixed line endings. With Windows Git filtering,
`hash-object --path` may normalize that clean file and disagree with its stored
blob. This is a tooling defect, not an operator edit.

The wrapper now calls the workstation's existing Python packager. It reads exact
committed blobs through Git's binary stdout, verifies each blob hash, compares
local bytes after the established CR removal, and packages only committed LF
bytes. Real code differences still fail before transfer. Server helper/transport
pins, frozen grant/clone source, migration, report source and execution sequence
are unchanged. No Node or new workstation package is required.

Four real-Git regressions pass: reproduce the hash mismatch in a clean checkout
with `core.autocrlf=true`, verify exact pinned transport bytes, accept CRLF without
changing packaged bytes, reject actual code changes, and reject a missing blob.
Full Setup after this correction: **791 passed / one optional native engineering
check skipped**. The corrected launcher must be pulled from merged main before
execution; do not edit/reset the helper locally to satisfy the old guard.

## October 8 backup recovery and maintenance ordering correction

The retained combined attempt `Setup88Read-20261008T161235Z` stopped on the first
ONLINE backup check: `Backup chain not current`. Maintenance and migration never
started. An unreadable root-owned October 5 rollback dump made NAS replication
exit 23 before Directus copies. Server Management #65/#66 record the one-file
owner repair, unchanged archive hash/mode, successful replication at 14:11:57 CDT
and current matching local/NAS backups plus ONLINE/unfenced services.

At 14:20 CDT Greg rejected a manual operator pause and directed use of the real
server maintenance routine. At 14:20:48 he confirmed **no new run had started**.
The old combined ordering (OFF before report install) is superseded. The corrected
runner prepares all exact report regressions ONLINE, uses one existing controller
ON/freeze/snapshot boundary for the grant and report promotion, compares all
preservation evidence while frozen, then uses controller OFF and live checks.
It reuses the unchanged pinned source helper methods; it does not invoke that
helper's standalone ONLINE deployment routine. Application/UI, grant/clone pin,
migration bytes, shared source and transport helper pins do not change.

Failure tests cover partial checkout, frozen source tests/probes/preservation,
OFF failure, live source rollback, controller drift, retained promotion journal
and legitimate operator work immediately after OFF. The terminal now prints the
failed gate reason beside the retained report path. Actual current-clone and
Production installation remain pending until the corrected host run passes.

Engineering acceptance of the one-window correction: **803 full Setup passed / 1
optional native PostgreSQL check skipped**; **55 targeted report/orchestration/
transport/legacy-installer checks passed**. The unchanged migration/exact report
SQL least-privilege proof also passes in PostgreSQL/WASM. Simulated absence of
`fcntl`: **27 portable tests passed / 2 Linux-only checks skipped**, with no
collection error. No Node install or new workstation package is required.
