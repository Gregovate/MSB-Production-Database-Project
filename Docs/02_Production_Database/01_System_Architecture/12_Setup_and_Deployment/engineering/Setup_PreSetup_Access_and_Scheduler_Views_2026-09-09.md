# Setup Pre-Setup Access Work and Scheduler Views — 2026-09-09

| Document Control | Value |
|---|---|
| Document Type | Engineering Planning-Workflow Contract |
| System | Production Database — Setup Session |
| Status | CURRENT DESIGN DIRECTION — operator-confirmed; not yet implemented |
| Owner | MSB Production Database engineering |
| Related Work | Issue #122; Setup Smart Scheduler Workflow; Setup Planning Operating Model; Setup Pick List Tablet Workflow |

## Purpose

Capture two operator-confirmed requirements exposed during the 2022/2025/current-catalog reconciliation:

1. the future scheduler needs simple operator views for schedulable, scheduled, completed, and unscheduled work; and
2. some early historical `staging`-like work is actually **real Pre-Setup access/mobilization work** because large items must be moved out of the workshop before crews can physically reach Displays stored on racks behind them.

This corrects an earlier oversimplification that treated nearly all old staging rows as obsolete once a future Pick List exists.

## Scheduler Views

The scheduler should provide simple derived views/filters over the same annual task state. Do not create duplicate task records merely to support these views.

### Available to Schedule

Show only incomplete work whose accepted hard predecessors/readiness conditions are satisfied and that does not already have an active future assignment.

This is the primary smart-scheduler candidate pool.

```text
incomplete
+ hard prerequisites satisfied
+ hard readiness satisfied
+ no active future assignment
-> Available to Schedule
```

Blocked downstream tasks such as `Lay Cords`, network connection, or other dependency-gated work remain absent from this primary view until they become eligible.

### Scheduled

Show tasks already assigned to a near-term work day / shift / crew lane.

This is short-range execution planning state and remains separate from reusable Stage/Scene order.

### Unscheduled / Outstanding

Provide a broader operator view of **all incomplete work that has no active future assignment**, including:

- currently available work;
- blocked/not-ready work;
- in-progress work needing continuation; and
- other outstanding annual tasks.

This view answers:

> What is still out there that has not been put on a work day yet?

It should support filters such as `Available`, `Blocked`, `In Progress`, Stage, Scene, effort, or other useful planning context.

### Completed

Provide a completed-work view so operators can see what has already been finished without mixing completed work into the active scheduler.

Completion history remains important for progress review and for understanding why downstream tasks became eligible.

### All

A full annual-task view should remain available for inspection/search. It is not the primary scheduling board.

## Pre-Setup Access / Workshop Clearance Is Real Work

A future Pick List removes the need for a generic manual `stage everything at the park because we do not know what we will need` process.

However, some work at the top of the old Setup list has a different and still-valid purpose:

> Large items must be moved out of the workshop before crews can physically reach Displays/racks behind them.

Operator examples include items such as:

- Whoville Spiral Tree / Whoville tree trailer;
- Mega Tree trailer;
- car counters; and
- other bulky floor-stored items that block access to rack-stored Displays.

These are not merely Pick List rows. They are **access-enabling Setup work**.

## Recommended Concept — Pre-Setup Access / Mobilization

Use a simple operator concept such as **Pre-Setup Access** or **Workshop Clearance** rather than reviving the old broad `Staging to Park` abstraction.

A task belongs here when moving/positioning an item is itself necessary to unlock later work.

Examples:

```text
Move Mega Tree trailer out of workshop / into field position
    -> opens workshop access behind/around it

Move Whoville tree trailer / Spiral Tree material
    -> opens access to rack-stored Displays

Move car counters / bulky floor items
    -> clears aisle or rack access for later picks
```

Exact task names should come from the reconciliation list and operator review rather than being invented from this design document.

## Relationship to Pick List

The distinction is:

```text
PRE-SETUP ACCESS / WORKSHOP CLEARANCE
    real work required to make inventory physically reachable

PICK LIST
    derived list of Containers/Displays/material required for selected near-term Setup work
```

A Pick List can tell the crew what needs to be pulled, but it cannot make an inaccessible rack physically reachable. If a large object blocks that access, the access-enabling move remains a real task/prerequisite.

Do not delete old early-season rows merely because they look like staging. During reconciliation, classify them as one of:

```text
PRE-SETUP ACCESS / MOBILIZATION — keep as real reusable work
PICK LIST / LOGISTICS ONLY — future derived logistics behavior
REAL FIELD SETUP TASK — keep normally
OBSOLETE GENERIC STAGING — remove/retire after review
```

## Ordering Value of Historical Dates

The early dates/order in the 2022 Project schedule are especially useful for identifying access-enabling work.

Items appearing at the very top of the old list may be early not because their final display installation has highest show priority, but because moving them first opens the workshop so later inventory can be reached.

Therefore historical dates and relative order should be preserved as evidence when reviewing Pre-Setup tasks.

Do not automatically convert those dates into future fixed calendar dates.

## Dependency / Readiness Direction

Where evidence is clear, Pre-Setup access work may become a hard prerequisite or readiness gate for later work.

Avoid creating hundreds of item-level dependencies merely to describe the workshop floor plan.

The first implementation should use the simplest durable relationship that reflects actual operations, for example:

```text
Workshop access-clearing task COMPLETE
    -> affected later Setup work can become eligible
```

If more granular rack/zone access dependencies are later proven necessary, add them deliberately from real operator evidence rather than building a warehouse-optimization model up front.

## Initial Complexity Guardrail

Do not overbuild this into inventory-path optimization.

The first useful behavior is:

1. keep the real access-enabling Pre-Setup tasks;
2. preserve their preferred early order;
3. add only real prerequisites/readiness relationships;
4. let completing them naturally expose more work in `Available to Schedule`;
5. use Pick List separately for the material required by the work actually selected next.

## Acceptance Direction

A future scheduling release should prove:

1. `Available to Schedule` contains only truly eligible work;
2. `Scheduled` shows near-term assigned work;
3. `Unscheduled / Outstanding` shows all incomplete unscheduled work, including blocked and in-progress items;
4. `Completed` provides an easy historical/progress view without cluttering active planning;
5. real Pre-Setup access tasks can remain early reusable work;
6. completing an access-enabling task can unlock downstream work where a true dependency exists;
7. a future Pick List does not accidentally erase real workshop-access work; and
8. obsolete generic staging can still be removed during reconciliation.

## Related Durable Sources

- [Setup Smart Scheduler Workflow](Setup_Smart_Scheduler_Workflow_2026-09-09.md)
- [Setup Planning Operating Model](Setup_Planning_Operating_Model_2026-09-08.md)
- [Setup Planning Candidate Work View](Setup_Planning_Candidate_Work_View_2026-09-09.md)
- [Setup Pick List Tablet Workflow](Setup_Pick_List_Tablet_Workflow_2026-09-09.md)
- GitHub issue #122
