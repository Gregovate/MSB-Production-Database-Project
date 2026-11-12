# Controller Inventory Operator Procedure

| Document Control | Value |
|---|---|
| Document Type | Operational SOP |
| System | Production Database — Controller Inventory |
| Production Version | V0.4.0 |
| Audience | Production Crew, Managers, Administrators, authorized read-only users |
| Status | CURRENT — SCREENSHOTS MAY BE ADDED LATER |
| Last Reviewed | 2026-09-03 |
| Engineering Authority | [Controller Inventory](../../01_System_Architecture/08_Controller_Inventory/README.md) |

[↑ Controller Inventory Operational SOPs](README.md)

## Purpose

Use this procedure to find physical Controllers, review their current information, plan Controller capacity, maintain Controller records, and manage current Controller-to-Display assignments.

The Controller Inventory browser is the normal operator interface. Do not edit Controller tables directly in PostgreSQL or try to recreate the workflow in Directus.

## Open Controller Inventory

Open:

```text
https://my.sheboyganlights.org/fieldwiring/controllers
```

Cloudflare Access identifies the signed-in user. The top of the page shows the resolved user/role when access has loaded.

If you can browse but do not see **Plan Capacity**, **Add Controller**, **Edit Controller**, or **Manage Assignments**, your current role may not allow Controller maintenance. Do not try to bypass the missing controls.

> **Screenshot placeholder — Main Controller Inventory screen.** Add a current production screenshot later.

## Important Rules Before Making Changes

- The Controller ID (`CTRL ####`) is the permanent identity of the physical Controller.
- Network, UID, IP address, Display, and Stage can change. They are **not** Controller identity.
- One Controller may serve more than one Display, and one Display may use more than one Controller.
- Intentional duplicate Network/UID addresses are valid in some parts of the show.
- The browser records what the **physical Controller is currently programmed as**. LOR/V7 remains the authority for what the show requires.
- There is no normal **Delete Controller** procedure. Unassigning a Display never deletes the Controller asset.
- If you do not know a value, leave it unknown or mark it for verification rather than guessing.
- Small **?** buttons beside less-obvious fields provide the accepted field explanation. Use them when a field meaning is unclear.

## Find a Controller

The main screen provides several ways to narrow the Controller list.

1. Use **Search** when you know any useful part of the Controller information. Search can match Controller, Display, Stage, model, serial number, or location.
2. Use **Stage / Sub-stage** to show Controllers serving Displays in one Stage or Sub-stage.
3. Use **Status** to narrow by operational state.
4. Use **Model** to narrow by Controller model.
5. Use **Assignment** to show all, assigned, or unassigned Controllers.
6. Select a Controller from the list to open its details on the right side.
7. Use **Clear** to remove the current filters.
8. Use **Refresh** when you need to reload current information after another change.

The summary cards at the top show current totals for:

- Total Controllers;
- Assigned;
- Unassigned;
- Firmware To Verify.

Stage is derived from current Display assignments. An unassigned shelf Controller normally has no Stage.

## Review a Controller

After selecting a Controller, review the detail panel before editing anything.

The detail panel shows the permanent Controller identity and current physical/operational facts, including the current Display assignments and firmware history.

Use the current assignments to confirm that you have selected the correct physical Controller before changing programming, status, location, or assignment information.

Where available, **Open Field Wiring** takes you to the wiring view for the related Display/Controller context. Use that for current wiring detail; do not copy wiring information manually into Controller notes as a substitute for Field Wiring.

> **Screenshot placeholder — Selected Controller detail screen.** Add a current production screenshot later.

## Plan Controller Capacity

**Plan Capacity** is a read-only planning tool for Managers and Administrators. It is intended for checking current Stage/Network evidence before a new Controller or Display is physically built or programmed.

1. Select **Plan Capacity** near the top of Controller Inventory.
2. Choose the Stage you are planning for.
3. Choose the Controller model.
4. Choose the LOR Network you are considering.
5. Review the physical Controllers already associated with the Stage.
6. Review current LOR usage and the physical Controllers already programmed on that Network.
7. Review the candidate contiguous UID blocks shown for the selected model width.
8. Pay attention to warnings about shared addresses, Stage/network mismatch, and AVAILABLE Controllers already programmed in the same range.
9. Close the planner when finished.

The planner does **not** reserve a UID range, change a Controller, or change LOR. It is planning evidence only. Recheck current conditions before the Controller is actually programmed or assigned.

> **Screenshot placeholder — Plan Capacity screen.** Add a current production screenshot later.

## Edit a Controller

Use **Edit Controller** to maintain facts about the physical Controller. Display assignments are handled separately under **Manage Assignments**.

1. Find and select the correct Controller.
2. Select **Edit Controller**.
3. Review the existing values before changing anything.
4. Update only facts you know are correct.
5. Use the **?** help beside a field when needed.
6. Select **Save Controller** when the changes are correct.
7. Confirm the Controller detail refreshes with the saved information.

If you start making changes and then select **Close** or otherwise leave the edit form, the browser warns about unsaved Controller changes. Keep that protection; only discard changes when you intend to.

### Identification and Operational State

Common fields include:

- **Model** — physical Controller model.
- **Status** — current operational state such as AVAILABLE, DEPLOYED, REPAIR, or RETIRED.
- **Physical Verification** — how confidently the physical Controller facts have been checked.
- **Hardware Revision** — board/hardware revision when known.
- **Serial Number** — manufacturer serial number when present.
- **Year Deployed** — first known year this physical Controller entered service.
- **Current Location** — where the Controller is currently stored or located.
- **Physically Attached to Display** — whether the Controller is mounted to, stored with, or normally moved with a Display. This is separate from the logical Display assignments below.
- **Label required** — marks that the Controller should have a permanent identity label. This does not itself request a physical print.
- **Notes** — useful Controller-specific information that does not belong in another structured field.

Do not use **Physically Attached to Display** to mean “this Controller has a Display assignment.” Those are separate facts.

### Current Programmed Configuration

Use this section to record how the physical Controller is programmed **now**.

- **LOR Network** — current programmed LOR Network.
- **First UID (hex)** — first programmed LOR Unit ID in hexadecimal.
- **UID Count** — number of sequential Unit IDs used by the Controller.
- **Calculated UID Range** — shown by the browser from First UID + UID Count.
- **Management IP** — current management IP where applicable.
- **Configuration Verification** — UNKNOWN, RECORDED UNVERIFIED, or VERIFIED.
- **Configuration Source / Verification Note** — where the recorded settings came from or what was checked.

If any of LOR Network, First UID, or UID Count is entered, all three must be entered together. The browser and database also enforce model-capacity and UID-range rules.

Do not change the Controller record merely to make it agree with a desired LOR plan. First determine whether the physical Controller or the show configuration is actually wrong.

### Firmware

Use the Firmware section to record the firmware installed on the physical Controller and how confidently that information has been checked.

- Choose the known **Installed Firmware** when available for that model.
- Use **Firmware Verification** to distinguish unknown, recorded-but-unverified, and physically verified firmware.
- Use the firmware note when useful to explain what was observed or how it was verified.

Do not change an unfamiliar firmware value just because another version is listed as recommended. Record the physical fact first; decide separately whether an upgrade is needed.

> **Screenshot placeholder — Edit Controller screen showing the three maintenance sections and ? help.** Add a current production screenshot later.

## Add a Controller

Use **Add Controller** when a physical Controller needs a permanent MSB Controller ID and does not already exist in Controller Inventory.

A new Controller does **not** need to be assigned to a Display immediately. Shelf stock is valid permanent inventory.

1. Select **Add Controller**.
2. Choose the correct physical model.
3. Confirm the starting Status. A newly discovered unassigned spare will normally be AVAILABLE unless its actual condition requires another status.
4. Enter the physical facts you know, such as serial number, hardware revision, year deployed, and current location.
5. Record current programmed Network/UID/IP facts only when they are known.
6. Record firmware and verification state only from actual evidence.
7. Leave unknown facts unknown rather than inventing values to complete the form.
8. Select **Add Controller** at the bottom of the form.
9. Record the new `CTRL` number assigned by the system.

The Controller ID is assigned automatically. Never type or reuse a Controller ID from another physical Controller.

> **Screenshot placeholder — Add Controller screen.** Add a current production screenshot later.

## Manage Display Assignments

Use **Manage Assignments** to maintain the current physical relationship between a Controller and one or more Displays.

### Review current assignments

1. Find and select the Controller.
2. Select **Manage Assignments**.
3. Review **Current Assignments** before changing anything.
4. Each assignment shows the Display and its Stage context plus the LOR wiring source.

The available actions are:

- **Edit** — keep the same Display relationship but change assignment details such as wiring source.
- **Replace** — move that relationship to a different Display in one controlled operation.
- **Unassign** — remove the relationship without deleting the Controller.

### Assign another Display

1. In **Assign Another Display**, search by Display name or Display ID.
2. Select **Search**.
3. Choose the correct Display from the results.
4. Select **Assign**.
5. Review the assignment editor.
6. Leave the LOR wiring source as **This Display** for normal assignments.
7. Use another Wiring Source Display only when the physical Display intentionally copies wiring that is defined by another Display.
8. If an AVAILABLE Controller is being assigned, the form normally offers **Change status from AVAILABLE to DEPLOYED when assigned**. Leave that checked when the Controller is actually going into service.
9. Select **Save Assignment**.
10. Confirm the new Display appears under Current Assignments.

### Replace an assignment

Use **Replace** when the current physical Controller relationship is moving from one Display to another and you want that handled as one controlled change.

1. Select **Replace** on the current assignment.
2. Search for the replacement Display.
3. Select **Replace With** on the correct Display.
4. Review the wiring-source choice.
5. Select **Save Assignment**.
6. Confirm the old relationship is gone and the new one is present.

### Unassign a Controller

1. Select **Unassign** on the relationship that should be removed.
2. If this is the final Display assignment for a DEPLOYED Controller, the browser asks whether the Controller should return to AVAILABLE.
3. Choose **OK** to return it to AVAILABLE when it is truly going back to shelf stock.
4. Choose **Cancel** in that first prompt when the Controller should remain DEPLOYED after the relationship is removed.
5. Confirm the second warning that removes the Display assignment.

The confirmation explicitly states that the **Controller asset itself will NOT be deleted**.

Do not silently change a Controller in REPAIR or RETIRED status merely to make an assignment work. Resolve the actual operational state first.

> **Screenshot placeholder — Manage Display Assignments screen.** Add a current production screenshot later.

## Record Verification

Verification states exist so the system can distinguish a value that was merely recorded from a value that was physically checked.

### Physical Verification

Use this for the physical Controller identity/facts as a whole. If the actual Controller has been checked in person, record the appropriate physically verified state. If field confirmation is still needed, leave it marked for field verification.

### Firmware Verification

Use:

- **UNKNOWN** when the installed firmware is not known;
- **RECORDED UNVERIFIED** when a version has been recorded but has not been checked on the actual Controller;
- **VERIFIED** when the physical Controller firmware has been checked.

### Configuration Verification

Use the same idea for Network / UID / IP programming:

- **UNKNOWN** — current programming is not known;
- **RECORDED UNVERIFIED** — programming has been recorded from evidence but not checked on the physical Controller;
- **VERIFIED** — programming was checked against the physical Controller.

Use the Source / Verification Note to say where the information came from or what was checked when that will help the next person.

## Controller Labels

The V0.4.0 Controller browser contains the governed **Print Label** request action, and **Label required** records whether the asset should have a permanent Controller label.

The Controller application does **not** own the physical printer polling service. Controller polling, Controller label template/profile selection, media/printer handling, physical printing, and successful request finalization belong to:

```text
Gregovate/MSB_LabelPrintService
Issue #14 / V4 label-service work
```

Until Controller polling is implemented and physically accepted in LabelPrintService, do not treat the Controller **Print Label** button as a completed physical-print procedure. A request may be recorded without a label being produced yet.

Do not create a second Controller print queue or manually clear Controller print flags as an ordinary operator workaround.

## Reporting

Offline/printable Controller reports are intentionally **deferred** at this time.

The crew should use V0.4.0 during normal work first. After real use, collect the reports, groupings, worksheets, or exception lists the crew actually asks for and design the reporting from that evidence.

Do not build a report solely because an earlier engineering discussion suggested one.

## What Not To Do

Do not:

- invent a Controller ID;
- use Network/UID/IP as permanent Controller identity;
- delete a Controller because it is no longer assigned;
- change a physical Controller record merely to force agreement with a proposed LOR plan;
- use **Physically Attached to Display** as a substitute for Display assignments;
- assign another Wiring Source Display unless the duplicated/copy wiring relationship is intentional and understood;
- guess serial number, firmware, location, programmed configuration, or verification state;
- bypass missing Manager/Admin controls through Directus or direct database edits;
- expect Controller physical label printing to be complete until the LabelPrintService Controller polling work is accepted; or
- design offline reports before field use establishes the actual need.

## If Something Is Wrong

- **The Controller cannot be found:** clear filters and search by Controller ID, Display, Stage, model, serial number, and location before adding a new asset.
- **A management button is missing:** verify the signed-in user/role. Do not work around the authorization boundary.
- **Save is rejected:** read the message. Correct the actual invalid or conflicting value; do not bypass model/UID/status rules.
- **The wrong Display appears in an assignment:** stop and verify the Display identity before changing the relationship.
- **The Controller is in REPAIR or RETIRED state:** do not force a normal deployment workflow over that state.
- **LOR and the physical Controller disagree:** determine which side is wrong before changing either one. Controller Inventory records physical current state; LOR/V7 records show-required wiring/configuration.
- **Print Label does not physically print:** Controller polling is owned by LabelPrintService and is not yet a completed Controller operator workflow.

## Expected Result

After using this procedure, the Controller Inventory should reflect the physical Controller that actually exists, its current operational/programmed facts, and its current Display relationships without changing Controller identity or LOR show authority.

Screenshots may be added after the procedure has been used in production. The written steps remain the controlling procedure until then.
