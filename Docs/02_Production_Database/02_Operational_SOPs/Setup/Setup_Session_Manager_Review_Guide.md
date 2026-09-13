# Setup Session Manager Review Guide

| Document Control | Value |
|---|---|
| Document Type | Operator / Manager Procedure |
| System | Production Database — Setup Session |
| Audience | Setup Managers, reviewers, and administrators |
| Status | CURRENT |
| Owner | MSB Production Database / Setup administrator |
| Last Reviewed | 2026-09-12 |

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

Reusable task edits and annual review state are separate governed data surfaces. Pending reusable edits are protected by explicit Save / Discard / Stay behavior. Independent surfaces such as Physical Effort, Display/Container Material, Display Ownership, Kit Boxes, Resources, Captains, and prerequisite maintenance save through their own governed commands.

## Annual vs Reusable Knowledge

Annual 2025 information describes what happened or was planned in 2025. Reusable information describes normal Setup knowledge that should carry forward.

Before changing reusable information, ask:

> Is this a normal Setup rule we want to carry forward, or is this only something that happened in 2025?

## Add or Correct Reusable Tasks

Build reusable tasks at the practical work-package level used by crews. Do not create one task per Display merely to make inventory relationships easier.

Reusable tasks can belong to Park Infrastructure / no LOR Stage, Stage-level / General, or a real Scene. Programming-only LOR groups are not separate Setup Scenes.

## Display / Container Material

Use **Uses Display / Container Material** when the task needs current LOR-derived Displays for its Stage or real Scene.

The accepted resolver remains:

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

### Kit Boxes

Use **Kit Boxes** to assign existing physical Kit Box Containers to the reusable task.

The picker is searchable. Assignments save immediately, assigned Kit names/IDs remain visible, and a wrong assignment can be removed directly.

The same physical Kit Box may support multiple reusable tasks. Do not infer a Kit assignment from name alone.

Detailed expected Kit contents, Extra Materials, quantities/specifications, and source relationships are not yet part of the live operator workflow.

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
- large-scope non-drag Display movement through **Move selected to**;
- resource/effort/prerequisite maintenance;
- reusable Resource Catalog maintenance;
- Procedure/document context; and
- protected authenticated browser access.

Still incomplete/separate:

- structured Extra Materials / expected Kit contents / source tracking;
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
- `Setup/Acceptance/Setup_Assignment_Layer_V0313_Production_Acceptance_2026-09-12.md`
