# Database engineering tools

Repository-only engineering utilities. These are not operator entry points.

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
**Windows runtime validation is still required;** a prior archived `car-l.svg`
rendered successfully on Linux Inkscape 1.4, which does not prove the current G:
file renders on Windows.
Consult the [GIS symbol maintenance contract](../../Docs/02_Production_Database/01_System_Architecture/11_Site_Infrastructure_GIS/engineering/GIS_Symbol_Management.md)
before replacing old-named PNG/BMP compatibility files. The previously supplied
October 9 icon ZIP must not be mistaken for a fresh export from current Plain.
