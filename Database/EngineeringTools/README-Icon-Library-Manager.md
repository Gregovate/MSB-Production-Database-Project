# MSB Icon Library Manager — one-time setup and normal use (Issue #171)

**Purpose:** stop generating temporary ZIPs in Downloads or remembering PowerShell commands for each new icon. The manager is a versioned GitHub tool, reads the authoritative Google Shared Drive files directly, and keeps one controlled audit/release history in the Shared Drive.

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
5. **Do not claim the existing Park Map now uses these SVGs.** The current `Setup/Application/locate_preview.html` reference map reads **legacy `…/images/symbols/msb/*.png` URLs from GPX-derived `marker_url` values** and forces `iconSize:[32,32]`, potentially stretching intentional rectangular markers. The Setup asset overlay also has a legacy `msb/T-Post.png` reference. Updating `msb-svg` by itself does not migrate these consumers. #171 requires separate marker alias and natural-size rendering review, preserving original GPX identities/legacy URLs and avoiding uninformed changes.

**Failure and authorization boundaries:** If `msb-svg` is missing, unreachable or the operator is not authorized to modify it, publication preflight stops without creating directories. There are no live web writes until the separately confirmed third action. The code does **not** modify the legacy `msb` PNG/BMP directory, ExpertGPS, GPX, map application source, browser CSS, database, or draw.io embedded symbols. All source and destination file hashes must match before success is displayed. **Real Windows/Synology and HTTP acceptance is pending**; the initial regression suite uses disposable local stand-in directories only.

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

**Scope boundary:** The optional third action can publish reviewed **Plain SVGs only** to the pre-existing Synology `msb-svg` share after explicit confirmation, backups and hashes; it does **not** automatically publish on scan or PNG save. The manager does **not** publish PNGs to the legacy `msb` share, install to `%LOCALAPPDATA%\TopoGrafix\Symbols\msb`, edit ExpertGPS/GPX type names or URLs, modify the GIS database or Park Map renderer, or change draw.io library/embedded artwork. Those remain separately controlled releases. It also does not automatically export plain derivatives from editable multi-layer Masters: correct layer selection is a meaningful operator choice.

**Recovery:** On a failure, open the **release history / logs** folder in the app and inspect `ERROR.txt` or `Inkscape-export.log`. Modified destination PNGs have copies in the run's `backups-before-replacement` folder, and the receipt lists every completed action. Do not discard them before identifying any partial promotion failure.

**Validation:** `python -m unittest -v Database/EngineeringTools/test_sync_gis_icons.py` is the disposable suite; the original 12 checks passed in the earlier PR, and two additional cache-regression tests now cover unchanged PNG reuse and corrupted-cache fallback (**new tests require execution before runtime acceptance**). A real disposable Inkscape integration test of a 24×32 SVG was previously executed outside Windows. The operator has now confirmed Windows first launch and preview functionality, including discovery of an incorrect `car-r`; quiet/fast repeat scan and actual Google Shared Drive PNG synchronization **still require operator acceptance**.