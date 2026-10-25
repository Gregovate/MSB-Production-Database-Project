# Production Deployment Change Log

| Document Control | Value |
|---|---|
| Document Type | Controlled Production deployment history |
| Repository | MSB Production Database Project |
| Status | CURRENT |
| Owner | Production project owner / administrator |
| Established | 2026-10-01 |
| Ordering | Reverse chronological — newest deployment first |

## 2026-10-25 — #171/#230 FieldWiring/GIS — server deployment PASS

- PR #319 merged as `6aa23c399cea5dad7ba6b9cef619d469fe024991`; accepted/deployed application `439ab237beaae4ac648e7590f824a774969cd84f`: FieldWiring **V0.4.20-picker-sort**, Setup **V0.3.91-integrated-power**. Release tooling `82bb112e19ec815d0b49c8d1dfed5c604e075490` is a separate identity.
- Existing maintenance controller: preflight, freeze, validated snapshot, three accepted #171 schema migrations, initial accepted GPX/FLW load, preserved-data validation and return to service all PASS in Greg's receipt.
- Report: `/home/msbadmin/setup-deployment-reports/PR319-GIS-20261025T062215Z`. Snapshot path/hash remain in that retained report; not separately supplied here.
- Greg has begun real Production panel inventory and supplied WV-00 Panel 10 evidence. Slot-count and presentation corrections are a follow-up candidate, not an initial-install replay. Preserve live data. Full browser/documentation closeout is not claimed solely from server PASS.

## 2026-10-20 — #419 Phase 2 Work Orders and email — Production PASS

- Installed application: **V1.1.2-manager-utilities**, source `24c0c8e526e032f4a7202a77ed14ab9a30b2459b`; PR #435 merged as `7f88be7d9a6b476fa60688e775b1e044140f5c28`. Infrastructure: Server Management #81, merged PRs #87 and #88.
- Migrations `002_work_management_due_by.sql` and `003_work_management_mail_delivery.sql` applied through existing #37 maintenance, validated rollback snapshot, independent source promotion and return ONLINE. Server regression: **193 passed**. Shared checkout `17c522c4f8ec06549bf7a6d9e8530c61276203f7` preserved.
- Upgrade receipt: `/home/msbadmin/work-management-deployment-reports/WO81-service-a6601b10c3e340b7b3e044c1639aee02.txt`.
- Bounded first delivery: SMTP accepted; Greg explicitly confirmed Inbox receipt. Receipt: `/home/msbadmin/work-management-deployment-reports/WO81-service-2788a2d26bc247e48196e29feae8d0be.txt`.
- Scheduled mail enabled; Setup timer remained active. Receipt: `/home/msbadmin/work-management-deployment-reports/WO81-service-947799d704a94744a7c95c5e2ee73188.txt`.
- Capture ON; only legacy email Flows `ebcde355-32c5-4826-b6fa-360621d0d357` and `9a7fb87b-d78e-492b-b2c5-ac3b521b5cf7` inactive, verified by activation gates. Non-mail Flows/operations and historical pending notifications preserved. Worker runs about every minute, bounded to 50 events; uncertain claimed sends are not automatically retried. Setup daily email schedule is separate and unchanged.
- Greg confirmed the live application working. Utilities is a separate Manager page for fictional no-send email previews. Source templates remain reviewed editable files; this utility does not edit or send them.
- Disposable SQL PASS/CLEAN EXIT at `61b73293f32ca9b49f3be863e3d9da89095db7a0`: `/home/msbadmin/setup-acceptance-reports/WO419_Disposable_Browser_Preview_20261020T234604.txt`. Later Utilities change was presentation-only; no repeat database dump was required.
- Snapshot path/hash and full preservation evidence reside in retained private server journals; their literal values were not supplied in the abbreviated receipt and are not invented here.
- **Follow-ups, not deployment failures:** Apps tile publication remains outstanding; all-event recipient coverage and longer-running worker observation are not claimed. Greg's 3–4-second typed-search delay is assigned to his separate performance thread; no performance investigation or change is part of this closeout. Keep #419/#81 open for remaining scope. These documentation commits do not change the installed application SHA.

## 2026-10-17 — #205 Scheduling Board drag-scroll and Crew Captain labels — Production PASS

- Emergency source-only correction under #205/#122: PR [#414](https://github.com/Gregovate/MSB-Production-Database-Project/pull/414) merged at `bcebcedde6c8043d00e26d1c3f72a244a338f76f`. Final source-only release PR [#415](https://github.com/Gregovate/MSB-Production-Database-Project/pull/415) merged at `65ea23dbfa474d50b9ffe8c23f101dbb76f9951c`; exact deployed application target `ec6d3f0e6a6a1cd69dd60256dcb7f76699e07910`, version remains `V0.3.84-direct-crew-cells` with October 17 UI footer/cache pins.
- Corrects drag-edge auto-scrolling to use the actual right Scheduling Board scroll owner `.setup-board205-right`, after #205 had changed the inner `.setup-board205-board` to non-scrolling overflow. Preserves established crew colors, scheduling and Report Work history. Schedule Annual Task/Move Crew choices now display Captain names, consistent with Perform Work.
- Greg explicitly reported disposable browser PASS for restored drag-and-drop and Captain names across both screens, then `Setup REUSABLE DISPOSABLE BROWSER PREVIEW: CLEAN EXIT`. Candidate browser SHA `86d9983d1ba2dff8b9c03b24e25cf6420985143b`; subsequent source-only release updated only browser cache/date and associated source contracts. Setup/FieldWiring and source-release safety/Windows transport GitHub CI PASS prior to merge.
- Operator reported `PASS: PR414 source-only deployment completed` and `#414 SOURCE-ONLY DEPLOYMENT PASS`, followed by **confirmed PASS in the protected Production browser**. Deployment used the established Setup source-only runner; no schema/data migrations, no #37 database maintenance entry or PostgreSQL rollback archive. Only Setup source/service is intended to be promoted. Exact server report path/fingerprint, old source SHA, and tested counts from the Production run were not supplied in the abbreviated output; do not invent them. Retain the runner report as controlling detail.
- #205 accepted functional behavior restored. Do not redeploy migrations 075/076 for this repair. This documentation-only closeout commit is not the installed application SHA.

## 2026-10-16 — Setup V0.3.84 direct crew cells / 2026 estimates — Production PASS

- Owner #205 under #122. Accepted application `723a733ffbea516519c6dd7a20ec75faca10a9c4`; feature PR #394; exact deployed Setup target `7740498e6602f36c8cdfd384791bbafaab71ee9e`, `V0.3.84-direct-crew-cells`. Tooling PR #409 merged at `b3cf229ccde4bcdfda9c27acedebb16ee5a61cda`; tooling/documentation SHAs are distinct from deployed source.
- Operator-visible release includes direct planned AM/PM crew-count editing independent of actual work, 2026 reusable/annual task estimate synchronization, and accepted Scheduling Board/Perform Work/Action Center corrections. Actual work and Captain history protections remain.
- Installed only `075_allow_setup_planned_crew_count_corrections.sql` then `076_capture_2026_reusable_task_estimates.sql`, in one existing #37 maintenance window. No backfill or Production test assignments. Shared Controller/FieldWiring/People checkout preserved; accepted GIS source retained.
- Greg supplied the complete runner PASS transcript and confirmed initial Production spot checks found no problems at approximately 17:05 CDT. Current freeze, validated snapshot/hash, ordered migration commits, database security/preservation validation, exact source promotion and return ONLINE/health/live checks passed per the reviewed runner's success contract. No independent host probe or exhaustive operator acceptance is claimed.
- Retained report: `/home/msbadmin/setup-deployment-reports/Setup205-075-076-20261016T215912Z`. Rollback archive path/hash/size and validation are retained in its `snapshot.json`; literal archive metadata and numerical fingerprints were not supplied in the terminal excerpt and have not been independently read here.
- Prior clean Setup rollback source: `86341d49dc8ccf290575f9d2b418c235094a1377` / `V0.3.65-scheduled-search-focus`.
- Engineering verification: 49 deployment/PostgreSQL16 tests, 840 Setup tests, Windows parser and committed-byte transport PASS. Detailed [release and Production receipt](../Setup/Acceptance/Setup_205_075_076_Release.md). Do not rerun the successful installer for documentation; #205/#122 remain open for remaining scope.

## 2026-10-16 — FieldWiring V0.4.2 Controller Network UID Explorer — Source-only Production PASS (operator-reported)

- Controller Inventory owner #110 / original #111, launch governance #122; implementation PR #406 merged as `b3acf960c9db5ee493f5b14759459315db79be8a`; regression contract follow-up PR #407 merged as `17c522c4f8ec06549bf7a6d9e8530c61276203f7`.
- Exact Production checkout after installation: `17c522c4f8ec06549bf7a6d9e8530c61276203f7`; previous clean live checkout `bb8dfa498c5b4bbecfc3693f68c4066c1e08242e`.
- Visible FieldWiring version: `V0.4.2-controller-uid-explorer`. Operator-reported health `{"data_mode":"postgres","status":"ok","version":"V0.4.2-controller-uid-explorer"}`; Procedures remained `V0.1.0`, healthy.
- Changes: selectable Network-wide 01–F0 UID inventory and search; case-insensitive `Regular` identity; removal of DMX/E1.31 universe contamination from LOR UID occupancy; physical Controller overlay; optional model-width contiguous UID search; improved one-UID and grouped-range presentations. Operator confirmed Regular/39 false Mega Tree attribution corrected in disposable browser. Post-season PixCon16 dual LOR/E1.31 IP/universe planning deferred in Controller engineering contract.
- **Source-only:** no database migrations executed, no PostgreSQL maintenance window. The checkout advance included `Setup/Database/073_add_setup_required_container_command.sql` as a source file, **not** as an executed migration. No evidence of any DB schema/data mutation in this release.
- Acceptance: prior exact-candidate disposable browser `1944af4140fda651eda173f06dec907c7aa448d6` reported BROWSER REVIEW READY, cleanup CLEAN EXIT, identical Controller fingerprints `0dd5493c19451711c4bf8af0a5960f72`. Full merged Controller/FieldWiring/Procedures regression after test-contract reconciliation: **263 passed in 4.08s**, operator transcript. Final operator-reported source installation: `SOURCE DEPLOYMENT HEALTH PASS` with exact deployed SHA and both services healthy. No post-deploy database fingerprint or full live regression output was supplied; do not claim either.
- Runtime deployment report/archive: none supplied for source-only direct command sequence. Operator output is current evidence; rollback source is the recorded prior checkout SHA above. Follow-up: verify protected browser Controller UI, perform post-deploy smoke / negative authorization check and document final evidence, then close issue/PR ownership under #122.

## 2026-10-14 — Setup V0.3.65 scheduled search reveal — Production PASS

- Owner #205 / #122 DBG-2026-014; feature PR #391 merge `4819959be8bdad3d002623775b83ebe876a417e5`; tooling PR #392 merge `f312a12b30e75f8bb5cc7733620ff1f301a54138`.
- Exact deployed application: `86341d49dc8ccf290575f9d2b418c235094a1377`, `V0.3.65-scheduled-search-focus`, footer Updated 2026-10-14. Tooling/main SHAs are not the live application pin.
- Clicking a scheduled search result expands the matching collapsed day, updates its arrow/accessibility state, and scrolls/highlights/focuses the task. Other days remain collapsed. Separate Day View terminology is unchanged.
- Exact-candidate engineering: 764 Setup/shared-preview checks and actual-handler DOM tests PASS. Greg confirmed disposable browser behavior and CLEAN EXIT, then authorized deployment.
- Operator-reported server PASS: `/home/msbadmin/setup-deployment-reports/PR391-Source-20261014T185934Z` (October 14 UTC). Source-only release used the installed maintenance controller at Greg's request: freeze and complete ref/ops preservation, exact Setup promotion, return ONLINE, exact health and live regression passed per runner receipt. Numerical fingerprints and observed shared SHA remain in the retained report/journal, not transcribed or independently inspected here.
- Prior Setup/rollback source: `efb7f26fd0d4e1275daa509e2ade62bc291b1d8f` / V0.3.64. The runner's mandatory preflight also proved the exact migration 073 command/security was already installed. No migrations replayed; no PostgreSQL rollback archive created for this source-only release. Separate PR389 installation report/archive receipt remains unprovided.
- Protected Production browser: Greg confirmed working October 14 at14:02 CDT. Local Office-worktree cleanup was supplied but execution remains unverified. Do not rerun the completed installer for documentation.
- Detailed evidence: [Scheduled Search Focus candidate/receipt](../Setup/Acceptance/Setup_205_Scheduled_Search_Focus_Candidate.md).

## 2026-10-13 — People V0.2.2 Directus-to-Person identity reconciliation — PASS

- Owning issue #385; implementation PR #386.
- Visible Production version: `V0.2.2`.
- Accepted runtime candidate: `2c9a2937079f817dafd5119584aaffc77b51357d`.
- Merged/deployed main SHA: `bb8dfa498c5b4bbecfc3693f68c4066c1e08242e`.
- Migration: `People/Database/005_reconcile_directus_person_identity.sql`, blob `88442b8f4150513fd6af581e2ea90004c6f27658`.
- Behavior: protected application actor paths now safely self-reconcile an existing active human Person to the matching active Google-backed Directus UUID by exact Sheboygan Lights email. Directus role/policy state remains unchanged and continues to authorize access.
- Explicit non-human exclusions: `tablet-*@sheboyganlights.org`, `printservice@sheboyganlights.org`, and `production-1@sheboyganlights.org` cannot reconcile to a Person.
- Current-Production disposable acceptance PASS: 26 exact-candidate tests; movement/management/execution/inventory/People/Controller actor paths self-reconciled; idempotence, role preservation, audit attribution, conflict/missing-state fail-closed behavior, and reconciliation report all passed.
- Production `ref.person` fingerprint remained `9dca556251712a3824cda436b0300fc8` during disposable acceptance and was the frozen Production fingerprint at deployment.
- Governed database-changing Production deployment PASS under Server Management Issue #37 maintenance control.
- Frozen Directus identity fingerprint: `1333a30c3f2f35fa1864e979c200c177`.
- Validated rollback snapshot: `/home/msbadmin/backups/postgres/msb-pre-people-identity-reconcile-20261013T183854.dump`.
- Deployment report: `/tmp/MSB_People_Identity_Reconcile_Production_Deploy_20261013T183854.txt`.
- Durable acceptance: [People Identity Reconciliation Production Acceptance](../People/Acceptance/People_Identity_Reconciliation_Production_Acceptance_2026-10-13.md).

## 2026-10-11 — Corrected Park Map waypoint and LinkIQ source — PASS

- Governing #122; GIS #171; permanent editor #230 remains unfinished.
- Exact deployed application: `2bc88ae627420c2138268e39a26b4942a3248580`, Setup `V0.3.62-field-networks`, visible update October 11.
- Accepted corrected waypoint names/positions and LinkIQ snapshot; obsolete temporary Workshop marker removed, real GPX Workshop and #88 Home anchor preserved. Prior schematic/LOR uncertainty remains visible.
- Feature PR #352 merge: `b4be04b95fff846223805187bd33092ba375e33e`. Installer PR #354 merge: `5108b24f3d03e22dd5ddef6f1abb506c63be191a`. Tooling/closeout SHAs are not the deployed application.
- Engineering regression: 751 Setup tests and network browser checks PASS. Greg accepted corrected waypoints in governed preview and reported CLEAN EXIT before merge.
- Operator-reported source-only deployment PASS: `/home/msbadmin/setup-deployment-reports/Setup-PR352-Map-Source-20261011T155458Z`. Greg then confirmed protected Production: **Waypoints corrected**.
- Rollback application: `c1db3e767f56b0346e76b05fd615d6e21e8ccf57`; no database migration/archive or maintenance transition for this source-only release. Runner retains preflight/result/fingerprint evidence; numeric fingerprints have not been transcribed.
- Next #171 priority: reconcile GPX track references with corrected waypoint identities and LinkIQ evidence. Operator suspects ExpertGPS track waypoint references remain wrong; specific defects are not yet established. Preserve trace geometry and unresolved matches pending review. PostgreSQL import/editor, offline revisions and interchange remain separate unfinished work.

## 2026-10-10 — Integrated Setup / Field Wiring map release

- Deployed source: `6192a1fdf5acb234fd83731b6a8eb73072b7a35d`; PR #318 merge `1943ac86d1b4d7a8c5c801a6f323faa7de9cf75b`.
- Setup V0.3.62-field-networks; Field Wiring V0.4.1-gis-entry. Shared map, network selection/defaults, container workshop anchor, and integrated container reconciliation.
- Migration `070_reconcile_setup_container_contents.sql` committed and database validation passed. Do not replay 071/072.
- Server deployment PASS: `/home/msbadmin/setup-deployment-reports/PR318-070-20261010T172234Z`; tooling PR #330/main `123f24e0a91707984e8325af29d13d287102b3b6` is distinct from deployed application source.
- Validated rollback snapshot: `/home/msbadmin/backups/setup-205/msb-pre-pr318-070-PR318-070-20261010T172234Z.dump`, 9,659,244 bytes; SHA256 `358acf2498b18810544ddf4b4c499564250875791b76e72f7a66b7948c097b0b`.
- Earlier fingerprint SQL failure and interrupted maintenance entry retained in #122; pre-fence recovery returned ONLINE before the successful deployment. No migration was applied by those failed attempts.
- Greg confirmed the Field Wiring map and direct Setup map work. Missing Setup header navigation is corrected separately in [Park Map entry follow-up](../Setup/Acceptance/Setup_122_Park_Map_Entry.md); its deployment/operator confirmation remains pending. Broader #122/#171 closeout remains open.

## Purpose

Maintain one human-readable, date-ordered record of Production changes across the MSB Production Database Project.

This log is the quick operational history. It does not replace the exact acceptance record, owning issue, pull request, migration, rollback archive, or Git history. Each entry links those identities together so an operator can answer what changed, when it changed, and what actually reached Production without reconstructing the answer from multiple issues and acceptance files.

## Entry Rule

Add a new entry for every Production deployment that changes application behavior, database schema/functions, Production data by governed migration/correction, runtime behavior owned by this repository, or another operator-visible Production capability.

Newest entries go at the top.

Each deployment entry must record, when applicable:

- deployment date;
- subsystem/application;
- visible Production version;
- concise operator-visible or operational changes;
- exact deployed application SHA;
- merged-main SHA when different;
- migration path/number and identity;
- owning issue(s);
- implementation/deployment PR(s);
- acceptance/deployment result;
- rollback archive/report identity;
- important post-deployment field validation.

Documentation-only repository changes that do not alter Production do not require a deployment entry.

## 2026-10-09 — #205 scheduling corrections — Production PASS

- Installed Setup target: `1fdc3b0250c5f750648c217c9e36f3ac9ea59f9e` (PR #324/#325). Client **V0.3.50**, backend `V0.3.50-container-movement-report`, footer **Updated 2026-10-09**.
- Greg approved both disposable previews with CLEAN EXIT and confirmed the protected Production screen PASS after installation.
- Source-only runner PASS: `/home/msbadmin/setup-deployment-reports/PR325-20261010T033752Z`. Exact source, health, focused regression and unchanged pre/post data fingerprints passed per runner receipt. Numerical fingerprint is retained in `preflight.json` / `result.json`, not transcribed here.
- Prior source/rollback SHA: `0b69a269b2a32d369ee4f25be6740e15d7c5a823`. Shared checkout remains `6dd05c4aa5ef8f50fe172145c3ae281cc245a101`. Tooling PR #326 merge: `291def5746ca0683cf9601cf7dc07753bd56ded4`; existing source-only runner retains its legacy 306 filename. Do not replay it.
- No database migration or maintenance transition in this update; only Setup restarted under the Server Management source-only runbook. No rollback reported.
- Changes: occurrence-based historical completion/collapse; prominent late work and Captain attribution; Captain TBD; AM/PM staffing/task summaries; required estimates for unstarted work; clearer rescheduling badges; Chicago day boundaries. Existing historical planning locks remain enforced.
- #205 stays open: audited D9 Tom Shircel Crew B-to-A correction and removal of erroneous B, deferred Schedule Churn KPIs, and possible future staffing-model refinement are not completed by this release.

## 2026-10-08 — #88 Container Movement report installed — server PASS

- Actual runner receipt supplied by Greg at 16:43 CDT: `/home/msbadmin/setup-deployment-reports/Setup88Read-20261008T214153Z`, frozen validation PASS, return to service and final server PASS. Greg reported about 20 seconds.
- Exact deployed Setup `6c44a082dd520b75881c50ad2ce78feb029ff87d`, `V0.3.50-container-movement-report`; previous source `cb0538022ed066ff90675e832daa1cd95488114a`. Execution main `cc93378f6ad62f353c5994860ebd98dff54a86aa` (#315); application #310, prerequisite #312, tooling #313/#314/#315. Shared checkout remains `6dd05c4aa5ef8f50fe172145c3ae281cc245a101`.
- Installed only `Setup/Database/071_grant_setup_container_type_report_read.sql`, blob `1fd5de8f3de7665336e0eabead498e94ed915883`: SELECT on `container_type_id` / `container_type_name` for `fieldwiring_app`. No business-row or movement-model change.
- Manager Material Status → Container Movement provides fresh read-only movement trails, Display Names, recorded destination/GPS separately from calculated nearest Stage, GPS feet and unresolved review evidence.
- Pinned runner PASS follows current-clone acceptance, exact regression, controller freeze/validated snapshot, frozen ref/ops row and unapproved ACL preservation, source promotion, ONLINE/unfenced/services/health/deployed tests/role reads and cleanup. No rollback was reported.
- Protected browser result remains PENDING. Snapshot path/hash and child source-report identity await transcription from retained `snapshot.json` / `report-directory.txt`; [detailed record](../Setup/Acceptance/Setup_88_Report_Read_Prerequisite.md#october-8--production-server-pass). Guided #309, migration 070, historical repairs and takedown loading remain separate. Do not rerun the installed grant/report.

## 2026-10-08 — #88 disposable ACL export STOP — historical failed attempt

- Deployment preflight report `Setup88Read-20261008T195058Z`, child acceptance `Setup_Disposable_Acceptance_20261008T195100.txt`: exit 23, empty Production SELECT boundary export. Exact frozen candidate Application regression: 716 passed / 2 skipped; clone restore succeeded, migration was not reached.
- Tooling omitted `docker exec -i` when streaming the host SQL file. Corrected reusable runner and separate exact blob selection preserve original report/migration identities; no broader privilege workaround.
- Disposable cleanup completed. Production Setup fingerprint remained `9d6f8d09a129ba7cbd839c4286c8d8c0`, live Setup remained `cb0538022ed066ff90675e832daa1cd95488114a`. No maintenance entry, Production migration or source promotion occurred.
- [Controlled prerequisite record](../Setup/Acceptance/Setup_88_Report_Read_Prerequisite.md#2026-10-08-1450-cdt--disposable-acl-export-stop) retains failure, correction and engineering proof. Actual current-clone acceptance, two-column grant, exact V0.3.50 installation and protected browser result remain pending.

## 2026-10-08 — #88 backup preflight STOP — backup recovery accepted; report pending

- Combined attempt retained at `/home/msbadmin/setup-deployment-reports/Setup88Read-20261008T161235Z`: `Backup chain not current`, ONLINE preflight, maintenance/migration not started. No grant or report promotion.
- NAS sender could not read the October 5 identity-repair rollback dump. Server Management [#65](https://github.com/Gregovate/MSB-Server-Management/pull/65)/[#66](https://github.com/Gregovate/MSB-Server-Management/pull/66) record its guarded owner repair: root:root 0600 → msbadmin:root 0600, same 9,603,652 bytes and validated SHA256 `f061657e71817c2aad9921ffb466f986b9ff92d7354c7e2d680a4885859ff209`.
- Existing NAS replication succeeded 2026-10-08 14:11:57 CDT. Current controller ONLINE/unfenced, no error, all listed services active; latest local/NAS PostgreSQL and Directus backup instances match. No maintenance, restore, application restart or Database grant was part of this recovery.
- At 14:20 CDT Greg directed one server-enforced maintenance window through both the approved grant and report promotion; at 14:20:48 he confirmed no new run had started. The old OFF-before-source/manual-pause handoff is superseded by [the controlled prerequisite record](../Setup/Acceptance/Setup_88_Report_Read_Prerequisite.md).
- Reviewed application remains exact `6c44a082dd520b75881c50ad2ce78feb029ff87d` / V0.3.50; migration 071 bytes unchanged. Corrected tooling engineering PASS does not prove actual current-clone acceptance, grant application or report installation. Those remain pending.

## 2026-10-08 — Container Movement report attempt — stopped before mutation

- Intended #88 / PR #310 application: `6c44a082dd520b75881c50ad2ce78feb029ff87d`, V0.3.50.
- Read-only preflight under `fieldwiring_app` failed: `permission denied for table container_type`.
- No live advancement, service restart, SQL mutation or rollback was required; temporary candidate removed.
- Operator readback: exact live `cb0538022ed066ff90675e832daa1cd95488114a`, active Setup, PostgreSQL healthy, V0.3.42.
- Retained report: `/home/msbadmin/setup-deployment-reports/Setup88Report-20261008T151700Z/report.txt`.
- [Acceptance / blocked handoff](../Setup/Acceptance/Setup_88_Container_Movement_Report_Deployment.md) and [proposed narrow read prerequisite](../Setup/Acceptance/Setup_88_Report_Read_Prerequisite.md). Report installation remains pending.

## 2026-10-07 — Setup V0.3.42 Current Location attempt — rolled back

- Owning work: [#175](https://github.com/Gregovate/MSB-Production-Database-Project/issues/175), #122 / DBG-2026-001. Application and installer PR [#305](https://github.com/Gregovate/MSB-Production-Database-Project/pull/305) merged to main at `5cbd4cfe156b62c484fe128b43b8119938c6fbef` before deployment.
- Attempted exact application target: `cb0538022ed066ff90675e832daa1cd95488114a`, `V0.3.42-current-location`. No migration. The target briefly reached live source, but focused regression failed because the test process mixed installed Production repository methods with the base SQLite fixture (`ref.lor_scene` missing in that fixture).
- Source rollback PASS: live restored to `0caed843bb37e7f1f1400972d8f6eb0b03f202d4`, postgres/ok/`V0.3.40-live-pick-demand`. Only Setup source/service changed; database fingerprint `07f14ba04cee4f17a2611c7b34c33b1e` matched the original. Disposable regression worktree removal completed.
- Operator-supplied retained report: `/home/msbadmin/setup-deployment-reports/PR305-20261007T103430Z/report.txt`. Subsequent read-only live SHA/health check confirms rollback. At the end of this first attempt, V0.3.42 was not installed or accepted in Production; the later successful install is recorded above.
- [Controlled acceptance/recovery record](../Setup/Acceptance/Setup_175_Current_Location_Candidate.md#2026-10-07-failed-install-and-tooling-recovery) records the corrected test-process grouping and pre-mutation focused checks. A later successful attempt requires its own result and protected-route acceptance; do not treat tooling preparation as installation.

## 2026-10-04 — Setup footer and maintenance dashboard presentation — PASS

- Current Setup source: PR [#295](https://github.com/Gregovate/MSB-Production-Database-Project/pull/295) merge `9b9d6a431c322f37221c24ef1901439acc063ad7`; version `V0.3.38-setup-day-milestones`; visible footer `Updated 2026-10-04`.
- Administrator dashboard now wraps long backup paths/hashes within cards and shows the PR293 stage. Source: Server Management PR [#63](https://github.com/Gregovate/MSB-Server-Management/pull/63), merge `8ddc11a4b8cf056d3d6e03de3f9b158e21529645`; installed blob `08394cc176b0534bebe17c01d30e4cfb66da7b56`.
- Initial cross-repository fetch prompted before installation. Corrected transfer tooling PR [#296](https://github.com/Gregovate/MSB-Production-Database-Project/pull/296), merge `13a3e91b72cca70841442a8325ec578ba8387967`, packages and verifies the accepted artifact without another repository login. Tooling identity differs from deployed application identity.
- Source-only host regression, UI date gate, focused live regression, health, unchanged Setup data fingerprint/shared checkout and ONLINE state PASS. No migration or maintenance re-entry; only Setup and administrator services restarted.
- Report: `/home/msbadmin/setup-deployment-reports/PR293-presentation-20261004T133051Z`. Greg confirmed footer and refreshed dashboard PASS.
- Prior application source: `e2f58d016f015f1ac695940e9ab67c61c04a8a8a`; prior administrator source retained in the report folder. [Controlled record](../Setup/Acceptance/Setup_205_Migration_069_Deployment_Record.md) owns detailed evidence and migration backup boundary. Owning issue: [#205](https://github.com/Gregovate/MSB-Production-Database-Project/issues/205).

## 2026-10-04 — Setup V0.3.38 / migration 069 — Production accepted

- Work Day numbers now follow chronological dates in open sessions; Historical Day Add, noted empty-day removal, passive scheduling audit and annual milestones are accepted.
- Exact accepted candidate: `3063a92877d89e5ec00b3b8187da20d208498254`; PR [#293](https://github.com/Gregovate/MSB-Production-Database-Project/pull/293) merge and migration-deployed Setup SHA: `e2f58d016f015f1ac695940e9ab67c61c04a8a8a`; version `V0.3.38-setup-day-milestones`.
- Migration: `069_fix_setup_day_sequence_and_audit.sql`, blob `a49b25cf7325da86fc9810e8a75465de07f8cadf`.
- Installed maintenance controller entry/freeze/snapshot/migration/preservation/promotion/return/health/regression PASS; Greg observed maintenance and accepted refreshed Production screens. Shared checkout unchanged.
- Reports: `/home/msbadmin/setup-deployment-reports/PR293-20261004T124235Z` and `PR293-20261004T124422Z`.
- Validated rollback dump: `/home/msbadmin/backups/setup-205/msb-pre-pr293-069-PR293-20261004T124422Z.dump`; SHA-256 `d1a8ec4f9345d5fee6b8f0168c72f9f857aeea8d66a81b257ad92de1bd8d4450`.
- [Controlled acceptance record](../Setup/Acceptance/Setup_205_Migration_069_Deployment_Record.md). The presentation correction completed afterward, as recorded above. No second migration was required.

## 2026-10-01 — Setup V0.3.34-scheduling-readiness-fixes

**Subsystem:** Setup and Deployment  
**Owning work:** #205 under #122  
**Production result:** PASS

### Changes deployed

- Restored inline Mark Ready / Mark Not Ready to the existing governed annual-readiness command after the newer Annual Readiness path caused an app-role row-lock permission failure.
- Added migration 067 with governed SECURITY DEFINER `ops.set_setup_annual_hold(text,bigint,boolean,text)` for annual note + explicit READY / NOT_READY changes without granting broad UPDATE on `ops.setup_session_task`.
- Removed duplicate readiness wording from Scheduling task cards.
- Removed the persistent informational Production banner while retaining actionable save/error feedback.
- Expanded Plan / Schedule to use available desktop width, with additional wide-screen space directed primarily to the board / AM / PM lanes while preserving the <=1100px stacked layout.

### Identity

```text
visible Production version = V0.3.34-scheduling-readiness-fixes
accepted/deployed application SHA = e103eedbf8caaf580ce6fe5df392fbd68c0cb7f4
application PR #281 merge = 8e0e40f73038d16452034d7b2c44846b89bdaed8
deployment tooling PR #283 merge / main = 64de3d2cfac17ad8688a47a3fd6d227d47e7745c
migration = Setup/Database/067_fix_setup_annual_hold_command.sql
migration blob = ee2e9417efc22a9821258df0522a7f518117b5e8
```

### Production acceptance

```text
marker = SETUP #205 V0.3.34 SETUP/POSTGRESQL PRODUCTION DEPLOYMENT WRAPPER: PASS
governed Setup fingerprint before/after = 9951600040f7b01c75b8c104b4ddeb8c unchanged
2026 Setup Session count before/after = 1 unchanged
exit status = 0
```

Rollback/evidence:

```text
rollback archive = /home/msbadmin/backups/setup-205/msb-pre-setup-205-v034-20261002T005512.dump
rollback SHA256 = 7d2017c6f55993b7464d10ccbd3b80f0fe85ff1fac866f6521d63e50b1e01f66
deployment report = /home/msbadmin/setup-deployment-reports/Setup_205_V034_Production_Deploy_20261002T005512.txt
```

Pre-Production acceptance:

- full Setup/Application regression: 654 passed in 1.85s;
- reusable disposable acceptance: CLEAN EXIT;
- exact-candidate browser review: operator PASS;
- reusable disposable browser preview: CLEAN EXIT.

---

## 2026-10-01 — Setup V0.3.33-material-status-review-fixes

**Subsystem:** Setup and Deployment  
**Owning work:** #206 under #122, with performance cross-reference #222  
**Production result:** PASS

### Changes deployed

- Added the separate Manager Material Status screen for annual material oversight while preserving the Rolling Pick List as the picker/material-handler execution surface.
- Added Manager search/filter/sort across physical material, Stage/Scene, status, Pick By, Needed For, Home Location, and identity.
- Added one-item Manager override Add / Edit / Remove controls using the existing governed override command path.
- Preserved independent schedule and Manager demand: an item may show `BOTH`; schedule demand does not replace or rewrite a Manager override, and removing the Manager override leaves schedule demand intact.
- Corrected Pick List Needed For filtering so a Manager override with blank Needed For remains visible using its effective Pick By date.
- Reworked Manager Material Status unscheduled-material resolution from per-task `field_context()` calls to bounded batched reads. Disposable browser evidence improved from about 13.2 seconds server application time to below the existing 250 ms slow-GET event threshold during review.
- Replaced repeated annual task-reason blocks with concise deduplicated physical Contents.
- Kept Unresolved material read-only on Material Status and routed correction to the existing Material Audit workflow.
- Corrected status-transition behavior so removing or adding an override does not make the same item appear lost behind the prior status filter.
- Advanced the Material Status client asset pins for the accepted browser behavior.

### Identity

```text
visible Production version = V0.3.33-material-status-review-fixes
accepted/deployed application SHA = e9839123e7483d7ced630b3dc6ab8f377c3f3262
application PR #276 merge = e81d4e2da9d84324d85f6423dca0aae831a98753
deployment tooling PR #277 merge = 893cca3fa593e75f4c41ec7e18e03aa24b6f971c
main-only deployment guard PR #278 merge = 5659de172cb5eb2abcf05e50c190a00ca775c4a7
database migration = NONE — source-only Setup deployment
```

### Production acceptance

```text
marker = SETUP #206 V0.3.33 SOURCE-ONLY PRODUCTION DEPLOYMENT WRAPPER: PASS
governed Setup fingerprint before/after = 72f5e30b374631daf91e059593b37500 unchanged
final Setup SHA = e9839123e7483d7ced630b3dc6ab8f377c3f3262
final health = {"data_mode":"postgres","status":"ok","version":"V0.3.33-material-status-review-fixes"}
exit status = 0
```

Rollback/evidence:

```text
rollback unit = prior exact Setup SHA 79574e3a7d16e82ef3e045eb2c7c96cff624e4e1 + msb-setup.service restart
PostgreSQL rollback archive = not applicable; Production database was not mutated
deployment report = /home/msbadmin/setup-deployment-reports/Setup_206_V033_Material_Status_Source_Only_Production_Deploy_20261001T231702.txt
```

Browser/operator validation before Production deployment included:

- Manager Material Status performance and search/sort behavior;
- Manager override add/edit/remove and date behavior;
- blank Needed For handling;
- `BOTH` schedule + Manager override behavior;
- concise Container Contents presentation;
- Unresolved -> Material Audit correction handoff;
- status-transition visibility after override removal/re-add;
- `CONT:134` re-add visible on both Manager Material Status and Rolling Pick List.

---

## 2026-10-01 — Setup V0.3.31-pick-review-fixes

**Subsystem:** Setup and Deployment  
**Owning work:** #206 under #122  
**Production result:** PASS

### Changes deployed

- Removed the blocking sticky Training banner from the Rolling Pick List.
- Training state is now shown inside the scanner controls without covering Pick counts or the Pick List.
- Corrected Training exit behavior.
- Removed Manager Override creation/edit/cancel controls from the Rolling Pick List; that screen remains the material-handler execution surface.
- Preserved Manager override demand state display on the Pick List.
- Removed the redundant second disposable-browser-review banner; the single Browser Review warning remains sufficient during disposable review.
- Deployed migration 066 so Manager override cancellation remains independent of preserved physical movement evidence.
- Advanced Pick Mode cache/assets for the accepted browser behavior.

### Identity

```text
visible Production version = V0.3.31-pick-review-fixes
accepted/deployed application SHA = 79574e3a7d16e82ef3e045eb2c7c96cff624e4e1
application PR #273 merge = 0976aedf28f05eac62040b27a22177a360cde415
deployment tooling PR #274 merge / main = f22f43dffcbb60050218a13f0788378d575749c5
migration = Setup/Database/066_allow_manager_pick_override_cancel_after_movement.sql
migration blob = a27574d99af70d5de0e247ef6ffb73974708f127
```

### Production acceptance

```text
marker = SETUP_206_V031_PRODUCTION_DEPLOYMENT_PASS
governed Setup fingerprint before/after = 9951600040f7b01c75b8c104b4ddeb8c unchanged
2026 Setup Session count before/after = 1 unchanged
exit status = 0
```

Rollback/evidence:

```text
rollback archive = /home/msbadmin/backups/setup-206/msb-pre-setup-206-v031-20261001T213325.dump
rollback SHA256 = 5ea93a8be1592400f00b393dd948e904a838ec7caf45591c4ff5edd6a145aa73
deployment report = /home/msbadmin/setup-deployment-reports/Setup_206_V031_Production_Deploy_20261001T213325.txt
```

Post-deployment field validation:

- real rugged-tablet / Zebra scanner path worked in Production Training Mode;
- Training Mode continued to prevent operational PICKED recording while exercising the real scanner validation path.

Remaining related work is not part of this deployment entry: #205 wide-screen Scheduling Board layout correction and #206 Manager Material Status remain separate active work.

---

## Historical Boundary

This centralized log begins with the 2026-10-01 V0.3.31 deployment.

Earlier Production history remains authoritative in the existing dated acceptance records, engineering handoffs, issues, pull requests, and Git history. Historical entries may be backfilled when useful, but no pre-2026-10-01 deployment fact should be invented merely to make this log look complete.

From 2026-10-01 forward, the project rule requires this log to be updated as part of Production deployment closeout.
