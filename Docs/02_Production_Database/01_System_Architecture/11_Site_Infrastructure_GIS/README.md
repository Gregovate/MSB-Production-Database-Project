# Site Infrastructure / GIS

This subsystem documents permanent physical-site identities, location history, power/site infrastructure relationships, and PostgreSQL integration of MSB GIS/GPS data.

## Current State

Substantial historical field/site information exists outside PostgreSQL, including GPX data going back to at least 2015, waypoints and tracks, receptacles, network tracks, power tracks, utility meters, distribution panels, circuit identifiers, and seasonal energization requirements.

Field collection uses a Garmin GPSMAP 66sr. ExpertGPS and county aerial imagery are used for validation/refinement.

Production PostgreSQL has PostGIS/geospatial capability available, but no accepted Setup/Deployment operational GIS workflow is currently using it. Before schema or application changes, verify the exact installed extension/version and existing geometry/geography objects rather than assuming how PostGIS is configured.

## Coordinate-System Contract

The working coordinate reference is:

`NAD83 HARN WISCRS Sheboygan County Feet (USft)`

This contract must be preserved when historical or new field data is integrated.

Browser/mobile device GPS normally arrives as latitude/longitude in a different coordinate reference. Any operational Setup workflow must explicitly transform/normalize that device input rather than silently mixing coordinate systems.

## Design Intent

PostgreSQL should provide durable identity, relationships, and useful location history for physical site infrastructure while preserving appropriate survey/GIS tools for collection and visualization.

For Setup/Deployment, GIS should answer questions such as:

- where is the intended park destination for this Display/Container;
- what permanent site/location identity represents that destination;
- what are the best current reference coordinates for it;
- how close is the operator/device/asset to that expected destination;
- is the observed GPS accuracy sufficient to make the requested confirmation meaningful.

GIS should not become a substitute for permanent Display or Container identity.

## Site Location Identity Requirement

Historical display/location data does not consistently use the Production Database permanent `display_id`. Future integration must reconcile to permanent Production Database identities rather than introduce another competing identity.

Likewise, a park destination should have a durable site/location identity when operational workflows require one. Raw GPS coordinates should not be the business key.

Why:

- coordinates can be refined after better survey evidence;
- device fixes vary by equipment and conditions;
- the same conceptual site location can remain stable across coordinate corrections;
- Setup history should refer to the location identity rather than a frozen coordinate string.

## GPS Evidence Classes

Future engineering should distinguish at least these location data classes.

### Reference / authoritative site coordinates

Coordinates established or validated through controlled GIS/survey sources such as Garmin field collection, ExpertGPS review, county imagery, or another approved reference process.

These describe the best known location of the permanent site feature/destination.

### Operational device coordinates

Coordinates produced by a phone/tablet or other field device during Setup/Deployment.

These are operational observations and may include accuracy/uncertainty metadata. They should not silently overwrite reference coordinates.

### Placement / proximity validation

A derived workflow result comparing an operational observation with the expected destination.

PostGIS may be useful for this comparison, but acceptable tolerances must come from the actual field process and location type—not from an arbitrary universal distance.

## Workshop Storage Boundary

Workshop/rack storage is not primarily a GIS problem.

Precise rack locations and broader storage locations already exist as discrete Production Database location identities. High-volume workshop workflows are expected to use labeled rack/storage locations and the Zebra DS3678-HD scanner.

Do not replace practical rack identifiers with GPS coordinates merely to unify the data model.

The likely boundary is:

```text
Workshop / storage
    -> discrete rack/storage location identity
    -> barcode/QR scanning

Park / field
    -> durable site/location identity
    -> reference GIS coordinates
    -> mobile GPS/map context where useful
```

## Setup/Deployment Integration Direction

Likely park workflow:

```text
scan DISP:<id> or CONT:<id>
    -> resolve expected Setup destination
        -> resolve durable park site/location identity
            -> obtain current device GPS/accuracy when needed
                -> compare with expected site geometry/location
                    -> guide / validate / confirm according to workflow rules
```

The exact write event is not yet defined. Being physically near the expected coordinate does not automatically mean a Container or Display should be marked delivered or installed.

Setup/Deployment owns the movement/status business event. GIS owns spatial identity/evidence and spatial calculations.

For the 2026 launch, GIS/location integration is a **field-start gate**, not a reason to create the real 2026 Setup Session early. The reusable Catalog/task/material foundation and #122 scheduling launch remain separate from the later field-execution acceptance.

## Setup Layout and Ground-Penetration Locate Direction

2026 Setup reconnaissance established a second operational use for the existing GIS source set: **layout guidance and targeted underground locate decisions**.

MSB already has relative placement tracks plus buried network/power reference information outside the new Production Database. That information should be made useful to Setup rather than requiring crews to rely on memory.

The locate rule is not `locate every Stage`.

The operator-confirmed rule is:

> Locate/clear underground infrastructure only where planned ground penetration has a plausible chance of intersecting buried network/power infrastructure or where the risk remains unresolved.

Conceptually:

```text
planned Display / stake / anchor / rebar footprint
    + known buried power/network reference tracks
    -> plausible intersection / proximity risk?

NO
    -> no locate requirement for that work scope

YES / UNCERTAIN
    -> locate/clear the affected area before ground penetration
```

Do not spend field time locating areas where there is nothing underground to damage.

This may be a partial-area determination. One corner or one Display line may require locate/clearance while unrelated work in the same Stage can proceed.

`No locate required` is a derived or reviewed readiness fact. It is not another annual task someone must manually mark complete.

Issue #171 owns the independently actionable 2026 engineering work to inventory the existing GPX/ExpertGPS source set, reconcile useful tracks/features, verify current PostGIS state, and design the smallest useful Setup integration.

Site Infrastructure / GIS owns the spatial reference/evidence and spatial calculation. Setup owns whether the resulting readiness condition permits planned work to proceed.

## Field Correction / Continuous-Improvement Boundary

Spatial reference data will not always be perfect. If Production Crew discover a missing/wrong buried route, layout track, waypoint, or risk area while doing real work, the finding must be preserved rather than becoming verbal/chat-only knowledge.

For a **concrete wrong/missing condition that needs somebody to act later**, the connected field workflow may create a contextual Work Order directly, consistent with the Setup correction contract. Creating the Work Order must not silently overwrite controlled reference GIS data.

Issue #172 remains the broader cross-system observation/continuous-improvement path for findings where the correct owner/action is genuinely unclear or where the finding is an improvement observation rather than a concrete correction.

GIS should consume those common mechanisms rather than inventing an isolated correction queue.

## PostgreSQL / PostGIS Engineering Gate

Before implementing the park workflow:

1. verify the production PostGIS extension/version;
2. inventory current geometry/geography columns, spatial reference usage, indexes, and GIS-related tables/views if any;
3. inventory current Storage Location tables separately;
4. inventory GPX/ExpertGPS waypoint conventions and stable identifiers;
5. reconcile useful site features to Production Database identities;
6. define transformation from phone/tablet GPS coordinates to the working GIS coordinate contract;
7. define whether application proximity checks should use geography, projected geometry, or another controlled calculation;
8. define required device accuracy and location-specific tolerance rules;
9. define which observations/history are worth preserving.

Do not start by adding generic latitude/longitude columns throughout the Production Database.

## Current/Future Responsibilities

- permanent site/location identities;
- reference GPS waypoints and track history;
- operational GPS observations where a workflow needs them;
- spatial/proximity calculations;
- receptacles and power infrastructure;
- utility meters, panels, and circuits;
- seasonal energization requirements;
- relationships to Network Infrastructure, Wiring, Controller Inventory, Displays, Work Orders, and Setup/Deployment.

## Known Open Work

- inventory the existing GPX/ExpertGPS data and waypoint naming/identity rules;
- verify production PostGIS configuration and current spatial objects;
- define durable park Setup destination identities;
- reconcile park destinations with Stage/Scene/Display/Container relationships;
- integrate placement tracks and buried network/power reference data for targeted Setup layout/ground-penetration decisions under Issue #171;
- define meaningful proximity/risk uncertainty for `locate required` / `review required` decisions rather than applying locates everywhere;
- define mobile GPS accuracy and proximity-validation requirements;
- determine whether park network coverage requires offline map/location behavior;
- preserve the existing NAD83 HARN WISCRS Sheboygan County Feet contract during integration;
- use direct contextual Work Orders for concrete correction needs and #172 for broader/unclear observations rather than inventing a GIS-specific queue.

## Resume Development

For Setup/Deployment GIS work, begin only after the actual Setup movement/placement workflow and current launch priority are understood.

Then review:

1. [Setup and Deployment](../12_Setup_and_Deployment/README.md);
2. [Setup Task Supporting Information Contract](../12_Setup_and_Deployment/engineering/Setup_Task_Supporting_Information_Contract_2026-09-11.md);
3. GitHub Issue #171;
4. GitHub Issue #172;
5. GitHub Issue #175 where offline/field-document behavior is relevant;
6. [Scan Workflows and Forklift Operations](../07_Labeling_and_Scanning/Scan_Workflows_and_Forklift_Operations.md);
7. [Containers and Storage](../04_Containers_and_Storage/README.md);
8. existing GPX/ExpertGPS datasets and waypoint conventions;
9. the live PostgreSQL/PostGIS configuration.

Do not design the GIS database schema from assumptions.

## Related Systems

- [Setup and Deployment](../12_Setup_and_Deployment/README.md)
- [Labeling and Scanning](../07_Labeling_and_Scanning/README.md)
- [Containers and Storage](../04_Containers_and_Storage/README.md)
- [Network Infrastructure](../10_Network_Infrastructure/README.md)
- [Controller Inventory](../08_Controller_Inventory/README.md)
- [Wiring System](../09_Wiring_System/README.md)
- [Work Orders](../06_Work_Orders/README.md)
