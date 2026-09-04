# Park Placement Candidate Selection Reconnaissance — 2026-09-03

| Document control | Value |
|---|---|
| Status | CURRENT ENGINEERING RECONNAISSANCE — implementation not yet approved |
| System | Setup Session |
| Parent system | Setup and Deployment |
| GIS dependency | Site Infrastructure / GIS |
| Owner | MSB Technical Team |
| Related issue | [#122 — Engineer annual Setup Session planning, pick-list, movement, and park-location subsystem](https://github.com/Gregovate/MSB-Production-Database-Project/issues/122) |

## Purpose

Preserve the field-process decision for how GPS should assist, but not control, park placement of Containers and Displays during Setup.

This document exists because a simple nearest-Stage algorithm would be operationally unsafe for MSB.

## Current capability and evidence

PostGIS/geospatial capability is installed in Production PostgreSQL, but no GIS schema or operational spatial model has yet been built.

MSB already maintains park infrastructure in ExpertGPS and has current Stage/setup reference points projected into the established MSB park CRS:

`EPSG:8158 — NAD83(HARN) / WISCRS Kewaunee, Manitowoc and Sheboygan (ftUS)`

Phones/tablets provide WGS84/EPSG:4326 operational observations. The GIS contract requires preserving the original device observation and transforming a derived copy to EPSG:8158 when projected comparison is needed.

## Why nearest Stage cannot be authoritative

Field-process examples establish that spatial proximity alone is insufficient:

- some Stages extend approximately **600–800 feet**, so one Stage reference point may be far from a valid placement at the other end of the Stage;
- **Traditional Christmas and Peanuts overlap**, so proximity can produce multiple plausible Stage candidates;
- the **Church is separated from the park by a river**, so straight-line proximity can identify the wrong side of an operational barrier;
- Containers are commonly unloaded/staged before final distribution, so an asset may temporarily be near a Stage without being placed for that Stage;
- shared Containers/trailers can legitimately support several Stages.

Therefore:

> GPS may rank or validate candidates, but GPS proximity must not by itself assign a Container/Display to a Stage or mark it placed.

## 2026 MVP candidate-selection rule

The first production workflow should use **business context first, GPS second, human confirmation last**.

Preferred flow:

```text
scan CONT:<id> or DISP:<id>
    -> resolve permanent asset identity
        -> resolve expected Setup areas from current business relationships
            -> linked Display Stage/Setup context
            -> supplemental reviewed KIT/support relationships where needed
            -> current Setup plan/work scope where applicable
        -> capture current WGS84 device observation + accuracy
        -> transform derived observation to EPSG:8158
        -> calculate distance to candidate reference Stage/site points
        -> rank expected candidates by spatial proximity
        -> present short candidate list
        -> operator explicitly selects/confirms actual destination
        -> record Setup-owned placement/relocation event
```

Do not search all park Stages first merely because GPS is available.

### Example — single-area Kit

```text
Container 60 — Elf Choir Kit
    -> expected Setup area: Old Elf Choir
    -> GPS confirms/ranks that candidate
    -> operator confirms destination
```

If one expected area is strongly established by current relationships, the UI may place it first or preselect it for confirmation, but the operator must still have a safe correction path.

### Example — shared Container

```text
Container 34 — Arch Trailer
    -> valid Setup support derived from multiple Stages
    -> GPS ranks the currently plausible Stage candidates
    -> operator chooses the actual placement/use for this event
```

Do not force a shared Container to one permanent Stage merely because of the current scan location.

### Unexpected placement

The operator must have an `Other Stage / Setup Area` path for deliberate exceptions or changed plans.

An unexpected selection should be recorded as an explicit deviation rather than silently rejected or silently changing permanent Container/Display relationships.

## Stage reference points are useful but not full Stage geometry

The current 2026 Stage GPS dataset provides useful reference points and is sufficient for rough candidate ranking.

It is **not** sufficient to represent the full physical shape of every Stage.

A future GIS model may need richer geometry where field value justifies it:

- `POINT` or one/more anchor points for compact Stages;
- `MULTIPOINT` for several meaningful anchors;
- `LINESTRING` for long linear Stages;
- `POLYGON` / `MULTIPOLYGON` for large areas;
- explicit site/zone geometry where a physical barrier such as the river matters.

Do not build all of those geometry classes merely to finish the 2026 MVP.

## Long-Stage behavior

For a 600–800 foot Stage, distance to one reference point can be misleading.

For 2026, that means:

- use the reference point only to rank candidates broadly;
- do not reject a valid Stage merely because the observed device point is far from its single reference point;
- do not use one universal proximity threshold for all Stages;
- require operator confirmation.

Future improvement may replace point-to-point distance with distance-to-line, distance-to-polygon, or nearest-anchor calculations for long Stages.

## Overlapping-Stage behavior

Traditional Christmas / Peanuts demonstrates that even accurate spatial geometry may overlap operationally.

Therefore spatial containment or nearest-distance cannot be the only discriminator.

The candidate ranking should also use:

- the Container/Display's expected Setup support relationships;
- the active Setup work planned for that day/session;
- the asset's permanent Display relationships where applicable;
- explicit operator selection.

If two expected areas are physically close or overlapping, both should remain visible candidates.

## River / barrier behavior

The Church/park river separation demonstrates that straight-line distance is not equivalent to operational accessibility.

For the 2026 MVP, do not attempt to create a full routing/barrier engine.

Instead:

- business-context filtering should normally keep unrelated candidates out of the short list;
- operator confirmation remains mandatory;
- a visibly wrong-side candidate must remain correctable;
- if field testing shows repeated ambiguity, introduce a coarse durable site/zone concept before attempting full route/network analysis.

A future GIS enhancement may model site zones, access areas, or barrier-aware geometry so the system can distinguish physically separated areas even when Euclidean distance is small.

## Staging versus final placement

A scan at the common unload/staging area must not automatically assign the Container to the geographically nearest Stage.

The Setup Session needs explicit business meaning for the scan, for example:

```text
UNLOADED / STAGED
    -> asset is at park staging area

RELOCATED / PLACED
    -> asset was moved to a selected Stage/setup destination
```

The exact event names/schema remain unapproved, but the workflow must preserve this semantic distinction.

## Recommended 2026 UI behavior

After a park placement/relocation scan, the task-focused UI should show approximately:

```text
Container 56 — Icicle Tunnel Kit

Expected Setup areas:
1. Icicle Tunnel        85 ft from current device fix
2. <another valid area> 240 ft

[Confirm Icicle Tunnel]
[Choose another Stage / Setup area]
[Record as staging/unloaded instead]

GPS accuracy: 18 ft
```

Distances and accuracy are decision aids, not proof of placement.

Do not require the operator to interpret raw Easting/Northing or latitude/longitude values.

## PostGIS 2026 MVP boundary

Because PostGIS is installed but unused, the first implementation can remain deliberately small.

Before schema work, verify:

1. installed PostGIS version;
2. EPSG:8158 exists in `spatial_ref_sys`;
3. `ST_Transform` from EPSG:4326 to EPSG:8158 behaves as expected for known park test points;
4. no existing GIS schema/table already owns these identities;
5. the minimum durable site/reference-point and operational-observation representation.

For the 2026 MVP, PostGIS should be used only where it materially helps:

- controlled coordinate transformation;
- distance/proximity ranking;
- later map/query support if needed.

Do not build a full GIS editing system, road-routing system, or generalized spatial inventory to complete Setup Session.

## Acceptance direction

The first park placement workflow should pass at least these cases:

- a Container with one expected Stage returns that Stage first and allows confirmation/correction;
- Container 34 / Arch Trailer can present more than one valid Stage candidate without creating a permanent one-Stage assignment;
- a scan in the common staging area can be recorded as staging rather than the nearest Stage;
- long Stage placement is not rejected because the single reference point is far away;
- Traditional Christmas / Peanuts ambiguity does not auto-select one based only on distance;
- a Church-side placement cannot become irreversible merely because a park-side point is closer in straight-line distance;
- the operator can deliberately choose another Stage/setup area and the event records that decision;
- original WGS84 observation/time/accuracy are preserved independently of the transformed coordinate and selected business destination.

## Related documents

- [Setup Session Engineering Reconnaissance — 2026-09-03](Setup_Session_Engineering_Reconnaissance_2026-09-03.md)
- [Container-to-Stage Relationship Reconnaissance — 2026-09-03](Container_Stage_Relationship_Reconnaissance_2026-09-03.md)
- [Setup Session subsystem](../README.md)
- [Site Infrastructure / GIS](../../../11_Site_Infrastructure_GIS/README.md)
- [Stage GPS Reference Data Reconnaissance — 2026-09-03](../../../11_Site_Infrastructure_GIS/Stage_GPS_Reference_Data_Reconnaissance_2026-09-03.md)
- [#122 — Setup Session engineering issue](https://github.com/Gregovate/MSB-Production-Database-Project/issues/122)
