# #171 Operational Park Map Candidate

Status: ENGINEERING CANDIDATE — current-clone/operator acceptance pending.

Baseline main: `86a025a2528be9f7071355965f679320a1362181` (PR #317).
Version: `V0.3.51-gis-asset-overlay`; visible Updated 2026-10-08.
Exact application SHA: the implementation commit identified on PR #318; pin
that SHA rather than resolving a moving branch at launch.
No migrations or new Production grants are proposed.

## Engineering proof

- Full Setup Application regression: 722 passed.
- Four focused adapter/API tests cover invalid/storage coordinates, no
  prior-event fallback, Unknown load, independent Display semantics, reader
  authorization, no-store and GET-only operation, and static asset allowlist.
- JavaScript syntax and rendering fixture passed: exact-coordinate grouping,
  escaped asset/Display names, accuracy in feet, Unknown SVG and unlocated list.
- Supplied SVGs parse as XML with 32 × 32 viewBox and no external references.
- Local Chromium rendering could not run: browser executable absent and download
  returned invalid/truncated archives. No visual browser PASS is claimed.
- No private server connection, current-clone SQL proof, real Container-position
  inspection, operator acceptance, merge or Production deployment is claimed.

## Current data contract and deliberate limits

GET `/api/setup/locate/assets?season_year=2026` consumes the #88 read-only
movement snapshot; existing Setup read authorization is required. Containers
include all reference identities, including those without session observations.
Only active Displays are included in contents/independent features. Asset names,
current movement status, event metadata and recorded coordinates are exposed;
operator email/history notes are not exposed as popup content.

Every Container's physical `load_state` is UNKNOWN. Missing Display state
defaults to WITH_CONTAINER in the owning projection, so associations/counts do
not establish a verified load. Supplied Loaded/Partial/Empty artwork is retained
for later accepted #88 state; no unsupported classification is fabricated.

Each state row's referenced event supplies coordinates. A later coordinate-free
event produces an unlocated asset; the map does not recover old GPS itself.
RETURNED is storage/unlocated even if an old event has GPS. C095 continuity is a
required clone review case and an owning #88 discrepancy if projection is wrong.
Guided PR #309 / migration070 are not pulled into this map candidate.

Within each layer, exact-coordinate assets share a marker and popup. Nearby
distinct coordinates remain distinct. WITH_CONTAINER Displays stay in Container
popups. Reference map geometry, aerial, compatibility symbols and tracks remain
unchanged. T-Post.png is the verified existing Display asset.

## Disposable/browser handoff

Authority: MSB-Server-Management
`docs/server/Pre_Production_Browser_Review_Runbook.md`,
`docs/server/PostgreSQL_Disposable_Acceptance_Standard.md`, and
`docs/server/Application_and_Test_Port_Register.md`, read October 8.
Reuse Setup port 8898; never replace a healthy concurrent review or unknown
listener. Existing wrapper owns clone isolation, identity, readiness and cleanup.

Prepare a separate clean worktree from remote `docs/171-symbol-type-mapping`
(PR #318). Keep unrelated/unmerged #88 review worktrees. From that worktree use:

```powershell
$Candidate171 = git rev-parse HEAD
if ($LASTEXITCODE -ne 0) { throw 'STOP: cannot read candidate SHA' }
.\Setup\Acceptance\run_setup_disposable_browser_preview.ps1 `
  -PreviewPort 8898 `
  -CandidateSha $Candidate171 `
  -TargetRef 'docs/171-symbol-type-mapping' `
  -ExpectedVersion 'V0.3.51-gis-asset-overlay' `
  -AllowConcurrentProductionWrites
if ($LASTEXITCODE -ne 0) { throw 'STOP: retain report; inspect before retry' }
```

Before launch verify HEAD equals the reviewed application SHA recorded on PR
#318. No candidate migration/validation paths are required. Open
`http://127.0.0.1:8898/locate/` only after BROWSER REVIEW READY.

Review real clone positions for C095, C199, C216 and another independently
located Display when present. Compare each pin's raw coordinates, timestamp,
accuracy, provenance, names and referenced event with Container Movement.
Check missing observations and RETURNED storage stay unlocated; check Unknown
load wording, contents-review flags and no duplicate WITH_CONTAINER pins.
Toggle each asset layer independently; check aerial/GPX/HV/PRI/NET preserved,
colocated popup entries accessible, and narrow tablet layout usable.
Refresh assets and inspect errors/role denial without any movement writes.
Record clone fingerprint, exact SHA/version, report path, operator disposition
and CLEAN EXIT. Then separately review deployment approval under the governing
Production runbook; browser review is not deployment approval.

After CLEAN EXIT, remove only this clean disposable worktree after verifying
its branch/ownership and that committed history is retained remotely. Preserve
unrelated worktrees. Return the primary desktop or laptop checkout to main and
`git pull --ff-only origin main`, stopping on failure; never force reset/remove.

## First browser finding — October 8

Greg supplied a V0.3.51 screenshot with the reference map working, no Container
pins, blank asset status and an empty unlocated list. The URL bar was not shown.
A reproducible route defect was found: `/locate` without a trailing slash served
the page but resolved the overlay script as `/assets/setup_locate_assets.js`,
which returns 404. Corrected by a canonical 308 redirect to `/locate/`; a real
Flask HTML/script URL-resolution test covers this path. Initial status now
explicitly reports overlay initialization instead of an unexplained blank.
This explains the symptom when the slashless route is used; it is not proof
of Greg's exact browser URL or a successful data fetch. No CRS/coordinate change
was made. Updated exact-candidate review is required after CLEAN EXIT.
