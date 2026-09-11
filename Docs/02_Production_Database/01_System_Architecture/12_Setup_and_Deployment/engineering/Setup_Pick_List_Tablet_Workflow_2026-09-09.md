# Setup Pick List Tablet Workflow — 2026-09-09

| Document Control | Value |
|---|---|
| Document Type | Engineering Workflow Contract |
| System | Production Database — Setup Session |
| Status | CURRENT DESIGN DIRECTION — not yet implemented |
| Owner | MSB Production Database engineering |
| Related Work | Issue #122; Issue #113; PR #125 |

## Purpose

Define the operator-facing Pick List workflow that belongs inside Setup.

There is currently **no live Pick List report/generator** and no accepted Setup Pick List operator surface. This document records the required direction so reconstruction work does not assume that capability already exists.

The Pick List should be a **standalone section of the Setup application**, usable on a tablet in the workshop/yard/park and able to use supported scanning input.

It is not a generic report and it is not a replacement for the shared Scan identity resolver. Setup owns the business workflow; Scan infrastructure supplies identity capture/resolution.

## Operator Goal

The operator should be able to open a Setup Pick List view and answer:

> What Containers, Displays, trailers, and support material need to be prepared or moved for the work we are scheduling next?

The list must be derived from actual Setup work, not manually maintained as a separate staging spreadsheet.

## Required Inputs

The Pick List should consume:

```text
near-term scheduled Setup tasks
+ preferred order / Needs Scheduling queue
+ reusable task -> Display / support Container relationships
+ current Display -> Container relationships
+ current Container/location state
+ mixed-stage Container contents
+ annual Setup movement/mobilization state
```

A scheduled task/date is the strongest needed-by signal. For work not yet dated, preferred order/readiness may establish priority without inventing a calendar date.

## Standalone Setup Section

The Pick List should be a first-class Setup section, for example:

```text
Setup
  Planning / Needs Scheduling
  Work Days
  Pick List
  Execution / Progress
  Reusable Task Catalog
```

The exact navigation label may change during browser review, but Pick List must not require the operator to leave Setup and work from raw Directus tables.

## Tablet / Field Requirement

The Pick List must be practical on a tablet while moving through workshop/storage areas.

Minimum interaction principles:

- large touch targets;
- low typing burden;
- clear current item/container context;
- quick scan-confirm workflow;
- tolerate HID scanner input such as Zebra DS3678;
- support browser camera scanning where the shared Scan capture layer is accepted;
- manual search/entry fallback;
- do not require desktop-only interaction for normal pick work.

## Scanning Boundary

Supported captured identities remain owned by the shared Scan/identity contract, such as:

```text
DISP:<display_id>
CONT:<container_id>
LOC:<location_code>
```

Within the Setup Pick List, scanning gives Setup a verified identity to act on. Setup then applies the Pick List business meaning.

Examples:

```text
scan CONT
  -> resolve Container
  -> show why it is on this Pick List
  -> confirm/move/mark appropriate Setup logistics state

scan DISP
  -> resolve Display
  -> show required task(s), current Container, and pick status

scan LOC
  -> resolve Location
  -> use only within an explicitly accepted movement/location workflow
```

Do not infer a business movement merely from scan order unless the Setup workflow explicitly defines that sequence.

## Pick List Resolution

The resolver must follow:

```text
selected / scheduled Setup work
  -> required Displays / assets
  -> current Containers
  -> deduplicate Containers
  -> show why each Container/item is required
```

The same Container may satisfy several tasks or Stages. The Pick List must show those reasons rather than duplicating the Container as unrelated rows.

## Mixed-Stage Container Rule

A mixed-stage Container/trailer is any Container whose authoritative current contents support more than one Setup Stage/scope.

The system should derive this from actual contents/relationships when possible rather than require a manually maintained `mixed_stage` flag.

When the first near-term task requires an item on a mixed-stage Container/trailer:

```text
first demand for any carried item
  -> surface Container-level mobilization
  -> move the whole Container/trailer as required by its logistics mode
  -> later tasks using other contents do not trigger duplicate workshop staging
```

Container-specific post-arrival behavior may differ:

```text
FULL UNLOAD
MOBILE / PARK STORAGE
SPECIAL TRANSFORMATION
```

That behavior must be represented deliberately; it cannot be inferred merely from mixed-stage membership.

Known examples include:

- Arch Trailer / Container 34 — carries material for multiple Stages; after cargo unload the trailer has a later Who House role;
- Antenna Trailer — carries material for multiple unrelated work areas and is another mixed-stage transport/storage case.

The general rule applies to any mixed-stage Container, not only these examples.

## Generic Staging Boundary

`Staging to Park` is not a reusable Setup task.

The Pick List replaces the old reason generic staging existed: MSB previously had no reliable way to know which Containers/items would be needed next.

The new model should derive logistics demand from the schedule/order itself.

Historical rows such as load/stage/unload remain evidence during reconstruction, but each must be classified as one of:

```text
PICK LIST / LOGISTICS ONLY
KEEP AS REAL REUSABLE FIELD TASK
ROUTE ELSEWHERE / REVIEW
REMOVE AS OBSOLETE GENERIC STAGING
```

## Pick Status / Execution Direction

Exact state names still require implementation design and acceptance, but the Pick List needs to distinguish at least:

- needed / not yet acted on;
- identified/scanned;
- ready/prepared;
- moved/loaded/delivered where the workflow requires it;
- Container already mobilized this annual Setup Session;
- exception/blocker.

Do not create state merely to imitate warehouse software. Preserve only logistics evidence useful to real Setup operation and future reconstruction.

## Relationship to Planning

The Pick List is downstream of planning, not a competing schedule.

```text
preferred order / readiness
  -> Needs Scheduling
  -> near-term work-day selections
  -> Pick List demand
```

If work is rescheduled, the Pick List must be able to recalculate priorities while preserving already-completed physical movement/mobilization.

## Relationship to Scan Application

Issue #113 owns Scan application readiness and the canonical identifier/camera/HID resolver matrix.

Setup Pick List should reuse that capability but remain a Setup-owned workflow.

The desired operator experience is not:

```text
open generic Scan
scan something
figure out what to do next
```

It is:

```text
open Setup -> Pick List
see what needs to be picked/moved
scan items/Containers while executing that list
Setup records the accepted logistics action
```

## Current Gap

As of this design record:

```text
Pick List generation/reporting       = NOT IMPLEMENTED
Setup tablet Pick List UI             = NOT IMPLEMENTED
Pick List scan-confirm workflow       = NOT IMPLEMENTED
mixed-stage Container resolver        = DESIGN REQUIREMENT / NOT IMPLEMENTED
annual Container mobilization state   = needs implementation design
```

Do not describe these as current Production capabilities until separately implemented, accepted, and deployed.

## Acceptance Direction

The first usable Pick List release should prove:

1. one standalone Setup Pick List page works well on a tablet;
2. near-term scheduled work resolves to required Displays/Containers;
3. shared Containers are deduplicated and show why they are required;
4. mixed-stage Containers are detected and handled correctly;
5. scanning `CONT`/`DISP` from the Pick List produces the intended Setup-owned action/context;
6. normal single-stage Containers do not create unnecessary mobilization tasks;
7. already-mobilized mixed-stage Containers do not reappear as workshop pulls for later carried items;
8. the Arch Trailer edge case is handled without falsely assigning Who House material to Container 34;
9. the Antenna Trailer/multi-stage-storage pattern is supported;
10. operator mistakes can be corrected without DBA intervention; and
11. the workflow remains understandable without raw Directus-table access.

## Related Durable Sources

- [Setup Planning Operating Model](Setup_Planning_Operating_Model_2026-09-08.md)
- [Setup engineering portal](README.md)
- GitHub issue #122 — Setup Session planning/pick-list/movement umbrella
- GitHub issue #113 — Scan application and Setup-season scanning integration
- GitHub issue #88 — Location scan resolution/movement workflow
