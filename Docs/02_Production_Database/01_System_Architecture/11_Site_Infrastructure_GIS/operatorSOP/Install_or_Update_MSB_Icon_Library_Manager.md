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

## Before You Start

- Your computer must have an authorized checkout of `Gregovate/MSB-Production-Database-Project`, including `Database\EngineeringTools`. If there is no authorized checkout, ask the MSB project administrator to provision one. Do not copy somebody else's GitHub credentials.
- Windows Python with **Tkinter** and installed Inkscape with `inkscape.com` are required. The launcher selects a Python `pythonw.exe` from the checkout's `.venv` or known Windows Python locations.
- The current approved icon source must be accessible on the Google Shared Drive: `G:\Shared drives\Display Folders\Park Drawings\MSB GIS\Symbols\Plain`. Permissions to that source and to the optional canonical PNG destination are separate from web-server permissions.
- **No Synology administrator access is needed** to install the shortcut, preview artwork, or update your own permitted ExpertGPS files. Only the administrator may publish anything to `\\192.168.5.4\webassets`.

## Install the Desktop Shortcut — Once Per Computer / Checkout

1. In Windows **File Explorer**, open your authorized repository checkout. Two known primary checkouts are:
   - Laptop: `C:\lor\ImportExport\VSCode`
   - Desktop: `C:\Users\Greg\Github\MSB-Production-Database-Project`
   Use the one actually on this computer; do not assume a different person's path.
2. Open the folder `Database\EngineeringTools`.
3. Double-click **Install-MSB-Icon-Library-Shortcut.cmd**. It creates **MSB Icon Library Manager** on your Windows Desktop.
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
6. Start the existing **MSB Icon Library Manager** Desktop shortcut again. No shortcut reinstall is needed when the checkout path is unchanged.

**The app currently does not show a version or build SHA in its window.** The `git rev-parse HEAD` output is the source identity until that UI issue is resolved. Do not interpret the printed SHA as proof that public SVGs or PNGs were published.

## Expected Result

The shortcut launches the current checked-out program, and **1. Check and preview icons** completes against the Shared Drive. No web files change during installation, updating, or preview.

## If Something Is Wrong

- **Shortcut missing or opens the wrong checkout:** rerun `Install-MSB-Icon-Library-Shortcut.cmd` from the correct authorized checkout.
- **Python/Tkinter or Inkscape unavailable:** have the workstation administrator install the missing prerequisite; do not try to publish.
- **Git status not clean or pull fails:** stop, preserve the worktree and error message, and ask the project maintainer. Do not use `git reset --hard` or a manual ZIP copy as a workaround.
- **Shared Drive unavailable:** restore permitted access to the correct Google Shared Drive before validating; do not use an arbitrary Downloads ZIP as the source.
- **No web publishing rights:** that is expected for non-administrators. Do not use other people's Synology credentials or bypass folder permissions.

## Related Documents

- [Review approved icons and update local ExpertGPS](Review_MSB_Icons_and_Update_Local_ExpertGPS.md)
- [Administrator-only SVG web publication](Publish_Approved_MSB_SVGs_to_Web.md)
- [GIS Symbol Management engineering authority](../engineering/GIS_Symbol_Management.md)
- [Icon Manager repository handoff](../../../../../Database/EngineeringTools/README-Icon-Library-Manager.md)
