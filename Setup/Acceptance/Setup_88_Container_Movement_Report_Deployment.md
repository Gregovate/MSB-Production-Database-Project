# #88 Container Movement report — source-only deployment

| Document control | Value |
|---|---|
| Status | PRODUCTION SERVER PASS 2026-10-08; protected browser verification pending |
| Owner | #88, commanding #122; Material Status #206 |
| Reviewed | 2026-10-08 America/Chicago |
| Current main at reconnaissance | `3ddda03221ae475ffec5399ea4955e9c1e728419` |
| Visible release | `V0.3.50-container-movement-report` |
| Exact application source | `6c44a082dd520b75881c50ad2ce78feb029ff87d` |
| Expected live / rollback source | `cb0538022ed066ff90675e832daa1cd95488114a` / `V0.3.42-current-location` |
| Expected shared checkout | `6dd05c4aa5ef8f50fe172145c3ae281cc245a101` — remains in place |
| Application PostgreSQL writes | NONE; combined release installed separately approved two-column SELECT grant 071 |
| Integration PR / execution main | #310 report; #312–#315 prerequisite/tooling; `cc93378f6ad62f353c5994860ebd98dff54a86aa` |
| Actual deployed source / report / protected-route result | `6c44a082dd520b75881c50ad2ce78feb029ff87d` / `Setup88Read-20261008T214153Z` / browser PENDING |

## October 8 Production installation — server PASS

Greg supplied final combined runner PASS at 16:43 CDT, report
`/home/msbadmin/setup-deployment-reports/Setup88Read-20261008T214153Z`.
Exact V0.3.50 report source and the approved narrow read grant are installed;
frozen preservation, return to ONLINE, health, deployed tests/role reads and
cleanup passed under the runner. [The prerequisite record](Setup_88_Report_Read_Prerequisite.md#october-8--production-server-pass)
records the receipt and remaining protected browser/archive closeout. No guided
workflow or historical repairs were included. Do not rerun deployment.

## October 8 original preflight STOP — Production unchanged at that attempt

The first server attempt retained
`/home/msbadmin/setup-deployment-reports/Setup88Report-20261008T151700Z/report.txt`.
The exact report read probe failed under `fieldwiring_app` with
`permission denied for table container_type`, before live checkout or service
restart. Temporary candidate cleanup succeeded. Operator readback proves live
`cb0538022ed066ff90675e832daa1cd95488114a`, service active, PostgreSQL healthy,
`V0.3.42-current-location`. V0.3.50 was **not installed by that attempt**.

The report's type-name join is required for its reviewed Container type labels
and protected Standalone/single-Display Pallet warnings. Existing Setup reads
avoid that lookup for Kit Boxes by using the governed ID 2; that does not supply
all report types. No approved general type-name view was found. Do not invent
numeric type IDs, suppress the warnings, or run the probe as administrator.
The separate `ref.display_status` read is already granted by migration 025.

[Proposed narrow read prerequisite](Setup_88_Report_Read_Prerequisite.md) adds
SELECT on only `container_type_id` and `container_type_name`; it has no business
data, structure or write-privilege changes. Greg separately approved it at
10:33 CDT. Use the combined controlled launcher in that record: clone acceptance,
one maintenance window for the grant and report promotion, frozen preservation
proof, then controller ONLINE/health/live checks. The report remains SQL read-only
and does not apply the grant implicitly. The later combined host run passed as
recorded above; the failed handoff and completed installer must not be rerun.

## Authorization and release boundary

On October 8 at 09:33 CDT Greg said the candidate looked good and reported browser
CLEAN EXIT. At 09:35 he explicitly instructed **deploy the new report**. This
approves Container Movement, not migration 070, historical repair or the unfinished
review/loading tools. PR #309 remains the guided-scan draft.

The report was extracted from reviewed source
`fe801e18f58acc58c0d4d6798d9ab6c334648b2e` onto current main as a separate report-only
release. Report module/template, Material Status API/screen/JS/CSS are byte-identical
to the reviewed report. Material Status's existing observation SELECTs additionally
return recorded GPS/accuracy/quality/age. Its planning/ownership model and commands
are unchanged. The new report test's miniature SQLite fixture explicitly supplies
existing event destination columns; this is a test fixture change, not a migration.

Server/client identities use V0.3.50 to distinguish this bounded Production release
from V0.3.49 guided-stop preview. Root visible Updated date is October 8, with a
new client asset pin. Record Location JS/CSS/service-worker, movement repository/
API, assignment/ownership layers, Perform Work renderer, location references and
all Setup/Database files remain identical to current main. Existing V0.3.42
Current Location remains; the pending #308 Home refinement is not silently released.

From **Material Status → Container Movement**, the Manager-only fresh read shows
current recorded assignments and complete movement/effect trails, Display Names,
recorded destination/GPS alongside calculated nearest Stage/distance in feet,
separate prior named context, all unresolved material-authority reasons and
historical review flags. Compare after an event and Print/Save PDF remain. A
calculated nearest point is not recorded placement; recorded detachment does
not establish physical removal. No report action repairs or resolves contents.

## Live baseline and authority

[Latest #175 operator installation evidence](https://github.com/Gregovate/MSB-Production-Database-Project/issues/175#issuecomment-6015355015)
records corrected installer PASS at
`/home/msbadmin/setup-deployment-reports/PR305-20261007T105751Z`, installing
cb053802 / V0.3.42. The earlier V0.3.40 rollback is superseded as expected live
source. Full new report/fingerprint and protected-route acceptance were not
supplied; do not reuse the failed attempt's fingerprint. The new installer obtains
fresh SHA/health/data checks and refuses drift. Never rerun the historical #305 runner.

Governing authority retrieved/read in this workstream:
[Server Management — Setup Source-Only Application Deployment Runbook](https://github.com/Gregovate/MSB-Server-Management/blob/main/docs/server/Setup_Source_Only_Application_Deployment_Runbook.md),
blob `4d243cc8b0c712fd47a38b77ef0a83ac474bbf77`. It requires a clean forward
application update, exact target regression, before/after read-only preservation,
only Setup service restart and old-source rollback. This is not a database-changing
release and does not enter database-wide maintenance or make a rollback dump.

The source-only runner is adapted from the corrected merged #305/#307 pattern.
It checks 8898 is stopped, exact clean detached live source, expected shared
checkout and baseline health; fetches explicit main without credential prompts;
proves target is merged/forward and no Database source differs; verifies exact
server/client version and UI date; runs full Application and focused groups on a
temporary detached candidate as fieldwiring before mutation. The location fixture
runs in a separate interpreter to prevent the known installed-method contamination.
The identical focused groups repeat after restart.

It also executes the exact report SELECTs on Production **READ ONLY under
fieldwiring_app** before and after installation, using count wrappers to avoid
logging field records. The deployment's data fingerprint covers governed Setup
planning/session data and Container/Display state/events/master assignments.
Failure after advancement returns to exact V0.3.42 and restarts only Setup. Only
this runner's temporary regression worktree is cleaned; reports are retained.
No environment/service-unit/shared checkout/proxy/firewall change is performed.

## Verification

- Exact application-only candidate: **761 full Setup tests**, browser/print/tablet
  checks PASS on actual Material Status/report routes with synthetic data; exact
  read-only report SELECTs executed in PostgreSQL/WASM; JS/diff/UI date gate PASS.
- With pinned installer: **775 full Setup tests**, **14 installer boundary tests**,
  identical focused groups **198 + 22 passed**. Node-absent Windows simulation:
  **716 Application passed / 2 engineering checks skipped**; no Node install needed.
- Original report fixture/API permission/comparison/escaping/attached/detached and
  supplied nearest-reference regressions retained. No broad DB write permission.
- Private SSH from this workspace reports network unreachable. No assistant server
  install, live fingerprint, service restart or Production report result is claimed.

## Historical workstation handoff — BLOCKED by read prerequisite

**Do not execute this handoff until the read prerequisite is accepted and proven.**

Confirmed current prompt: laptop `C:\lor\ImportExport\VSCode`. Run there. This
finds main by reading worktree inventory line by line. If no worktree has main,
it safely switches a clean primary checkout to the existing local main branch
or creates main tracking origin/main. It never resets a branch or discards files.
Native failures stop the whole sequence.
The main checkout must be clean. This historical standalone handoff is retired;
the current combined runner uses the controller fence through source promotion
and does not require an operator edit pause.
Greg already reported preview CLEAN EXIT; server preflight independently checks.

```powershell
& {
    $ErrorActionPreference = 'Stop'
    $PrimaryReport88 = 'C:\lor\ImportExport\VSCode'
    function GitReport88 {
        & git @args
        if ($LASTEXITCODE -ne 0) { throw "STOP: Git failed: $args" }
    }
    Set-Location $PrimaryReport88
    try {
        GitReport88 fetch origin main
        $MainPathReport88 = $null
        $WorktreePathReport88 = $null
        foreach ($LineReport88 in @(GitReport88 worktree list --porcelain)) {
            $LineReport88 = ([string]$LineReport88).TrimEnd()
            if ($LineReport88.StartsWith('worktree ')) {
                $WorktreePathReport88 = $LineReport88.Substring(9)
            }
            elseif ($LineReport88 -eq 'branch refs/heads/main') {
                $MainPathReport88 = $WorktreePathReport88
            }
        }
        if (-not $MainPathReport88) {
            if (GitReport88 status --porcelain) { throw 'STOP: preserve primary checkout changes first.' }
            if (@(GitReport88 branch --list main).Count -gt 0) {
                GitReport88 switch main
            }
            else {
                GitReport88 switch -c main --track origin/main
            }
            $MainPathReport88 = $PrimaryReport88
        }
        Set-Location $MainPathReport88
        if (GitReport88 status --porcelain) { throw 'STOP: preserve main checkout changes first.' }
        GitReport88 pull --ff-only origin main
        .\Setup\Acceptance\run_setup_88_report_source_only_deploy.ps1
        if ($LASTEXITCODE -ne 0) { throw 'STOP: installation failed; retain report and do not rerun.' }
    }
    finally {
        Set-Location $PrimaryReport88
    }
}
```

The wrapper requires clean merged main and packages the committed pinned runner
using the established UTF-8/line-ending-safe transfer pattern. Foreground SSH
owns password/sudo interaction. It prints the exact old/new source and authority.
Retain final PASS/STOP plus server report path. No database is copied by this install.

After PASS, refresh the real protected Setup route, confirm **Client/server V0.3.50**
and **Updated 2026-10-08**, then **Material Status → Container Movement**. Verify a
fresh real report/database/session/watermark, both recorded and calculated fields,
GPS feet and print. Do not create fake Production movements to test a read-only
report. A deployed-source report failure follows the runbook's source rollback.

## Closeout and local worktree disposition

Server installer PASS, deployed SHA/version, report path and frozen preservation
are recorded above. Protected-route acceptance and snapshot path/hash
transcription remain pending; no rollback was reported.
After server/operator proof, update this record, owning issue/PR/#122, the
reverse-chronological Production Deployment Change Log and Server Management
runtime authority. Later documentation commits are not another installed source.
Do not close #88 or DBG-2026-007/009/010: Manager review resolution, historical
correction and takedown loading remain unfinished.

The unmerged guided-scan review worktree/branch must be preserved. CLEAN EXIT
cleaned the server preview, not that local engineering worktree. This install
returns the operator to updated primary main. Report-only worktree cleanup is
safe only after checking its branch, clean status and merged containment; never
force-remove unrelated/unmerged work.


### October 8 checkout handoff correction

At 09:55 CDT the original blank-record inventory parser stopped with
`cannot identify the existing main checkout` at Greg's laptop primary prompt.
This happened before local pull or any server contact/Production action. The
handoff incorrectly required main to already be checked out and depended on
blank lines surviving native output. Corrected navigation parses inventory lines
and handles main checked out elsewhere, local main not checked out, and local
main absent, with clean-status guards and no forced removal/reset. The exact
application/installer/rollback pins and server gates remain unchanged. No actual
server installation or rollback is inferred from this workstation-only stop.
