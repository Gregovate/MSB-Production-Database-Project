# MSB GIS Manager — Windows Desktop Application Engineering Design

| Document control | Value |
| --- | --- |
| Status | DRAFT — October 19, 2026 recovery/design reconciliation; operator acceptance pending |
| Owner | Site Infrastructure / GIS; Issue #171 under #122 |
| Subject | Windows application behavior, distribution, workstation verification, field-recording intake and track review |
| Source baseline | Current main at `a770e755dc4ce59873a004b3d92368c4c4cf7eae`; parallel PR #378 and PR #319 candidates are not accepted Production releases |
| Related current authority | [GIS Symbol Management](GIS_Symbol_Management.md); [GIS engineering portal](README.md); [Network Source Reconciliation](Network_Source_Reconciliation_2026-10-09.md) |
| Backend contract | [#319 Site Source Synchronization Contract](https://github.com/Gregovate/MSB-Production-Database-Project/blob/feature/171-cableiq-import-validation/Database/EngineeringTools/Site_Source_Synchronization_Contract.md) — draft branch, not merged/current main |
| Implementation evidence | [PR #378](https://github.com/Gregovate/MSB-Production-Database-Project/pull/378) — desktop/ExpertGPS/Garmin candidate; [PR #319](https://github.com/Gregovate/MSB-Production-Database-Project/pull/319) — governed PostgreSQL/PostGIS backend candidate |

## Purpose, ownership, and immediate priority

This document is the **dedicated engineering design for the MSB GIS Manager Windows PC application**, not the desktop source code, an operator SOP, a PR description, or a separate GIS database design. The manager must serve an ordinary authorized engineering user without requiring VS Code, Git, Python, PowerShell, or direct database commands to perform routine app tasks.

The October 19 operator priorities are:

1. **Update incorrect current park-map tracks for ongoing 2026 repairs now.** Distinguish historical installed/design geometry from repair/current field-located geometry; recognize work already manually applied to the latest master; preserve source and history; do not create duplicate tracks.
2. **Finish the Show PC configuration safely.** It retains older ExpertGPS waypoint Types/symbol mappings and has not passed synchronized workstation acceptance. Do not open or save the authoritative GPX there until the installed MSB symbol library, mapping/profile and aerial registration are verified.
3. **Deliver a real self-contained Windows installer and update path.** The existing Git worktree/Python launcher and trial desktop shortcut are engineering-only.
4. Finish the full source-review, Garmin, FLW and guarded PostGIS interchange after the above urgent field-data lane is usable.

The current 2019 park aerial used by the operator must be reusable across Windows GIS workstations. **A common image file does not by itself prove identical ExpertGPS per-user scanned-map registration/calibration.** Inventory exact raster hashes, actual registered map names, CRS and control points on each PC before asserting parity; preserve the already verified Office working-map configuration. The operator's statement that the same 2019 aerial is used across PCs takes precedence over an unverified assumption that every machine needs an independently cropped image. Historical full/cropped map registrations remain evidence, not authorization to replace them.

## Boundaries: one source of engineering truth

- The Windows manager is an **engineering workstation and intake/review client**. It controls local app installation, authorized symbols, ExpertGPS workstation comparison, Garmin field recordings and exports, GPX source acquisition/diff/review, and LinkIQ evidence handoff. It must not become a second maintained GIS reference database.
- **#319** owns source hash/identity checks, immutable GPX/FLW ingestion receipts, governed PostGIS revisions, source-to-maintained reconciliation and safe export interfaces. Desktop app sends reviewed proposals through those existing contracts. No direct desktop SQL writes, duplicate importer or implicit Production migration.
- **#230** owns the authorized database-backed permanent reference editor: revised waypoints, managed physical cables/track associations, panel/circuit relationships, role-gated audit and conflict control. Setup Park Map and Field Wiring Map are distinct **read-only engineering-reference consumers** and must preserve #88 seasonal movement ownership.
- Official GPX original observations and source snapshots are immutable evidence; maintained PostgreSQL/PostGIS becomes the reviewed maintenance authority after accepted promotion. ExpertGPS ↔ PostGIS is conflict-aware two-way *review*, not last-writer-wins synchronization. LinkIQ/FLW is strictly one-way immutable intake; never write back to tester SQLite. Draw.io is schematic presentation, not surveyed geography.
- GIS reference data does not establish electrical isolation or a safe-to-dig decision merely from map overlap or absence of a line. Missing or stale surveyed coverage remains **unknown / locate review required**.

## Application interaction model

The normal screen should answer **what changed, what should I do, what is safe to apply, and what remains**. The expected pattern is **Check → Compare → Review → Offer correction → Backup → Apply → Verify**. No auto-apply upon launch, detecting a Garmin or reconnecting G:. A clear status differentiates **current, update available, conflict, review required, unavailable and not verified**. Show source revision/age, current app version/SHA, approved workstation-release version/digest, active Windows user/host, and unapplied review counts.

Normal operator-facing sections:

| Area | Required work |
| --- | --- |
| Home | Read-only checks; next safe action for outdated workstation profile, shared Symbol Library, Garmin recordings, source revisions and pending conflicts; prominent warning when GPX is unsafe to open |
| Symbol Management | Single reviewed Master → Plain → ExpertGPS PNG and Garmin-compatible BMP derivative workflow; previews, approval, backup, verified publication or local install as *separate consented destinations* |
| Workstation Management | Compare this PC to approved versioned GIS release; check local installed icons, ExpertGPS Type/Map Marker/GPS Symbol/reverse map, selected 2019 aerial raster and calibration; consented targeted repair/rollback |
| GIS Data Management | Recording work queue, source-provenance tracking, map-based individual track/segment review, baseline vs revised master, GPX changes, deferred exceptions and handoff to #319/#230 |
| Garmin GPS | Read-only device identity/status; incremental archived-recording import offer; separately consented symbols and waypoint transfer with compatibility checks; never silently clean device |
| LinkIQ / FLW | Read-only source/retest comparison, immutable originals and reviewed identity proposals; actual promotion through #319 only |
| Utilities / Advanced | Expert diagnostics, registry/manifest/path views, recovery receipts and support functions kept off the normal screens |

Avoid adding another row of engineering/Office-only buttons to the main operator view. Nontechnical operators should not navigate Python scripts or source-tree paths for routine use.

## Controlled G: Symbol Library and PC release contract

The accepted **physical** shared-folder migration on October 14 renamed the old `MSB GIS\Symbols` root to `MSB GIS\Symbol Library`, preserving **823/823 files** and matching the aggregate inventory digest `d437f9ed30b6c53605a5a5bbc9f35c8a1fae1596564250f995aa2262b7fc67d1`. This proves the folder rename, **not** that every runtime caller, installer and workstation has been upgraded.

Canonical shared source for the current configured G: environment:

- `G:\Shared drives\Display Folders\Park Drawings\MSB GIS\Symbol Library\Masters`: editable Inkscape design;
- `...\Symbol Library\Plain`: approved, pixel-sized SVG export;
- `...\Symbol Library\png`: canonical ExpertGPS PNG derivatives;
- `...\Symbol Library\bmp`: reviewed Garmin device-compatible derivatives, only after accepted device mapping;
- `...\Symbol Library\release-history`: immutable release manifests, backups, receipts and fingerprints.

Drive letter is **host-specific**. Resolve the approved shared-drive mount/controlled location through configuration and verify access; do not create a second old `Symbols` tree when G: is missing. Stop if both old and new roots exist unexpectedly; report migration conflict. Inventory old-root literal references across helper scripts, shortcuts, tests, SOPs and packaging. Support already-published public web `/symbols/msb` and `/symbols/msb-svg` URLs and the existing local ExpertGPS `%LOCALAPPDATA%\TopoGrafix\Symbols\msb` convention; these are **different consumers**, not targets for renaming along with the G: source.

The shared library holds approved **distribution/source assets**, not a magic substitute for the per-user ExpertGPS installation. On a target PC verify local PNG files and `readme.txt`, their hashes, Type → Bitmap Symbol URL and per-waypoint `type`/`sym`/marker-extension separation, the reverse `SymbolToType` mapping, and scanned-map raster/calibration. No whole-HKCU export/import as routine synchronization; preserve other personal ExpertGPS settings and historical aliases. Any mismatched current-user value must show before/after and its exact released provenance.

## Real Windows installer and updates — required acceptance

Current PR #378 `Launch-MSB-Icon-Library.cmd` resolves a repository-relative script and requires Python/Tk/Pillow/source modules. `Install-MSB-GIS-Review-Shortcut.cmd` creates a **test shortcut** to a Git worktree. Neither constitutes ordinary-user installation.

An accepted release must:

1. Package the GIS Manager GUI and its pinned Python/native dependencies into a properly versioned Windows installable application and ordinary Desktop/Start Menu entry. **End users must not install VS Code, Git, Python or run PowerShell.** Administrator diagnostics may exist in Advanced, not as normal workflow.
2. Use a normal per-user installation where feasible and document privilege needs for installation, shared-drive reads, public publishing, Garmin/USB access and protected database API actions. Do not embed Synology/admin tokens or grant web-publish rights merely because the app can run.
3. Ship an independently verified immutable release manifest, app/build version, package hash, signed/trusted publisher handling where supported, compatible Windows versions, update check, reviewed update/rollback, and retained prior working package. If shared drive/network is unavailable, report source unavailable without silently treating stale local symbols as current.
4. On first run and update, **read only** inventory the workstation first. An accepted configuration version/digest must be independently approved by the designated MSB GIS custodian, not inferred from the laptop's proposal hash.
5. Compare exact target host/current user with approved release and protect all original Type/reverse-map registry entries, local MSB symbols, map registrations and configuration through verified backup before any targeted repair. Require ExpertGPS closed, review/consent, recheck preflight, deterministic write, readback equivalence, failure rollback, and a discoverable recovery receipt.
6. Never open/save the official master GPX automatically. Run an isolated disposable GPX open/save/reopen comparison only after target symbols/type settings and aerial/calibration pass.
7. Pass clean **nondeveloper** Windows user installation/update/rollback, clean Show PC acceptance, and one additional authorized-user test before calling the app released. A CI fixture PASS or developer shortcut is insufficient.

## Show PC — current STOP and acceptance sequence

**Observed / operator reported:** Show PC ExpertGPS has old waypoint Type and symbol configuration. It has not passed the new #171 synchronized profile test. The operator currently cannot safely open the 2019 aerial/master GIS map there because the local MSB symbol library is not current. Do not call the Show PC synchronized, installed, or tested.

Safe order:

1. Confirm actual Windows account, ExpertGPS closed, current installer/app version, G: mount, shared `Symbol Library` resolution, installed local MSB icon inventory and source hashes; inspect registry Type, marker URL and `SymbolToType` mappings read-only.
2. Inventory **the selected 2019 raster image**, registration name, CRS, calibration/control points and image hash on Show/Office/laptop. Identify equivalence or difference before choosing a released map/calibration subset. Do not overwrite other registered aerials.
3. Select a separately approved immutable workstation configuration release using reviewed upstream source/provenance, with exact host-target plan. Show PC's current values are preserved, not silently treated as approved.
4. After reviewed backup and explicit operator consent, install local ExpertGPS symbols plus the authorized scoped profile/calibration corrections. Fail closed on missing/mismatched assets, bad value kinds, ambiguous Type/Garmin reverse mappings and incomplete shared release.
5. Verify local symbol hashes, Type/icon/symbol mappings and raster/calibration independently. Only then open an isolated **working copy** of GPX on Show PC; confirm waypoint/track count, Name/Label on Map, `type`, `sym`, marker URL, geometry and metadata survive save/reopen. No authoritative master Save.
6. Record the Show PC identity/version, accepted digest, source and target fingerprints, backup, post-install proof and operator result. Mark **PASS** only after actual human visual acceptance, not merely code tests.

This Show PC activity is independent of the urgent repair-track review on an already-verified engineering PC.

## Field recordings: no duplicate master tracks

**Current blocker:** 2026 field locates and repairs are ongoing; old master tracks include wrong/obsolete positions, and new Garmin recordings have already been manually imported, split, renamed and repaired in ExpertGPS. Some raw timestamp-only recordings were archived; not all resulting segments or approvals are known. A one-file → one-track model and name filtering are false assumptions.

### Recording work queue and stable identity

- On Garmin connection, **offer** incremental archive/import. Copy original recording bytes to immutable, hash-verified archive; identify by source SHA-256, original path/device timestamp and import receipt. Never rename or delete the original based only on an edited track label.
- Compare the **fresh current master GPX** to archived Garmin recordings and available prior master snapshots **before importing anything**. Record real current master hash and snapshot age; do not assume October 13/15 attachment hashes still describe today's bytes.
- Detect previously hand-processed or partially processed tracks by original point-range/geometry, source timing, proximity and notes/history, not merely human names. One recording may legitimately produce multiple independently named **FE, RA, CL, HV, NET or other** segments; show them grouped by original source recording.
- Queue only actionable or unresolved recordings by default. Support `Pending`, `Partially processed`, `Already in master — needs confirmation`, `Reviewed`, `Approved`, `Applied/verified`, `Deferred` and `Dismissed duplicate`, with individual segment states; maintain permanent Done/History with receipts. A partial recording stays in the active queue. No automatic deletion of archived originals.
- If evidence is ambiguous, show competing candidates and require human attribution; never auto-insert another copy on top of an existing track.

### Per-segment map review and correct geometry

Display only the selected raw recording / proposed segments on the approved park aerial; overlay authoritative maintained waypoints as **read-only reference** and show nearby labels/endpoints and candidate existing master tracks/notes. Do not merge waypoint records into raw source GPX. Provide before/after evidence and source timestamps; allow reviewed tail trimming, raw GNSS outlier suppression in a derivative, splits at intermediate boxes, points/geometry correction, endpoint association, and type selection `H` (high voltage/120 V), `N` (network), `P` (primary), `HN` (shared trench) as appropriate to the surveyed segment. Never interpret a shared trench as shared physical cable identity.

Preserve the original raw points, historical master/design track geometry, all existing comments/descriptions and installation/repair dates/evidence as separate retained versions. A new confirmed as-built/painted-locate observation can **supersede** an old incorrect route for current-map display only after identifying the affected physical cable/track and recording reviewed effective status/time; do not erase the design/installation record or silently copy historical notes to an unrelated cable. Keep the original and proposed new route inspectable side by side.

**Connectivity is not forced geometric snapping.** Cartographic track endpoints may intentionally stop just short of a panel/pole; logical endpoints belong in an audited relationship even if line vertices do not exactly touch waypoint coordinates. Cable topology, intermediate survey points, coincident parallel cables and tested endpoints are different identities.

**Known safety regression:** FE-01 → FE-07 home-run cable was **not located** when crew traced the wrong cable. Other nearby FE survey coverage does not mark that separate physical connection as located. Support `wrong cable traced`, `missed locate — revisit required` and unknown evidence linked to the actual physical cable identity; never promote a visually overlapping trace as clearance for it.

### Decision, promotion and round trip

A source recording may yield zero, one or many reviewed segments with stable lineage and explicit source point ranges. Distinguish original installation, design/historical, located current/as-built, repaired/rerouted, retired/superseded and uncertain evidence. Per-item or related-batch **approve/defer/reject** must not block unrelated independent decisions.

Preview the proposed effective/current park-map result and historic-source retention, then hand off **only approved** changes via #319's guarded source revision/identity reconciliation and #230's role-gated edits. Server/API enforces actor, permissions, previous revision guard, transaction, audit and rollback; desktop tool never writes the Production database directly. Export a new reviewed GPX derivative via the maintained conflict-aware contract and verify ExpertGPS save/reopen. Original Garmin GPX and prior master snapshots remain unchanged.

## October 19 corrected #428 scope — existing Windows GIS Manager imports and reconciles OLD tracks with NEW/updated tracks

**Greg's scope correction:** #428 is NOT completed by photographs, provisional map pins, or an independent lightweight paint-mark viewer. It is the **existing MSB GIS Manager PC application** designed for intake of old ExpertGPS/GPX and new Garmin recordings, historical/current master comparison, already-hand-processed detection, segmented track review, and deliberate decisions about exactly which old physical route/segment a newer surveyed or painted route supersedes. Paint visibility makes this urgent, but is NOT a substitute for the full import/reconciliation workflow. The existing desktop/source designs and backend are authoritative and must be reused.

### Actual one-person PC workflow — one physical cable/track at a time

1. **Find the old physical track and its history:** search current authoritative working master, prior master snapshots, older GPX/ExpertGPS names/geometry, original installation notes, archived Garmin observations and actual cable/waypoint/endpoints; show source date, identity, and what each geometry means (original, design, repair, effective). Do not equate an identical name or nearby line with a unique cable identity.
2. **Import NEW recordings without duplicating what Greg already corrected:** preserve unchanged raw Garmin/GPX files as immutable dated/hash-pinned evidence, compare to latest working master geometry, identify previously imported, renamed or partially split tracks and multiple derivatives from one raw recording. Show unresolved segment lineage rather than accepting one recording = one new physical track.
3. **Visual OLD versus NEW map overlay:** on the correctly calibrated common 2019 aerial, show historical route, current effective repaired route and new/as-painted route in separable layers with labeled waypoints, source timestamps, photographs/landmark measurements and device GPS accuracy when present. Explicitly distinguish map-drawn corrections from measured/field-verified positions; never treat phone GPS as surveyed accuracy.
4. **Choose an explicit update for each real segment:** replace/supersede precisely identified old segment; retain old and new as independent routes; accept partial repair; split/merge documented sections; mark already applied/no change; defer unknown; reject duplicate or wrong-cable attribution. Do not silently erase old line geometry, original GPX, comments, installation date or prior repair evidence. FE wrong-cable traces remain unlocated/unknown.
5. **Review proposed effective-map replacement and apply through existing mechanisms:** compare exact before/after identities, vertex/endpoint changes, original source hashes, physical cable ID and retained historical geometry; require human approval. Save work queue and decisions (Pending, Partially processed, Reviewed, Applied/verified, Deferred, Dismissed duplicate), preserve historic backups/revision and reject concurrent stale-source changes. Existing #319 PostGIS/source-sync owns accepted promotion/exports; existing #378 Windows GIS Manager owns client import/review. If a guarded source-only working-master/current map release is selected as the immediate lane, use existing #171 release and operator/browser gates, not a second GIS data store or unsanctioned writes.
6. **Field and workstation acceptance:** open output with the current approved ExpertGPS symbols/aerial calibration, compare new effective route with still-visible paint, and verify current map displays correct revised line while old retained track remains available as history. Never open protected master on unsynchronized Show PC; preserve other manually corrected latest-master tracks.

### Priorities, dependencies, and completion

**First milestone now:** locate exact latest working master and archived original/new tracks; use existing GIS Manager PC code to display one real old/new/split-track comparison and approve one proposed replacement while retaining original history. In parallel collect photographs/landmark offsets before paint fades. This is a bounded functional slice of the full PC app, not a competing photographic shortcut.

**#428 is not accepted** until it demonstrates at least one already-hand-split route without duplicate import, one correctly identified old-to-new segment replacement with preserved history, one genuine new separate track, one wrong-cable/unknown case, no-GPS observation support, and saved/reopenable approved output on the real 2019 aerial. Necessary #319 database/GPX promotion and #378 PC integration are separate established implementation boundaries; no Production mutation without #122 and Server Management acceptance.

**Interpretation of older subsection:** the field-first paint photograph/capture section below is only an urgent evidence-preservation subtask. It does not redefine #428 as a photo/map-pin workflow or permit replacing the existing full GIS Manager design.

## October 19 field-first priority — capture current ground paint before it disappears (#171)

**Focused urgent work item:** [#428 — capture visible 2026 paint marks on the existing map](https://github.com/Gregovate/MSB-Production-Database-Project/issues/428). This is the first operator-deliverable; it does not depend on #429–#432.

**Operator priority: now, while locate/paint marks are still visible.** This urgent field-evidence work is a **smaller deliverable than complete GIS Manager installation, PostGIS migration, full ExpertGPS synchronization, or historical cable cleanup**. Do not use those larger projects as prerequisites to *capturing* ground truth.

### Minimum field capture, without assuming smartphone GPS is surveyed truth

1. **Show the existing approved 2019 park aerial and named current reference waypoints/tracks** in the established Park Map / controlled GIS intake surface. Identify specific marked underground routes, stake/anchor boundaries, relocated junctions, power/network routes, Stage/context and any as-laid/repair changes. Keep source names and physical cable identities separate; don't create a duplicate map or infer a cable from a nearby paint color alone.
2. On a visible paint mark, record a **field observation** against a named current or proposed real waypoint/track segment: date/time, person, reference type and human label, what painted mark/segment signifies, provisional status, and source photo(s). Support 2+ photographs with nearby permanent landmarks, start/end or turn points, and measured offsets/distances from visible stable reference objects where available. User-confirmed points can be entered on the aerial with visible coordinates but are **approximate reviewed positions**, not synthetic GPS/survey points.
3. GPS may be absent, off by tens of feet, or unreliable near trees. Store original device fix and stated accuracy **as optional evidence only**, with explicit low-confidence/absent quality. Allow a field operator to place/correct a provisional map point/route **by visually matching the current aerial/paint and reviewing offset measurements**, retaining whether coordinates were GPS, map-drawn, or from actual measured offset. Do not silently snap to the nearest existing marker, invent underground clearance, or overwrite permanent surveyed geometry.
4. **Preserve what exists today** even if connected editing cannot be completed: allow locally retained source photo/named observation set or controlled notes/GPX copy, keyed to an immutable dated evidence batch for later reviewed import. Existing map offline/cache state must be verified, not assumed. If the protected app/map can't perform the field capture yet, the immediate fallback is saved date/time-stamped photographs, current approved aerial/Garmin/ExpertGPS on a **verified** workstation, hand measurements and named evidence, never risk changing the master on unsynchronized Show PC or pretending offline API writes succeeded.
5. Overlay **previous route and proposed corrected as-painted route** separately; reviewer explicitly approves/declines individual edits by source identity. Persist immutable raw GPX/photos and before/after evidence; only promote via **existing #319 maintained PostGIS/review workflow or the accepted controlled source-only map release** under #122/#171, never direct ad hoc SQL or a second GIS ledger. Mark unknown/unlocated cable segments clearly; no implied permission to drive stakes without an approved locate.
6. Produce a **reviewable map of today's captured paint marks/route corrections** with current source revision, known uncertainties, outstanding unverified marks and a clear done/pending count, usable by Greg while the paint is still on the ground. This is a distinct accomplishment from map icon polish, offline installer, or January Testing.

**Acceptance for this urgent work slice:** on a laptop/verified park-capable device, identify a real painted cable or Stage anchor, capture a named set of observations/photos + optional GPS + measured landmark offset, see a provisional route/point over the 2019 aerial, save/reopen it without loss or duplicate, compare against historical reference, and obtain a reviewed portable/source-only map result. Test 1) no GPS, 2) inaccurate GPS, 3) a track already modified in current master, 4) a known unlocated FE home-run, 5) map offline/read-only after cache prep, and 6) false source/profile mismatch. No automatic Production mutation from field capture.

**Owning priority:** #171 permanent GIS capture and presentation; #230 separately owns reviewed permanent reference editor, #319 PostGIS/source promotion and #378 desktop packaging. **#88 seasonal Container/Display scan locations, GPS event fixes, physical no-label exceptions, cargo-empty return and task Ready for Wiring are separate and are not dependencies on this paint-saving field-evidence lane.** The commanding #122 controls any Production release. No code, installer or field capture feature is asserted shipped by this design.

## Emergency lane: correct 2026 repair map without waiting for packaging

This is **not authorization to bypass Production gates**. The smallest useful engineering deliverable comes before the full desktop installer and sophisticated freehand editor:

1. On the already verified engineering workstation, take an immutable SHA-256 snapshot of the **fresh latest authoritative working master GPX**, the latest archived Garmin recordings and prior accepted master snapshot; collect unresolved repaired/moved route observations.
2. Run **read-only master-versus-recordings reconciliation**: list already-processed segments, confirmed/new modified segments, partial/overlap duplicates, changed historic names/descriptions and unlocated cables. Preserve manual ExpertGPS repairs made after prior snapshots.
3. Provide a single-recording, read-only park-map review with named waypoints, prior/current candidate tracks and historic notes. Human-approve a short set of immediate 2026 fixes; then deliver a reviewed working GPX/master correction **without replacing originals**.
4. Release corrections to the actual maintained reference map only using the established #319/#230 guarded review/promote path and current Server Management runbook/authorized migration, or a deliberately scoped **source-only existing Setup Park Map** release through its governing acceptance/runbook if the permanent editor is still unfinished. Label the displayed revision and do not misrepresent it as current PostGIS acceptance.
5. Confirm the corrected current map and source age in the real protected browser and, where applicable, refreshed offline package. Unknown/unlocated routes stay visibly unknown; do not infer locate clearance from an unsurveyed area.

This path may be developed in parallel with Show PC profile repair and the true Windows installer. It must **not** trigger new automatic GPX import, master replacement, SQL migration, production source change or Garmin cleanup just because a candidate review screen exists.

## Engineering verification and acceptance matrix

| Candidate / evidence | Current verified limitation | Required next acceptance |
| --- | --- | --- |
| #378 Windows GIS Manager | Existing dev launcher needs repo modules and Python; not an end-user installer | Package clean-user installer; source/version, updates, backup/rollback, ordinary-user GUI acceptance |
| Shared Symbol Library move | October 14 physical rename 823/823 verified; full application consumer cutover not accepted | Inspect all hardcoded old-root consumers, normalize approved root, test laptop/Office/Show and prevent old folder recreation |
| Show PC | Older symbols/profile, no proven safe current GPX/aerial open, no synchronized install acceptance | Read-only baseline → independently approved release → consented install → exact parity and disposable GPX roundtrip |
| #378 source change review | Read-only name/occurrence-based GPX diff; no spatial lineage work queue, map per segment or approvals | Detect manual prior processing and one source → N segments, map review, duplicate guard, reviewed disposition |
| #319 backend | Initial bootstrap/FLW evidence and synthetic/disposable tests do not prove recurring populated-DB acceptance | Different-SHA staged reconcile, per-item decisions, retained old routes, guarded publish and operator browser validation |
| 2026 repair map | Current master and protected viewer may differ; exact current GPX/accepted PostGIS hashes unverified | Compare fresh current sources, approve priority repairs, publish only under governed release, visually verify corrected effective routes |
| Garmin device | USB presence can be detected; complete dedup recording import, device mapping and cleanup not accepted | Separate consented intake/sync, field tests, stable original archive; device cleanup separately approved |

Before any code or controlled-doc update: refresh remote main/branch SHA, inspect current code and linked standards, reconcile concurrent branches and approved newer decisions. Do not overwrite PR #319 implementation or bypass #88/#230. Run targeted and full regressions, current-source disposable replay, installer tests on clean Windows user, actual protected browser and Garmin/Show-PC operator acceptance as applicable.

**Acceptance status October 19:** design reconciliation proposal only; no new Windows installer, Show PC profile synchronization, approved repair-track reconciliation or Production map update is claimed. The documented October 14–15 #171 issue requirements must be promoted to the controlling contracts before related code is called complete.

## Navigation and controlled documentation closeout

- [GIS Symbol Management](GIS_Symbol_Management.md) remains authority for SVG/PNG/BMP content, per-consumer icon publication and compatibility (including historical release evidence). Move or cross-link desktop-specific requirements into this dedicated document **after approval**; do not maintain conflicting normative text in two places.
- [Site Source Synchronization Contract](https://github.com/Gregovate/MSB-Production-Database-Project/blob/feature/171-cableiq-import-validation/Database/EngineeringTools/Site_Source_Synchronization_Contract.md) on #319 remains authoritative for PostGIS identity, backend ingestion, revisioned source promotion and exports.
- [Network Source Reconciliation](Network_Source_Reconciliation_2026-10-09.md) provides historic raw tester/drawing/GPX evidence rather than substitute app behavior.
- [GIS Engineering README](README.md) is a portal/handoff only. [#171](https://github.com/Gregovate/MSB-Production-Database-Project/issues/171) records outstanding work/evidence; #378 and #319 consume these engineering documents in code and acceptance. No new independent GIS application, importer or duplicative work-order system is authorized.


### October 20 #428 first operator GUI test — intake and identification

Implement in existing #378 Windows GIS Manager, as a GIS Data Management action (NOT Garmin symbol wizard). Operator sequence: connect Garmin; read each GPX track from mounted Garmin GPX folders; overlay individual track and nearby waypoint identities on the already registered 2019 aerial; suggest a human name using recorded first/last points and any HV/NET/PRI hint in the recording name; allow corrections; Save & Next. Never require permanent master Type, cable identity or import into PostGIS during identification. Store reviewed names and temporary types as separate intake receipts; original Garmin GPX, original Shared Drive source and master GPX remain byte-unchanged. Reopening shows prior reviewed names; review does not delete Garmin files. Calibration must use existing validated workstation/map authority; an uncalibrated vector-only canvas is not acceptable as aerial acceptance. If no verified raster/calibration is accessible, show a blocking error rather than an invented basemap. Later old/current/replacement reconciliation stays #319-governed and explicitly separate.

### October 20 Windows candidate verification — bounded intake, not release acceptance

PR #378 now contains current-main `a770e755dc4ce59873a004b3d92368c4c4cf7eae` and design head `4655a32593b0558f5ddd6f7caa9fc81b97af0160` through deliberate merges, preserving both sides of the GIS documentation conflicts. Runtime candidate **V0.4.6-garmin-track-intake**, source `43c2469f8d0f18d3b7e414362ffb9197d83634a3`, uses the existing Manager GUI and existing published 2019 XYZ aerial. No replacement application or GIS database is introduced.

- Fixed unavailable-G: startup failure and inaccessible-drive discovery failure. Operations still preflight actual destinations; inability to inspect a library is never proof it is current.
- Fixed HTTP 403 for tile requests by providing client identification/referrer; live 550 × 290 composition around park coordinates succeeded. No tile publication/server mutation was performed. This proves retrieval/projection, not independent survey alignment or full park coverage.
- Framing uses projected bounds rather than point-average centering, preserving unevenly sampled endpoints. GPX segment gaps remain gaps. Invalid coordinates and unrenderable extents stop review. Tile loading runs outside Tk's event loop; results from superseded selections are discarded.
- Save binds the review to the displayed recording hash and loaded master hash. Changed inputs stop saving; receipts retain master provenance. Intake destination cannot be inside the selected Garmin source folder. Original/master byte preservation, reviewed-name reopen, and Tk Read → edit → Save & Next were verified with disposable GPX fixtures.
- Ten intake tests and seventeen Garmin tests passed on Windows/Python 3.13/Pillow 12.0.0. A Pillow API compatibility defect in the existing Garmin BMP conversion was corrected. Full EngineeringTools discovery: **189 run, four failures, one error, two skips**. Remaining failures concern Office repair dialog naming, icon-preview scrolling, Windows case-insensitive SVG alias behavior, a stale source-string layout assertion, and the Office map-source test's missing argument. All occur on original `babfba47` as well; no full regression PASS or ordinary-user release is claimed.
- `build_gis_manager_candidate.py` built the same Manager as a self-contained Windows executable using PyInstaller 6.16.0. Its title was observed as `MSB GIS Manager — V0.4.6-garmin-track-intake [43c2469f]`. Executable SHA-256: `8b653ef5781a8999a05aeba0be308b163a13a33c6f6182ecc1c2cedc492fd0d3`. The adjacent candidate manifest records source file hashes. It is unsigned, has not passed clean-user installation/update/rollback, and is not an approved workstation configuration release.

**Concrete local access limits:** the existing Desktop shortcut targets `C:\lor\ImportExport\VSCode\database\EngineeringTools\Launch-MSB-Icon-Library.cmd`. This session cannot inspect/update that checkout or the shared G: GIS folder even after read permission was granted. The original shortcut/checkout remains untouched. On the operator's connected-Garmin report, this session's drive discovery exposed C:, G:, H: and P:, with no accessible mounted `Garmin/GPX`; D: did not exist. No real Garmin recording was read, processed, archived, or accepted. An accessible mounted source (or a separately implemented reviewed device-transfer path) remains required; do not report an empty inaccessible scan as completed intake.

**Still open:** real Garmin and fresh-master identification, visual calibrated-map acceptance, controlled update of the existing installation, clean-user package acceptance, and all later old/current/replacement reconciliation and governed promotion. #428/#171 remain open. No Production, registry, master, shared source or Garmin writes were performed during this verification.

**Subsequent real desktop verification:** Windows File Explorer independently showed **Garmin GPSMAP 66sr (D:)**. Launching the same built executable through the normal desktop session (rather than the restricted command-session token) resolved device/G: visibility: Home showed **Connected**, one Garmin symbol folder, and 37 approved PNGs matched. The restricted test instance was closed. In the normal instance, Track Intake automatically selected `D:\Garmin\GPX`; clicking **Read Garmin tracks (read only)** loaded the real queue. The first recording `2026-10-14 11:16:39.gpx` displayed **23 vertices** as a blue raw route over the published 2019 aerial, with nearby master waypoint labels and proposed **FE-10 → FE-02**, temporary type **Unknown**. This is actual device/read/display evidence; no review was saved or operator identification approved by the agent. Master path was the existing shared `MSB-Park-Infrastructure.gpx`, opened read-only by this app; no ExpertGPS action was taken. Survey alignment, correct cable/endpoints and promotion still require operator acceptance. At the observed Windows scaling, **maximize the intake window to expose Read**; compact-window button visibility needs correction before clean-user release. Do not launch end-user candidates from a restricted engineering shell and interpret its absent mapped drives as absent hardware.

**Final bounded candidate V0.4.7:** source `d173b18584b9200e3f280f14657962b679133eb8` corrects that observed compact-window defect by reserving Read/status and the endpoint/editor/Save dock before the expanding map. The real-device V0.4.6 window was left available for operator review; no operator edits were discarded to switch versions. Tk tests now require both Read and Save to be mapped and inside the normal-height window. Garmin names observed in the real queue such as `Hvfe00 tfe04&02` and `Netfe00tfe15` now yield temporary HV/NET hints; unrelated names stay Unknown. Home says **Not detected**, rather than asserting **Not connected**, when no accessible folder can be found. Ten intake tests pass; full final suite remains **189 run / four failures / one error / two skipped**, with the unrelated pre-existing limitations listed above.

The V0.4.7 self-contained executable SHA-256 is `6be6428c7e532c79c0497f7f7d19289f33980774b10851ed935ef4bf8646a4c5`. Its runtime source was published to the existing PR #378 branch as `37655e6bf53409812f639f1424bf02789a6bb741`, using the connected account when local Git credentials were unavailable. The complete published tree `044b05407c29f3c29b3cd98415189a95db7da3d5` equals the local package-source tree exactly; main and design heads are ancestors. The executable manifest records both identities and file hashes. This is a runnable engineering candidate, not an accepted installer/update/rollback release; the existing Desktop shortcut still targets the prior checkout. No full #428 completion, source promotion or Production acceptance is claimed.

**V0.4.8 close inspection:** Intake adds mouse-wheel/pointer-centered zoom, plus/minus controls, drag-to-pan, Fit track, and a 6-inch detail preset at display zoom 24 with a six-inch scale bar. Published tiles remain capped at z20; higher display levels enlarge those same registered pixels and explicitly identify the enlargement. This does not establish six-inch source resolution or Garmin positional accuracy. Map navigation preserves operator edits and disables Save during loading. Eleven intake tests pass, including close-view projection/tile limits and Tk zoom with edited-name preservation. Executable links in Codex preview binaries rather than launch them; launch the existing executable in the normal Windows desktop session. Prior release/installer limitations remain open.

**V0.4.9 pan/label correction:** Left-button dragging now immediately moves the aerial, track and waypoint overlays together; release requests imagery at the new registered center. A hand/move cursor makes the gesture visible. Waypoints use yellow markers with black borders, and larger black labels on opaque white bordered backgrounds. START/END use the same label backing. Eleven intake tests pass, including actual Tk drag-motion displacement, label backgrounds and preservation of operator edits across pan/zoom. No real review is automatically saved.

**V0.4.10 viewport resize correction:** Canvas size changes invalidate stale tile requests and trigger a debounced redraw at the actual canvas dimensions, preserving geographic center, zoom and operator fields. Eleven intake tests pass, including resizing a live Tk intake window and checking image dimensions match the enlarged canvas while the edited name and zoom remain unchanged. Candidate replacement must close superseded Manager instances after preserving current operator edits; do not leave each test version running.

### October 20 operator correction — current master reconciliation and annual history

The operator confirmed that the current ExpertGPS `MSB-Park-Infrastructure.gpx`, not the prior PostgreSQL load, is the core source for this review. Display and endpoint suggestions use its waypoints except records whose Type is Stage; retain all source waypoints in exported GPX. Actual read-only inspection of the October 20 03:26 local file: SHA-256 `cb398c2c3ec489dcc0a2395ed1a13155153c47ec7ea4a09449663b6dcb93d46c`, 236 waypoints, 33 Stage records, 203 non-stage references, 199 tracks. This is a file observation, not verification of the current database revision.

Operator sequence extends bounded identification: rank similar existing master tracks; explicitly select the same physical track; compare old master geometry with new recording on the existing aerial; inspect historical comments, description, installation notes/years and ExpertGPS extensions; polish only a derivative using selected-point removal or explicit coordinate correction; choose Keep existing or Accept replacement. Neither ranking nor proximity establishes physical identity. The first recording ranks master ordinal 185 `NET FE-02 to FE-10` first (approximately 1.1 ft mean raw-to-master distance, matching endpoints), and may already be processed. Its 2014 installation/replacement notes remain unaltered.

**Annual history policy, operator-confirmed:** one historical version per physical track per year, not every individual editing update. Overall history starts in 2012; core infrastructure begins in 2014. Extract explicit year references from track comments/descriptions as review evidence, deduplicate references by track/year, retain original text and mark uncertain chronology. Never backdate present geometry to an installation year or invent annual survey geometry. Transaction/audit/source-integrity receipts are not additional user-facing annual history versions. The live PostgreSQL history implementation has NOT been verified; do not claim that PostgreSQL already implements this policy.

**V0.5.0 candidate:** extends the same Windows Manager with stage exclusion and Match / polish / replace master track. Accepted decisions retain immutable raw/master snapshots, exact master/source SHA and ordinal, selected original vertex lineage and reason/evidence. Master metadata and unrelated features survive a separate reviewed working-master export; only selected track segments change. Garmin/ExpertGPS use different versions under the same `gpxtpx` prefix, so imported vertices retain their own local namespace scope rather than altering master namespace bindings. Conflicting duplicate replacement targets, source drift, missing evidence and corrupt snapshots stop acceptance/export. The export manifest carries annual history evidence and explicitly marks PostgreSQL release pending. No direct desktop SQL or competing maintained database is introduced.

**Validation:** 18 focused intake/reconciliation tests pass, including actual Tk match/confirm/accept against disposable fixtures, edited-name preservation, live canvas resize/pan and XML metadata/namespace conservation. A disposable replay using local read-only copies of the actual 199-track/236-waypoint source and first recording preserved every unrelated feature and selected-track metadata semantically (XML formatting may differ); both input hashes remained unchanged and disposable output was removed. No real operator acceptance was fabricated. Full EngineeringTools: 197 tests, four known pre-existing failures, one known pre-existing error, two skips; see prior baseline evidence.

**PostgreSQL handoff remains incomplete:** current #319 `Site_Source_Synchronization_Contract.md` explicitly documents that its bootstrap rejects a different source SHA once maintained rows exist and that recurring populated-database compare/identity/conflict/promotion acceptance is missing. The requested final release requires that #319 workflow, annual-history implementation/disposable tests, comparison with the actual accepted DB source, and Server Management runbook-controlled release after operator review is finished. This candidate exports reviewed source proposals; it does not assert a completed database migration, accepted installer, or release. No shared master, Garmin source, or Production data was changed by development/testing.

### October 20 operator correction — explicit new-run export and canonical labels
The operator rejects bulk Receive from GPS as the reconciliation workflow: it can introduce uncontrolled names and duplicates. Existing #428 intake must distinguish read-only device enumeration from accepted GPX changes. Add an explicit reviewed NEW run path with operator name/type and original point range, separate from replacement of a chosen master run. Export one complete working master containing only accepted additions/replacements; clearly require opening it separately in ExpertGPS rather than merging the complete master into itself. Preserve originals, unrelated master features, existing run metadata and source receipts. Reject duplicate names/exact route replay and unknown new-run classification; proximity alone cannot prove a duplicate or cable identity.
Use ExpertGPS Label on Map (extension label_text) for maintained waypoint/track display and matching, with GPX name fallback; preserve distinct GPS names as source provenance. The operator will add the combo outlet box at the indicated intermediate point in ExpertGPS. No guessed waypoint/circuit coordinates or topology are approved.
The #319 current contract still documents missing recurring populated-database promotion. This desktop correction does not establish live PostgreSQL contents or update Production.


### V0.5.7 route installation intake — October 20, 2026

One reviewed Network route retains one geometry and multiple cable designations.
The operator explicitly supplies installation year (2026 for the current new
FE-02/LPFC-01 installation); unknown historical HV years remain unknown.
Network, HV, Primary and geometry-only road/trail workflows remain distinct.
HV circuit and Primary transformer/panel relationship editors remain unfinished.

The existing governed network authority is ref.site_network in #319. Intake can
read the existing site-reference snapshot format (format_version=1,
data_mode=postgres, revision, networks with site_network_id/network_code).
Multi-selection retains table identities plus snapshot revision/SHA. Without
that snapshot, operator-entered labels are explicitly pending identity evidence;
no network table or database identities are created. SPARE designations remain
separate from network membership. No live catalog connection or Production
reference-editor deployment has been verified in this Windows candidate.

Working GPX exports include msb.gis.route-installation.v1 evidence in the review
manifest and urn:msb:gis:route-installation:1 GPX extensions. New routes also get
a consistent human-readable description with Year installed and Networks.
Replacement comments, descriptions and existing extensions remain intact.
These intake fields are staged evidence for #319, not a claim that its importer
already promotes this new extension or converts a year into an exact date.
ExpertGPS extension round-trip remains to be verified. FLW remains read-only.

Save draft preserves installation fields and review notes without acceptance.
The current user's eight designations are REG, E1.31, INET, AUX-E, AUX-F, AUX-G,
AUX-H and SPARE-1. Geometry splits and new FE-02B placement remain ExpertGPS work.
