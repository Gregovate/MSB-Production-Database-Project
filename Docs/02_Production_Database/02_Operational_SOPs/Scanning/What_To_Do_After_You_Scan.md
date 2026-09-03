# What To Do After You Scan

| Document Control | Value |
|---|---|
| Document Type | Operational SOP |
| System | Production Database — Scan |
| Task | Choose the correct action after scanning an MSB item |
| Audience | MSB volunteers and operators |
| Status | DRAFT — operator review and screenshots required |
| Owner | MSB Database Administrator |
| Last Reviewed | 2026-09-03 |
| Keywords | after scan, display record, testing, field wiring, procedures, container, controller, work orders |

## Purpose

Use this guide after Scan has identified an item and shown the available actions.

The most complete current landing page is the Display Scan hub.

## After Scanning a Display

A current Display Scan page shows the Display name, its `DISP` code, assigned Container when available, and the available actions.

Choose the action that matches what you are trying to do.

### Open Display Record

Choose **Open Display Record** when you need to view or maintain the normal Production Database information for the Display.

Examples include checking the Display record, container assignment, notes, or other information maintained there.

### Open Current Test Record / View Test Record

When current testing is available, Scan shows either:

- **Open Current Test Record** — the Display is in the active test session and still needs a test result; or
- **View Test Record** — a test result already exists for that active record.

If testing is not currently available, the testing button is greyed out and the text explains why. Examples include **No Container Assigned**, **No Container Test Session**, **Container Not Started**, **Container Testing Complete**, **Testing Not Required**, or **Testing Deferred**.

Do not try to work around a greyed-out testing state by opening a different Display or Container.

### Field Wiring

Choose **Field Wiring** when you need the current wiring information used to connect or troubleshoot the Display in the field.

### Procedures

Choose **Procedures** when you need the current field procedure package associated with the Display, such as available setup, takedown, or inspection material.

### Open Container

Choose **Open Container** when you need the Container currently assigned to the Display.

If no Container is assigned, the system cannot open one from the Display.

### Open Work Orders

Choose **Open Work Orders** when you need to review an active problem or repair record for the Display.

The button shows the number of active Work Orders.

Examples:

```text
Open Work Orders (2)
Open Work Orders (0)
```

When there are no active Work Orders, the button is disabled.

If there is one active Work Order, Scan opens it directly. If there is more than one, Scan shows a list so you can choose the correct Work Order.

## After Scanning a Container

The current Container Scan landing page provides:

- **Open Container Record** — open the Production Database Container record; and
- **Back to Scan** — return to the Scan start page.

Do not assume additional Container movement/setup actions are available through Scan until those workflows are implemented and documented.

## After Entering or Scanning a Controller

The Controller route opens Controller Inventory with the exact Controller ID in Search, one matching Controller shown, and that Controller's detail panel open.

Use the existing Controller Inventory information and actions there. Scan does not provide a second Controller-detail screen.

Physical Controller-label scanning remains pending until the printing service can produce the first label. Manual compact and full-URL Controller entry are deployed.

## Location Codes

`LOC` is an approved MSB identity type, but its complete operator Scan workflow is not yet deployed.

See [QR Code Types and Meanings](QR_Code_Types_and_Meanings.md) for the current boundary.

## Expected Result

After scanning an item, you should be able to choose the task you actually need without having to search through unrelated application menus.

## If Something Is Wrong

### The scanned item is not the item you expected

Stop before making changes. Recheck the physical label and the name/code shown on screen.

### The action you need is greyed out

Read the text shown on the disabled button. It normally explains why that action is unavailable in the current workflow state.

### An expected action is missing

Do not guess another route or substitute another record. Report what you scanned and what you expected to see so the current data/workflow can be checked.

## Related Documents

- [MSB Scan — Operator Guide](README.md)
- [Use Scan Manually](Use_Scan_Manually.md)
- [QR Code Types and Meanings](QR_Code_Types_and_Meanings.md)
- [Set Up a Phone or Tablet for Scanning](Set_Up_Phone_or_Tablet_for_Scanning.md)
