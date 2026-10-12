# MSB Icon Library Manager — engineering handoff and document pointers

| Document control | Value |
| --- | --- |
| Purpose | README handoff/navigation for the installed desktop icon-maintenance tool |
| Owning issue | [#171 — Site Infrastructure / GIS](https://github.com/Gregovate/MSB-Production-Database-Project/issues/171), coordinated with #230/#122 |
| Current handoff | October 12, 2026 |
| Authority | [GIS Symbol Management — CURRENT engineering contract](../../Docs/02_Production_Database/01_System_Architecture/11_Site_Infrastructure_GIS/engineering/GIS_Symbol_Management.md) |

## Current State

The desktop manager is the **existing Git-controlled tool**, run from an authorized Windows checkout through a one-time-installed Desktop shortcut; it does **not** update itself or carry separate login permissions. Step 1 now validates independently of local ExpertGPS, while Step 5 can provision a missing current-user `msb` folder, canonical `readme.txt` and current PNGs after review. This code is merged to `main`; actual Windows/GPX compatibility remains a separate acceptance gate. The launcher/GUI use a dedicated checked-in ICO; **rerun the shortcut installer once after updating main** to refresh the old generic shortcut icon. See the controlling engineering document for acceptance status. The approved source is Shared Drive `Symbols\Plain`, derived from editable `Masters`; canonical ExpertGPS PNGs are in sibling `png`. Source rules, five independent operations, safety gates, backup/receipt contract and permission matrix are controlled in [GIS Symbol Management](../../Docs/02_Production_Database/01_System_Architecture/11_Site_Infrastructure_GIS/engineering/GIS_Symbol_Management.md), **not in this README or a PR description**.

**Accepted October 12 release:** the administrator published and SHA-256 verified **37 Plain SVG entries on the Synology SMB `msb-svg` share**, while the current Windows user's **37 ExpertGPS PNGs matched canonical hashes**. Public HTTPS appearance/Stage symbol validation, draft #319 Park Map/offline field acceptance, ExpertGPS GPX round-trip and web PNG case compatibility remain separate open gates. Exact release evidence and history are in the engineering authority.

**Latest engineering handoff (October 12):** Read-only registry evidence from **laptop, Show PC and Office PC** confirms independent current-user ExpertGPS waypoint Type/style catalogs (**57 / 37 / 28 Types** respectively), including distinct `GPS Symbol`, `Bitmap Symbol URL`, and `Common\Settings\SymbolToType` associations. The `Flag, Blue` reverse assignment differs across **all three**. Vendor-supported settings transfer uses `HKCU\Software\TopoGrafix\ExpertGPS` and `Common`, but no selective import or GPX-import precedence has been accepted. **Do not import full registry files blindly, overwrite legacy mixed-case symbol URLs, or hardcode Type-to-SVG mappings.** The [engineering authority](../../Docs/02_Production_Database/01_System_Architecture/11_Site_Infrastructure_GIS/engineering/GIS_Symbol_Management.md) governs evidence and unresolved design; the [ExpertGPS operator SOP](../../Docs/02_Production_Database/01_System_Architecture/11_Site_Infrastructure_GIS/operatorSOP/Review_MSB_Icons_and_Update_Local_ExpertGPS.md) governs local install and safe comparison.

**Critical current handoff:** A Windows profile without the local MSB custom-symbol folder is **not ready to open MSB GPX data in ExpertGPS**. MSB field testing showed that missing symbols can change map-marker associations to `GPS Symbol` even without an intentional GPX Save. Install and verify Step 5 first. Preserve authoritative GPX and use only disposable copies for post-install recovery checks. The [GIS engineering authority](../../Docs/02_Production_Database/01_System_Architecture/11_Site_Infrastructure_GIS/engineering/GIS_Symbol_Management.md) defines the precise risk and acceptance gate; [local ExpertGPS SOP](../../Docs/02_Production_Database/01_System_Architecture/11_Site_Infrastructure_GIS/operatorSOP/Review_MSB_Icons_and_Update_Local_ExpertGPS.md) has the operator steps.

## What Do You Need To Do?

Use the [GIS icon operator procedure portal](../../Docs/02_Production_Database/01_System_Architecture/11_Site_Infrastructure_GIS/operatorSOP/README.md):

- [Install the Desktop shortcut or update its Git checkout](../../Docs/02_Production_Database/01_System_Architecture/11_Site_Infrastructure_GIS/operatorSOP/Install_or_Update_MSB_Icon_Library_Manager.md)
- [Preview approved icons and update your own ExpertGPS PNGs](../../Docs/02_Production_Database/01_System_Architecture/11_Site_Infrastructure_GIS/operatorSOP/Review_MSB_Icons_and_Update_Local_ExpertGPS.md)
- [Publish approved Plain SVGs — Synology administrator **only**](../../Docs/02_Production_Database/01_System_Architecture/11_Site_Infrastructure_GIS/operatorSOP/Publish_Approved_MSB_SVGs_to_Web.md)

The manager has **no application login**. Only the Synology administrator has write permission to `\\192.168.5.4\webassets`. Do not delegate public SVG or PNG publication or embed server credentials. Non-admin authorized users may perform only the operations their normal filesystem permissions permit.

## Implementation Entry Points

- [One-time Desktop shortcut installer](Install-MSB-Icon-Library-Shortcut.cmd)
- [Desktop shortcut target / launcher](Launch-MSB-Icon-Library.cmd)
- [Windows GUI](icon_library_manager.pyw)
- [Canonical Plain SVG/PNG source validator](sync_gis_icons.py)
- [SVG website publisher](publish_gis_svgs.py)
- [PNG/ExpertGPS distributor](distribute_gis_pngs.py)
- [Engineering tool index](README.md)

## #171 workstation-profile comparison — isolated candidate

The existing GUI now has a separate **6. Compare GIS workstation release (READ ONLY)** action on the isolated #171 branch. Its new `gis_workstation_profile.py` reads only the running Windows user's narrow ExpertGPS Type, reverse-symbol, scanned-map calibration and local icon information; it requires a manifest plus a separately approved SHA-256, and shows a field-level diff. **No actual approved workstation release has been issued.** No installation, registry mutation, GPX import/export, calibration transfer, proposed change submission or two-way authorization is implemented by this code. The read-only candidate and synthetic fixture tests must pass CI and real-PC review before it can be accepted; see the [controlling engineering contract](../../Docs/02_Production_Database/01_System_Architecture/11_Site_Infrastructure_GIS/engineering/GIS_Symbol_Management.md). The five established icon actions remain independent.

## Resume / Open Acceptance

Read the **current engineering contract** first. The app still lacks a visible source/version SHA, and the web publication review has exhibited blank action-button labels. The web PNG `IP-camera.png` case conflict is unresolved. The draft #319 map must confirm all approved SVG types and missing-symbol fallback (including eight prior Anchor/Waypoint markers) and pass genuine Android offline acceptance. No icon success implies Production map release.

[↑ Engineering tools](README.md) | [↑ GIS subsystem](../../Docs/02_Production_Database/01_System_Architecture/11_Site_Infrastructure_GIS/README.md)
