# #171 / #230 — Existing Park Map: implementation, offline gap, and editor acceptance

| Document control | State |
|---|---|
| Status | **BASELINE RECONNAISSANCE + SOURCE-ONLY SVG/OFFLINE CANDIDATE — browser/tablet acceptance pending** |
| Verified repository baseline | `main` `4ef6087600ef8dbcfb64293241dae2ab2c15b4de` (2026-10-11) |
| Work vehicle | Existing draft PR #319 (`feature/171-cableiq-import-validation`), reconciled with latest `main`; no Production deployment |
| Governing issues | #171 GIS/map and source topology; #230 Reference Data Manager/editor; #122 acceptance; #88 movement events; #113 tablet infrastructure |
| Operator evidence | 2026-10-11 screenshot of actual `https://my.sheboyganlights.org/setup/locate/` showing current aerial, park symbols, waypoint search, GPX/HV/NET layer controls, season assets, and cable evidence |
| Purpose | **Evolve this existing map**, not replace it with another offline HTML map or recreate an existing waypoint finder |

## October 19 map popup / C009 current movement correction — active #171 engineering design

**Observed operator/browser evidence:** On the deployed protected Setup Park Map, expanding the Potter's Pole base **Record details** popup covers the selected marker. The marker remains at its recorded coordinate; the popup is an overlay and must not be mistaken for a removed feature or edited GPS. The existing `setup_locate_assets.js` attaches a Leaflet popup to markers and renders nested HTML `<details>` without explicitly offsetting popup content above the complete marker artwork or remeasuring when details opens. The acceptance criterion is **keep the selected icon visible while its popup is both collapsed and expanded** on desktop and narrow tablet, for Containers and independently observed Displays, including colocated markers.

**Presentation-only implementation:** Keep all original marker positions, exact-coordinate co-location grouping, icons, source events, movement associations, popup contents and map search untouched. Add a Leaflet popup offset derived from the rendered marker icon's actual vertical anchor/size, with a little separation below the popup tip, so popup content no longer covers the icon. When internal `<details>` expand/collapse, update the existing popup layout and auto-pan using Leaflet's popup API rather than recreating markers, modifying the map dataset, or changing stored GPS. Bound popup maxHeight remains 360 and its scroll remains available. Avoid unconditional recentering or erroneous marker deletion. Regression must check both icon types, disclosure event handling and nonmutation of positions; actual browser/tablet visual acceptance remains pending.

**C009 operator evidence, pending saved-record verification:** Greg reports Container **9** was renamed **Ginger Bread House** and linked Display **909** is `CL-GingerbreadHouse`. Directus edit form visibly shows Home `Z-BLDG-A-EAST`, Container Type **Display Pallet**, separate `Display Pallet Flag` **unchecked**, Goes To **Park** and Test Annually **enabled**. Editing text shown in a form is not a database-save receipt. Type and flag are distinct fields and their inconsistency must not be auto-corrected by the map. #230 must check the current saved record, assigned Display names, actual physical show-base role and if the existing flag should be governed; #88 owns the separate physically detached/remaining cargo versus field-position events. The Container may remain in the park after all carried Displays are removed; **empty cargo does not mean Returned Home**. The map must continue to show the Container and Display identities separately without manufacturing physically separate objects or conflating the reference relationship with current Setup placement.

**Docker read-only Production inspection correction:** The authoritative [MSB Server Management disposable/database standard](https://github.com/Gregovate/MSB-Server-Management/blob/main/docs/server/PostgreSQL_Disposable_Acceptance_Standard.md) identifies host `msb-prod-db / 192.168.5.9` and PostgreSQL Docker Container **`msb-postgres`**. The earlier proposed host `sudo -u postgres psql` command is inappropriate for this runtime. Execute checked read-only SQL from server-host path **through stdin** to `sudo docker exec -i msb-postgres psql -X -v ON_ERROR_STOP=1 -U msbadmin -d msb`, under role `fieldwiring_app` for allowed reads. `psql -f /tmp/host.sql` inside Docker cannot access an unmounted host path. No Production SQL result, saved C009 name or actual popup fix deployment is yet proven.

**Ownership:** #171 owns existing map presentation, #88 owns movement, #122 coordinates launch, #230 owns Container metadata, #231 synthetic Testing wrapper. Implement on existing #171 PR #319 and reconcile with newer `main` before merge; source-only isolated CSS/JS behavior is not a reason to integrate unaccepted #319 PostGIS migration. No new viewer or infrastructure.

## October 11 implementation candidate — correct Plain SVG map and offline field package

This is a **candidate branch based on PR #319**, not a Production installation. It
modifies the **same** `/setup/locate/` screen and current PostGIS projection,
rather than adding another map. The baseline table below describes the prior
implementation and must not be read as the new candidate's runtime acceptance.

**Approved symbols:** `setup_locate_symbols.js` maps explicitly recognized
ExpertGPS waypoint *types* (not guessed waypoint name text) to approved
lowercase `msb-svg/*.svg` filenames. The browser loads each image's actual
`naturalWidth/naturalHeight` and uses that exact 1–32 px aspect ratio; a
missing/unreviewed image produces a visible neutral point, not an incorrectly
stretched legacy PNG. `marker_url`, label, type, original GPX reference and
position remain unchanged in the source and DB. Types without a reviewed icon
mapping (e.g. original Anchor/Waypoint, certain car and tower labels) continue
as circles until an explicitly approved mapping exists. Containers retain their
four separate load-state SVGs; independent Display markers use the reviewed
`t-post.svg` rather than public `T-Post.png`. No source artwork is created,
published or overwritten here. **Administrator publication of current Plain SVG
files to `msb-svg` is still a separate field acceptance gate.**

**Offline read-only operation:** local licensed Leaflet 1.9.4 JS/CSS replaces
the `unpkg.com` runtime dependency. The **Offline park map** control explicitly
downloads a versioned package into the same browser/device CacheStorage and
shows completion/progress, installed time, tile count and reference revision.
One Park Map-scoped service worker caches the same map HTML (including its
embedded GPX waypoint/track names/geometry/search index), local scripts,
source-network JSON, reviewed SVG icon URLs and fixed 2019 imagery URLs.
Package activation happens only after successful full cache writes; failed
updates leave any previous completed package intact. The user chooses imagery
through zoom 19, 20 or 21, with approximate bounded tile counts **484 / 1,699 /
6,426**, respectively. Coverage uses two deliberate rectangles for Evergreen
Park and the approach toward the real GPX Workshop, excluding the unrelated
southwest outlier GPX observation. The imagery is **not** a verified locate or
survey. Extra/uncached geography has no offline tile guarantee.

When online authenticated PostgreSQL references are available, the explicit
download also saves a **read-only, dated** maintained reference snapshot
(waypoints, tracks, panels, circuits, cable review and memberships) without
permissions or an edit queue. When unavailable, the package contains just the
static GPX/dated network source with that limitation prominently shown. Offline
map/reload/search/GPS can still be used; **#88 Container/Display live asset
positions are not cached**. If asset refresh fails, the map clears its last-known
asset overlays rather than portraying stale movement as current. The Site
Reference editor is deliberately disabled for offline snapshots; every
Production mutation remains an online, server-authorized command.

The offline package saves public webassets tile/image responses in CacheStorage.
Cross-origin images may be opaque to script, so a successful copy count alone
does **not** prove tile-image validity, field coverage, browser quota retention or
Cloudflare/Access offline restart. **Real rugged Android field acceptance is
mandatory**: prepare while connected, verify required Plain symbols and zoom
coverage, switch to airplane mode, completely close/reopen the installed
browser/PWA, reload `/setup/locate/`, search `PANEL A5-00` / `Workshop`,
inspect HV/NET routes and saved circuits, pan through Park and Workshop at
the chosen zoom, verify the offline/dated label, confirm no #88 asset claims
or offline writes, reconnect/refresh and repeat. Do not mark the work accepted
before that run. Source regression is
`node Setup/Application/test_setup_locate_offline.cjs` via the Site Reference
workflow. No database migration or additional Production dump is required
for this source-only offline renderer candidate.

## Verified existing behavior — source/code inventory

The screenshot demonstrates a useful existing aerial-backed interactive park viewer, not an editor. The corresponding code in current `main` confirms:

| Data/component | Actual implementation | Consequence |
|---|---|---|
| Aerial and map UI | `Setup/Application/locate_preview.html` contains Leaflet map code, layer controls, popup presentation, an **embedded generated GeoJSON snapshot** (`const data = …`). The visible UI calls itself **Park Map v1**, version `V0.3.62-field-networks`, updated 2026-10-10, read-only. | GPX-derived waypoint/track positions are **baked into the deployed HTML** at generation/publish time. They are not dynamically fetched from accepted maintained PostGIS reference tables and cannot be edited here. “Hard-coded” describes the resulting artifact, not manual typing of each waypoint into the source. |
| Orthophoto | Leaflet tiles read `https://webassets.sheboyganlights.org/maps/evergreen-2019-v1/{z}/{x}/{y}.jpg` (2019 Sheboygan County imagery). Leaflet JS/CSS load from `unpkg.com`. | Remote network access is necessary for uncached images/library code. The current park viewer **does not demonstrate reliable offline access**. |
| Icons | Reference feature `marker_url` points to `https://webassets.sheboyganlights.org/images/symbols/msb/…`. | These assets must be available in a versioned offline package; preserve approved MSB GIS/symbol artwork and type mapping. |
| Network/cable evidence | `Setup/Application/setup_locate_networks.js` fetches `assets/setup_locate_networks.json` (no-store). The current committed JSON identifies **`26-10-09-Park-Data-roundtrip-test.flw`**, contains **445 `cables` entries**, 59 mapped-route candidates, 122 unresolved GPX tracks, 25 review records, and 73 legacy edges. | This is a **dated, generated reconciliation snapshot**, not an automatic import/view of the newly confirmed shared FLW or approved DB cable topology. The 445 entries have a different scope than the newer source's 476 UUIDs; do not interpret their difference as precisely 31 lost physical cables. |
| Container and Display positions | `Setup/Application/setup_locate_assets.js` calls GET `../api/setup/locate/assets?season_year=…` with `cache: 'no-store'`. The Python adapter `setup_locate_assets.py` uses #88 current movement/evidence read-only. | This layer **is API-backed**, not hard-coded. It must remain separate from permanent infrastructure waypoints and not be rewritten as reference points. It is unavailable without a live API unless explicitly shown as a stale dated cache. |
| Serving and write authorization | `Setup/Application/production_backend.py` serves GET `/locate/` from `locate_preview.html`, approved map assets from a static allowlist, and uses `Cache-Control: no-store`. `Setup/Acceptance/test_setup_gis_preview.py` confirms POST to `/setup/locate/` responds 405. | There is currently **no editor**, no general reference-data save endpoint, no map permission matrix, and no accepted offline map package. A passing synthetic DB schema test does not change that. |
| Existing *other* offline implementation | `Setup/Application/setup_record_location_sw.js` precaches `/record-location/` app shell and its reference JSON using a versioned service worker. It handles its **own scoped routes**, not `/locate/`, the map tiles, symbols, or full map's JS. | Reuse proven service-worker lessons, but **do not claim `/record-location/` offline support makes the park map itself offline** or overwrite its separate #88 workflow. |

**Source inputs/corrected baseline:** the operator-verified GPX at `Shared drives\Display Folders\Park Drawings\GPS Data\2026 Updates and DB connection\2026_msb_FRESH_START_CLEANED_2026-10-06.gpx` has **233 ExpertGPS Label-on-Map waypoints and 181 tracks**. The corrected LinkIQ file at `Shared drives\Display Folders\Park Drawings\Network\LinkIQ Data Files\LinkIQ Data Import for DB with corrected names.flw` contains **684 LinkWare project appearances of 476 distinct saved-test UUIDs**, including 208 repeated appearances; 0 cross-project measurement conflicts in the read-only extractor. Shared Drive mount letters vary by user. Source paths and file hashes are detailed in draft PR #319's `Database/EngineeringTools/Site_Source_Synchronization_Contract.md`. GPX canonical display identity is ExpertGPS **Label on Map**, never Garmin `<name>`.

**Database acceptance scope:** governed disposable current-Production-clone acceptance for PR #319 candidate `baefba3c1e849430536c45581a0bacb09db5bacb` completed with **exit 0** and unchanged Production fingerprint, report `/home/msbadmin/setup-acceptance-reports/Setup_Disposable_Acceptance_20261011T113238.txt`. This verified **proposed schema and synthetic SQL constraints**, not an actual 233/181/476 source import, permanent identity promotion, UI editor, or Production installation. The temporary DB was cleaned up.

## Operator-defined destination — improve the existing `/setup/locate/` screen

**#230 is the application editor. #171 supplies its maintained spatial, power and network reference semantics.** Use the current aerial, map navigation, search, layers, selected equipment popups, and cable investigation UI as the front end, extended by role-governed editor commands rather than a competing viewer. Keep Setup's movement semantics (#88) separate.

### Permanent reference editing (Manager; #230)

- Select a waypoint on this map; see canonical **ExpertGPS Label-on-Map** identity, type/icon, coordinates, source history, verified state and audit; create new waypoint, rename/edit alias, correct coordinates, and retire/reference track as separately authorized actions.
- Geometry editing must respect **NAD83 HARN WISCRS Sheboygan County Feet / EPSG:8158**, transform for browser WGS84 and record source/fix uncertainty. Do not treat smartphone observations, drawing symbol movement, or schematic coordinates as an automatic replacement for curated survey/GPX source.
- Field contributions can be staged as **review required**. Show the before/after and who/when, preserve prior values, and detect GPX ↔ DB concurrent changes; no silent last-write-wins or duplicate permanent identity.

### Power panel / breaker / outlet relationships (authorized Production crew; #171/#230)

These requirements already exist in the GIS README's *Required panel, circuit and seasonal power records* and its 2026-10-10 permission clarification. They have **not** been implemented by the current #319 candidate schema.

- Open an existing panel waypoint (e.g., `A5-00`), identify the actual panel/meter/owner, add breaker/circuit identifiers **scoped to that panel**, supporting labels, applicable ratings and provenance.
- Choose a circuit, link it to one or many **existing outlet/OUT-Combo waypoints** and downstream loads, including intermediate fuse/disconnect where documented. Clicking an outlet reveals its supplying panel + breaker, and clicking a breaker lists all its attached waypoints.
- A Production crew user may identify/maintain circuit information and link **existing** waypoints; this is **not** authorization to rename or move waypoint identities/coordinates. Do not infer electrical feeds from spatial proximity, network tests or diagram geometry.
- Include source, uncertainty, verified/unverified state, actor/time and change history. Seasonal power-switching tasks and “turned off” evidence remain #122 operational facts—not permanent GIS topology or proof of de-energization.

### Networks, testers, tracks (investigate, then maintain reviewed facts)

- An OUT-Combo may belong to **multiple network designations**; a network covers multiple locations. Show both memberships alongside the **separate electrical circuit**. Name ambiguity and incomplete topology stay unresolved until reviewed.
- Inspect LinkIQ cable UUID/test history, edited `Records.CableId` versus embedded original tester name, endpoints and measured length; identify **unique physical cable IDs** without conflating repeated tests/project appearances with independent cables or assuming qualified standard = live link speed.
- Link reviewed physical cables to waypoint endpoints, GPX tracks, network(s) or SPARE designation, and schematic object IDs. Preserve separate parallel cables, destroyed/replaced/historical traces and route alternatives.
- Keep three authorities distinct: GPX = waypoint positions/routes, LinkIQ = cable test evidence, draw.io = schematic topology/presentation evidence. Surface conflicting endpoints, unmapped routes and source age/hash on the *existing* network details UI. The versioned JSON file is **not** an approved DB import.

## Offline map requirement — **mandatory**, not optional reconnaissance

Park Wi‑Fi is **not available throughout Evergreen Park**. Reading known waypoint locations, searching names and inspecting reference tracks **must work after the user has intentionally prepared the device while connected**, including a full app restart without internet. Offline usability must not depend on browser disk cache accidents.

1. **Versioned offline package for this map:** package the permitted 2019 orthophoto tiles covering the actual park and appropriate field zoom levels, Leaflet JS/CSS locally (no CDN dependency), all used marker icons, 233-waypoint/181-track reference geometry and lookup index, reviewed network/cable/circuit reference projections and metadata. Estimate tile count/storage per chosen zoom boundary; respect source rights and device storage; do not blindly cache an unbounded tile service.
2. **Field installation/update:** a pre-season / pre-field “Download or refresh offline park map” action, clear progress/storage-size indication, version/hash and last-successful-sync time. Atomic replacement; do not leave a partially fetched map presented as complete. Clearly indicate **online current / offline dated snapshot / incomplete package**.
3. **Read-only first:** while disconnected, pan/zoom the actual park imagery; search a waypoint; inspect named GPX network/HV tracks and panels/outlets with their last downloaded relationships; show source/version/time and absence of current asset truth. Device geolocation may be shown when permitted, with accuracy in feet and fresh/stale fix handling. Do not invent current Containers/Displays from expired #88 API data.
4. **Offline edit policy must be explicit:** no silent reference or Production mutation; if offline edits are introduced, queue attributed proposals with stable IDs, baseline versions and source evidence, validate on reconnect, reject conflicting writes for review, and enforce server-side Manager/crew permissions. **No last-write-wins or automatic source promotion**. Online editor actions can be delivered first while offline remains guaranteed for reference lookup.
5. **Security/runtime:** design cache scope for authenticated Setup/Access; avoid copying personal or current movement data into a permanent public cache. Because current `/locate/` is served `no-store`, offline handling needs its own approved asset-manifest/service-worker policy rather than overriding global application caching. Review Service Worker ownership with existing `/record-location/` scope. Field testing requires a supported rugged Android tablet, park/network dead-zone simulation, airplane mode/reload, tiles/icons/search and version updates. A desktop browser rendering once does **not** demonstrate offline readiness.

## Minimal staged acceptance using the existing UI

1. **Current-state inventory and preview:** screenshot and code references above are baseline. Show current source version and classification in the existing map UI. Do not create yet another parallel map/waypoint finder.
2. **Visual DB proof:** import source evidence into a governed disposable database, **repeat import**, then show browser counts and unresolved list versus source manifest. Distinguish staged source rows from promoted permanent waypoint/cable/panel/circuit records. No duplicate UUID, overwritten corrected label or false matched cable.
3. **Manager map editing:** select `A5-Church` or other safe test waypoint on disposable clone; edit approved metadata/location; show map update, exact audit and GPX export conflict handling. Never mutate shared GPX or Production for a test.
4. **Crew circuit editing:** create an example test panel/breaker and attach multiple existing test outlets; verify click-through in both directions and permission denial for crew coordinate editing. Use disposable examples rather than invent actual A5-00/FE-00 wiring.
5. **Networks:** inspect a conflicting/unmatched LinkIQ/GPX segment; classify only after reviewed evidence; show assigned network members, physical cable ID/history, source age/hash and unknowns.
6. **Offline:** download bounded map package while online; disconnect; reload the existing map, search, pan, inspect GPX tracks and circuit information; reconnect and refresh with explicit review/permissions. Do not depend on Wi‑Fi throughout park.
7. Browser/editor acceptance should **not trigger a second Production dump merely to preview a UI**. Reuse a governed persistent disposable snapshot/environment where explicitly supported; previous candidate acceptance clone/dump was cleaned up. Keep #122 runbook and Production authorization separate.

**Not completed:** #230 editor/API, real full-source DB ingestion and promotion, panel/breaker/waypoint/network maintained relationships, offline package/cache, actual tablet offline proof, operator visual browser acceptance, and Production deployment. **Do not treat a clean SQL migration test as fulfillment of these requirements.**

## 2026-10-11 operator review of corrected *existing* Park Map preview

Greg opened the corrected local version of the existing `/setup/locate/` map and
reported that the **waypoint names are now updated** and the overall presentation
is **much better**. This is positive operator evidence for the GPX name/position
correction, **not an acceptance of Production deployment**, offline coverage,
physical cable topology or the permanent reference editor.

Remaining acceptance findings and explicit ownership:

- **Remove the temporary Workshop marker.** The latest approved ExpertGPS GPX
  already contains `Workshop`, **Type: Waypoint**. The October 8
  `temporary-workshop` injection in the old generated map is superseded; the
  permanent GPX point is authoritative. Do not conflate it with #88 Workshop
  storage/movement evidence or allow both points to show as duplicates. The
  #319 local preview assembler now checks for the canonical GPX point before
  deleting only the identified placeholder in the staged output.
- **Missing waypoint icons:** Greg is correcting artwork/type symbols in the
  separate existing GIS icon workstream. Do not alter that image library or
  introduce guessed/duplicate icon mappings in the #319 source-data fix.
- **LB WiFi Antenna:** source label `LB WiFi Antenna`, **Type: Tower**,
  ExpertGPS source time `2026-10-10T18:40:42.586Z`. Preserve its source name,
  type and timestamp in the map data even if its missing icon is resolved
  separately.
- **AUX-I incomplete:** some AUX-I route segments still do not resolve in
  the corrected network view. Greg reports the **other two previously missing
  segments are now resolving**, but did not supply their identities in this
  feedback. Do not assert that AUX-I topology is complete or guess missing
  endpoints. This remains a #171 spatial/LinkIQ/schema reconciliation review
  item with explicit unmatched evidence. `32` candidate matched tracks and
  `149` unresolved tracks describe the new GPX+FLW screening result, not
  verified cables or proof of a complete route.
- **Release boundary:** refresh the current Setup map's source HTML and network
  JSON as a separately scoped source-only correction after normal candidate
  visual/regression acceptance and explicit authorization. Defer manager/crew
  editing to the next #230 milestone, without delaying the immediate correction.
  No new PostgreSQL dump is needed merely to review the source-only map.

Status: **operator visual feedback received / corrections still pending**.
Local source-only previews are not Production and are not offline-ready.

