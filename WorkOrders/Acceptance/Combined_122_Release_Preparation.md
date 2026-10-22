# Combined #122 release preparation — October 22, 2026

Status: PREPARED MANIFEST / NOT EXECUTABLE / NOT AUTHORIZED FOR PRODUCTION.
Owner: #122 integration; #447/#419 application; Server #81 runtime, #37 maintenance.
Existing source vehicle: draft PR #449. This record does not replace other owners.

## Pinned inventory and compatibility

Database main reviewed: `395b8e9651f4da0d06bfccaff9be189e00a0541a`.
Server main reviewed: `cce91956be59c4c12b355a40baa8776504e1e20d`.

| Item | Exact source | Disposition and dependency |
|---|---|---|
| #447 / PR449 | d72789bfb84db930eb473799e6e2e96446683dbe | Accepted component, V1.1.3-identity-reconciliation; include migration004 and its matching application together. |
| #445 / PR446 | 47ca28995543fe0915811289465b92468e6ce4d7 | Proposed batch partner only. Rollback-only probe, no disposable receipt or deployable migration; BLOCKED, not approved manifest input. |
| #395 / PR403 | 4d5b61cbfb114c35aebf8b582dba797134d21127 | Exclude: invisible bootstrap undeployed, credential scope/provisioning gates unresolved. Not fixed by #447. |
| #419 / PR444 | b88e528a16a28485c8fd13b87ff46eac9d646ac5 | Source-only wording target from older deployed source; do not merge whole old release branch into batch. Verify live SHA and compare accepted UI blobs; no separate DB window. |
| #122 / PR448 | e9cbb926782acce77d36fa2da298cf96df9b6bbd | Documentation register; no database payload. |
| #291 empty Work Days; #309 movement; GIS/FieldWiring/scan/LOR lanes | Independent open owners | Exclude unaccepted or superseded branch payloads; open PR is not proof of new migration readiness. |
| DBG-2026-017 Horse & Sleigh Pick List | Reconnaissance only | No correction candidate; exclude until owner proves cause and acceptance. |
| Shared mail / PR453 / Server #97 | Current main documentation | Preserve delivery authority. No queue, sender, timer, Flow, resend or consolidation change. |

No independent deployment of #447 is implied. Batch membership remains open for
compatible accepted database repairs. #445 must retain #122 Arch unload, a distinct
Antenna unload (not #387), #33 harness prerequisite, C034 and Displays785–832,
all actual reports/audit/2025 data and Greg's #17-to-#19 reassignment. Its current
probe must not be converted to an installer merely by replacing ROLLBACK with COMMIT.

## Exact migration manifest

Only currently eligible SQL payload:
`WorkOrders/Database/004_work_management_identity_reconciliation.sql`
SHA256: `5e4f3a689b52bbf451abf62d47db5e4c6590770d83c08ddd528a5ea392cbca94`.
Requires installed People005 shared reconciler, native Work Orders actor and
work_management_app. Directus remains sole role/policy authority. Migration004
adds the narrow entry wrapper; it must not bulk-reconcile People during installation.

Do NOT replay WorkOrders001/002/003, create roles/accounts, run clone grant fixtures
against Production, execute #395 migration006, or execute the #445 rollback probe.
No numbered #445 migration/file hash is invented here. A final ordered manifest
cannot be frozen until that repair is deployable and accepted. Proposed ordering:
identity004, then accepted #445 repair, validate both, promote exact matching source
before reopening writers. Recheck dependency order against the actual repair SQL.

## Existing mechanism and identified gap

Authority in MSB-Server-Management docs/server:
- Production_Database_Change_Deployment_Runbook.md
- Production_Database_Maintenance_Mode.md
- Work_Management_Production_Runtime.md
- Pre_Production_Browser_Review_Runbook.md
- PostgreSQL_Disposable_Acceptance_Standard.md

RUNBOOK GAP FOUND: installed-service upgrade companion
scripts/work_management_phase2_upgrade.py is pinned to migrations002/003.
scripts/work_management_service_release.py dispatches that old upgrade; its
source-only update permits presentation/Markdown changes, not backend004.
Neither is an accepted executable combined004/Setup-repair release profile.
Do not run either old mode for this batch. Extend the existing owning service
launcher/companion under Server #81 and #37, preserving its lock, private journal,
controller, snapshot, foreground SSH and source rollback boundaries. No new
maintenance system, port, credential, role system or standalone deployment runner.
A reviewed and tested exact profile is a required gate, not claimed implemented.

## Final exact-candidate checks

1. Refresh main and participating refs; record final integrated source SHA, tree,
   visible versions, source delta, migration paths/hashes and server-tool SHA/hash.
   Reconcile newer main authority; no force-reset, main edits or unapproved merge.
   Freeze a release candidate on a feature branch after eligible payloads exist.
2. Verify installed runtime and shared checkout SHA/clean state read-only; do not
   assume either 24c0c8 or 180841d is still live. Capture service/config/Flow/timer
   baselines privately; reject drift. No secrets in reports or Git.
3. Run full Setup, FieldWiring, Work Orders and acceptance tests against the exact
   candidate. Test launcher/profile failure paths: stale SHA/hash, non-ONLINE,
   missing prerequisite, bad snapshot, SQL failure, uncertain commit, promotion
   failure and interrupted transport. No weakened permission or cleanup gates.
4. Use the existing disposable infrastructure for one current-Production capture:
   apply exact ordered payloads only to that clone; run identity privilege/repair/
   audit/idempotence/revocation and V1/Phase2 SQL checks plus #445 preservation,
   material ownership and both annual/reusable dependency checks. Preserve historical
   SENT rows; no mail worker or external delivery. Do not re-dump between SQL and
   affected browser checks. Existing wrappers must be reconciled to this continuous
   sequence before handoff; present tooling does not prove a combined profile.
5. Verify Manager/Crew HTTP and browser behavior and changed Setup surfaces on the
   same candidate/clone, using sequential registered8898 ownership. Prior acceptance
   below remains valid component evidence; repeat only affected integration/identity
   gates, not the original Steve incident diagnosis. Require CLEAN EXIT, owned
   resource cleanup and Production/shared-source preservation proof.
6. Record exact reports and operator disposition in #122/#447 and owning repair.
   Final runtime SHA may differ from documentation commit; prove runtime subtree
   equivalence explicitly. Any runtime/SQL change invalidates affected prior gates.
7. Only then prepare the explicit merge/Production approval request identifying
   exact source/tooling SHA, ordered manifest, rollback identities and one window.

## One maintenance window and rollback plan

Preparation stays ONLINE. After explicit approval only: acquire existing release
lock; verify clean exact sources, controller ONLINE/unfenced and all services;
stage/regress detached candidate; enter #37 once; prove MAINTENANCE/fence and zero
normal writers; capture frozen baselines; create validated custom-format snapshot
through controller (nonempty, archive-list validation, SHA256/path retained).
Capture existing004 function definition/ACL/owner or proven absence, current
application SHA, and protected configuration identities before mutation.

Apply only approved files with stop-on-error and durable per-stage journal. Validate
narrow EXECUTE and no direct Person/Directus DML/shared-helper EXECUTE, no unrelated
row/ACL changes. For #445 compare exact approved changes plus preserved history,
not global equality of intentionally corrected tables. Promote only correct
application worktrees under the existing owner; leave unrelated shared source alone.
Validate complete DB/source baseline while fenced; controller OFF only after PASS;
verify ONLINE/unfenced, services, versions, protected routes and role smoke.
Preserve mail control, existing delivery receipts and Setup timer throughout.

| Failure point | Required disposition |
|---|---|
| Before mutation | Leave live source/database unchanged; remove only owned clean temporary resources; report no snapshot if none exists. |
| SQL transaction uncommitted | Require proven rollback; inspect journal/catalog/fence. Do not retry or call OFF blindly. |
| Committed004 or repair fails validation | Keep writers fenced. Retain snapshot and before-images; choose reviewed forward correction or governed recovery. Source-only rollback is insufficient for committed data repair. |
| Source promotion fails while fenced | Restore only recorded release-owned clean application source through existing procedure, then validate matching database/source contract. No invented inverse SQL or unconditional DROP004. |
| Failure after ONLINE | Do not restore whole DB over new legitimate work. Reconcile writes; bounded source rollback only if DB compatibility and owner state are proven. Any database recovery requires its own reviewed authorization. |
| Transport interruption | Inspect lock/process, journal, live SHA, controller and commit status before action; never rerun blindly. |

The rollback snapshot is containment/recovery evidence, not a claim that a restore
has been rehearsed. Explicitly rehearse release-specific rollback on disposable
infrastructure before final readiness. Retain migration before-images and snapshot;
do not erase successful audited identity repairs merely to revert application code.

## Accepted component receipts and remaining work

8797f32df557ec25f2cf911410467a3da1766901: SQL identity/V1/Phase2 PASS,
report20261022T145813; Manager preview PASS report20261022T154806.
d72789bfb84db930eb473799e6e2e96446683dbe: Crew PASS report20261022T160204,
175 local tests and both GitHub checks PASS. Greg confirmed Manager load/refresh
and Crew personal scope/refresh with Manager controls absent. All cleanup and
Production/shared checkout preservation PASS. Reports under
/home/msbadmin/setup-acceptance-reports/WO419_Disposable_Browser_Preview_<stamp>.txt.
Between those two SHAs only acceptance validator/tests/documentation changed.

Remaining: #445 executable accepted repair; existing Server #81 combined profile
correction and tests; final integrated SHA/one-clone acceptance/rollback rehearsal;
current live identity preflight; explicit approval. No final combined SHA, merged
identity, Production snapshot or deployment receipt exists yet. Do not claim otherwise.

After authorized deployment, update exact installed SHA/version, manifests,
controller ONLINE/health, report/snapshot paths/hash, operator evidence, reverse
chronological Production Deployment Change Log and Server runtime README. Keep
#395 and unrelated unfinished owners open. This preparation does not close #122.
