# PR470 Park Map Production Release

Filename: PR470_PRODUCTION_RELEASE.md  
Revision: 2026-10-27  
Status: Operator preview PASS / CLEAN EXIT; approved for release; server installation pending.

Accepted application: `b463f10d852d30b24aacf8e9657622ef93ed08de` (PR470).
Setup: `V0.3.95-map-return`. FieldWiring: `V0.4.35-power-panel-link`.
Expected live baseline for both applications: `820b154cd664f0cac0d1d8dfd38e47b4fe19df9c`.

Authority: `Gregovate/MSB-Server-Management` — `docs/server/Production_Database_Change_Deployment_Runbook.md` and `docs/server/Production_Database_Maintenance_Mode.md`.
Procedure: existing combined database prerequisite/application promotion under the maintenance controller.
This step: one panel-outlet migration, validation, and both accepted application sources.

From the clean, updated primary main checkout, run:

```powershell
.\Setup\Acceptance\run_setup_470_release.ps1 -Deploy
```

Omit `-Deploy` for read-only preflight. The runner checks source identity, healthy services, backups, free preview port, database baseline and candidate regressions before maintenance. It stops on drift; do not reset live sources to bypass it. It reuses the existing controller, snapshot, preservation and failure-containment mechanism. Do not operate the maintenance dashboard or another deployment during this run.

The only migration is `Database/EngineeringTools/sql/171_panel_receptacles.sql`. The validator is `Database/Acceptance/171_panel_receptacles_validation.sql`. No PR463 migrations, Scan installation, source import or business-record correction is included. Production panel-outlet flags start false; disposable review edits are not copied into Production. Existing Production rows remain intact.

A successful run prints `#470 SERVER DEPLOYMENT PASS` and the retained report and rollback snapshot paths. Save those outputs for closeout. Then check the protected Production map, associated panel and cable links, map return position/controller markers, and latest recorded person.

On STOP or a lost connection, do not rerun or change maintenance. Retain the report path and terminal output. Follow the runbook's interrupted-deployment inspection; no automatic inverse SQL, snapshot restore or forced OFF is performed.

The server runner removes only its temporary candidate worktree and transport bundle. Keep the reusable local GIS review worktree until protected Production acceptance, then remove only this task's clean, merged review branch/worktree using the repository cleanup rules. Return to the primary updated main checkout. Actual deployment report, snapshot and Production browser PASS remain to be recorded.
