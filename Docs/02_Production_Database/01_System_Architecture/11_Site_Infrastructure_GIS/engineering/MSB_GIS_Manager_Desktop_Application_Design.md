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

## October 19 field-first priority — capture current ground paint before it disappears (#171)

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
