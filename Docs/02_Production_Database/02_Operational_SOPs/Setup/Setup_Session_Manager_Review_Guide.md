# Setup Session Manager Review Guide

| Document Control | Value |
|---|---|
| Document Type | Operator / Manager Procedure |
| System | Production Database — Setup Session |
| Audience | Setup Managers, reviewers, and administrators |
| Status | CURRENT |
| Owner | MSB Production Database / Setup administrator |
| Last Reviewed | 2026-09-15 |

## Purpose

Use this guide for the live Setup application and the Production-backed **2025 Historical Verification** session. This is real Production data.

## Open the Application

```text
https://my.sheboyganlights.org/setup/
2025 — Historical Verification
Client V0.3.13
```

Refresh or reopen Setup if the client marker is stale or unexpected before making a governed change.

## Safe Saving

Reusable task edits and annual review state are separate governed data surfaces. Pending reusable edits are protected by explicit Save / Discard / Stay behavior. Independent surfaces such as Physical Effort, Display/Container Material, Display Ownership, Kit Boxes, Extra Materials, Resources, Captains, prerequisites, expected Kit contents, and physical inventory use their own governed commands.

## Annual vs Reusable vs Physical Knowledge

Keep these facts separate:

```text
annual Session fact         = what happened / was planned for one season
reusable task requirement   = what normal Setup work requires
expected Kit/source content = what should normally be available from a physical source
physical inventory event    = what was actually counted/added/removed at a point in time
```

Before changing reusable information, ask whether it is a normal rule to carry forward or only something that happened in 2025.

## Add or Correct Reusable Tasks

Build reusable tasks at the practical work-package level used by crews. Do not create one task per Display merely to make inventory relationships easier.

Reusable tasks can belong to Park Infrastructure / no LOR Stage, Stage-level / General, or a real Scene. Programming-only LOR groups are not separate Setup Scenes.

## Display / Container Material

Use **Uses Display / Container Material** when the task needs current LOR-derived Displays for its Stage or real Scene.

```text
Stage-level task
    -> current Stage-level LOR Display groups
    -> true child-Scene material excluded

real Scene task
    -> exact current Display membership of that Scene

resolved Displays
    -> current Display-to-Container assignment
```

The Manager does not choose a separate Preview/programming group or maintain a competing ordinary Display list.

### Display Ownership for subdivided work

When only one reusable task is material-bearing in the scope, material resolution stays automatic.

When several material-bearing reusable tasks share the same applicable scope, open **Display Ownership**. Each current resolved Display must have exactly one effective reusable task owner.

You can click, Ctrl/Cmd-click, or Shift-click to select Displays. Drag selected Displays between task columns for normal scopes. For very large scopes, use **Move selected to** and **Move selected** instead of dragging across the full board.

The ownership screen shows **Coverage complete** when all resolved Displays have an effective owner.

Display Ownership does not change LOR membership and does not rewrite the Display's current Container.

## Kit Boxes

Use **Kit Boxes** to assign existing physical Kit Box Containers to the reusable task.

The picker is searchable. Assignments save immediately, assigned Kit names/IDs remain visible, and a wrong assignment can be removed directly.

The same physical Kit Box may support multiple reusable tasks. Do not infer a Kit assignment from name alone. Task-to-Kit assignment answers which physical Kit is needed; it does not by itself say what is inside the Kit.

## Task Extra Materials

Selected reusable tasks now include **Extra Materials Required by This Task**.

Managers may add/edit/remove a requirement and retain:

- material identity;
- required quantity and UOM;
- size, length/unit, and color where operationally important;
- quantity qualifier such as Exact, Minimum, Conditional, or Spare;
- verification state; and
- requirement/use notes.

Expected source Containers are displayed separately. A task can require T-Posts even when those posts come from shared stock rather than the assigned Kit.

Do not convert an unknown quantity/specification into a guessed value. Migrated `UNVERIFIED` / `NEEDS_REVIEW` rows are review queues, not automatically accepted truth.

## Kit Inventory

Open **Kit Inventory** from Setup or directly:

```text
https://my.sheboyganlights.org/setup/kit-inventory/
```

Use **All / Assigned / Unassigned** to find the physical Kit. The selected Kit shows a compact summary, then **Expected Kit Contents** as the primary review table.

Important distinctions:

- **Expected** = normal expected Kit quantity/specification.
- **On Hand** = current physical balance from inventory events.
- **Setup task assignment** = current reusable task-to-Kit relationships.
- **Displays stored in this Kit** = current `ref.display.container_id` truth, read-only here.
- **Unverified Items / Remainders** = unresolved procedure/reconstruction text that has not been normalized/verified.

Managers use **Add expected item** or **Edit** only for expected-content definition. Editing expected contents does not change physical on-hand.

For physical inventory, select one expected row and use **Count / Adjust**. An Initial Count establishes the first balance. Later Receipt, Return, Count Correction, Damage/Loss, Consumption, Transfer In/Out, or Other events change that balance without rewriting the expected definition. Record a reason/note when it helps explain the event.

Do not enter an expected/planning quantity as a physical count unless the item was actually counted.

## T-Post Inventory

Open:

```text
https://my.sheboyganlights.org/setup/t-post-inventory/
```

T-Post Inventory records physical T-Posts by their actual storage Container. The left list separates shared/bulk stock from T-Posts intentionally stored with Kits/Displays.

Each stock row represents one T-Post variant. **Planning / Known Qty** is optional reference evidence and is not the physical count. **Physical On Hand** comes only from inventory events.

Managers use **Add new T-Post row** / **Edit stock definition** to correct the stock-row definition (length, size/stock note, verification, planning quantity). That action does not record inventory and does not change a task requirement.

Use **Count physical stock** for the selected row to establish or adjust actual on-hand. Initial Count establishes the first balance; later events are signed changes.

A T-Post being stored with a Kit/Display is legitimate when that is the actual physical arrangement, but storage location does not assign the T-Post requirement to that Kit/Display/task. Requirement truth stays with the reusable task/installation scope.

## Resources and Effort

Search for an existing resource first. Keep catalog identity/type/notes/active state separate from task-specific quantity, Required-vs-Preferred, and task notes.

Use **Manage Resource Catalog** when the reusable catalog entry itself needs correction.

## Prerequisites and Readiness

Keep hard predecessor, preferred order, and readiness condition separate.

For fast prerequisite entry, hold **Shift** before left-button-down on the dependent task, drag it onto the prerequisite, and release. Normal drag without Shift remains task movement/reorder.

Task detail contains one canonical prerequisite list with Add / Up / Down / Remove controls. Circular dependencies are rejected.

## Procedures

Where the application shows a current published Setup PDF, review whether it still matches the work. If an editable source is corrected, update the current published PDF before treating the instruction as current.

## Current Live Boundary

Production-operational now includes:

- Production-backed 2025 review;
- reusable task create/copy/update/delete where governed safeguards allow;
- active-task identity and dirty-edit protection;
- Stage/real-Scene scope organization;
- automatic LOR-derived Display/Container resolution;
- explicit Display Ownership for multi-task scopes;
- many-to-many physical Kit Box assignment;
- structured reusable-task Extra Material requirements;
- expected Kit contents and Remainders;
- standalone Kit Inventory and T-Post Inventory;
- append-only physical inventory events/balances;
- resource/effort/prerequisite maintenance;
- reusable Resource Catalog maintenance;
- Procedure/document context; and
- protected authenticated browser access.

Still incomplete/separate:

- final reusable Catalog acceptance and disposable 2026 seed proof;
- structured readiness gating;
- Pick List generation and staged release scheduling;
- Container/Display movement/scanning writes; and
- park-location execution evidence.

## 2025 to 2026 Transition

There is currently no 2026 Setup Session. Every active reusable task is seeded into a new annual Session, so final Catalog acceptance remains required immediately before real 2026 creation.

Do not force a reusable task into 2025 merely to make the historical Plan look complete.

## Related Documents

- [Setup operator portal](../../01_System_Architecture/12_Setup_and_Deployment/README.md)
- [2025 review procedure](../../01_System_Architecture/12_Setup_and_Deployment/operatorSOP/Review_2025_Setup_History.md)
- [Setup engineering handoff](../../01_System_Architecture/12_Setup_and_Deployment/engineering/README.md)
- `Setup/Acceptance/Setup_Kit_Inventory_TPost_Production_Acceptance_2026-09-15.md`
