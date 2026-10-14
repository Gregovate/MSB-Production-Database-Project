# #171 — Garmin GPS symbol association audit (October 14, 2026)

| Control | Value |
| --- | --- |
| Owner | Site Infrastructure / GIS, Issue #171 |
| Status | VERIFIED SOURCE INVENTORY; physical device mapping acceptance pending |
| Source | Operator-uploaded Garmin/CustomSymbols ZIP copied via USB; original ExpertGPS SendToGPS_10_13_2026_2_46_28_PM.GPX |
| Scope | Read-only icon name/candidate association, not firmware load proof |

## Primary finding

ExpertGPS's waypoint Type and PC Bitmap Map Marker are NOT what the GPSMAP necessarily uses to choose device artwork. The transfer GPX contains 235 waypoints and 19 different literal GPS sym values. The Garmin USB CustomSymbols snapshot has 23 BMP images, 20 numbered PNG files and one nested ZIP, for 44 entries total. The archive contains both stock-name references in GPX and locally stored custom artwork; its mere presence does NOT establish which image firmware chose.

A case-insensitive filename-stem comparison between the 19 outgoing GPX sym values and the named BMPs yielded only THREE custom-image candidate names: PANEL matching Panel.bmp, Outlet_Combo matching Outlet_Combo.bmp, and Outlet_Network matching Outlet_Network.bmp. Case-insensitive comparison is investigative only; actual firmware matching rules still need physical verification.

## Key concrete discrepancies

| Type | Outgoing GPX sym | Count in 235-waypoint send | Matched named device BMP |
| --- | --- | ---: | --- |
| OUT-Combo | Navaid, Red/White | 83 | None; potential stock symbol, not Outlet_Combo.bmp |
| Panel | Block, Red | 9 | None; stock-looking name |
| Panel | PANEL | 8 | Panel.bmp (case difference) |
| Outlet Power | Navaid, Red | 7 | None; stock-looking name |
| Outlet Power | Outlet_Combo | 5 | Outlet_Combo.bmp |
| Outlet Power | Outlet_Network | 1 | Outlet_Network.bmp |
| Outlet Power | PANEL | 1 | Panel.bmp (case difference) |
| Outlet Power | Navaid, Red/White | 1 | None |
| Stage | Stadium | 33 | None; stock-looking name |

The literal GPX names are observations, not proof which firmware stock/custom symbols appeared. The outgoing mapping of Type OUT-Combo to Garmin Outlet_Combo is an existing separately approved engineering decision, not an authorization to silently rewrite official GPX. In particular, a type-to-sym blanket replacement could destroy intended historical exceptions.

## Inventory details

The physical Garmin ZIP contains 23 BMP files; most are 24-bit RGB, while Stage.bmp and numbered 021.bmp are 32-bit RGBA duplicates. The 20 numbered PNG files are not proof of 20 device-usable custom icons. Several named BMPs have dimensions other than 24 x 24; image existence, exact case, format, size, and actual firmware behavior need independent verification. Stock symbols are part of Garmin firmware and are not contained in this ZIP.

## Reconnaissance next steps

1. Preserve original uploaded SendToGPS file, device CustomSymbols ZIP and dated master GPX snapshots separately.
2. Produce a full Type / per-waypoint sym / PC marker / candidate device filename report from GPX + Symbol Library. Preserve unique waypoint names and exceptions.
3. Confirm the Garmin menu's actual rendered icon for a small representative set, including one PANEL and one Block, Red Panel, OUT-Combo and Outlet Power. A file-stem match alone is insufficient.
4. Only then approve outgoing sym mapping changes for future Garmin transfer via a reviewed disposable waypoint-only GPX; compare all names/locations/Types before and after.
5. Keep authenticated #319 source ingestion and physical Garmin symbol release distinct. Do not alter original master GPX, Garmin files or live map as an audit shortcut.

## Cross-reference
- [GIS Symbol Management](GIS_Symbol_Management.md) — engineering authority for artwork, ExpertGPS and approved compatibility.
- [Garmin Field Survey Workflow](Garmin_Field_Survey_Workflow.md) — field track recording and operator handoff.


## October 14 corrected waypoint-only Garmin candidate

Operator explicitly directs aligning the master waypoint **outgoing GPS symbols** to the installed MSB custom icons rather than collecting more isolated stock-icon observations. This is not permission to modify the authoritative GPX without reviewed acceptance.

Actual master GPX SHA-256: `1594ce1f96c1df8f6751e0d436a99acc824a95274768c2f1b1160376175943fd`. Prepared read-only-derived candidate `MSB-Garmin-Waypoint-Symbols-REVIEW-20261014.gpx` with SHA-256 `96ad2b3111c9852e9ab983d446a750b4bfb825c0ffbfb1215ce90fddc57cf298`. Changed **only** 93 per-waypoint `sym` text elements: nine `Panel` `Block, Red` to `PANEL`, and 84 `OUT-Combo` `Navaid, Red/White` to `Outlet_Combo`. All other XML elements and attributes (including names, Types, map marker URLs, coordinates, all track geometry and metadata) were verified exactly equal after suppressing the candidate `sym` text. No file sent to Garmin and no shared master modified. The candidate requires explicit engineering review before field use.

Compared the 37 approved ExpertGPS PNG basenames from YOGA-GREG's documented proposal with the actual named Garmin BMP files using normalized spelling/hyphens/underscores. Only **14** directly match in this heuristic; **23** do not. These 23 are **unresolved mapping/provisioning candidates, not 23 proven missing icons**: some refer to alias names, different artwork categories, or symbols not needed on Garmin. Full inventory/report produced as `MSB-Garmin-Symbol-Library-Gaps-20261014.csv`. Garmin inventory includes 23 BMP files and 20 numbered PNG images plus a nested ZIP. Determine which artwork is required for field waypoints before producing a device-compatible BMP package; retain exact existing case/legacy aliases and verify real GPSMAP rendering. Next Type mappings such as Outlet Power to an intended red pin require operator-approved device identifier, not an invented name.

