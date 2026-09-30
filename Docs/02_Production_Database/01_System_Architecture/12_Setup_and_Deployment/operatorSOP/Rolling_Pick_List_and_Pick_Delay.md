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

The Pick List is a logistics projection of current demand. It does not by itself prove that a Container was physically picked, moved, delivered, or scanned.

## What Appears on the List

The list is intentionally limited to picker-actionable physical demand.

Current schedule and material authority determine what appears. When future scheduled work changes, its current material demand follows that schedule rather than requiring a second manual planning list.

Use the visible **Pick By** and **Needed For** timing to understand urgency. Rack/home-location information helps put the physical pull in practical warehouse order.

## Normal Picker Workflow

1. Open the Rolling Pick List.
2. Work from the current highest-priority items shown by Pick By / Needed For and storage order.
3. Use the Container identity and displayed material/task context to find the correct physical item.
4. If the item should not be picked yet and you have Manager authority, use **Pick Delay** rather than changing the Setup schedule just to hide the item.
5. Do not treat the Pick List as a physical movement/completion record.

Persisted physical PICKED/movement execution belongs to the separate movement/scanning workflow.

## Manager Early-Pick Demand

A Manager may add an explicit early-pick demand when a deliberate physical pull is needed before normal schedule-derived demand would surface it.

An early-pick override:

- adds Pick List demand;
- does not schedule a Setup task;
- does not assign material to a reusable task; and
- does not mark anything physically picked or moved.

Use it only when the physical pull is intentionally needed early.

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
