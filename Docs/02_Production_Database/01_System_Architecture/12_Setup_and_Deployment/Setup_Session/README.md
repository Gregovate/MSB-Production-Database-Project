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

The subsystem is in engineering reconnaissance. No Setup Session schema, application, or operator workflow described here should be treated as implemented until production evidence and acceptance establish it.

Current durable findings and design constraints are preserved in:

- [Setup Session Engineering Reconnaissance — 2026-09-03](engineering/Setup_Session_Engineering_Reconnaissance_2026-09-03.md)

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
- Stage Setup Procedure document content.

## Integration Boundaries

- [Labeling and Scanning](../../07_Labeling_and_Scanning/README.md) owns permanent scan identity and capture/resolution behavior.
- [#113 — Scan application and Setup-season scanning integration](https://github.com/Gregovate/MSB-Production-Database-Project/issues/113) remains the Scan readiness umbrella.
- [#88 — Setup-critical Location scan resolution and movement workflow](https://github.com/Gregovate/MSB-Production-Database-Project/issues/88) remains the focused Location/Scan integration work. Its accepted output must be reusable by Setup Session rather than becoming the Setup planner itself.
- [Containers and Storage](../../04_Containers_and_Storage/README.md) owns permanent Container identity, current Display-to-Container assignments, and home/intended storage relationships.
- [Site Infrastructure / GIS](../../11_Site_Infrastructure_GIS/README.md) owns durable site/location identity, authoritative/reference coordinates, coordinate transformation, and spatial calculations.
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
- [Setup Session Engineering Reconnaissance — 2026-09-03](engineering/Setup_Session_Engineering_Reconnaissance_2026-09-03.md)
- [Scan Workflows and Forklift Operations](../../07_Labeling_and_Scanning/Scan_Workflows_and_Forklift_Operations.md)
- [Site Infrastructure / GIS](../../11_Site_Infrastructure_GIS/README.md)
- [Containers and Storage](../../04_Containers_and_Storage/README.md)
