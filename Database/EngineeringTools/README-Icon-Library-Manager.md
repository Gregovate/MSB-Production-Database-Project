# MSB Icon Library Manager — one-time setup and normal use (Issue #171)

**Purpose:** stop generating temporary ZIPs in Downloads or remembering PowerShell commands for each new icon. The manager is a versioned GitHub tool, reads the authoritative Google Shared Drive files directly, and keeps one controlled audit/release history in the Shared Drive.

## Actual Windows/Synology release status — October 12, 2026

**Web Plain SVG publication PASS — verified in the operator's administrator session.** On the normal Windows laptop checkout `C:\lor\ImportExport\VSCode`, fast-forwarded to `main` `f64f78757311b1c4156ed77faeaf6b05722d0b87` (merged PR #362), the manager's **1. Check and preview icons** validated all **37** approved current Plain SVG inputs and found **37 matching canonical PNG derivatives** (0 new / 0 changed). Seven editable-Master-versus-Plain timestamp warnings remained visible in **Source review (7)**; these are review reminders, not failed source hashes.

The operator then ran **3. Review/publish Plain SVGs to web** and expressly confirmed the LIVE Synology publication. The complete `\\192.168.5.4\webassets\images\symbols\msb-svg` preflight and publication receipt reported:

| Destination result | Count | Details |
| --- | ---: | --- |
| NEW | **12** | Includes previously missing `stage.svg`, `t-post.svg`, `transformer.svg`, `star.svg`, the two antenna variants, and switch/pole variants |
| UPDATE (backup) | **3** | `car-r.svg`, `lp.svg`, `manhole.svg` |
| Unchanged exact-case | **21** | Destination hashes already matched |
| Historical-case, unchanged verified bytes | **1** | Existing `msb-splitter-Combiner.svg` remains under its original capitalization |
| **Total source SVG entries SHA-256 verified on SMB** | **37** | Manager displayed **Web SVG publication PASS** |

The versioned receipts and replacements' backups are in the operator-confirmed Shared Drive release folder:
`G:\Shared drives\Display Folders\Park Drawings\MSB GIS\Symbols\release-history\MSB-GIS-Icon-Sync-20261012-071719-e79214`.

**Acceptance boundaries:** This is an observed **Windows/Synology SMB publication/hash PASS**, **not** an independently accepted public HTTPS rendering test, offline tablet installation, or Production Park Map deployment. Verify exact published URLs such as `https://webassets.sheboyganlights.org/images/symbols/msb-svg/stage.svg` in the browser. The historical-cased splitter's lowercase URL was separately observed to return HTTP 404; the manager deliberately did not rename it or claim that alias is live. The live website PNG `msb` action remains blocked on the unrelated `IP-camera.png` versus `ip-camera.png` case collision, and is not required for the Plain SVG Park Map. The user's local ExpertGPS `msb` folder passed a **37-file canonical PNG hash comparison**, but actual ExpertGPS UI/GPX round-trip acceptance and Garmin device installation are separate.

**Access rule:** Only the authorized Synology administrator has write permission to the webassets share. The desktop manager has no application login and may be used for preview or local ExpertGPS updating without granting web-publish permissions; the SMB ACL, not a GUI button, enforces the publication boundary. Do not embed or distribute elevated credentials.

**Unfinished UI and map gates:** The manager does not yet display a version/build SHA, and the LIVE SVG review's confirmation/cancel buttons appeared as blank rectangles in an operator screenshot; do not guess an unlabeled live-action button. The separate #171/#230 commanding PR #319 includes proposed Plain SVG/natural-size map rendering and a bounded offline package; it still requires browser/operator acceptance and correction of fallback marker coverage (eight source Waypoint/Anchor symbols became neutral circles). Do not treat successful web icon publication as proof that the map, source registry, or tablet offline experience is accepted. No new database clone is necessary merely to verify a public SVG URL.

## Install once on a Windows workstation

1. Update your normal local Git checkout when repository code changes (the laptop primary checkout is `C:\lor\ImportExport\VSCode`). Do not use a disposable review worktree or overwrite unrelated changes.
2. In Windows File Explorer, open the repository's `Database\EngineeringTools` folder.
3. **Double-click `Install-MSB-Icon-Library-Shortcut.cmd` ONCE.** This creates the desktop shortcut **MSB Icon Library Manager**. It does not copy assets, create PNGs or run any release.
4. Use that desktop shortcut for every subsequent icon update. If you move the repository checkout, repeat the shortcut installer. The launcher uses the checked-out `.venv` Python or a discovered Windows Python installation with Tkinter. Inkscape must be installed with Windows `inkscape.com` available.

## First Windows operator review — performance and source-freshness correction (October 11)

The first real laptop preview successfully exposed an error: **`car-r.svg` was visually the same as `car-l.svg`**. Operator corrected the editable `car-r-inkscape.svg` master, but the PNG preview did not change because the tool intentionally renders **`Symbols\Plain\car-r.svg`, not editable `Masters`**. Saving a master does not update its Plain derivative. **In Inkscape, also Save a Copy as *Plain SVG* to `Symbols\Plain\car-r.svg`**, replacing the incorrect previous Plain file (choose correct layer visibility before saving). Rerun the preview: corrected `car-r.png` should be **UPDATE (backup)** if it differs from the canonical PNG, or **NEW** if the folder was not yet populated. This manual source-to-Plain decision is necessary for layered variants; the manager must not guess it silently.

Other reported usability failures during first Windows run: Inkscape spawned a visible Windows command window once **per rendered icon**, full library rendering was slow, and a large modal listed eight `master newer than Plain` timestamps (antenna-r, car-r, LP Combo/network/outlet, MSB splitter/combiner, splitter, panel). **Freshness timestamps alone are not artwork-content differences**; LP Combo is intentionally one editable master driving multiple different layer-selected Plain exports.

The follow-up manager correction:

- Launch Inkscape with Windows `CREATE_NO_WINDOW` while retaining its stdout/stderr and exit status in `Inkscape-export.log`, so no console window flashes once per icon.
- Cache **only validated stage PNGs** under canonical `Symbols\release-history`, with an atomic `MSB_GIS_Preview_Cache.json` index. For each icon, always reread and XML-validate the current Plain SVG; reuse its staged PNG only if **current exact Plain SVG SHA-256**, PNG SHA-256, and width/height match. Otherwise **re-render that icon only**. Corrupted or missing cache falls back to Inkscape; staging ZIP, readme, source hashes and canonical PNG destination checks remain unchanged. The index is an optimization, not approval or a source of authority.
- Replace the auto-opening wall of timestamp warnings with a persistent **Source review (N)** control and on-demand scrollable detailed list. Warning count stays visible in the main window. The second approval confirmation still flags unresolved warnings if user actually saves changed PNGs.
- A corrected **master only** does not invalidate cache (correct: Plain artwork remains unchanged); saving corrected **Plain** SVG changes its source hash and triggers fresh rendering. No silent Master→Plain propagation or LP Combo layer guessing.

The existing `MSB Icon Library Manager` Desktop shortcut continues to work after updating the normal Git checkout to a version containing these changes. **First Windows follow-up validation still required**: run **Check and preview icons** twice (second unchanged run should be much quicker and without per-icon console windows), then save the corrected Plain `car-r.svg` and verify the next preview marks only intended icon changes; inspect warnings using **Source review**. Do not run the historical manual 32-icon ZIP promoter.

## Scan and save progress indication — October 11

The operator requested a **persistent progress meter and working/activity indicator** because long icon scans otherwise appear frozen. The manager now displays a progress bar, completed-file count/percentage, and **the name of the icon currently being processed** for both **Check and preview icons** and **Save approved PNG changes**.

- During discovery/validation, source rechecks, backup creation and package verification, work cannot be expressed as a reliable number of files completed; the bar runs in **indeterminate (activity) mode**, explicitly marked "Working…", without an invented ETA.
- During icon rendering, cache reuse and canonical PNG copying, the bar becomes **determinate** with real completed/total icon counts and the current filename (for example `car-r.svg: rendered — 12 / 34 (35%)`). Every icon advances only **after its PNG and source hashes have been verified**.
- On completion, the bar reads **Complete**; on error it reads **Stopped**, and the error dialog/log explains why. No operation claims 100% while a save is still running.
- Background threads send progress events through a thread-safe queue polled by the Tk main window. Long Inkscape subprocesses remain off the UI thread, so the indicator continues to animate while working. The manager does not estimate time remaining.
- Progress callbacks are optional on the Python engine, so the existing headless command and independent consumers retain their previous behavior. No changes to symbol identity, map data, ExpertGPS installed library, webassets or GPX.
- Disposable tests verify every icon's completion event and that save progress reaches its full count only after verified receipt rows. **Windows GUI progress animation and actual G: runtime remain for operator acceptance**; static checks are not a Windows UI test.

The existing desktop shortcut is unchanged. After updating the normal Git checkout, relaunch **MSB Icon Library Manager**, select **Check and preview icons**, and watch the new meter. The first scan can still take time while rendering; a second scan should be substantially faster because its previous unchanged previews are cached.

## Web-server SVG publication — separate, explicitly confirmed action (October 11)

The operator discovered that newer approved `Plain` SVG artwork had **not** been synchronized to the live file server while he was reviewing the Park Map. That makes public-image visual acceptance unreliable. This is a **separate publication gap** from generating canonical `png` derivatives. The existing Icon Library Manager previously refused web changes by design; it now offers an additional controlled button, but **never auto-publishes during icon scan or PNG save**.

The updated workflow is:

1. Save reviewed editable Inkscape master artwork and its corresponding correct `Symbols\Plain\*.svg` derivative. Open the desktop **MSB Icon Library Manager**, choose **1. Check and preview icons**, and inspect artwork. This validates every Plain file as XML, in pixel units and with **both canvas dimensions ≤32 px**; visually incorrect artwork still requires an operator correction.
2. Choose **3. Review/publish Plain SVGs to web**. This requires the earlier valid preview and checks the entire **current Plain source snapshot** against the existing server share `\\192.168.5.4\webassets\images\symbols\msb-svg`. It displays a **scrollable exact list** of NEW, UPDATE (backup), and Unchanged names; does not rename or delete unknown or legacy files.
3. After reviewing that list, press **Publish reviewed SVG changes** and separately approve the explicit **LIVE web file server** confirmation. The engine rechecks every source and case-sensitive destination collision immediately beforehand; preserves changed server SVGs in the same G: run's `web-svg-backups-before-replacement` directory, creates new SVGs exclusively, verifies remote SHA-256 bytes and continuously updates `MSB_GIS_Web_SVG_Publication_Receipt.csv`. Errors stop the process; a partial receipt and backups must be reviewed rather than interpreting interruption as full success.
4. Select an icon in the preview and use **Open selected SVG URL** to open `https://webassets.sheboyganlights.org/images/symbols/msb-svg/<filename>.svg` with a source-hash cache-busting query. **The browser URL must still be visually and operationally checked**: a successful UNC copy does not by itself verify HTTP delivery, CDN behavior or the correct artwork.
5. **Do not confuse web image publication with Park Map deployment.** The deployed/static map history used GPX-derived legacy `msb/*.png` marker URLs and fixed 32×32 sizing. The separate #171/#230 **draft PR #319 map candidate** now selects approved Plain SVG artwork at its natural dimensions and plans offline packaging, but has **not** passed operator browser/tablet or Production deployment acceptance. Its incomplete type/fallback mapping must not change GPX waypoint identities, source `marker_url` values or historical URLs. Successful `msb-svg` publication does not itself install this map candidate.

**Failure and authorization boundaries:** If `msb-svg` is missing, unreachable or the operator is not authorized to modify it, publication preflight stops without creating directories. There are no live web writes until the separately confirmed third action. The code does **not** modify the legacy `msb` PNG/BMP directory, ExpertGPS, GPX, map application source, browser CSS, database, or draw.io embedded symbols. All source and destination file hashes must match before success is displayed. **Real Windows/Synology SMB publication/hash acceptance PASSED October 12 (37 entries)**; independent public HTTPS artwork and offline/browser map acceptance remain pending. The isolated automated regressions use disposable local stand-in directories only.

### October 11 field-test correction — identical mixed-case published SVG alias

The authorized administrator's first real Windows/Synology check found an old
published filename `msb-splitter-Combiner.svg` versus canonical approved
`msb-splitter-combiner.svg`. The actual SHA-256 of both files is
`DD2369417633A3623BD77BCD74BCD8BCB2105DA616A1DD60B811CC184472E7A0`.
The historical-cased public URL returns HTTP 200, while the lowercase URL
returns HTTP 404. There is **no artwork change to publish for this file**.
Windows/SMB cannot safely create an independent case-only counterpart, and
renaming the old file risks breaking historical consumers.

The SVG publisher now distinguishes **historical-case / bytes identical**
from a real conflict. It can proceed with publishing *other* reviewed SVGs,
while leaving this exact existing alias untouched. The review shows the
canonical -> historical published name, and receipts record the **actual
published exact-case URL**, not a fictitious lowercase URL. A case-only match
with **different bytes, duplicate ambiguous filenames, or a source hash
change still stops before any publication**. It does not create a redirect,
rename files, change GPX, or make the lowercase URL resolve; a map consumer
must use its approved published exact-case artwork or an independently
authorized future alias mapping. The new Plain SVG Park Map uses a separate
reviewed type registry and does **not** depend on the splitter-combiner icon.

All web publication actions still require the sole authorized Synology
administrator's Windows SMB credentials and an explicit per-action preview
and confirmation. Application buttons do not grant rights or contain an
administrator login. CI uses disposable directories; real Windows preview,
public SVG URL and offline Park Map tablet acceptance remain separate.

## Complete canonical PNG distribution: website AND per-user ExpertGPS — October 11

The operator correctly identified two **independent missing steps** after producing reviewed SVG/PNG files: (a) canonical `Symbols\png` outputs were **not** copied to the existing Synology public PNG folder and (b) canonical PNGs were **not** installed in the current Windows account's TopoGrafix/ExpertGPS symbol folder. The original `readme.txt` is **not a publisher/installer**.

**Exact ExpertGPS `readme.txt` contract:** first line `https://webassets.sheboyganlights.org/images/symbols/`. It tells ExpertGPS which **parent URL** to write into GPX or KML/KMZ custom-symbol references **based on the symbol folder name and PNG filename**; e.g. the local folder `TopoGrafix\Symbols\msb` containing `car-r.png` results in a reference equivalent to `https://webassets.sheboyganlights.org/images/symbols/msb/car-r.png`. It does **not** put PNGs on the web, copy PNGs into local ExpertGPS or migrate old GPX aliases. Do **not** add `msb/` to that first readme line; ExpertGPS already appends the folder name. Preserve the complete original `readme.txt` and verify its parent URL before local installation.

The **one Desktop Icon Library Manager** now provides all independent governed operations:

| Action in manager | Output and release control |
| --- | --- |
| **1. Check and preview icons** | Validate all current G: Plain SVGs, rasterize/cache, inspect source artwork, no canonical or web changes |
| **2. Save approved PNG changes** | Verified canonical G: `Symbols\png` with backup/receipt |
| **3. Review/publish Plain SVGs to web** | Existing `\\192.168.5.4\webassets\images\symbols\msb-svg`; separate explicit review/confirmation, backups, hashes, receipt |
| **4. Publish PNGs to web** | Existing `\\192.168.5.4\webassets\images\symbols\msb`; separate explicit review/confirmation; retain legacy-named files/BMPs; backup replacements; verify hashes and web URLs |
| **5. Install PNGs for this ExpertGPS user** | Current account's `%LOCALAPPDATA%\TopoGrafix\Symbols\msb`; separate explicit review/confirmation, backup existing files, verify hashes, **preserve validated readme.txt** |

**Required sequence for PNG distribution:** complete 1 then 2 first. Steps 4 and 5 will refuse to proceed unless **all current canonical PNGs exactly match** the earlier validated G: Plain source/manifest hashes, including the individual 1–32-pixel width/height constraints. They inspect the *full current icon set*, not a hard-coded 32/34 count or a previously copied ZIP. For each destination, the read-only comparison shows NEW, UPDATE (backup), Unchanged; ambiguous filename/case collisions **stop before writing** and must be reconciled deliberately, particularly where historical `Panel.png`/`panel.png` might conflict on a case-insensitive file share. Do **not** silently delete, rename or overwrite an older alias to clear a conflict. On confirmed write, backed-up copies/receipts are stored in the G: run `release-history` folder, every destination file is SHA-256 verified, and a partial failure is clearly marked STOPPED.

**ExpertGPS per-account specifics:** installer resolves current Windows `LOCALAPPDATA` instead of a hard-coded username. The existing `msb` folder and `readme.txt` must already be present and valid; for a brand-new ExpertGPS user without this folder/readme, installation stops instead of silently inventing a first-line URL or rewriting an unrelated symbol directory. Initial ExpertGPS folder provisioning needs a separate, explicitly authorized setup procedure. ExpertGPS should be **closed during installation**, restarted afterward, and tested with a new symbol plus an existing legacy GPX import/export. The readme URL alone does not prove online files are reachable.

**Web-specific acceptance:** after step 4 succeeds on the Synology file share, verify actual public URLs `https://webassets.sheboyganlights.org/images/symbols/msb/<canonical-name>.png` in a browser. SMB SHA-256 equality does not itself prove HTTPS delivery or browser cache freshness. Old GPX links may reference historical filenames; the manager preserves those files but cannot certify all aliases until reconciled. Likewise, the current reference Park Map still uses legacy GPX-derived `msb/*.png` URLs and fixes all marker canvases at 32×32; merely publishing the new PNGs does not automatically select newer aliases or preserve narrower marker geometry. Those are separate #171 mapping/rendering acceptance gates.

**Automated safeguards:** repository [GIS Icon Library regression workflow](../../.github/workflows/gis-icon-library-tests.yml) performs Python compile and isolated sync/SVG/PNG distribution tests on PR and main updates; all tests operate in disposable directories, not G:, the Synology public shares or local TopoGrafix. GitHub CI acceptance does **not** substitute for real Windows file-access and HTTP browser review.

**Deploy state:** these actions are implemented as repository code only until validated on the actual Windows laptop and live Synology. No copy to the user's local TopoGrafix folder or public server has been performed by the GitHub merge itself. All live writes remain behind explicit review and confirmation.

## Weekly workflow (no PowerShell, no Downloads)

1. Edit an Inkscape file in `G:\Shared drives\Display Folders\Park Drawings\MSB GIS\Symbols\Masters`; save the correct **Plain SVG** in sibling `Plain`. Layered masters (such as LP-Combo) can intentionally produce multiple Plain outputs: choose layer visibility inside Inkscape; **the manager does not guess or rewrite layer configurations**.
2. Open **MSB Icon Library Manager** from the Desktop, choose **1. Check and preview icons**.
3. It discovers **every current** lower-case/hyphenated Plain SVG (no fixed count), rejects invalid SVG, mm/inches/canvas sizes above **32 px on either axis**, Inkscape editing metadata still present in Plain files, external linked assets, failed Inkscape conversion, wrong PNG dimensions/format, and changes made to a source during generation.
4. The preview shows **NEW**, **UPDATE (backup)** or **Unchanged** for every icon, and lets you inspect PNG artwork. It also reports any editable master modified later than its associated Plain SVG, including recognized LP-Combo derived variants. Such warnings require review and an additional confirmation rather than assuming every newer master is visibly different. It **does not** write to the canonical PNG folder yet.
5. Choose **2. Save approved PNG changes** and confirm. The manager checks source hashes again, retains identical files, creates missing PNGs, backs up changed files and replaces them, verifies SHA256 after each write, and writes a per-run CSV receipt. If it encounters a case conflict or other error, it stops with diagnostics and **does not claim complete success**.

**Canonical sources and outputs:**

| Folder | Role |
| --- | --- |
| `Symbols\Masters` | Editable Inkscape SVG artwork (operator controlled) |
| `Symbols\Plain` | Approved per-variant Plain SVG inputs (read-only to this tool) |
| `Symbols\png` | Canonical generated PNG library; updates only on confirmed action |
| `Symbols\release-history\MSB-GIS-Icon-Sync-*` | Versioned source/PNG manifests, exact release ZIP, logs, backup PNGs, receipts, or error details; **never Downloads** |

**Icon rules:** each image canvas is at least **1 px** and at most **32 × 32 px**. Unequal widths/heights are valid (e.g., 32×18, 16×32). Accept only true pixel dimensions. Do not silently rescale source SVGs.

**Scope boundary:** The optional third action can publish reviewed **Plain SVGs only** to the pre-existing Synology `msb-svg` share after explicit confirmation, backups and hashes; it does **not** automatically publish on scan or PNG save. The manager also now offers **separate, explicitly confirmed PNG distribution** to the existing legacy web `msb` PNG folder and the current user's `%LOCALAPPDATA%\TopoGrafix\Symbols\msb`; neither operation is automatic. It does not edit ExpertGPS/GPX type names or existing URLs, modify the GIS database or Park Map renderer, or change draw.io library/embedded artwork. Those remain separately controlled releases. It also does not automatically export plain derivatives from editable multi-layer Masters: correct layer selection is a meaningful operator choice.

**Recovery:** On a failure, open the **release history / logs** folder in the app and inspect `ERROR.txt` or `Inkscape-export.log`. Modified destination PNGs have copies in the run's `backups-before-replacement` folder, and the receipt lists every completed action. Do not discard them before identifying any partial promotion failure.

**Validation:** `python -m unittest -v Database/EngineeringTools/test_sync_gis_icons.py` is the disposable suite; the original 12 checks passed in the earlier PR, and two additional cache-regression tests now cover unchanged PNG reuse and corrupted-cache fallback (**new tests require execution before runtime acceptance**). A real disposable Inkscape integration test of a 24×32 SVG was previously executed outside Windows. The operator has now confirmed Windows first launch and preview functionality, including discovery of an incorrect `car-r`; quiet/fast repeat scan and actual Google Shared Drive PNG synchronization **still require operator acceptance**.