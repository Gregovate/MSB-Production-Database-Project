# Site Infrastructure / GIS

This subsystem documents permanent physical-site identities, location history, power/site infrastructure relationships, and PostgreSQL integration of MSB GIS/GPS data.

## Current State

Substantial historical field/site information exists outside PostgreSQL, including GPX data going back to at least 2015, waypoints and tracks, receptacles, network tracks, power tracks, utility meters, distribution panels, circuit identifiers, and seasonal energization requirements.

Field collection uses a Garmin GPSMAP 66sr. ExpertGPS and county aerial imagery are used for validation/refinement.

Production PostgreSQL has PostGIS/geospatial capability available, but no accepted Setup/Deployment operational GIS workflow is currently using it. Before schema or application changes, verify the exact installed extension/version and existing geometry/geography objects rather than assuming how PostGIS is configured.

Current Setup Session reconnaissance has also established that a `2026_Stage_GPS.csv` dataset exists with 31 unique Stage/setup points and populated projected Easting/Northing coordinates. The dataset structure and ingestion gates are preserved in [Stage GPS Reference Data Reconnaissance — 2026-09-03](Stage_GPS_Reference_Data_Reconnaissance_2026-09-03.md). The uploaded CSV is not yet declared the controlled authoritative source until its source/export process and CRS are confirmed.

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
- confirm the source/export process and exact CRS for the supplied `2026_Stage_GPS.csv` dataset;
- reconcile the 31 Stage/setup reference points to `ref.stage` and/or durable park site/location identities without assuming one CSV row equals one Stage row;
- verify production PostGIS configuration and current spatial objects;
- define durable park Setup destination identities;
- reconcile park destinations with Stage/Scene/Display/Container relationships;
- define mobile GPS accuracy and proximity-validation requirements;
- determine whether park network coverage requires offline map/location behavior;
- preserve the existing NAD83 HARN WISCRS Sheboygan County Feet contract during integration.

## Resume Development

For Setup/Deployment GIS work, begin only after the actual Setup movement/placement workflow is documented.

Then review:

1. [Setup and Deployment](../12_Setup_and_Deployment/README.md);
2. [Stage GPS Reference Data Reconnaissance — 2026-09-03](Stage_GPS_Reference_Data_Reconnaissance_2026-09-03.md);
3. [Scan Workflows and Forklift Operations](../07_Labeling_and_Scanning/Scan_Workflows_and_Forklift_Operations.md);
4. [Containers and Storage](../04_Containers_and_Storage/README.md);
5. existing GPX/ExpertGPS datasets and waypoint conventions;
6. the live PostgreSQL/PostGIS configuration.

Do not design the GIS database schema from assumptions.

## Related Systems

- [Setup and Deployment](../12_Setup_and_Deployment/README.md)
- [Stage GPS Reference Data Reconnaissance — 2026-09-03](Stage_GPS_Reference_Data_Reconnaissance_2026-09-03.md)
- [Labeling and Scanning](../07_Labeling_and_Scanning/README.md)
- [Containers and Storage](../04_Containers_and_Storage/README.md)
- [Network Infrastructure](../10_Network_Infrastructure/README.md)
- [Controller Inventory](../08_Controller_Inventory/README.md)
- [Wiring System](../09_Wiring_System/README.md)
- [Work Orders](../06_Work_Orders/README.md)
