# Setup Mixed-Stage Container Unload Contract — 2026-09-09

| Document Control | Value |
|---|---|
| Document Type | Engineering Workflow Contract |
| System | Production Database — Setup Session / Pick List |
| Status | CURRENT DESIGN DIRECTION — operator-confirmed; not yet implemented |
| Owner | MSB Production Database engineering |
| Related Work | Issue #122; Setup Pick List Tablet Workflow; PR #125 |

## Purpose

Preserve the operator-confirmed execution model for shared/mixed-Stage Containers and trailers so the future Setup Pick List does not require volunteers to scan every Display/piece and does not incorrectly treat Container arrival at the park as proof that all contents were unloaded.

This contract applies generally to any Container whose current authoritative contents span more than one Setup Stage/scope. Known examples include Container 34 / Arch Trailer and the Antenna Trailer.

## Core Rule

A mixed-Stage Container is handled at **Container + unload-scope** level, not Display-by-Display.

The normal operator flow is:

```text
open Setup -> Pick List
    -> scan CONT:<container_id> once
    -> system resolves current contents grouped by Stage
    -> operator chooses unload scope
         - one Stage
         - multiple selected Stages
         - all remaining contents
    -> confirm unload
    -> Setup records annual unload state for the selected Stage scope(s)
```

Do **not** require scanning every Display/piece carried on a shared trailer/container. High-count Containers make that operationally unreasonable.

## Why Stage-Scoped Unload Is Required

A shared trailer may be brought to the park because one Stage needs material first, while material for several later Stages remains on the trailer.

Therefore these facts are distinct:

```text
Container is at the park
Stage 17 material has been unloaded
Stage 25 material is still loaded
```

The system must not collapse those into one `container_mobilized = all contents available` assumption.

A later scheduled task for another Stage on that same Container must **not** request that the Container be pulled from the workshop again. Instead, the Pick List should surface the still-loaded Stage scope as the work that now needs unloading.

## Required Tablet Interaction

After a mixed-Stage Container scan, the Pick List should present a compact touch-friendly scope picker, conceptually:

```text
Arch Trailer / Container 34
At park: YES

Remaining loaded Stage groups:
[ ] 04 Food Collection
[ ] 10 Stars
[ ] 14 Icicle Tunnel
[ ] 17 Candyland
[ ] 21 Polar Bear Playground
[ ] 25 Racing Arches

[Confirm Selected Unload]   [Unload All Remaining]
```

The exact UI is subject to browser/tablet acceptance, but the business meaning is fixed:

- one Container scan;
- Stage-group confirmation;
- optional multi-select;
- one action for all remaining contents;
- no piece-by-piece scan requirement.

For a normal single-Stage Container, the UI may collapse to a simple Container-level unload confirmation.

## Annual Execution State

Exact schema/table names are not yet accepted, but annual Setup state must be able to distinguish at least:

```text
Container not yet moved
Container moved / at park
Stage scope still loaded
Stage scope unloaded
all remaining contents unloaded
```

The state should be derived from real Setup execution events and should be correctable by an operator without DBA cleanup.

Do not change permanent `ref.display.container_id` merely because a Display has been unloaded for Setup. Permanent storage assignment and annual deployment/unload state are different concepts.

## Pick List Resolution Behavior

The resolver remains:

```text
scheduled / selected Setup work
    -> required Displays/assets
    -> current Container assignments
    -> deduplicate shared Containers
    -> show why the Container is required
```

Then annual Container/Stage unload state determines the next logistics action:

```text
Container still at workshop
    -> mobilize / move Container

Container already at park
+ required Stage scope still loaded
    -> unload that Stage scope

required Stage scope already unloaded
    -> no duplicate unload action
```

## Arch Trailer / Container 34

Container 34 is the primary proven edge case. It carries Displays for multiple Stages, including Food Collection, Stars, Icicle Tunnel, Candyland, Polar Bear Playground, and Racing Arches.

Operator-confirmed reusable planning guidance for the Arch Trailer unload operation:

```text
normal crew: 2 people
normal elapsed time: approximately 60-90 minutes
```

Historical 2025 evidence may show a different crew on a specific date. Preserve that as annual historical evidence; do not overwrite the reusable planning guidance with one historical crew count.

The Arch Trailer also has a later operational role: after its cargo is unloaded, the trailer becomes the Who House base. The Who House itself is stored elsewhere and must not be falsely assigned to Container 34 merely to express that dependency.

## Antenna Trailer and Other Mixed Containers

The same Container + Stage-scope execution model applies to the Antenna Trailer and any other Container whose contents span multiple Stages.

Do not hard-code `Arch Trailer` as a special-case algorithm. Detect mixed-Stage contents from authoritative current relationships, then apply the same unload-scope workflow.

Container-specific special roles may still need explicit relationships or rules, but mixed-Stage detection itself should be data-driven.

## Acceptance Direction

A future Pick List implementation should not be accepted until it proves:

1. a mixed-Stage Container is detected from current contents;
2. the operator scans the Container once rather than every Display;
3. the UI can confirm one Stage, several selected Stages, or all remaining contents;
4. partial unload leaves other Stage scopes visibly still loaded;
5. later scheduled work for another carried Stage generates an unload request without re-requesting workshop transport;
6. single-Stage Containers remain simple;
7. operator correction is possible without DBA intervention; and
8. the Arch Trailer normal planning guidance of 2 people / 60-90 minutes is preserved separately from historical actual crew evidence.

## Related Durable Sources

- [Setup Pick List Tablet Workflow](Setup_Pick_List_Tablet_Workflow_2026-09-09.md)
- [Setup Planning Operating Model](Setup_Planning_Operating_Model_2026-09-08.md)
- GitHub issue #122 — Setup Session planning / Pick List / movement umbrella
