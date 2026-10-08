# #88 Container Movement — read prerequisite

| Document control | Value |
|---|---|
| Status | AUTHORIZED 2026-10-08 10:33 CDT; prepared runner/engineering proof PASS; host acceptance/deployment pending |
| Reviewed | 2026-10-08 America/Chicago |
| Owning issues | #88, #122 |
| Proposed permission migration | `Setup/Database/071_grant_setup_container_type_report_read.sql` |
| Frozen grant/clone-artifact source | `6b04d1afff67e2b79a068316198ee7ad95a635f7` |
| Frozen source tree | `73a3454c4da0838a87a3fce117d7fc58039048ba` |
| Integration | PR #312; merge before execution |
| Exact migration blob | `1fd5de8f3de7665336e0eabead498e94ed915883` |
| Application | Existing approved V0.3.50 / `6c44a082dd520b75881c50ad2ce78feb029ff87d`; unchanged |
| Current live proof | V0.3.42 / `cb0538022ed066ff90675e832daa1cd95488114a`; healthy |
| Production permission change / report installation | NOT APPLIED |

## Failure and concrete correction

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
4. Recheck live state. Controller ON, current freeze proof, retained validated
   rollback snapshot, all ref/ops row hashes and Container-type ACL evidence.
5. Apply only verified migration 071. Exact report statements run READ ONLY as
   `fieldwiring_app`; all ref/ops rows and every unapproved type ACL must match.
6. Controller OFF, ONLINE/health proof, unchanged V0.3.42 and shared checkout.
7. Invoke the unchanged report Installer under the same cooperative lock. Its
   merged/forward source guards, real role query probe, full/focused tests,
   preservation comparisons and old-source rollback remain. Only Setup advances
   to `6c44a082` / V0.3.50. Report directory is retained separately and linked.

The disposable clone is restored once for this run. The later frozen rollback
snapshot is a Production recovery archive, not another disposable download or
restore. `-PreflightOnly` is available for diagnosis but is not a required extra
run; the authorized default completes the sequence above.

## Authority and failure boundary

Retrieved/read in this workstream:

- [Production Database Change Deployment Runbook](https://github.com/Gregovate/MSB-Server-Management/blob/main/docs/server/Production_Database_Change_Deployment_Runbook.md), blob `d307771d15baf27b0086b8c421c0c84146b74887`.
- [Production Database Maintenance Mode](https://github.com/Gregovate/MSB-Server-Management/blob/main/docs/server/Production_Database_Maintenance_Mode.md), blob `919da2182d6d211d789c213ab37b3bdb085f8208`.
- [PostgreSQL Disposable Acceptance Standard](https://github.com/Gregovate/MSB-Server-Management/blob/main/docs/server/PostgreSQL_Disposable_Acceptance_Standard.md).
- [Setup Source-Only Application Deployment Runbook](https://github.com/Gregovate/MSB-Server-Management/blob/main/docs/server/Setup_Source_Only_Application_Deployment_Runbook.md), blob `4d243cc8b0c712fd47a38b77ef0a83ac474bbf77`.
- [Runbook-First Production Rule](../../System_Documentation/Project_Rules/Runbook_First_Production_Rule.md).

This chat owns the window. Do not use the maintenance dashboard or another
Deployment chat while the runner is active. Pause Setup edits for the final
source-only preservation check. No new browser preview is needed for an unchanged
reviewed UI; current-clone/permission checks are required.

Any failed maintenance/grant gate stops without automatic OFF, grant retry,
inverse SQL or database restore. Inspect the retained journal and controller
state. An interrupted psql command does not prove rollback; inspect actual ACLs.
After the grant and ONLINE proof pass, a source-install failure uses the existing
source rollback; the approved read grant remains. Do not restore a whole database
or revoke access that existed before this prerequisite.

## Workstation handoff after integration

From the confirmed clean laptop main checkout `C:\lor\ImportExport\VSCode`, pull
merged main and run `Setup/Acceptance/run_setup_88_report_read_deploy.ps1`.
Use this combined launcher, not a blind repeat of the failed source-only handoff.
On PASS, refresh protected Setup and confirm V0.3.50, Updated 2026-10-08, then
Material Status → Container Movement. On STOP, retain the printed report path;
do not rerun or change maintenance state.

Production is not claimed installed until the actual host report and protected
browser result are supplied. Closeout must record snapshot path/hash, clone
receipt, granted columns, ONLINE proof, actual app SHA and report/browser result.
