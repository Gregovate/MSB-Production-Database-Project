# Site Infrastructure / GIS

This subsystem documents permanent physical-site identities, location history, power/site infrastructure relationships, and PostgreSQL integration of MSB GIS/GPS data.

## Required reference-data editing authority — #171 / #230

Operator decision, 2026-10-10: the MSB database-backed application will be the
normal editor and source of truth for maintained infrastructure reference data.
This is required scope of unfinished [#230 Reference Data Manager](https://github.com/Gregovate/MSB-Production-Database-Project/issues/230),
coordinated with [#171 GIS/infrastructure](https://github.com/Gregovate/MSB-Production-Database-Project/issues/171)
under commanding [#122 Setup](https://github.com/Gregovate/MSB-Production-Database-Project/issues/122).

- Maintain permanent waypoints, names/aliases, reference geometry, tracks,
  physical cables/endpoints, networks, switches/devices, reference classifications
  and type/icon mappings in governed `ref` tables and relationships. Reuse existing
  identities and objects; exact table names/DDL follow current-schema inventory.
- #171 owns spatial/source reconciliation and coordinate rules. #230 owns the
  governed reference-maintenance interface, including map-based reference edits.
  Map, schematic and Wiring views consume the same maintained records.
- Names, waypoint positions, track geometry and device/cable relationships must
  be editable through authorized application actions with validation, actor/time
  audit and retained prior versions. A read-only import/archive is insufficient.
- Schematic layout is separate presentation state; moving a schematic symbol
  must not move geographic coordinates. Reuse supplied icon assets rather than
  recreate artwork; editable type/icon references do not change physical identity.
- GPX is the authoritative location source during initial reconciliation and
  transition. After accepted migration/editor cutover, database reference records
  become maintenance authority; GPX/draw.io are source evidence or controlled
  interchange/presentation outputs. Do not silently maintain competing masters.
- Keep original GPX/FLW/draw.io provenance, test results and #88 seasonal movement
  observations separate from editable reference facts. Declaring reference data
  in `ref` does not put all test/event history there or make evidence overwriteable.
  LOR remains authoritative for expected show wiring configuration.
- Correct reference identity once. Routine workflow is download FLW -> process
  new/updated test evidence -> done. Preserve approved corrections/aliases,
  skip already-imported tests, append retests and surface only new/ambiguous
  matches. Routine work requires neither CSV export nor tester writeback.
- #230 remains unfinished for this integration until reference editing and
  shared consumption are implemented and accepted. Existing map rendering is
  preserved while this is completed. This decision authorizes documentation and
  design direction, not an unreviewed Production migration or source cutover.

## Current State

Substantial historical field/site information exists outside PostgreSQL, including GPX data going back to at least 2015, waypoints and tracks, receptacles, network tracks, power tracks, utility meters, distribution panels, circuit identifiers, and seasonal energization requirements.

Field collection uses a Garmin GPSMAP 66sr. ExpertGPS and county aerial imagery are used for validation/refinement.

Production PostgreSQL has PostGIS/geospatial capability available, but no accepted Setup/Deployment operational GIS workflow is currently using it. Before schema or application changes, verify the exact installed extension/version and existing geometry/geography objects rather than assuming how PostGIS is configured.

## Coordinate-System Contract

The working coordinate reference is:

`NAD83 HARN WISCRS Sheboygan County Feet (USft)`

This contract must be preserved when historical or new field data is integrated.

Browser/mobile device GPS normally arrives as latitude/longitude in a different coordinate reference. Any operational Setup workflow must explicitly transform/normalize that device input rather than silently mixing coordinate systems.

## 2026 Launch Reference Maintenance Stopgap

The launch Record Location screen needs a small trusted known-reference set before the long-term #171 GIS maintenance workflow exists.

Until that maintenance/import path is implemented, the accepted launch stopgap is:

```text
ExpertGPS / Garmin authoritative waypoint editing
    -> EPSG:8158 Easting/Northing retained as source authority
    -> deliberate EPSG:8158 -> WGS84 transform
    -> versioned Setup/Application/setup_location_references.json
    -> Record Location known-reference / nearest-reference UI
```

Do not ask the operator to reformat ExpertGPS output into latitude/longitude manually. ExpertGPS exports in the established MSB projected CRS are valid source evidence.

The curated Setup reference file is **not** a replacement GIS database. It exists so launch can use known references while preserving provenance and coordinate authority.

Perform Work's #175 Current Location candidate also consumes this exact versioned
set to describe recorded effective movement coordinates with a nearest waypoint
name/distance. It preserves the raw observation and confirmed named-location
precedence. This is derived presentation, not a new Stage assignment, reference
edit, historical rewrite or claim that the asset is placed at the anchor.
See [the Current Location contract](../12_Setup_and_Deployment/engineering/Setup_Task_Supporting_Information_Contract_2026-09-11.md#effective-current-location--175--dbg-2026-001).

On 2026-10-03 the operator supplied an ExpertGPS correction/export that:

- moved `15-Church-Bells-CH` to the corrected map position; and
- added `15-Church-ParkingLot` as an intentional operational unload/drop reference.

Those source EPSG:8158 coordinates are retained with the transformed WGS84 values used by the browser. Future field observations may improve ranking/operational understanding but must not silently overwrite these curated reference anchors.

A maintainable reference editor/import process is required joint #171/#230 work under the rule above.

## Waypoint Type / Layer Classification Direction

ExpertGPS does not treat every waypoint as the same kind of feature. The source data carries waypoint types/categories, including the operator-confirmed **Stages** type, and the broader file contains multiple other waypoint types.

That classification is operationally valuable because it makes the map easier to layer, filter, and interpret. Future #171 reference/location design should therefore preserve waypoint type/category as first-class source metadata rather than flattening every waypoint into one generic location list.

Required direction:

```text
ExpertGPS waypoint
    -> stable source identity/name
    -> source waypoint type/category
    -> EPSG:8158 reference coordinates
    -> optional transformed WGS84 browser coordinates
    -> application-specific associations/ranking
```

Important boundaries:

- preserve the original ExpertGPS type/category value as source provenance;
- support type-based map layers and filters, such as showing **Stages** separately from other waypoint classes;
- do not equate waypoint type with exclusive Stage ownership;
- a waypoint may be useful to Setup without becoming a Stage, Scene, Display, Container, or Home Location identity;
- if a future normalized internal category is introduced, retain the original ExpertGPS type alongside it rather than replacing the source classification;
- the temporary launch reference JSON may remain a simplified consumption layer, but the long-term #171 maintenance/import path should carry type/category through from the authoritative GIS source.

This classification requirement is especially important because the full ExpertGPS/Garmin source contains many waypoint classes beyond the current launch reference subset. Preserving them will make later GIS/map layering substantially easier and avoid having to infer feature meaning from names after import.

## Operational Asset Overlay Candidate — #171

The V0.3.51 candidate extends the existing Locate map with independent Container
and independent Display layers. GET `/api/setup/locate/assets?season_year=2026`
requires existing Setup read access and returns a no-store snapshot. It reuses
#88 `movement_picture` with optional unobserved Container inventory inside the
same read-only REPEATABLE READ transaction. The report default is unchanged.

Coordinates come only from each state row's `last_movement_event_id`; the map
adapter does not independently search prior history. Missing/invalid coordinates
and RETURNED/storage state remain unlocated. This exposes the gap between the
requested last-valid-GPS continuity and current #88 projections rather than
silently changing the projection. Review C095 against the current clone before
acceptance; any projection repair belongs to #88.

Active WITH_CONTAINER Display associations appear inside Container popups.
DETACHED and NO_ASSIGNED_CONTAINER Displays use their own state event, or remain
unlocated. Expected/reference assignments, recorded position mode and physical
contents are distinct. Icons describe recorded associations: all WITH_CONTAINER
is Loaded, mixed WITH_CONTAINER/DETACHED is Partial, and all DETACHED is Empty.
No assigned active Displays or unsupported modes is Unknown. These categories
do not assert a physical contents inspection; missing Display state still
defaults to WITH_CONTAINER in the owning projection. Historical contents-review flags are shown as
recorded evidence, without claiming they are resolved or still actionable.

Exact coordinate matches share one marker/popup within a layer. Coordinates are
never moved or snapped to Stage anchors. Display artwork is anchored above
Container artwork and given a higher stacking order at shared coordinates. Observation timestamps, GPS feet,
quality/stale-fix evidence, destination notes and capture provenance remain
visible. Refresh clears prior operational markers before requesting new data;
a failed request exposes an unavailable state rather than leaving stale pins.

See [candidate review and limitations](../../../../Setup/Acceptance/Setup_171_Operational_Map_Candidate.md).
This is engineering candidate documentation, not a Production deployment claim.

## Network search candidate — October 9, 2026

Current candidate is reconciled with main `38f6f9427007470cbc02b3e2d23a97450d4414ba`
and preserves the accepted scheduling changes/Production closeout from PR #324/#325.
Use Greg's laptop feature worktree `C:\lor\ImportExport\VSCode-171-map-review`;
its primary main is divergent and must not be reset as a preview preparation step.


PR #318 now has a V0.3.54-gis-network-routes candidate consuming a read-only
draw.io/GPX cross-reference: network groups highlight all segments of every
endpoint-matched route and expose unresolved cables and endpoint conflicts.
43 route candidates use named waypoint anchors and draw.io cable chains; 35
remain unresolved. Exact AUX-I/INET search returns a single network group; raw
GPX routes remain separately discoverable. Dashed highlights currently classify shared-evidence routes as alternatives;
that classification is unsupported and pending correction. These are
operator-review correspondences, not verified reconstructed routes or proof of
continuous connectivity. Existing asset/waypoint search remains available.

[Source inventory, matching rules, confirmed infrastructure facts and resume point](engineering/Network_Source_Reconciliation_2026-10-09.md)
record the current SQL inventory and #319 boundary. Wiring database integration,
editable infrastructure and corrected tester-export reconciliation remain open.

## Deferred Symbol Registry / Type Mapping — #171

Operator-confirmed direction, 2026-10-08: ExpertGPS manages symbols by type
name. In that program the type name is the key and cannot be renamed; changing
it requires deleting and recreating the type. Preserve the exact source type
name during future import/reconciliation rather than treating it as an editable
presentation label. This is reported ExpertGPS behavior, not an implemented MSB
database constraint.

Consider a future reference table mapping feature type and, where applicable,
authoritative operational status to an icon asset path and presentation label.
Keep SVG artwork as separately maintained assets; do not require an icon
assignment on every Container or Display. Preserve source type names separately
if an internal identity or editable display label is introduced. Any type
replacement must deliberately reconcile existing mappings and source references.

For the first operational map overlay, a small replaceable configuration mapping
is sufficient. Greg supplied `container-loaded.svg`, `container-partial.svg`,
`container-empty.svg`, and `container-unknown.svg` (32 × 32 px), and selected the
existing T-Post symbol for independently located Displays. Status symbols must
consume accepted #88 evidence; assigned Display counts alone do not establish
physical load state. Displays WITH_CONTAINER remain in their Container popup
rather than producing overlapping Display pins.

The symbol reference table is deferred design work under #171. It must not delay
functional Container/Display overlays or imply authorization for a Production
schema change. Existing public compatibility symbols remain functional.

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
