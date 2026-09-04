# Setup Session Engineering Reconnaissance — 2026-09-03

| Document control | Value |
|---|---|
| Status | CURRENT ENGINEERING RECONNAISSANCE — schema/application not yet approved |
| System | Setup Session |
| Parent system | Setup and Deployment |
| Owner | MSB Technical Team |
| Current engineering issue | [#122 — Engineer annual Setup Session planning, pick-list, movement, and park-location subsystem](https://github.com/Gregovate/MSB-Production-Database-Project/issues/122) |
| Repository baseline reviewed | `main` at `0540d3b702de68d10d78ff8e17e8bca317a9a51f` |

## Purpose

Preserve the Setup Session business-process discoveries, verified Production Database evidence, design constraints, unresolved relationships, and implementation gates established during 2026-09-03 engineering discussion.

This document is intentionally detailed because later Setup Session engineering must not reconstruct these findings from conversation history.

It does **not** approve a database schema or application implementation.

## Core Direction

Setup should become an annual operational session system comparable in purpose to the Testing System's annual session context, but Setup has materially different planning and execution needs.

Testing primarily answers whether a Container/Display is ready. Setup must answer:

> What are we setting up, what physical Displays/assets does that work require, where are those items currently stored or transported, when do we intend to move them, and what actually happened when the work was performed?

The Setup Session therefore needs to become the umbrella for:

```text
annual Setup Session
    -> flexible work planning
        -> selected Setup work
            -> physical dependency resolution
                -> pick / transport work
                    -> scan-confirmed execution
                        -> park movement / placement
                            -> GPS/location observations where useful
                                -> planned-versus-actual history for later seasons
```

Do not make raw Directus table search the field/planning workflow.

## Real Planning Process

The Setup schedule is deliberately flexible.

Current operating practice is approximately:

- the first couple of Setup days can normally be planned with reasonable confidence;
- later work changes based on the number of volunteers who actually arrive;
- weather can change the day's plan;
- work completed faster or slower than expected changes what happens next;
- large jobs are intentionally followed by smaller/easier work where practical so volunteers are not repeatedly overloaded;
- some large Displays can occupy an entire trailer and require multiple trips to move all parts to the park;
- strict trailer loading sequence is less important than initially assumed because trailers are normally side-loaded.

The future system must support frequent replanning rather than forcing a rigid calendar commitment.

### Planning history worth preserving

A primary reason to build the annual Setup Session is to retain enough planned-versus-actual evidence to improve later seasons.

Useful evidence may include, subject to later workflow validation:

- work planned for the day;
- work actually completed;
- selected Stage/Sub-stage/Scene/Display/work package;
- crew size and/or volunteer participation when useful;
- start/finish or useful duration evidence;
- transport/trip burden;
- major delays;
- reason a plan changed or was deferred, such as weather, crew availability, equipment/material problem, prior work incomplete, or work finishing sooner/later than expected;
- actual sequence used;
- effort history useful for estimating future volunteer-hours or day size.

Do not require volunteers to enter data that can be captured automatically or is not useful for later planning.

## Pick-List Problem

The current practical problem is that there is no operator-safe way to generate the physical pick list for a selected Setup job. Searching/browsing Directus tables is not a scalable field workflow.

The planner cannot simply ask:

> Which Containers belong to this Stage?

Containers can hold Displays from multiple unrelated Stages, and a Display required for one Setup job may be stored on a Container primarily associated with something else.

The required resolver direction is:

```text
selected Setup work
    -> required current Displays/assets
        -> current storage/Container relationship for each required item
            -> deduplicate shared Containers/trailers
                -> explain why each physical asset is required
```

### Old Elf Choir / Old Man Winter example

A representative real-world dependency is the Old Elf Choir conductor.

Operationally, when MSB decides to set up Old Elf Choir, the Conductor is needed, but the Conductor is stored on the Old Man Winter Container.

The planner must therefore be able to derive:

```text
Set up Old Elf Choir
    -> Conductor is required
        -> Conductor is stored on Old Man Winter Container
            -> Old Man Winter Container must be included in the pick list
```

The resulting pick list should show **why** that Container is required so a warehouse volunteer does not have to remember the exceptional relationship.

This example is a critical acceptance case for the first dependency resolver.

## Shared Transport/Storage Assets

The real system includes trailers and Containers used as practical shared storage/transport assets for many unrelated Displays.

### Antenna Trailer

The Antenna Trailer stores parts for multiple Displays because that is a practical way to keep and transport them.

This means a selected Setup job may depend on a shared trailer even when the trailer itself does not conceptually belong to that Stage.

The exact database representation of those stored parts must be inventoried before deciding whether existing Display relationships are sufficient or component-level inventory is needed.

### Container 34 — Arch Trailer

Container 34 is a critical engineering test case because it is simultaneously:

1. a warehouse storage/transport asset for Displays from multiple Stages;
2. a shared transport dependency for several Setup jobs; and
3. after its cargo is unloaded, the physical base/platform used by the Who House for the show season.

The trailer stays at the park through the show and is released/reloaded during Takedown.

This proves that a physical Container can have permanent storage/transport relationships and a separate relationship where the Container itself becomes part of a Display.

## Verified Production Database Evidence — Container 34

On 2026-09-03, a DBeaver query against Production Database `ref.display` returned all Displays currently assigned to `container_id = 34` together with Stage information.

The query pattern was:

```sql
SELECT
    d.display_id,
    d.display_name,
    d.container_id,
    d.stage_id,
    s.stage_key,
    s.stage_name,
    d.display_status_id
FROM ref.display d
LEFT JOIN ref.stage s
    ON s.stage_id = d.stage_id
WHERE d.container_id = 34
ORDER BY
    s.stage_key,
    d.display_name;
```

The returned result contained **121 Display records across six Stages**, and every returned row had `display_status_id = 1`.

| Stage | Displays on Container 34 |
|---|---:|
| 04 — Food Collection | 8 |
| 10 — Stars | 24 |
| 14 — Icicle Tunnel | 36 |
| 17 — Candyland | 2 |
| 21 — Polar Bear Playground | 3 |
| 25 — Racing Arches | 48 |
| **Total** | **121** |

This is production evidence that Stage -> Container is not a valid general pick-list model.

### Star Stage finding

All 24 Star Stage stars are already represented as individual `ref.display` records on Container 34 (`ST-StarRow-01` through `ST-StarRow-24`).

Therefore, at least for Star Stage, the first Setup resolver does **not** need a new component-inventory model to discover the Arch Trailer dependency. It can resolve the required Displays, follow their existing `container_id`, and deduplicate Container 34.

### Other Container 34 groups returned

The production result also included current Display records for:

- Food Collection arch material;
- Icicle Tunnel entry/exit/hanger arch material;
- Candyland Arch material;
- Polar Bear steel arch-support material; and
- Racing Arches wraps and steel arch pieces.

The exact 121-row production output is not duplicated here because the executable Production Database remains the authority for current assignments. The counts and representative identities above are preserved as reconnaissance evidence.

## Display Storage Relationship Versus Container-as-Display Relationship

A critical distinction was established during reconnaissance.

### Display stored in Container

The normal current relationship represented by `ref.display.container_id` answers:

> Which physical Container is this Display currently associated with/stored on?

Example:

```text
Conductor Display
    -> stored on Old Man Winter Container
```

### Container itself becomes part of a Display

The Production Database also has a `display_pallet` Container flag indicating that a Container itself is part of a Display.

Current reconnaissance has **not** established a field/relationship identifying **which Display** the flagged Container becomes part of.

The Arch Trailer demonstrates why that missing relationship matters:

```text
Container 34 / Arch Trailer
    -> stores many unrelated Displays
    -> after unloading, trailer itself becomes base/platform of Who House
```

The Who House itself is stored separately against the workshop wall in a different location. Therefore the Who House must **not** be assigned to `container_id = 34` merely to express that the Arch Trailer becomes its base.

These two relationships point in different directions and must remain conceptually separate:

```text
Display -> current storage Container

Container -> Display that the Container physically becomes part of
```

### Engineering gate

Before schema design:

1. inventory the live `ref.container` fields, constraints, views, Directus metadata, and actual rows using `display_pallet`;
2. determine the intended historical/current meaning of `display_pallet` from production evidence;
3. determine whether an existing relationship already identifies the Display that the Container forms part of;
4. if no relationship exists, define the minimum durable relationship needed by Setup without casually removing or repurposing the existing flag;
5. verify all existing consumers of `display_pallet` before changing it.

Do not use `ref.display.container_id` to solve this reverse relationship.

## Setup Work Scope and Dependency Resolution

The operator should be able to start from the work they intend to perform, not from knowledge of Container IDs.

Useful selectable scopes may include, subject to real workflow validation:

- Stage;
- Sub-stage;
- Scene;
- individual Display;
- a Setup-specific work package only where existing Stage/Scene/Display relationships cannot adequately express the real job.

Do not introduce a new work-package identity merely because it sounds convenient. First prove whether existing Production Database Stage/Scene/Display relationships can resolve the required Displays.

### Deduplication requirement

If several selected jobs require material stored on the same Container/trailer, the pick list must contain the physical asset once and explain all reasons it is needed.

Example:

```text
Container 34 — Arch Trailer

Required because selected work needs:
- 24 Star Stage Displays
- Candyland Arch Displays
- Polar Bear arch-support Displays
```

One movement of Container 34 may satisfy many future/parallel work dependencies.

The annual Setup Session should also know after a shared trailer/Container has already been moved to the park so later work does not incorrectly schedule the same transport again.

## Transport Burden

Some Displays consume an entire trailer and may require approximately three trips to move all pieces to the park.

The Setup Session therefore needs a way to represent or learn transport burden separately from the number of Containers returned by a pick-list resolver.

Do not build a freight-management subsystem prematurely. First inventory real multi-trip cases and determine the minimum planning fields/history that help MSB decide what can reasonably be accomplished on a given day.

Because trailers are normally side-loaded, strict front-to-back loading/unloading sequence is not a primary requirement for the first planner. Physical grouping, trip count, shared-asset dependencies, and completeness are more important.

## Annual Setup Session Model Direction

The annual Setup Session should provide annual context in the same broad spirit as annual Testing while preserving Setup-specific layers.

The current design direction is conceptually:

```text
Setup Session / season
    |
    +-- flexible work days / planning
    |       |
    |       +-- selected work scopes/packages
    |               |
    |               +-- resolved Displays/assets
    |                       |
    |                       +-- deduplicated Containers/trailers
    |
    +-- actual execution
            |
            +-- picked / loaded / transported
            +-- park arrival / unloaded
            +-- relocated / placed
            +-- GPS/location observations where useful
            +-- actual crew/time/delay evidence where useful
```

This is a business model direction, not approved table structure.

### Planned versus actual

Do not repeatedly overwrite a planned date/sequence until it looks like the final outcome.

When useful for later seasons, preserve enough distinction to know:

- what MSB planned;
- what changed;
- why it changed; and
- what actually happened.

Normal replanning must remain easy. History should improve future decisions without creating administrative burden during Setup.

## Park Location / GPS Workflow

Park location tracking is part of the active Setup Session, not a standalone generic tracking database.

### Container arrival/unload

Typical real workflow:

1. a Container arrives at the park on a trailer;
2. it is unloaded, commonly in the Food Collection parking-lot/staging area;
3. the operator scans the Container;
4. the tablet/phone captures its current GPS observation;
5. the Setup Session records the meaningful arrival/unload observation/event.

### Container relocation

Later, another worker moves the Container from the unloading area to the Stage/work area where it belongs and scans it again.

The later observation becomes newer "last seen" evidence while the earlier unloading observation remains useful Setup history.

### Display placement

Containers may hold Displays belonging to more than one Stage. A Display may therefore be removed from the Container and moved independently to its own Stage.

When that independent movement matters operationally, scan the `DISP` identity and capture a new GPS observation for the Display.

Do **not** fabricate Display GPS observations merely because its assigned Container was scanned somewhere. A Container observation may be useful indirect search context, but it is not proof that every assigned Display was physically present there at that moment.

## Offline Field Requirement

Not every tablet will have cellular service, and Wi-Fi may not be available everywhere in the park.

The park workflow must therefore be evaluated for deliberate offline operation.

Expected design direction:

```text
scan permanent CONT/DISP identity
    -> normalize locally
        -> attach current device GPS observation/accuracy
            -> create locally unique observation/event identity
                -> queue locally while offline
                    -> synchronize when connectivity returns
```

Requirements to preserve during later engineering:

- location services/GPS must be enabled where GPS capture is required;
- the device must actually be capable of producing useful field location fixes; do not assume cellular service is required or that every Wi-Fi-only tablet has equivalent GNSS behavior;
- preserve the original observation time separately from server receive/sync time;
- offline synchronization must be idempotent so retrying a partially synchronized queue does not duplicate events;
- the operator must be able to see whether observations are queued, synchronized, or failed;
- existing full-URL QR labels must remain usable through the MSB Scan application's local normalization where offline browser navigation would otherwise fail;
- do not make Setup business logic depend on Zebra-specific scanner formatting.

Exact PWA/browser/local-storage technology is not approved by this document.

## GPS / GIS Boundary

Operational phone/tablet coordinates are evidence associated with Setup work. They are not authoritative surveyed/reference coordinates.

Preserve the existing Site Infrastructure/GIS contract:

- permanent park/site identity is separate from raw device coordinates;
- authoritative/reference coordinates may come from controlled Garmin/ExpertGPS/GIS sources;
- device observations should retain accuracy/uncertainty where available;
- device coordinates must not silently overwrite reference GIS coordinates;
- coordinate transformation/spatial calculations belong with Site Infrastructure/GIS;
- Setup Session owns what the observation means operationally, such as delivered, relocated, or placed.

Do not add generic latitude/longitude fields across permanent Display/Container tables merely to implement Setup tracking.

## Scan Boundary

Permanent identities remain:

```text
DISP:<display_id>
CONT:<container_id>
LOC:<location_code>
CTRL:<controller_id>
```

Scan resolves those identities. Setup Session gives a scan its annual business meaning when the operator is working inside an explicit Setup workflow.

This avoids inferring a destructive state change from arbitrary scan order.

Related Scan work remains separate:

- [#113 — Prepare Scan application and Setup-season scanning integration](https://github.com/Gregovate/MSB-Production-Database-Project/issues/113)
- [#88 — Implement Setup-critical Location scan resolution and movement workflow](https://github.com/Gregovate/MSB-Production-Database-Project/issues/88)

#88 must hand accepted Location/scan behavior into Setup Session; it must not become the annual Setup planner.

## Operator UX Direction

The future Setup Session operator interface should be task-focused.

Warehouse volunteers should not need to understand:

- PostgreSQL table relationships;
- Directus collection structure;
- Stage IDs versus Container IDs;
- why an exceptional shared trailer is needed.

The application should explain the result, for example:

```text
Container 34 — Arch Trailer
Required because:
- 24 Star Stage Displays are stored here
- Candyland Arch material is stored here
```

Similarly, the Old Man Winter Container should be explainable as required for Old Elf Choir because it carries the Conductor.

Normal scanning should confirm physical execution of the plan, not force the operator to construct the plan by scanning arbitrary assets.

Unplanned additions/deviations must remain possible because real Setup work changes during the day, but the system should preserve enough distinction between planned and unplanned execution to learn from it later.

## Takedown Implication

The Arch Trailer demonstrates that Takedown is the reverse of some Setup dependencies.

During Setup:

```text
Arch Trailer
    -> moves to park
    -> shared cargo unloaded for multiple jobs
    -> trailer becomes Who House base
```

During Takedown:

```text
Who House dismantled
    -> Arch Trailer released from Display/base role
    -> shared arch/star material reloaded as applicable
    -> trailer returns to storage/transport role
```

Do not engineer Takedown schema from this single example, but preserve the lifecycle because Setup decisions must not make the reverse operation impossible to represent.

## Current Proven Facts Versus Open Questions

### Proven / directly established

- Setup planning is flexible and varies with volunteer availability, weather, job size, fatigue, and actual progress.
- Directus table search is not a sufficient future pick-list workflow.
- A required Display can be stored on a Container primarily associated with another Display/job, as demonstrated by the Old Elf Choir Conductor / Old Man Winter Container example.
- Container 34 has 121 current `ref.display` assignments across six Stages in the 2026-09-03 production query.
- Those assignments include all 24 Star Stage stars as individual Display records.
- The Arch Trailer is shared storage/transport for multiple Setup areas.
- After unloading, the Arch Trailer becomes the base for Who House and stays in the park until Takedown.
- Who House is stored separately in the workshop and must not be assigned to Container 34 merely to express the trailer-as-base relationship.
- a `display_pallet` flag exists on Containers to identify Containers that are part of a Display, but the current reconnaissance has not yet established which Display relationship is used or missing in production.
- park work may occur without Wi-Fi/cellular connectivity and may require later synchronization of GPS-backed observations.

### Still to prove before schema design

- exact existing Setup/season tables or fields in production, if any;
- exact live `ref.container` schema and all `display_pallet` consumers;
- whether any existing relationship already identifies the Display associated with a Display-pallet Container;
- exact existing representation of Antenna Trailer parts;
- the correct selectable planning scope(s) for each real Setup job;
- whether any Setup-specific dependency table is needed after existing Stage/Scene/Display relationships are fully tested;
- which KIT/material contents need inventory for Setup planning;
- the minimum transport-burden representation;
- the minimum crew/effort/history data worth preserving;
- offline browser/device capabilities and supported field devices;
- actual park GPS accuracy requirements;
- production PostGIS configuration and coordinate-handling implementation;
- exact event/state model for pick/load/delivery/relocation/placement;
- how annual Setup state should integrate with Takedown without conflating the two workflows.

## Required Next Reconnaissance

Before proposing DDL or application code:

1. inventory live season and any Setup-related production objects;
2. inventory live `ref.container`, `ref.display`, Stage/Scene, storage-location, person/audit, and relevant Testing session structures;
3. enumerate all Containers where `display_pallet = true` and identify their real-world Display relationships;
4. inspect Container 34 and the Antenna Trailer in current production data;
5. test the proposed `selected work -> Displays -> Containers -> deduplicate` resolver against representative real jobs;
6. document additional exceptions where the normal relationship chain fails;
7. identify the minimum plan-versus-actual information that materially improves next-year scheduling;
8. inventory current Scan #88/#113 contracts and determine the clean Setup Session handoff;
9. verify Site Infrastructure/GIS/PostGIS baseline before designing GPS storage/calculation;
10. design schema only from that evidence.

## Related Systems and Documents

- [Setup Session subsystem portal](../README.md)
- [Setup and Deployment](../../README.md)
- [Containers and Storage](../../../04_Containers_and_Storage/README.md)
- [Testing System](../../../05_Testing_System/README.md)
- [Labeling and Scanning](../../../07_Labeling_and_Scanning/README.md)
- [Scan Workflows and Forklift Operations](../../../07_Labeling_and_Scanning/Scan_Workflows_and_Forklift_Operations.md)
- [Site Infrastructure / GIS](../../../11_Site_Infrastructure_GIS/README.md)
- [#122 — Setup Session engineering issue](https://github.com/Gregovate/MSB-Production-Database-Project/issues/122)
- [#88 — Location scan/movement integration](https://github.com/Gregovate/MSB-Production-Database-Project/issues/88)
- [#113 — Scan Setup-season integration](https://github.com/Gregovate/MSB-Production-Database-Project/issues/113)
