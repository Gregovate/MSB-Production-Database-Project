# #175 Current Location launch stabilization candidate

| Document control | Value |
|---|---|
| Status | V0.3.42 installed — Home visibility and missing-location status candidate awaiting browser review |
| Reviewed | 2026-10-07 |
| Owner | #175, commanding #122 / DBG-2026-001; #88 movement dependency |
| Baseline main | `3ddda03221ae475ffec5399ea4955e9c1e728419` |
| Branch | `fix/175-hide-home-with-gps` |
| Release | `V0.3.42-current-location` |
| Application candidate SHA | `6e4cc77eed51559554a528ab1c8ab1ec7e04ba92` |
| Currently deployed application SHA | `cb0538022ed066ff90675e832daa1cd95488114a` |
| Database migrations | None |

## Bounded correction

`field_context()` reads effective movement status/event, observed time, coordinates,
accuracy, fix age, quality and capture method. Attached Displays follow Container
evidence; detached Displays retain their own event pointer, including Container
unload events. No new observations, reference-data cleanup, or schema changes.

The material panel, its task-cover-sheet copy, and the older overlay share truthful
Current/Home presentation. Named evidence is preserved; GPS-only evidence shows
a compact nearest known waypoint name/distance with recorded GPS coordinates and
accuracy behind an expandable GPS disclosure. It uses the existing versioned Record Location reference
set; proximity does not confirm placement at that waypoint. Unnamed movement and no observation have explicit text.
Home storage is shown only when valid recorded GPS coordinates are unavailable.
Grouped legacy Displays retain individual locations. The print sheet uses the same rule.
Without GPS/named location, show the actual recorded movement status (for example,
Picked or Unloaded) followed by `current location not recorded`. Do not hide that
status behind the former `Location recorded — unnamed` wording or infer Not Picked.

No appropriate healthy open implementation PR owns this bounded defect. #266 is
stale and unrelated offline rehearsal; #230 reference cleanup is outside this fix.

## Verification and limitations

- Linux engineering verification: full `Setup/Application` regression **705 passed**; `Setup/Acceptance` **31 passed**; combined **736 passed**. On Windows, run `Setup/Application` only; the acceptance-tooling suite includes Linux-only installer imports (`fcntl`).
- 22 tests execute the actual projection SELECTs using SQLite with only text casts
  array binds and placeholders translated, classify evidence, exercise Flask Decimal/timestamp
  transport, and execute the actual JS helpers/legacy grouping under Node.
- Checks cover GPS-only Container, attached/no-override Display inheritance,
  detached unload evidence after Container movement, missing detached evidence,
  season isolation, named Stage/Scene scope, unresolved movement, quality/accuracy,
  explicit RETURNED note, no-observation Home separation, and escaped output.
- SQLite is a local semantic fixture, not PostgreSQL/current-Production acceptance.
- Changed JavaScript syntax and whitespace checks pass. Exact committed footer gate: PASS, Updated 2026-10-06; server/client identity both V0.3.42-current-location.
- Browser execution was not possible here: no installed Chromium; Playwright's
  browser download returned a truncated/invalid archive.
- This workspace has no established MSB private SSH/server access. No current
  Production clone or real steeple browser check was performed here.
- Production is untouched. #175 and DBG-2026-001 remain open pending acceptance/deployment.

## First browser rejection and active-path correction

Greg's V0.3.40 browser check on 2026-10-06 showed all six steeple Displays as
`Current location not recorded`, while DBeaver's read-only Production query
confirmed Session 2 / 2026, DETACHED / TASK_UNLOAD, effective event 43 for
853/860/861 and event 44 for 834/840/848. Both events have 3.00 m GPS accuracy:
43 is (43.778465, -87.749201), 44 is (43.778556, -87.749142).
The screenshot proves the changed renderer was loaded, not that its evidence was correct.

Root cause: `production_backend` installs automatic material resolution, Display
ownership, then the corrected assignment layer. These replace the base
`SetupNextRepository.field_context`; their active projection queries omitted
movement/GPS fields and the location classification. The first candidate fixed
the base method only. Its tests exercised that uninstalled method and missed
the actual Production API path. **V0.3.40 / c54019d671497d30d5d8992f212afd0bd816108e
failed browser acceptance and is superseded.**

V0.3.41 adds effective state/event/GPS projection and classification to the active
material resolver, support-Container query and assignment source query. It preserves
LOR membership and assignment filtering. Six additional isolated-process cases import
the real Production host, install its full method chain, execute its SELECTs and call
the real Flask field-context route with all six steeples. Cases cover detached unload,
attachment, later parent movement, explicit ownership filtering, no observation and
another season. All six new cases fail on the prior candidate's missing classification;
all pass on the corrected candidate. The clone SQL gate now checks effective evidence
for every steeple Display as well as the two parent Containers.

This is still a source-only correction with **no migrations**. The new exact candidate
requires fresh disposable acceptance and browser review on registered port **8898**.
Finish the old preview with ENTER and retain CLEAN EXIT before launching the new one.

## Operator presentation correction — V0.3.42

The next browser screenshot shows GPS observations and accuracy for the steeples
and crosses, proving the active read-path correction reached the screen. Greg
requested changes because `GPS observation · ±10 ft` does not say where the asset is.

V0.3.42 retains the effective recorded coordinates and derives a nearest waypoint
from the existing `setup_location_references.json`, version
`2026-stage-reference-20261003.1`. The nearest-reference calculation uses the same
spherical distance in feet as Record Location, with already-transformed WGS84
coordinates. The reference file, source EPSG:8158 anchors, movement history and
Stage assignments are unchanged.

Expected steeple presentation:

- C177 Displays: `Current: nearest waypoint 15-Church-Bells-CH · 46 ft away · ±10 ft`;
  `Recorded GPS: 43.778465, -87.749201`.
- C178 Displays: `Current: nearest waypoint 15-Church-Bells-CH · 76 ft away · ±10 ft`;
  `Recorded GPS: 43.778556, -87.749142`.
- Home storage remains a separate reference line.
- A confirmed named Stage/note takes precedence. Nearest means geographical
  proximity to an anchor in this curated set, not confirmed destination/placement.
- Missing reference data falls back to recorded coordinates, never Home or a
  guessed waypoint. Invalid observations/reference points cannot generate a label.

The full installed-Production API tests check nearest name/distance/provenance for
all six steeples. Additional cases cover confirmed-name precedence, absent reference
data, invalid coordinates/waypoints, coordinate formatting and escaped waypoint labels.
**V0.3.41 browser disposition: CHANGES REQUIRED.** New-candidate disposable/browser
acceptance remains pending; Production is untouched.

## Compact presentation and concurrent Pick reconciliation — 2026-10-06

Greg confirmed the original V0.3.42 candidate `7390012daea2e67e1cab92ee80616da7d0524d47`
is working. His screenshot `image(20261006-144217).png` shows the two crosses and
all six steeple Displays with Church-Bells proximity, recorded coordinates and
Home references. **Location evidence is working; presentation CHANGES REQUIRED: too wordy.**

The current candidate keeps V0.3.42 under the presentation-only exception in the
Release Identity and Versioning Rule. Its exact SHA above supersedes the earlier
candidate for review. Main was refreshed to `5109fff5145122525c7ea9ae5d2bc0ff5d6b994a`;
accepted PR #306 live Pick demand resolution, online cache refresh and scanner
shell v18 are integrated without reverting them.

Default rows now show:
- C177: `Current: near 15-Church-Bells-CH (46 ft) · Home: Z-BLDG-B-EAST`.
- C178: `Current: near 15-Church-Bells-CH (76 ft) · Home: Z-BLDG-B-EAST`.
- Crosses C8: `Current: near 15-Church-Bells-CH (64 ft) · Home: RC05-A-01`.

A small native GPS disclosure retains coordinates and accuracy, initially collapsed
and operable by touch/keyboard. GPS quality warnings remain visible in the current
location line. Without a usable reference, the coordinates remain directly visible.
The printed task sheet expands the disclosures in its copy, leaving the live page
collapsed. Nearest means proximity, not confirmed placement. No database/API evidence
semantics, reference anchors or movement history changed.

**705 application + 31 acceptance-tooling = 736 passed** on Linux, including the
five live Pick demand regressions. Tested/uploaded tree:
`c9a174f76a2aa06b244960cff6164faac7e2e9ce`. Actual rendering-helper checks cover
compact labels, default-closed GPS details, coordinate/accuracy retention, quality,
escaping, no-observation rows and legacy grouping. JS syntax, whitespace and exact
committed footer gate pass. Fresh disposable acceptance/browser review of the
combined exact candidate remains pending; no #175 Production deployment or merge.

End the existing preview with ENTER and wait for CLEAN EXIT before running the
updated command below. Keep port 8898. Closing the browser alone does not clean up
the remote preview; network loss can preserve it for reconnect.

## Operator acceptance — 2026-10-07

Greg confirms the requested Current Location behavior is now working. Screenshot
`image(20261007-100206).png` shows Mt. Crumpit Displays 2/3/4 near 07-Whoville-WV
at 51/50/47 ft, standalone pipes 1132/1133/1134 at 39 ft, with compact GPS controls
and Home references where present. Many additional Containers moved on Oct 6.
Earlier Church/Cross evidence is retained above. **Current Location operator PASS.**

Record Location's unload-checkbox confusion remains tracked under #88. Select
only Displays/groups physically removed here; unselected groups remain WITH_CONTAINER
and follow later Container movements. This candidate changes no unload/history semantics.

Preview CLEAN EXIT/report evidence is still pending. GPS expansion and Print Task
were requested but no separate evidence was supplied; no completed check is inferred.
No #175 merge or Production installation is claimed.

The governing source-only runbook was retrieved/read again on Oct 7. Runtime docs
still carry the older Oct 4 V0.3.38 pin; PR #306's record lacks execution evidence.
The required live Setup HEAD/health and shared checkout baseline was subsequently
supplied by Greg; see the pinned source-only section below. The approved
application target remains `cb0538022ed066ff90675e832daa1cd95488114a`.
The prepared source-only installer pins that confirmed baseline; actual installation
follows main integration, preview cleanup and the authorized operator-run install window. Do not reuse the historical migration-bearing #175/#132 installer.

## Governed disposable review

Authorities retrieved and read for this workstream:

- Server Management `docs/server/PostgreSQL_Disposable_Acceptance_Standard.md`.
- Server Management `docs/server/Pre_Production_Browser_Review_Runbook.md`.

Use a clean branch worktree at the exact application candidate named in the PR.
The tooling checkout may be a clean descendant on the same branch under the
existing launcher contract. The review is read-only against Production;
all application writes are confined to its disposable clone. No maintenance
window or Production deployment is included.

On Windows, local regression is `python -m pytest -q -p no:cacheprovider Setup/Application`.
Do not include `Setup/Acceptance` in that Windows invocation: its Linux deployment
installer tests import `fcntl`. The reusable server runner independently runs the
exact candidate's full `Setup/Application` regression on Linux before cloning.

Run the sequence as one PowerShell script block so a thrown failure ends the whole
sequence. Separately pasted interactive commands can still run after an earlier throw.
From that worktree, using the exact SHA recorded in the PR:

```powershell
& {
    $ErrorActionPreference = 'Stop'
    # Local VS Code Windows PowerShell; use your existing candidate checkout.
    function Invoke-Git175 {
        & git @args
        if ($LASTEXITCODE -ne 0) { throw "STOP: Git failed: $args" }
    }
    if (Invoke-Git175 status --porcelain) { throw 'STOP: local changes need preservation.' }
    Invoke-Git175 fetch origin
    Invoke-Git175 switch fix/175-current-location-evidence
    Invoke-Git175 pull --ff-only origin fix/175-current-location-evidence

    $Candidate = 'cb0538022ed066ff90675e832daa1cd95488114a'
    $TargetRef = 'fix/175-current-location-evidence'
    $Validation = @('Setup/Acceptance/setup_175_current_location_readonly_validation.sql')

    python -m pytest -q -p no:cacheprovider Setup/Application
    if ($LASTEXITCODE -ne 0) { throw 'STOP: local application regression failed.' }

    .\Setup\Acceptance\run_setup_disposable_acceptance.ps1 `
      -CandidateSha $Candidate -TargetRef $TargetRef `
      -MigrationPaths @() -ValidationPaths $Validation `
      -AllowConcurrentProductionWrites
    if ($LASTEXITCODE -ne 0) { throw 'STOP: disposable acceptance failed; inspect retained report.' }

    # Reuse the established Setup review port 8898; verify it is unused.
    # STOP on an occupied/unknown listener instead of replacing it.
    .\Setup\Acceptance\run_setup_disposable_browser_preview.ps1 `
      -CandidateSha $Candidate -TargetRef $TargetRef -PreviewPort 8898 `
      -ExpectedVersion 'V0.3.42-current-location' `
      -MigrationPaths @() -ValidationPaths $Validation `
      -AllowConcurrentProductionWrites
    if ($LASTEXITCODE -ne 0) { throw 'STOP: browser preview failed; inspect retained report.' }
}
```

Reuse Greg's established Setup review URL `http://127.0.0.1:8898/` under
[the Server Management port register](https://github.com/Gregovate/MSB-Server-Management/blob/main/docs/server/Application_and_Test_Port_Register.md).
The initial #175 startup attempt was configured on 8806. Greg confirms the browser
review never started. The workstation launcher reported start exit code `-1` and
classified it as not resumable. This does not identify the underlying remote failure. The retained browser report is
`/home/msbadmin/setup-acceptance-reports/Setup_Disposable_Browser_Preview_20261006T114947.txt`.
Read that report first; do not assume there is a running review to finish. If the
report shows preview resources were created, inspect only that recognized instance
through the governed diagnostic/cleanup flow before a fresh launch on 8898.
BROWSER REVIEW READY and browser acceptance did not occur. The wrapper does not
automatically resume start exit `-1`. A new candidate does not require a new port.

Do not open the URL until **BROWSER REVIEW READY**. Finish with ENTER and retain
CLEAN EXIT, exact SHA/version, before/after evidence and report locations.

## Exact browser checklist

1. Verify disposable banner, Client/server V0.3.42 identity and Updated 2026-10-06.
2. Perform Work -> All scheduled work -> Show completed -> completed **Setup
   Steeples & Crosses**, Oct 5 / Crew 4. Open its material panel.
3. Inspect C177 Displays 853/860/861 and C178 Displays 834/840/848. Current must
   reflect each effective state/event from the cloned data. GPS-only observations
   must show the nearest known waypoint/distance; expand GPS to see raw recorded
   coordinates and accuracy. Verify keyboard and touch disclosure operation. Against the recorded steeple evidence and current reference
   set, C177 is about 46 ft and C178 about 76 ft from 15-Church-Bells-CH;
   `Z-BLDG-B-EAST` appears only after the Home label
   unless a real RETURNED/named observation explicitly establishes it as current.
4. Check one attached and one detached Display against API evidence. Detached
   Displays retain their own unload/movement event rather than later Container evidence.
5. Check named current Stage, support Container and an asset with no observation.
   No observation says Current location not recorded; Home is reference-only.
6. Print Task preview must preserve Current/Home separation and expand GPS details. Check phone/portrait
   width for readable wrapping and usable Report Work controls.
7. Do not report new real work for this read fix. Record actual review observations
   and any missing representative case; do not substitute fixture tests for operator PASS.

After acceptance, retrieve/read the governing source-only deployment runbook and
prepare the reviewed exact-candidate install. Production authorization is a separate
step. Never rerun the old #175/#132 migration-bearing installer for this fix.

## Pinned source-only deployment — prepared 2026-10-07

Greg explicitly requires merging PR #305 back to main before deployment. Use a
normal merge commit so the exact accepted application candidate remains an ancestor
of main. Documentation/deployment-tooling commits do not change the accepted application.

Read-only live baseline supplied by Greg on Oct 7:

```text
/opt/msb-setup = 0caed843bb37e7f1f1400972d8f6eb0b03f202d4
health = postgres / ok / V0.3.40-live-pick-demand
/opt/fieldwiring = 6dd05c4aa5ef8f50fe172145c3ae281cc245a101
```

Pinned target: `cb0538022ed066ff90675e832daa1cd95488114a`, V0.3.42-current-location.
Authority: Server Management `docs/server/Setup_Source_Only_Application_Deployment_Runbook.md`.
New wrapper `run_setup_305_source_only_deploy.ps1` and server runner
`setup_305_source_only_deploy.py` may run only from a clean main checkout that contains
this accepted target. The server independently fetches main and proves target ancestry,
old-to-target forward ancestry and no Setup/Database source changes.

The runner stops if preview port 8898 still listens, live/shared source drifts, a checkout
is dirty or the exact server/client build differs. It runs exact-candidate regression as
fieldwiring, checks the committed footer date, fingerprints Setup data including movement
history and Container/Display state in READ ONLY transactions, advances only /opt/msb-setup,
restarts only msb-setup.service, verifies health and focused regression, and checks data
preservation before operator writes. Rollback restores only the old source/service.
Temporary regression worktree cleanup is mandatory; failure returns STOP, not PASS.
No migration, environment/proxy/service-unit change or shared-checkout promotion.

Ten new mocked installer-boundary tests pass, covering success, live/preflight drift,
failed-health rollback, unmerged target, active preview, read-only movement coverage,
signal handling and cleanup-failure propagation. Prior 705 application/31 tooling checks
remain valid for the unchanged accepted source; the revised acceptance-tooling suite has
41 tests. PowerShell is not installed in this engineering container; the wrapper follows
the established foreground SSH/line-ending-safe transfer pattern.

Before running: finish the preview with ENTER and retain CLEAN EXIT; pause Setup edits for
the short install window. Production execution is performed by Greg from local PowerShell,
not by this assistant through private SSH. No installation is claimed by preparing tooling.
After PR #305 is merged, run from the laptop primary checkout (desktop path is separately
recorded in Repository Change Workflow):

```powershell
& {
    $ErrorActionPreference = 'Stop'
    Set-Location 'C:\lor\ImportExport\VSCode'
    function Invoke-Git175 {
        & git @args
        if ($LASTEXITCODE -ne 0) { throw "STOP: Git failed: $args" }
    }
    if (Invoke-Git175 status --porcelain) { throw 'STOP: uncommitted changes.' }
    Invoke-Git175 worktree list
    Invoke-Git175 fetch origin
    Invoke-Git175 switch main
    Invoke-Git175 pull --ff-only origin main
    Invoke-Git175 merge-base --is-ancestor cb0538022ed066ff90675e832daa1cd95488114a HEAD
    .\Setup\Acceptance\run_setup_305_source_only_deploy.ps1
    if ($LASTEXITCODE -ne 0) { throw 'STOP: deployment failed; retain report; do not rerun.' }
}
```

Then refresh the real protected `https://my.sheboyganlights.org/setup/` route and verify
Client/server V0.3.42, Updated 2026-10-06, Current/Home separation, compact waypoint/GPS
behavior for real movement evidence, and the already accepted Pick behavior. No fake
Production movements or tasks for this read fix. Retain report path, exact deployed SHA,
health/fingerprint result and protected-route operator disposition. Add the actual install
to Production Deployment Change Log and reconcile Server Management runtime docs only
after execution evidence. Close #175/DBG-2026-001 only after accepted installation;
#88 unload-checkbox feedback remains separate active work.

## 2026-10-07 failed install and tooling recovery

PR #305 merged into main at `5cbd4cfe156b62c484fe128b43b8119938c6fbef`.
Greg ran the merged installer from his local laptop PowerShell checkout. Retained report:
`/home/msbadmin/setup-deployment-reports/PR305-20261007T103430Z/report.txt`.
The target briefly reached live Setup, then focused regression returned
**8 failed, 198 passed, 1 skipped**. All eight failures were the location test's
SQLite fixture encountering `no such table: ref.lor_scene` after another test
imported the Production host and globally installed repository method replacements.
This is a test-process isolation failure, not evidence of a missing PostgreSQL table.
Full application regression did not expose this particular grouping/import order.

The documented rollback returned live Setup to
`0caed843bb37e7f1f1400972d8f6eb0b03f202d4`, restarted only Setup and verified
postgres/ok/**V0.3.40-live-pick-demand**. Rollback fingerprint
`07f14ba04cee4f17a2611c7b34c33b1e` matched the original; the report records
`SOURCE ROLLBACK PASS; database not mutated`. Candidate worktree
`/tmp/PR305-20261007T103430Z` removal completed without a cleanup failure.
Greg's subsequent read-only SHA/health check independently confirms the restored baseline.
V0.3.42 is **not installed or accepted in Production**.

Recovery changes only the installer and its documentation/boundary tests. The accepted
application target remains `cb0538022ed066ff90675e832daa1cd95488114a`; no application,
Database, reference data or validation SQL changed. The location test file now runs
in its own fresh Python process. Its installed-host/API cases continue to use their
existing child processes. All other approved focused tests remain in the other group;
none are removed, marked skipped or weakened. Both exact groups also run against the
candidate before any live checkout, so a focused failure stops before service mutation.
The same groups repeat on live source after restart under the existing runbook.

Engineering verification reproduced the grouped failure (nine failures with Node
available; the server skipped that additional renderer test). Corrected focused
groups: **185 passed + 22 passed**. Full application suite: **705 passed**.
Acceptance tooling: **43 passed**, including new isolation/order and focused-preflight
failure tests. These are engineering results, not a claim of another server deployment.
The governing source-only runbook was retrieved and re-read after failure. A new
operator attempt must pull the merged recovery tooling first; retain the failed report.
No database repair or migration is needed. #175/DBG-2026-001 stay open until successful
installation and protected-route acceptance; #88 retains unload-checkbox follow-up.

## 2026-10-07 successful install and hide-Home presentation follow-up

Greg supplied `PASS: Setup V0.3.42 installed; protected browser check pending` and
report `/home/msbadmin/setup-deployment-reports/PR305-20261007T105751Z`.
The corrected #307 installer completed after its merge to main
`3ddda03221ae475ffec5399ea4955e9c1e728419`. Installed application remains exact
`cb0538022ed066ff90675e832daa1cd95488114a`; only Setup source/service changed.
Installer PASS requires candidate/full/focused regression, exact live source,
postgres/ok/V0.3.42 health, unchanged shared checkout and governed fingerprint,
and temporary-worktree cleanup. No migration. The successful fingerprint literal
has not been supplied; do not copy it from the earlier failed attempt.

Greg's next screenshot shows Church/Cross rows with correct compact nearest-waypoint
context and expandable GPS, but unwanted Home lines. He explicitly requests:
**do not show Home when GPS has data**. Protected-route closeout is therefore
CHANGES REQUIRED for this presentation refinement, not a claim that GPS projection failed.

New exact candidate `be082fd078f99faae182ffc983f7e8392f98c9eb` changes only the shared
location renderer, cache pin, visible Updated date and relevant contracts. Home markup
is omitted whenever the existing GPS formatter accepts both coordinates, including
zero coordinates, no nearest-reference match and named-location rows that also carry
GPS. Missing/invalid/out-of-range coordinates retain Home as a separately labeled
fallback. Raw GPS disclosure, quality warning and print expansion remain available.
No business data, movement/unload behavior, API, schema or reference set changes.

This presentation-only change retains synchronized **V0.3.42-current-location** under
the Release Identity and Versioning Rule. Visible footer advances to **Updated 2026-10-07**;
`setup_next_pass.js` cache pin advances to `2026-10-07.1`. Exact source SHA distinguishes
it from the installed October 6 presentation. Engineering regression **748 passed**
(705 application + 43 tooling); isolated location suite **22 passed**; Node syntax and
exact-candidate UI-date gate PASS. Remote application tree matches tested local tree
`bd93d8b9af6dea22fbcbf1136a4aee994a5da267`.

Current review handoff uses the later movement-status refinement described below
and supersedes the earlier cb053802/old-branch commands above.
Run in local laptop VS Code Windows PowerShell. The browser launcher runs full
candidate regression, applies the existing read-only validation to its current-Production
disposable clone and checks health before readiness. Reuse registered **8898**; no migration.

```powershell
& {
    $ErrorActionPreference = 'Stop'
    Set-Location 'C:\lor\ImportExport\VSCode'
    function Invoke-Git175 {
        & git @args
        if ($LASTEXITCODE -ne 0) { throw "STOP: Git failed: $args" }
    }
    if (Invoke-Git175 status --porcelain) { throw 'STOP: uncommitted changes.' }
    Invoke-Git175 worktree list
    Invoke-Git175 fetch origin
    $Branch175 = 'fix/175-hide-home-with-gps'
    if (Invoke-Git175 branch --list $Branch175) {
        Invoke-Git175 switch $Branch175
        Invoke-Git175 pull --ff-only origin $Branch175
    } else {
        Invoke-Git175 switch --create $Branch175 --track "origin/$Branch175"
    }
    .\Setup\Acceptance\run_setup_disposable_browser_preview.ps1 `
        -CandidateSha '6e4cc77eed51559554a528ab1c8ab1ec7e04ba92' `
        -TargetRef $Branch175 -PreviewPort 8898 `
        -ExpectedVersion 'V0.3.42-current-location' `
        -MigrationPaths @() `
        -ValidationPaths @('Setup/Acceptance/setup_175_current_location_readonly_validation.sql') `
        -AllowConcurrentProductionWrites
    if ($LASTEXITCODE -ne 0) { throw 'STOP: preview failed; retain the report.' }
}
```

Open `http://127.0.0.1:8898/` only after BROWSER REVIEW READY. Verify GPS rows have no
Home line, non-GPS rows retain Home, disclosure/print remain usable and footer is
October 7. Finish with ENTER/CLEAN EXIT. This candidate is not merged or deployed yet.
After operator acceptance, merge to main before preparing a new source-only installer
pinned from currently installed cb053802 to the new candidate. **Do not rerun the
completed #305 installer:** it targets the prior application and prior V0.3.40 baseline.
Keep #175/DBG-2026-001 open; #88 owns the unload-checkbox follow-up.

## 2026-10-07 Elf Choir missing-location wording refinement

During the new preview Greg reports Church is fine, but Elf Choir Displays in
Container 15 and Support Container 60 repeat `Current: Location recorded — unnamed`.
He cannot determine whether they were picked or where they are. The Scaffold in
Container 122 already has GPS context near 08-Elf Choir-EC (44 ft).

Existing API rows already include effective `current_movement_status`; the renderer
discarded that distinction whenever location kind was UNRESOLVED_FIELD. That kind
means there is movement/state evidence without usable named/GPS location; it does
not prove a named location was captured, a Pick occurred, or Home is the current place.
The actual statuses/history of Containers 15/60 have not yet been supplied.

Latest exact candidate `6e4cc77eed51559554a528ab1c8ab1ec7e04ba92` replaces the vague
wording with the recorded movement label, such as `Picked — current location not recorded`,
`In transit — current location not recorded`, `Unloaded — current location not recorded`
or `Moved — current location not recorded`. A missing/unrecognized status falls back
to `Movement recorded — current location not recorded`, never Not Picked. Named/GPS
rows, including Church, remain unchanged. The renderer still hides Home on GPS rows
and retains it as a separately labeled reference when GPS is absent.

This adds no API/history query or movement/schema/data change. Presentation-only
V0.3.42 and Updated 2026-10-07 remain; JS cache pin advances to 2026-10-07.2.
The candidate supersedes be082fd for the next browser review. Engineering verification:
**748 passed** (705 application + 43 tooling), isolated location **22 passed**, Node
syntax and exact UI-date gate PASS; tested remote/local application tree
`812a77015b4a138fe53b671be3836289d936a94f`. Assertions cover every governed movement
status, unknown values, Home fallback and the grouped overlay without weakening GPS cases.

Read-only diagnostic [setup_175_current_location_status_probe.sql](setup_175_current_location_status_probe.sql)
inspects Container 15/60/122 state and whether each has a recorded Pick in the 2026
session, plus effective Display state/event for the Elf Choir rows. Detached Displays
use their own event; attached Displays inherit the Container. The recorded Pick source
is shown from its event, separately from current Home. Run the complete script in DBeaver
and retain both result sets. No data repair, inference or SQL mutation is authorized by
this diagnostic. A false Pick-history flag means no Pick record in this session,
not proof that an unrecorded physical Pick did not occur.

Finish the existing preview with ENTER/CLEAN EXIT, pull the updated branch, then use
the updated current handoff above for exact 6e4cc77. The new candidate is not deployed;
current live remains cb053802. Keep PR #308 draft and #175/DBG-2026-001 open until
the ambiguity is resolved, exact-candidate browser acceptance and subsequent main
integration/new pinned deployment are complete. #88 still owns unload-workflow changes.

## Local worktree disposition

Use the workstation primary checkout identified by the latest terminal prompt
(desktop `C:\Users\Greg\Github\MSB-Production-Database-Project`; laptop
`C:\lor\ImportExport\VSCode`). Inspect `git worktree list` before changing branches.
Keep the candidate worktree while acceptance is pending. After merged closeout,
prove it is clean and its HEAD is an ancestor of refreshed `origin/main`, then
`git worktree remove <this-task-worktree>` and `git branch -d fix/175-current-location-evidence`
from the primary checkout. Stop after every failed native Git command; never force
removal or remove unrelated worktrees. Return to the existing primary `main` worktree
and `git pull --ff-only origin main`. Preview CLEAN EXIT is separate from Git cleanup.
