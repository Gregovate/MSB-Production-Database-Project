# Setup QC Production Release — PR485

| Document Control | Value |
|---|---|
| Document Type | Production acceptance record |
| Status | SERVER PASS — protected browser and local cleanup pending |
| Owner | Setup engineering / administrator |
| Last Reviewed | 2026-11-11 |

## November 11 — PR485 Setup QC server deployment PASS

Deployment started **2026-11-11 22:43:14 America/Chicago** (2026-11-12T04:43:14Z).
Operator returned preflight, freeze, validated snapshot, migration081 commit,
database validation and return-to-service PASS. Evidence is the operator-returned
runner receipt, not an independent host inspection. Protected live browser
confirmation remains pending; do not label it accepted until Greg confirms it.

- Live Setup: `3f281e49bf44a5d64a3be5e43f71319f59c8c27f` / `V0.3.121-qc-compact`.
- Merged PR485: `9803b249ffd8c09f08361d92a5a35eb1368d93c9`.
- Release tooling: `d6521b7b31018e1814a7cc8d0fba0a97671dc8cb`.
- Report: `/home/msbadmin/setup-deployment-reports/PR485-081-20261112T044314Z`.
- Snapshot: `/home/msbadmin/backups/setup-205/msb-pre-pr485-081-PR485-081-20261112T044314Z.dump`.
- Snapshot SHA256: `15eb2e8a9c3edbc91f140b1378f905ac5121a1b308d4770760dcc710d0d56a57`.

The exact candidate passed regression, PostgreSQL gates, browser regression,
operator Entrance Arch reporting/claim/repair/auditor/final-signoff review and
CLEAN EXIT before explicit Production approval. Existing maintenance controller
and foreground transport performed the release. No Node was required locally
or on the preview/server. No new server infrastructure or historical cleanup.
Do not replay081. Recovery follows the Server Management database-change runbook;
after reopening, restoring the snapshot could discard subsequent legitimate work.

Existing QC coverage is retained: no bulk task additions, renaming or Stage/Scene
reassignment. Winter Wonderland has Stage-level QC498; Icicle Tunnel has Stage475
and Scene496. Catalog coverage review and historical Intake/Work Order cleanup
remain deferred under #122/#205. Normal QC writes create no Intake, Work Order,
schedule assignment or artificial work report.

Laptop inventory shows no PR485 worktrees remain. The one identified leftover
launcher is `MSB485-release-f73b151d-2c87-4a36-9c64-6fe30ed22d41.ps1` in the user's
Temp directory. Removal and return to updated `C:\lor\ImportExport\MSB-Main`
were instructed; completion remains unconfirmed. Preserve other worktrees and
all server reports/snapshots. Refresh main with explicit fetch and merge --ff-only.
