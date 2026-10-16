# #205 under #122 — V0.3.84 Production release profile

Status: release tooling verification; Production execution pending.

Authority: current MSB-Server-Management
`docs/server/Production_Database_Change_Deployment_Runbook.md` (combined database
prerequisite and Setup promotion) and `Production_Database_Maintenance_Mode.md`.
Both were retrieved and read October 16, 2026. This profile consumes the existing
controller and `setup_maintenance_deploy.py`; it adds no maintenance mechanism.

## Exact release identities

- Accepted application: `723a733ffbea516519c6dd7a20ec75faca10a9c4`,
  `V0.3.84-direct-crew-cells`; operator light/dark PASS and CLEAN EXIT approved.
- PR #394 integration / deployment target: `7740498e6602f36c8cdfd384791bbafaab71ee9e`.
  Complete `Setup/Application` and `Setup/Database` trees equal the accepted SHA.
- Required live rollback source: `86341d49dc8ccf290575f9d2b418c235094a1377`,
  `V0.3.65-scheduled-search-focus`, clean detached `/opt/msb-setup`.
- Only migrations 075 and 076, in that order; exact blobs in
  `setup_205_estimates_release.json`. No 074, backfill, or Production test writes.
- Shared `/opt/fieldwiring` is recorded, checked clean and contained in current
  main, then preserved; Controller Inventory capacity, GIS and People stay intact.

## Guarded execution contract

The Windows wrapper requires clean merged main, packages committed LF bytes,
uses one SCP and one foreground SSH, and removes only its unique transport
bundle. `-PreflightOnly` performs ONLINE preparation without entering maintenance.
Normal invocation consumes Greg's existing explicit Production authorization.
No additional operator preview or manual preflight is required.

The runner acquires the existing deployment lock. ONLINE preflight validates
controller/services/backups, live source/version, preview CLEAN EXIT, target
ancestry, accepted Setup trees, migration identities, helper hashes, build/date,
full detached Setup regression, exact old function bodies/security, absence of
the 076 function/trigger, and a syntax/read probe of row/ACL fingerprints.
ONLINE probes are never compared across normal operator edits.

One controller ON starts the governed window. Current freeze proof precedes
stable row/ACL capture and a controller-created validated custom-format rollback
snapshot with independently checked SHA256. The runner rechecks frozen data,
validates prerequisites, applies 075 then 076, and journals each successful file.
They retain their approved individual transactions; a failed second migration
leaves 075 installed, maintenance retained, and no source promotion/OFF.

Before promotion: exact new function bodies, owners, search paths, SECURITY
DEFINER, required command EXECUTE, forbidden public/sync EXECUTE, exact enabled
trigger definition, no direct table DML, identical business/audit rows and
existing ACLs, unchanged clean source checkouts. Only detached Setup moves.
Before OFF: deployed regression, repeat security/source/fingerprint checks,
current fence proof. After OFF: current ONLINE/unfenced/health/version, live
regression, exact source/security checks and unauthenticated PATCH rejection.
No equality comparison is made after legitimate Production edits resume.

Any failure stops; no automatic retry, inverse SQL, database restore, or OFF in
cleanup. A partial/ambiguous migration requires reviewed recovery using the
retained state and validated snapshot. Never replay this wrapper after a STOP.

## Evidence retained by execution

`/home/msbadmin/setup-deployment-reports/Setup205-075-076-<UTC>/` contains
`report.txt`, `state.json`, `snapshot.json`, ONLINE probe, frozen fingerprints,
after-migration and pre-ONLINE fingerprints. The custom-format archive remains
under `/home/msbadmin/backups/setup-205/`. A PASS receipt must identify the actual
archive/hash, deployed SHA/version and ONLINE proof before deployment is claimed
or the Production deployment change log is updated.

Tooling validation includes orchestrator failure injection, previous-profile
regression, real isolated PostgreSQL 16 catalog gates, Windows PowerShell parser
and committed-byte transport, and full Setup application regression. These are
engineering tests, not another operator preview or a Production deployment.

Keep #205/#122 open for execution receipts and release closeout. No Production
installation is asserted by merging this tooling.
