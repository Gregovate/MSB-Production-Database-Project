# PR464 unassigned breaker correction — authorized Production release

Owner #171/#230 under #122. This thread owns the short release window; PR463 equipment/cable work is excluded. Greg requested this release before further engineering in that thread. Do not deploy a second candidate or operate the maintenance dashboard during this runner.

## Accepted identities

- Accepted application: `2548edd130b5cebad33a44786bc1811c2b089bf8`, FieldWiring `V0.4.29-breaker-correction`.
- PR464 merge: `af8b6efc0c7a57975071b32fd46bd784e077f2b2`.
- Prior FieldWiring: `875003c504e8a60c5851c530ec6496e4430945d9`, `V0.4.27-panel-performance`.
- Unchanged Setup: `72a94be772f2e4ae8bfaed74051f667fc87201a6`, `V0.3.91-integrated-power`.
- Operator acceptance: corrected/deleted ST-00 entry; recreated four independent Milbank entries. CLEAN EXIT,8898/source lock free; review/171-equipment-ea080130 restored; shell returned to C:\lor\ImportExport\MSB-Main. All eight circuits were not tested or claimed.

## Existing mechanism and scope

Use `run_setup_171_correction_release.ps1` (defaults to ONLINE preflight; `-Deploy` executes the authorized release). The profile reuses setup_maintenance_deploy.py, the existing deployment lock/controller, committed-byte transport, detached regression, snapshot, journal and cleanup. Governing server documents: Production_Database_Change_Deployment_Runbook.md and Production_Database_Maintenance_Mode.md. There is no new deployment mechanism.

Only `171_unassigned_breaker_correction.sql` and its read-only validation are pinned in the manifest. The installed command body must be7c1ff2630aefda0a7e46c0ef4672714e, optimized snapshot1409b5a8bada107ecfd5954c8f49a18d. After migration command906289a801cae2e2d85957898984f031 and active-only circuit-name uniqueness are required; optimized snapshot stays unchanged. All existing rows, identities, notes, circuit relationships, observations, GIS/FLW evidence and source files are preserved. No data correction, import or state seed runs during release.

While ONLINE: prove exact clean source/health, services/backups/controller, free preview port/source lock, merged target/ancestry, reviewed tree/SQL/helper bytes and detached application regression. Then use the existing controller for freeze proof, validated rollback snapshot and all-row preservation baseline; apply/validate only the approved migration; promote only FieldWiring while fenced; verify unchanged business rows; return ONLINE and verify health, source and unauthorized request rejection. Setup source remains untouched. Prior application identity is a recovery reference, not permission to automatically reverse the migration or restore the database.

A HOLD/STOP retains the report, journal and any validated snapshot. Do not retry or change maintenance state blindly. Reconcile exact source, controller and commit status under the runbook. The migration rejects replay and concurrent command drift. PR463's later migration must be reconciled against this installed command before its release; never remove the guard to bypass that requirement.

## Operator command and outcome

From clean, updated `C:\lor\ImportExport\MSB-Main`, run:

```powershell
& .\Setup\Acceptance\run_setup_171_correction_release.ps1 -Deploy
```

The wrapper performs one SCP and one foreground SSH session, allowing normal password/sudo prompts. Do not run a concurrent dashboard operation. On success retain the printed report directory, snapshot path/hash and verified source identities. Check protected Production breaker correction/removal after success. Repeat desired corrections there: preview edits were disposable.

## October 25 — PR464 Production server deployment PASS

Greg returned the reviewed release runner's server PASS receipt. This is operator-returned evidence; no independent live host probe or protected Production browser acceptance is claimed.

- FieldWiring installed: `2548edd130b5cebad33a44786bc1811c2b089bf8` / `V0.4.29-breaker-correction`.
- Setup verified unchanged: `72a94be772f2e4ae8bfaed74051f667fc87201a6` / `V0.3.91-integrated-power`.
- Application PR464 merge: `af8b6efc0c7a57975071b32fd46bd784e077f2b2`. Release tooling `d339f3cf0956b54f51a464e5c372a5163bc35cb3`; PR465 merge `b8763948b422b9f6fd2f0e39444a8c703b24d2ce`.
- Report: `/home/msbadmin/setup-deployment-reports/PR464-Breaker-Correction-20261025T225218Z`.
- Validated rollback snapshot: `/home/msbadmin/backups/setup-205/msb-pre-pr464-breaker-correction-PR464-Breaker-Correction-20261025T225218Z.dump`.
- Snapshot SHA256: `c3a63d77cfb0a49bfec2dc85a634c4707a5c9e954149622bc9383a0d28b217ce`.
- Only `Database/EngineeringTools/sql/171_unassigned_breaker_correction.sql` applied, with `Database/Acceptance/171_unassigned_breaker_correction_validation.sql`. Command body MD5 is `906289a801cae2e2d85957898984f031`; optimized snapshot remains `1409b5a8bada107ecfd5954c8f49a18d`. Circuit designation uniqueness now applies only to active rows.
- The reviewed runner's PASS contract proves maintenance/freeze, validated snapshot, migration/validation, existing-row preservation, FieldWiring promotion while fenced and return ONLINE with health/source/negative-auth checks. Detailed evidence remains in the retained report.

Disposable operator acceptance: ST-00 correction/deletion and four recreated single-pole Milbank entries PASS; CLEAN EXIT released8898/source lock and restored the other review branch. No panel records were automatically repaired during deployment. Greg must repeat desired corrections in Production. **Protected Production browser spot check remains pending.** Do not replay this successful migration or restore the snapshot as routine cleanup.

PR463 equipment/cable work is not installed by this release. Its later command migration must reconcile the new installed command body and preserve this correction before review/release; do not weaken the baseline guard. #171/#230 under #122 remain open for Part2 work. Earlier pending-release entries below are historical and superseded by this receipt.
