# MSB Icon Library Manager — engineering handoff and document pointers

| Document control | Value |
| --- | --- |
| Purpose | README handoff/navigation for the installed desktop icon-maintenance tool |
| Owning issue | [#171 — Site Infrastructure / GIS](https://github.com/Gregovate/MSB-Production-Database-Project/issues/171), coordinated with #230/#122 |
| Current handoff | October 12, 2026 |
| Authority | [GIS Symbol Management — CURRENT engineering contract](../../Docs/02_Production_Database/01_System_Architecture/11_Site_Infrastructure_GIS/engineering/GIS_Symbol_Management.md) |

## Current State

The desktop manager is the **existing Git-controlled tool**, run from an authorized Windows checkout through a one-time-installed Desktop shortcut; it does **not** update itself or carry separate login permissions. The approved source is Shared Drive `Symbols\Plain`, derived from editable `Masters`; canonical ExpertGPS PNGs are in sibling `png`. Source rules, five independent operations, safety gates, backup/receipt contract and permission matrix are controlled in [GIS Symbol Management](../../Docs/02_Production_Database/01_System_Architecture/11_Site_Infrastructure_GIS/engineering/GIS_Symbol_Management.md), **not in this README or a PR description**.

**Accepted October 12 release:** the administrator published and SHA-256 verified **37 Plain SVG entries on the Synology SMB `msb-svg` share**, while the current Windows user's **37 ExpertGPS PNGs matched canonical hashes**. Public HTTPS appearance/Stage symbol validation, draft #319 Park Map/offline field acceptance, ExpertGPS GPX round-trip and web PNG case compatibility remain separate open gates. Exact release evidence and history are in the engineering authority.

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

## Resume / Open Acceptance

Read the **current engineering contract** first. The app still lacks a visible source/version SHA, and the web publication review has exhibited blank action-button labels. The web PNG `IP-camera.png` case conflict is unresolved. The draft #319 map must confirm all approved SVG types and missing-symbol fallback (including eight prior Anchor/Waypoint markers) and pass genuine Android offline acceptance. No icon success implies Production map release.

[↑ Engineering tools](README.md) | [↑ GIS subsystem](../../Docs/02_Production_Database/01_System_Architecture/11_Site_Infrastructure_GIS/README.md)
