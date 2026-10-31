# Site Infrastructure / GIS — Icon Operator Procedures

This is the task guide for installing and using the **MSB Icon Library Manager**. Approved artwork and publication behavior are controlled by the [GIS Symbol Management engineering authority](../engineering/GIS_Symbol_Management.md); this page does not redefine that design.

## What do you need to do?

- [Garmin GPSMAP 66sr — record a cable route and clear old tracks (DRAFT)](Garmin_66sr_Record_and_Clear_Tracks.md) — simple button-by-button field instructions; device test required before issuing to technicians.

- [Install or update the MSB Icon Library Manager](Install_or_Update_MSB_Icon_Library_Manager.md) — prepare an authorized Windows checkout, create the one-time Desktop shortcut, and get current program changes.
- [Review icons and update your local ExpertGPS symbols](Review_MSB_Icons_and_Update_Local_ExpertGPS.md) — work with approved Plain SVGs and canonical PNGs; no public web publishing.
- [Publish approved Plain SVGs to the web — administrator only](Publish_Approved_MSB_SVGs_to_Web.md) — controlled review, explicit confirmation, backups, and public URL verification.

**Web publishing is administrator-only.** The manager has no login screen. Only the authorized Synology administrator has SMB write rights to `\\192.168.5.4\webassets`. Installing or opening the manager does not give someone web publishing rights.

## Current handoff

The authorized administrator's October 12 release verified **37 approved SVG entries** in the Synology `msb-svg` folder by SHA-256. The exact release record, legacy-case exception, known remaining defects and acceptance boundaries are maintained in [GIS Symbol Management](../engineering/GIS_Symbol_Management.md). Public HTTPS appearance, complete Park Map rendering, and offline tablet use require separate acceptance.

For related GIS source and map work, return to [Site Infrastructure / GIS](../README.md).
