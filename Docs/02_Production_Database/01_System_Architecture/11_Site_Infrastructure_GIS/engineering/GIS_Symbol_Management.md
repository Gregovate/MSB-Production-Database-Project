# MSB GIS Symbol Creation, Publication, and Compatibility

| Document control | Value |
| --- | --- |
| Status | CURRENT engineering/source-maintenance contract (runtime adoption remains separately gated) |
| Owner | Site Infrastructure / GIS, Issue [#171](https://github.com/Gregovate/MSB-Production-Database-Project/issues/171) |
| Recorded | 2026-10-12, current controlled contract with retained October 9–11 investigation history |
| Related ownership | #230 reference editor/type registry; #88 Container movement/load evidence; #175 Task Cover Sheet consumer |
| Subject | SVG masters, Plain SVG export, ExpertGPS PNG derivative, legacy symbol compatibility, web publication |

## CURRENT ENGINEERING AUTHORITY — Icon Library, GIS consumers and publication (October 12, 2026)

| Document control | Value |
| --- | --- |
| Authority | **CURRENT controlled subsystem engineering contract** for artwork, derived symbols, desktop manager and publication |
| Responsible subsystem | Site Infrastructure / GIS — Issue #171, under #122; #230 owns governed reference editing |
| Owner | MSB Site Infrastructure / GIS administrator |
| Reviewed | 2026-10-12 |
| Implementation authority | Repo source: `Database/EngineeringTools/{icon_library_manager.pyw,sync_gis_icons.py,publish_gis_svgs.py,distribute_gis_pngs.py}`; consumer code under Setup/FieldWiring as separately controlled |
| Adjacent authority | [draft #319 Site Source Synchronization Contract](https://github.com/Gregovate/MSB-Production-Database-Project/blob/feature/171-cableiq-import-validation/Database/EngineeringTools/Site_Source_Synchronization_Contract.md) for GIS/GPX/FLW/PostGIS evidence and [Site Infrastructure / GIS README](../README.md) for engineering handoff |

### Design control — the document governs implementation

The **accepted engineering rules and operator requirements in this controlled document take priority over draft PR descriptions, chat summaries and dated experiment notes**. A PR is an implementation/review vehicle, not the source of a new unapproved architecture. Before code changes: reconcile latest approved engineering direction and source evidence, update the responsible engineering contract when a decision/requirement changes, then implement and validate to that contract. Record field findings against the existing owning Issue #171 and promote accepted results here. An accepted release or UI observation does not silently supersede this authority. Cross-thread contributors must coordinate shared `locate_preview.html` or #319 work instead of merging competing map rewrites.

The supported design is **one approved artwork source with independently controlled publication and consumers**, not separate independently edited icon libraries. SVG/PNG symbols are presentation assets, **not** waypoint identities, surveyed geometry, cable/panel relationships or new database reference records. Preserve GPX provenance, ExpertGPS `Label on Map` identities and historical URLs; approved #230 reference editing uses the maintained PostgreSQL/PostGIS model. Source snapshots and the editor must not rewrite source GPX/FLW as side effects of icon maintenance.

### Source, derivative and destination contract

| Component | Controlled location | Current behavior and ownership |
| --- | --- | --- |
| Editable original artwork | `G:\Shared drives\Display Folders\Park Drawings\MSB GIS\Symbols\Masters` | Inkscape masters and intentional layers. The manager **never** infers desired layer visibility or edits masters. |
| **Approved browser artwork source** | `G:\Shared drives\Display Folders\Park Drawings\MSB GIS\Symbols\Plain` | Validated pixel-based, lowercase hyphenated Plain SVG outputs; source for public SVG and PNG derivative. Each axis is an integer **1–32px**; rectangular shape is intentional. This is **not** the website publication destination. |
| Canonical ExpertGPS PNG derivative | `G:\Shared drives\Display Folders\Park Drawings\MSB GIS\Symbols\png` | Rendered from **current approved Plain**, 8-bit RGBA native pixel canvas, hash-verified; no master/XML ZIP is an alternative authority. |
| Permanent release evidence | `G:\Shared drives\Display Folders\Park Drawings\MSB GIS\Symbols\release-history\MSB-GIS-Icon-Sync-*` | Versioned input/source manifest, output hashes, previews, copy receipts, failure details and replaced-original backups. Preserve history through failed/partial copies. |
| Website **SVG** publication | `\\192.168.5.4\webassets\images\symbols\msb-svg` — public URL `https://webassets.sheboyganlights.org/images/symbols/msb-svg/` | **Administrator-only** reviewed publication from Plain, separately confirmed; current 37-entry SMB synchronization PASS (October 12); independent HTTPS/browser delivery acceptance remains open. |
| Website legacy **PNG/BMP** | `\\192.168.5.4\webassets\images\symbols\msb` — public URL `https://webassets.sheboyganlights.org/images/symbols/msb/` | Separate **administrator-only** compatibility distribution; currently BLOCKED for canonical `ip-camera.png` versus existing `IP-camera.png`. Leave historical aliases intact. Not required for new Park Map SVG rendering. |
| Current-user ExpertGPS icons | `%LOCALAPPDATA%\TopoGrafix\Symbols\msb` | Separate user-local reviewed PNG installation. Existing `readme.txt` first line `https://webassets.sheboyganlights.org/images/symbols/` is a URL-parent contract, **not** a copy/upload task. Existing `msb` identity is preserved. |
| Garmin / draw.io / GPX types | Their own existing source/device/model authorities | A locally updated ExpertGPS folder does not install Garmin symbols. draw.io stores embedded artwork requiring separate acceptance. Icon publication must not rename GPX types/URLs or mutate schematic object IDs. |

Do not install from the earlier temporary 31-/32-/34-icon Downloads ZIPs or pin a permanent icon count in code. The observed **37-file** result is the **current October 12 release checkpoint**, not a hard-coded future source-set limit.

### Icon Library Manager — five independent actions

1. **Check and preview icons**: read and validate all current Plain SVGs, render/verify native PNGs using Inkscape, compare canonical PNG hashes and display source-timing warnings without automatically replacing approved artwork. Cache reuse requires matching source/output hashes and verified dimensions.
2. **Save approved PNG changes**: optional, for approved NEW/UPDATE canonical PNGs only; separate explicit consent, backup-before-replace and per-file hashes/receipt. Does **not** publish.
3. **Review/publish Plain SVGs to web**: administrator-only destination comparison (NEW/UPDATE/Unchanged and safe historical-case identical), separate explicit LIVE server approval, retained backups and SHA-256 receipts. A hash-identical differently-cased existing published SVG can be retained at its **actual exact-case URL**, never claimed as a lowercase URL. Differing-byte or ambiguous case clashes fail closed. No PNG, GPX or map deployment.
4. **Publish PNGs to web**: separate administrator-only compatibility task from canonical PNGs, **not part of the accepted October 12 SVG release**. Source/hash preflight currently correctly stops at the `IP-camera.png` case mismatch; do not rename historical files to bypass it.
5. **Install PNGs for this ExpertGPS user**: current-user TopoGrafix target only. On an **initial installation where `msb` does not yet exist**, Step 5 previews the full canonical PNG set and, after explicit confirmation, provisions `msb` with all current approved PNGs and a new canonical `readme.txt` using the controlled parent URL. If the folder exists, preserve unrelated legacy files and any valid existing `readme.txt`; missing readme may be provisioned with separate confirmation, but invalid/mismatching readme must STOP for review. Use backup/receipts and current-user-only target enforcement. ExpertGPS must be closed during installation and reopened for the actual visual/GPX round-trip test.

No action 1/2/5 silently invokes actions 3/4. The Desktop tool is a **repository-checked-in program**, not a self-updating installed executable: one-time `Install-MSB-Icon-Library-Shortcut.cmd` creates a Desktop link to `Launch-MSB-Icon-Library.cmd` within the authorized Git checkout. Future software updates require updating the correct clean `main` checkout with `git pull --ff-only`. The launcher selects `.venv\Scripts\pythonw.exe` or a known installed Windows Python with Tkinter; Inkscape `inkscape.com` is required. A moved checkout requires reinstalling the shortcut. The GUI still lacks a visible release SHA/version; its Git HEAD is currently the external version check, and the blank publish/cancel button-label defect remains unresolved.

### Command Center PC portability: Step 1 / local ExpertGPS independence and application identity (October 12 field defect)

**Operator observation (Command Center Windows account `Light-O-Rama`):** the Desktop shortcut installed and the G: approved `Plain` source was accessible, but **1. Check and preview icons** failed before scanning because `%LOCALAPPDATA%\TopoGrafix\Symbols\msb\readme.txt` was absent. Code incorrectly used `readme_bytes(local ExpertGPS path)` when staging a preview ZIP; this is unrelated to SVG validation. The shortcut/GUI also used a generic/default icon instead of a dedicated MSB application identity.

**Required behavior controlling the repair:**
- Steps **1** (validation/preview), **2** (canonical G: PNG save), **3** (approved web SVG) and **4** (web PNG compatibility) **must not depend on local ExpertGPS installation, `%LOCALAPPDATA%`, or its `readme.txt`**. All normal source validation/hashes/Inkscape/canonical destination security checks remain in force. The optional preview's staged `msb/readme.txt` derives from the already-approved `README_URL` constant and is *not* a copy from any PC user profile. This staging artifact does **not** create/update TopoGrafix user files.
- **Only Step 5** (install PNGs for this ExpertGPS user) works with the **current Windows user's** `TopoGrafix\Symbols\msb` destination. **Correction from the Command Center field check:** ExpertGPS was installed and `TopoGrafix\Symbols` existed, but the application-specific `msb` folder had never been created. This is a normal first-use state. Step 5 **must offer to provision `msb` itself**, with all validated canonical PNGs and the canonical parent-URL `readme.txt`, **after an explicit review and confirmation**; never require the operator to create or borrow either. First-use preflight remains read-only; staging/complete-copy/hash verification occurs before a new `msb` folder is made visible. Existing valid readmes and unrelated PNG/BMP aliases remain unchanged; conflicting/invalid readmes stop for review. Never use another Windows profile, change GPX references, or publish web files. The local install is a different gate from Step 1 or the public SVG action.
- The source-controlled Windows **Desktop shortcut and application window must share a distinct MSB Icon Library Manager icon**, not the generic CMD/Python/Tk icon or a GIS waypoint icon. The application branding asset is **separate from the G: `Symbols\Plain` GIS waypoint publication/GPX registry**; it must be stored with the checked-in tool and cannot require local ExpertGPS, webassets credentials, live database, or G: publication. Rerunning the one-time shortcut installer after a code update must replace/refresh the existing shortcut's icon without modifying any imagery source or permissions.
- **Acceptance:** disposable regression for missing/invalid local ExpertGPS readme during Step-1 staging; canonical ZIP URL metadata; no unintended TopoGrafix creation/write from Step 1; **Step-5 first-use preflight (no writes), approved `msb`/readme/full-PNG provisioning on confirmation, repeat-run idempotence, invalid existing readme denial, wrong-profile denial and failure cleanup**; Windows ICO/shortcut/window appearance; actual Command Center PC repeat test. Do not claim field operation PASS until verified.

**Source-only remediation scope:** UI/helper/tests and installer/icon assets, updated operator SOP and link handoff, existing #171 issue. No GPX, Synology, Canonical G: artwork/PNG, #88, #230, or Production modifications.

**Current candidate evidence:** [PR #365](https://github.com/Gregovate/MSB-Production-Database-Project/pull/365) adds the portable source-to-staged-ZIP metadata, dedicated source-controlled Windows ICO/Tk/shortcut branding, and regressions. [GIS icon GitHub Actions run #38272142754](https://github.com/Gregovate/MSB-Production-Database-Project/actions/runs/38272142754) **PASS** (19 core, 11 SVG publication, 12 PNG distribution tests = **42**, plus Python syntax). The previously implemented Step-5 denial for a missing/wrong original local readme remains tested. **Actual Command Center Windows reinstallation, branded shortcut/window appearance and Step-1 G: preview are PENDING user verification**; no web/server/Production release occurred.

### Command Center portability — renderer must be needed before it is required (October 12 follow-up)

**Observed on clean `main` `529c4a1e` under Windows account `Light-O-Rama`:** Step 1 now passes the missing-ExpertGPS-readme dependency, but stops with **`Inkscape CLI unavailable: supply --inkscape path to inkscape.com`** before checking its existing shared, hash-verified PNG preview cache. The operator has G: access; the cache was built from the same controlled shared source on the administrator laptop. This is an unnecessary code dependency, not proof that an icon or its source is missing.

**Required source/renderer contract:** Validate every current Plain SVG's name, XML, canvas units and SHA-256; for each source, try the existing `MSB_GIS_Preview_Cache.json` only when its source SHA, verified PNG SHA, physical image bytes and native dimensions match. A **full cache hit must not perform or require Inkscape executable discovery on this Windows PC**. If *any* source lacks a valid cached derivative, attempt `choose_inkscape()` **only at that exact render-required point**; without the CLI, fail closed with the affected filename, cache-miss reason and clear prerequisite guidance. Never reuse an unverified canonical PNG as if it were a current-source export, fabricate a preview, or copy to canonical/local/web destinations after a failed scan. Keep the existing source snapshot, current canonical PNG comparisons, package verification, release receipts, and independent ExpertGPS Step 5 behavior.

**UI layout requirement:** Keep **5. Install PNGs for this ExpertGPS user** fully readable at ordinary Windows display scaling and the existing minimum 800px app width. Do not place the full local installation button into the same crowded horizontal row as web actions. Preserve clear separation of **web (administrator-only)** actions 3/4 from **current-user local** action 5; each remains separately confirmed and permission-gated.

**Windows shortcut separate:** The checked-in `assets/MSB-Icon-Library-Manager.ico` is the Desktop shortcut icon; `Launch-MSB-Icon-Library.cmd` itself contains no embedded Windows icon. After updating Git, rerun `Install-MSB-Icon-Library-Shortcut.cmd` once to refresh its `IconLocation`. Copying `msb_icon_library_manager.png` to the `EngineeringTools` root or choosing the CMD as an icon source is not part of the installation. Operator screenshot shows the custom icon in the running Tk application title bar, **not yet proof of the refreshed Desktop shortcut**.

**Acceptance:** isolated complete-cache/no-Inkscape PASS with `choose_inkscape` explicitly forbidden; partial-cache/miss requiring an available CLI; stale SVG hash refusing cache and failing specifically for missing renderer; no writes to any live destination on failed scan; preserve existing Step 5 first-run tests and real Command Center trial. **PR #367 isolated CI run #38278598703 PASS: 23 core + 11 web SVG + 16 PNG distribution = 50 tests, plus Python syntax.** No actual Windows scaling or Step-1 G: cache acceptance is claimed before operator review. Production, web, GPX, PostGIS and G: source artwork remain untouched.

### CRITICAL — ExpertGPS fallback can damage custom-symbol associations (October 12 field STOP)

**Observed by MSB operator:** Opening a GPX with MSB custom symbol references in **ExpertGPS before provisioning the current Windows user's `msb` custom-symbol library** causes its MSB icon associations to change to **`GPS Symbol`**, **even without intentionally saving the opened GPX**. This is a **data-integrity/identity and application-configuration hazard**, not a merely missing image. It is not yet known whether the unsaved change is in memory, persisted in ExpertGPS per-user waypoint-Type/Map-Marker settings, persisted in another application state store, or modifies GPX bytes outside normal Save. **Do not infer that closing without Save or installing PNGs afterward restores the original custom mapping.**

**Immediate fail-closed operator prerequisite:** Before opening **any authoritative MSB GPX or ExpertGPS project** on a new PC or Windows profile, the user must **first** run Icon Library Manager Steps 1/2 as applicable and **5. Install PNGs for this ExpertGPS user**, creating the full approved `%LOCALAPPDATA%\TopoGrafix\Symbols\msb` (including canonical parent-URL `readme.txt`) if missing. Verify folder identity, complete current PNG hashes, readme first line, and presence of map marker entries; **restart ExpertGPS to load the custom symbol set** before any MSB GPX is opened. For already-affected computers, preserve application/type settings as evidence before further opens and perform any verification against a **disposable copy** of known-good GPX, never the authoritative shared source. User profile A having 37 PNGs does not protect user profile B. Merely publishing SVGs to the web does not install the required local PNGs or make ExpertGPS types safe.

**Recovery/data preservation:** Preserve the verified original shared GPX, its source SHA and earlier approved ExpertGPS `Label on Map`, `type`, `sym`, custom-symbol `marker_url`/extensions and waypoint coordinates. Do not save, export, resynchronize, promote, or overwrite that GPX from an ExpertGPS session exhibiting fallback GPS Symbol. **Reinstalling symbols alone is not evidence of repaired prior Type/Map-Marker associations**. Establish root cause using an isolated file copy and reviewed before/after GPX export as a separate acceptance experiment; check whether the application retains incorrectly remapped waypoint Type state across restart. Until resolved, this is an **OPEN BLOCKER** for ExpertGPS round-trip/reimport acceptance in #171/#230/#319.

**ExpertGPS vendor documentation establishes:** custom symbols must be placed in a named `Symbols` subfolder alongside a correctly formatted `readme.txt`, and ExpertGPS must be restarted to load them. A waypoint's `Type` and `Map Marker` are distinct settings; symbol settings can be associated with types. See [custom symbol instructions](https://www.expertgps.com/tutorials/creating-custom-map-symbols-and-markers-with-expertgps.asp) and [Edit Waypoint field help](https://www.expertgps.com/help/cmd-edit-waypoint.asp). The vendor references **do not document this precise no-save persistence failure**; that portion is grounded in MSB operator observation only.

**Implementation/acceptance boundary:** Before allowing further MSB ExpertGPS source round-trip testing, update the operator SOP with an unequivocal **install-before-open** warning, label Step 5 similarly in the desktop app, and verify the onboarding procedure. Any automated GPX/FLW/PostGIS edits or source renaming to "fix" GPS Symbol fallbacks are forbidden. No change to the accepted web SVG publication/administrator-only ACL. Continue to record the evidence in owning [Issue #171](https://github.com/Gregovate/MSB-Production-Database-Project/issues/171#issuecomment-6128753934) and coordinate draft PR #319's import/export gate separately.

### Discovery — ExpertGPS waypoint Types and map styles are Windows-user configuration (October 12, 2026)

**Observed MSB workflow:** ExpertGPS's **Edit Waypoints → Type** drop-down and the **Map Display Style (for all waypoints of this type) → Map Marker** selection are **not consistent between the operator laptop and the Command Center Windows account**, even when both computers have the complete `msb` PNG collection and a correct `readme.txt`. The laptop has a custom **`Display Anchor`** Type and its selected map marker. The other PC has **`Flag`** associated with an `msb` yellow-pole graphic and a separate blue-flag **GPS Symbol**. This is **not** evidence that `Flag`, `Display Anchor`, the GPS Symbol, or a source GPX marker URL are interchangeable. An earlier opening without symbols led to unexpected `GPS Symbol` map-marker fallback; **readme plus 37 PNG files alone does not restore the intended waypoint-Type → Map-Marker configuration**.

**Verified vendor-supported setting storage and transfer:** ExpertGPS publishes [Transferring ExpertGPS Settings to a New Computer](https://www.expertgps.com/transfer-settings.asp), instructing users to export the **`HKEY_CURRENT_USER\Software\TopoGrafix\ExpertGPS` and `HKEY_CURRENT_USER\Software\TopoGrafix\Common`** branches to `.reg` files on the source PC and import them under the destination Windows account. Vendor [Working with Types](https://www.expertgps.com/help/type.asp) confirms a personal list of types and per-Type map style, and its [custom symbol instructions](https://www.expertgps.com/tutorials/creating-custom-map-symbols-and-markers-with-expertgps.asp) confirm that the selected custom Map Marker applies to all waypoints of that Type. The registry **branch level is confirmed, but the exact individual key/value that records Type → Map Marker is NOT identified by the vendor material inspected**. Do not claim it is definitely in GPX, definitively in the registry, or safely transferable by cherry-picking a guessed value. This does **not** resolve whether GPX export also embeds some symbol metadata.

**New direct laptop registry evidence (October 12, after backup):** With `Display Anchor` configured in ExpertGPS on the laptop, the operator ran read-only `reg query` of both HKCU branches. The `ExpertGPS` branch returned the value line **`Type    REG_SZ    Display Anchor`** (the containing subkey was not included in the pasted output). The `Common` branch returned **`Flag, Blue    REG_SZ    Display Anchor`** and, decisively, the full subkey **`HKEY_CURRENT_USER\Software\TopoGrafix\Common\Waypoint Types\Display Anchor`**. Earlier equivalent searches on the Command Center Windows user found **no Display Anchor** in either branch. Thus **a named per-user Waypoint Types registry subkey exists for the laptop's custom type**, and the destination lacks that same searchable association. The significance of the `Flag, Blue` value is **not yet established**; do not confuse it with the custom MSB Map Marker and do not infer that the complete per-Type display style can be restored by copying that value alone. The exact `Display Anchor` subkey values/dependencies have **not** been inspected.

**Direct Show PC registry-export evidence (October 12; no settings imported or changed):** The operator provided two exports from the `Light-O-Rama` Windows account. Although their filenames contained `Laptop`, their provenance is **Show PC**. They are Windows Registry UTF-16 exports, inspected **locally** without publishing the raw data or exposing unrelated keys/registration details. The `ExpertGPS` export has 108 registry sections; `Common` has 84 sections. Under `HKCU\Software\TopoGrafix\Common\Waypoint Types`, the Show PC has **37 named waypoint Type subkeys**, **no `Display Anchor` subkey**, **11 nonempty custom `Bitmap Symbol URL` values** pointing to `https://webassets.sheboyganlights.org/images/symbols/msb/*.png`, and **26 empty bitmap URLs**. These observed URLs are source/profile configuration; they do **not** prove the current public PNG URL renders.

**The actual per-Type map marker fields are now identified in the Show PC export** (this was **not** known from vendor documentation alone). For example:

```reg
[HKEY_CURRENT_USER\Software\TopoGrafix\Common\Waypoint Types\Flag]
"Symbol Type"="2"
"GPS Symbol"="Flag, Blue"
"Bitmap Symbol URL"="https://webassets.sheboyganlights.org/images/symbols/msb/pole-yellow.png"
```

Other observed Type → PNG associations: `Car → car-r.png`, `Controller → lor-controller.png`, `Drop Point → kit-box.png`, `Hydrant → fire-hydrant.png`, `Light Pole → lp.png`, `LP-Combo → lp-combo.png`, `Panel → panel.png`, `Stage → stage.png`, `Tower → antenna-r.png`, and `Waypoint → pin-white.png`. **`GPS Symbol` and `Bitmap Symbol URL` are separate stored fields**, matching the operator's ExpertGPS dialog.

**The Show PC also has a reverse/association table:** `HKCU\Software\TopoGrafix\Common\Settings\SymbolToType` contains `"Flag, Blue"="Flag"`. The operator's earlier **laptop** read-only query showed **`"Flag, Blue"="Display Anchor"`**. This is a directly observed cross-PC conflict and a plausible cause of the same GPS symbol being assigned a different local waypoint Type when a GPX is opened. **It does not yet prove how GPX import chooses a Type or whether the missing-symbol event persisted that change.** Do not overwrite either user profile or canonical GPX on the basis of this hypothesis.

**Laptop subkey now CONFIRMED by the operator's read-only registry query (October 12):**

```reg
[HKEY_CURRENT_USER\Software\TopoGrafix\Common\Waypoint Types\Display Anchor]
"Symbol Type"="2"
"GPS Symbol"="Flag, Blue"
"Bitmap Symbol URL"="https://webassets.sheboyganlights.org/images/symbols/msb/pole-yellow.png"
```

Those **three values are identical** to the Show PC's `Waypoint Types\Flag` entry. The difference is the **waypoint Type name** and the separate `Common\Settings\SymbolToType` reverse assignment (**laptop `Flag, Blue → Display Anchor`; Show PC `Flag, Blue → Flag`**). This establishes that a full identical local PNG collection alone cannot align the two PC-specific Type names, and narrows the portability defect to the user-specific ExpertGPS Type/style registry configuration. It **does not establish** whether ExpertGPS reads GPX `<type>` directly, reinterprets Garmin `<sym>` with `SymbolToType`, uses extensions, or has additional state. The original GPX remains actively edited and must not be opened, reverted, or compared to stale October 11 hashes as a diagnostic.

**Next controlled gate:** inspect the **raw current GPX or an existing disposable copy read-only outside ExpertGPS**, isolating the waypoint `ST POLE DS1` and its exported `<type>`, `<sym>`, `<extensions>` metadata and compare them to these registry fields. Do not mutate the authoritative GPX, blindly merge registry branches, copy guessed mappings into PostGIS, or hardcode `Flag → pole-yellow.svg`. A safe Type/style installation/migration procedure can be designed only after the import precedence and other registry dependencies are understood. Preserve the original backups from both Windows accounts.

**Office PC third-profile comparison — user-provided read-only backups (October 12, 2026):** The operator supplied the Office PC's `Common-Office.reg` and `ExpertGPS-Office.reg` exports. They were inspected **without importing registry settings or modifying files**. The per-Type registry sections are under the same `HKCU\Software\TopoGrafix\Common\Waypoint Types\<Type>` path. Only the following nonsensitive aggregate counts and relevant waypoint-style values are recorded; **raw .reg exports and unrelated registration/profile configuration are not repository artifacts**.

| Current-user registry observation | Maintained laptop | Command Center / Show PC | Office PC |
| --- | ---: | ---: | ---: |
| Named `Waypoint Types` subkeys | **57** | **37** | **28** |
| Types with nonempty `Bitmap Symbol URL` | **32** | **11** | **15** |
| `Display Anchor` Type present | **Yes** | No | No |
| `Common\Settings\SymbolToType`: `Flag, Blue` maps to | **Display Anchor** | **Flag** | **Outlet Power** |
| `Waypoint Types\Flag` | `Symbol Type=2`, `Bitmap Symbol URL=msb/pole-yellow.png` | **same style as laptop Flag** | `Symbol Type=1`, empty bitmap URL |

The Office PC contains **14 historical MSB PNG references** with old mixed-case/underscore filenames, plus one non-MSB Google Maps shape URL. Examples include `Panel → msb/Panel.png`, `Stage → msb/Stage.png`, `Light Pole → msb/LP.png`, `Display → msb/T-Post.png`, and `Drop Point → maps.google.com/.../square.png`. By comparison, the laptop uses `panel.png`, `stage.png`, `lp.png` under the MSB symbol URL. These **are different, intentionally retained historic case-sensitive references**, not permission to rename or silently rewrite source GPX, registry values, or the legacy public PNG folder.

**Cross-PC comparison of exact `Symbol Type`, `GPS Symbol`, and `Bitmap Symbol URL`:** Office and laptop have **26** Type names in common, **16** of which have at least one differing style field. Office and Show PC share **18** Type names, **9** with differing fields. The Show PC's **37** Type names all occur on the laptop, but **7** have at least one different style field. The number of installed local PNGs cannot be used to infer registry Type configuration or remotely served legacy URL viability.

**Implication:** Three independent Windows profiles demonstrably hold three different waypoint Type/style catalogs. A broad registry import could overwrite other legitimate Type definitions and machine preferences, while a simple PNG installation cannot reconcile the catalogs. The maintained laptop is a **candidate**, not yet an approved organization-wide type/style master. The correct future workflow must explicitly review source Type/style configuration, transfer only governed references with backup/rollback, retain legacy filename and user mappings, and prove GPX-import interpretation from **actual, read-only source XML** before designing #319's PostGIS/API resolution. Do not mistake matching local `Bitmap Symbol URL` for confirmation that a new Type round-trips through ExpertGPS or is included in the current GPX.

**Preservation and investigation contract:**
1. Treat the **laptop's currently maintained Type/style configuration** as the candidate source for the Command Center PC, but do **not** automatically promote it as organization-wide authority until its complete association set and version are reviewed.
2. With ExpertGPS closed, export **both** `HKCU\Software\TopoGrafix\ExpertGPS` and `HKCU\Software\TopoGrafix\Common` **separately on the laptop and destination** to protected **local** evidence. Use only the account in which ExpertGPS normally runs; an elevated command using another account would back up the wrong HKCU. Retain both before any import.
3. These broad registry trees may contain registration details, cached credentials, device/scanned-map paths, other personal preferences, or machine-specific data. **Never attach unredacted `.reg` exports to GitHub, an issue, ChatGPT, or a publicly shared folder.** Inspect and redact or select only nonsensitive key paths and value-name evidence. No raw registration values in repository.
4. Use **read-only** comparison to locate the actual Type/style associations. A text search returning no `Display Anchor` match is not proof the mapping is absent: it may be encoded/binary. Do not delete or edit the registry manually, use a registry cleaner, or blindly import full settings into an in-use Windows profile. Follow the vendor's broader transfer process only after reviewing potential overwrites and capturing a rollback.
5. Before opening any authoritative MSB GPX on the destination, verify local PNGs and canonical readme, transfer the reviewed Type/Map Marker configuration through an approved reversible procedure, restart ExpertGPS, then validate an **isolated copy** of the GPX. Preserve original source files, source identities, and historic type names. Prove association and GPX export fields independently. No automatic PostgreSQL mapping, GPX rewrite, SVG/PNG web publication, or application-code CASE list is authorized as a shortcut.

**Read-only GPX field observation on the laptop (October 12; `ST POLE DS1`):** The operator inspected the GPX as XML **without opening or saving it in ExpertGPS** and reported the following direct-child waypoint values:

| Raw GPX element | Reported value | Meaning / evidence boundary |
| --- | --- | --- |
| `<name>` | `ST POLE DS1` | GPX/Garmin name; this single example must **not** redefine the separately controlled ExpertGPS `Label on Map` comparison identity |
| `<type>` | **`Display Anchor`** | **The intended user-defined ExpertGPS waypoint Type is explicitly present in the GPX** |
| `<sym>` | **`Flag, Blue`** | GPS device Symbol; **not the displayed MSB custom Map Marker** |

The laptop's local registry `HKCU\Software\TopoGrafix\Common\Waypoint Types\Display Anchor` independently confirms `Symbol Type=2`, `GPS Symbol=Flag, Blue`, `Bitmap Symbol URL=https://webassets.sheboyganlights.org/images/symbols/msb/pole-yellow.png`. The Show PC instead has the same bitmap URL under its **different Type `Flag`**, and its `SymbolToType` maps the same GPS symbol to `Flag`. Thus **`Display Anchor` survives GPX export as a Type** and `Flag, Blue` survives separately as `sym`; a destination computer's Type list or reverse mapping must not replace the source `<type>` with `Flag` during an approved import. Whether the GPX **`<extensions>`** also contains the selected Map Marker URL, or how ExpertGPS prioritizes `<type>` versus its local `SymbolToType` on open, is **still unverified**. The matching filename in `<name>` does not establish that this record's `Label on Map` was independently extracted.

**#319 implementation/acceptance implication:** The currently inspected `Database/EngineeringTools/site_source_sync.py::extract_gpx` separately extracts `<type>` but **does not surface direct-child `<sym>` or any marker extension data** in its waypoint result. Source-fidelity test fixtures must distinguish these fields, preserve the original GPX Type and any extension metadata verbatim, and **refuse** to infer a yellow pole from generic GPS Symbol `Flag, Blue` or hardcoded JS `Flag → pole-yellow.svg`. The per-Type bitmap URL presently lives in the ExpertGPS user registry; do not create a competing authoritative mapping table until any GPX extension coverage and accepted synchronization boundary are proved. #319 owner should inspect **the extensions for this one waypoint read-only** before choosing the data contract. No source GPX, registry, map asset, SQL, Production or #319 branch change is authorized by this finding.

**#319 import/model implication:** The source record's waypoint Type, GPS Symbol, per-Type Map Marker selection and independently exported GPX marker metadata are distinct concepts. Preserve original GPX fields and provenance; **do not turn the Command Center's fallback `Flag`/GPS Symbol or the hardcoded `Flag → pole-yellow.svg` presentation workaround into canonical semantics**. The ultimate source-of-truth sync boundary depends on determining exactly what the GPX serializes versus which type styles exist only in an ExpertGPS user profile. Document and test that distinction before implementing a live PostgreSQL/PostGIS or offline SVG mapping contract. This discovery is a **research checkpoint, not the acceptance of a new mapping design**.

### Confirmed: ExpertGPS scanned-map georeferencing is also stored per Windows user (October 12, 2026)

**Operator field discovery:** The same underlying scanned orthophoto/drawing was not identically aligned across the laptop and Show PC. The operator needed to recalibrate it on the Show PC, although the map artwork itself was the same; the Office PC may have yet another configuration and must **not** be assumed synchronized. This parallels the already confirmed user-dependent ExpertGPS waypoint Types and Map Markers, but **the map calibration and waypoint Type/style are separate data classes**.

**Verified local registry-export structure:** Read-only inspection of an operator-provided `Common-Laptop.reg` export (the filename **does not independently establish the exporting PC**) found:

- `HKEY_CURRENT_USER\Software\TopoGrafix\Common\Maps\2019 Ortho Cropped for GPS Export`, with values **`Map Path`, `Width`, `Height`, `Bits Per Pixel`, `Use Worldfile Data`, `Projection`, `Projection\\EPSG`, `Datum`**. In this captured configuration, `Use Worldfile Data = 1` and image dimensions are 18281 × 9492 px.
- Child **`Point01`** and **`Point02`** contain **`X`, `Y`, `Latitude`, `Longitude`, `Worldfile X`, `Worldfile Y`**; **`Point03`** exists without populated values.
- The companion `HKCU\Software\TopoGrafix\ExpertGPS\Scanned Maps` key includes the user's default scanned-map selection. This is separate from the `Common\Maps\...` calibration data.

Therefore **at least one ExpertGPS scanned-map library entry and its geographic calibration points/coordinate system are stored in the current Windows user's registry**, independently of just sharing a TIFF/JPEG/PNG drawing. The original image, world file, an exported calibration file, and each Windows user's registered map-library entry must not be conflated. The stored `Map Path` can be machine-specific. Do **not** import broad `Common`/ExpertGPS registry settings from one PC to another solely to carry calibration; that could replace Type configurations, device paths or other per-user settings.

**Vendor-supported portable calibration:** [ExpertGPS scanned-map calibration documentation](https://www.expertgps.com/help/calibrating-a-scanned-map.asp) explains that scanned maps are added to the local map library with a projection/datum and calibration points, and that supported calibration sidecars (including worldfiles or `.map`) may be detected when adding the map. [Save Map Calibration File](https://www.expertgps.com/help/cmd-save-map-calibration-file.asp) documents **Scanned Map Library → select map → Export** to create a portable `.map` georeference file. [Calibration Points](https://www.expertgps.com/help/calibration-point.asp) explains TFW/JGW/PGW/BPW world files and OziExplorer-style `.map` calibration files. These vendor docs support **a portable georeferencing route that does not depend on copying the entire user registry**; whether the exact current 2019 map's existing sidecar and ExpertGPS-generated `.map` are mutually consistent requires validation, not assumption.

**Required #171 GIS engineering boundary and safe next test:**
1. Preserve the laptop and Show PC registry backups and existing 2019 map, `.tfw`/`.map` sidecars and original geospatial provenance. Do not overwrite any calibration, GPX, map image, or PostGIS location in this reconnaissance.
2. On the PC with the **reviewed correct alignment**, compare its Scanned Map Library entry, `Map Path`, projection/datum, and two calibration points to the other PC's entry **read-only**, using the targeted registry key rather than resurveying from scratch.
3. Prefer reviewing/exporting a portable **`.map` calibration artifact** using ExpertGPS's supported Scanned Map Library Export, and confirm whether a companion worldfile is present and correct; validate it with a disposable copy of the map and known reference control points before changing either active machine's calibration.
4. Only after a verified, portable georeference is agreed should an operator SOP be written for repeatable per-PC installation and tested cross-PC alignment. This is a **scanned-map configuration portability issue**, not a change to the approved GPX waypoint Type→Map Marker association or a reason to hardcode map placement in #319 JavaScript.

**Acceptance remains OPEN:** The registry structure and supported vendor export feature are verified. Cross-PC equivalence, transfer via exported `.map`, correct TFW alignment, and no calibration drift are **not yet tested**.

### Authorization is a hard filesystem boundary

**Public `webassets` publication is exclusively authorized to the Synology administrator who has SMB write permissions.** The desktop manager has no application login, does not determine GIS/Setup roles, and **must not contain embedded administrator passwords or elevation helpers**. Showing a publication button to another user does not confer write access. Other authorized people may inspect approved source, update canonical PNGs if their Google Drive access allows it, and maintain their own ExpertGPS folder; they may **not** publish to either public website directory. No change may relax Synology ACLs merely to allow a volunteer to run the same desktop application. A future delegation decision would require its own explicit reviewed security design.

### Web, map and offline acceptance gates

- **Accepted field evidence (October 12):** administrator-only Synology `msb-svg` publication verified **37** SVG source entries by remote SMB SHA-256: **12 NEW, 3 backed-up replacements, 21 exact-case unchanged, 1 unchanged hash-identical historical-case**. Receipt/backups under `MSB-GIS-Icon-Sync-20261012-071719-e79214`. Seven source-timestamp review notices are not data/hash validation failures. The current Windows user's **37 ExpertGPS PNGs matched canonical hashes**. See the [acceptance evidence below](#accepted-publication-evidence-and-remaining-svg-map-integration--october-12-2026) for exact release details.
- **Not yet accepted:** independent HTTPS/body/visual checks of all map-required published SVGs; especially `stage.svg`, `t-post.svg`, non-square shapes, case-sensitive URLs; full ExpertGPS app and GPX save/reopen; separate PNG web compatibility; Garmin; publisher visible version/buttons.
- **Map consumer design:** the existing Setup Park Map, existing Field Wiring Map and proposed dedicated #230 reference editor are **distinct interfaces sharing maintained PostgreSQL/PostGIS reference authority**. Setup/Field Wiring maps consume reviewed reference locations read-only; #230 is the governed reference-maintenance UI. Retain #88 seasonal Container/Display movement as an independent overlay and retain the existing Field Wiring Controller workflow. A GPX `marker_url` is historical source evidence, not authority to rewrite waypoint identity. Prefer published approved Plain SVGs sized at each file's **native `width×height`**, not forcibly 32×32; use an explicit approved type/asset mapping and meaningful, tested missing-symbol fallbacks. Draft #319's first 15-type map mapping covers 195 of 233 static GPX points; **eight existing `Waypoint`/Anchor symbols (including real `Workshop`) became neutral circles**. That is **an unfinished presentation regression**, not an acceptable removal of waypoints. Also, a missing SVG must not silently become an apparently valid survey marker. Source geometry and database counts are different from image loading.
- **Offline field design:** same existing Park Map must work after *deliberate* per-device download of bounded 2019 orthophoto tiles, local Leaflet and symbol files, GPX names/routes and approved cached reference snapshot. Offline viewing/search/tracks may show an explicitly dated reference revision; **no offline maintenance edits**, no unsourced current Container/Display positions, and no unchecked data promotion. Require actual rugged Android airplane-mode restart and imagery/symbol/accuracy-in-feet review. The PR #361 package now integrated into draft #319 is a tested **candidate**, **not** a Production or field-accepted deployment.
- **PR gate:** #171 icon/media and #230 reference editors are coordinated under #122; no parallel branch may overwrite accepted source-map/PostGIS work. Before merging future code, update this engineering authority for any design change, align the operator SOP when the task changes, run targeted regressions, then collect operator/browser/device acceptance. PR comments contain implementation evidence, **not competing engineering requirements**. No duplicate current-Production dump is needed merely to check a public icon URL.

### Current operator procedures (separate from engineering design)

- [Install or update the manager](../operatorSOP/Install_or_Update_MSB_Icon_Library_Manager.md)
- [Review icons and update local ExpertGPS](../operatorSOP/Review_MSB_Icons_and_Update_Local_ExpertGPS.md)
- [Publish approved Plain SVGs — Synology administrator only](../operatorSOP/Publish_Approved_MSB_SVGs_to_Web.md)

**Earlier October 9–11 sections below are retained as historical investigation, migration evidence and earlier test states.** When historical statements describe a missing app action, unsynchronized web SVGs, an old icon count or a zip-based process, they are **superseded by the CURRENT contract and October 12 verified state above**. Do not use historical handoffs as an active operator procedure.

## Accepted publication evidence and remaining SVG map integration — October 12, 2026

**Controlled source authority:** `G:\Shared drives\Display Folders\Park Drawings\MSB GIS\Symbols\Masters` is for editable Inkscape masters; `Symbols\Plain` contains the *approved* per-layer-variant Plain SVG outputs; `Symbols\png` is the canonical ExpertGPS PNG derivative. Public Plain SVGs are a **separate, administrator-only** controlled publication into `\\192.168.5.4\webassets\images\symbols\msb-svg`, served at `https://webassets.sheboyganlights.org/images/symbols/msb-svg/`. The original local TopoGrafix `msb/readme.txt` supplies a *parent GPX/KML URL* for PNG compatibility, not publication or local installation. Never conflate these separate libraries or silently rewrite GPX feature identity, source track, or old URLs.

**Verified live October 12 release:** Greg ran the updated desktop **MSB Icon Library Manager** from his authorized laptop checkout at merged `main` `f64f78757311b1c4156ed77faeaf6b05722d0b87` (PR #362). Step 1 validated **37** current icons with canonical PNGs all SHA-256-identical (7 nonfatal master-freshness warnings). Step 3 independently preflighted and obtained explicit administrator approval to publish **12 NEW** SVGs (including `stage.svg`, `t-post.svg`, `transformer.svg`, `star.svg`, pole variants, antenna variants and switch variants), replace **3** with retained backups (`car-r.svg`, `lp.svg`, `manhole.svg`), retain **21** unchanged and recognize **1 historical mixed-case file** (`msb-splitter-Combiner.svg`) as exact-byte-identical and **unmodified**. The actual manager completion screenshot states **`Web SVG publication PASS: 37 entries SHA-256 verified; 1 retained historical-case alias`**. Release receipts and changed-file backups are at `G:\Shared drives\Display Folders\Park Drawings\MSB GIS\Symbols\release-history\MSB-GIS-Icon-Sync-20261012-071719-e79214`.

**Precise evidence boundary:** the successful completion verifies the published **Synology SMB files' SHA-256 equality**, but it does **not** verify every public HTTPS URL, correct physical artwork, the existing Setup map's browser rendering, or offline Android operation. Check exact-case HTTPS URLs and native dimensions in the consuming browser. Historical `msb-splitter-Combiner.svg` HTTP 200 / canonical lowercase HTTP 404 had been observed with matching SVG content before the October 12 release; the publication did **not** create a lower-case alias. The live web **PNG** destination `msb` is still separately blocked on the unrelated `IP-camera.png` versus `ip-camera.png` filename-case collision. This does not block Park Map Plain SVGs. The current user's **37 local ExpertGPS PNG file hashes match canonical**; actual ExpertGPS application/export round trip is not accepted and Garmin installation is not implemented.

**Map consumer boundary:** draft commanding PR #319 (`feature/171-cableiq-import-validation` under #122) contains the source-only, unaccepted `Setup/Application/setup_locate_symbols.js` type-to-SVG mapping, native-width/height logic and a bounded offline map package from PR #361. SVG publication alone does not deploy or accept this map. The reviewed static GPX source has 233 point waypoints and 181 tracks; of these, the initial new 15-type mapping covers 195 points, while **eight historical `Waypoint` features (including `Workshop`) previously using `Anchor.png` now display generic circles**, a known presentation regression requiring a reviewed fallback/mapping correction. **32 Stage points** now depend on `msb-svg/stage.svg`; it was newly published in the October 12 release, but fresh HTTPS/browser appearance and #319 disposable/field acceptance remain mandatory. #319's separate PostgreSQL/editor bugs and route/circuit work belong to its owning thread; do not edit GPX or make another DB clone solely to validate symbols.

**Publishing permissions and operational gaps:** Only the administrator's established Synology SMB ACL grants public webasset writes. The desktop manager has **no application login or privileged embedded credentials**. The icon publisher preserves file history and stop-on-mismatch behavior, with 39 source-only automated icon regression tests passing before merge. The desktop program still lacks visible version/build SHA and its web SVG publication-dialog buttons appeared blank in an operator screenshot; these are separate open UX issues, **not accepted fixes**.

For the exact five-step operator flow, use [MSB Icon Library Manager](../../../../../Database/EngineeringTools/README-Icon-Library-Manager.md). Keep the field acceptance proof and future corrections in [Issue #171](https://github.com/Gregovate/MSB-Production-Database-Project/issues/171#issuecomment-6124219004) and its controlled records; web publication is an administrator action, not a crew workflow.

## Routine operator workflow — controlled Icon Library Manager (October 11)

The operator explicitly requested replacing the hours-long ad hoc sequence of PowerShell commands, manual ZIPs in Downloads, per-icon corrections and assistant handoffs with **one repeatable interface**. The canonical Shared Drive artwork, not an old Downloads ZIP or an arbitrary Git checkout, must drive every recurring PNG update. **Hard icon canvas rule: width ≤32 px and height ≤32 px independently**; smaller rectangular widths/heights are expected and valid, with no forced 32×32 resizing. Unitless SVG widths/heights mean CSS pixels; explicit `px` is accepted, but `mm`, `cm`, inches, percentages and larger canvases are rejected with the exact source filename and reason.

### Implemented application and source roles

- **Controlled executable/code authority:** [GIS Icon Library Manager](../../../../../Database/EngineeringTools/README-Icon-Library-Manager.md), with `Install-MSB-Icon-Library-Shortcut.cmd` (one-time Windows Desktop shortcut), `Launch-MSB-Icon-Library.cmd`, `icon_library_manager.pyw` and tested Python engine `sync_gis_icons.py` all maintained in this repository. The operator uses the Desktop shortcut thereafter, **not a remembered PowerShell invocation**. An existing Windows Python with Tkinter and Inkscape `inkscape.com` are prerequisites.
- **Editable artwork:** operator maintains source Inkscape documents under canonical G: `Symbols\Masters`. The visible-layer settings for one-master/multiple-output cases (especially LP-Combo) are intentional source configuration; no algorithm is authorized to guess or hide those layers automatically.
- **Approved exported artwork:** current G: `Symbols\Plain` is the only SVG input for PNG generation. User saves desired Plain SVG versions in Inkscape first. The manager does not modify Masters/Plain or assume timestamps alone prove matching source layers.
- **Canonical PNG derivative:** G: `Symbols\png`. Every icon in the **current** Plain directory is discovered and processed; **no hard-coded count, old ZIP SHA or antenna filename exception**.
- **Persistent audit and backups:** G: `Symbols\release-history\MSB-GIS-Icon-Sync-*` contains per-run SVG and PNG SHA-256 manifest, Inkscape output log, versioned ZIP, diagnostic error on failure, and receipts and backups when changing existing destination PNGs. This **replaces** manually exchanging and accumulating new ZIPs in Downloads.

### Operation and safeguards

1. **Check and preview icons**: validate the entire current Plain directory before attempting export; enforce names/case, XML validity, pixel units and independent 1–32 px limits, no Inkscape/Sodipodi metadata or external-linked assets in Plain copies. Compare inferred editable-master timestamps to the current Plain copies (including the operator-confirmed LP-Combo fan-out); surface possible stale Plain exports as review warnings in the UI, preserve the warnings in release history, and require extra confirmation before applying changes. This is a **warning, not proof** that the visible artwork differs, since native master metadata can change independently of Plain artwork. Invoke Inkscape console exporter for every current icon. Reject export failures, zero/missing output, invalid PNG signature/format or wrong dimensions; verify source SHA-256 did not change during export.
2. Compare staged PNGs to current canonical `png` by exact case-sensitive filenames and SHA-256. Show **NEW**, **UPDATE (backup)**, **Unchanged** with a PNG preview in the GUI; abort on ambiguous case collisions. Unknown unrelated/legacy files remain untouched.
3. **Save approved PNG changes** requires explicit operator confirmation: recheck full Plain source hashes and destination state, back up existing differing PNGs into the run release folder, create new files exclusively, then replace changed files after validated backups, verify each destination hash and write a per-file receipt as the run progresses. On a write interruption do **not** claim a completed release; retain backups and partial receipt.
4. No automatic promotion to **installed ExpertGPS**, no rewritten GPX `type`/`sym`, no automatic Synology/web publication, no browser map marker or draw.io XML/schematic mutation. **Reviewed Plain SVG web publication** is now a *separate*, expressly confirmed third GUI action, not part of PNG scan/save; legacy web `msb` PNG/BMP publication and map consumer migration remain separately governed under #171/#230.

**Validation status:** 12 disposable Python tests PASS for rectangular canvas size, mm/121px rejection, external SVG links/editor metadata, dynamic filename set, source mutation, staging and byte-validation, missing/identical/changed destination PNGs, backups, and case collision. A separate real Linux Inkscape run produced and published a disposable 24×32 PNG successfully, and receipts were verified. **Windows Tkinter GUI / Inkscape console and G: operator acceptance have not yet been executed**: this is an implemented, repository-controlled candidate, not proof of workstation deployment or web publication. The former hard-pinned `Export-ExpertGPSSymbols.ps1` / `Promote-ApprovedGISPNGs.ps1` remain for history/forensics but **are not the recommended ongoing operator interface**.

### Windows first-use feedback: correct car-r Plain derivative and faster nonmodal previews (October 11)

Operator ran the new `MSB Icon Library Manager` successfully on the laptop and found through the actual PNG previews that **the existing right-facing car `car-r.svg` looked like a duplicate of `car-l.svg`**. He changed and saved the editable `car-r-inkscape.svg` master, but initially the preview remained unchanged. Confirmed design rule: **the manager renders the approved `Symbols\Plain\car-r.svg` derivative**, never the editable master itself. Saving only the master does not update that Plain file. The operator must also explicitly Save a Copy as **Plain SVG** into `Symbols\Plain\car-r.svg`, preserving the correct intended car orientation/layers. Only then can the PNG render change, and subsequent source-hash validation protects against an old preview. Do not claim the Plain car or canonical PNG is already corrected until Windows preview and promotion prove it.

The first Windows scan revealed three UX problems: a separate Inkscape console opened for every icon; all icons were rendered repeatedly and scans were slow; and a large modal warning listed eight masters more than one minute newer than Plain (antenna-r, car-r, LP Combo/network/outlet, splitter/combiner, splitter, panel). **These are timestamp/freshness alerts only**, not proof of malformed images or unsafe source identity, especially for LP Combo's intentional single master with multiple layer-derived Plain outputs. No artificial changes to historical SVGs should be made solely to clear these warnings.

**Usability correction:** use `subprocess.CREATE_NO_WINDOW` on Windows Inkscape renderer while capturing stdout/stderr to the persistent per-run diagnostics. Cache only PNG artifacts from a previously **fully verified stage** with an atomically updated release-history cache pointer, verifying **current exact Plain SVG SHA-256 + cached PNG SHA-256 + pixel dimensions** at every lookup; cache misses/changed sources rerender only the affected icons. All current Plain SVGs continue to be validated and the complete source-set and canonical destination are rechecked before write. Show source-freshness warnings through an **on-demand scrollable “Source review (N)”** control and persistent main status instead of interrupting each scan with a modal wall of timestamps. Applying changes still requires explicit confirmation and an additional warning acknowledgement when needed. Recorded UI failure/Windows timing and post-update operator acceptance are tracked under owning #171.

**Follow-up acceptance:** user updates normal laptop checkout and relaunches the existing Desktop shortcut (not a new installer), saves the correct `Plain\car-r.svg` if not yet done, scans twice and confirms second identical scan launches no Inkscape renders/no console flashes and uses hash-verified cache, confirms only genuinely changed icons show `UPDATE` and source warnings are accessible through the Source review control, then performs a governed destination save/receipt. Windows real-G: timing and full promotion still require operator confirmation.

### Operator requirement: always-visible progress during GUI scans and writes — October 11

The operator explicitly requested a **progress meter or activity indicator on every long-running icon manager operation**, not just static messages. Under issue #171, the GUI now displays an always-present indicator for both **Check and preview icons** and **Save approved PNG changes**.

**Progress semantics:** a determinate bar shows actual completed/current total files, percent, and filename only after the icon has passed rendering/cache/hash or destination receipt verification; preflight, backups, source/destination scans, and final ZIP validation use an indeterminate moving bar and clear phase name. The UI reports **Complete** only on successful completion and **Stopped** on exceptions. No ETA is fabricated. Background operations communicate progress through a thread-safe queue, and Tk controls are updated solely on the Tk event thread so the application remains responsive. Source validation, `32×32` maximum dimensions (smaller rectangles valid), immutable master/Plain input roles, approved G: canonical PNG destination, safe backup and receipt rules remain unchanged.

The existing **MSB Icon Library Manager** Desktop shortcut is the permanent entry point; an updated Git checkout is sufficient to load the enhanced UI. The new optional engine callbacks do not force changes on headless callers. Unit tests cover count, names, successful completion, and backed-up destination receipts; Windows UI/Shared Drive performance acceptance is pending operator follow-up. See the controlled [Icon Library Manager runbook](../../../../../Database/EngineeringTools/README-Icon-Library-Manager.md). This is independent of #171 GIS map/GPX track work and does not deploy ExpertGPS, webassets, or draw.io images.

### Field report: Plain SVG assets not published, and Park Map still uses legacy PNG symbols — October 11

The operator reports that the **new Plain SVG artwork has not been synchronized to the live web file server**, so current Park Map icon visual tests are **not accepted as current-artwork tests**. The operator also says the **“new svg format is wrong”**; the exact affected filename, appearance or SVG structure has **not yet been specified or independently validated**. Do not conflate an unsynchronized published file with a malformed `Plain` SVG; source SVG correctness, web asset delivery and browser rendering require independent evidence before calling the issue resolved.

**Verified repository consumer behavior:**

- Canonical editable and released-artwork folders are on G: `MSB GIS\Symbols\Masters` and `Symbols\Plain`. The publicly published **SVG** directory is the separate existing Synology share `\\192.168.5.4\webassets\images\symbols\msb-svg` (URL base `https://webassets.sheboyganlights.org/images/symbols/msb-svg/`).
- In current `Setup/Application/locate_preview.html`, the waypoint reference markers take GPX-derived `properties.marker_url` values from **legacy `https://webassets.sheboyganlights.org/images/symbols/msb/*.png`**, e.g. `Panel.png` / `Outlet_Combo.png`. The map currently forces `L.icon({iconUrl:p.marker_url,iconSize:[32,32],iconAnchor:[16,16]})` for all those waypoint reference markers, potentially distorting legitimate non-square icons. The separate `setup_locate_assets.js` layer still uses legacy `msb/T-Post.png` for independent Display markers and its own local state SVGs for Containers. The HTML map code does **not** reference `msb-svg`. Do not claim that publishing Plain SVGs alone migrates these GPX/map consumers or fixes their square sizing.
- The legacy `msb` published PNG/BMP directory is retained intact; no marker `type`, original GPX `marker_url`, aliases or geometry should be rewritten merely to switch rendering. Separate #171 reconciliation is required to choose mapped canonical assets with fallbacks and preserve waypoint identity and styling. No #88 movement or #319 track/network changes.

**Implemented controlled source-to-web publication step:** The existing GUI now has **3. Review/publish Plain SVGs to web** after a verified source preview. It compares the *entire current Plain source snapshot* against the existing `msb-svg` share by exact filenames and SHA-256, displays NEW/UPDATE/Unchanged, refuses case-clashing destination files or inaccessible share, and requires **a separate explicit public-server confirmation**. The new `publish_gis_svgs.py` helper takes verified source bytes only, backs up any changed server files into the controlled G: release-history run folder, writes by exclusive create or validated same-directory replacement, verifies the remote bytes and saves per-file publication receipts. It never deletes other icons, touches legacy `msb` PNG/BMP symbols, ExpertGPS, GPX, map UI, schema or Production application. Operator can open the selected `msb-svg` URL with a cache-busting source-hash query to independently review public HTTP delivery/appearance. **UNC SHA match alone is not HTTP/browser acceptance.** Real Windows/Synology publishing runtime remains unverified and should be reviewed first on the operator laptop.

**Operator acceptance sequence:** after confirming the corrected `Plain` SVG appearance (and clarifying what “format wrong” refers to), open the desktop manager, select **Check and preview icons**, then **Review/publish Plain SVGs to web**, inspect exact proposed file changes/backups, explicitly approve publication, and visually compare published HTTP SVG URLs with approved Plain source. Separately review the reference map's actual PNG marker aliases and non-square canvas behavior before accepting reference-map icon tests. Issue #171 stays open.

### Full custom-symbol distribution: `readme.txt` is a URL contract, not a copy operation — October 11

The operator supplied his actual ExpertGPS custom-symbol `readme.txt` and correctly identified two remaining distribution gaps: (1) copying reviewed **PNG** derivatives from canonical G: `Symbols\png` to the website's **existing** `\\192.168.5.4\webassets\images\symbols\msb` folder, and (2) installing those same canonical PNGs in the **current Windows user's** `%LOCALAPPDATA%\TopoGrafix\Symbols\msb` folder. Earlier work provided canonical G: PNG generation and a separate `msb-svg` publisher, **not** either of these PNG distribution paths.

The attached `readme.txt` first line is `https://webassets.sheboyganlights.org/images/symbols/` and its instructions explain that ExpertGPS writes custom-symbol web URLs into newly produced GPX/KML/KMZ based on that **parent URL** plus the containing custom-symbol folder name (`msb`) and symbol filename. Another user's ExpertGPS/Google Earth can then retrieve published symbols from the web. **It does not upload, copy, install, synchronize, cache-bust or validate icons by itself**, and it should not include `msb/` twice. Correctly deployed `car-r.png` in local `msb` would correspond to `https://webassets.sheboyganlights.org/images/symbols/msb/car-r.png` once independently published. Do not rewrite old GPX `marker_url` identities while distributing assets.

**Implemented controlled extension to the existing desktop manager:** `Database/EngineeringTools/distribute_gis_pngs.py` adds two **independent, reviewed** controls **4. Publish PNGs to web** and **5. Install PNGs for this ExpertGPS user**, preserving the separate **3. Publish Plain SVGs to web**. Neither action runs automatically on scan or canonical PNG save, and **both refuse to run** if the current G: PNG source library does not match the fully validated current G: Plain SVG source/manifest set. Distinct source and destination rights are deliberate:

- Web PNGs: publish into existing `\\192.168.5.4\webassets\images\symbols\msb`, preserving all legacy PNG/BMP/old-case files and no deletion/renaming. Existing same-name different PNGs are backed up and replaced **only after operator approval and verified destination preflight**. Case-insensitive filename alias collisions refuse to publish, since preserving the old URL and also adding a differently cased filename may be impossible on Windows.
- Per-user ExpertGPS PNGs: resolve active Windows account's `LOCALAPPDATA` dynamically; install only to existing `TopoGrafix\Symbols\msb`. Existing `readme.txt` must be present with correct parent URL/bytes and **is never overwritten**. Missing/invalid local folder/readme refuses copy and requires separate operator setup, rather than constructing an incorrect TopoGrafix identity. Existing legacy BMP/PNG names remain in place. Test with ExpertGPS **closed during installation and restarted afterward**, verifying both a new icon and an old GPX export.
- For either destination: show exact NEW, UPDATE (backup), Unchanged summary; require explicit separate confirmation; re-read exact source and canonical PNG SHA-256 before writing; preserve all changed originals in the same versioned `Symbols\release-history` stage, create new files exclusively, verified same-directory replacements for changed existing files, compare per-file final SHA-256, and write incremental CSV receipts. A partial error never claims complete success.
- Source icons may be any integer canvas from 1 through 32 px on **each axis independently**; no forced 32×32 resizing. Newly added SVGs are discovered dynamically; older ZIP hashes and manually hard-coded 32-/34-icon counts are **not used** for future distribution.
- A verified web file-share copy is **not public HTTPS/GPX acceptance**. Browser-check explicit `https://webassets.sheboyganlights.org/images/symbols/msb/<file>.png` URLs; preserve old marker references, original GPX identities, and historical web filenames. The current existing `Setup/Application/locate_preview.html` reference map still uses GPX-derived **legacy** `msb/*.png` URLs and forces `iconSize:[32,32]`, so aliases and rectangular marker display require separately accepted #171 map-renderer changes.

**Acceptance boundary:** code and disposable tests can establish the safety behavior, but **only the operator's real Windows/Synology test** can establish that either website or user-specific ExpertGPS distribution has completed. No repository merge performs those live copies. Initializing a new Windows account's TopoGrafix `msb` folder is outside this first guarded release. This does not touch `msb-svg` publication, GPX types/URLs, draw.io embeds, Setup/Production database tables, #88 movement data or #319 site networking.

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

### Priority correction status — operator confirmation, October 11

After the first live read-only inventory (454 files, 54 preliminary review flags) and the clarification that `LP-Combo` is a single layered master producing multiple Plain SVG variants, the operator reports: **"all remaining priorities have been corrected."** This is a current operator declaration about the priority artwork/source cleanup, superseding the earlier action list as a statement of *work still to be done*. It does **not** supply new file contents, a fresh inventory, a list of specific rename/delete actions, or a validated master-to-derivative release manifest.

**Verification status remains PENDING.** The prior 454-file CSVs describe the *before-correction* state and must not be treated as current. Next run the repository read-only inventory on the same laptop against the current G: files. Compare only actionable findings against the before-correction baseline, accounting for the verified one-to-many `LP-Combo` layer exports and expected differences between native Inkscape SVG and Plain SVG bytes. Do not require a zero-review-flags count: historical extras and byte variations may legitimately remain. Preserve proof of the actual source versions, names, dimensions, and any compatibility aliases.

A fresh PNG export from the corrected `Symbols\Plain` may proceed **only after** the current inventory confirms the previous noncanonical filename blocker is resolved and that SVG source pairs/derivatives are accepted. The script `Export-ExpertGPSSymbols.ps1` stages PNGs to a separate Downloads folder, **not** to canonical `Symbols\png` or installed ExpertGPS; subsequent reviewed promotion, legacy GPX/URL compatibility verification and publication are separate gates.

This operator correction **does not mean** PNG files were created, copied into the local ExpertGPS `msb` folder, published to Synology, or incorporated into draw.io's embedded artwork. No Production/browser release acceptance is inferred.

### Post-correction report upload — exact baseline duplication, October 11

After stating that all remaining priority artwork corrections were completed, the operator uploaded three files named `summary(1).txt`, `svg_and_raster_inventory(1).csv` and `review_required(1).csv`. A direct local byte-for-byte comparison against the preceding `summary.txt`, `svg_and_raster_inventory.csv` and `review_required.csv` demonstrated that **all three pairs are identical**: hashes exactly match the first 454-file report above (respectively `2f5568864965fac2ea5e2abdfe69d33b70ff54fa458d069d5883fba651e12701`, `12d63e6f74bfb6a8d0b5a95d1aeee873e7be38d455f2b6028966852ed26ebd13`, and `096f05d1f036db8a42f16cd7d421266bfbc07d5b8afeeec5f37f9ed952006994`).

This is **not a verified post-correction inventory**. Possibilities include a duplicate upload of the original Downloads files or a later run with no changes observable under the inventory's scan roots. Do not claim the operator's corrections failed, or treat old flags as current defects. Neither conclusion follows from identical copies.

For an unambiguous subsequent handoff, run the already-merged **read-only** `inventory_gis_symbols.py` with a **new, explicit, timestamped `--output` directory** on the laptop, observe the printed `Reports:` path, and upload a ZIP of that exact directory without selecting previous reports by filename. Record the absolute report directory and run time in the #171 evidence. Compare source-file hashes and actionable findings against the old baseline rather than relying on aggregate flag counts. No PNG generation, promotion or publication may be accepted from the duplicate report alone.

### Actual fresh post-correction inventory — verified October 11, 06:19 local

The operator supplied the **newly generated** `MSB-GIS-Symbol-Inventory-20261011-061917.zip` from the laptop. Unlike the previously re-uploaded identical CSVs, **each new contained report has a different SHA-256 from the old baseline**, and the per-file comparisons show actual source changes. ZIP SHA-256 `cad6835397ec9d459cf86bf57ebeed06e7320e4dc3d1b985fd47cb09a22b721e`.

| ZIP member | Fresh SHA-256 |
| --- | --- |
| `summary.txt` | `4017c012e506b6117bbd970cea72c94fc55ac372daea178d80afa5a2c419fb1a` |
| `svg_and_raster_inventory.csv` | `794877e144d06d85638a419b7ef98d4f03b792de0d0b9f99e435447b7e6e1b31` |
| `review_required.csv` | `25feb8f495e4928fba5531312b41ccec6489dca6c54929fe996fc1363fe42c34` |

**Source state before → after:** 454 → 454 total files; 54 → 47 review flags; 32 → 31 `Masters` SVGs; 31 → 32 `Plain` SVGs; scattered historical SVGs remain 109; installed ExpertGPS PNGs remain 282; zero files inventoried under `Symbols\png`. Inkscape-editor-metadata SVGs decrease 107 → 103, and Plain-like SVGs increase 63 → 67; two invalid XML documents persist only in historical `2023 Upgrade`.

**Three prior release-readiness blockers definitively cleared by fresh file metadata:**
- `Plain\car-r.svg`, `Plain\lp.svg` and `Plain\manhole.svg` no longer retain Inkscape/Sodipodi editing metadata. This is consistent with corrected Plain exports, though not full visual parity proof.
- `Plain\msb-splitter-Combiner.svg` has become `Plain\msb-splitter-combiner.svg`; **identical SHA-256**, so this is a name-only correction. The exporter’s noncanonical filename gate is no longer flagged.
- `Masters\lor-reprater-inkscape.svg` has become `Masters\lor-repeater-inkscape.svg`; **identical SHA-256**, name-only correction. Name-pair missing-master/missing-Plain flags for this logical identity are gone.

**Additional verified changes:** `Masters\stage-32x32-inkscape.svg` is no longer among scanned current Masters; `Plain\star.svg` was added, with approved-looking XML (no Inkscape metadata), 32 × 32 canvas and SVG title `Star`. Existing `Masters\star-inksccape.svg` was modified and now has title `Star`. Five pre-existing editable master paths (`car-r`, `lp-combo`, `lp`, `stage`, `star`) and three pre-existing Plain paths (`car-r`, `lp`, `manhole`) have new *content hashes*. `Plain\stage.svg` has a new modification timestamp but unchanged content hash. In total the compact comparison includes **13 source-change rows**: two content-identical path renames, one no-longer-present master path, one new Plain source, eight content-changed same-path files, and one unchanged-content timestamp update. The separately generated conversation-side delta CSV is `MSB_171_20261011_Inventory_Delta.csv`, SHA-256 `a0041d88b1161ef005f790f69defe468ff9b2a2f03042cf3d072fa3cdd36a90a`.

**Remaining 47 scanner flags:** 42 raw XML/hash variation groups (not 42 verified visual defects), two malformed XML files in historic `2023 Upgrade`, and three name-only pairing hints: `lp-network.svg` and `lp-outlet.svg` are **operator-confirmed intentional layered derivatives** from `lp-combo-inkscape.svg`, while `lp-power-inscape.svg` is a historical extra master without a same-name Plain output. None is the original fatal noncanonical-name/editor-metadata issue. The scanner is not lineage-aware, so these flags are not evidence the LP assets are incorrectly generated.

**Critical separate currency/appearance gate:** `Masters\lp-combo-inkscape.svg` changed on October 11, but `Plain\lp-combo.svg`, `Plain\lp-network.svg` and `Plain\lp-outlet.svg` still bear prior April source timestamps and unchanged hashes. This could be a metadata/title-only master update, or it could mean the configured layer-specific derivatives have not been regenerated after a visible master edit; **the report cannot distinguish these**. The edited `car-r` and `stage` masters were also saved seconds *after* their Plain exports, which by itself does not establish stale artwork. Before **publication**, visually inspect current artwork and its intended layer visibility for LP-Combo, plus any other changed masters. Never overwrite good Plain files on timestamp alone.

**Staging eligibility:** the new `Plain` folder has **32** SVGs (the older documented release snapshot had 31). It is now **structurally eligible for a read-only-source PNG staging export** using `Export-ExpertGPSSymbols.ps1` (no noncanonical Plain filenames flagged; zero Plain SVG parse errors in inventory). That exporter only writes its own new Downloads staging directory; it does not install into `Symbols\png`, TopoGrafix, Synology, browser or draw.io. Confirm whether `star.svg` is intended for the next published release before promoting all 32 staged PNGs. PNG build/runtime, visual parity and ExpertGPS/GPS/web compatibility are **not yet accepted or performed**. #171 remains open.

### Next acceptance step

**Verify the operator-reported completed corrections** with a fresh read-only inventory and staged review of current Masters/Plain contents. Compare with the earlier priority list (including LP-Combo layered derivatives, outlet/power alias choice, LOR spelling, editor metadata, Splitter case, and Stage variants), rather than assuming old report flags are still present or that absence of flags proves visual equivalence. Preserve historical sources and compatibility aliases. After verified source approval, generate PNG derivatives to staging, review eventual `Symbols\png` promotion, and separately validate ExpertGPS, public SVG/PNG URLs, and embedded draw.io artwork. The previous inventory did not include all PCs, archives, web assets or every drawing icon.

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

### Inkscape Windows CLI staging failure and diagnostics — October 11

After the fresh 06:19 current-Plain inventory cleared casing and SVG metadata issues, operator ran the existing `Export-ExpertGPSSymbols.ps1` on laptop `C:\lor\ImportExport\VSCode`. It failed on the **first** file, `car-l.svg` at script line 79 with only the generic exception `Inkscape PNG export failed: car-l.svg`. Because the old script did not surface the renderer exit code/stderr, **the root cause is not yet established**. Do not infer `car-l.svg` is corrupt. The old `msb-plain-icons-corrected.zip` copy of `car-l.svg` was separately tested with Linux Inkscape 1.4 and produced a valid **32 × 18 RGBA PNG**; this is a historical source snapshot, **not** proof the current live G: file renders on Windows.

**Likely environment error / controlled repair:** the exporter previously launched `C:\Program Files\Inkscape\bin\inkscape.exe`, which on Windows is the GUI application. Inkscape provides `inkscape.com` as a Windows **console wrapper** to surface process exit status and CLI output; this is distinct from changing the SVG source. The revised script defaults to `C:\Program Files\Inkscape\bin\inkscape.com`, allows `-InkscapeExecutable` for installations elsewhere, and logs source/output paths, command-line exit status, stdout/stderr and exceptions to `MSB_Inkscape_Export_Diagnostics.txt` within a **new Downloads staging directory**. It still fails closed on nonzero code, missing output, invalid signature, non-RGBA and source-hash changes. PNG IHDR dimension extraction was parenthesized for clarity. A failed attempt leaves its staging folder intact for forensics; **do not reuse the same OutputDirectory**. No file was installed or published by the failed run.

**Windows runtime staging acceptance — OPERATOR PASS, October 11:** the operator retried the merged exporter on the laptop against the current Shared Drive Plain SVG folder and it **completed all 32 SVG→RGBA PNG conversions** without throwing. The actual ZIP/manifest still need to be independently inspected, including image appearance/geometry and intended addition of `star.svg`. This validates the Windows exporter operation on the actual local files; it does **not** validate installation, publication, cross-application compatibility, or visual/source-layer parity. Source SVGs were read rather than modified by the script.

### Successful current-Plain PNG staging run — operator evidence, October 11 at 07:01 local

Command on laptop `C:\lor\ImportExport\VSCode`: `.\Database\EngineeringTools\Export-ExpertGPSSymbols.ps1` (merged repaired version from PR #342). Operator supplied exact successful output:

- `Exported 32 current Plain SVGs to RGBA PNGs.`
- Source: `G:\Shared drives\Display Folders\Park Drawings\MSB GIS\Symbols\Plain`
- Staging: `C:\Users\greg\Downloads\MSB-ExpertGPS-PNGs-20261011-070134`
- ZIP: `C:\Users\greg\Downloads\MSB-ExpertGPS-PNGs-20261011-070134\MSB_ExpertGPS_Current_Plain_Staged.zip`
- Explicit end-of-run safeguards: `NOT installed to local ExpertGPS. NOT published to Synology.`

**Outcome: Windows exporter staged-batch execution PASS, downstream acceptance NOT YET REVIEWED.** This success establishes the revised `inkscape.com` approach completes for the operator's current 32 Plain SVGs and built-in output/source checks returned successfully. It is not yet proof that all PNGs are visually faithful, all expected canvas sizes are correct, that the manifest and ZIP contain exactly the intended identities/bytes, or that the new `star.svg` should be in a published 32-icon set.

**Next evidence:** obtain the exact staged ZIP and optionally `MSB_ExpertGPS_PNG_Inventory.csv` plus `MSB_Inkscape_Export_Diagnostics.txt` from the staging directory. Verify SHA-256 for each staged PNG against the manifest, 32 PNG names and sizes including rectangular canvases, copied unchanged `readme.txt` parent URL, transparent alpha and visible rendering; compare the layered LP-Combo exports with the approved master visibility configurations. Record release selection and alias mapping before copying into canonical `Symbols\png`, installed ExpertGPS `msb`, Synology/web symbols or draw.io. The next promotion should not remove legacy PNG/BMP aliases or rewrite GPX types.

### Independent QA of the uploaded 32-PNG staging ZIP — October 11

**Result: ZIP/manifest integrity PASS; artwork release requires specific operator review.** The operator uploaded the actual `MSB_ExpertGPS_Current_Plain_Staged.zip` from the successful 07:01 laptop stage. SHA256 of that received ZIP: `4a19c4ec1b0f7c50f95674d4f48e6500b5246390257085ab9d072bcfe3f3000a`. It contains exactly **34 files**: `msb/` has **32 PNGs + one unmodified `readme.txt`**, and the ZIP root has one manifest CSV (`MSB_ExpertGPS_PNG_Inventory.csv`). ZIP CRC integrity passes, no duplicate entries or unlisted payloads. The `readme.txt` SHA256 is `69115edd6b8dcf97db836179e014c9221e0f8eba62033703e35b1411a18e9b59`; bytes match the previously supplied original `readme.txt`, with first line `https://webassets.sheboyganlights.org/images/symbols/`.

All **32 manifest PNG SHA-256 hashes** match actual decoded ZIP members, all **32 SVG source SHA-256s match the fresh 06:19 G: Plain inventory**, and all PNGs load as **RGBA** with manifest dimensions exactly matching the saved canvas. All 32 have visible (nonzero alpha) content. Non-square sizing matches the accepted baseline (32×18 cars, 24×24 splitter/repeater, 32×16 switches, 16×32 T-post); all other expected icons have the documented 32×32 canvases, including the new `star`.

**Independent pixel-level regression against the prior 31-icon October 9 PNG snapshot:** 30 existing symbols are pixel-identical. `lp.png` changed **276 of its 1,024 pixels**: prior icon had light pole *with* blue network and red outlet glyphs; new `lp.png` is the **bare pole**, while `lp-combo.png`, `lp-network.png` and `lp-outlet.png` retain their separate established variants. This matches the stated intent of distinct layered presentations but **must be approved by the operator for mapping/reference meaning**. `star.png` is **new** (32×32, blue square with white star), bringing the prospective set to 32; no release inclusion decision is documented.

**Semantic image finding / publication hold:** `fire-hydrant.png` and `manhole.png` both visibly depict a white hydrant silhouette on a red square; they have slight differences in border/pixels and are **not bit/pixel-identical**, but are visually the **same type of symbol**, contrary to their names. Both icons were also the same respective artwork in the older PNG snapshot, so the issue is inherited, **not a regression from the exporter**. Ask the operator whether `manhole` is intentionally a hydrant-style placeholder or should be separately corrected. Do not unilaterally substitute an invented manhole graphic or rewrite identities.

**Alpha-channel nuance:** Both `fire-hydrant.png` and `manhole.png` have 1,024 fully opaque pixels (RGBA min=max 255), while `panel.png` has no fully transparent pixels (minimum alpha 209). These are technically valid **RGBA** files, but a PNG with an alpha channel need not have transparent surroundings. Confirm the intended opaque square tile treatment in ExpertGPS/browser mapping, especially manhole/hydrant, instead of assuming it meets a transparent-overlay appearance requirement. Other 29 PNGs have some fully transparent pixels.

The independent report `MSB_171_ExpertGPS_PNG_Staging_Audit_20261011.csv` (conversation artifact, **not** committed source input) SHA256 `93d80f10d79b797a274f9245ca400b41ac7adc0fb09191bea3d7a634d43b761d` records every icon, hashes, dimensions, visible alpha and Oct 9 pixel comparison. Verification was confined to the **uploaded ZIP**, its recorded source hashes and the earlier ZIP; it did not read the live Synology, update the G: `Symbols\png` folder, inspect the current master layer state, install ExpertGPS files or open mapped GPX/type references.

**Decision gate:** integrity accepted for staged source review; **do not mark the complete set approved for canonical `Symbols\png`, ExpertGPS or web publication** until operator adjudicates `manhole` versus `fire-hydrant` appearance, confirms standalone `lp` meaning and approves or excludes `star` for the next release. Then record exact-file release manifest and preserve old ExpertGPS/GPX/public URL aliases and draw.io embedded artifacts. Keep Issue #171 open.

### Operator clarification and 07:24 follow-up PNG export — October 11

**Supersedes the tentative semantic interpretation of the 07:01 staging audit, but does not rewrite its historical findings.**

- **Manhole:** the operator supplied a distinct corrected `manhole.svg` artwork and explicitly confirmed that the `Plain\manhole.svg` used for the *07:01* export was **wrong**. The earlier hydrant-like depiction was an **incorrect Plain source**, not an intentionally shared manhole/hydrant symbol or an exporter error. The correct source is the newly attached SVG; do not invent a replacement. The source copy and resulting `manhole.png` in the next staged ZIP must be checked against that attachment before declaring correction verified or authorizing publication.
- **Standalone light pole:** the operator confirms the current-day `Plain\lp.svg` and the associated new bare-pole `lp.png` are **correct**. The older pole-plus-network/outlet artwork belongs to the *combo* light-pole concept with independent `lp-combo`, `lp-network` and `lp-outlet` derivative presentations. **Remove any pending approval hold on the intentional standalone LP appearance; preserve the separate combo variants.**
- **Star:** whether newly added `star.png` belongs in the upcoming release is **still an independent unresolved inclusion decision**.

After this clarification, the operator reran `Export-ExpertGPSSymbols.ps1` and posted a PowerShell listing of the newest 07:24 local staging directory showing:

| Staged item | Operator-observed size / time |
| --- | --- |
| `msb` directory | last modified 2026-10-11 07:24:02 local |
| `MSB_ExpertGPS_Current_Plain_Staged.zip` | **39,370 bytes**, modified 07:24:02 |
| `MSB_ExpertGPS_PNG_Inventory.csv` | 5,836 bytes, modified 07:24:02 |
| `MSB_Inkscape_Export_Diagnostics.txt` | 8,951 bytes, modified 07:24:02 |

**The latest exporter DOES produce a ZIP:** the ZIP is inside the staging directory, not necessarily beside the Git repository or in the Downloads root. The posted listing demonstrates its existence and output timestamps, but is not an independent integrity/artwork inspection of this second batch. Do not conflate the second 07:24 package with the audited 07:01 ZIP; the second ZIP has **not yet been uploaded and compared**. Next request that exact ZIP, check the `manhole.png` pixel content against the operator-supplied corrected `manhole.svg`, verify the 32-item manifest/PNG SHA-256 list and compare unchanged icons against the prior audited batch. If only the intended manhole art changed, gate independent release/alias checks after Star disposition. **No canonical `Symbols\png` promotion, TopoGrafix installation, Synology web publication or draw.io schematic update is inferred.**

### Independent acceptance of corrected manhole re-export ZIP — 07:24 batch, October 11

**Staged derivative QA PASS; the prior source-artwork hold on `manhole` is RESOLVED.** Operator uploaded `MSB_ExpertGPS_Current_Plain_Staged(1).zip` from the subsequent 07:24 export. This is a **different and later package** than the audited 07:01 staging archive, and was independently compared file-by-file against that earlier ZIP and the operator's attached correct `manhole.svg`.

| Verified input / output | SHA-256 |
| --- | --- |
| Newly uploaded 07:24 staging ZIP | `85569dc7cafa1da169bd68244bb9757daadfb53c1d02e911256790d0c6a63e53` |
| Correct operator-supplied `manhole.svg` | `6aac9641f3964787dc7db54e2bf6c023f335875abd30f6f5e891085a23f6978d` |
| Correct `msb/manhole.png` in new ZIP | `bf835b6e2ee67a6812b4c01501d450933161815cb3e4e506bd7d514e60df9e39` |
| New internal PNG inventory manifest | `aff048898f3e4df7128cda79822dbd3fa77df68a5a1412a91227433eec7e6573` |
| Unchanged original ExpertGPS `msb/readme.txt` | `69115edd6b8dcf97db836179e014c9221e0f8eba62033703e35b1411a18e9b59` |
| Independent 32-row audit report (conversation artifact) | `7428e6eaaa42f61030297089c3acfe75b01572cb21f309fc6cc6f15f67aab5f6` |

**Completed checks:**

- ZIP CRC integrity passes, with the exact expected **34 files**: 32 unique `msb/*.png`, one `msb/readme.txt` and one `MSB_ExpertGPS_PNG_Inventory.csv`, with no extra image files.
- All 32 PNGs decode as **RGBA**; dimensions match each manifest record, and all 32 individual image SHA-256 hashes match that manifest.
- **Exactly one icon changed from 07:01:** `manhole.png`. The other **31 PNGs remain byte-for-byte identical**, and their manifest source SVG hashes also remain unchanged. Manhole's source SVG SHA-256 changed from `9b74037f9551db5c918d1b427d46cf5be42c6597c9644ca0dcc120e7cfcbcc45` to `6aac9641f3964787dc7db54e2bf6c023f335875abd30f6f5e891085a23f6978d`, **exactly matching the corrected attachment**. This verifies the source was replaced as intended, not just relabeled.
- The **new manhole is genuinely distinct from the hydrant**: its artwork is a circular manhole/utility-cover marker rather than the previous white hydrant silhouette on a red tile. Its output remains **32×32 RGBA**, with **300 transparent pixels**. A fresh Inkscape rendering of the exact attached `manhole.svg` was independently compared to staged `manhole.png`: **zero differing RGBA pixels**. Current `fire-hydrant.png` is unchanged from the previously audited ZIP.
- Existing `lp.png` remains unchanged from the first successful 32-icon batch and the operator already approved its current **bare standalone pole**. The older combo pole is correctly represented by separate `lp-combo` / `lp-network` / `lp-outlet` symbols; the prior LP semantic hold is closed.
- `star.png` is **unchanged** from 07:01 and newly introduced relative to the older 31-icon baseline. **Operator later explicitly approved Star for inclusion in the 32-icon release on October 11**; source/artwork acceptance remains the same, while governed installed/public GPX alias and browser/draw.io compatibility validation is still pending.

The current **32-icon PNG staged artwork batch**, including `star.png`, is **source/manifest/image-integrity accepted and operator-approved in scope for release planning**, **not automatically approved for deployment**. It has **not** been copied into canonical G: `Symbols\png`, installed in ExpertGPS, published to Synology or browser/webassets, or substituted into existing embedded draw.io schematic icons. Preserve old ExpertGPS filename aliases and source GPX symbols; do not silently rename. The reviewed 07:24 ZIP, rather than the outdated 07:01 package, is the candidate for any further release gate.

### Operator's Star inclusion decision — October 11

The operator explicitly responded **“yes we can add the star”** to the question of whether the newly generated `star.png` belongs alongside the other 31 symbols. **Decision: include `star.svg` → `star.png` in the planned, controlled 32-icon MSB GIS release.** No additional SVG/PNG rendering or 31-icon rollback is needed: the already audited corrected **07:24 ZIP** contains the accepted 32 icon identities and `star.png` matches its audited manifest. The older 31-icon inventory and package remain historical baselines only.

| Release-selection item | Decision |
| --- | --- |
| Staged release candidate | **07:24 corrected 32-icon package**, SHA-256 `85569dc7cafa1da169bd68244bb9757daadfb53c1d02e911256790d0c6a63e53` |
| `manhole.png` | **Approved corrected** circular manhole, exact match to attached SVG and independent pixel render |
| `lp.png` | **Approved** bare standalone light pole; combo/network/outlet symbols are distinct variants |
| `star.png` | **Approved for inclusion**, 32×32 RGBA; new relative to original 31-file baseline |
| Selected icon count | **32** |
| Image file/hash and manifest integrity | **PASS** for complete selected batch |
| Canonical `Symbols\png` copy | **Not yet performed or verified** |
| Installed ExpertGPS and existing GPX custom type/filename alias compatibility | **Not yet performed or verified** |
| Synology/web/browser SVG/PNG deployment and draw.io embedded artwork | **Not yet performed or verified** |

**Next controlled phase:** establish a versioned, collision-safe promotion from the accepted staging ZIP to `G:\Shared drives\Display Folders\Park Drawings\MSB GIS\Symbols\png` without changing source `Masters`/`Plain`. Compare destination contents and preserve/backup any existing files before writing; confirm SHA-256 matches the staged release afterward. ExpertGPS `%LOCALAPPDATA%\TopoGrafix\Symbols\msb`, Synology `webassets/images/symbols/msb` and `msb-svg`, GPX type names/URLs, browser marker lookup and draw.io's embedded libraries/schematic are **separate governed propagation/compatibility gates**. This decision **authorizes Star's inclusion in the proposed icon set, not an unreviewed installation, rename/delete of legacy symbols, web publication or Production deployment**. Issue #171 remains open.

### Controlled promotion to canonical Shared Drive PNG derivatives — approved batch, October 11

**Target / authority:** `G:\Shared drives\Display Folders\Park Drawings\MSB GIS\Symbols\png` is the canonical local/shared **derived PNG library**, separate from editable `Masters`, approved `Plain` and the local ExpertGPS or public web libraries. The operator agreed to populate it with the accepted **corrected 07:24 batch containing all 32 icons**, including newly approved Star.

The verified ZIP release SHA-256 is `85569dc7cafa1da169bd68244bb9757daadfb53c1d02e911256790d0c6a63e53`. Its 32-row CSV manifest maps each PNG hash back to the exact current `Plain` SVG hash and canvas. Do **not** use the earlier 07:01 batch, which contained the incorrect manhole artwork.

Use [`Promote-ApprovedGISPNGs.ps1`](../../../../../Database/EngineeringTools/Promote-ApprovedGISPNGs.ps1) from the operator's updated laptop Git checkout. This is a fail-closed, **non-destructive** local-file operation. It searches Downloads staging folders for the exact approved ZIP hash; an explicit `-ZipPath` can be supplied if the archive moved. The tool validates:

1. Exact release ZIP SHA-256, 34 approved archive members (32 PNG, readme, inventory CSV) and no duplicate/case-clashing member names.
2. Copied unchanged ExpertGPS `readme.txt` SHA-256 and expected parent URL; 32 manifest rows, canonical lowercase PNG names, each PNG's SHA-256/RGBA signature/canvas and each corresponding **live G: Plain SVG SHA-256**.
3. Destination filenames and bytes. **Identical existing PNGs are retained**. Any existing different PNG with the same name, or a case-only filename collision, aborts **before writing**. Unrelated/legacy filenames are never removed.
4. With explicitly requested `-Apply` only: creates missing approved PNGs using exclusive create-new file mode, checks each final destination hash, writes a receipt CSV alongside the Downloads ZIP. It **never overwrites an existing PNG**, so no historical content needs to be displaced or silently archived. Any destination conflicts require separately reviewed backups and name/alias reconciliation before a later run.

First run **without `-Apply`** (read-only preflight); review count of missing, matching and conflicting files, especially whether canonical `png` currently exists and what it contains. Then apply separately, record the receipt and verify exactly 32 current approved derivatives. A staging ZIP is not the canonical folder itself; the promotion fills the authoritative G: derived-asset location.

**Acceptance not yet claimed:** as of this change, no tool execution on the operator's actual Windows G: drive has been reported, and no canonical `png` file copy is independently verified. This operation does **not** install or alter ExpertGPS `%LOCALAPPDATA%\TopoGrafix\Symbols\msb`, Synology `webassets/images/symbols/msb` / `msb-svg`, GPX/custom-marker type values, browser GIS markers, or draw.io's embedded library/schematic snapshots. Those are independent preservation/publication gates under #171; never automatically propagate local edits into live web assets.

### Wi-Fi antenna L/R icons added to source library — October 11 operator update

Following acceptance of the corrected **32-icon** 07:24 staging release candidate (including `star`), the operator reports adding **two more Inkscape master files and matching Plain SVG outputs** for previously missing Wi-Fi antenna icons, identified as `antenna-l` and `antenna-r`. **Intended full library is now 34 icon identities** (32 previously audited plus left/right Wi-Fi antenna symbols). Exact new file paths/bytes, icon dimensions, visibility, orientation and PNG output have **not** yet been independently inventoried or reviewed. Do not invent names for the editable Inkscape masters based on the Plain filenames; only the identities `antenna-l` and `antenna-r` are operator-confirmed.

**Changed release boundary:** the existing approved 07:24 ZIP SHA256 `85569dc7cafa1da169bd68244bb9757daadfb53c1d02e911256790d0c6a63e53` and its pinned promoter represent a **32-icon snapshot**. They no longer establish a complete current Plain-to-PNG asset set once the two antennas exist. The initial promoter validated the 32 known live source hashes but did not verify the absence of new Plain SVG files: a material **source-set completeness gate** was missing. The revised promoter now checks **exact manifest-versus-current-Plain SVG filenames/count, including case and additions**, before dry-run acceptance and rechecks sources immediately before any `-Apply` writes; it refuses to promote incomplete or stale 32-icon batches. Preserve the immutable 32-icon ZIP and its previous independent audit as historical release evidence; do not quietly change the hard-pinned ZIP hash or declare the newer artwork accepted without review.

**Next steps:** confirm whether the previously authorized `-Apply` was already executed (and obtain any 32-icon receipt) before the antenna addition; inventory the actual current `Masters`/`Plain` and verify `antenna-l.svg`/`antenna-r.svg`, then rerun `Export-ExpertGPSSymbols.ps1` into a **new** unique Downloads stage. Expect **34** PNGs *if both Plain antenna files are present*, but verify actual output count, two antenna canvas sizes, visual left/right distinction, source/PNG hashes, original ExpertGPS readme and the 32 earlier approved icons. After the complete candidate has been reviewed and its **new SHA256 approved**, update/pin the governed promotion candidate and dry-run collision check. If 32 PNGs were already copied earlier, the next promotion should find those as identical and add only the two missing antenna PNGs (unless earlier sources genuinely changed); no overwriting or legacy deletion. Later ExpertGPS/webassets/draw.io publishing and GPX alias checks remain separate controlled gates.

**Status:** new operator source-addition reported, not yet independently verified; planned 34-icon release not yet exported or approved. Existing 32-icon package and its merge decisions remain historically valid. No new PNG library, web or Production change is inferred by this note.

### Independent review of newly uploaded 34-PNG antenna L/R staging ZIP — October 11

The operator uploaded `MSB_ExpertGPS_Current_Plain_Staged(2).zip`, an actual third Windows export with the newly added `antenna-l` and `antenna-r` symbols. The uploaded ZIP is **53,765 bytes**, SHA-256 `da27a035d2265a4c664338160e052efefabc8490569e487ed12faec9d99d76ed`, and passes Python ZIP CRC verification. It contains **36 file entries**: 34 unique `msb/*.png` entries, the original `msb/readme.txt`, and one root `MSB_ExpertGPS_PNG_Inventory.csv`.

| Reviewed item | SHA-256 or observation |
| --- | --- |
| New 34-icon ZIP | `da27a035d2265a4c664338160e052efefabc8490569e487ed12faec9d99d76ed` |
| New 34-row manifest | `3d472ec92fb491d3e53d5dee8cbfec3c48ea70beb9d25fe9602126743b6c3c1d` |
| Original readme.txt | `69115edd6b8dcf97db836179e014c9221e0f8eba62033703e35b1411a18e9b59` (same bytes as prior reference) |
| `antenna-l.svg` source hash (as reported by manifest, not independently fetched live) | `b4ae485ddb81a3d33135e98a8f9706aac547045680ae6c0c8043b15fad662299` |
| `antenna-l.png` output | `cb12679ffafda0eba6e80963ed247b0c18846e84783ce2543b661531825a6d5d` |
| `antenna-r.svg` source hash (manifest) | `46d50a6390d8930eecb687ad85e29fbe223c13ef293ae779e58a7a24bd9e21fa` |
| `antenna-r.png` output | `206ded5ea270d2d1d84fdf393bf9209151f886e3b5777b2882da7618138afdd1` |

**Manifest and image integrity PASS:** 34 unique manifest rows, **34/34** actual PNG bytes have the recorded PNG SHA-256; 34/34 decode as RGBA; dimensions equal their manifest numbers; no ZIP CRC errors. The unchanged original ExpertGPS readme SHA-256 matches the preceding verified release exactly. The **previous 32 icons are unchanged byte-for-byte and unchanged by source hash** versus the independently verified corrected 07:24, 32-icon ZIP (SHA256 `85569dc7cafa1da169bd68244bb9757daadfb53c1d02e911256790d0c6a63e53`). The two new assets are the only additions; no artwork regression in Manhole, standalone LP or Star.

**Visual check / explicit size decision still needed:** The two antenna symbols are distinctly opposite-facing turquoise directional dish/antenna illustrations. Both output PNGs have a **121 × 121 px** canvas (bounding alpha boxes `(7,3)-(114,114)`); their alpha channels include transparent surroundings. That is significantly larger than the existing icon canvases (typically 32 × 32 px), though it is not a file-format or manifest error. **Do not presume the 121 px size is a defect or approve a scale change without asking the operator.** Request whether 121×121 is intentional for the mapped icons, or whether the operator wishes to adjust editable/master canvases and re-export approved Plain SVGs before a released 34-icon ZIP. Do not resize automatically or silently force all canvases to 32×32; preserve intended shapes and existing pixel scales.

An independent per-icon report `MSB_171_34_Icon_Staging_QA_20261011.csv` (conversation artifact) has SHA-256 `1580671a7fb800400a7503bd62c2428726214106dac2d465a0f7d19ef20ae769` and reports hashes, dimensions, visible alpha, and unchanged/new status for all 34 items. A visual contact-sheet comparison `MSB_171_Antenna_34_PNG_Review.png` was also prepared from the actual ZIP. **Not independently verified from live Windows Shared Drive:** the newly reported antenna SVG bytes/canvases, their Inkscape master lineage, or whether the previously approved 32 icons were already added to `Symbols\png` by the operator. This review does **not** prove currently installed ExpertGPS, Synology, browser or draw.io marker behavior.

**Release gate:** the existing `Promote-ApprovedGISPNGs.ps1` is still deliberately pinned to the earlier 32-icon ZIP/count, and its source-set guard now rejects incomplete input. **Do not run `-Apply` with the 32-icon candidate**. After operator acceptance of antenna scale/appearance and independent validation of the actual current 34-file `Plain` set, prepare a separately reviewed 34-icon pinned promotion script, then perform read-only destination preflight and governed additive promotion of missing files. Preserve any already promoted 32 PNGs and their receipt; never overwrite legacy filenames/GPX references. Keep #171 open.

### Operator correction: Wi-Fi antenna Inkscape document units were millimeters — October 11

Following the first independently audited 34-icon batch in which both `antenna-l.png` and `antenna-r.png` measured **121 × 121 pixels**, the operator explained the source problem: **the Inkscape documents were set to millimeters (mm), not pixels (px)**. He reports **changing the units to px and resizing both left/right antenna illustrations**. This resolves the operator decision about whether the previous large size was intended: **it was not**.

**Correction status:** reported applied by the operator in the local editable artwork; **actual new master file bytes, current Plain SVG exports, canvas dimensions, and resulting PNG files have not yet been independently inspected**. Do not infer the corrected size is 32 × 32, or that both Plain derivatives have been refreshed, merely from the units statement. The authoritative G: source must be checked for the two `antenna-l.svg` / `antenna-r.svg` files after the operator's changes. Keep the old 121 × 121 version and its hashes above as a dated, superseded staging snapshot for provenance, not as the desired release.

**Next stage:** rerun `Export-ExpertGPSSymbols.ps1` from the actual current Shared Drive `Symbols\Plain` folder into a **new** timestamped Downloads staging folder, expecting 34 PNG files if all intended source icons remain. Upload the newly produced `MSB_ExpertGPS_Current_Plain_Staged.zip` (from inside that new staging directory); check exact new antenna pixel dimensions, visible left/right graphics, manifest/source SHA-256, and confirm all previous 32 accepted PNGs remain unchanged. If the exporter still returns 121 × 121 for either antenna, check the saved **Plain SVG** width/height/viewBox versus the revised Inkscape master and explicitly re-export the intended Plain file before regenerating PNGs.

**No promotion authorization by this correction alone:** `Promote-ApprovedGISPNGs.ps1` remains intentionally pinned to the old 32-icon ZIP and cannot be used to promote a 34-file library. After accepting a fresh corrected 34-icon ZIP, update the governed exact ZIP SHA/promotion manifest as a reviewed separate change, dry-run the canonical `Symbols\png` destination, and preserve any previously installed files and GPX legacy aliases. Nothing here installs ExpertGPS, syncs Synology/browser assets, updates draw.io embedded artwork, or mutates Production.

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

- Current approved `Masters`/`Plain` assets and **37** canonical PNG derivatives were reviewed through the Windows Icon Library Manager; the current user's local ExpertGPS `msb` folder **matched all 37 PNG hashes** on October 11–12. This proves local file synchronization, **not** real ExpertGPS application/GPX export acceptance. The older October 11 31-PNG ZIP/readme is historical, not the active current library. Public Synology **SVG** publication is verified by hash on October 12 as recorded above; the distinct Synology `msb` **PNG** publication remains blocked on a mixed-case `IP-camera.png` filename, and legacy PNG/BMP aliases remain intact. Preserve the local `msb` folder and do not move it to `MSB Icons` without an explicit backward-compatibility review.
- The October 12 administrator publish verified **37** current Plain SVG entries against their Synology SMB counterparts by SHA-256. **Full public HTTPS/individual symbol appearance validation remains open**; the earlier single `container-loaded.svg` browser test is now only historical, not the whole publication status.
- A complete reusable symbol registry and GPX/ExpertGPS old/new URL alias inventory are **pending**; don't mark them deployed based on this document.
- Reconcile active #171 map candidates and #230 editor direction before updating browser symbol lookup or databases. Do not overwrite concurrent #171/#319 work.
- For any production code, schema or server mutation, follow project rules and governing Server Management runbooks; this document is documentation-only.

See [Site Infrastructure / GIS README](../README.md), [#171](https://github.com/Gregovate/MSB-Production-Database-Project/issues/171), and [#230](https://github.com/Gregovate/MSB-Production-Database-Project/issues/230).
