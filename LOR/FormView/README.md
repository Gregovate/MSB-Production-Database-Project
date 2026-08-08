# FormView

| Document control | Value |
|---|---|
| Status | ACTIVE — transitional production application |
| Owner | MSB Database Administrator |
| Current application version | 0.3.1 |
| Current revision | 2026-08-0 |

## Purpose

FormView is a standalone Windows desktop application used to turn the LOR
SQLite data and preview background images into practical wiring, stage, and
programming information. It is Python source compiled with PyInstaller into
`FormViewSA.exe`; production users run the executable and do not need Python.

FormView is part of the LOR input-side system. It does not use PostgreSQL and
it is not part of LOR2DB reconciliation.

## Production functions

- **Wiring View** selects a stage/preview, displays field-wiring rows and
  associated wiring images, and exports CSV or printable HTML.
- **Stage View** lists displays by stage and preview and exports a printable
  stage display report.
- **Programming View** lists props, groups, and tags for a selected preview and
  exports CSV or printable HTML for programmers.

FormView remains required until PostgreSQL snapshot reporting reproduces and
validates every operational function above. The replacement is not complete.

## Current data contract

The application currently opens:

`G:\Shared drives\MSB Database\database\lor_output_v6.db`

It also queries established `_v6` SQLite views. These filenames and view names
are active compatibility dependencies of FormView; they do **not** make the V6
parser or V6 PostgreSQL ingest current. Any change to this contract requires a
controlled FormView update and operational validation before deployment.

Current data source

FormView currently reads the compatibility database lor_output_v6.db.

Equivalent views now exist in lor_output_v7_scene.db.

Migration to the V7 scene-aware database is planned but not yet complete.

## Source, build, and deployment

| File | Role |
|---|---|
| `FormView.py` | Tkinter application source; `APP_VERSION` is the version authority |
| `build_formview.ps1` | PyInstaller build, version metadata, icon/image bundling, and deployment |
| `build_formview.bat` | Windows operator wrapper for the PowerShell build |
| `FormViewApp.bat` | Production launcher with prerequisites, local cache, update, and single-instance handling |

Build output:

`LOR\FormView\build_artifacts\dist\FormViewSA.exe`

Canonical deployed executable:

`G:\Shared drives\MSB Database\Apps\FormView\current\FormViewSA.exe`

The launcher copies the canonical executable to
`%LOCALAPPDATA%\MSB\FormView\FormViewSA.exe` and runs the local cached copy. Its
log is `%LOCALAPPDATA%\MSB\FormView\FormViewApp.log`.

## Build procedure

1. Update and test `FormView.py`; increment `APP_VERSION` for a release.
2. Confirm the G: shared drive, SQLite database, and `Docs\images` assets are
   available.
3. Run `build_formview.bat` from this folder.
4. Confirm PyInstaller succeeds and the script reports the deployed file,
   version, size, and SHA-256 hash.
5. Launch with `FormViewApp.bat` on a representative workstation.
6. Validate all three tabs, background/wiring images, CSV exports, and printable
   HTML before treating the build as accepted.

Do not replace the shared executable with an unvalidated local build.
