# Setup Acceptance Tooling

## #88 report-only Production release

[Approved Container Movement source-only release and pinned install handoff](Setup_88_Container_Movement_Report_Deployment.md)
uses V0.3.50 / exact application 6c44a082dd520b75881c50ad2ce78feb029ff87d.
It is separate from the guided-stop draft: no migration, database copy, or movement
workflow change. The expected live rollback pin is the operator-reported installed
V0.3.42 / cb053802 from #175. Installation/protected-route result remain pending.

The October 8 server attempt stopped at the read-only preflight because the
application cannot SELECT Container type names. Production remains healthy on
V0.3.42; V0.3.50 was not installed. **Do not rerun the report installer yet.**
[Prepared two-column read prerequisite and proof](Setup_88_Report_Read_Prerequisite.md)
was authorized at October 8 10:33 CDT. Use
`run_setup_88_report_read_deploy.ps1`: current-clone/actual-read acceptance,
controlled maintenance permission step, ONLINE proof, then the unchanged pinned
source installer. Host execution and protected browser results remain pending.

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

## Required lifecycle

For database-affecting Setup work, use the same sequence every time:

```text
exact candidate + clean local checkout
    -> full Setup/Application regression
    -> disposable current-Production clone acceptance
    -> exact-candidate browser review against a fresh disposable clone
    -> operator acceptance
    -> separate Production deployment runbook
```

Production mutation is not part of either reusable acceptance launcher. Production is limited to `pg_dump` and read-only evidence/fingerprint queries until the candidate has been explicitly accepted.

If the candidate changes after either gate, start again from the new exact SHA. Do not carry forward a prior disposable clone or browser preview.

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
