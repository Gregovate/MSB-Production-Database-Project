# Database engineering tools

Controlled repository engineering utilities. Operator-run tools below require the documented preflight and governed acceptance gates; none are Production UI entry points.

## Normal icon editing and PNG management — Issue #171 (new operator GUI)

**Use the [MSB Icon Library Manager](README-Icon-Library-Manager.md), not the old timestamped Downloads ZIP workflow.** On a Windows workstation, double-click `Install-MSB-Icon-Library-Shortcut.cmd` **once** from this directory. Then open **MSB Icon Library Manager** from the Desktop whenever you add or edit icons. The launcher and GUI live in this GitHub repository; actual artwork is read directly from the canonical Shared Drive `Symbols\\Masters` / `Plain` folders.

The GUI discovers all current Plain SVGs automatically (no fixed icon count), validates pixel dimensions **1–32 px independently for width and height**, rejects mm/canvas mistakes, Inkscape editor metadata and external references in Plain files, stages/render-checks RGBA PNGs, visually previews each icon, and shows new/changed/unchanged status. On explicit confirmation only, it synchronizes new/changed PNGs into canonical G: `Symbols\\png`, with verified backups, source hashes and receipts stored in G: `Symbols\\release-history`. **No Downloads transfer or operator-run PowerShell commands are needed for recurring icon updates.**

The versioned Python engine is [`sync_gis_icons.py`](sync_gis_icons.py), the Windows UI is [`icon_library_manager.pyw`](icon_library_manager.pyw), the desktop launcher is [`Launch-MSB-Icon-Library.cmd`](Launch-MSB-Icon-Library.cmd), and the disposable checks are [`test_sync_gis_icons.py`](test_sync_gis_icons.py). The manager does **not** silently choose layers for a multi-layer master (e.g. LP-Combo); the operator still saves the desired Plain SVG variant in Inkscape. It also **warns when a matching editable master is newer than the saved Plain SVG**, including the LP-Combo layered derivatives, and requires an additional explicit confirmation before a PNG change when such source-freshness questions remain. It does **not** install ExpertGPS symbols, update GPX/draw.io, or publish Synology/web assets. The actual Windows GUI and shared-G: runtime still require operator acceptance before declaring deployment complete.

### Legacy tools kept for diagnostics/history

The following source inventory and staged ZIP utilities remain available for forensics or specialized controlled exports, but **are not the everyday icon maintenance entry point**.

## GIS / ExpertGPS symbol source inventory — Issue #171

[inventory_gis_symbols.py](inventory_gis_symbols.py) is a **read-only, standard-library Python** inventory of scattered SVGs, the chosen G: `Masters` and `Plain`, G: `Symbols\\png` derivatives, local ExpertGPS symbols, and optionally historical ZIPs/draw.io libraries. It reports retained Inkscape/Sodipodi metadata, source hashes, names, duplicate revisions, and noncanonical filename findings into a new Downloads folder. Inkscape metadata present means editor-specific information remains; absent metadata is **not proof** of a Plain SVG export. Use inventory/review **before** running the PNG exporter or changing current icons. Regression tests: `python -m unittest discover -s Database/EngineeringTools -p test_inventory_gis_symbols.py`.

## GIS / ExpertGPS symbol export — Issue #171

[Export-ExpertGPSSymbols.ps1](Export-ExpertGPSSymbols.ps1) stages RGBA PNGs from
**the actual current Google Shared Drive Plain SVG folder**, with a source/output
SHA-256 manifest and the user's existing ExpertGPS `readme.txt`. It does **not**
modify the source SVG, installed ExpertGPS symbols, Synology, or Production.
Run in Windows PowerShell 5.1+ on a PC with the G: drive and Inkscape.
**Windows launcher:** the script now defaults to `C:\Program Files\Inkscape\bin\inkscape.com`,
the console wrapper that reports Inkscape's native exit status and diagnostics;
`inkscape.exe` is the GUI launcher. If the install location differs, provide
`-InkscapeExecutable` pointing to the available `inkscape.com`. A staged
`MSB_Inkscape_Export_Diagnostics.txt` is written even when the first SVG fails;
inspect it before changing the SVG or repeating the run. Every attempt needs a
fresh output directory because a failed run retains its partial staging.
**Windows 32-icon staging run PASS (operator, October 11, 07:01):** the corrected
exporter completed against current G: `Symbols\\Plain` and printed 32 RGBA PNGs,
a manifest and staged ZIP under `Downloads\\MSB-ExpertGPS-PNGs-20261011-070134`.
This confirms the real Windows execution gate, **not** byte/visual manifest review,
legacy alias checks, `Symbols\\png` promotion, ExpertGPS install, or web release.
Request the generated ZIP and diagnostic/manifest before proceeding.
Consult the [GIS symbol maintenance contract](../../Docs/02_Production_Database/01_System_Architecture/11_Site_Infrastructure_GIS/engineering/GIS_Symbol_Management.md)
before replacing old-named PNG/BMP compatibility files. The previously supplied
October 9 icon ZIP must not be mistaken for a fresh export from current Plain.

## Canonical GIS PNG promotion — Issue #171

[Promote-ApprovedGISPNGs.ps1](Promote-ApprovedGISPNGs.ps1) handles **only** the
operator-approved corrected **07:24, 32-icon** ExpertGPS staging ZIP (pinned
SHA-256: `85569dc7cafa1da169bd68244bb9757daadfb53c1d02e911256790d0c6a63e53`).
The source must still match all 32 SHA-256 values in the current Shared Drive
`MSB GIS\Symbols\Plain` folder. It verifies the ZIP layout, manifest PNG hashes,
PNG dimensions/RGBA, original readme bytes and source SVG hashes before copying.

On the laptop at `C:\lor\ImportExport\VSCode`, update clean `main` first:

```powershell
.\Database\EngineeringTools\Promote-ApprovedGISPNGs.ps1
```

That is a **read-only dry run**. It identifies exactly how many PNGs would be
added to `G:\Shared drives\Display Folders\Park Drawings\MSB GIS\Symbols\png`,
how many are already byte-identical and any filename/case/hash collisions.
The utility searches timestamped Downloads export folders for the **single**
byte-exact approved ZIP, rather than guessing a folder timestamp; if moved,
use `-ZipPath 'C:\path\to\MSB_ExpertGPS_Current_Plain_Staged.zip'`.

If the preflight reports **zero conflicts** and the operator confirms the
canonical G: destination, the reviewed write action is:

```powershell
.\Database\EngineeringTools\Promote-ApprovedGISPNGs.ps1 -Apply
```

`-Apply` creates **missing approved files only**, uses create-new semantics,
verifies the destination SHA-256, and writes a receipt CSV beside the staging
ZIP. Existing correct PNGs are left untouched, **no existing file is
overwritten**, and unexpected/old-named files remain in place. Conflicting
same-name/case files abort for separate backup/reconciliation **before any
copy**; do not manually delete or overwrite to make a conflict disappear.
The utility never installs ExpertGPS icons or publishes Synology/web/draw.io
assets or changes GPX. Live Windows/G: copy acceptance remains pending.

**October 11 source addition / invalidate stale release:** operator has added
Wi-Fi antenna left/right master and Plain SVG variants (`antenna-l`,
`antenna-r`). The 32-file reviewed ZIP is an earlier snapshot, not a complete
34-icon set. The promotion script now **refuses** dry-run or `-Apply` if any
current Plain SVG filename is unlisted in its pinned manifest; it rechecks the
full live file set immediately before copying. **Do not promote the 32-file ZIP**
until the new 34-file candidate is exported, independently inspected and its
exact ZIP SHA approved in a separately reviewed update.
A disposable, G:-independent PowerShell 5.1 regression harness is available:
`Test-PromoteGISPNGs-SourceSet.ps1`. It AST-loads only the source-set guard
and tests exact matches, new antenna filenames, renames and removed SVGs
without running a real promotion. **Laptop execution remains pending.** If 32 were already
promoted before this source change, preserve the receipt and leave them intact;
a future 34-icon promotion should add missing antenna PNGs without replacing
matching existing derivatives.

