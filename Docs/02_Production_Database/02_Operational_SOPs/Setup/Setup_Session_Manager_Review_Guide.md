# Setup Session Manager Review Guide

| Document Control | Value |
|---|---|
| Document Type | Operator / Manager Procedure |
| System | Production Database — Setup Session |
| Audience | Setup Managers, reviewers, and administrators |
| Status | CURRENT — live 2025 review plus current reusable-task development |
| Owner | MSB Production Database / Setup administrator |
| Last Reviewed | 2026-09-11 |

## Purpose

Use this guide for the live Setup application and the Production-backed **2025 Historical Verification** session.

The 2025 session preserves/corrects annual history while the reusable Catalog is the working baseline for future Setup planning. This is real Production data, not disposable test data.

## Open the Application

Use:

```text
https://my.sheboyganlights.org/setup/
```

Confirm the selected annual session is:

```text
2025 — Historical Verification
```

The selected Setup Session controls operational dates. The 2025 session accepts 2025 operational dates only. Audit timestamps remain truthful current timestamps.

Only an Administrator may create a new annual Setup Session or promote annual order into the reusable future baseline.

## Annual 2025 Information vs Reusable Setup Knowledge

Keep these separate.

### Annual 2025 information

Annual information describes what happened or was planned in 2025, such as:

- annual review/reconciliation state;
- annual planned order;
- 2025 crew/time evidence;
- annual notes;
- progress/completion evidence; and
- 2025 work-day/date/shift assignments where used.

### Reusable Setup knowledge

Reusable information describes how the work normally exists across seasons, including:

- task name and active state;
- Park Infrastructure / Stage / real Scene scope;
- normal local sequence/order;
- normal crew range and expected duration;
- Physical Effort;
- **Uses Display / Container Material**;
- equipment/resources;
- prerequisites/readiness;
- completion point; and
- reusable whole-Setup baseline order.

Before changing reusable information, ask:

> Is this a normal Setup rule we want to carry forward, or is this only something that happened in 2025?

## Add or Correct Reusable Tasks

Build reusable tasks at the practical work-package level used by crews.

Do not create one task per Display or panel merely to make inventory relationships easier.

A valid task may have no Display material at all. Examples include locating, some layout work, power/network preparation, greasing bearings, and other non-Display work.

## Choose the Correct Scope

Reusable tasks can belong to:

```text
Park Infrastructure / no LOR Stage
Stage-level / General
real Scene
```

Task scope answers **where the work belongs**. Do not move a task to the wrong Stage/Scene merely to make material appear.

Programming-only LOR groups are not separate Setup Scenes just because they exist in LOR.

## Uses Display / Container Material

Each reusable task has:

```text
[ ] Uses Display / Container Material
```

This is the operator control for normal Display/Container material resolution.

### Leave it unchecked

Leave it off when the task does not require LOR-derived Display material.

An unchecked task can still be a complete, valid, schedulable Setup task.

### Check it

Check it when crews performing that task need the current Displays/Containers associated with that task's Stage or real Scene.

Setup resolves material automatically:

```text
Stage-level task
    -> current Stage-level LOR Display groups
    -> true child-Scene material excluded

real Scene task
    -> exact current Display membership of that Scene

resolved Displays
    -> current Display-to-Container assignment
    -> deduplicated current Containers
```

The Manager does **not** choose a separate LOR Preview, programming group, or manual ordinary Display list as the material source.

If the result is wrong, first check whether the reusable task's Stage/Scene scope and material checkbox are correct. Do not create duplicate tasks or move work to an incorrect scope just to change the material result.

### Color marker

A colored marker/highlight identifies material-enabled tasks in supported views. It is only a visual cue. The checkbox is the stored reusable-task setting.

### Read-only material context

The task detail may show the resolved Displays/Containers as Material / Logistics context. This is for verification and downstream planning. Ordinary material membership comes from current LOR membership and current Display-to-Container assignment rather than a second manually maintained Setup list.

### Current limitation: material context is not yet task-specific release timing

The current resolver can still be too broad when one Stage has several separate physical Setup steps.

Example:

```text
Magic Igloo
    -> frame work
    -> skin installation
    -> later lighting/camera/finish work
```

The skins may need to stay warm in the workshop until the skin-install task. If more than one of those Stage-level tasks has the material checkbox enabled, the current resolver can show the same Stage-level Displays/Containers for each task because all of them share the same Stage scope.

That does **not** mean every resolved item should be picked, loaded, or delivered for the first task.

The current checkbox answers whether the task uses Stage/Scene Display material and shows that current context. It does not yet subdivide a Stage's material into task-specific release groups or determine when each subset should leave storage.

Task-specific staged material and pick-list timing are tracked in Issue #141 and remain future engineering work.

## Stage View and Planned Order

**Plan / Schedule** and **Perform Work** support Stage-oriented presentation.

Stage view groups work as:

```text
Stage
    Stage-level / General
    Scene — <real Scene>
```

Stage view is presentation. It does not rewrite annual planned order.

Switch to **Planned order** when you need to review or modify the annual planning sequence.

## Search

The shared **Find task or Stage** search works across:

- Reusable Task Catalog;
- Plan / Schedule; and
- Perform Work.

Search can use task, Stage, Scene, and related visible context. Clear the search to restore the full view.

## Review Resources and Effort

Use structured resources for recurring requirements such as lifts, vehicles, trailers, tools, stake pounders, and other real equipment.

Review:

- correct resource;
- quantity;
- Required vs Preferred status;
- Physical Effort where known; and
- whether the requirement belongs as reusable knowledge.

Do not invent quantities or effort values merely to fill fields.

## Review Prerequisites and Readiness

Do not treat these as the same thing:

```text
HARD PREDECESSOR
PREFERRED ORDER
READINESS CONDITION
```

A hard predecessor is another Setup task that must finish first.

A readiness condition may instead be an outside/site condition such as mowing/mulching being complete in the specific work area. Do not invent fake Setup tasks merely to represent external conditions.

Structured readiness remains future work; free-text readiness notes are descriptive, not a complete scheduling control.

## Rolling-Horizon Planning

Setup is not intended to be a rigid season-long Gantt schedule.

The normal operating direction is:

```text
remaining work
    -> prerequisites/readiness/resources
    -> Stage/candidate review
    -> schedule the next practical few days
    -> perform work
    -> record progress/completion
    -> replan
```

Tasks may span multiple work periods. Complete a task only when its practical completion point is reached.

## Procedures

Where the application shows a current published Setup PDF, review whether it still matches the work. If an editable source is corrected, update the current published PDF before treating the instruction as current.

## Current Live Boundary

Production-operational now includes:

- Production-backed 2025 review/training;
- reusable task create/copy/update/delete where governed safeguards allow it;
- Stage/real-Scene scope organization;
- automatic Display/Container material applicability and Stage/Scene context resolution;
- Stage-oriented Plan / Schedule and Perform Work presentation;
- search across Catalog, Plan / Schedule, and Perform Work;
- resource/effort/prerequisite maintenance;
- Procedure/document context; and
- authenticated browser access.

Still incomplete/separate work includes:

- final reusable Catalog cleanup before 2026 creation;
- task-specific staged material subdivision / release timing (#141);
- structured readiness gating;
- improved predecessor-entry interaction;
- Pick List generation/tablet workflow;
- mixed-stage Container annual mobilization/unload-state workflow;
- Container/Display movement/scanning writes; and
- park-location execution evidence.

## 2025 to 2026 Transition

There is currently no 2026 Setup Session.

The annual Session creation command seeds **every active reusable task** into the new Session. Therefore active Catalog cleanup is mandatory before 2026 creation.

A valid reusable task may have no 2025 annual row because it was reconstructed or created after the historical annual rows were established. Do not force that task into 2025 merely to make the 2025 Plan look complete.

Issue #145 tracks the Catalog-cleanup gate before 2026 creation.

## Related Documents

- [Setup operator portal](../../01_System_Architecture/12_Setup_and_Deployment/README.md)
- [2025 review procedure](../../01_System_Architecture/12_Setup_and_Deployment/operatorSOP/Review_2025_Setup_History.md)
- [Setup engineering handoff](../../01_System_Architecture/12_Setup_and_Deployment/engineering/README.md)
