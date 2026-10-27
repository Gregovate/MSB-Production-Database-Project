# Install or Update the MSB Icon Library Manager

[↑ Icon procedures](README.md) | [Next: Review icons and local ExpertGPS →](Review_MSB_Icons_and_Update_Local_ExpertGPS.md)

| Document Control | Value |
|---|---|
| Document Type | Operational SOP |
| System | Site Infrastructure / GIS — MSB Icon Library Manager |
| Task | Install its Desktop shortcut or get a newer checked-in application version |
| Audience | Authorized Windows icon editors and ExpertGPS users; GIS administrator |
| Status | CURRENT — existing checkout and shortcut workflow; new-PC setup requires validation |
| Owner | MSB Site Infrastructure / GIS administrator |
| Last Reviewed | 2026-10-12 |
| Keywords | MSB icons, updater, install, Desktop shortcut, Git, Inkscape, ExpertGPS, SVG, PNG |

## Purpose

Install the **MSB Icon Library Manager** on a Windows computer that has access to the approved MSB symbol library. The installer creates a Desktop shortcut to the program **inside the local Git checkout**. It does not install a stand-alone copy, copy icons, or grant access to the web server.

**Important:** This application does **not** self-update. Future software changes arrive through an authorized `git pull --ff-only` of the checkout that the shortcut points to.

## Critical Prerequisite for ExpertGPS Data

**Do not open an MSB GPX or project in ExpertGPS on a new Windows account before running the Icon Library Manager's local installation Step 5 and verifying the `msb` PNG/readme library.** MSB field testing observed missing custom symbols causing waypoint map markers to become **GPS Symbol**, even without intentionally saving the file. The exact persistence is not established; treat the GPX and current user's ExpertGPS Type settings as at risk. Install and validate on a disposable copy before authoritative editing. See the [local ExpertGPS symbol procedure](Review_MSB_Icons_and_Update_Local_ExpertGPS.md).

## Before You Start

- Your computer must have an authorized checkout of `Gregovate/MSB-Production-Database-Project`, including `Database\EngineeringTools`. If there is no authorized checkout, ask the MSB project administrator to provision one. Do not copy somebody else's GitHub credentials.
- Windows Python with **Tkinter** is required. Inkscape with `inkscape.com` is necessary **only when an approved Plain SVG cannot be served from the SHA-256-verified Shared Drive preview cache** and must be rendered. For artwork editing or any changed/missing source derivative, Inkscape must be installed. The launcher selects a Python `pythonw.exe` from the checkout's `.venv` or known Windows Python locations.
- The current approved icon source must be accessible on the Google Shared Drive: `G:\Shared drives\Display Folders\Park Drawings\MSB GIS\Symbols\Plain`. Permissions to that source and to the optional canonical PNG destination are separate from web-server permissions.
- **No Synology administrator access is needed** to install the shortcut, preview artwork, or update your own permitted ExpertGPS files. Only the administrator may publish anything to `\\192.168.5.4\webassets`.

## Install the Desktop Shortcut — Once Per Computer / Checkout

1. In Windows **File Explorer**, open your authorized repository checkout. Two known primary checkouts are:
   - Laptop: `C:\lor\ImportExport\VSCode`
   - Desktop: `C:\Users\Greg\Github\MSB-Production-Database-Project`
   Use the one actually on this computer; do not assume a different person's path.
2. Open the folder `Database\EngineeringTools`.
3. Double-click **Install-MSB-Icon-Library-Shortcut.cmd**. It creates **MSB Icon Library Manager** on your Windows Desktop with its **dedicated MSB icon** (the same icon appears on the application window). No separate icon pack, Google Drive icon file, ExpertGPS installation or web-publishing permission is needed.
4. Confirm the installer reports that the Desktop shortcut was created. Open that shortcut. The window title should say **MSB Icon Library Manager — #171**.
5. Select **1. Check and preview icons**. Successful operation validates the current approved `Plain` source and shows icon previews. A warning in **Source review** means examine the source; it does not grant permission to replace artwork automatically.

The shortcut runs `Launch-MSB-Icon-Library.cmd` in the checkout. **If the checkout is later moved, repeat this installation** from the new location to update the shortcut.

## Update an Existing Installation After a Released Code Change

1. Close the Icon Library Manager.
2. In your normal repository terminal, check where you are and whether the checkout is safe to update:
   ```powershell
   # Read only: confirm that this is the intended primary checkout on main.
   git status --short --branch
   ```
3. Proceed only if the branch is `main` and your work is clean. **If it is not `main`, has uncommitted changes, or Git reports another worktree owns `main`, STOP** and ask the project maintainer to select the correct checkout. Do not reset, force a switch, or delete a worktree.
4. Fast-forward the checked-out `main`:
   ```powershell
   # Update source code only. Stop if fast-forward is not possible.
   git pull --ff-only
   ```
5. Verify the checked-out version for reporting:
   ```powershell
   # The manager currently has no visible build/version identity.
   git rev-parse HEAD
   ```
6. If your original Desktop shortcut was created **before the dedicated app icon was added**, run **Install-MSB-Icon-Library-Shortcut.cmd** once more from this same checkout to refresh its visible icon. For later ordinary program updates, reopening the existing Desktop shortcut is sufficient while its checkout path and icon remain unchanged. Open the manager and run **1. Check and preview icons**.

**The app currently does not show a version or build SHA in its window.** The `git rev-parse HEAD` output is the source identity until that UI issue is resolved. Do not interpret the printed SHA as proof that public SVGs or PNGs were published.

## Expected Result

The branded shortcut launches the current checked-out program, and **1. Check and preview icons** validates current approved Shared Drive artwork **even on a PC without ExpertGPS installed or an ExpertGPS `readme.txt`**. Only **5. Install PNGs for this ExpertGPS user** needs a pre-existing, valid current-user ExpertGPS symbol folder and readme. No web files or local ExpertGPS files change during installation, updating, or preview.

## If Something Is Wrong

- **Shortcut missing or opens the wrong checkout:** rerun `Install-MSB-Icon-Library-Shortcut.cmd` from the correct authorized checkout.
- **Python/Tkinter or Inkscape unavailable:** have the workstation administrator install the missing prerequisite; do not try to publish.
- **Git status not clean or pull fails:** stop, preserve the worktree and error message, and ask the project maintainer. Do not use `git reset --hard` or a manual ZIP copy as a workaround.
- **Shared Drive unavailable:** restore permitted access to the correct Google Shared Drive before validating; do not use an arbitrary Downloads ZIP as the source.
- **Missing application icon during shortcut installation:** stop and update the approved checkout; the installer intentionally refuses to create an unbranded shortcut when its checked-in ICO is absent.
- **Step 1 says `Existing ExpertGPS readme.txt unavailable`:** you are running an older checked-out program. Stop, confirm the correct `main` checkout and update; do **not** install ExpertGPS or create a guessed readme merely to make Step 1 work.
- **No web publishing rights:** that is expected for non-administrators. Do not use other people's Synology credentials or bypass folder permissions.

## Related Documents

- [Review approved icons and update local ExpertGPS](Review_MSB_Icons_and_Update_Local_ExpertGPS.md)
- [Administrator-only SVG web publication](Publish_Approved_MSB_SVGs_to_Web.md)
- [GIS Symbol Management engineering authority](../engineering/GIS_Symbol_Management.md)
- [Icon Manager repository handoff](../../../../../Database/EngineeringTools/README-Icon-Library-Manager.md)
