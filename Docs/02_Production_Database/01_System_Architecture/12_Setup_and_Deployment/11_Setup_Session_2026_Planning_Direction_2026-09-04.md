# Setup Session 2026 Planning Direction — 2026-09-04

| Document control | Value |
|---|---|
| Status | CURRENT ENGINEERING PLANNING DIRECTION — workflow direction established; schema/application not yet approved |
| System | Setup and Deployment — Setup Session |
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
        -> show what is available now, later, or blocked
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

### Flexible planning still has hard calendar anchors

The Setup process is flexible inside several real operating windows.

Current field-process dates/rules are:

- official annual Setup starts on **October 5**;
- Setup must be **totally ready and tested one week before Thanksgiving** because that is the VIP sponsor night;
- Santa's Station work cannot begin until **November 1**;
- individual work packages inside a Stage can also have later practical start windows even when other pieces of the same Stage are already being installed.

The planner therefore needs to distinguish flexible day-to-day ordering from real date constraints.

Conceptually:

```text
remaining work
    -> available now
    -> not before <date/window>
    -> blocked by prerequisite
    -> must be complete by <milestone>
```

This does **not** imply a full critical-path/Gantt scheduling engine. It means the presentation layer must not offer work as immediately selectable when a known real-world rule says it cannot start yet, and must keep the final VIP-readiness milestone visible.

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

### A Stage can be installed in practical phases

Selecting a Stage does not necessarily mean every physical piece associated with that Stage should be moved or installed at the same time.

Food Collection is a representative example. Some perimeter/bracket work may be installed substantially earlier, while the traffic lanes are intentionally held until much later, roughly two weeks before the show begins.

The presentation layer therefore needs to let the team select the **actual practical Setup work** they intend to perform, not merely check an entire Stage as one indivisible item.

Conceptually:

```text
Stage 04 — Food Collection
    -> perimeter / bracket work          [earlier]
    -> other Stage components            [as appropriate]
    -> traffic lanes                     [later window]
```

This has an important dependency-resolver consequence:

> The pick list must resolve from the selected practical work item, not automatically from every Display/Container associated with the parent Stage.

Otherwise selecting an early Food Collection task could incorrectly pull later traffic-lane material to the park weeks before it is needed.

### Setup work exists at several useful levels

A work item may be expressed as:

- a Stage;
- a Sub-stage;
- a Scene where the newer Scene model genuinely helps;
- an individual Display;
- a practical Stage component/phase;
- a practical Setup/support task;
- a future Setup-specific work package only where existing identities cannot adequately describe the real job.

Do not force every practical job into one hierarchy level merely for schema simplicity.

### Some readiness work is intentionally outside the Setup Session

Before MSB can pound stakes in many park areas, the crew must physically locate the existing underground electrical wiring and network cables with the MSB locator.

That locating work is a real prerequisite for safe field execution, but the locator process itself is **not intended to become a Setup Session subsystem**.

The Setup planner still needs to respect its effect on readiness. For example:

```text
stake-dependent Setup work
    -> underground wiring/network locate not complete
        -> work is not ready to select yet

stake-dependent Setup work
    -> locate complete / field cleared
        -> work may become selectable
```

The exact way this readiness confirmation is represented remains open. The first implementation should not build locator/GIS tracing workflows merely to represent that the prerequisite exists.

### Stage remains the primary orientation vocabulary

MSB's established internal park language is Stage/setup-area based. Scenes are new in 2026 and may provide useful finer-grained guidance, but Scene terminology must not become a prerequisite for basic planning or orientation.

The current Stage GPS reference dataset exists primarily to make local MSB place names discoverable:

```text
Take this to Whoville
    -> Show me where Whoville is
```

City/park rental Area numbers remain a separate external vocabulary requiring an explicit crosswalk where useful. Do not merge rental Area numbers with MSB Stage numbers.

### Rework and defects belong to the Work Order System

The historical Setup punch-list/rework process evolved into the current Work Order System.

Setup Session should therefore track whether planned Setup work has been performed and whether the Stage/Display is sufficiently complete for Setup progression. It should **not** recreate a second punch-list/repair lifecycle.

If Setup discovers a defect, repair, correction, or debugging need, that follow-up belongs in the existing Work Order System. An open Work Order may affect whether a particular Setup item can be considered ready/complete, but the Work Order remains a separate authoritative lifecycle.

## First 2026 workflow direction

The following flow is sufficiently supported by current evidence to guide implementation planning.

### 1. Open the annual Setup Session

One annual Setup Session provides the season context for planning and execution.

It should answer:

> What do we expect to set up this season, what are we planning next, what physical assets are required, what has already moved, what is complete, and what actually happened?

The annual session is analogous in purpose to annual Testing context but must not copy the Testing schema mechanically.

### 2. Present the remaining Setup work

The system should present the work that remains to be done without assigning every item to a rigid date far in advance.

This presentation layer is central to the operating model. It should help the team see an understandable ordered/progression list and choose the next practical work based on current conditions.

Useful planner behavior includes:

- priority/order;
- broad Stage/setup context where applicable;
- practical Stage component/phase where a Stage is not installed all at once;
- practical task wording;
- whether work is available now, date-gated, or blocked by a prerequisite;
- known not-before windows such as Santa's Station on November 1;
- final readiness milestone visibility for the VIP sponsor night;
- rough effort or job-size information where it proves useful;
- readiness/blocker information where it materially affects whether the work can be selected;
- visibility into what physical assets the work will require.

Exact effort scales, ordering fields, date-constraint fields, and blocker representation remain to be designed.

### 3. Build a near-term day/progression plan

The planner should make it easy to choose likely work for today / tomorrow / the next couple of days or establish an intended order of progression.

The near-term plan should be easy to:

- add to;
- remove from;
- reorder;
- defer;
- substitute when volunteer count or weather changes;
- avoid work that is not yet eligible because of a date window or external prerequisite.

Replanning must not erase the distinction between what was originally planned and what was actually done when that distinction is useful for later learning.

The planner should help answer:

> Given the people, weather, current progress, readiness constraints, and remaining work, what should we set up next?

It should support the human decision rather than pretending the system can automatically know the best answer.

### 4. Resolve physical dependencies automatically

Selecting Setup work should resolve the physical Displays/assets needed for **that selected work** and then determine how they are currently stored or transported.

Current resolver direction:

```text
selected practical Setup work
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

The resolver must not automatically expand a selected Stage-phase task into all material for the entire parent Stage when later components are intentionally being held for a future window.

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

- completeness for the selected work;
- physical Container/trailer identity;
- home/current storage context;
- why each item is needed;
- whether the asset has already been moved;
- known multi-trip/transport burden where useful.

Do not prematurely build freight management or strict trailer-load sequencing. Trailers are normally side-loaded, so exact reverse unload order is not a primary first-version requirement.

### 8. Scan assets as they leave the workshop

Containers, KIT Containers, and independently handled Displays/assets should be scanned as appropriate when they are pulled/moved for transport.

The purpose is to confirm actual physical execution of the selected plan and maintain current location/state evidence without requiring a separate scheduling clerk to reconcile the plan afterward.

### 9. Scan again when assets reach the park and when their location changes

The system must distinguish movement/location observations over time.

A practical sequence can include:

```text
workshop pull / departure
    -> park arrival / unload
        -> temporary staging location
            -> final Stage/setup-area placement
```

Containers and KIT Containers should be scanned again when they reach the park and again when moved to a staged/final location where that movement matters.

If a Display is removed from a Container and moved to a different location from the Container, that Display must receive its own later scan/location observation. Do not fabricate a Display location merely from its Container's location.

Arrival at the common park unloading/staging area is not the same business event as final Stage/setup-area placement.

The exact event/status names remain open, but the business distinction must survive.

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

### 11. Repeat until all intended Setup work/material is out and installed

As Setup progresses, the system should continuously return to the remaining-work presentation.

Conceptually:

```text
review remaining eligible work
    -> consider volunteers / weather / progress / readiness
        -> choose next practical group
            -> resolve pick list
                -> pull / scan / transport / place
                    -> update actual progress
                        -> repeat
```

The cycle continues until everything that is supposed to leave the workshop for Setup has been moved and the show is ready/tested for the VIP milestone.

### 12. Return empty non-display Containers to the workshop

When a Container has finished its Setup transport role and is not itself part of a Display, it may return to the workshop before Takedown.

Those returned Containers should be scanned back to a rack/storage location or otherwise restored to their normal home-location context so the organization knows where they are when Takedown begins.

Do not apply this rule to Containers/trailers that remain part of a Display or have another required park role, such as the Arch Trailer becoming the Who House base.

### 13. Preserve planned versus actual history

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

## Team-level operating summary

The Setup Session can be explained to the broader team without the database/GIS engineering detail:

```text
1. Decide what still needs to be set up.
2. Choose the next practical work for the day/progression.
3. Let the system determine what Containers/KITs/assets are needed.
4. Scan those assets as they leave the workshop.
5. Scan them again as they arrive, stage, and move within the park.
6. Scan an individual Display again if it leaves its Container and moves elsewhere.
7. Review what remains and choose the next practical work based on people, weather, progress, and readiness.
8. Repeat until everything intended for the park is out and the show is ready/tested.
9. Return empty non-display Containers to their workshop/rack/home locations until Takedown.
```

This is the team-level workflow. Detailed dependency resolution, GIS behavior, readiness rules, Work Order integration, and schema remain engineering concerns underneath it.

## What the first Setup Session must not become

The first implementation must not become:

- a Gantt-chart clone;
- a system requiring a dedicated scheduler;
- a rigid predecessor/resource-leveling engine;
- a one-Stage-per-day calendar;
- a generalized freight-management system;
- a complete KIT/BOM inventory system;
- an underground-wire/network locator system;
- a second Work Order/punch-list system;
- a GIS editing/routing platform;
- a replacement for permanent Stage/Scene/Display/Container identities;
- a system that silently changes permanent storage relationships when field plans change;
- a workflow that requires volunteers to perform duplicate administrative entry after doing the physical work;
- a Directus-table-search exercise presented as an operator application.

## Practical planner view — conceptual, not final UI

A useful first planner may conceptually look more like a work board than a traditional project schedule:

```text
SETUP 2026

AVAILABLE / NEXT
    Icicle Tunnel
    Candyland
    Church
    Racing Arches
    ...

LATER / DATE-GATED
    Santa's Station            not before Nov 1
    Food Collection traffic lanes
    ...

BLOCKED / NOT READY
    stake-dependent work       underground locate not complete
    ...

TODAY / SELECTED
    Food Collection perimeter/bracket work
        -> physical pick/load requirements resolved
        -> Containers/KITs/trailers shown
        -> work status captured from execution

DONE
    actual completion history retained
```

The exact columns, labels, dates, drag/drop behavior, and UI technology are unapproved. The important direction is **easy prioritization plus eligibility/readiness visibility plus execution-linked history**, not formal schedule maintenance.

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

The 2022 Setup hours/progress/punch-list material provides additional historical evidence that Setup progresses through repeated remaining-work snapshots and that some Stages are installed through multiple practical tasks. Historical punch-list/rework work is treated as predecessor evidence for the current Work Order System, not as a reason to rebuild punch-list lifecycle inside Setup Session.

Any 2025 actual-history source that is later recovered should be used to improve estimates and planning behavior, but the first 2026 design no longer depends on recovering a perfect historical record.

## Firm direction versus open design questions

### Firm direction established enough to engineer against

- one annual Setup Session context;
- official Setup begins October 5;
- the show must be totally ready/tested one week before Thanksgiving for VIP sponsor night;
- Santa's Station work cannot begin before November 1;
- flexible backlog and near-term planning rather than a rigid full-season schedule;
- the presentation layer must show remaining work and support practical ordering/progression;
- work can be available now, date-gated, or blocked by an external prerequisite;
- a Stage can contain separately selectable/phased practical work;
- multiple work items can occur in one day;
- practical work items can exist at different scope/granularity;
- planned and actual must remain conceptually distinct;
- normal execution should capture most actual history;
- selected work must resolve only the physical Displays/assets/Containers relevant to that selected work;
- shared Containers/trailers must deduplicate and explain why they are required;
- KIT Containers are in scope while detailed KIT contents remain deferred;
- transport burden can matter independently of Container count;
- Containers/KITs must be observable as they move from workshop to park/staging/final placement;
- an independently moved Display requires its own later scan/location observation;
- empty non-display Containers may return to a known workshop/rack/home location before Takedown;
- underground electrical/network locating is an external readiness prerequisite for stake-dependent work, not a Setup Session-owned locator workflow;
- defects/rework discovered during Setup belong to the existing Work Order System rather than a duplicate Setup punch-list lifecycle;
- Stage-level orientation remains primary for the first park guidance layer;
- Scene-level guidance is optional refinement, not prerequisite knowledge;
- city rental Areas remain a separate vocabulary/crosswalk;
- GPS/proximity is evidence or guidance, not automatic Stage authority;
- permanent home/storage relationships must not be destroyed by temporary Setup movement;
- scanner identities `DISP`, `CONT`, `LOC`, and `CTRL` remain permanent identity mechanisms owned by the Scan/Labeling boundary.

### Still intentionally open

- exact PostgreSQL schemas/tables/columns;
- exact work-item identity model;
- how practical Stage phases/components should be represented when existing Stage/Scene/Display identity is insufficient;
- whether a Setup-specific reusable work-package entity is needed at all;
- exact ordering/priority/job-size/effort estimation fields;
- exact representation of not-before, must-complete-by, and readiness/blocker constraints;
- exact representation of external prerequisite confirmation such as underground locate complete;
- which manual change/defer reasons are worth capturing;
- how much crew/volunteer information is useful in the first version;
- exact pick/load status/event names;
- exact staging/placement event names;
- when an open Work Order should block Setup completion versus simply remain parallel follow-up work;
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
2. define the minimum Setup work-item / annual-session data model needed to support remaining-work presentation, phased work, near-term progression, actual execution, and history;
3. define the minimum calendar/readiness constraint model needed for October 5 start, November 1 Santa's Station gate, VIP readiness, and external blockers without building a Gantt engine;
4. prove the dependency resolver against several representative Production cases and phased Stage work;
5. define the minimum physical pick/load output;
6. define the smallest execution/status/event model that normal scans/actions can maintain across workshop, park arrival, staging, placement, and return-to-workshop movement;
7. preserve the Work Order boundary for defects/rework;
8. add Stage-level orientation capability using the existing GPS reference dataset without building a full GIS platform;
9. test the workflow against real field scenarios before expanding scope.

Representative resolver/workflow test cases should include:

- a normal single-Stage setup area;
- Food Collection perimeter/bracket work selected without prematurely pulling later traffic-lane material;
- Food Collection traffic lanes remaining visibly later/date-gated;
- Santa's Station unavailable before November 1 and selectable afterward;
- stake-dependent work blocked until underground electrical/network locating has been completed externally;
- Icicle Tunnel including its KIT Containers;
- Old Elf Choir requiring the Conductor stored on Old Man Winter Container;
- Container 34 / Arch Trailer shared across multiple Stages;
- a zero-linked KIT requiring reviewed supplemental support;
- a non-Stage support task;
- common park staging before final placement;
- a Display moved away from its Container and scanned at its actual placement;
- an empty non-display Container returned to a workshop/rack/home location;
- `Take this to Whoville` orientation for a volunteer who does not know the park;
- a day whose plan changes because volunteer count or progress differs from expectation;
- a defect discovered during Setup creating/using the Work Order lifecycle without turning the Setup Session into a punch-list system.

## Success condition for the first production version

The first Setup Session is successful if MSB can use it during real Setup to answer, with materially less tribal knowledge and manual coordination:

> What still needs to be set up, what is actually available to work on next, what do we need to pull and transport for the selected work, where are those assets now, and what actually got done?

while respecting real date/readiness constraints and allowing the day to change naturally without requiring a separate person to maintain a formal project schedule.

## Related Documents

- [Setup and Deployment](README.md)
- [Setup Session Engineering Reconnaissance — 2026-09-03](Setup_Session_Engineering_Reconnaissance_2026-09-03.md)
- [Historical Setup Planning Evidence — 2024](Historical_Setup_Planning_Evidence_2024.md)
- [Container-to-Stage Relationship Reconnaissance — 2026-09-03](Container_Stage_Relationship_Reconnaissance_2026-09-03.md)
- [Park Placement Candidate Selection Reconnaissance — 2026-09-03](Park_Placement_Candidate_Selection_Reconnaissance_2026-09-03.md)
- [Park Area Naming and Orientation Reconnaissance — 2026-09-03](Park_Area_Naming_and_Orientation_Reconnaissance_2026-09-03.md)
- [Work Orders](../06_Work_Orders/README.md)
- [Stage GPS Reference Data Reconnaissance — 2026-09-03](../11_Site_Infrastructure_GIS/Stage_GPS_Reference_Data_Reconnaissance_2026-09-03.md)
- [#122 — Setup Session engineering issue](https://github.com/Gregovate/MSB-Production-Database-Project/issues/122)
