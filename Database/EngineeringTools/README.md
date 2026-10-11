# Database engineering tools

Repository-only engineering utilities. These are not operator entry points.

## GIS / ExpertGPS symbol export — Issue #171

[Export-ExpertGPSSymbols.ps1](Export-ExpertGPSSymbols.ps1) stages RGBA PNGs from
**the actual current Google Shared Drive Plain SVG folder**, with a source/output
SHA-256 manifest and the user's existing ExpertGPS `readme.txt`. It does **not**
modify the source SVG, installed ExpertGPS symbols, Synology, or Production.
Run in Windows PowerShell 5.1+ on a PC with the G: drive and Inkscape;
consult the [GIS symbol maintenance contract](../../Docs/02_Production_Database/01_System_Architecture/11_Site_Infrastructure_GIS/engineering/GIS_Symbol_Management.md)
before replacing old-named PNG/BMP compatibility files. The previously supplied
October 9 icon ZIP must not be mistaken for a fresh export from current Plain.
