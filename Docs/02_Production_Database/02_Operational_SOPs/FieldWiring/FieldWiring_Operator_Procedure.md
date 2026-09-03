# FieldWiring Operator Procedure

| Document Control | Value |
|---|---|
| Document Type | Operational SOP |
| System | Production Database — FieldWiring |
| Task | Find and use current field wiring information |
| Production Version | V0.4.0 |
| Audience | Production Crew, Managers, Administrators, authorized production users |
| Status | CURRENT — SCREENSHOTS MAY BE ADDED LATER |
| Owner | MSB Database Administrator |
| Last Reviewed | 2026-09-03 |
| Keywords | field wiring, wiring, display, stage, sub-stage, scene, controller, output, plug, channel, wiring image |
| Engineering Authority | [Wiring System](../../01_System_Architecture/09_Wiring_System/README.md) |

[↑ FieldWiring Operational SOPs](README.md)

## Purpose

Use this procedure to find the current field wiring for a Display, Stage, Sub-stage, or Scene and to identify the Controller/output connections needed in the field.

FieldWiring is the current MSB field-wiring system. Use it instead of former FormView instructions or old saved wiring information when current FieldWiring is available.

The **Field Hookup** information is the primary wiring instruction. Wiring images are supplemental guidance to help locate equipment and understand the area.

## Before You Start

You need:

- an authorized MSB production account;
- a phone, tablet, Chromebook, or computer with web access; and
- enough information to find the wiring, such as a Display name/ID or the Stage, Sub-stage, or Scene where you are working.

If you are standing at a labeled Display, you may also enter FieldWiring from the Display Scan page.

## Open FieldWiring

Open:

```text
https://my.sheboyganlights.org/fieldwiring/
```

The page should show:

- **Find Display**;
- **Browse Stage / Scene**;
- a link to **Controller Inventory**; and
- the Field Wiring heading.

If the site does not open or you are told that you do not have access, contact the MSB Database Administrator or the person coordinating Production access. Do not use another person's login.

> **Screenshot placeholder — FieldWiring landing page showing Find Display and Browse Stage / Scene.**

## Find Wiring for a Display

Use **Find Display** when you know which Display you are working on.

1. In **Display Name or Display ID**, begin typing the Display name or ID.
2. Review the matching results.
3. Select the correct Display.
4. Review the **Wiring Selection** box that appears.
5. Confirm the Display, Stage/Area, Scene/Area, and Wiring context are correct.
6. Select **Open Field Wiring**.

Only Displays with current wiring are shown in the Display search.

You can search using a normal Display name such as:

```text
CH-RGBCandyCane-01
```

or a Display ID such as:

```text
DISP:309
```

Do not select a similarly named Display without checking the Stage/Area shown in **Wiring Selection**.

When Field Wiring opens from a Display search, the selected Display is identified at the top and its applicable hookup rows are highlighted where the presentation supports it.

> **Screenshot placeholder — Display search result and Wiring Selection confirmation.**

## Browse by Stage / Sub-stage / Scene

Use **Browse Stage / Scene** when you are wiring an area rather than looking for one specific Display.

1. Select the correct **Stage / Sub-stage**.
2. Review the wiring choices shown below it.
3. Choose the whole Stage/Sub-stage or the specific Scene you are working on.
4. If more than one current wiring context is available, pay attention to the displayed context such as **Background / Static** or **Musical**.
5. Review the **Wiring Selection** box.
6. Confirm the Stage/Area, Scene/Area, and Wiring context are correct.
7. Select **Open Field Wiring**.

A Sub-stage appears underneath its parent Stage in the Stage/Sub-stage list. Select the actual Sub-stage when that is where the work belongs.

Do not choose a whole Stage merely because a Scene or Sub-stage is unfamiliar. Use the wiring scope that matches the physical area you are working in.

> **Screenshot placeholder — Stage/Sub-stage selection with whole-area and Scene choices.**

## Confirm the Wiring Context

When Field Wiring opens, review the context at the top before connecting anything.

The page shows:

- **Selected Display** when you entered through a Display;
- **Stage**;
- **Scene / Area**; and
- **Wiring** context.

Confirm these match the work in front of you.

If the wrong Display, Stage, Scene, or wiring context is shown, select **Find another** and choose the correct one before continuing.

Normal crew use does not require opening **Technical details** or **Engineering details**. Those sections exist for troubleshooting and engineering review.

## Read the Field Hookup

The **Field Hookup** section is the primary source for making the physical connections.

### A/C and Pixie-style Controller groups

For Controller groups that use numbered physical outputs, the table normally shows:

- **Output / Plug** — the physical output or plug number;
- **Display** — the Display connected to that output; and
- **Plug Label / Channel Name** — the current wiring description.

Work through the Controller card and connect the Display to the shown physical output.

One physical output may show more than one Display line when the current show wiring intentionally shares that output. Do not assume repeated output numbers are an error.

One Display may also use more than one Controller or more than one output. Follow each displayed hookup relationship rather than assuming one Display equals one plug.

### DMX / DumbRGB / E1.31 groups

Not every Controller family is presented as a simple numbered A/C output table.

For DMX, DumbRGB, or E1.31 sections, follow the labels and connection information shown in that Controller/group card. Depending on the equipment, FieldWiring may show information such as:

- Display / Fixture;
- Connection;
- Network; or
- Physical Controller.

Do not substitute a raw universe, UID, or other number for a physical plug unless FieldWiring specifically presents it as the physical connection.

### Controller information

Controller cards may show the current Controller type, Unit ID information, Network, or permanent Controller information where available.

Use **Controller Inventory** when you need more information about the physical Controller itself. FieldWiring is the hookup guide; Controller Inventory is the physical Controller inventory/management system.

> **Screenshot placeholder — Field Hookup Controller card with Output / Plug, Display, and Plug Label / Channel Name.**

## Use the Wiring Image

The wiring image is supplemental. The **Field Hookup** information remains primary.

Use the image to help understand where Displays, Controllers, or wiring routes are located in the Stage/Scene.

Available image controls may include:

- **Hide Image / Show Image**;
- **Previous / Next** when more than one image exists;
- **Fit Width**;
- **Fit All**;
- zoom in/out; and
- a divider for resizing the image and hookup areas on larger screens.

On a phone or smaller screen, the layout may be different from the desktop layout. The same current Field Hookup information still applies.

### No wiring image available

FieldWiring can still provide valid hookup information when no wiring image exists.

If the page says:

```text
NO WIRING IMAGE AVAILABLE
```

continue using the **Field Hookup** information unless another warning tells you to stop.

### Context image — not wiring

If FieldWiring shows an image marked as context only or states that it is **not wiring**, do not use that image as a wiring diagram.

It may help identify the physical area, but the Field Hookup information is the wiring authority.

## Switch Wiring Context When Offered

Some Stage/Scene views can safely offer both current **Background / Static** and **Musical** wiring for the same physical scope.

When those buttons appear near the **Wiring** context:

1. Check which context is currently selected.
2. Select the other context only when that is the wiring you need to work on.
3. Confirm the Field Hookup information refreshes for the selected context.

If FieldWiring does not offer a context-switch button, return to **Find another** and select the correct Stage/Scene context from the lookup page instead of trying to force a different view.

## Open Field Wiring From a Display Scan

When a Display QR/code is scanned through the MSB Scan system, the Display action page includes **Field Wiring**.

1. Scan or enter the Display code.
2. Confirm the correct Display was found.
3. Select **Field Wiring**.
4. FieldWiring opens using that permanent Display identity.
5. Confirm the **Selected Display**, Stage, Scene/Area, and Wiring context before connecting anything.

A Display scan is a shortcut to the same current FieldWiring information. It does not create a separate wiring record.

## Print or Save a Field Copy

Use **Print / Save PDF** when a hard copy or offline PDF is needed for field work.

1. Open the correct current Field Wiring view.
2. Confirm the Stage/Scene and wiring context.
3. Select **Print / Save PDF**.
4. Use the browser's normal print or PDF-save controls.
5. Keep the generated/currentness information with the printed or saved copy.

Printed and saved copies can become outdated. A newer approved wiring snapshot supersedes an older copy immediately.

Whenever practical, reopen FieldWiring before starting work rather than assuming a saved copy is still current.

## Use Controller Inventory From FieldWiring

Select **Controller Inventory** when you need physical Controller information beyond the hookup instructions.

Depending on the current Controller relationship, FieldWiring may also provide a link directly to the related Controller.

Use Controller Inventory to review the physical Controller identity, model, current assignments, programmed information, status, firmware, or other Controller facts.

Do not copy Controller information into wiring notes as a replacement for the current Controller Inventory record.

## What Not To Do

Do not:

- use former FormView instructions as the current field-wiring procedure;
- assume an old printed/PDF wiring copy is still current without checking FieldWiring when access is available;
- connect a Display before confirming the Stage/Scene and Wiring context;
- treat a context-only image as a wiring diagram;
- ignore the Field Hookup table because an image looks familiar;
- assume one Display always uses only one Controller or one output;
- assume one output can never be shared by more than one Display;
- use raw UID, universe, or technical values as physical hookup instructions unless FieldWiring presents them that way;
- change physical wiring merely to force it to match the screen when something appears wrong; or
- use **Engineering details** as the normal volunteer wiring procedure.

## If Something Is Wrong

- **FieldWiring does not open / access is denied:** contact the MSB Database Administrator or Production access coordinator. Your production access may not be registered correctly yet.
- **A Display cannot be found:** confirm the Display name/ID and try searching by a distinctive part of the name. Only Displays with current wiring are shown.
- **The wrong Stage or Scene appears:** return to **Find another** and select the correct context. Do not continue in the wrong scope.
- **No current wiring context is available:** stop and report it. Do not substitute an old FormView procedure or unrelated Stage wiring.
- **No wiring image is available:** use the Field Hookup information. The image is supplemental.
- **Only a context image is shown:** use it for location/context only, not as the wiring diagram.
- **The physical Controller/Display/plug does not match FieldWiring:** stop and report the mismatch before changing connections. The physical condition or the approved wiring information needs to be reviewed.
- **A hookup row is unclear:** do not guess from UID, universe, Channel Name, or nearby outputs. Ask a Manager or the person responsible for the Stage to review it.
- **A saved/printed copy conflicts with the live system:** use the newer current FieldWiring information and report the discrepancy if the physical installation is already based on the older copy.
- **Controller information appears wrong:** open Controller Inventory and verify the physical Controller record. If the show wiring and physical Controller disagree, stop and have the discrepancy reviewed rather than changing one side casually.

## Expected Result

After using this procedure, the operator should be able to identify the correct current wiring context and connect each Display using the Field Hookup information shown by FieldWiring.

The operator should also be able to recognize when an image is only supplemental, when a saved copy may be outdated, and when a physical mismatch requires review instead of guessing.

Screenshots may be added after the procedure has been used by the crew. The written steps remain the controlling procedure until then.

## Related Documents

- [FieldWiring Operational SOPs](README.md)
- [Controller Inventory Operational SOPs](../Controllers/README.md)
- [Scanning Operational SOPs](../Scanning/README.md)
- [Wiring System Engineering Authority](../../01_System_Architecture/09_Wiring_System/README.md)
