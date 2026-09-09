# Setup Session Manager Review Guide

| Document Control | Value |
|---|---|
| Document Type | Operator / Manager Procedure |
| System | Production Database — Setup Session |
| Audience | Setup Managers, reviewers, and administrators |
| Status | CURRENT — live 2025 review plus current reusable-task development |
| Owner | MSB Production Database / Setup administrator |
| Last Reviewed | 2026-09-09 |

## Purpose

Use this guide for the live Setup application and the Production-backed **2025 Historical Verification** session.

The 2025 session remains the annual review/training context, but the reusable catalog is now also the live working baseline for 2026 preparation.

This is **not disposable test data**. Changes saved in the application are real Production Database records.

## Current PostgreSQL Baseline

The reusable catalog reconstruction was accepted in Production on 2026-09-09:

```text
active reusable tasks      = 185
total reusable task rows   = 187
reusable prerequisites     = 0
2026 Setup Sessions        = 0
```

The prerequisite count is intentionally zero pending the reviewed predecessor/readiness pass.

The reviewed reconstruction workbook, 2025 notes, and recovered 2022 schedule remain evidence. They are not a parallel task master. Continue building and correcting reusable tasks against the **current PostgreSQL catalog**.

## Open the Application

Use:

```text
https://my.sheboyganlights.org/setup/
```

Sign in through the normal MSB Google/Cloudflare Access login.

Confirm the selected annual session is:

```text
2025 — Historical Verification
```

## The Most Important Safety Rule

The selected Setup Session controls the allowable operational year.

```text
2025 Historical Verification
    -> work dates and historical actual dates must be in 2025

future 2026 Setup Session
    -> work dates and operational dates must be in 2026
```

Audit timestamps remain truthful current timestamps.

Only an Administrator may create a new annual Setup Session or promote an annual order into the reusable future baseline.

Do **not** create the 2026 Setup Session yet. The current catalog and predecessor/readiness model must first be useful enough for planning.

## Annual 2025 Information vs Reusable Setup Knowledge

This distinction is fundamental.

### Annual 2025 information

Annual information describes what happened or was planned in 2025:

- verification/reconciliation state;
- annual planned order;
- 2025 crew/time evidence;
- annual notes;
- progress/completion evidence; and
- 2025 work-day/date/shift assignments where used.

### Reusable Setup knowledge

Reusable information describes how the work normally exists across seasons:

- task name and active state;
- Park Infrastructure / Stage / Scene scope;
- normal local sequence/order;
- normal crew range and expected duration;
- Physical Effort (`LIGHT`, `MODERATE`, `HEAVY`, or unreviewed);
- equipment/resources;
- prerequisites;
- completion point;
- readiness/weather notes; and
- reusable whole-Setup baseline order.

Before changing reusable information, ask:

> Is this a normal Setup rule we want to carry forward, or is this only something that happened in 2025?

If it only happened in 2025, keep it in annual history.

## Review / Reconciliation States

Current annual verification/reconciliation states are:

```text
UNVERIFIED
NEEDS_CORRECTION
VERIFIED
ASSIGNED
```

Use them as follows:

- `UNVERIFIED` — not yet sufficiently reviewed;
- `NEEDS_CORRECTION` — known to be wrong/incomplete and still needs work;
- `VERIFIED` — reviewed as the accepted annual record;
- `ASSIGNED` — the annual item is accepted as belonging to its current reusable task definition.

`ASSIGNED` is a **reconciliation state, not execution/completion state**. Assigned rows are preserved and can be filtered deliberately, but leave the default actionable review queue.

Reassigning/merging an annual item to a different reusable task remains a separate governed workflow.

## Add or Correct Reusable Tasks

If real Setup work is missing, Managers may add a reusable task when the work should normally exist beyond one historical occurrence.

Use **Add Task Here** in the correct scope. Use **Copy** when a new task is substantially similar to an existing task, then review the copy carefully.

A task is useful when it:

- can realistically be missed;
- affects readiness, planning, or resources;
- has meaningful prerequisites;
- needs progress/completion tracking; or
- preserves operational learning worth carrying forward.

Do not create separate reusable tasks for ordinary transport when movement/logistics owns that action.

Current example: `Bring Frosty to park` is logistics evidence and should not become the reusable task. The missing reusable work is physical **`Set Up Frosty`**, and Frosty setup must precede the applicable Stars setup work.

## Choose the Correct Scope

Reusable tasks can belong to three practical scopes.

### Park Infrastructure / no LOR Stage

Use this only for park-wide work with no appropriate LOR Stage or Scene owner.

### Stage-level / General

Use Stage-level when the task belongs to a real LOR Stage generally but should not be forced into a Scene.

### Scene

Use Scene scope when a current LOR Scene is the natural reusable organizational home for the work.

The Manager assigns scope explicitly. Do not infer Scene ownership merely from a task or Display name.

Issue #133 tracks the current drag/drop limitation between Stage-level and Scene scope. That limitation is non-blocking because governed scope editing still exists.

## Understand Task Scope, Display Ownership, and Containers

These are three different concepts. Do not use one as a substitute for another.

### Task scope answers: where does this work belong?

Stage/Scene scope describes the physical Setup area or organizational home of the work. A task may belong to a Stage or Scene even when **no Display is assigned to that task**.

Example:

```text
Grease Bearings
    -> belongs at 01-Front Gate
    -> requires the gate bearings to be greased
    -> has no Display work-package assignment
```

Do not move that task to Santa's Workshop or another area merely because no Display is attached to it. The task belongs where the work is physically performed.

### Display ownership answers: which Displays are this task's physical work package?

Display assignment is optional and separate from task scope.

Current operating rule:

```text
one Display
    -> zero or one reusable Setup task

one reusable Setup task
    -> zero, one, or many Displays
```

A Display must **not** appear in two different reusable Setup tasks. If a Display belongs to a Setup work package, one task owns that Display for reusable Setup planning/reporting.

Do not create one task per panel merely to make Display relationships easy. Build tasks at the practical crew/work-package level.

Examples:

```text
Set Up Traffic Signs
    -> one reusable task
    -> owns all Traffic Sign Displays assigned to that work package

Set Up MSB & Rotary Signs
    -> one reusable task
    -> owns the MSB/Rotary sign Displays assigned to that work package

Volunteer Path Setup
    -> separate reusable task when it is normally assigned to a parallel crew
```

LOR Scene/display-group information may help identify a logical batch of Displays, but it does **not** mean every task located in that Scene automatically owns every Display in that Scene.

### Containers answer: how do the Displays/material get to the park?

A Container is normally the storage/transport mechanism. It does not determine the task's Stage/Scene scope and does not create Display ownership.

For Display-bearing tasks, the intended direction is:

```text
reusable Setup task
    -> its assigned Display work package
    -> each Display's current Container assignment
    -> current storage/location information
```

This allows the future Pick List to determine what physical Containers must move without forcing operators to define task scope from Container storage.

Some Containers are themselves used as part of the deployed show. Containers marked as part of a Display (the existing `display_pallet` concept) are not ordinary empty transport Containers after Setup. When their deployed role requires them to remain at the park, they stay there through the show and return during Takedown rather than automatically returning to the workshop when their cargo is unloaded.

Keep that deployed-Container behavior separate from reusable task-to-Display ownership.

### Current Material / Logistics UI limitation

The current Material / Logistics resolver does not yet fully enforce this operating model. In particular, Scene scope can currently cause Displays to appear under a task even when the task does not own those Displays, while some Stage-level Display-bearing tasks can show zero Displays because their explicit work-package assignment has not been populated.

Treat those Material / Logistics results as **under active correction** while the task/Display ownership workflow is built. Do not create fake tasks or move tasks to the wrong scope to make that panel look populated.

While building the reusable catalog now, focus on:

- the correct practical task boundary;
- correct Stage/Scene location;
- crew size and expected duration;
- completion point;
- equipment/resources;
- effort;
- predecessors; and
- readiness conditions.

When a task clearly represents a Display work package, record/report the intended group of Displays so the governed assignment can be established. Do not manually duplicate one Display across multiple tasks.

## Review Resources and Effort

Use structured resources for recurring requirements such as lifts, vehicles, trailers, tools, and stake pounders.

Review:

- correct resource;
- quantity;
- Required vs Preferred status;
- Physical Effort where known; and
- whether the requirement belongs as reusable knowledge.

Do not invent quantities or effort values merely to fill fields.

## Review Prerequisites and Readiness

A prerequisite means another reusable task must complete first.

Readiness is different: a task may have all predecessors complete but still be blocked by leaves, weather, access, equipment, grass cutting, or another practical condition.

The 2026-09-09 catalog reconstruction intentionally reset all reusable dependencies. The next review pass must rebuild them deliberately and distinguish:

```text
HARD PREDECESSOR
PREFERRED ORDER
READINESS CONDITION
```

Do not rebuild a rigid chain merely because tasks happened in that order once.

## Review Order and Planning

Keep these concepts separate:

```text
Stage / Scene organization
reusable local task order
reusable whole-Setup baseline order
annual planned order
short-horizon work-day / shift / crew plan
```

Setup is not intended to be a rigid season-long Gantt schedule. Plan the next practical few work days, then revise as progress, weather, volunteer turnout, equipment, and site conditions change.

Tasks may span multiple days and may use parallel crews. A task remains `IN_PROGRESS` until its practical completion point is reached.

## Procedures

Stage- and Scene-scoped tasks use the established Google Drive Procedure structure. Park Infrastructure uses:

```text
G:\Shared drives\Display Folders\41 Park Infrastructure-PI
```

Where the application shows a current published Setup PDF, review whether it still matches the work. If an editable procedure is corrected, update the published PDF before treating the instruction as current.

## Current Live Boundary

Live now:

- Production-backed 2025 review/training;
- 185-active-task reusable PostgreSQL catalog;
- annual review/reconciliation including `ASSIGNED`;
- reusable task create/copy/maintenance;
- Stage/Scene scope and order maintenance;
- resource, effort, prerequisite, crew/time/readiness maintenance;
- Procedure/document context; and
- authenticated browser access.

Not yet Production-operational as complete workflows:

- Manager-facing task-to-Display ownership assignment;
- corrected Material / Logistics resolution under the one-Display/one-task rule;
- cross-Stage candidate planning / short-horizon scheduler surface;
- Pick List generation;
- mixed-stage Container annual mobilization/unload-state workflow; and
- Container/Display movement/scanning writes and park-location execution evidence.

## Current Task Development Rule

Use current PostgreSQL first.

```text
current reusable task data
    -> identify gap/correction
    -> verify scope and practical task boundary
    -> correct/add through governed Setup controls
    -> add predecessor/readiness/resource/effort knowledge when known
```

Do not restart a large spreadsheet import merely because a missing task is discovered.

## Related Documents

- [Setup operator portal](../../01_System_Architecture/12_Setup_and_Deployment/README.md)
- [2025 review procedure](../../01_System_Architecture/12_Setup_and_Deployment/operatorSOP/Review_2025_Setup_History.md)
- [Setup Session Shared Review and Season-Year Guard](../../01_System_Architecture/12_Setup_and_Deployment/Setup_Session_Shared_Review_and_Season_Year_Guard_2026-09-07.md)
