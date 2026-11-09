# #445 Shared trailer unloading — disposable correction candidate

Status: **UNTESTED / review required**. Commanding #122. Do not deploy to Production or merge as accepted.

## Scope and source
Issue #445 and its operator evidence (October 21, 2026) govern this correction. One Arch trailer unloading run is #122; one new Antenna unloading run will be created. #387 remains parking-lot drop-off and #86 is not reinterpreted as unloading. Scanner bugs are owned by #88.

This work branch is based on main `2d65781d73c761f0320eefd35fc06a5bf7b7dfa9`. The repository has two independent dependency graphs, `ref.setup_task_dependency` and `ops.setup_session_task_dependency`. Both must be changed, and reported work lives against the existing annual task identities.

## Candidate files
- `Setup/Acceptance/setup_445_current_state_readonly.sql`: current-state capture; safe SELECT on Production.
- `Setup/Acceptance/setup_445_disposable_correction_probe.sql`: **rollback-only**, guarded to a disposable/clone/preview/acceptance database. Tests the actual task/material/dependency transformations in a single transaction; no persistent changes.
- The existing `run_setup_disposable_acceptance.ps1` and `setup_disposable_acceptance_server.sh` are reused; no new server runner or clone convention.

## Intended changes
- Retain reusable and annual Arch unloading task #122; create reusable and 2026 annual `Unload Antenna Trailer` with no invented completion.
- Deactivate reusable #17/#20/#32/#126/#306. Keep their annual 2026 rows (including work reports, crew records, audits, timestamps, assignments, and movement evidence) while setting `included_flag=false`. 2025 not modified.
- Transfer #20 C034 requirement to installation task #21; #32 C034 and Display 785–832 to installation #34; require conflict-free destination ownership. Do not touch Greg's #17→#19 material reassignment.
- Replace redundant predecessors in Catalog and 2026 graphs. #34 requires both #122 and #33. #213 requires the new Antenna unloading task. #387 and unrelated prerequisites unchanged.
- Existing actual work is not relabeled, duplicated, transferred, or fabricated.

## Acceptance
**Not yet executed on a disposable clone.** Repository commits alone are not a database PASS, and the rollback probe is not a Production change script. All edits stop here until exact-SHA disposable validation completes, the reviewed current DB evidence matches the asserted assumptions, and Greg approves the resulting candidate. The wrapper must prove Production fingerprint and live checkout unchanged.

From a clean candidate checkout, use:

```powershell
$ErrorActionPreference = 'Stop'
git fetch origin
if ($LASTEXITCODE -ne 0) { throw 'git fetch failed' }
git switch issue-445-shared-trailer-unload-disposable
if ($LASTEXITCODE -ne 0) { throw 'git switch failed' }
git pull --ff-only origin issue-445-shared-trailer-unload-disposable
if ($LASTEXITCODE -ne 0) { throw 'git pull failed' }
$sha = (git rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0) { throw 'Unable to resolve candidate SHA' }
& .\Setup\Acceptance\run_setup_disposable_acceptance.ps1 `
 -CandidateSha $sha `
 -TargetRef issue-445-shared-trailer-unload-disposable `
 -ValidationPaths @('Setup/Acceptance/setup_445_disposable_correction_probe.sql') `
 -AllowConcurrentProductionWrites
if ($LASTEXITCODE -ne 0) { throw 'Disposable acceptance failed; stop' }
```

The above is a **test only**, not a persistent even-on-clone migration: the SQL uses `ROLLBACK`. Request a separate approved, version-pinned mutation-bearing candidate only after the database trial and operator review. A real browser review would then use the registered Setup browser preview mechanism, not a new server.

## Known gates / unresolved
- Actual live DB row shapes and dependency/material assumptions may differ; SQL intentionally throws instead of improvising.
- Confirm that the remaining 2026 work assignments for retired tasks remain visible for historical reporting while they are excluded from active planner.
- Verify #20→#21 installation material ownership and #32→#34 exact Racing display ownership with Greg against a disposable preview before a Production migration is built.
- Keep #445 open and do not interpret a SQL rollback PASS as browser acceptance.
