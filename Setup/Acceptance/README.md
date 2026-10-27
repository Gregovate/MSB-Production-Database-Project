# Setup Acceptance Tooling

October 26 PR463 first attempt stopped ONLINE at isolated Scan artifact verification: Windows Git archive produced CRLF bytes (`3e899a6a...`) instead of accepted LF bytes (`f9b82250...`). Report `PR463-Equipment-Location-20261026T154830Z` proves live Scan and Directus state unchanged, validation root/TAR removed, no maintenance entry or migration. Transport now uses command-local Git EOL overrides and verifies archived src/dist against exact Git blobs before SCP. Regression reproduces the original failure with `core.autocrlf=true` and `core.eol=crlf`, on Linux and Windows. Accepted application and server helpers unchanged; corrected deployment completed with server PASS in `PR463-Equipment-Location-20261026T155409Z`; protected browser/live Scan acceptance remains pending.

PR463 accepted equipment/location release: `run_setup_463_release.ps1` defaults to ONLINE preflight; `-Deploy` runs the established maintenance controller and snapshot gates for the four pending migrations, then the existing Scan runner. Exact app `820b154cd664f0cac0d1d8dfd38e47b4fe19df9c`; live Scan acceptance remains pending. Failure retains the report and snapshot; do not replay. Production execution PASS is recorded in [the deployment change log](../../System_Documentation/Production_Deployment_Change_Log.md); do not rerun.

`measure_171_controller_transport.ps1` complements the server probe with three read-only GETs through the already-running localhost8898 preview tunnel. It reports headers/body download/PowerShell parse durations and bytes to Documents/MSB-Diagnostics, without API writes, SSH changes or database access. Browser rendering is not measured. Use only while the existing preview remains open; PR463 supplies the pinned no-edit invocation.


## #171 controller initial-load diagnostic (existing preview only)

`diagnose_171_controller_preview.py` attaches read-only to the existing port8898 reusable preview state and exact expected SHA. It performs only loopback GETs and clone-local EXPLAIN ANALYZE SELECTs within BEGIN READ ONLY / SET LOCAL ROLE fieldwiring_app; no migrations, Production connection, credentials/process-environment discovery, service changes or clone lifecycle changes. SQL comes from the running candidate's existing query builders. Uses documented `/opt/fieldwiring/.venv/bin/python`, foreground SSH/sudo and container-local psql. Full HTTP measurements and SQL plans are retained in `/home/msbadmin/setup-acceptance-reports/Controller_Initial_Load_Diagnostic_<tag>.json`. The original preview runner owns cleanup. PR463 contains the exact-byte pinned upload/run/download block; use a second PowerShell window and leave the preview open. This is diagnostic evidence, not Production or browser acceptance.


## #171 accepted panel correction — Production preparation

[PR455 incremental panel-slot release](Setup_171_Panel_Production_Release.md)
records accepted V0.4.22 and the existing-controller release profile. Initial GIS
installation must not be replayed. Production execution remains pending.


## #205 current non-mail KPI and Report Work candidate

[V0.3.79 source-tested #205 review: shared sticky current Setup Day beside Find Scheduled Task; full integrated six-defect/cross-Catalog corrections, migration 075/076 and both rollback checks, one disposable browser clone; operator acceptance pending](Setup_205_KPI_Action_Center_Disposable_Candidate_2026-10-15.md). Daily email/Directus integration is parked separately and excluded. Not a Production deployment or browser acceptance.


Current integrated #122 candidate: [field release checkpoint and review](Setup_122_Integrated_Field_Release.md). This supersedes separate preview handoffs for the included PR308/309/318/321 changes.


## #88 current contents recovery

[October 17 event494 field-picture findings and recovery order](Setup_88_Contents_Reconciliation_Candidate.md#october-17-current-field-picture--event-494)
distinguish coherent C154/C155 returns, still-old C216 detachments, protected
Standalone violations, C052/C053 returned-but-attached wraps, missing C131
Display location, historical review flags and source-proven report gaps.
Guided behavior/070 shipped via #318 on October10 despite the old #309 draft
remaining open. Manager resolve/correct and Containers to Move remain unfinished.
The PDF analysis performed no Production mutation; the October8 source pins and
handoffs below are historical release evidence, not current deployment advice.

## #88 October 8 report-only Production release — historical

[Approved Container Movement source-only release and pinned install handoff](Setup_88_Container_Movement_Report_Deployment.md)
uses V0.3.50 / exact application 6c44a082dd520b75881c50ad2ce78feb029ff87d.
Production server installation passed on October 8, receipt
`/home/msbadmin/setup-deployment-reports/Setup88Read-20261008T214153Z`.
The combined run installed only approved migration 071 (SELECT on two Container
type columns) plus the exact reviewed report under one controller maintenance
window. Current-clone acceptance, frozen preservation, ONLINE/service/health,
deployed tests/role reads and cleanup passed. Protected browser verification and
snapshot path/hash transcription remain pending. **Do not rerun deployment.**

[Read prerequisite, failure history and actual server receipt](Setup_88_Report_Read_Prerequisite.md)
retain earlier transport/backup/stdin STOPs and their corrections. Execution used
merged tooling main `cc93378f`; that run deployed `6c44a082` / V0.3.50.
Guided #309, migration 070 and historical movement repair were separate then. No
operator pause or new workstation dependency was needed.

## #88 contents reconciliation browser candidate

[Implementation, reconnaissance, verification and exact-candidate review handoff](Setup_88_Contents_Reconciliation_Candidate.md).

[Reusable #88 daily field picture](setup_88_daily_field_picture_readonly.sql) is
read-only SQL for the existing query client: day activity, event/Display evidence,
current recorded contents/location and historical review flags. Default report day
is October 7, 2026 Chicago; run the whole script. It cannot establish unrecorded or
unsynced work, physical contents, or resolved reviews. No Node dependency.
V0.3.49 retains a Manager **Container Movement** report from Material Status: fresh printable
movement/location trail, all unresolved reasons and receipt comparison after a
prior event (123 for the October 6 snapshot). GPS-only Current display is fixed;
GPS-only report headings now show the nearest Stage reference and distance in
feet as an estimate, using each asset's own observation. Recorded destination/GPS
and calculated nearest Stage are explicitly labelled and shown together. Exact current source and
reference version are in the candidate handoff. Read-only source, not deployed.
V0.3.49 makes Empty / Not Empty / Not Sure required at ordinary Container stops,
adds quick All still here confirmation, and preserves compact observed-HERE
Stage-group removal. Uncertain event notes retain the named scope/prior evidence.
Delayed Manager review resolution, historical correction and takedown loading remain
unfinished. The overall branch reuses movement/event tables with unchanged migration 070.
Current-clone/browser acceptance and Production deployment remain pending.


## Authority

Setup acceptance consumes the runtime/safety rules owned by `Gregovate/MSB-Server-Management`:

- `docs/server/PostgreSQL_Disposable_Acceptance_Standard.md`
- `docs/server/Pre_Production_Browser_Review_Runbook.md`
- [Application and Test Port Register](https://github.com/Gregovate/MSB-Server-Management/blob/main/docs/server/Application_and_Test_Port_Register.md)
- `docs/server/Production_Database_Change_Deployment_Runbook.md`

The Production Database repository owns Setup feature migrations, validation SQL, application behavior, and the reusable Setup launchers that consume those server/runtime contracts.

The reopened #175 / DBG-2026-001 Current Location candidate has
[one acceptance record and review handoff](Setup_175_Current_Location_Candidate.md).
It uses the existing reusable launchers, no migrations, and the read-only
`setup_175_current_location_readonly_validation.sql` evidence gate. Operator acceptance
is recorded. The source-only installer is `run_setup_305_source_only_deploy.ps1`,
with pinned server runner `setup_305_source_only_deploy.py`; it enforces clean merged
main, the confirmed V0.3.40 live baseline, stopped preview, exact V0.3.42 target,
read-only movement preservation and source rollback. No migration.

The 2026-10-07 first install rolled back after focused tests shared Production's
process-global repository installers with a base-projection SQLite fixture.
The corrected runner launches that location test file separately, retains every
focused test, and proves the identical focused groups in the candidate worktree
before live mutation. [The acceptance record](Setup_175_Current_Location_Candidate.md#2026-10-07-failed-install-and-tooling-recovery)
retains the report, rollback evidence and corrected verification.

The corrected install completed with server PASS at deployed `cb053802` / V0.3.42;
the completed #305 installer is not a replay command. Greg's follow-up requests hiding
Home on GPS rows. The current presentation candidate `6e4cc77` retains V0.3.42,
updates the footer to October 7 and awaits browser review on registered port 8898.
Use [the latest handoff](Setup_175_Current_Location_Candidate.md#2026-10-07-successful-install-and-hide-home-presentation-follow-up),
then merge accepted changes to main before a new pinned source-only installation.
It also shows the recorded movement status when a current location is missing,
instead of `Location recorded — unnamed`. The [read-only status probe](setup_175_current_location_status_probe.sql)
separates recorded Pick/history, Container state and effective detached/attached
Display evidence for Greg's Elf Choir examples; physical whereabouts are not inferred.

## Required lifecycle

For database-affecting Setup work, use the same sequence every time:

```text
exact candidate + clean local checkout
    -> full Setup/Application regression
    -> ONE current-Production dump and disposable clone
    -> migrations + database assertions + feature import checks on that clone
    -> exact-candidate browser review against THAT SAME clone
    -> operator finishes browser review and exits cleanly
    -> preview/clone cleanup, retained evidence
    -> separate Production deployment runbook
```

Production mutation is not part of either reusable acceptance launcher. Production is limited to `pg_dump` and read-only evidence/fingerprint queries until the candidate has been explicitly accepted.

For database-changing work requiring browser review, use
`run_setup_disposable_browser_preview.ps1` for the combined regression, database
and browser lifecycle. Do not run the standalone database acceptance first and
then take a second dump for browser review of the same candidate. Normal cleanup
runs after the operator completes browser review and presses ENTER in the review
terminal. Closing a browser tab alone is not the runner's completion signal.
Transport loss uses the existing reconnect path; do not launch another clone
merely because the browser tunnel disconnected. Failure cleanup and retained
reports remain governed by the existing runbook.

If the candidate changes, prior acceptance is invalidated; rerun affected gates
against the exact new SHA. This does not authorize duplicate dumps merely to
move from regression/database checks into browser review.

For #171/#230 real-source acceptance, pass `-GisGpxPath`, `-GisFlwPath`, and
`-GisActor` to that same browser launcher, with the centrally allowlisted #171
migration and validation SQL. The importer runs before browser launch on that
same clone. Its exported artifacts and receipts are evidence; importing them
does not by itself establish that every application screen consumes the new data.

**Source transfer / bounded cache (October 11):** The browser wrapper
computes the exact SHA-256 of the selected GPX and FLW, probes
\`$HOME/setup-source-cache/<sha>.gpx/.flw\` on the server, and transfers a
file only when that exact source hash is absent. The October 11 first
cache-populating run may upload the ~253 MB FLW once because earlier accepted
disposable runs predated this cache. A subsequent run with unchanged FLW SHA
must print \`Reusing server FLW source <sha>\` and omit \`source.flw\` from
SCP. A genuinely new FLW version still requires one transfer: it must
**never overwrite bytes under an old hash**.

The server's incoming \`/tmp/msb-setup-disposable-browser-preview-*\` upload
bundle and temporary PostgreSQL dump are removed by normal governed browser
cleanup. The newer bounded-retention cleanup also holds an exclusive
per-operator cache lock, verifies both active source hashes, and removes
superseded hash-named GPX/FLW cache versions **only after a clean completed
browser review**. It does not remove a source on transport loss, on failed
acceptance, when another preview may be active, or if current hashes are
unverified. Original Shared Drive files, immutable PostgreSQL source
observations, LinkIQ test evidence, and acceptance reports are never cleaned
by this operation. Cache deletion is recorded as a count and bytes in the
existing preview report; skipped cleanup is visible. The current in-flight
preview is pinned to its own exact candidate SHA and will not adopt newer
runner changes retroactively.


For the combined #171/#230 GIS/circuit candidate, use the ONE reusable browser
runner with all three allowlisted migrations in order: infrastructure foundation,
panel circuit capture, GIS operations; include both rollback-only validations.
Supply the selected Master GPX and optionally LinkIQ FLW. Both applications use
one disposable clone and one listener. The selected operator must already have
Directus Manager authority. No synthetic user or separate GIS grant is created.
The candidate rejects an incomplete migration set before server contact.
FieldWiring's /fieldwiring/circuits consumes the same imported waypoint IDs and
current names as /setup/locate/. Its tests and cable evidence remain consumers of
that source; there is no competing waypoint store or LinkIQ upload facility.
Production installation and recurring GPX revision promotion remain separate
acceptance gates, not implied by successful initial-load browser review.

During browser review test the existing /setup/locate/ track-name correction
from historical NET FT-SS Reg/Spare/Aux to reviewed NET LP-08 to CL-00, reload
and search; original GPX name, geometry and source description remain retained.
Test circuit/network relationships and audit/optimistic conflict behavior only
in the disposable clone. The second, reviewed LinkIQ physical-cable-to-GPX
route-consistency exception workflow is NOT implemented or accepted yet.
Do not infer a number of cables from track description. ExpertGPS export
after editing, Android airplane-mode map, and public SVG visual acceptance
are separate required gates, not implied by preview readiness.


## Mandatory exact client/server build identity gate

Every reusable Setup acceptance launcher must fail **before server contact** when the exact candidate contains different client and server build identities.

The authoritative candidate markers are:

```text
Setup/Application/production_backend.py
    PRODUCTION_VERSION = "<build>"

Setup/Application/setup_catalog_dirty_guard.js
    CLIENT_BUILD = '<build>'
```

Required behavior:

- reusable disposable acceptance extracts both markers from the exact `CandidateSha` with `git show`;
- client and server build strings must match exactly before SCP/SSH or any server-side acceptance work begins;
- reusable browser preview requires `-ExpectedVersion` and it must exactly match that same candidate build;
- a mismatch is an acceptance-tooling failure and must be corrected in source, asset pins, and regression contracts before the candidate is tested again;
- do not dismiss a browser mismatch alert and continue operator testing;
- if application code changes to correct the mismatch, restart regression -> disposable acceptance -> browser review from the new exact SHA.

This gate exists because #205 browser review on 2026-09-29 reached a disposable preview with server `V0.3.21-scheduling-gates` while the client still declared `V0.3.20-material-authority`. The browser guard correctly exposed the mismatch, but reusable acceptance had not rejected it earlier. The reusable launchers now own that preflight so future Setup threads do not rediscover the same failure.

## Reusable disposable acceptance

Use:

```powershell
.\Setup\Acceptance\run_setup_disposable_acceptance.ps1 `
  -CandidateSha <exact-sha> `
  -TargetRef <exact-branch> `
  -MigrationPaths @(<candidate-relative Setup/Database SQL files>) `
  -ValidationPaths @(<candidate-relative Setup/Acceptance SQL files>)
```

The launcher and server runner:

- require the local checkout to be clean and exactly match the requested candidate SHA/ref;
- rerun the full `Setup/Application` regression on a detached exact-candidate worktree;
- capture current Production with `pg_dump` only;
- restore a disposable `postgis/postgis:16-3.5` clone;
- require final PostgreSQL PID 1 plus `pg_isready` before restore/use;
- mirror the current Production `fieldwiring_app` Setup read/execute privilege surface using read-only Production queries;
- apply only the migration files explicitly supplied by the feature;
- run only the validation SQL explicitly supplied by the feature;
- clean the disposable container/worktree/dump/pycache on success, failure, interruption, or HUP; and
- prove the Production Setup fingerprint and live `/opt/msb-setup` SHA are unchanged before returning success.

Feature-specific behavior belongs in the supplied migration/validation files, not in a new acceptance runner.

## Recoverable browser-preview transport

A disposable browser review must not be discarded merely because the workstation SSH tunnel resets.

The reusable Setup browser launcher now separates **application candidate identity** from later **acceptance-tooling hardening**:

- `-CandidateSha` is the exact application/database candidate under review;
- the local acceptance-tooling checkout may be a clean descendant of that candidate on the same target branch;
- the launcher records both Candidate SHA and Tooling SHA;
- tooling-only reconnect/cleanup hardening does not by itself redefine the application candidate being reviewed.

Before the operator-review wait, the remote runner writes narrow resumable state for the exact preview instance. If the SSH/PTTY transport is lost:

1. the remote wrapper preserves the healthy Flask process, disposable PostgreSQL container, candidate worktree, and existing browser writes;
2. destructive cleanup does **not** run merely because the terminal disappeared;
3. the workstation launcher reconnects a foreground SSH tunnel to that same preview;
4. the resume path verifies candidate/ref/port/operator/version, exact preview PID ownership, listener ownership, and `/api/health`;
5. the operator continues the same review from the same disposable database state;
6. normal cleanup and Production-after proof run only when the operator explicitly finishes the review or a nonrecoverable failure occurs.

Automatic reconnect remains foreground and bounded. It does not use `ssh -N`, `ssh -f`, `Start-Process ssh`, or a detached Windows SSH process.

This requirement was strengthened after #205 on 2026-09-29 proved that the browser application remained healthy while the workstation SSH/PTTY reset. The old wrapper then lost terminal input and failed cleanup, forcing repeated operator work despite an intact disposable preview.

## Stable Setup review URL

Port allocation is owned by the Server Management
[Application and Test Port Register](https://github.com/Gregovate/MSB-Server-Management/blob/main/docs/server/Application_and_Test_Port_Register.md).
Read that register before supplying a review command. Its recorded Setup review
allocation is **8898**: `http://127.0.0.1:8898/`.
Pass `-PreviewPort 8898` explicitly and retain the existing local/server
availability and ownership checks.

Reuse the recorded allocation for sequential reviews. If occupied, identify the
owner and follow the governed resume/cleanup procedure. A demonstrated need for an
alternate must be recorded in the server register before launch. An active review
keeps its configured port until governed cleanup; cancelling the local command does
not prove remote cleanup.

## Reusable disposable browser review

After disposable acceptance passes, use:

```powershell
.\Setup\Acceptance\run_setup_disposable_browser_preview.ps1 `
  -PreviewPort 8898 `
  -CandidateSha <same-exact-sha> `
  -TargetRef <same-exact-branch> `
  -ExpectedVersion <candidate-health-version> `
  -MigrationPaths @(<same candidate migrations>)
```

`-ValidationPaths` is optional for browser review. Use it only when a validation/preparation SQL is intentionally safe to leave in the disposable browser state. Do not preload a feature validation that would hide the operator behavior being reviewed.

The browser launcher preserves the same disposable-clone/Production-after safety gates and additionally:

- refuses governed Production listener ports;
- owns the foreground SSH tunnel directly;
- starts the exact candidate with the documented `fieldwiring` Python runtime;
- pins `/api/health` to the expected candidate version when supplied;
- verifies the preview operator has Setup Manager capability;
- cleans the preview process as the `fieldwiring` runtime owner;
- verifies the preview-owned TCP listener is gone after cleanup; and
- remains bounded by an eight-hour foreground timeout so an abandoned session cannot become a permanent preview.

When the terminal prints `SETUP REUSABLE DISPOSABLE BROWSER REVIEW READY`, perform the feature-specific operator checklist. Press ENTER only after the review is complete so the same bounded process performs cleanup and Production-after proof.

### People #395: exact external Apps source in reusable browser bundle

`-PreviewProfile PeopleIdentityBootstrap` uses the existing reusable launcher and registered `-PreviewPort 8898`. Unlike the default Setup profile, it also needs one exact HTML asset from `Gregovate/MSB-Internal-Web-Backbone`. Both `-ExternalAppsSha` (commit) and `-ExternalAppsBlob` (`my/apps/index.html` Git blob) are mandatory and independently checked.

The initial October 15 preview attempt with tooling SHA `5865beae...` stopped **before pg_dump/disposable clone creation**: the server's anonymous `raw.githubusercontent.com` download of the valid draft Backbone commit returned HTTP 404; exit 22. Existing Production identity fingerprints, People service, checkout and port 8898 passed cleanup/after-check. Do not retry that anonymous URL, change pins, or bypass blob verification.

The corrected reusable People profile obtains the exact external commit using **authenticated Git in a temporary workstation clone** (outside the Production Database checkout and SCP bundle), detaches at the requested SHA with `core.autocrlf=false`, verifies the committed path blob and actual HTML bytes, then copies the byte-identical file into the already-established SCP bundle. The server independently checks the bundled file's Git blob and expected visible Apps/endpoint markers **before** the Production dump. The temporary workstation source clone is removed on success/failure. This extends only the People profile; default Setup behavior and the existing SSH/reconnect/cleanup model remain unchanged.

#### People #395 operator browser checklist — only the local Apps page

The `http://127.0.0.1:8898/` screen is the **isolated Apps shell**, not a disposable copy of every linked Production application. Its buttons retain real `https://my.sheboyganlights.org/...` destinations; following one leaves the preview and **does not test the clone-only identity bootstrap**. Do not click those buttons during this review or make changes in Production. This distinction confused the operator during the October 15 review and must be explicit in future acceptance instructions.

The operator needs only to view the local Apps screen, scroll to the version footer (`MSB Apps v0.2 — Updated 2026-10-15`), verify that no Directus/Google account chooser or identity-bootstrap error banner appears, refresh the same **localhost** tab once, and verify the page remains normal. Then return to the original foreground PowerShell session and press Enter. **The server runner**, not navigation to Production Setup, checks the disposable Directus identity, Browser-only role, exact Person link, repeat/idempotence, cleanup, and Production preservation. The final PowerShell result footer is a transport/runner summary; distinguish `CLEAN EXIT` from actual operator acceptance and preserve any server report.

The repaired profile subsequently passed local Setup regression (770 passed, 5 skipped), both PowerShell and Git Bash syntax checks, and the integrated localhost Apps+People disposable browser gate on October 15, 2026. The foreground remote runner returned `PeopleIdentityBootstrap REUSABLE DISPOSABLE BROWSER PREVIEW: CLEAN EXIT` / exit 0. Production `ref.person`, `directus_users`, shared Git checkout and People service preservation checks all passed; port 8898 was released. The final report is `/tmp/MSB_People_Identity_Bootstrap_Browser_Preview_20261015T215102.txt`. This is a **completed test**, not a command to rerun. Don's preserved real first-login fixture remains unconsumed and no Production deployment was authorized.

The workstation-only result-summary example issued separately in chat was broken when its `finally` was pasted as a standalone PowerShell statement after the launcher returned. That parser error does **not** invalidate the server PASS, but must not be repeated in operator handoffs. Print a bounded final results summary through one syntactically complete script/invocation; do not ask the operator to append a separate `finally` block or pipe foreground SSH through a capture pipeline.

Detailed initial failure, corrected acquisition contract, exact source pins and final browser acceptance evidence belong in [People #395 disposable/bootstrap acceptance](../../People/Acceptance/People_Identity_Bootstrap_Disposable_Acceptance_2026-10-15.md). Both governing Server Management runbooks still apply to future reviews and release work.

## Legacy feature-specific wrappers

Older Setup acceptance files remain historical evidence for the feature that created them. They contain hard-coded candidate SHAs, migration sets, or feature checks and must not be copied or patched for new work when the reusable launchers above can express the candidate.

If the reusable launchers cannot safely express a future requirement, treat that as an acceptance-tooling gap: improve the reusable tooling first, contract-test the improvement, then rerun the exact candidate. Do not substitute an ad-hoc interactive SSH procedure.

## Migration 069 controlled deployment

[Setup #205 Migration 069 Deployment Record](Setup_205_Migration_069_Deployment_Record.md) records the merged release, verified live/acceptance evidence, Issue #37 maintenance stages, preservation checks and failure decisions. The release-specific runner and its failure-path tests are versioned here. Host preflight must PASS before the authorized deployment. Runtime procedure remains owned by Server Management.

Operator instructions: [Install a reviewed Setup change](../operatorSOP/Install_a_Reviewed_Setup_Change.md).

## Production gate

A green disposable acceptance and accepted browser review do **not** authorize Production mutation by themselves.

Only after explicit operator acceptance switch to the Server Management `Production_Database_Change_Deployment_Runbook.md`, including its live-checkout verification, validated rollback point, reviewed migration/deployment, post-deployment health/security/invariant checks, and rollback path.

## Current Production Acceptance Records

- `Setup_205_V034_Scheduling_Readiness_Fixes_Production_Acceptance_2026-10-01.md` — #205 Annual Readiness governed-write repair, readiness-card cleanup, persistent-banner removal, and wide-screen Scheduling Board V0.3.34 Production acceptance.
- `Setup_206_V033_Manager_Material_Status_Production_Acceptance_2026-10-01.md` — #206 Manager Material Status / Manager override controls / Pick List Needed For correction / performance batching / V0.3.33 source-only Production acceptance.
- `Setup_206_V0322_Pick_List_Delay_Production_Acceptance_2026-09-30.md` — #206 bounded material frontier / transient Pick Delay / automatic schedule-release / V0.3.22 Production acceptance; persisted physical movement remains #88.
- `Setup_205_Scheduling_Board_Production_Acceptance_2026-09-29.md` — #205 rolling Scheduling Board / season-only Work Order placement / Captain live-dispatch default / planned-vs-actual labor KPI / V0.3.21 source-only Production acceptance and #206 handoff.
- `Setup_172_Report_Correction_Production_Acceptance_2026-09-27.md` — #172 Report Correction -> Work Order Intake / migration 062 / Directus items.create manager-notification boundary / Production acceptance.
- `Setup_175_132_Report_Work_Production_Acceptance_2026-09-26.md` — #175 Perform Work / Captain Work List + #132 Report Work / migration 061 / Production acceptance.
- `Setup_206_Pick_List_Production_Acceptance_2026-09-25.md` — #206 rolling physical Pick List / Manager early-pick override / migration 060 / V0.3.19 Production acceptance.
- `Setup_Reusable_Name_Sync_Production_Acceptance_2026-09-25.md` — #122 reusable Catalog -> current annual task-name synchronization / migration 059.
- `Setup_122_2026_Scheduling_Board_Production_Acceptance_2026-09-25.md` — #122 real 2026 annual Session launch and accepted Scheduling Board baseline.

- `Setup_Assignment_Layer_V0313_Production_Acceptance_2026-09-12.md`
- `Setup_Resource_Upsert_Repair_Production_Acceptance_2026-09-13.md`
- `Setup_Kit_Inventory_TPost_Production_Acceptance_2026-09-15.md` — #184 durable Extra Material / Kit Inventory / T-Post subsystem plus completed #167 one-time reconstruction.
- `Setup_Planning_Summary_Production_Acceptance_2026-09-15.md` — #122 Planning Summary / hand-markup scheduler and Pick-List readiness review surface.
- `Setup_Extra_Material_Catalog_UOM_Production_Acceptance_2026-09-15.md` — #189 inline Extra Material catalog workflow plus #191 governed UOM catalog/migration 049.
- `Setup_Extra_Material_Source_Containers_Production_Acceptance_2026-09-16.md` — #198 Manager expected-source Container maintenance, source-allocation audit, and Northern Lights 66-EA correction.
- `Setup_Expected_Duration_Hours_Minutes_Production_Acceptance_2026-09-17.md` — #204 reusable expected duration Hours / Minutes UI with total-minute durable storage.

## Current V0.3.38 Production closeout

[Migration 069 and presentation acceptance](Setup_205_Migration_069_Deployment_Record.md) records the current deployed source, validated migration backup, retained reports and operator PASS. The successful migration and presentation installer are historical execution tools, not commands to rerun after success.

Every UI deployment must run `check_setup_ui_update_date.py` against the exact target before mutation. It compares the visible footer to the latest HTML/CSS/JS commit date; documentation-only commits do not advance that date. Full application regression remains required by the governing workflow.

Package accepted cross-repository artifacts with their owning source/merge and exact file identity. Do not derive a second private-repository URL from the Production origin or assume shared credentials. Keep report output on the server and return only PASS/STOP and its location.

## Tablet launch-debug candidate

[All three #205/#122 tablet launch corrections](Setup_205_Tablet_Launch_Debug_Candidate.md) are a source-only candidate. Local regression passes; disposable/browser/operator acceptance remains pending. Production is unchanged.

- [#206 live Pick demand correction candidate](Setup_206_Live_Pick_Demand_Candidate.md) — reconciles focused validation misses with visible live physical demand and refreshes stale online scan data.

## Direct required Containers — C106

[Candidate and single-clone browser checklist](Setup_Required_Containers_Candidate.md)
adds a searchable direct physical Container requirement without material/contents
records. Migration 073 is candidate-only; no Production deployment yet.

C106 direct requirement browser save/refresh and CLEAN EXIT accepted October 14;
Greg authorized migration 073 deployment. Feature PR #389 is merged. Use
`run_setup_required_container_deploy.ps1` from updated primary main; the existing
controller maintenance runner profile and committed-byte transport own the short
freeze/snapshot/install/validate/ONLINE window. No Production test assignment,
manual operator pause or repeated disposable clone. Actual installation pending.

## Scheduled search and collapsed days — DBG-2026-014

[Candidate and browser checks](Setup_205_Scheduled_Search_Focus_Candidate.md):
selecting a scheduled search result expands its day before scrolling/focusing the
assignment. V0.3.65 source candidate; no migration or Production change. Reconcile
with concurrent #205 workload/KPI changes; #389 deployment remains separate.

PR391 scheduled-search browser acceptance and CLEAN EXIT passed October14; Greg
approved merge and maintenance-mode deployment. Use the existing wrapper
`run_setup_required_container_deploy.ps1 -Release ScheduledSearch` from clean
updated main. The source-only profile requires proven prior V0.3.64/073 and
applies no migrations; same controller/lock/committed transport, no new clone.
Exact app86341d49, V0.3.65; actual Production install/closeout pending receipt.

### October 14 search deployment server PASS

Operator supplied `/home/msbadmin/setup-deployment-reports/PR391-Source-20261014T185934Z`:
exact86341d49 / V0.3.65 installed with controller ONLINE and preservation gates
PASS. No migration replay/archive for the source-only change. Prior V0.3.64/073
prerequisite verified; original C106 report still unprovided. Protected Production
search and local cleanup pending. See candidate receipt and deployment change log.

Greg confirmed protected Production search works October14 at14:02 CDT.
DBG-2026-014 server/browser acceptance is complete; Office cleanup remains
operator-side and unverified. Day View wording remains separate #205 work.

## #205 V0.3.84 / migrations 075 and 076 release

[Governed release profile and execution record](Setup_205_075_076_Release.md)
uses the existing maintenance orchestrator with ordered migration and final
validation hooks. The dedicated `run_setup_205_estimates_deploy.ps1` packages
committed bytes from merged main. The older RequiredContainers/ScheduledSearch
wrapper is not a #205 release command. Operator acceptance and CLEAN EXIT are
already approved. Production runner PASS and initial operator spot-check PASS
were received October 16; the linked record contains the transcript and retained
report directory. Do not rerun the completed release for documentation.

- [Catalog Scene placement refresh candidate](Setup_122_Catalog_Scene_Refresh_Candidate.md) — Copy/Add/Move refresh correction; operator browser acceptance pending.

- Catalog approved source promotion: `run_setup_catalog_scope_deploy.ps1` reuses the established maintenance-controlled source profile; accepted app remains pinned to PR440 revision3.

### PR464 accepted breaker correction release

[Authorized release and pinned identities](Setup_171_Breaker_Correction_Release.md): existing maintenance runner, incremental unassigned-breaker command/index migration, FieldWiring-only promotion. PR463 equipment work excluded; PR464 server deployment PASS, protected Production browser check pending.

## October 27 panel supplies and local receptacles correction

Candidate versions: Setup `V0.3.92-panel-supplies`, FieldWiring `V0.4.32-panel-receptacles`.
Use the existing reusable browser runner on 8898, exact candidate SHA/ref,
`-MigrationPaths @('Database/EngineeringTools/sql/171_panel_receptacles.sql')`
and `-ValidationPaths @('Database/Acceptance/171_panel_receptacles_validation.sql')`.
These are the only pending files after the completed PR463 deployment. Preserve
current GIS imports and circuit assignments; do not replay PR463 migrations.
Review 42-03S's supplying circuits and named receptacles at Panel42-00, including
separate supplies, save/reload/edit/removal and no extra map waypoints. Retain
CLEAN EXIT. Candidate testing does not constitute Production deployment or
protected browser/physical Scan acceptance. See the owning panel circuit checkpoint.
