# Publish Approved MSB Plain SVGs to the Web

[↑ Icon procedures](README.md) | [Install/update manager](Install_or_Update_MSB_Icon_Library_Manager.md)

| Document Control | Value |
|---|---|
| Document Type | Operational SOP |
| System | Site Infrastructure / GIS — Synology webassets symbols |
| Task | Publish reviewed Plain SVG icons to the MSB public web server |
| Audience | **Authorized Synology webassets administrator only** |
| Status | CURRENT — SVG publication field-tested October 12, 2026 |
| Owner | MSB Site Infrastructure / GIS administrator |
| Last Reviewed | 2026-10-12 |
| Keywords | publish, webassets, Synology, SVG, administrator, Plain, icon manager |

## Purpose

Publish the current, approved **Plain SVG** symbols to the existing Synology public website. This is separate from generating PNGs or installing ExpertGPS symbols.

## Access Required — Do Not Delegate

**Only the MSB Synology webassets administrator may perform this procedure.** Publication requires actual write permission to `\\192.168.5.4\webassets`. The Icon Library Manager has **no application login or role-based authorization**. Its buttons do not grant administrator privileges. Do not embed, share, or borrow administrator credentials, expand the web share ACL for ordinary operators, or run the desktop app as a workaround to elevate access.

Previewing icons and updating a user's local ExpertGPS PNGs are separate non-web tasks; their permissions do **not** authorize publication.

## Before You Start

1. On the administrator's authorized Windows PC, update the normal Git checkout and launch the Desktop **MSB Icon Library Manager** using [Install or Update the Manager](Install_or_Update_MSB_Icon_Library_Manager.md).
2. Confirm the intended approved source on the Shared Drive is `G:\Shared drives\Display Folders\Park Drawings\MSB GIS\Symbol Library\Plain`. These are exported Plain SVGs, not editable Inkscape Masters or a Downloads ZIP.
3. Ensure that any intentional source edits have been saved as Plain SVG, and that the images look right. Do not publish because of a timestamp warning alone.
4. Confirm the existing intended Synology destination is `\\192.168.5.4\webassets\images\symbols\msb-svg`, not `...\msb` (which is the separate legacy PNG/BMP folder).

## Procedure — Plain SVG Publication

1. Select **1. Check and preview icons**. Wait for **Complete**, inspect the intended artwork, and review **Source review (N)** warnings as appropriate.
2. Select **3. Review/publish Plain SVGs to web** — **not 4. Publish PNGs to web**.
3. In **Review LIVE web SVG publication — existing msb-svg**, verify the destination path and the count/list of **NEW**, **UPDATE (backup)**, **Unchanged**, and any **Historical-case (byte-identical)** items. Existing old-case matches with identical source hashes are retained; they are not renamed or assigned a fictitious lowercase public URL.
4. If the changes are approved, select the clearly labeled **Publish reviewed SVG changes**, then explicitly approve **Confirm LIVE SVG publication**. **If action buttons are blank/unreadable, STOP.** This is a known GUI defect; do not guess which rectangle publishes live files.
5. Wait until the manager reports **Web SVG publication PASS** with the verified entry count. Keep the resulting release-history/receipt location for the project record.
6. Use **Open selected SVG URL** for representative symbols and independently verify public browser delivery and actual artwork, including `stage.svg` and `t-post.svg` after a change. Correct public destination base:
   `https://webassets.sheboyganlights.org/images/symbols/msb-svg/`
7. Record the publication date, total/new/updated/unchanged/legacy-case counts, actual receipt folder and browser results in the [GIS Symbol Management engineering release record](../engineering/GIS_Symbol_Management.md) under #171.

## Expected Result

Published existing- and new-case **SVG** files match the approved Plain SVG source hashes on Synology. Changed files have backups and an incremental CSV receipt in the release-history folder. Public HTTPS/browser appearance is accepted **only after its separate visual check**.

The verified October 12 administrator run published **12 new**, updated **3** with backups, preserved **21** exact-match and **1** historical-case unchanged, and reported **37 SHA-256 verified SVG entries**. See the engineering release record for its exact receipt path and remaining browser acceptance.

## If Something Is Wrong

- **Publisher blocks on an SVG case collision:** do not rename/delete a historical file. Ensure the normal checkout contains the accepted publisher and report both existing and approved filenames/hashes for #171 engineering review.
- **Status says `PNG distribution requires attention` and mentions `ip-camera.png`:** that came from **4. Publish PNGs to web**, not action 3. The unrelated PNG compatibility collision remains unresolved. Do not rename `IP-camera.png`.
- **Missing/unreadable confirmation labels, incorrect destination, mismatched artwork or changed source warning:** cancel or stop publication until reviewed.
- **Copy interruption or hash failure:** **STOP**; preserve the run's partial receipt and backups. Do not repeat the entire publication blindly.
- **Synology SHA matches but a browser URL fails:** record the exact filename and public URL, including capitalization, then investigate delivery separately. Never assume different-case URLs resolve equivalently.

**Web PNG publishing is not an accepted follow-on step.** Action 4 is currently blocked by the historical `IP-camera.png` / canonical `ip-camera.png` case collision. It is also **administrator-only** and must not be attempted as a workaround for missing Park Map SVGs.

## Related Documents

- [Install or update the manager](Install_or_Update_MSB_Icon_Library_Manager.md)
- [Review approved icons and update local ExpertGPS](Review_MSB_Icons_and_Update_Local_ExpertGPS.md)
- [GIS Symbol Management engineering authority](../engineering/GIS_Symbol_Management.md)
