# #175 Current Location launch stabilization candidate

| Document control | Value |
|---|---|
| Status | CURRENT LOCATION OPERATOR PASS — cleanup/source-only deployment pending |
| Reviewed | 2026-10-06 |
| Owner | #175, commanding #122 / DBG-2026-001; #88 movement dependency |
| Baseline main | `5109fff5145122525c7ea9ae5d2bc0ff5d6b994a` |
| Branch | `fix/175-current-location-evidence` |
| Release | `V0.3.42-current-location` |
| Application candidate SHA | `cb0538022ed066ff90675e832daa1cd95488114a` |
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
set; proximity does not confirm placement at that waypoint. Unnamed movement and no observation have explicit text. Home storage
is a separately labeled inline reference. Grouped legacy Displays retain individual locations.

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
Before freezing the expected-old installer pin, retrieve current live Setup HEAD/health
and shared checkout HEAD using a read-only command from local PowerShell. The approved
application target remains `cb0538022ed066ff90675e832daa1cd95488114a`.
Installer preparation and separate Production authorization follow confirmed baseline
and cleanup. Do not reuse the historical migration-bearing #175/#132 installer.

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
