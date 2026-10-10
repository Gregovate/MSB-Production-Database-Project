# #171 Operational Park Map Candidate

Status: ENGINEERING CANDIDATE — current-clone/operator acceptance pending.

Baseline main: `38f6f9427007470cbc02b3e2d23a97450d4414ba` (PR #327).
Version: `V0.3.53-gis-network-search`; visible Updated 2026-10-09.
Exact application SHA: the implementation commit identified on PR #318; pin
that SHA rather than resolving a moving branch at launch.
No migrations or new Production grants are proposed.

## Engineering proof

- Current network candidate full Setup Application regression: 741 passed.
- Source reconciliation conflict/legacy checks and multi-feature selection tests pass.
- Actual network JavaScript fixture passed: AUX-I/INET each resolve five GPX
  features, unmapped networks remain discoverable, details open and source failure
  preserves base search. Inline map/script syntax and unchanged source geometry
  checks pass. Browser/current-production clone acceptance remains pending.
- Four focused adapter/API tests cover invalid/storage coordinates, no
  prior-event fallback, recorded contents classification, independent Display semantics, reader
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

Icons now show recorded association state: all active assigned Displays
WITH_CONTAINER is Loaded; a WITH_CONTAINER/DETACHED mix is Partial; all DETACHED
is Empty. Missing assignments or unsupported modes is Unknown. Physical contents
inspection remains unconfirmed, explicitly separate in the popup and API.
Missing Display state defaults to WITH_CONTAINER in the owning projection; this
classification describes those records rather than verifying actual contents.
Display artwork sits above Container artwork at the same recorded coordinates.
Greg's Dancing Forest example (16 DETACHED Displays, event 113) must show Empty
with the T-Post above it; C001's all-WITH_CONTAINER list must show Loaded.

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
recorded contents and physical-inspection wording, contents-review flags and no duplicate WITH_CONTAINER pins.
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

## Closer zoom — operator request October 8

Extended map and aerial layer maximum zoom to 24 while retaining tile native
maximum 21. Leaflet enlarges the existing aerial tiles at zoom 22–24 rather than
requesting nonexistent higher-resolution tiles. This provides 8× greater linear
magnification than the former maximum, without claiming improved imagery or GPS
accuracy. Recorded coordinates remain unchanged. Review close Container selection
and map navigation on the next exact-candidate preview.

## Map-wide search — operator-required first implementation

Search includes all named reference waypoints and tracks, Container names and
C-numbers/numeric IDs, and Display names. WITH_CONTAINER Displays resolve to
the Container marker without introducing duplicate pins. Reference search works
while asset data is loading or unavailable. Refresh removes previous asset
search entries along with the markers. Missing positions say Location not
recorded. Selecting a result enables its layer and checkbox, fits the complete
track (all segments) or point, and opens details; typing does not change layers.
Stage popups omit source timestamps. Review Aux-I with NET disabled, C001, an
attached Display name, an independent Display and an unlocated asset.

Unobserved Containers (no movement state/event) and their attached Displays
show Workshop as the operator-defined expected location before picking. No
Workshop coordinates are fabricated: the permanent Workshop waypoint has
not yet been added to the source system. Search selection uses the temporary operator-provided Workshop reference.

Temporary Workshop reference supplied October 8: first screenshot point, EPSG:8158
X 213626.715, Y 186613.225 USft. Transformed with pyproj to WGS84 longitude
-87.73315025812246, latitude 43.778472269285245. The second screenshot point
is 6.815 ft away. Source coordinates and temporary provenance are preserved
in the feature properties. This is expected storage context, not observed asset
GPS. Replace with the maintained source waypoint when available.

Selecting a reference track highlights every segment in bright magenta at 7px
width and brings it forward. Selecting another result restores prior styles;
refresh also clears highlighting. Verify the long segmented Aux-I route stays
identifiable across the view without altering source geometry.


## Network grouping review — October 9

Use the exact candidate recorded on PR #318, existing branch
`docs/171-symbol-type-mapping`, reusable disposable browser wrapper on port 8898,
ExpectedVersion `V0.3.53-gis-network-search`. No candidate migrations or grants.
The prior preview CLEAN EXIT is recorded on PR #318; new browser review is pending.

- Search `Aux I` or `AUX-I`, choose **AUX-I · Network (draw.io)**.
  All five endpoint-matched Whoville GPX routes must turn magenta together;
  their individual rendered segments must remain intact. Missing routes stay explicit.
- Open cable details and use Show cable route to narrow selection. Switching
  selection restores the previous route styles. Typing alone does not alter layers.
- Search `INET`: choose the network group, not an individual historical GPX track.
  Five matching routes are expected. Source descriptions do not control membership.
- Search `AuxB`: network evidence remains searchable even without mapped routes.
  No fabricated connecting line or expected reference position may appear.
- Inspect `WV-00 to WV-03 Aux I` in AUX-I details: endpoint conflict, no map match.
- Recheck C001, Display-name search, original waypoint selection, and asset refresh.
- Record exact SHA, browser verdict and wrapper CLEAN EXIT/report after review.

Source inventory and unresolved work:
[GIS reconciliation authority](../../Docs/02_Production_Database/01_System_Architecture/11_Site_Infrastructure_GIS/engineering/Network_Source_Reconciliation_2026-10-09.md).
This slice does not deliver the editable Wiring database integration or import the
latest corrected tester export. No Production mutation/deployment is claimed.


## Current-main reconciliation — October 9, 22:55 CDT

Reconciled the network candidate with main `38f6f9427007470cbc02b3e2d23a97450d4414ba`.
Preserved accepted PR #324/#325 scheduling behavior, source assets/cache pins,
Production closeout documentation and existing acceptance tooling. The sole merge
conflict was obsolete scheduling asset pins in the navigation contract; the new
accepted pins prevail. Reconciled build is V0.3.53-gis-network-search with matching
client/server identity. Previous V0.3.52 testing does not substitute for new review.
No additional migrations are required by this read-only map slice; the inherited
migration 072 file is not authorization to apply it or any other migration.

Greg's laptop primary `C:\lor\ImportExport\VSCode` has divergent local main
(ahead 5, behind 134, local `11fed289`). Do not reset or switch that worktree.
Use existing `C:\lor\ImportExport\VSCode-171-map-review`, branch
`docs/171-symbol-type-mapping`, observed clean SHA `a523b508`. Update this feature
worktree by fetch plus fast-forward-only merge, then launch exact candidate on
8898. Other contents-review and office scheduling worktrees are out of scope.
Preserve the map worktree pending acceptance/integration; server preview CLEAN EXIT
is separate from Git cleanup. Primary-main repair remains a separate deliberate
history reconciliation, not a prerequisite for testing the feature worktree.

Reconciled candidate checks: 741 Setup/Application tests and five UI-date gate tests
passed; network/search JavaScript syntax passed. No new browser PASS is claimed.
