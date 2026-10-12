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

## Purpose

Keep approved symbol artwork and each Windows ExpertGPS user's local PNG library consistent. **This procedure never publishes to the public web server.** For web publishing, only the authorized administrator uses the separate procedure.

## Before You Start

- Have the Desktop **MSB Icon Library Manager** shortcut installed and updated; see [Install or Update](Install_or_Update_MSB_Icon_Library_Manager.md).
- The approved files are on the Google Shared Drive under `G:\Shared drives\Display Folders\Park Drawings\MSB GIS\Symbols`.
- **ExpertGPS is not required for Step 1 or Step 2.** The optional staged ZIP uses its approved canonical URL metadata and does not read or write the current user's TopoGrafix folder. **Step 5** is the only action that requires the user's existing ExpertGPS `msb/readme.txt`.
- Icon editing requires permission to the source folders. Updating the canonical PNG folder requires appropriate Shared Drive write permission. Local installation affects the **current Windows user only**.

## Review or Update Artwork

1. If artwork needs editing, open the existing editable Inkscape file from **Masters**. Preserve the master.
2. Save the correct layers as a separate approved **Plain SVG** to **Plain**. Saving a master alone does not update Plain. Use the approved lowercase filename and preserve its intended dimensions; icons may be rectangular. Each canvas dimension must be between **1 and 32 pixels**.
3. Start the Desktop **MSB Icon Library Manager** and select **1. Check and preview icons**.
4. Inspect the preview and any **Source review (N)** timestamp warnings. A timestamp warning does not prove the artwork is wrong and is not permission to silently overwrite Plain SVG files.
5. If any canonical PNGs show **NEW** or **UPDATE (backup)**, and you are authorized to maintain the Shared Drive PNGs, select **2. Save approved PNG changes** and review the confirmation. Wait for **Complete** and inspect the release receipt. If all are **Unchanged**, no PNG save is needed.

## Update Your Own ExpertGPS Symbols

1. **Close ExpertGPS** before installing files.
2. In the validated manager session, select **5. Install PNGs for this ExpertGPS user**.
3. Review the intended **NEW**, **UPDATE (backup)** and **Unchanged** comparison for your existing `%LOCALAPPDATA%\TopoGrafix\Symbols\msb` folder. Approve only the reviewed changes.
4. Wait for the result. Confirm that the destination files match the canonical hashes, then reopen ExpertGPS and visually inspect both a new icon and an existing historical waypoint.
5. When GPX symbol compatibility is material, make a **test GPX export** and check its symbol URL/filename on an authorized computer; file hash equality alone does not verify GPX/ExpertGPS behavior.

The existing `msb\readme.txt` first line must remain `https://webassets.sheboyganlights.org/images/symbols/`. It is a custom-symbol **URL parent** used by ExpertGPS, **not** a file uploader. Never add another `msb/` to that line, rename the `msb` folder to `MSB Icons`, or replace old PNG/BMP filenames without reviewed backward-compatibility work.

## Expected Result

The approved Plain SVGs remain unchanged unless you intentionally edited and re-exported them. Canonical PNG derivatives and this Windows user's ExpertGPS PNGs match their reviewed sources. No public Synology files are written.

## If Something Is Wrong

- **Missing local `msb` folder or `readme.txt`:** installation stops. Do not create guessed URLs or replace it with another user's readme; ask the administrator to recover/provision the intended local folder.
- **Unapproved source filename, incorrect canvas, missing image, or unexpected replacement:** stop, correct/review the approved source in Inkscape, then preview again.
- **Web PNG action 4 reports `ip-camera.png` case collision:** that is a separately known web compatibility block, *not* a failure of local ExpertGPS update or web SVG publishing. Do not rename `IP-camera.png`.
- **A file is current but ExpertGPS still shows an incorrect symbol:** record the source type, local filename and exported URL for #171 review. Do not change GPX identities just to make an icon appear.

## Related Documents

- [Install or update the manager](Install_or_Update_MSB_Icon_Library_Manager.md)
- [Administrator-only SVG web publication](Publish_Approved_MSB_SVGs_to_Web.md)
- [GIS Symbol Management engineering authority](../engineering/GIS_Symbol_Management.md)
