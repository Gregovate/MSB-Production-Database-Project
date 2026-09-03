# MSB Scan — Operator Guide

| Document Control | Value |
|---|---|
| Document Type | Operator Portal |
| System | Production Database — Scan |
| Task | Find and use current Scan instructions |
| Audience | MSB volunteers, operators, and managers |
| Status | DRAFT — operator review and screenshots required |
| Owner | MSB Database Administrator |
| Last Reviewed | 2026-09-03 |
| Keywords | scan, scanning, QR code, display, container, phone, tablet, camera, manual entry, field wiring, procedures |

## What Is MSB Scan?

MSB Scan gives volunteers one place to scan or enter an MSB asset code and then choose the task they need to perform.

A permanent QR code identifies the item. The Scan system decides what useful actions are available for that item.

For example, scanning a Display can take you to its Display record, current testing record, Field Wiring, Procedures, assigned Container, or open Work Orders.

You do **not** need to understand database IDs, application routes, or the repository structure to use Scan.

## Open Scan

The normal operator entry is the protected MSB Internal home page:

**https://my.sheboyganlights.org/**

Use the green **Open Scan** button in the top Work Order / Scan / Database section.

You may also open Scan directly at:

**https://my.sheboyganlights.org/scan/**

`/scan/` is the canonical operator application entry. Existing printed labels and older scan links that use `https://db.sheboyganlights.org/scan/...` remain supported for compatibility and do not need to be replaced merely because the operator launch point is now under `my.sheboyganlights.org`.

The Scan page provides two normal ways to start:

- enter or paste a code and press **Go**;
- press **Scan with Camera** and scan the label with a phone or tablet camera.

## What Do You Need To Do?

| I want to... | Go to |
|---|---|
| Enter a code instead of using the camera | [Use Scan Manually](Use_Scan_Manually.md) |
| Understand what `DISP`, `CONT`, `LOC`, and `CTRL` mean | [QR Code Types and Meanings](QR_Code_Types_and_Meanings.md) |
| Set up a phone or tablet to scan labels | [Set Up a Phone or Tablet for Scanning](Set_Up_Phone_or_Tablet_for_Scanning.md) |
| Know which button to choose after I scan something | [What To Do After You Scan](What_To_Do_After_You_Scan.md) |

## Current Production Boundary

Display scanning is the most complete current Scan workflow.

Container scanning also has a current Scan landing page that opens the Container record.

`LOC` and `CTRL` are approved MSB identity types, but their broader operator workflows must not be assumed to be complete merely because the identifiers exist. The QR Code reference explains that distinction.

## Expected Result

A volunteer should be able to start at Scan, identify an item, and reach the correct next task without needing to know where the underlying application or documentation is stored.

## If Something Is Wrong

If a code will not scan, try entering it manually using [Use Scan Manually](Use_Scan_Manually.md).

If the system says an item cannot be found or an action is unavailable, do not substitute a different ID. Verify the label and ask the responsible manager for help if needed.

## Related Documents

- [Production Database Operational SOPs](../README.md)
- [Label Printing](../Label_Printing/README.md)
