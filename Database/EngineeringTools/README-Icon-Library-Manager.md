# MSB Icon Library Manager — one-time setup and normal use (Issue #171)

**Purpose:** stop generating temporary ZIPs in Downloads or remembering PowerShell commands for each new icon. The manager is a versioned GitHub tool, reads the authoritative Google Shared Drive files directly, and keeps one controlled audit/release history in the Shared Drive.

## Install once on a Windows workstation

1. Update your normal local Git checkout when repository code changes (the laptop primary checkout is `C:\lor\ImportExport\VSCode`). Do not use a disposable review worktree or overwrite unrelated changes.
2. In Windows File Explorer, open the repository's `Database\EngineeringTools` folder.
3. **Double-click `Install-MSB-Icon-Library-Shortcut.cmd` ONCE.** This creates the desktop shortcut **MSB Icon Library Manager**. It does not copy assets, create PNGs or run any release.
4. Use that desktop shortcut for every subsequent icon update. If you move the repository checkout, repeat the shortcut installer. The launcher uses the checked-out `.venv` Python or a discovered Windows Python installation with Tkinter. Inkscape must be installed with Windows `inkscape.com` available.

## Weekly workflow (no PowerShell, no Downloads)

1. Edit an Inkscape file in `G:\Shared drives\Display Folders\Park Drawings\MSB GIS\Symbols\Masters`; save the correct **Plain SVG** in sibling `Plain`. Layered masters (such as LP-Combo) can intentionally produce multiple Plain outputs: choose layer visibility inside Inkscape; **the manager does not guess or rewrite layer configurations**.
2. Open **MSB Icon Library Manager** from the Desktop, choose **1. Check and preview icons**.
3. It discovers **every current** lower-case/hyphenated Plain SVG (no fixed count), rejects invalid SVG, mm/inches/canvas sizes above **32 px on either axis**, Inkscape editing metadata still present in Plain files, external linked assets, failed Inkscape conversion, wrong PNG dimensions/format, and changes made to a source during generation.
4. The preview shows **NEW**, **UPDATE (backup)** or **Unchanged** for every icon, and lets you inspect PNG artwork. It **does not** write to the canonical PNG folder yet.
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

**Validation:** `python -m unittest -v Database/EngineeringTools/test_sync_gis_icons.py` exercises 11 disposable tests (no G: writes). A real disposable Inkscape integration test of a 24×32 SVG was also executed outside Windows. Windows one-click launch and Google Shared Drive sync **require operator acceptance** before declaring fully deployed.