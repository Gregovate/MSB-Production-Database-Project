# Rolling Pick List and Pick Delay

| Document Control | Value |
|---|---|
| Document Type | Operational SOP |
| System | Production Database — Setup and Deployment |
| Task | Review current physical demand and manage temporary pick holds |
| Audience | Production Crew, warehouse/pickers, Setup Managers |
| Status | CURRENT |
| Owner | MSB Production Database / Setup administrator |
| Last Reviewed | 2026-09-30 |
| Keywords | Setup, 2026 Setup, Rolling Pick List, Pick By, Needed For, Pick Delay, Resume Pick, early-pick |

## Purpose

Use the **Rolling Pick List** to see which physical Containers/material are currently needed by the live 2026 Setup schedule.

Open:

[**Rolling Pick List**](https://my.sheboyganlights.org/setup/pick-list/)

The Pick List is a logistics projection of current demand. Merely appearing on the list does not prove physical movement. When the operator deliberately starts **Start Picking**, however, a successful Container/Display scan records the annual `PICKED` event for that demanded item.

## What Appears on the List

The list is intentionally limited to picker-actionable physical demand.

Current schedule and material authority determine what appears. When future scheduled work changes, its current material demand follows that schedule rather than requiring a second manual planning list.

Use the visible **Pick By** and **Needed For** timing to understand urgency. Rack/home-location information helps put the physical pull in practical warehouse order.

## Pick List Summary Counters

The Pick List summary is physical-material status, not a second schedule summary.

- **Items to pick** — current demanded physical items that are not delayed and are not already out/moved.
- **Delayed items** — current demanded physical items temporarily held by Pick Delay.
- **Items already moved** — current demanded physical items whose latest Setup movement state shows they are already out/moved. This may include Containers or standalone Displays and may include a real field observation that occurred without a prior Pick scan.
- **Containers picked** — current-demand Containers with an actual `PICKED` event in the current Setup Session.

**Containers picked** is therefore a true Pick throughput measure. A Container that is first discovered in the park through Record Location does not count as picked unless a real `PICKED` event also exists.

## Normal Picker Workflow

1. Open the Rolling Pick List. The working view defaults to **Needs pick**.
2. Work from the current highest-priority items shown by Pick By / Needed For and storage order.
3. Choose **Start Picking** when you are physically pulling/loading demanded material.
4. Scan the Container/Display with the Zebra/HID scanner, or use the explicit picker fallback.
5. A successful scan records **PICKED FOR PARK TRANSPORT**. The item then leaves the **Needs pick** working list.
6. While the scanner is armed, the sticky Pick panel keeps **Containers picked** visible so the material handler can track real Container throughput without scrolling back to the page totals.
7. Use **Already moved** or **All demanded items** only when you intentionally need to review material that is no longer in the Needs pick working set.
8. If the item should not be picked yet and you have Manager authority, use **Pick Delay** rather than changing the Setup schedule just to hide the item.

The Pick operation deliberately does **not** require separate Load or Depart buttons. The physical Pick scan means the item is going onto transport for the park.

## Training / Device Test

Use **Training / device test** when teaching or checking the forklift tablet/Zebra workflow.

Training uses the real current Pick List and the same scan validation, including delayed, already-moved, and not-on-current-list feedback, but:

- it does **not** record a `PICKED` movement;
- it does **not** add anything to the offline movement queue;
- it does **not** remove the item from the real **Needs pick** list;
- it does **not** change the real **Containers picked** count; and
- it may show a temporary **Training picks** count for the current training page/session only.

Entering Training requires deliberate confirmation. While active, the compact safety strip must continuously show **TRAINING — NO RECORDING** and provide **Exit Training**. A successful training scan reports **WOULD PICK … · NOT RECORDED** without repeating the same Training warning across the scanner panel.

Use normal Pick Mode only when the physical item is actually being picked for park transport.

**Record Location** is a separate field workflow used later to record where a Container/Display is physically observed. It is not embedded in the Pick List.

## Manager Early-Pick Demand

Manager early-pick creation/edit/cancel is not performed on the Rolling Pick List. The Pick List is the material-handler execution surface. Manager override control belongs on the separate Manager Material Status surface owned by #206/#122.

A Manager override may add an explicit early-pick demand when a deliberate physical pull is needed before normal schedule-derived demand would surface it.

An early-pick override:

- adds Pick List demand;
- does not schedule a Setup task;
- does not assign material to a reusable task; and
- does not mark anything physically picked or moved.

The **Pick By** and **Needed For** dates on a Manager override remain editable. Use **Edit Override** when a manual pick was entered with the wrong timing. The Container identity is locked during that edit; changing a Container means canceling the mistaken override and creating the correct one.

Pick List working order is:

```text
Pick By
-> Needed For
-> Home Location / rack walk order
```

That means an override accidentally dated earlier than the main pull can jump ahead of nearby rack items and confuse the material handler. Correct the override date rather than changing the permanent Home Location or fabricating movement.

Schedule-derived Pick By / Needed For dates remain schedule-owned. Correct those through the Scheduling/Setup authority rather than editing them as if they were Manager overrides.

Use an early-pick override only when the physical pull is intentionally needed early.

## Pick Delay

Use **Pick Delay** when an item is legitimately visible on the Pick List but should not be pulled yet.

A Pick Delay is temporary logistics state:

- it means **do not pick yet**;
- it does not cancel or defer the Setup task;
- it does not rewrite reusable knowledge;
- it does not change expected Kit contents or physical inventory; and
- it does not record movement.

Use **Resume Pick** when the item may be picked again.

The transient delay is also released when a requiring downstream task is scheduled, because the live schedule has become the stronger demand signal.

## Relationship to Setup Scheduling

Keep these concepts separate:

```text
Plan / Schedule
    = when and by whom the annual work is planned

Rolling Pick List
    = what physical material the current schedule says should be made ready

Physical movement / scanning
    = what actually moved
```

Do not add fake Setup tasks merely to make material appear on a list. Real labor remains real Setup work; physical material demand belongs on the Pick List.

## If Something Looks Wrong

If the Pick List shows material that does not make operational sense:

- do not invent a pick or movement event;
- check whether the scheduled work, task Extra Material requirement, expected source Container, Kit relationship, or current Container data is wrong;
- use **Report Correction** from the relevant scheduled Setup work when the problem was found in the field; or
- ask a Manager to correct the authoritative source through the appropriate Setup/data surface.

## Related Procedures

- [Setup operator procedure index](README.md)
- [Perform and Report Setup Work](Perform_and_Report_Setup_Work.md)
- [Extra Materials and Kit Inventory](Extra_Materials_and_Kit_Inventory.md)
- [Setup Manager Review Guide](../../../02_Operational_SOPs/Setup/Setup_Session_Manager_Review_Guide.md)
