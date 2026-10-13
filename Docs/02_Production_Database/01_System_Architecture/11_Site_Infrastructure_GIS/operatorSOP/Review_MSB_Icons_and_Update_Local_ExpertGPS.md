# Review MSB Icons and Update Your Local ExpertGPS Symbols

[↑ Icon procedures](README.md) | [Previous: Install or update manager](Install_or_Update_MSB_Icon_Library_Manager.md)

| Document Control | Value |
|---|---|
| Document Type | Operational SOP |
| System | Site Infrastructure / GIS — ExpertGPS icon maintenance |
| Task | Preview approved Plain SVG artwork, maintain canonical PNGs, or install current-user ExpertGPS PNGs |
| Audience | Authorized icon editors and Windows ExpertGPS users |
| Status | CURRENT — file-based procedure; ExpertGPS application/GPX round-trip still requires acceptance |
| Owner | MSB Site Infrastructure / GIS administrator |
| Last Reviewed | 2026-10-12 |
| Keywords | ExpertGPS, local symbols, SVG, PNG, Plain, Inkscape, TopoGrafix, update |

## CRITICAL — Install the MSB Symbols BEFORE Opening an MSB GPX

**Do not open an MSB GPX file in ExpertGPS until this Windows user's `msb` symbol folder, complete PNGs and `readme.txt` have been installed and verified.**

MSB operator testing found that ExpertGPS can replace MSB custom map-marker associations with **GPS Symbol** when those files are missing, **even when the GPX is not intentionally saved**. Closing without saving is **not proven safe**. The behavior may also affect ExpertGPS's own waypoint-type settings. The exact persistence mechanism is still under investigation.

If an MSB GPX was already opened with symbols missing, **do not save, export, overwrite, or resynchronize it**. Preserve the original and backups. Restore/verify the local MSB symbol folder first, then use **only an isolated copy of a known-good GPX** for further tests. Ask the GIS administrator before resuming authoritative GPX editing.

## Cross-PC GIS configuration — synchronization NOT YET available

**Important:** The Icon Library Manager currently installs artwork and `msb/readme.txt` for *this Windows user*. That does **not** synchronize ExpertGPS's user-specific waypoint Types, Map Marker associations, GPS-symbol-to-Type table, or scanned-map calibration. Identical GPX and scanned-map images can therefore behave differently on the laptop, Show PC or Office PC.

**Until a reviewed MSB GIS workstation-configuration release and verification process is implemented, do not use a newly provisioned or unverified PC to edit/export authoritative MSB GPX or participate in two-way database imports.** Escalate mismatched Type names, unexpected `GPS Symbol` fallbacks, map-calibration differences or profile version uncertainty to #171. Keep existing authorized laptop maintenance separate; no unreviewed settings import or GPX rewrite is a remedy.

The controlled [GIS engineering contract](../engineering/GIS_Symbol_Management.md) owns the mandatory shared profile, conflict checks, acceptance across all PCs and eventual distribution/rollback design. There is **not yet** a supported One-click "Synchronize all GIS settings" operation; do not interpret PNG installation success as overall GIS configuration acceptance.

## Candidate read-only GIS workstation release comparison — NOT a synchronization install

The #171 **source-only candidate** adds **6. Compare GIS workstation release (READ ONLY)** to the existing Icon Library Manager. **This is not yet an accepted workstation update procedure**, because no administrator-approved GIS configuration release has been issued and laptop/Show/Office acceptance remains open.

For a **disposable test** using an administrator-issued release and a *separately supplied approved SHA-256*:

1. Start the candidate manager as the same Windows user who runs ExpertGPS. Do not open or edit the authoritative MSB GPX.
2. Select **6. Compare GIS workstation release (READ ONLY)**. Choose the explicitly approved JSON manifest, then paste the exact 64-character hash from the GIS administrator's separate approval receipt.
3. Read the displayed **Current** or **Not verified** status and the exact per-field differences. A missing file, inconsistent file hash, absent registry setting or unverifiable scanned map **stops acceptance**. Do not manually rename a Type or replace it with a GPS Symbol.
4. Close the comparison window. It neither changes the registry nor installs calibration or PNG files. Even **Current** means comparison only, **not** permission to perform two-way GPX/PostGIS edits.

Until the first shared release, trust/ACL, rollback and multi-PC checks are accepted, continue using the existing safe icon-only actions and preserve the original registry backups/GPX. Do not import someone else's full registry export to make Step 6 say Current.

**Laptop layout acceptance note (candidate only):** The source-only manager candidate should open at a practical 15-inch laptop size, with Steps 1–6, the red ExpertGPS warning, GIS **Not verified** status and Close accessible without maximizing. If any control remains offscreen, stop and report the window/display scaling to #171; do not change ExpertGPS settings or import a registry backup as a workaround.

## Purpose

Keep approved symbol artwork and each Windows ExpertGPS user's local PNG library consistent. **This procedure never publishes to the public web server.** For web publishing, only the authorized administrator uses the separate procedure.

## Before You Start

- Have the Desktop **MSB Icon Library Manager** shortcut installed and updated; see [Install or Update](Install_or_Update_MSB_Icon_Library_Manager.md).
- The approved files are on the Google Shared Drive under `G:\Shared drives\Display Folders\Park Drawings\MSB GIS\Symbols`.
- **ExpertGPS is not required for Step 1 or Step 2.** The optional staged ZIP uses its approved canonical URL metadata and does not read or write the current user's TopoGrafix folder. **Step 5** installs reviewed PNGs for this Windows user. If `msb` or its readme is missing, the manager offers to create it during the confirmed installation. No manual creation is required.
- Icon editing requires permission to the source folders. Updating the canonical PNG folder requires appropriate Shared Drive write permission. Local installation affects the **current Windows user only**.

## Review or Update Artwork

1. If artwork needs editing, open the existing editable Inkscape file from **Masters**. Preserve the master.
2. Save the correct layers as a separate approved **Plain SVG** to **Plain**. Saving a master alone does not update Plain. Use the approved lowercase filename and preserve its intended dimensions; icons may be rectangular. Each canvas dimension must be between **1 and 32 pixels**.
3. Start the Desktop **MSB Icon Library Manager** and select **1. Check and preview icons**.
4. Inspect the preview and any **Source review (N)** timestamp warnings. A timestamp warning does not prove the artwork is wrong and is not permission to silently overwrite Plain SVG files.
5. If any canonical PNGs show **NEW** or **UPDATE (backup)**, and you are authorized to maintain the Shared Drive PNGs, select **2. Save approved PNG changes** and review the confirmation. Wait for **Complete** and inspect the release receipt. If all are **Unchanged**, no PNG save is needed.

## Install/Update Local Symbols BEFORE ExpertGPS Opens MSB Data

1. **Close ExpertGPS and do not open any MSB GPX**, including from the shared G: source, until setup is complete. A fresh Windows profile with ExpertGPS installed may not yet have the `msb` custom-symbol folder.
2. In the validated manager session, select **5. Install PNGs for this ExpertGPS user**.
3. Review the **NEW**, **UPDATE (backup)** and **Unchanged** list. If the current user has no `msb` folder, the manager explicitly offers to create it, add the approved `readme.txt` and install **all** current canonical PNGs after your confirmation. If the folder already exists, it preserves unrelated symbols and a valid readme; it can add a missing readme. **Do not approve unexpected destinations or replacements.**
4. Wait for verification. Before starting ExpertGPS, confirm this Windows user's `%LOCALAPPDATA%\\TopoGrafix\\Symbols\\msb` contains the complete reviewed canonical PNG set and `readme.txt` with first line `https://webassets.sheboyganlights.org/images/symbols/`. **After** installation, restart ExpertGPS to load the custom symbols. Check its custom MSB symbol choices before opening an MSB GPX.
5. **Only on a disposable copy of a known-good GPX**, check whether the MSB waypoint Types and Map Markers still select the intended symbols. If any selection is `GPS Symbol` unexpectedly, **STOP**. Do not export, save, or open the authoritative GPX. A future controlled round-trip comparison must verify `type`, `sym`, marker URL/extensions and coordinate conservation before normal GPX editing can resume.

The approved `msb\readme.txt` first line must remain `https://webassets.sheboyganlights.org/images/symbols/`. It is a custom-symbol **URL parent** used by ExpertGPS, **not** a file uploader. Never add another `msb/` to that line, rename the `msb` folder to `MSB Icons`, or replace old PNG/BMP filenames without reviewed backward-compatibility work.

## Different Waypoint Type / Map Marker Choices on Another PC

**Installing the approved 37 PNG files and `msb/readme.txt` does not copy your ExpertGPS waypoint Type definitions or their selected Map Markers.** If `Display Anchor` exists on your laptop but not on the Command Center PC, **STOP before editing an authoritative GPX**. Do not manually rename `Flag` or select a guessed substitute.

ExpertGPS's [official transfer instructions](https://www.expertgps.com/transfer-settings.asp) identify two current-user Windows Registry branches:

- `HKEY_CURRENT_USER\Software\TopoGrafix\ExpertGPS`
- `HKEY_CURRENT_USER\Software\TopoGrafix\Common`

Before attempting a transfer, **close ExpertGPS on both computers**. On the laptop, from a normal PowerShell window running as the **same Windows user as ExpertGPS**, back up both branches **locally**:

```powershell
$backup = Join-Path $env:USERPROFILE 'Documents\MSB-ExpertGPS-Settings'
New-Item -ItemType Directory -Path $backup -Force | Out-Null
reg export "HKCU\Software\TopoGrafix\ExpertGPS" "$backup\ExpertGPS-Laptop.reg" /y
reg export "HKCU\Software\TopoGrafix\Common" "$backup\Common-Laptop.reg" /y
```

Also preserve **both branches of the Command Center account** under separately named `-CommandCenter.reg` files **before** any registry import. These files may include registration information and personal or machine-specific settings. **Keep them private; do not attach their raw contents to GitHub, ChatGPT, or shared GIS source folders.** The vendor's procedure transfers broad application settings. **Show PC inspection has identified the Type/Map Marker field names**, but the laptop's full `Display Anchor` settings and a safe transfer subset still require review. Do **not** double-click/import either registry file or delete/edit any existing registry entries until a reviewed migration/rollback procedure is prepared.

**Confirmed October 12 workstation comparison:** The laptop has `Common\Waypoint Types\Display Anchor` with `Symbol Type=2`, `GPS Symbol=Flag, Blue`, and `Bitmap Symbol URL=https://webassets.sheboyganlights.org/images/symbols/msb/pole-yellow.png`. The Show PC has **identical three settings under `Common\Waypoint Types\Flag`**, but no Display Anchor type. Their `Common\Settings\SymbolToType` maps `Flag, Blue` differently: laptop to `Display Anchor`, Show PC to `Flag`. The *map marker URL itself matches*. Do not change or import these settings yet.

The unresolved step is to determine whether a GPX waypoint's own Type or its GPS Symbol is used by ExpertGPS to choose the current PC's Type. Use only a **read-only XML inspection** of a disposable source copy or protected current file, not another ExpertGPS open/save operation, before considering a reversible targeted settings transfer. Preserve the registry backups from both machines; no more wide registry searches are needed.

Once the two PCs' settings have been compared and a safe transfer approved, confirm the intended Type and Map Marker on a **disposable GPX copy** first. Do not open or save the working shared GPX during diagnosis. The [controlling engineering contract](../engineering/GIS_Symbol_Management.md) owns the research checkpoint and recovery conditions.

## Expected Result

The approved Plain SVGs remain unchanged unless you intentionally edited and re-exported them. Canonical PNG derivatives and this Windows user's ExpertGPS PNGs match their reviewed sources. No public Synology files are written.

## If Something Is Wrong

- **Missing local `msb` folder or `readme.txt`:** this is a supported first-use condition on a PC with ExpertGPS's `TopoGrafix\Symbols` directory. Step 5 offers to create the missing folder/readme from the controlled source **after you review and approve**. Do not create it manually or borrow another Windows user's configuration.
- **Missing `TopoGrafix\Symbols` parent folder:** stop and open/install ExpertGPS for the current Windows user before retrying; the Icon Manager must not guess an ExpertGPS installation.
- **Existing readme has the wrong URL:** stop for administrator review; the manager does not overwrite a mismatching readme.
- **Unapproved source filename, incorrect canvas, missing image, or unexpected replacement:** stop, correct/review the approved source in Inkscape, then preview again.
- **Web PNG action 4 reports `ip-camera.png` case collision:** that is a separately known web compatibility block, *not* a failure of local ExpertGPS update or web SVG publishing. Do not rename `IP-camera.png`.
- **A file is current but ExpertGPS still shows an incorrect symbol:** record the source type, local filename and exported URL for #171 review. Do not change GPX identities just to make an icon appear.

## Related Documents

- [Install or update the manager](Install_or_Update_MSB_Icon_Library_Manager.md)
- [Administrator-only SVG web publication](Publish_Approved_MSB_SVGs_to_Web.md)
- [GIS Symbol Management engineering authority](../engineering/GIS_Symbol_Management.md)
