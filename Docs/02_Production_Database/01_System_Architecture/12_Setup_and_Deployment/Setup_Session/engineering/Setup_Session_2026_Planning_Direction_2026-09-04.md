# Setup Session 2026 Planning Direction — 2026-09-04

| Document control | Value |
|---|---|
| Status | CURRENT ENGINEERING PLANNING DIRECTION — workflow direction established; schema/application not yet approved |
| System | Setup Session |
| Parent system | Setup and Deployment |
| Owner | MSB Technical Team |
| Related issue | [#122 — Engineer annual Setup Session planning, pick-list, movement, and park-location subsystem](https://github.com/Gregovate/MSB-Production-Database-Project/issues/122) |

## Purpose

Consolidate the Setup Session reconnaissance into one actionable planning direction for the first 2026 implementation.

This document is the bridge between field-process reconnaissance and later schema/application engineering. It records what the first Setup Session is supposed to accomplish, the failure modes it must avoid, the minimum operational flow that now appears justified, and the design questions that remain intentionally open.

It does **not** approve table names, columns, migrations, final UI layout, or a specific application implementation.

## Core product direction

The first Setup Session must behave like a **living Setup work system**, not like Microsoft Project or a traditional Gantt schedule that requires a dedicated scheduler to keep it synchronized with reality.

The practical operating model is:

```text
annual Setup Session
    -> maintain backlog / candidate Setup work
        -> choose likely work for the next day or two
            -> resolve required physical assets
                -> prepare pick/load work
                    -> execute in the field
                        -> normal scans/actions capture what actually happened
                            -> retain planned-versus-actual history for later seasons
```

The system is useful only if it remains useful when no one is assigned the separate job of "maintaining the schedule."

> If the system only stays accurate when one knowledgeable person spends significant time updating the plan after every field change, it has reproduced the main failure mode of Microsoft Project.

## Operating assumptions established by reconnaissance

### Setup planning is deliberately flexible

The first couple of Setup days can normally be planned with reasonable confidence. Later work changes frequently based on:

- volunteer turnout;
- weather;
- work finishing sooner or later than expected;
- equipment or material problems;
- what has already been transported to the park;
- volunteer fatigue;
- the practical desire to alternate very large jobs with smaller/easier work where possible.

The planner must therefore support easy reprioritization without treating every change as an exception or forcing the user to rebuild a dependency network.

### One day is not one Stage

Historical 2024 planning evidence and current field-process discussion both show that one Setup day may contain:

- several tasks in one Stage/setup area;
- work from more than one Stage;
- short supporting jobs around a larger job;
- infrastructure, traffic-control, staging, harness, trailer, or other work that is not itself a Stage;
- tasks that span more than one day.

Therefore the first planner must not use a model equivalent to:

```text
one date -> one Stage
```

### Setup work exists at several useful levels

A work item may be expressed as:

- a Stage;
- a Sub-stage;
- a Scene where the newer Scene model genuinely helps;
- an individual Display;
- a practical Setup/support task;
- a future Setup-specific work package only where existing identities cannot adequately describe the real job.

Do not force every practical job into one hierarchy level merely for schema simplicity.

### Stage remains the primary orientation vocabulary

MSB's established internal park language is Stage/setup-area based. Scenes are new in 2026 and may provide useful finer-grained guidance, but Scene terminology must not become a prerequisite for basic planning or orientation.

The current Stage GPS reference dataset exists primarily to make local MSB place names discoverable:

```text
Take this to Whoville
    -> Show me where Whoville is
```

City/park rental Area numbers remain a separate external vocabulary requiring an explicit crosswalk where useful. Do not merge rental Area numbers with MSB Stage numbers.

## First 2026 workflow direction

The following flow is sufficiently supported by current evidence to guide implementation planning.

### 1. Open the annual Setup Session

One annual Setup Session provides the season context for planning and execution.

It should answer:

> What do we expect to set up this season, what are we planning next, what physical assets are required, what has already moved, what is complete, and what actually happened?

The annual session is analogous in purpose to annual Testing context but must not copy the Testing schema mechanically.

### 2. Maintain a Setup work backlog

The system should hold candidate work that remains to be done without assigning every item to a rigid date far in advance.

Useful planner behavior includes:

- priority/order;
- broad Stage/setup context where applicable;
- practical task wording;
- rough effort or job-size information where it proves useful;
- readiness/blocker information where it materially affects whether the work can be selected;
- visibility into what physical assets the work will require.

Exact effort scales, priority fields, and blocker representation remain to be designed.

### 3. Build a near-term day plan

The planner should make it easy to choose likely work for today / tomorrow / the next couple of days.

The near-term plan should be easy to:

- add to;
- remove from;
- reorder;
- defer;
- substitute when volunteer count or weather changes.

Replanning must not erase the distinction between what was originally planned and what was actually done when that distinction is useful for later learning.

### 4. Resolve physical dependencies automatically

Selecting Setup work should resolve the physical Displays/assets needed for that work and then determine how they are currently stored or transported.

Current resolver direction:

```text
selected Setup work
    -> required Displays / durable physical assets
        -> current Display.container_id relationships
            -> required Containers / trailers

    + supplemental reviewed Setup-support relationships
        -> only where required physical Containers cannot be derived
           from current Display relationships

then
    -> deduplicate physical Containers/trailers
    -> explain why each physical asset is required
```

The operator should not have to know Container IDs or manually search Directus to reconstruct these dependencies.

### 5. Include KIT Containers without requiring detailed KIT inventory

The 2026 rule is:

> KIT contents are deferred; KIT Containers are not.

If a KIT Container is known to support the selected Stage/setup work, it belongs on the physical pick list even though ties, stakes, garland, cords, spacers, hardware, small lighting pieces, and other contents are not individually inventoried.

Use linked Displays to derive KIT support where possible. Use supplemental reviewed non-exclusive support relationships only where needed.

Do not force small non-LOR items into `ref.display` merely to make Setup planning work.

### 6. Deduplicate shared Containers and explain dependencies

Shared Containers/trailers must appear once on the physical pick/load list while showing every selected job that depends on them.

Container 34 / Arch Trailer remains the principal acceptance case:

- 121 current Display records;
- six Stages;
- shared storage/transport role;
- later becomes the physical base/platform for Who House;
- must not be forced into one Stage merely for planning convenience.

The system must also know once a shared Container/trailer has already moved to the park so later work does not incorrectly schedule another warehouse transport for the same physical asset.

### 7. Produce practical pick/load work

The physical work output should tell the warehouse/forklift team what must move and why.

The first version should emphasize:

- completeness;
- physical Container/trailer identity;
- home/current storage context;
- why each item is needed;
- whether the asset has already been moved;
- known multi-trip/transport burden where useful.

Do not prematurely build freight management or strict trailer-load sequencing. Trailers are normally side-loaded, so exact reverse unload order is not a primary first-version requirement.

### 8. Let normal execution maintain the history

The field workflow should capture actual execution from the actions volunteers already need to perform.

Examples include:

- scanning a Container when picked/moved/unloaded;
- scanning an individual Display when its independent movement matters;
- marking a selected work item complete;
- recording a changed/deferred work item when plans change;
- capturing current GPS observation during an explicit park movement/placement workflow where useful.

Avoid creating a second administrative workflow whose only purpose is to update the schedule after the real work occurred.

### 9. Distinguish staging from final placement

Arrival at the common park unloading/staging area is not the same business event as final Stage/setup-area placement.

The exact event names remain open, but the business distinction must survive:

```text
arrived / unloaded / staged
    !=
relocated / placed at Setup area
```

A Container scan at the common lot must not become an automatic assignment to whichever Stage happens to be geographically nearest.

### 10. Use park coordinates to reduce tribal knowledge

The current Stage reference coordinates are sufficient for a useful first orientation layer.

A volunteer receiving:

```text
Take this to Whoville
```

should be able to discover where Whoville is from the MSB system without asking the one person who currently knows the entire park crosswalk from memory.

Possible future UI aids include a labeled park map, Stage reference point, current-position context, landmarks/access notes, or Scene-level refinement. Exact presentation is not yet approved.

GPS may assist orientation or candidate ranking, but proximity must not automatically assign business meaning because:

- some Stages are 600–800 feet long;
- Traditional Christmas and Peanuts overlap;
- the river creates misleading straight-line proximity around Church;
- shared Containers may have several valid destinations;
- staging areas can be geographically near unrelated Stages.

### 11. Preserve planned versus actual history

The annual session should retain enough information to improve future seasons.

At minimum, later engineering must be able to distinguish:

```text
what we intended to do
    !=
what we actually did
```

Useful history may eventually include:

- planned work/day/order;
- actual completion date/order;
- crew size or participation where useful;
- useful start/finish/duration evidence;
- transport/trip burden;
- reason work changed or was deferred;
- weather/equipment/material/crew constraints;
- work finishing sooner or later than expected.

Do not require fields merely because Microsoft Project or conventional project-management software has them. Every manual field must justify its operational value.

## What the first Setup Session must not become

The first implementation must not become:

- a Gantt-chart clone;
- a system requiring a dedicated scheduler;
- a rigid predecessor/resource-leveling engine;
- a one-Stage-per-day calendar;
- a generalized freight-management system;
- a complete KIT/BOM inventory system;
- a GIS editing/routing platform;
- a replacement for permanent Stage/Scene/Display/Container identities;
- a system that silently changes permanent storage relationships when field plans change;
- a workflow that requires volunteers to perform duplicate administrative entry after doing the physical work;
- a Directus-table-search exercise presented as an operator application.

## Practical planner view — conceptual, not final UI

A useful first planner may conceptually look more like a work board than a traditional project schedule:

```text
SETUP 2026

BACKLOG / LATER
    Icicle Tunnel
    Candyland
    Church
    Racing Arches
    Network / support work
    ...

TOMORROW / NEAR TERM
    Whoville
    Elf Choir
    small support task

TODAY
    Food Collection
        -> physical pick/load requirements resolved
        -> Containers/KITs/trailers shown
        -> work status captured from execution

DONE
    actual completion history retained
```

The exact columns, labels, dates, drag/drop behavior, and UI technology are unapproved. The important direction is **easy prioritization plus execution-linked history**, not formal schedule maintenance.

## Historical evidence role

The recovered `MSB Setup 2024 Master.mpp` is useful as planning evidence but also documents a failed operating model.

It demonstrates useful real planning characteristics:

- several tasks on one day;
- several tasks under one broad Setup area;
- short and long work mixed together;
- non-Stage supporting work;
- multi-day planned work.

It also demonstrates the maintenance failure:

- Microsoft Project was too cumbersome and rigid for the actual Setup process;
- the plan changed faster than the file was maintained;
- MSB did not have one person assigned to keep the project plan synchronized with field reality.

Any 2025 actual-history source that is later recovered should be used to improve estimates and planning behavior, but the first 2026 design no longer depends on recovering a perfect historical record.

## Firm direction versus open design questions

### Firm direction established enough to engineer against

- one annual Setup Session context;
- flexible backlog and near-term planning rather than a rigid full-season schedule;
- multiple work items per day;
- practical work items can exist at different scope/granularity;
- planned and actual must remain conceptually distinct;
- normal execution should capture most actual history;
- selected work must resolve physical Displays/assets and current Containers;
- shared Containers/trailers must deduplicate and explain why they are required;
- KIT Containers are in scope while detailed KIT contents remain deferred;
- transport burden can matter independently of Container count;
- Stage-level orientation remains primary for the first park guidance layer;
- Scene-level guidance is optional refinement, not prerequisite knowledge;
- city rental Areas remain a separate vocabulary/crosswalk;
- GPS/proximity is evidence or guidance, not automatic Stage authority;
- permanent home/storage relationships must not be destroyed by temporary Setup movement;
- scanner identities `DISP`, `CONT`, `LOC`, and `CTRL` remain permanent identity mechanisms owned by the Scan/Labeling boundary.

### Still intentionally open

- exact PostgreSQL schemas/tables/columns;
- exact work-item identity model;
- whether a Setup-specific reusable work-package entity is needed at all;
- exact priority/job-size/effort estimation fields;
- which manual change/defer reasons are worth capturing;
- how much crew/volunteer information is useful in the first version;
- exact pick/load status/event names;
- exact staging/placement event names;
- exact map/orientation UI;
- whether Scene-level coordinates are needed in 2026;
- exact PostGIS representation and ingestion path;
- exact offline queue/application implementation;
- how supplemental zero-linked KIT support relationships should be represented;
- how the `display_pallet` / `display_pallet_flag` legacy/current fields relate to the reverse Container-as-part-of-Display requirement;
- whether any historical 2025 actual data can be recovered and reconciled.

## Immediate engineering sequence

The next implementation-planning work should be evidence-driven and narrow:

1. finish the outstanding live-schema reconnaissance needed to avoid inventing duplicate relationships;
2. define the minimum Setup work-item / annual-session data model needed to support backlog, near-term plan, actual execution, and history;
3. prove the dependency resolver against several representative Production cases;
4. define the minimum physical pick/load output;
5. define the smallest execution/status/event model that normal scans/actions can maintain;
6. add Stage-level orientation capability using the existing GPS reference dataset without building a full GIS platform;
7. test the workflow against real field scenarios before expanding scope.

Representative resolver/workflow test cases should include:

- a normal single-Stage setup area;
- Icicle Tunnel including its KIT Containers;
- Old Elf Choir requiring the Conductor stored on Old Man Winter Container;
- Container 34 / Arch Trailer shared across multiple Stages;
- a zero-linked KIT requiring reviewed supplemental support;
- a non-Stage support task;
- common park staging before final placement;
- `Take this to Whoville` orientation for a volunteer who does not know the park;
- a day whose plan changes because volunteer count or progress differs from expectation.

## Success condition for the first production version

The first Setup Session is successful if MSB can use it during real Setup to answer, with materially less tribal knowledge and manual coordination:

> What should we work on next, what do we need to pull and transport for it, where does it go, what has already moved, and what actually got done?

while allowing the day to change naturally without requiring a separate person to maintain a formal project schedule.

## Related documents

- [Setup Session subsystem](../README.md)
- [Setup Session Engineering Reconnaissance — 2026-09-03](Setup_Session_Engineering_Reconnaissance_2026-09-03.md)
- [Historical Setup Planning Evidence — 2024](Historical_Setup_Planning_Evidence_2024.md)
- [Container-to-Stage Relationship Reconnaissance — 2026-09-03](Container_Stage_Relationship_Reconnaissance_2026-09-03.md)
- [Park Placement Candidate Selection Reconnaissance — 2026-09-03](Park_Placement_Candidate_Selection_Reconnaissance_2026-09-03.md)
- [Park Area Naming and Orientation Reconnaissance — 2026-09-03](Park_Area_Naming_and_Orientation_Reconnaissance_2026-09-03.md)
- [Stage GPS Reference Data Reconnaissance — 2026-09-03](../../../11_Site_Infrastructure_GIS/Stage_GPS_Reference_Data_Reconnaissance_2026-09-03.md)
- [#122 — Setup Session engineering issue](https://github.com/Gregovate/MSB-Production-Database-Project/issues/122)
