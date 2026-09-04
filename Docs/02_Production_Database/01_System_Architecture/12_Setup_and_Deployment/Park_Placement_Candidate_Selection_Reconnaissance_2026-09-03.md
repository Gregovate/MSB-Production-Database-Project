# Park Placement Candidate Selection Reconnaissance — 2026-09-03

| Document control | Value |
|---|---|
| Status | CURRENT ENGINEERING RECONNAISSANCE — concepts under consideration; implementation not yet approved |
| System | Setup Session |
| Parent system | Setup and Deployment |
| GIS dependency | Site Infrastructure / GIS |
| Owner | MSB Technical Team |
| Related issue | [#122 — Engineer annual Setup Session planning, pick-list, movement, and park-location subsystem](https://github.com/Gregovate/MSB-Production-Database-Project/issues/122) |

## Purpose

Preserve field-process observations, operational problems, and candidate ideas for how GPS/map/location information could assist park placement of Containers and Displays during Setup.

This document is **reconnaissance, not an approved workflow design**. The project is intentionally getting tribal knowledge and real field constraints onto paper before deciding how much GIS automation belongs in the 2026 Setup Session.

A simple nearest-Stage algorithm is already known to be unsafe as an automatic decision rule for MSB, but that does not mean a final replacement workflow has been selected.

## Current capability and evidence

PostGIS/geospatial capability is installed in Production PostgreSQL, but no GIS schema or operational spatial model has yet been built.

MSB already maintains park infrastructure in ExpertGPS and has current Stage/setup reference points projected into the established MSB park CRS:

`EPSG:8158 — NAD83(HARN) / WISCRS Kewaunee, Manitowoc and Sheboygan (ftUS)`

Phones/tablets provide WGS84/EPSG:4326 operational observations. The GIS contract requires preserving the original device observation and transforming a derived copy to EPSG:8158 when projected comparison is needed.

## Operator orientation / tribal-knowledge problem

A separate operational requirement exists even if GPS is never used to auto-select or validate a Stage:

> A volunteer should not need years of MSB tribal knowledge to know where Icicle Tunnel, Candyland, Festive Trees, the Church, or another Stage/setup area physically is in the park.

Today, experienced volunteers know the park layout and can interpret Stage names from memory. A new or occasional volunteer may know the name of the Container or Stage but still not know where to drive, unload, or carry it.

The future Setup workflow should therefore provide some form of **location/orientation guidance** for the selected work area. The exact presentation is intentionally open and could eventually include one or more of:

- a readable Stage/setup-area name and description;
- a simple park map showing the Stage/setup area;
- the operator's current position relative to the intended area;
- a reference point or several useful anchor points;
- a visual route/access hint where physical access matters;
- notes such as `Church side of river`, `north end`, `along road`, or another practical landmark;
- current-day Setup context showing which areas are being worked;
- a link/button such as `Show me where this goes` rather than an automatic placement decision.

These are **candidate forms of guidance, not approved UI requirements**.

The important requirement is that Stage/location knowledge becomes discoverable from controlled system data rather than remaining only in experienced volunteers' memory.

This orientation problem is related to, but distinct from, recording where an asset was actually placed. A user may need help finding Candyland before any Container scan occurs.

## Why nearest Stage cannot be authoritative

Field-process examples establish that spatial proximity alone is insufficient:

- some Stages extend approximately **600–800 feet**, so one Stage reference point may be far from a valid placement at the other end of the Stage;
- **Traditional Christmas and Peanuts overlap**, so proximity can produce multiple plausible Stage candidates;
- the **Church is separated from the park by a river**, so straight-line proximity can identify the wrong side of an operational barrier;
- Containers are commonly unloaded/staged before final distribution, so an asset may temporarily be near a Stage without being placed for that Stage;
- shared Containers/trailers can legitimately support several Stages.

Therefore the following is a constraint, not a complete design decision:

> GPS proximity must not by itself assign a Container/Display to a Stage or mark it placed.

## Candidate-selection concept under consideration — not approved

One plausible low-risk workflow is **business context first, GPS second, human confirmation last**.

Conceptual flow under consideration:

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

This is **not yet an approved implementation rule**. It is preserved because it appears to reduce tribal knowledge while avoiding the known failure modes of nearest-point automation.

Do not search all park Stages first merely because GPS is available unless later field testing proves that is useful and safe.

### Example — single-area Kit

Possible behavior:

```text
Container 60 — Elf Choir Kit
    -> expected Setup area: Old Elf Choir
    -> location information can help orient/rank that candidate
    -> operator confirms destination if the workflow requires confirmation
```

If one expected area is strongly established by current relationships, a future UI might place it first or preselect it for confirmation, but the operator must have a safe correction path if confirmation is used.

### Example — shared Container

Possible behavior:

```text
Container 34 — Arch Trailer
    -> valid Setup support derived from multiple Stages
    -> location information may help rank currently plausible Stage candidates
    -> operator chooses the actual placement/use for this event
```

Do not force a shared Container to one permanent Stage merely because of the current scan location.

### Unexpected placement

Any future workflow must allow deliberate exceptions or changed plans without silently changing permanent Container/Display relationships.

An `Other Stage / Setup Area` path is one possible UI treatment, not yet an approved control.

## Stage reference points are useful but not full Stage geometry

The current 2026 Stage GPS dataset provides useful reference points and can support orientation and rough candidate ranking.

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

This establishes constraints for any future design:

- do not reject a valid Stage merely because an observed device point is far from its single reference point;
- do not use one universal proximity threshold for all Stages;
- one point may still be useful for general orientation even when it is insufficient for placement validation.

Future improvement could use distance-to-line, distance-to-polygon, multiple anchors, or another representation if field value justifies it.

## Overlapping-Stage behavior

Traditional Christmas / Peanuts demonstrates that even accurate spatial geometry may overlap operationally.

Therefore spatial containment or nearest-distance cannot be the only discriminator if the system eventually assists with candidate selection.

Potential additional context includes:

- the Container/Display's expected Setup support relationships;
- the active Setup work planned for that day/session;
- the asset's permanent Display relationships where applicable;
- explicit operator knowledge/selection.

If two expected areas are physically close or overlapping, a future workflow must not hide that ambiguity merely to produce one answer.

## River / barrier behavior

The Church/park river separation demonstrates that straight-line distance is not equivalent to operational accessibility.

This is important both for placement and for orientation. Telling a new volunteer that the Church is "near" a park-side point is not enough if the correct delivery route requires being on the other side of the river.

For the 2026 MVP, no full routing/barrier engine is assumed.

Possible future aids include:

- coarse durable site/zone identity;
- access notes such as `Church side of river`;
- landmark/direction notes;
- mapped access points;
- richer GIS geometry if repeated field use proves it worthwhile.

Do not choose among those approaches until the actual operator workflow is tested.

## Staging versus final placement

A scan at the common unload/staging area must not automatically assign the Container to the geographically nearest Stage.

The Setup Session needs to preserve the semantic difference between temporary park staging and a later Stage/setup-area placement. Possible business concepts include:

```text
UNLOADED / STAGED
    -> asset is at park staging area

RELOCATED / PLACED
    -> asset was moved to a selected Stage/setup destination
```

The exact event names/schema remain unapproved.

## Illustrative UI concepts — not approved

One possible task-focused UI might show:

```text
Container 56 — Icicle Tunnel Kit

Expected Setup area:
Icicle Tunnel

[Show area on map]
[Confirm Icicle Tunnel]
[Choose another Stage / Setup area]
[Record as staging/unloaded instead]

Current GPS accuracy: 18 ft
```

Another workflow may not need all of those controls. The durable requirement is that the operator can discover where the named Setup area is and safely record what actually happened without interpreting raw Easting/Northing or latitude/longitude values.

## PostGIS 2026 MVP boundary

Because PostGIS is installed but unused, any first implementation can remain deliberately small.

Before schema work, verify:

1. installed PostGIS version;
2. EPSG:8158 exists in `spatial_ref_sys`;
3. `ST_Transform` from EPSG:4326 to EPSG:8158 behaves as expected for known park test points;
4. no existing GIS schema/table already owns these identities;
5. the minimum durable site/reference-point and operational-observation representation.

Potential 2026 uses of PostGIS include:

- controlled coordinate transformation;
- distance/proximity calculations;
- map/query support if it materially reduces operator confusion.

Do not build a full GIS editing system, road-routing system, or generalized spatial inventory merely to complete Setup Session.

## Scenarios any later design should handle

Regardless of the final UI or spatial model, future Setup engineering should account for these real cases:

- a new volunteer can determine where a named Stage/setup area is without asking an experienced volunteer;
- a Container with one expected Stage can be guided toward that area without an irreversible automatic assignment;
- Container 34 / Arch Trailer can support more than one valid Stage without creating a permanent one-Stage assignment;
- a scan in the common staging area can remain staging rather than becoming the nearest Stage;
- long Stage placement is not rejected because a single reference point is far away;
- Traditional Christmas / Peanuts ambiguity is not falsely collapsed into one answer based only on distance;
- Church-side versus park-side access remains understandable despite misleading straight-line proximity;
- the operator can deliberately record an unexpected Stage/setup area when plans change;
- original WGS84 observation/time/accuracy can be preserved independently of transformed coordinates and business destination if operational GPS observations are implemented.

## Related documents

- [Setup Session Engineering Reconnaissance — 2026-09-03](Setup_Session_Engineering_Reconnaissance_2026-09-03.md)
- [Container-to-Stage Relationship Reconnaissance — 2026-09-03](Container_Stage_Relationship_Reconnaissance_2026-09-03.md)
- [Setup Session subsystem](../README.md)
- [Site Infrastructure / GIS](../../../11_Site_Infrastructure_GIS/README.md)
- [Stage GPS Reference Data Reconnaissance — 2026-09-03](../../../11_Site_Infrastructure_GIS/Stage_GPS_Reference_Data_Reconnaissance_2026-09-03.md)
- [#122 — Setup Session engineering issue](https://github.com/Gregovate/MSB-Production-Database-Project/issues/122)
