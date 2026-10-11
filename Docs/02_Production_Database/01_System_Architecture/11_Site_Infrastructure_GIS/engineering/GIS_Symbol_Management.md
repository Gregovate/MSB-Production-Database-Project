# MSB GIS Symbol Creation, Publication, and Compatibility

| Document control | Value |
| --- | --- |
| Status | CURRENT engineering/source-maintenance contract (runtime adoption remains separately gated) |
| Owner | Site Infrastructure / GIS, Issue [#171](https://github.com/Gregovate/MSB-Production-Database-Project/issues/171) |
| Recorded | 2026-10-11, capturing operator-confirmed October 9–11 decisions |
| Related ownership | #230 reference editor/type registry; #88 Container movement/load evidence; #175 Task Cover Sheet consumer |
| Subject | SVG masters, Plain SVG export, ExpertGPS PNG derivative, legacy symbol compatibility, web publication |

## Authoritative directories and copy ownership

These are **operator-confirmed existing locations**, not proposed folders:

| Location | Purpose / source status |
| --- | --- |
| `G:\Shared drives\Display Folders\Park Drawings\MSB GIS\Symbols\Masters` | **Editable Inkscape master artwork**. Edit here; do not edit the published web copies. |
| `G:\Shared drives\Display Folders\Park Drawings\MSB GIS\Symbols\Plain` | **Approved exported Plain SVG artwork**, derived from the editable masters; canonical source for GIS/browser artwork and PNG generation. |
| `G:\Shared drives\Display Folders\Park Drawings\MSB GIS\Symbols\png` | **New operator-required canonical PNG derivative folder.** Content/synchronization not yet inventoried; the #334 exporter stages to Downloads rather than writing here. |
| `\\192.168.5.4\webassets\images\symbols\msb-svg\` | Published **new Plain SVG** files (the operator confirmed the folder contains them). |
| `\\192.168.5.4\webassets\images\symbols\msb\` | Existing **legacy-named PNG and BMP** compatibility files. Preserve them; new PNG names may coexist during a controlled changeover. |
| `%LOCALAPPDATA%\TopoGrafix\Symbols\msb\` | **Confirmed current ExpertGPS PNG + `readme.txt` location** on each Windows PC/user. `%LOCALAPPDATA%` resolves under that user's profile; one observed example is `C:\Users\greg\AppData\Local\TopoGrafix\Symbols\msb\`. Do not hardcode the username. |
| `G:\Shared drives\Display Folders\Park Drawings\GPS Data\Custom Waypoint Symbols\Master Icons` | Older/legacy artwork reference reported previously; **not** the new canonical editing location. Retain as provenance until reviewed. |

Web URL bases corresponding to the confirmed Synology shares:

- New SVG: `https://webassets.sheboyganlights.org/images/symbols/msb-svg/`
- Existing PNG/BMP: `https://webassets.sheboyganlights.org/images/symbols/msb/`

The operator opened `https://webassets.sheboyganlights.org/images/symbols/msb-svg/container-loaded.svg` and saw the green Container icon. **This verifies that one SVG URL**, not automatic publication validation for every item. Published web assets are derivatives; artwork maintenance starts from `Masters` then `Plain`.

## ExpertGPS folder identity, portable installation and custom-symbol URL — October 11 confirmation

The operator's current ExpertGPS symbol folders include **`msb`**, **`MSB Icons`**, `Orienteering`, `paddle`, `pushpin`, and `shapes` (October 11 screenshot). The existing MSB symbols are under `msb`, even though `MSB Icons` would be a cleaner human-facing name. The folders accumulated during approximately five years of ExpertGPS use; their layout must be treated as an existing compatibility constraint rather than reorganized casually. **Keep `msb` active**; do not move the symbol files to `MSB Icons` until GPX references, ExpertGPS type assignments, old URL aliases, and published links have been inventoried and verified.

Use the Windows-user-independent location on each computer:

```text
%LOCALAPPDATA%\TopoGrafix\Symbols\msb\
```

One observed local path is `C:\Users\greg\AppData\Local\TopoGrafix\Symbols\msb\`; the `greg` user string must not be hardcoded in instructions or automation.

The operator supplied the **current** `readme.txt` with SHA-256 `69115edd6b8dcf97db836179e014c9221e0f8eba62033703e35b1411a18e9b59`. Its first line is exactly:

```text
https://webassets.sheboyganlights.org/images/symbols/
```

The subsequent ExpertGPS explanation in that file says its generated custom-marker URL uses this **parent URL** and the current **symbol folder name**. Therefore a PNG in `Symbols\msb\` is intended to resolve as:

```text
https://webassets.sheboyganlights.org/images/symbols/msb/container-loaded.png
```

**Do not add `msb/` to the first readme line**. The symbol folder is already added by ExpertGPS; including it in the parent URL could produce a doubled directory. This is supported by the supplied readme instructions, **not independently verified against a fresh ExpertGPS export**.

### Safe per-PC install and corresponding Synology publication

1. Close ExpertGPS. Resolve the existing `%LOCALAPPDATA%\TopoGrafix\Symbols\msb\` for the current Windows user. Back up that entire folder, including existing PNGs, BMPs and `readme.txt`.
2. Extract `MSB_ExpertGPS_msb_Install_2026-10-11.zip` into a staging directory. Its `msb/` directory contains 31 RGBA PNGs with the intentionally different SVG source dimensions and an **unaltered copy** of the operator-supplied `readme.txt`. Its outer files include a SHA-256/dimension inventory and installation instructions.
3. **Merge** the contents of the staged `msb/` directory into the existing local `msb` folder. Review same-name replacement before overwriting; **never delete or replace the entire legacy folder** or its other symbols. Do not modify sibling `MSB Icons`, `Orienteering`, `paddle`, `pushpin` or `shapes` directories.
4. Merge the same new PNGs into the *existing* web path `\\192.168.5.4\webassets\images\symbols\msb\`, preserving other legacy-named PNG/BMP assets and URLs. Continue to publish Plain SVGs separately to `msb-svg`.
5. Check the uploaded PNG URLs, existing older symbol URLs, and current ExpertGPS waypoints. Verify a fresh exported GPX/KML marker URL, including folder name, spelling and letter case, on a real ExpertGPS installation before claiming migration compatibility.
6. Do **not** move to `MSB Icons` as cosmetic cleanup until an explicit alias/type/URL migration is planned, accepted, and backward tested. Such a move could change ExpertGPS type or folder-relative references and published GPX URLs.

Historical snapshot (not certified current): conversation-stage install ZIP `MSB_ExpertGPS_msb_Install_2026-10-11.zip`, SHA-256 `1608aee54573aa081d2b6d25aed8768e5d8b6bdef1f9158c5400338cac534e5e`. Package validation passed: 31 PNGs, all RGBA and dimensions matching corrected Plain SVGs; complete ZIP integrity; `readme.txt` bytes match the supplied file. The package was handed off in chat; **its filename is not evidence that the ZIP itself was committed to GitHub or copied to the user's PC or Synology**. It was generated from an uploaded snapshot, **not from a fresh scan of the current Shared Drive Plain files**. Regenerate using the exporter above before installing. The operator must confirm actual installation and web publishing.

Old ExpertGPS type keys and GPX custom-marker URLs may reference case-sensitive legacy names even though new generated artwork is lowercase. New PNG creation alone does not remap those keys. Preserve legacy assets until a reviewed source/type/URL compatibility mapping and ExpertGPS round-trip test are complete.

## Current-Plain-to-ExpertGPS release gate — correction, October 11

**Do not install the previous October 9/11 PNG ZIP as a verified current release.** Those 31 PNGs were generated from a **conversation-uploaded SVG ZIP snapshot**, not by re-reading the operator's maintained `G:\Shared drives\Display Folders\Park Drawings\MSB GIS\Symbols\Plain` folder after the artwork/folder changes. Matching the earlier ZIP does not prove those icons remain identical to the current source-of-truth files. The previously packaged `readme.txt` was valid, but correct URL metadata alone does not fix stale raster artwork.

The missing step is a **fresh, on-PC export from the actual current Plain SVG folder**, followed by reviewed local ExpertGPS and Synology PNG installation. No assistant connected to GitHub or a chat-uploaded ZIP has direct access to the operator's Google Shared Drive or local `%LOCALAPPDATA%` tree.

The repository now provides [Export-ExpertGPSSymbols.ps1](../../../../../Database/EngineeringTools/Export-ExpertGPSSymbols.ps1). Its purpose is to complete the missing reproducible source-to-raster stage, **not** to overwrite existing icons or deploy to the web server:

```powershell
# Run on the Windows PC where G: and Inkscape are available,
# from the project repository checkout:
& .\Database\EngineeringTools\Export-ExpertGPSSymbols.ps1
```

The script reads the current `Symbols\Plain` path, validates lower-case hyphenated filenames and the existing local ExpertGPS `readme.txt` parent URL, invokes Inkscape without overriding each SVG's deliberately chosen canvas size, checks RGBA PNGs, records per-file source and output SHA-256 plus width/height in a CSV, and stages an install ZIP in a uniquely named Downloads directory. It **does not** mutate Plain SVGs, the installed `Symbols\msb` folder, Synology, GPX or database records. If either source directory, the readme, or Inkscape has moved again, pass its actual location explicitly (`-PlainSvgDirectory`, `-ReadmePath` or `-InkscapeExecutable`) rather than silently using stale copies.

Only **after comparing the staged inventory against current Plain files and reviewing the symbols** should the PNGs be merged into the backed-up local `%LOCALAPPDATA%\TopoGrafix\Symbols\msb\` folder, and then published to the matching web `msb` path under the governing server procedure. Preserve all old-named icons/BMPs and the original root-URL readme; never rename the folder to `MSB Icons` in this release. Verify ExpertGPS icon rendering and a fresh GPX export URL before marking it installed. The October 9 inventory remains useful as a historical comparison, not an automatic current-release manifest.

**Current disposition:** export script prepared in repository; **no runtime test on the operator's Windows G: folder, no current PNG rebuild there, and no PC/Synology deployment has been performed**. Operator must execute the source-directory export or provide a fresh ZIP of the exact current Plain SVG directory for an off-PC export.

## Historical scattered SVGs and current exporter block — inspected October 11

Greg reports several previous icon-organization attempts, and identifies the **existing** `G:\Shared drives\Display Folders\Park Drawings\MSB GIS\Symbols\Masters` folder as his chosen permanent **editable Inkscape master** location. The current local files there and under `Plain` have not yet been inspected directly. Do **not** assume historical `-inkscape.svg` naming, directory placement, or a prior SVG ZIP is correct source authority.

Read-only uploaded historical library inventory:

- `icon_library (2).zip`, SHA-256 `1239b9ada1b18100804136a4a4bbf9a9d2d77e7674fb25d2f0396b409b4dc26d`: **41 SVGs** (20 in `icon_library/inkscape-masters/`, 21 in its outer `icon_library/`), **21 PNGs**, **22 BMPs**, one XCF and a Windows `desktop.ini`. All 20 `inkscape-masters` SVGs contain detectable Inkscape/Sodipodi editing metadata; 20/21 outer SVGs lack those markers, but **`LP.svg` in the outer folder still contains Inkscape metadata**. Thus filename/folder are not reliable format classifiers. Three historic suffix typos appear: `LP_Power-inscape.svg`, `IP-camera-inskape.svg`, `Stage-inksccape.svg`. Preserve these as historical originals pending review. A master named `LP_Power-inscape.svg` is present, but there is no directly corresponding `LP_Power.svg` in the root of the uploaded archive; do not invent a missing pair or conflate that icon with a different power outlet.
- Comparing these outer old SVGs to the **earlier** 31-file corrected Plain SVG ZIP by case/underscore/hyphen-insensitive candidate filename: **14 name matches**, of which 12 are byte-identical; `Stage.svg` and `T-Post.svg` differ in bytes. The newer T-Post canvas is 16 × 32 versus 32 × 32 in the older ZIP. This indicates revisions, not automatically a defect or visual mismatch. These are historical upload comparisons, **not** today’s G: comparison.
- `LOR Library.xml`, SHA-256 `559845661eebd2e7678d4d2452a821c6c65e31ffe5b1d52d934e9f6181074b33`, valid draw.io `mxlibrary`: **23 entries** (five embedded PNG image entries, 18 entries with draw.io graph XML). LOR controller/component schematic symbols are **not necessarily waypoint/GIS icon masters**. The XML library is itself an embedded presentation source; inventory/report it separately and do not replace it simply because a similarly named GIS Plain SVG exists.
- Greg ran `Export-ExpertGPSSymbols.ps1` on laptop `C:\lor\ImportExport\VSCode` after updating to main `c46b7d1e`; it stopped at line 52 on **`msb-splitter-Combiner.svg`** in the current G: `Plain` folder. This is a direct observed filename inconsistency with approved `msb-splitter-combiner.svg`. **Do not blindly rename it or bypass the exporter’s guard:** first reconcile copies, ExpertGPS type links, GPX URLs and web/draw.io references. The script did not complete a current PNG export.

### Read-only laptop inventory and reliable SVG classification

Use the repository-standard-library Python utility [inventory_gis_symbols.py](../../../../../Database/EngineeringTools/inventory_gis_symbols.py). Run on the laptop from the **updated** primary repository (`C:\lor\ImportExport\VSCode`; exact startup path may vary by workstation):

```powershell
python .\Database\EngineeringTools\inventory_gis_symbols.py
```

The utility checks SVGs recursively under `Park Drawings`, output PNGs under canonical `Symbols\png`, and installed raster/SVG copies under the current user’s `%LOCALAPPDATA%\TopoGrafix\Symbols`. It accepts repeatable `--extra-root` directories for additional known scattered sources, `--archive` historical ZIPs and `--library` draw.io symbol libraries. It writes **only** to a new timestamped Downloads report directory (CSV inventory, CSV review findings and summary text). It does **not** copy, delete, rename, convert, publish or edit sources.

Classification logic: parse SVG XML and count Inkscape/Sodipodi namespaced elements/attributes. `INKSCAPE_METADATA_PRESENT` means editor-specific metadata **is retained**. `PLAIN_LIKE_NO_EDITOR_METADATA` means those markers are absent, but does **not** prove a file was actually exported using Inkscape “Plain SVG”, nor does it prove the vector shapes cannot be edited. `INVALID_SVG` needs inspection. Report all source hashes, viewBox, title, user-selected dimensions, path roles, noncanonical filenames, name-possible master/Plain gaps and multiple revisions for operator adjudication. File-content hashes do not guarantee visual equivalence.

The master promotion decision comes **after** this report: compare candidate original/editable SVGs and plain derivatives visually and by provenance, select a reviewed master per logical icon, stage missing masters rather than overwrite, export approved Plain copies, generate reviewed PNG derivatives into `Symbols\png`, and only then publish/test independent ExpertGPS, web-browser and draw.io copies.

## First live laptop SVG inventory — 2026-10-11 05:08 local

**Read-only inventory completed; source reconciliation and publishing remain pending.** Greg ran `python .\Database\EngineeringTools\inventory_gis_symbols.py` on laptop `C:\lor\ImportExport\VSCode`. It created `C:\Users\greg\Downloads\MSB-GIS-Symbol-Inventory-20261011-050843` and reported **454 files and 54 review flags**. Files were not copied, renamed, converted, deleted or published.

Uploaded evidence files and SHA-256 digests (reports are conversation artifacts, not yet installed in this repo):

| Report | SHA-256 |
| --- | --- |
| `summary.txt` | `2f5568864965fac2ea5e2abdfe69d33b70ff54fa458d069d5883fba651e12701` |
| `svg_and_raster_inventory.csv` | `12d63e6f74bfb6a8d0b5a95d1aeee873e7be38d455f2b6028966852ed26ebd13` |
| `review_required.csv` | `096f05d1f036db8a42f16cd7d421266bfbc07d5b8afeeec5f37f9ed952006994` |

### Inventory categories

| Category | Files | Interpretation |
| --- | ---: | --- |
| Chosen `Symbols\Masters` | 32 SVG | **All 32 retain Inkscape/Sodipodi editing metadata** |
| Chosen `Symbols\Plain` | 31 SVG | 28 lack editing metadata (Plain-like); **3 retain it** |
| Scattered under Park Drawings | 109 SVG | 72 editing-metadata, 35 Plain-like, **2 malformed XML** |
| Current-user ExpertGPS | 282 PNG | `paddle` 124; `shapes` 103; `msb` 26; `MSB Icons` 17; `pushpin` 8; `Orienteering` 4 |
| New canonical `Symbols\png` | **0 inventoried PNG/SVG/BMP** | Not synchronized; the scan does not speak to other extension types |

The **54 review flags** break down to 41 multiple-SVG-raw-byte-revisions, 4 Masters without name-matched Plain, 3 Plain without name-matched Masters, 3 Plain retaining editor metadata, 2 invalid historical XML, and 1 mixed-case Plain filename. **41 hash differences are not 41 proven image defects**: native editable and exported Plain SVGs often have different XML bytes. The 28 normal name-matched Master/Plain pairs have matching dimensions but different file hashes; geometry/visual equality has **not** been verified. Filename/date/hash alone must not select authoritative artwork.

### Priority source and identity review

| Current files | Evidence and required disposition |
| --- | --- |
| `Plain\car-r.svg`, `Plain\lp.svg`, `Plain\manhole.svg` | Retain native editing metadata; compare with selected Masters, then make reviewed staged Plain exports |
| `Plain\msb-splitter-Combiner.svg` | Noncanonical uppercase `C` triggered `Export-ExpertGPSSymbols.ps1` safety gate; investigate old ExpertGPS/web/draw.io URLs before approving canonical `msb-splitter-combiner.svg` |
| `Masters\lor-reprater-inkscape.svg` vs `Plain\lor-repeater.svg` | Likely one icon with misspelled master name: both titles `LOR Repeater` and 24 × 24 dimensions. Verify content before adopting alias/migration |
| `Plain\lp-network.svg` | **Operator-confirmed derived export** from the **LP-Combo Inkscape master**, with selected master layers turned off. The matching-name-only inventory falsely labels it masterless; retain the output and record its layer preset before regenerating. Historical `Network\icon_library\LP_Network.svg` is byte-identical to the current Plain copy. |
| `Plain\lp-outlet.svg` | **Operator-confirmed derived export** from the **LP-Combo Inkscape master** with selected layers turned off. Operator says **`lp-outlet` and `lp-power` depict the same icon** and wants one redundant designation eliminated. Current `Plain` inventory has `lp-outlet.svg`, not a separate `lp-power.svg`; historical `Network\icon_library\LP_Outlet.svg` is byte-identical. Preserve alias/URL/type compatibility before retiring a name. |
| `Masters\lp-power-inscape.svg` | An existing extra/legacy master-like file. **Do not assume it remains the generation source** of `lp-outlet.svg`: operator identifies LP-Combo as the shared editable master. Keep this historical variant until direct visual/content review confirms whether it can be archived. |
| `Masters\stage-32x32-inkscape.svg`, `Masters\star-inksccape.svg` | Extra master candidates without name-matched Plain; `star` has title `Stage`. Retain until possible older Stage variants are reviewed |
| `2023 Upgrade\2023 Updates.svg` and `2023 Updates23-10-17.svg` | XML parser reports unbound namespace prefixes; outside current chosen canonical directories |

The current installed ExpertGPS `msb` folder includes **26 older-named PNGs**, not a verified installed copy of the 31 approved lower-case icons. `MSB Icons` is a different 17-PNG collection. Do not delete either folder or rename references until older GPX/URL compatibility has been inventoried.

### Corrected LP-Combo master-to-export lineage — operator confirmation, October 11

The operator clarified that **one editable Inkscape master, `Masters\lp-combo-inkscape.svg`, contains multiple layers**. By selectively hiding layers, the operator created separate approved Plain SVG presentations, including `lp-network.svg` and the outlet/power presentation; `lp-combo.svg` is also present in the current Plain inventory. The absence of a same-basename master for `lp-network` and `lp-outlet` is **expected** and must not be treated as evidence that the editable sources are missing.

This is a **one-master-to-many-exports relationship**, not an error to repair by duplicating masters. The current filename-based scanner reported `NO_MATCHING_MASTER_NAME` for some valid multi-layer exports because its provisional matching algorithm only understands names. A future export manifest should record the master path/hash, output filename, **exact intended layer visibility state** (to be inspected from actual master), canvas, and output hash; a master edit alone must not silently regenerate public or ExpertGPS symbols.

**Operator duplicate declaration:** `lp-outlet` and `lp-power` represent the **same icon appearance** and one duplicate designation should ultimately be retired. The present live file inventory found `Plain\lp-outlet.svg` but no `Plain\lp-power.svg`; `Masters\lp-power-inscape.svg` is a separate historic file to inspect, not authority to publish a second visually identical icon. Before deletion/rename, inspect GPX/ExpertGPS custom symbols, case-sensitive web URLs, draw.io library entries, embedded schematic images, and map mapping; choose **one canonical derivative name** with operator approval and preserve any required old-name aliases. The currently existing `lp-outlet.svg` is a practical candidate, **not a final user-approved canonical choice**. No source file, icon, or path was deleted, renamed, converted, or published by this correction.

### Next acceptance step

Review actual SVG bytes and visually compare the chosen 32 Masters / 31 Plain files; record the confirmed LP-Combo layer-to-export lineage and review the redundant `lp-outlet`/`lp-power` naming against existing references, plus LOR typo, three editor-containing Plain files, mixed-case Splitter and Stage alternatives. Preserve all originals. Only after approval, regenerate corrected Plain SVGs, PNG derivatives into staging and approved `Symbols\png`, then independently review ExpertGPS, public SVG/PNG URLs and draw.io library/schematic artwork. The scan did not access all PCs, all historical archives, actual website assets or every embedded drawing icon.

**No PNG export, ExpertGPS/Synology installation, browser asset promotion, draw.io update, schema or Production change is authorized by this inventory.**

## draw.io symbol library and schematic independence — operator confirmation, October 11

The operator's current paths are:

- Custom draw.io library: `G:\Shared drives\Display Folders\Park Drawings\Network\MSB-icon-library.xml`. This XML **can be stored elsewhere**; the path is where the operator currently keeps it, not a required draw.io runtime path.
- Active schematic: `G:\Shared drives\Display Folders\Park Drawings\Network\Park Network Schematic 2026.drawio`.

draw.io library XML can contain **embedded SVG data**, and schematic objects can contain their own independent embedded icon payloads. Updating a source Plain SVG, regenerating the library XML, or replacing a PNG does **not** automatically update already-placed icons in the schematic. This creates a separate synchronization and controlled diagram-migration boundary. Preserve all diagram object IDs, geometry, topology, cable metadata and drawing layout; do not bulk-replace artwork without an identity-by-identity review and actual draw.io open/visual acceptance.

Read-only inspection of **operator-uploaded copies** on October 11, not the live G: versions:

| Uploaded artifact | SHA-256 | Evidence |
| --- | --- | --- |
| `MSB-icon-library.xml` | `a767246bd36f72f2642c9f819ba096e07d804e8bfe3d8646957d016713908d59` | Valid mxlibrary JSON with **20** icons: 18 direct base64 SVG entries and 2 XML-wrapped symbols; legacy titles include `LOR Repater`. |
| `Park Network Schematic 2026(20261011-093142).drawio` | `65d7607485e526e4d058b4ce997a24f2fe53a731b4f52817dcd44233e420a0a8` | One page, 743 mxCell elements, **199 embedded image references** (196 SVG, 3 PNG), **32 unique image payloads**; no external HTTP image URLs in `image=` cell styles. |
| Prior corrected `msb-plain-icons-corrected.zip` | `eba2ab74bbc7430b024fbde8e22bc220c7e856821aff4714667a0092ef9fe34c` | 31 Plain SVGs in the prior uploaded snapshot. **Not** a live-G:-folder inventory or authoritative current revision. |

Some library titles correspond to the earlier Plain names, but embedded SVG bytes and canvas sizes differ. **Raw byte inequality alone does not establish a visual change**: exports can reserialize and transform SVGs. A geometry/style-aware visual comparison and operator disposition are needed. Also, the 20 library entries and 32 unique schematic payloads are *not* a demonstrated one-to-one match; do not assume the schematic uses only those 20 entries.

### Reconciliation and release sequence — pending

1. **Read-only inventory** of scattered local/shared SVG files, including current `Masters`, `Plain`, `png`, legacy artwork folders, ExpertGPS symbols, the draw.io library and its installed/embedded schematic images. Record full paths, file hashes, dimensions where applicable, last-write dates and aliases. Scan additional roots explicitly; do not silently claim all local drives were covered.
2. Identify missing/duplicate/renamed or divergent Inkscape masters and approved Plain derivatives. Require operator review before selecting an authoritative revision or moving anything into `Masters`. Never overwrite an existing master based only on filename or timestamp.
3. After approved Plain SVG inventory, compare intended output and existing `Symbols\png` derivatives by source/output manifest. The current exporter stages into Downloads, not the canonical `png` directory; add an explicitly approved promotion step only after source and output validation.
4. Check ExpertGPS type/legacy-URL dependencies and review web SVG/PNG delivery independently. The Browser map must not be silently changed by local ExpertGPS editing; generated web assets remain controlled published derivatives. Preserve legacy files and version/publish deliberately.
5. Rebuild/reconcile the draw.io XML library **as a separate derivative** from approved Plain SVGs, preserving reviewed titles and internal library identity. The existing schematic stores embedded artwork: any icon refresh in that document must be a separately reviewed change, with an unchanged object-ID/geometry/cable-attribute comparison and draw.io visual acceptance.
6. Keep a release manifest of selected master + Plain SVG + PNG + published SVG/PNG + draw.io library/schematic artifact hashes and known alias references. Only approved versions promote; local edits alone never automatically rewrite web/browser or source schematics.

Issue #171 owns this icon/inventory reconciliation; #319 owns network cable data. No file or source migration, Production mutation or web deployment was performed by this inspection.

## Repeatable maintenance and publication workflow

1. **Edit** the relevant master in Inkscape under `Masters`; retain the editable original.
2. **Export/Save a Copy as Plain SVG** into `Plain` with the approved lowercase, hyphen-separated filename. Preserve each icon's deliberately chosen document dimensions, `viewBox` and aspect ratio; no forced universal 32 × 32 resize.
3. **Validate** the resulting SVG file parses and visually renders; inspect intended dimensions and transparency. Compare renamed/missing/added files against the 31-file baseline below. Use a new reviewed baseline when artwork changes.
4. **Publish SVGs** from `Plain` to the existing `msb-svg` share using unchanged filenames, then check browser URLs, rendering, and case-sensitive path spelling. No GPX/device identity is renamed by this artwork operation.
5. **Generate ExpertGPS PNGs** from the approved Plain SVGs into a **separate staging/export folder**, preserving each individual canvas size and transparent background. Do not modify SVGs to satisfy a raster export.
6. **Review the PNG set** (count, filename, width/height, RGBA/alpha, and representative appearance) before installing copies in the TopoGrafix folder and publishing new PNG files in `msb`. Existing legacy PNG/BMP names must remain available until current GPX/ExpertGPS custom-marker and web references are reconciled/tested.
7. **Verify GPX/ExpertGPS compatibility** by opening representative waypoints after any filename or symbol-type mapping change and verifying the published map still renders older markers. Do not silently rewrite GPX `type`, symbol references, URLs, marker metadata or Garmin-compatible names.
8. **Document and review changes** to filenames, dimensions, marker associations, browser URL contract and any aliases in this engineering authority, link from #171, and confirm downstream app/browser acceptance separately. No Production deployment or reference-table migration is implied by publishing artwork.

One validated export approach uses the installed Inkscape CLI and intentionally omits width/height overrides. Execute on the workstation after confirming the actual Inkscape executable path; `<staging-folder>` must be a new/reviewed destination, never the legacy PNG library:

```powershell
$plain = 'G:\Shared drives\Display Folders\Park Drawings\MSB GIS\Symbols\Plain'
$pngStage = '<staging-folder>'
$inkscape = 'C:\Program Files\Inkscape\bin\inkscape.exe'
New-Item -ItemType Directory -Force -Path $pngStage | Out-Null
Get-ChildItem -LiteralPath $plain -Filter '*.svg' -File | ForEach-Object {
    $output = Join-Path $pngStage ($_.BaseName + '.png')
    & $inkscape $_.FullName '--export-type=png' "--export-filename=$output"
    if ($LASTEXITCODE -ne 0) { throw "PNG export failed: $($_.Name)" }
}
```

The October 9 conversion created one RGBA PNG per supplied Plain SVG, with the same pixel canvas dimensions (31/31), using Inkscape without fixed-size overrides. No automatic upload to TopoGrafix/Synology, live marker migration or Garmin BMP regeneration was performed by that conversion.

For older Garmin use, a **24 × 24 BMP with magenta transparency key** was discussed as a possible compatibility derivative; it was **not** regenerated in this batch. Keep existing BMPs, and test with the actual Garmin/ExpertGPS path before adding any new BMP pipeline.

## Approved 31-file Plain SVG / ExpertGPS PNG name-and-size baseline

From the corrected input archive `msb-plain-icons-corrected.zip`, converted into `MSB_ExpertGPS_PNGs_from_SVG_2026-10-09.zip`. The archives were generated in the conversation; these **archive filenames alone do not establish that ZIP files are stored in GitHub or the Shared Drive**. The controlled/current artwork copies reside at the directories above.

| Plain SVG filename | Intended canvas (pixels) | PNG filename |
| --- | ---: | --- |
| `car-l.svg` | 32 × 18 | `car-l.png` |
| `car-r.svg` | 32 × 18 | `car-r.png` |
| `cf50d-l.svg` | 32 × 32 | `cf50d-l.png` |
| `cf50d-r.svg` | 32 × 32 | `cf50d-r.png` |
| `container-empty.svg` | 32 × 32 | `container-empty.png` |
| `container-loaded.svg` | 32 × 32 | `container-loaded.png` |
| `container-partial.svg` | 32 × 32 | `container-partial.png` |
| `container-unknown.svg` | 32 × 32 | `container-unknown.png` |
| `fire-hydrant.svg` | 32 × 32 | `fire-hydrant.png` |
| `ip-camera.svg` | 32 × 32 | `ip-camera.png` |
| `kit-box.svg` | 32 × 32 | `kit-box.png` |
| `lor-controller.svg` | 32 × 32 | `lor-controller.png` |
| `lor-repeater.svg` | 24 × 24 | `lor-repeater.png` |
| `lp-combo.svg` | 32 × 32 | `lp-combo.png` |
| `lp-network.svg` | 32 × 32 | `lp-network.png` |
| `lp-outlet.svg` | 32 × 32 | `lp-outlet.png` |
| `lp.svg` | 32 × 32 | `lp.png` |
| `manhole.svg` | 32 × 32 | `manhole.png` |
| `msb-splitter-combiner.svg` | 24 × 24 | `msb-splitter-combiner.png` |
| `msb-splitter.svg` | 24 × 24 | `msb-splitter.png` |
| `outlet-combo.svg` | 32 × 32 | `outlet-combo.png` |
| `outlet-network.svg` | 32 × 32 | `outlet-network.png` |
| `outlet-power.svg` | 32 × 32 | `outlet-power.png` |
| `panel.svg` | 32 × 32 | `panel.png` |
| `pin-white.svg` | 32 × 32 | `pin-white.png` |
| `stage.svg` | 32 × 32 | `stage.png` |
| `switch-5-port-e131.svg` | 32 × 16 | `switch-5-port-e131.png` |
| `switch-5-port-inet.svg` | 32 × 16 | `switch-5-port-inet.png` |
| `switch-5-port-poe.svg` | 32 × 16 | `switch-5-port-poe.png` |
| `t-post.svg` | 16 × 32 | `t-post.png` |
| `transformer.svg` | 32 × 32 | `transformer.png` |

Archive provenance for engineering comparison (SHA-256, calculated from uploaded conversation archives):

- Corrected SVG archive: `eba2ab74bbc7430b024fbde8e22bc220c7e856821aff4714667a0092ef9fe34c`; 31 SVG files, SVG XML parsed.
- Converted PNG archive: `ba0d0865e0dba88a12ae69cf868ccef79a1f364ade05eb5e6b7b454bc91b89e1`; 31 PNGs, PNG dimensions match the associated SVG documents.

## Corrected artwork filenames and compatibility

Corrections from the original supplied symbol ZIP to the canonical Plain SVG baseline:

| Originally supplied | Canonical Plain SVG |
| --- | --- |
| `pin.-white.svg` | `pin-white.svg` |
| `lor-repater.svg` | `lor-repeater.svg` |
| `msb-plitter.svg` | `msb-splitter.svg` |
| `msb-plitter-Combiner.svg` | `msb-splitter-combiner.svg` |

Do **not** presume these old names are the exact filenames in the long-standing public `msb` folder: inventory that folder before mapping old URL references. Older `Panel.png`, `Stage.png`, `Outlet_Combo.png`, etc. are known examples of capitalization/underscore compatibility names and must not be deleted merely because current exports are lowercase.

ExpertGPS waypoint type names are not arbitrary mutable labels: the operator reports that changing a type key requires deleting/recreating the ExpertGPS type. Keep source `type`, `sym`, GPX extensions/custom-marker links and map display identity distinct from an internal icon filename. An explicit reviewed old-name alias, duplicate published filename or type-reference migration may be needed; never assume that renaming a PNG also repairs GPX links.

## MSB browser/DB symbol contract and boundaries

- Use Plain SVG as the preferred MSB GIS/browser source. A future **maintained type/icon reference registry** under #171/#230 may map logical feature type and authoritative Container load state to presentation asset paths; reuse existing physical identities. No new schema or cutover has been approved by this document.
- **Container state icons:** `container-loaded.svg`, `container-partial.svg`, `container-empty.svg` and `container-unknown.svg`. Use accepted #88 movement/contents evidence, not expected `ref.display.container_id` membership, historical assignment or proximity. Unknown stays unknown when physical contents cannot be established. A Container marker's current position is likewise taken from accepted #88 state.
- **Displays:** `WITH_CONTAINER` Displays normally appear in the parent Container's details rather than each receiving a duplicate map pin; independently observed Displays may have their own marker (T-Post was the existing interim symbol). Unlocated assets must not be placed at invented coordinates.
- **Symbol geometry:** application implementations must preserve purposeful rectangular icon shapes (32 × 16 switches, 16 × 32 T-Post, 32 × 18 cars, 24 × 24 repeater/splitter) without stretching every marker to 32 × 32. Confirm icon sizes/anchors in browser visual acceptance; this document is not proof current renderer has been updated for every icon.
- **GPX round trip:** preserve original GPX name/type/extensions/marker metadata, including custom URLs; accepted ExpertGPS **Label on Map** is the current waypoint display identity when it differs from Garmin legacy name (see the maintained #171 identity reconciliation). Icon replacement must not alter geometry, source identity, coordinate provenance or track topology.
- **Network/power independence:** waypoint function/type can represent combined power/network equipment and does not grant an exclusive classification; type/icon mappings remain presentation, not inferred cable/panel/circuit relationships. Do not modify #319 network/link-test data or #88 movement writes as a side effect.
- **Security/publication:** SVG/PNG public web directories contain presentational artwork. GIS infrastructure references, private operational overlays and access-controlled views remain in the authenticated application; publishing an icon does not authorize publishing sensitive tracks or operational JSON.

## Current handoff / unfinished tasks

- Operator reports `Masters`, `Plain` and `msb-svg` established with corrected files; the legacy `msb` share still contains old-named PNG/BMP. October 11 install ZIP includes the original ExpertGPS `readme.txt` and 31 PNGs; **actual per-PC installation and Synology PNG publication remain unconfirmed**. Preserve `msb` and do not move to `MSB Icons` without a backward-compatibility review.
- Only the green `container-loaded.svg` URL was operator-verified individually. Before a release, validate all published SVG URLs, sizes/visuals and case-sensitive filenames against the authoritative Plain folder.
- A complete reusable symbol registry and GPX/ExpertGPS old/new URL alias inventory are **pending**; don't mark them deployed based on this document.
- Reconcile active #171 map candidates and #230 editor direction before updating browser symbol lookup or databases. Do not overwrite concurrent #171/#319 work.
- For any production code, schema or server mutation, follow project rules and governing Server Management runbooks; this document is documentation-only.

See [Site Infrastructure / GIS README](../README.md), [#171](https://github.com/Gregovate/MSB-Production-Database-Project/issues/171), and [#230](https://github.com/Gregovate/MSB-Production-Database-Project/issues/230).
