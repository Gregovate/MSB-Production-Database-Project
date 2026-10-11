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

**Scope boundary:** This manager does **not** publish to Synology/webassets, install to `%LOCALAPPDATA%\TopoGrafix\Symbols\msb`, edit ExpertGPS or GPX type names/URLs, modify GIS database, or change the draw.io library/embedded schematic. Those remain separately controlled releases. It also does not automatically export plain derivatives from editable multi-layer Masters: correct layer selection is a meaningful operator choice.

**Recovery:** On a failure, open the **release history / logs** folder in the app and inspect `ERROR.txt` or `Inkscape-export.log`. Modified destination PNGs have copies in the run's `backups-before-replacement` folder, and the receipt lists every completed action. Do not discard them before identifying any partial promotion failure.

**Validation:** `python -m unittest -v Database/EngineeringTools/test_sync_gis_icons.py` exercises 12 disposable tests (no G: writes). A real disposable Inkscape integration test of a 24×32 SVG was also executed outside Windows. Windows one-click launch and Google Shared Drive sync **require operator acceptance** before declaring fully deployed.