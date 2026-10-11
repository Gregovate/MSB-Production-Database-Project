# #171 / #230 — Existing Park Map: implementation, offline gap, and editor acceptance

| Document control | State |
|---|---|
| Status | **RECONNAISSANCE / ACCEPTANCE REQUIREMENTS — not implemented** |
| Verified repository baseline | \`main\` \`4ef6087600ef8dbcfb64293241dae2ab2c15b4de\` (2026-10-11) |
| Work vehicle | Existing draft PR #319 (\`feature/171-cableiq-import-validation\`), reconciled with latest \`main\`; no Production deployment |
| Governing issues | #171 GIS/map and source topology; #230 Reference Data Manager/editor; #122 acceptance; #88 movement events; #113 tablet infrastructure |
| Operator evidence | 2026-10-11 screenshot of actual \`https://my.sheboyganlights.org/setup/locate/\` showing current aerial, park symbols, waypoint search, GPX/HV/NET layer controls, season assets, and cable evidence |
| Purpose | **Evolve this existing map**, not replace it with another offline HTML map or recreate an existing waypoint finder |

## Verified existing behavior — source/code inventory

The screenshot demonstrates a useful existing aerial-backed interactive park viewer, not an editor. The corresponding code in current \`main\` confirms:

| Data/component | Actual implementation | Consequence |
|---|---|---|
| Aerial and map UI | \`Setup/Application/locate_preview.html\` contains Leaflet map code, layer controls, popup presentation, an **embedded generated GeoJSON snapshot** (\`const data = …\`). The visible UI calls itself **Park Map v1**, version \`V0.3.62-field-networks\`, updated 2026-10-10, read-only. | GPX-derived waypoint/track positions are **baked into the deployed HTML** at generation/publish time. They are not dynamically fetched from accepted maintained PostGIS reference tables and cannot be edited here. “Hard-coded” describes the resulting artifact, not manual typing of each waypoint into the source. |
| Orthophoto | Leaflet tiles read \`https://webassets.sheboyganlights.org/maps/evergreen-2019-v1/{z}/{x}/{y}.jpg\` (2019 Sheboygan County imagery). Leaflet JS/CSS load from \`unpkg.com\`. | Remote network access is necessary for uncached images/library code. The current park viewer **does not demonstrate reliable offline access**. |
| Icons | Reference feature \`marker_url\` points to \`https://webassets.sheboyganlights.org/images/symbols/msb/…\`. | These assets must be available in a versioned offline package; preserve approved MSB GIS/symbol artwork and type mapping. |
| Network/cable evidence | \`Setup/Application/setup_locate_networks.js\` fetches \`assets/setup_locate_networks.json\` (no-store). The current committed JSON identifies **\`26-10-09-Park-Data-roundtrip-test.flw\`**, contains **445 \`cables\` entries**, 59 mapped-route candidates, 122 unresolved GPX tracks, 25 review records, and 73 legacy edges. | This is a **dated, generated reconciliation snapshot**, not an automatic import/view of the newly confirmed shared FLW or approved DB cable topology. The 445 entries have a different scope than the newer source's 476 UUIDs; do not interpret their difference as precisely 31 lost physical cables. |
| Container and Display positions | \`Setup/Application/setup_locate_assets.js\` calls GET \`../api/setup/locate/assets?season_year=…\` with \`cache: 'no-store'\`. The Python adapter \`setup_locate_assets.py\` uses #88 current movement/evidence read-only. | This layer **is API-backed**, not hard-coded. It must remain separate from permanent infrastructure waypoints and not be rewritten as reference points. It is unavailable without a live API unless explicitly shown as a stale dated cache. |
| Serving and write authorization | \`Setup/Application/production_backend.py\` serves GET \`/locate/\` from \`locate_preview.html\`, approved map assets from a static allowlist, and uses \`Cache-Control: no-store\`. \`Setup/Acceptance/test_setup_gis_preview.py\` confirms POST to \`/setup/locate/\` responds 405. | There is currently **no editor**, no general reference-data save endpoint, no map permission matrix, and no accepted offline map package. A passing synthetic DB schema test does not change that. |
| Existing *other* offline implementation | \`Setup/Application/setup_record_location_sw.js\` precaches \`/record-location/\` app shell and its reference JSON using a versioned service worker. It handles its **own scoped routes**, not \`/locate/\`, the map tiles, symbols, or full map's JS. | Reuse proven service-worker lessons, but **do not claim \`/record-location/\` offline support makes the park map itself offline** or overwrite its separate #88 workflow. |

**Source inputs/corrected baseline:** the operator-verified GPX at \`Shared drives\Display Folders\Park Drawings\GPS Data\2026 Updates and DB connection\2026_msb_FRESH_START_CLEANED_2026-10-06.gpx\` has **233 ExpertGPS Label-on-Map waypoints and 181 tracks**. The corrected LinkIQ file at \`Shared drives\Display Folders\Park Drawings\Network\LinkIQ Data Files\LinkIQ Data Import for DB with corrected names.flw\` contains **684 LinkWare project appearances of 476 distinct saved-test UUIDs**, including 208 repeated appearances; 0 cross-project measurement conflicts in the read-only extractor. Shared Drive mount letters vary by user. Source paths and file hashes are detailed in draft PR #319's \`Database/EngineeringTools/Site_Source_Synchronization_Contract.md\`. GPX canonical display identity is ExpertGPS **Label on Map**, never Garmin \`<name>\`.

**Database acceptance scope:** governed disposable current-Production-clone acceptance for PR #319 candidate \`baefba3c1e849430536c45581a0bacb09db5bacb\` completed with **exit 0** and unchanged Production fingerprint, report \`/home/msbadmin/setup-acceptance-reports/Setup_Disposable_Acceptance_20261011T113238.txt\`. This verified **proposed schema and synthetic SQL constraints**, not an actual 233/181/476 source import, permanent identity promotion, UI editor, or Production installation. The temporary DB was cleaned up.

## Operator-defined destination — improve the existing \`/setup/locate/\` screen

**#230 is the application editor. #171 supplies its maintained spatial, power and network reference semantics.** Use the current aerial, map navigation, search, layers, selected equipment popups, and cable investigation UI as the front end, extended by role-governed editor commands rather than a competing viewer. Keep Setup's movement semantics (#88) separate.

### Permanent reference editing (Manager; #230)

- Select a waypoint on this map; see canonical **ExpertGPS Label-on-Map** identity, type/icon, coordinates, source history, verified state and audit; create new waypoint, rename/edit alias, correct coordinates, and retire/reference track as separately authorized actions.
- Geometry editing must respect **NAD83 HARN WISCRS Sheboygan County Feet / EPSG:8158**, transform for browser WGS84 and record source/fix uncertainty. Do not treat smartphone observations, drawing symbol movement, or schematic coordinates as an automatic replacement for curated survey/GPX source.
- Field contributions can be staged as **review required**. Show the before/after and who/when, preserve prior values, and detect GPX ↔ DB concurrent changes; no silent last-write-wins or duplicate permanent identity.

### Power panel / breaker / outlet relationships (authorized Production crew; #171/#230)

These requirements already exist in the GIS README's *Required panel, circuit and seasonal power records* and its 2026-10-10 permission clarification. They have **not** been implemented by the current #319 candidate schema.

- Open an existing panel waypoint (e.g., \`A5-00\`), identify the actual panel/meter/owner, add breaker/circuit identifiers **scoped to that panel**, supporting labels, applicable ratings and provenance.
- Choose a circuit, link it to one or many **existing outlet/OUT-Combo waypoints** and downstream loads, including intermediate fuse/disconnect where documented. Clicking an outlet reveals its supplying panel + breaker, and clicking a breaker lists all its attached waypoints.
- A Production crew user may identify/maintain circuit information and link **existing** waypoints; this is **not** authorization to rename or move waypoint identities/coordinates. Do not infer electrical feeds from spatial proximity, network tests or diagram geometry.
- Include source, uncertainty, verified/unverified state, actor/time and change history. Seasonal power-switching tasks and “turned off” evidence remain #122 operational facts—not permanent GIS topology or proof of de-energization.

### Networks, testers, tracks (investigate, then maintain reviewed facts)

- An OUT-Combo may belong to **multiple network designations**; a network covers multiple locations. Show both memberships alongside the **separate electrical circuit**. Name ambiguity and incomplete topology stay unresolved until reviewed.
- Inspect LinkIQ cable UUID/test history, edited \`Records.CableId\` versus embedded original tester name, endpoints and measured length; identify **unique physical cable IDs** without conflating repeated tests/project appearances with independent cables or assuming qualified standard = live link speed.
- Link reviewed physical cables to waypoint endpoints, GPX tracks, network(s) or SPARE designation, and schematic object IDs. Preserve separate parallel cables, destroyed/replaced/historical traces and route alternatives.
- Keep three authorities distinct: GPX = waypoint positions/routes, LinkIQ = cable test evidence, draw.io = schematic topology/presentation evidence. Surface conflicting endpoints, unmapped routes and source age/hash on the *existing* network details UI. The versioned JSON file is **not** an approved DB import.

## Offline map requirement — **mandatory**, not optional reconnaissance

Park Wi‑Fi is **not available throughout Evergreen Park**. Reading known waypoint locations, searching names and inspecting reference tracks **must work after the user has intentionally prepared the device while connected**, including a full app restart without internet. Offline usability must not depend on browser disk cache accidents.

1. **Versioned offline package for this map:** package the permitted 2019 orthophoto tiles covering the actual park and appropriate field zoom levels, Leaflet JS/CSS locally (no CDN dependency), all used marker icons, 233-waypoint/181-track reference geometry and lookup index, reviewed network/cable/circuit reference projections and metadata. Estimate tile count/storage per chosen zoom boundary; respect source rights and device storage; do not blindly cache an unbounded tile service.
2. **Field installation/update:** a pre-season / pre-field “Download or refresh offline park map” action, clear progress/storage-size indication, version/hash and last-successful-sync time. Atomic replacement; do not leave a partially fetched map presented as complete. Clearly indicate **online current / offline dated snapshot / incomplete package**.
3. **Read-only first:** while disconnected, pan/zoom the actual park imagery; search a waypoint; inspect named GPX network/HV tracks and panels/outlets with their last downloaded relationships; show source/version/time and absence of current asset truth. Device geolocation may be shown when permitted, with accuracy in feet and fresh/stale fix handling. Do not invent current Containers/Displays from expired #88 API data.
4. **Offline edit policy must be explicit:** no silent reference or Production mutation; if offline edits are introduced, queue attributed proposals with stable IDs, baseline versions and source evidence, validate on reconnect, reject conflicting writes for review, and enforce server-side Manager/crew permissions. **No last-write-wins or automatic source promotion**. Online editor actions can be delivered first while offline remains guaranteed for reference lookup.
5. **Security/runtime:** design cache scope for authenticated Setup/Access; avoid copying personal or current movement data into a permanent public cache. Because current \`/locate/\` is served \`no-store\`, offline handling needs its own approved asset-manifest/service-worker policy rather than overriding global application caching. Review Service Worker ownership with existing \`/record-location/\` scope. Field testing requires a supported rugged Android tablet, park/network dead-zone simulation, airplane mode/reload, tiles/icons/search and version updates. A desktop browser rendering once does **not** demonstrate offline readiness.

## Minimal staged acceptance using the existing UI

1. **Current-state inventory and preview:** screenshot and code references above are baseline. Show current source version and classification in the existing map UI. Do not create yet another parallel map/waypoint finder.
2. **Visual DB proof:** import source evidence into a governed disposable database, **repeat import**, then show browser counts and unresolved list versus source manifest. Distinguish staged source rows from promoted permanent waypoint/cable/panel/circuit records. No duplicate UUID, overwritten corrected label or false matched cable.
3. **Manager map editing:** select \`A5-Church\` or other safe test waypoint on disposable clone; edit approved metadata/location; show map update, exact audit and GPX export conflict handling. Never mutate shared GPX or Production for a test.
4. **Crew circuit editing:** create an example test panel/breaker and attach multiple existing test outlets; verify click-through in both directions and permission denial for crew coordinate editing. Use disposable examples rather than invent actual A5-00/FE-00 wiring.
5. **Networks:** inspect a conflicting/unmatched LinkIQ/GPX segment; classify only after reviewed evidence; show assigned network members, physical cable ID/history, source age/hash and unknowns.
6. **Offline:** download bounded map package while online; disconnect; reload the existing map, search, pan, inspect GPX tracks and circuit information; reconnect and refresh with explicit review/permissions. Do not depend on Wi‑Fi throughout park.
7. Browser/editor acceptance should **not trigger a second Production dump merely to preview a UI**. Reuse a governed persistent disposable snapshot/environment where explicitly supported; previous candidate acceptance clone/dump was cleaned up. Keep #122 runbook and Production authorization separate.

**Not completed:** #230 editor/API, real full-source DB ingestion and promotion, panel/breaker/waypoint/network maintained relationships, offline package/cache, actual tablet offline proof, operator visual browser acceptance, and Production deployment. **Do not treat a clean SQL migration test as fulfillment of these requirements.**
