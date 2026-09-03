# QR Code Types and Meanings

| Document Control | Value |
|---|---|
| Document Type | Operator Reference |
| System | Production Database — Scan |
| Task | Understand MSB scan-code prefixes |
| Audience | MSB volunteers and operators |
| Status | DRAFT — operator review required |
| Owner | MSB Database Administrator |
| Last Reviewed | 2026-09-03 |
| Keywords | QR code, scan code, DISP, CONT, LOC, CTRL, display, container, location, controller |

## Purpose

MSB labels use a short type code before the item identifier.

The normal pattern is:

```text
TYPE:KEY
```

You usually do not need to memorize the prefixes. They simply tell you what kind of thing the label identifies.

## Current Approved Types

| Prefix | Means | Example | Current Scan status |
|---|---|---|---|
| `DISP` | Display | `DISP:251` | Current Display Scan hub is deployed and verified |
| `CONT` | Container | `CONT:587` | Current Container Scan landing page exists and opens the Container record |
| `LOC` | Storage Location | `LOC:RA-01-A-03` | Approved identity type; broader operator Scan workflow is not yet documented as fully deployed |
| `CTRL` | Controller | `CTRL:1014` | Production route opens the exact Controller Inventory record; physical-label testing remains pending |

## What The Code Does

The code identifies the item. It should not permanently lock the label to one specific screen or application.

For example, a Display QR identifies the permanent Display. The Scan system can then offer several useful actions for that same Display.

## Display Codes

A Display code begins with:

```text
DISP:
```

After scanning a current Display label, the Scan hub can provide actions such as:

- **Open Display Record**;
- current testing when available;
- **Field Wiring**;
- **Procedures**;
- **Open Container**; and
- **Open Work Orders** when active work orders exist.

See [What To Do After You Scan](What_To_Do_After_You_Scan.md).

## Container Codes

A Container code begins with:

```text
CONT:
```

The current Container Scan page provides **Open Container Record** and **Back to Scan**.

## Location Codes

A Storage Location code begins with:

```text
LOC:
```

These identify discrete operational locations such as storage or rack positions.

Do not assume every `LOC` workflow is available in Scan yet merely because the identifier is approved.

## Controller Codes

A Controller code begins with:

```text
CTRL:
```

The permanent numeric value after `CTRL:` is the Controller ID. Entering a compact value such as `CTRL:1014`, or opening its full Scan URL, routes to Controller Inventory with that Controller selected.

The route and manual-entry behavior are deployed. Physical Controller-label scanning will be accepted after the printing service can produce the first label.

## Expected Result

When you see an MSB code, you should be able to tell what kind of item it identifies before deciding what to do next.

## If Something Is Wrong

If the printed human-readable information and the QR result appear to identify different things, stop and report the label for review. Do not relabel the item or substitute another ID unless the responsible workflow tells you to do so.

## Related Documents

- [MSB Scan — Operator Guide](README.md)
- [Use Scan Manually](Use_Scan_Manually.md)
- [What To Do After You Scan](What_To_Do_After_You_Scan.md)
