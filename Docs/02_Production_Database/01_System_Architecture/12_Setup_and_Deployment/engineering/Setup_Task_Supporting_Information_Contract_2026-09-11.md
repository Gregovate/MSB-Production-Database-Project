# Setup Task Supporting Information Contract — 2026-09-11

| Document Control | Value |
|---|---|
| Document Type | Engineering Operating-Model Contract |
| System | Production Database — Setup and Deployment |
| Status | CURRENT CONTRACT — 2026 annual Session live; supporting-information model remains authoritative |
| Owner | MSB Production Database engineering |
| Last Reviewed | 2026-09-25 |
| Related Work | #122, #132, #145, #167, #171, #172, #175 |

## Purpose

Preserve the operator-confirmed model for the information that must support reusable Setup tasks and annual field execution without forcing every procedure step, material detail, or field discovery into an independent scheduled task.

## Current Annual / Launch Control

#141, #145, and #167 are complete. The real 2026 Setup Session is live and is now the current annual planning/execution context under #122.

```text
Reusable Catalog = recurring Setup knowledge
2026 annual Session = this season's planning/execution set
season-only work = 2026 only unless explicitly promoted
```

Use 2025 only as historical/verification evidence. Do not recreate the 2026 Session or use 2025 annual membership as current planning authority.

## Preservation Rule

Preserve accepted V0.3.7 through V0.3.13 behavior, the working Stage/Scene Display resolver, 2025 historical boundaries, current Display/Container authority, and the narrow governed write-command model.

## Core Principle — Task Granularity

A reusable Setup task is a meaningful operational control point, not a transcription of every procedure step.

Keep detailed how-to steps in the Procedure unless the step needs independent planning/completion, a hard predecessor, meaningful handoff, independent progress/history, or materially different resource/material demand.

## Display Ownership — Implemented #141 Contract

The accepted Stage/Scene resolver remains the authoritative current Display source set.

```text
current Stage/Scene LOR resolver
    -> resolved current Displays
    -> Setup ownership layer
        -> exactly one effective reusable Setup-task owner per Display
```

Rules:

- simple scopes with one material-bearing task remain effectively implicit;
- multi-task scopes require explicit ownership;
- Managers may move Displays between eligible reusable tasks;
- coverage review exposes missing/invalid ownership;
- LOR remains authority for which Displays belong in the Stage/real-Scene scope;
- Display ownership does not rewrite `ref.display.container_id`;
- a task that receives explicit Display ownership becomes material-bearing as required by the governed assignment command.

The Production UI supports click, Ctrl/Cmd-click, Shift-click, drag, and a non-drag **Move selected to** path for very large boards.

## Kit / Support Containers — Implemented #141 Foundation

KITs are existing physical `ref.container` identities. Do not create a competing KIT identity catalog.

Accepted reusable relationship:

```text
reusable Setup task
    -> ref.setup_task_container_support
    -> ref.container
```

For physical Kit Boxes:

```text
container_type_id = 2
relationship_type = 'KIT'
```

The relationship is many-to-many:

- one task may require multiple Kit Boxes;
- one Kit Box may support multiple tasks;
- one Kit Box may support tasks in more than one Stage/Scene.

Existing `SUPPORT` and `REQUIRED_CONTAINER` relationships keep their prior logistics meaning and remain distinct from `KIT`.

#141 establishes the assignment foundation only. #167 owns expected contents, Extra Materials, source quantities/specifications, and the distinction between expected source and actual physical inventory.

## Requirement vs Source vs Actual Inventory

Keep these separate:

```text
WHAT IS REQUIRED
vs.
WHERE IT IS EXPECTED TO COME FROM
vs.
WHAT IS PHYSICALLY PRESENT NOW
```

A single requirement may be split across sources. Verified physical shortages must not silently rewrite the underlying task requirement.

## T-Posts and Spacers

For 2026, task requirements need useful quantity/specification facts without requiring per-piece identity.

- T-posts are reusable bulk material stored/transported separately from Kit Boxes.
- Spacers are reusable bulk material; some custom/fitted spacers may also be expected in Kits.
- Quantity matters at the reusable task requirement.
- Length/specification must be preserved where known.
- Do not invent per-piece inventory merely to represent the rack/container.

Full detailed Kit inventory remains a later 2027 goal.

## Extra Material Catalog Direction

Extra Materials are non-LOR physical supplies/support items needed to perform Setup work. Procedure wording is evidence, not canonical identity.

The model must normalize stable material families and meaningful variants/specifications. Task-specific quantity belongs on the task-material relationship, not on the global item definition.

Do not duplicate existing Resource Catalog tools/equipment into Extra Materials merely because they are mentioned in a procedure or stored in a Kit.

## Reusable vs Consumable

The material model must distinguish durable reusable components from consumables. Examples of consumables include zip ties, electrical tape, and marking paint. Requirements represent what must be available for the work, not necessarily what returns after Takedown.

## Staged Release Boundary

The #141 assignment layer now answers which reusable task owns each current Display and which physical Kit Boxes support a task.

Actual Pick List release/scheduling remains downstream work:

```text
near-term selected work
    -> task-owned Displays
    + Extra Material requirements
    + Kit/support requirements
    -> release/pick timing
    -> current source/container state
    -> logistics action
```

The Pick List must not interpret Stage membership as `pick everything now`. Magic Igloo remains the representative temperature-sensitive case.

## Production Crew / Manager Boundary

Production Crew need governed operational capability to perform assigned work, report progress/completion, validate physical state, and report concrete problems.

Managers retain authority for reusable definitions, prerequisites, catalogs/defaults, and durable Display/Kit/material assignments.

Administrators retain annual/system authority where required.

## Field Corrections

Concrete wrong/missing conditions that require later action may go to the existing Work Order system. Creating a Work Order does not itself mutate canonical LOR, Setup, Container, Kit, material, or procedure data.

## 2026 Posture

Use the best available procedures, Production data, derived rules, Kit/source information, and verified field evidence. Keep uncertainty visible. Do not block useful 2026 operation on future 2027 detailed Kit inventory.

The real 2026 Setup Session is live. Continue correcting durable reusable knowledge through governed Manager surfaces while preserving annual 2026 planning/execution history. Remaining #175/#132/#172/#206 work consumes real annual/schedule identities rather than blocking the already-created Session.

## Resume Development

1. read Production Database Project Rules;
2. refresh current `main` and read the current Setup engineering handoff/README;
3. preserve accepted V0.3.7 through V0.3.13 foundations plus the accepted live Scheduling Board behavior;
4. treat 2025 as historical/verification evidence and 2026 as the current annual planning/execution context;
5. resume downstream #175/#132/#172/#206 work from real 2026 identities under #122;
6. inspect current Production schema/migrations before asking the operator to rediscover schema facts;
7. use governed application commands rather than broad table DML; and
8. update this contract and acceptance evidence whenever implementation establishes durable behavior.

## Related Durable Sources

- [Setup engineering portal](README.md)
- [Setup Stage / Scene Material Resolution Contract](Setup_Stage_Scene_Material_Resolution_Contract_2026-09-10.md)
- [Setup Data Consumption and Authorization Contract](Setup_Data_Consumption_and_Authorization_Contract_2026-09-10.md)
- `Setup/Acceptance/Setup_Assignment_Layer_V0313_Production_Acceptance_2026-09-12.md`
