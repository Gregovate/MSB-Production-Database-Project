# Setup Session

| Document control | Value |
|---|---|
| Status | CURRENT ENGINEERING SUBSYSTEM PORTAL — implementation not yet approved |
| Parent system | Setup and Deployment |
| Owner | MSB Technical Team |
| Current engineering issue | [#122 — Engineer annual Setup Session planning, pick-list, movement, and park-location subsystem](https://github.com/Gregovate/MSB-Production-Database-Project/issues/122) |

## Purpose

The Setup Session subsystem owns the annual operational workflow for planning and executing MSB Setup work from warehouse preparation through park placement.

It is intended to provide the Setup-season equivalent of an annual operational session without copying the Testing System's exact data model. Setup must support flexible planning, physical dependency resolution, pick/load work, scan-confirmed execution, park movement/location evidence, and useful prior-year history.

The normal planning question is:

> What are we setting up, what physical Displays/assets does that work require, where are those items currently stored or transported, and what actually happened when the work was performed?

Directus table search is not the intended long-term operator workflow for answering that question.

## Current State

The reconnaissance phase has produced a current 2026 planning direction, but no Setup Session schema, application, or operator workflow should be treated as implemented until production evidence and acceptance establish it.

Start with the planning direction, then use the focused reconnaissance documents for supporting evidence and unresolved details:

- [Setup Session 2026 Planning Direction — 2026-09-04](engineering/Setup_Session_2026_Planning_Direction_2026-09-04.md) — consolidates the intended first production workflow, establishes the living-work-system direction, records what must not be rebuilt from Microsoft Project, and separates firm direction from remaining design questions.
- [Setup Session Engineering Reconnaissance — 2026-09-03](engineering/Setup_Session_Engineering_Reconnaissance_2026-09-03.md)
- [Historical Setup Planning Evidence — 2024](engineering/Historical_Setup_Planning_Evidence_2024.md) — preserves recoverable planned schedule evidence from the rolling Microsoft Project master and explicitly separates historical plan evidence from actual execution history.
- [Container-to-Stage Relationship Reconnaissance — 2026-09-03](engineering/Container_Stage_Relationship_Reconnaissance_2026-09-03.md) — preserves the current KIT/Container finding that `goes_to` is a broad endpoint such as Park and does not provide the complete Setup-support relationship needed by pick-list generation.
- [Park Placement Candidate Selection Reconnaissance — 2026-09-03](engineering/Park_Placement_Candidate_Selection_Reconnaissance_2026-09-03.md) — preserves the known failure modes of naive nearest-Stage logic and candidate ideas for GPS-assisted placement without treating a final workflow as approved.
- [Park Area Naming and Orientation Reconnaissance — 2026-09-03](engineering/Park_Area_Naming_and_Orientation_Reconnaissance_2026-09-03.md) — preserves the tribal-knowledge/single-point-of-failure problem across MSB Stages, new Scenes, park rental-area numbers, landmarks, and physical geography.
- [Stage GPS Reference Data Reconnaissance — 2026-09-03](../../11_Site_Infrastructure_GIS/Stage_GPS_Reference_Data_Reconnaissance_2026-09-03.md) — preserves the current 31-point park Stage/setup reference-coordinate dataset and the GIS ingestion/identity gates.

### 2026 MVP boundary

The first Setup Session implementation is intentionally focused on the annual planning/pick-list/execution/location workflow using existing permanent Display/Container relationships and proven larger physical dependencies.

Detailed KIT/material inventory is **deferred by design** from the 2026 MVP. KITs are operationally important future work, but small non-LOR items such as ties, garland, hardware, small structural pieces, some lighting pieces, stakes/cords/plugs/bull line, and similar materials must not be forced into LOR Preview or `ref.display` merely to make the first Setup Session work.

Existing KIT **Containers** are different from detailed KIT contents: the Containers already have permanent identity and are in scope for 2026 planning. If a KIT is known to support the selected Stage/setup area, the KIT Container belongs on that work's physical pick list even though its individual contents are not yet inventoried.

For park location/orientation, the current requirement is deliberately narrower than a final GIS workflow: GPS proximity must **not** become an automatic Stage-assignment rule, and the system should reduce dependence on tribal knowledge about where named Stages/setup areas physically are. Exact UI, ranking, map, Scene-level refinement, and confirmation behavior remain under reconnaissance.

The current engineering reconnaissance owns the detailed scope boundary and future KIT/GIS integration direction.

## Ownership Boundary

Setup Session owns the business meaning of annual Setup planning and execution, including where proven necessary:

- annual Setup season/session context;
- flexible work-day planning;
- selected Setup work and physical dependency resolution;
- pick lists and transport grouping;
- planned versus actual execution;
- meaningful picked/loaded/delivered/relocated/placed events;
- park GPS/location observations associated with Setup work;
- useful prior-year effort, sequence, crew, delay, and planning history.

It does **not** own:

- permanent Display, Container, Controller, Stage, Scene, Location, or person identity;
- scanner-specific input programming;
- permanent label payload design;
- authoritative GIS reference coordinates;
- permanent warehouse/home storage semantics;
- Testing System test-session rules;
- Stage Setup Procedure document content;
- detailed KIT/small-component inventory for the 2026 MVP.

## Integration Boundaries

- [Labeling and Scanning](../../07_Labeling_and_Scanning/README.md) owns permanent scan identity and capture/resolution behavior.
- [#113 — Scan application and Setup-season scanning integration](https://github.com/Gregovate/MSB-Production-Database-Project/issues/113) remains the Scan readiness umbrella.
- [#88 — Setup-critical Location scan resolution and movement workflow](https://github.com/Gregovate/MSB-Production-Database-Project/issues/88) remains the focused Location/Scan integration work. Its accepted output must be reusable by Setup Session rather than becoming the Setup planner itself.
- [Containers and Storage](../../04_Containers_and_Storage/README.md) owns permanent Container identity, current Display-to-Container assignments, and home/intended storage relationships.
- [Site Infrastructure / GIS](../../11_Site_Infrastructure_GIS/README.md) owns durable site/location identity, authoritative/reference coordinates, coordinate transformation, and spatial calculations. Setup Session consumes reconciled Stage/site destination information and gives any device observations their operational movement meaning.
- [Testing System](../../05_Testing_System/README.md) provides a useful annual-session pattern for comparison only; Setup Session must be designed around the actual Setup process.

## Engineering Rule

Do not design the Setup Session schema from conversation assumptions.

Before schema or application implementation:

1. inventory the current production objects and relationships;
2. preserve the real Setup process and representative edge cases in controlled engineering documentation;
3. prove the minimum dependency/pick-list resolver against existing Production Database relationships;
4. define which planned-versus-actual history is operationally useful;
5. define Scan/GPS/offline handoffs against accepted Scan and GIS contracts; and
6. only then propose database/application changes.

## Related Documents

- [Setup and Deployment](../README.md)
- [Setup Session 2026 Planning Direction — 2026-09-04](engineering/Setup_Session_2026_Planning_Direction_2026-09-04.md)
- [Setup Session Engineering Reconnaissance — 2026-09-03](engineering/Setup_Session_Engineering_Reconnaissance_2026-09-03.md)
- [Historical Setup Planning Evidence — 2024](engineering/Historical_Setup_Planning_Evidence_2024.md)
- [Container-to-Stage Relationship Reconnaissance — 2026-09-03](engineering/Container_Stage_Relationship_Reconnaissance_2026-09-03.md)
- [Park Placement Candidate Selection Reconnaissance — 2026-09-03](engineering/Park_Placement_Candidate_Selection_Reconnaissance_2026-09-03.md)
- [Park Area Naming and Orientation Reconnaissance — 2026-09-03](engineering/Park_Area_Naming_and_Orientation_Reconnaissance_2026-09-03.md)
- [Stage GPS Reference Data Reconnaissance — 2026-09-03](../../11_Site_Infrastructure_GIS/Stage_GPS_Reference_Data_Reconnaissance_2026-09-03.md)
- [Scan Workflows and Forklift Operations](../../07_Labeling_and_Scanning/Scan_Workflows_and_Forklift_Operations.md)
- [Site Infrastructure / GIS](../../11_Site_Infrastructure_GIS/README.md)
- [Containers and Storage](../../04_Containers_and_Storage/README.md)
