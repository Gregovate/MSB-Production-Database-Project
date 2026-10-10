# #171 Operational Park Map Candidate

Status: ENGINEERING CANDIDATE — current-clone/operator acceptance pending.

Baseline main: `38f6f9427007470cbc02b3e2d23a97450d4414ba` (PR #327).
Version: `V0.3.56-network-picker`; visible Updated 2026-10-10.
Exact application SHA: the implementation commit identified on PR #318; pin
that SHA rather than resolving a moving branch at launch.
No migrations or new Production grants are proposed.

## Current V0.3.56 network checklist acceptance

Greg reviewed V0.3.55 on October 10: network links work and expose segments that
may lack test evidence. CLEAN EXIT confirmed. This is targeted positive feedback,
not completion of all #171 acceptance or Production authorization.

Expand **NET — networks** using its disclosure arrow. Every network in the
LinkIQ source has a checkbox, including networks with no matched routes. Select
one or several to highlight their combined candidate routes. Counts retain
unmatched test evidence. Shared tracks remain highlighted while any selected
network uses them. **Clear highlights** restores source styles. Turning the
parent NET checkbox off clears network highlights, including those on shared
HV tracks, without disabling other geographic layers. Search remains available
and synchronizes the checks; selecting another feature clears stale checks.
Collapsing the list does not change the selected networks.

No source data, geometry, matching rules or database changes in this revision.
Map header date corrected to October 10. Existing Container/Display behavior
and the V0.3.55 limitations below remain applicable.

Validation: full Setup Application regression 744 passed; five UI-date tests
passed. Actual shipped-script Node fixture covers combined selection, removing
one network from shared geometry, zero-route evidence, search synchronization,
clear and parent-off behavior across NET/HV/PRI/Other layers. Disposable browser
review of V0.3.56 is pending.

## Current V0.3.55 acceptance (supersedes historical V51–V54 network checks below)

- LinkIQ raw SQLite is now the endpoint/network/test source. The corrected
  roundtrip FLW is read-only: 470 records = 445 parsed test records + 18 names
  requiring review + 7 source-deleted records. UUIDs identify tests, not cables.
- All geographic track classes are screened, including shared HV geometry.
  59 whole-source-track candidates; 122 tracks remain unresolved. AUX-I has 13
  candidates, INET 30. These are review correspondences, not verified routing.
- WV-00 → WV-03 AUX-I now finds t4/t131 using LinkIQ, while the draw.io WV-04
  endpoint disagreement remains visible. Shared geometry is not automatically
  classified as an alternative/historical cable. Source geometry is unchanged.
- Network details show raw tester length, test metadata, note/Faceplate/Outlet,
  endpoint navigation, schematic comparisons, GPX whole-track length and original
  installation descriptions. Whole-track length may span several cables.
- All 84 structured schematic infrastructure objects are searchable. Devices
  navigate only to uniquely matched GPX waypoint IDs; diagram coordinates never
  become GPS. Unlocated objects retain attributes and schematic connections.
- Search **LOR** for expected network/UID/universe inventory from the supplied
  October 9 SQL dump (latest PASSED snapshot run 71), separately from 178 recorded
  Controller Inventory identities/programming. This is dated snapshot evidence,
  not a live query or proof of physical attachment.
- Containers/Displays continue using the live read-only movement snapshot.
  `/locate/?container_id=199` focuses a located C199, or reports its unavailable
  position. Missing IDs report absence. Existing #175 links can consume this.
- Search **LinkIQ reconciliation review** for deleted/unparsed tester records and
  schematic conflicts. All raw source files remain unmodified.

Validation: 744 Setup Application tests plus three new LinkIQ/LOR importer tests pass;
actual shipped JavaScript runs against the generated data in the Node harness.
Operator/browser acceptance on the current disposable clone is still required.
No Production changes, migrations or writeback. #230 reference editor/import
persistence and #175 printed task map inset are still unfinished; this candidate
makes the operational map and evidence navigable now. #319 should reuse the new
`Database/EngineeringTools/reconcile_linkiq_map.py` adapter for its import work.

Operator checks: search AUX-I and INET; inspect WV-00 → WV-03; inspect **LOR**,
**LinkIQ reconciliation review**, and a **SW-INET** device; open a real Container
link and verify recorded contents/independent Displays. Confirm source track
installation descriptions remain visible. Exit the wrapper and require CLEAN
EXIT before starting another disposable session on port 8898.

## Engineering proof

- Current network candidate full Setup Application regression: 744 passed.
- Source reconciliation conflict/legacy checks and multi-feature selection tests pass.
- Actual network JavaScript fixture passed: AUX-I/INET route selection and original GPX
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
  -ExpectedVersion 'V0.3.56-network-picker' `
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
ExpectedVersion `V0.3.54-gis-network-routes`. No candidate migrations or grants.
The prior preview CLEAN EXIT is recorded on PR #318; new browser review is pending.

- Search `Aux I` or `AUX-I`, choose **AUX-I · Network (draw.io)**.
  Exactly one network result must appear, with 13 candidate routes selected together;
  their individual rendered segments must remain intact. Missing routes stay explicit.
- Open cable details and use Show cable route to narrow selection. Switching
  selection restores the previous route styles. Typing alone does not alter layers.
- Search `INET`: choose the network group, not an individual historical GPX track.
  Exactly one result and 19 candidate routes are expected; Cabinets must not appear.
  Dashed magenta highlights denote alternative historical source routes.
- Search `AUX-1`: network evidence remains searchable even without mapped routes.
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


## Operator findings and correction — October 9, 23:05 CDT

Greg's V0.3.53 screenshots report missing AUX-I sections, two apparent AUX-I
network results and more extensive INET gaps. The first screenshot actually
selected a raw GPX track while old AUX-I group details remained visible. The
second also showed INET matching Flammables Cabinets. Disposition: CHANGES REQUIRED.
CLEAN EXIT for that preview has not yet been supplied.

V0.3.54 corrects search semantics, clears stale details, and expands source matching
using named geographic anchors plus an explicit draw.io cable chain. All route
assignments remain review candidates; no source geometry, source draw.io or
Production records are changed. AUX-I's WV-00/WV-03 endpoint conflict remains
visible, and INET still has 15 unmapped records. Do not claim complete topology.

Before the new preview, finish the running V0.3.53 wrapper and require CLEAN EXIT.
Then fast-forward the existing laptop map worktree and launch the newly pinned SHA
with ExpectedVersion V0.3.54-gis-network-routes on the existing 8898 allocation.

V0.3.54 engineering evidence: 744 Application tests and five UI-date tests passed;
actual search/network script fixture passes exact-name isolation, 13/19 complete
candidate selections, dashed alternatives, original-style restoration, stale-detail
cleanup and source failure. Geometry tests reject missing/conflicting cable links,
off-route intermediates and unsupported multi-segment features. Original GPX
feature geometry/properties compare identical to the preceding candidate.
Screenshots inspected from operator attachments: image(20261010-040226).png and
image(20261010-040512).png. Full screenshot imagery stays in the supplied evidence;
this record preserves the diagnosed behavior and correction, not a new acceptance.
