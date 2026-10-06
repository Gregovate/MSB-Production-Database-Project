# #175 Current Location launch stabilization candidate

| Document control | Value |
|---|---|
| Status | LOCAL REGRESSION PASS — disposable/browser acceptance pending |
| Reviewed | 2026-10-06 |
| Owner | #175, commanding #122 / DBG-2026-001; #88 movement dependency |
| Baseline main | `8ea3d42224c25e9fdf2d01edd8bee3b9cc5693b6` |
| Branch | `fix/175-current-location-evidence` |
| Release | `V0.3.40-current-location` |
| Application candidate SHA | `c54019d671497d30d5d8992f212afd0bd816108e` |
| Database migrations | None |

## Bounded correction

`field_context()` reads effective movement status/event, observed time, coordinates,
accuracy, fix age, quality and capture method. Attached Displays follow Container
evidence; detached Displays retain their own event pointer, including Container
unload events. No new observations, reference-data cleanup, or schema changes.

The material panel, its task-cover-sheet copy, and the older overlay share truthful
Current/Home presentation. Named evidence is preserved; GPS-only evidence shows
`Current: GPS observation · ±10 ft` for 3 m accuracy. GPS does not establish a
park boundary. Unnamed movement and no observation have explicit text. Home storage
is a separate reference line. Grouped legacy Displays retain individual locations.

No appropriate healthy open implementation PR owns this bounded defect. #266 is
stale and unrelated offline rehearsal; #230 reference cleanup is outside this fix.

## Verification and limitations

- Linux engineering verification: full `Setup/Application` regression **691 passed**; `Setup/Acceptance` **31 passed**; combined **722 passed**. On Windows, run `Setup/Application` only; the acceptance-tooling suite includes Linux-only installer imports (`fcntl`).
- 13 new tests execute the actual projection SELECTs using SQLite with only text casts
  and placeholders translated, classify evidence, exercise Flask Decimal/timestamp
  transport, and execute the actual JS helpers/legacy grouping under Node.
- Checks cover GPS-only Container, attached/no-override Display inheritance,
  detached unload evidence after Container movement, missing detached evidence,
  season isolation, named Stage/Scene scope, unresolved movement, quality/accuracy,
  explicit RETURNED note, no-observation Home separation, and escaped output.
- SQLite is a local semantic fixture, not PostgreSQL/current-Production acceptance.
- Changed JavaScript syntax and whitespace checks pass. Exact committed footer gate: PASS, Updated 2026-10-06; server/client identity both V0.3.40-current-location.
- Browser execution was not possible here: no installed Chromium; Playwright's
  browser download returned a truncated/invalid archive.
- This workspace has no established MSB private SSH/server access. No current
  Production clone or real steeple browser check was performed here.
- Production is untouched. #175 and DBG-2026-001 remain open pending acceptance/deployment.

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
    $Candidate = 'c54019d671497d30d5d8992f212afd0bd816108e'
    $TargetRef = 'fix/175-current-location-evidence'
    $Validation = @('Setup/Acceptance/setup_175_current_location_readonly_validation.sql')

    python -m pytest -q -p no:cacheprovider Setup/Application
    if ($LASTEXITCODE -ne 0) { throw 'STOP: local application regression failed.' }

    .\Setup\Acceptance\run_setup_disposable_acceptance.ps1 `
      -CandidateSha $Candidate -TargetRef $TargetRef `
      -MigrationPaths @() -ValidationPaths $Validation `
      -AllowConcurrentProductionWrites
    if ($LASTEXITCODE -ne 0) { throw 'STOP: disposable acceptance failed; inspect retained report.' }

    # Reuse the preferred Setup review port 8806; the runner must prove it is unused;
    # STOP on an occupied/unknown listener instead of replacing it.
    .\Setup\Acceptance\run_setup_disposable_browser_preview.ps1 `
      -CandidateSha $Candidate -TargetRef $TargetRef -PreviewPort 8806 `
      -ExpectedVersion 'V0.3.40-current-location' `
      -MigrationPaths @() -ValidationPaths $Validation `
      -AllowConcurrentProductionWrites
    if ($LASTEXITCODE -ne 0) { throw 'STOP: browser preview failed; inspect retained report.' }
}
```

Use the consistent Setup review URL `http://127.0.0.1:8806/`; reuse this port
for sequential reviews under [the acceptance port convention](README.md#stable-setup-review-url).
A new candidate does not need a new port. Keep the current review on 8806 through clean exit.

Do not open the URL until **BROWSER REVIEW READY**. Finish with ENTER and retain
CLEAN EXIT, exact SHA/version, before/after evidence and report locations.

## Exact browser checklist

1. Verify disposable banner, Client/server V0.3.40 identity and Updated 2026-10-06.
2. Perform Work -> All scheduled work -> Show completed -> completed **Setup
   Steeples & Crosses**, Oct 5 / Crew 4. Open its material panel.
3. Inspect C177 Displays 853/860/861 and C178 Displays 834/840/848. Current must
   reflect each effective state/event from the cloned data. GPS-only observations
   must show GPS with available accuracy; `Z-BLDG-B-EAST` appears only as Home storage
   unless a real RETURNED/named observation explicitly establishes it as current.
4. Check one attached and one detached Display against API evidence. Detached
   Displays retain their own unload/movement event rather than later Container evidence.
5. Check named current Stage, support Container and an asset with no observation.
   No observation says Current location not recorded; Home is reference-only.
6. Print Task preview must preserve Current/Home separation. Check phone/portrait
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
