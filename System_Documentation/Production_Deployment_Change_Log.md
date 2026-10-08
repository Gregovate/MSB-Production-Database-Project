# Production Deployment Change Log

| Document Control | Value |
|---|---|
| Document Type | Controlled Production deployment history |
| Repository | MSB Production Database Project |
| Status | CURRENT |
| Owner | Production project owner / administrator |
| Established | 2026-10-01 |
| Ordering | Reverse chronological — newest deployment first |

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

## 2026-10-08 — #88 disposable ACL export STOP — report still pending

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
- Operator-supplied retained report: `/home/msbadmin/setup-deployment-reports/PR305-20261007T103430Z/report.txt`. Subsequent read-only live SHA/health check confirms rollback. **V0.3.42 is not installed or accepted in Production.**
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
