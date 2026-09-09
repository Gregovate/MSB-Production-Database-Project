# Setup Planning Candidate Work View — 2026-09-09

| Document Control | Value |
|---|---|
| Document Type | Engineering Planning-Workflow Contract |
| System | Production Database — Setup Session |
| Status | CURRENT DESIGN DIRECTION — operator-confirmed; not yet implemented |
| Owner | MSB Production Database engineering |
| Related Work | Issue #122; PR #125; Setup Planning Operating Model; Setup Pick List Tablet Workflow |

## Purpose

Define the planning surface that sits **between the reusable task catalog and the short-range work-day schedule**.

This is the difficult planning problem that the current Setup application does not yet solve.

The reusable task catalog is primarily organized by Stage/area because that is how operators can understand, review, and visualize Setup work. That organization must not be mistaken for the way work is actually scheduled in the field.

The planner needs a separate cross-Stage view that answers:

> What work is available to do, what can we do next, and what do we want to do next?

Once that choice is made, downstream schedule and Pick List behavior should follow from the selected work instead of relying on tribal knowledge.

## Three Different Views

Setup needs three different concepts that must not be collapsed into one screen or one ordering rule.

### 1. Reusable Task Catalog

Purpose:

- preserve the full repeatable Setup process;
- organize tasks primarily by Stage/Sub-stage/Scene/area for human comprehension;
- preserve preferred order, predecessors, crew guidance, equipment, readiness constraints, and expected effort;
- support reconstruction and maintenance of reusable knowledge.

This is the best place to **see and understand the work**, but not the place to pretend the full season is scheduled.

### 2. Planning Candidate Work View

Purpose:

- combine all incomplete annual tasks across Stages;
- apply hard predecessors/readiness constraints;
- show which work is available now and which is blocked;
- show useful planning evidence without forcing a date;
- let the operator decide what should be scheduled next.

This is the missing planning surface.

### 3. Short-Range Work-Day Schedule

Purpose:

- assign selected candidate work to the next few actual work days;
- reflect volunteer/equipment availability and weather/site conditions;
- support partial continuation of multi-day tasks;
- feed downstream Pick List/material/logistics demand.

The schedule is an **output of planning**, not the master definition of task order.

## Historical Order and Predecessors

The recovered 2022 Project schedule and reconstructed 2025 work provide useful evidence for:

- relative order;
- predecessor relationships;
- rough seasonal timing;
- crew/resource patterns; and
- common task grouping.

But historical Project-style predecessors must not automatically become hard scheduling constraints.

During reconstruction, distinguish:

```text
HARD PREDECESSOR
    task genuinely cannot/should not proceed until prior work is complete

PREFERRED ORDER
    normally done after/before another task, but operator may legitimately reorder it

READINESS CONDITION
    task becomes available when a site/material/weather/grass/equipment condition is true
```

The planner should explain **why** a task is or is not available rather than simply hiding it.

## Candidate Work Buckets

The planning view should derive at least these operator-visible buckets:

```text
AVAILABLE NOW
    prerequisites/readiness satisfied
    incomplete
    not already scheduled

AVAILABLE WITH CONDITION / REVIEW
    generally possible but has a visible soft constraint, resource need, or operator decision

BLOCKED / NOT READY
    hard predecessor/readiness condition not satisfied

IN PROGRESS — NEEDS CONTINUATION
    partial work exists
    task is incomplete
    no future work-day assignment exists

SCHEDULED
    already assigned to a near-term work day

COMPLETE
    excluded from candidate planning
```

The exact labels may change during browser review, but the distinction is required.

## What the Planner Should Show

For each candidate task, the operator should be able to see enough context to make a decision without opening several unrelated pages:

- Stage / area;
- reusable task name;
- preferred order;
- predecessor/readiness status;
- why it is available or blocked;
- expected crew range;
- useful capability/qualification needs when the People subsystem is ready;
- required equipment;
- expected duration/effort guidance;
- current progress / percent or completion note where available;
- material/container readiness;
- weather/site restrictions;
- whether the task has already been scheduled;
- whether selecting it will trigger notable logistics work.

The operator must still be able to group/filter by Stage because Stage is the easiest way to visualize the physical Setup process.

## Scheduling Interaction

A candidate task should not receive a future date merely because it appears in the planning view.

The expected workflow is:

```text
open Planning
    -> review Available / Blocked / In-Progress work across Stages
    -> filter/group by Stage if useful
    -> choose one or more tasks that make sense next
    -> assign those tasks to a near-term work day
    -> planner records the real short-range schedule
    -> Pick List derives physical material/container needs
```

Selection should remain flexible. The system provides evidence and constraints; the operator chooses the practical next work.

## Relationship to Stage Organization

Stages remain extremely useful for:

- task maintenance;
- visual understanding;
- reconstructing the Setup process;
- reviewing whether a Stage is missing steps;
- displaying progress by area.

But **Stage completion is not a scheduling gate**.

The planning view must allow work from several Stages to appear together and be selected in whatever practical combination fits the current crew, equipment, weather, readiness, and material situation.

## Relationship to Pick List

Planning decisions should drive logistics automatically.

```text
candidate work selected for a near-term day
    -> required Displays/assets
    -> current Containers
    -> mixed-stage/shared Container rules
    -> Pick List demand
```

This is how tribal knowledge moves into the system.

The operator should not separately remember that scheduling a particular arch or Display implies moving/unloading a particular trailer/container.

## Arch Trailer — Operator-Confirmed Unload/Access Order

Container 34 / Arch Trailer has an operator-confirmed physical unload order, described as **backwards through the park**:

1. Racing Arches
2. Polar Bear Arch
3. Candyland Arch
4. Icicle Tunnel Arches
5. Stars
6. Food Collection Arches

This is not the Setup Stage schedule. It is **Container-specific logistics knowledge** used to determine what must be unloaded when scheduled work requires material from that trailer.

The system should preserve this order so operators do not need to know it from memory.

Example:

```text
Candyland Arch is selected for near-term work
    -> system resolves Candyland Arch to Arch Trailer
    -> system sees the trailer unload/access order
    -> if Racing Arches and Polar Bear Arch groups are still loaded ahead of Candyland,
       the Pick List shows the required unload sequence through Candyland
    -> operator may unload the required groups or choose Unload All Remaining
```

If earlier groups are already unloaded, they are skipped.

The operator should scan the **Container once**, not every Display/piece. The system tracks the annual stage-group/container unload state.

Current operator-confirmed normal planning guidance for Arch Trailer unload work is:

```text
crew = 2 people
elapsed time = approximately 60–90 minutes
```

Historical 2025 crew evidence remains separate and must not overwrite this reusable guidance automatically.

If future review shows partial-stage unloads have meaningfully different effort, that can be captured later; do not invent per-stage duration now.

## General Mixed-Stage Container Rule

The same concept applies to the Antenna Trailer and any Container whose contents span multiple Stages.

The resolver should determine mixed-stage membership from authoritative Display-to-Container and Stage relationships. Container-specific physical access/unload order may require durable additional knowledge where the order cannot be derived from those relationships alone.

For a mixed-stage Container:

- one Container scan is sufficient for normal grouped execution;
- operators can confirm one Stage group, several Stage groups, or all remaining contents unloaded;
- already-unloaded groups remain complete for that annual Setup Session;
- later scheduling of another carried Stage should surface only the still-needed unload work;
- Container arrival at the park does not imply that every carried Stage has been unloaded;
- known physical access order must be honored when deciding which groups must come off first.

## Architecture Consequence

Do not model the planner as:

```text
Stage 01 dates
Stage 02 dates
Stage 03 dates
...
```

and do not model it as a restored Microsoft Project Gantt chart.

The more accurate architecture is:

```text
Reusable Catalog
    organized for understanding by Stage/area

Annual Task State
    progress + completion + readiness + predecessor state

Planning Candidate View
    cross-Stage available/blocked/in-progress work

Operator Choice
    what do we want/can we do next?

Short-Range Work-Day Schedule
    actual next few days

Pick List
    derived physical requirements and mixed-container logistics

Field Execution
    progress + logistics state + actual history
```

## Current Gap

As of this design record:

```text
cross-Stage candidate planning view        = NOT IMPLEMENTED
available/blocked explanation surface       = NOT IMPLEMENTED
short-range candidate-to-work-day workflow  = PARTIAL / requires engineering review
Pick List generator/tablet workflow         = NOT IMPLEMENTED
mixed-stage unload/access-order resolver     = NOT IMPLEMENTED
```

Do not describe these as current Production capabilities.

## Acceptance Direction

A useful first planning release should prove:

1. the operator can see incomplete work across all Stages without assigning fake dates;
2. Stage grouping/filtering remains available for visual understanding;
3. hard predecessor/readiness blockers are visible and explainable;
4. preferred order is visible but does not prevent legitimate reordering;
5. in-progress multi-day work returns to the planning candidates when it needs continuation;
6. selected tasks can be assigned to a near-term work day without rebuilding the reusable catalog;
7. scheduling a task automatically exposes downstream Pick List/material consequences;
8. mixed-stage Container logistics do not require tribal knowledge;
9. the Arch Trailer access/unload order is correctly honored; and
10. the resulting workflow makes scheduling easier rather than requiring the operator to maintain a Gantt chart.

## Related Durable Sources

- [Setup Planning Operating Model](Setup_Planning_Operating_Model_2026-09-08.md)
- [Setup Pick List Tablet Workflow](Setup_Pick_List_Tablet_Workflow_2026-09-09.md)
- [Setup engineering portal](README.md)
- GitHub issue #122 — Setup Session planning / Pick List / movement umbrella
