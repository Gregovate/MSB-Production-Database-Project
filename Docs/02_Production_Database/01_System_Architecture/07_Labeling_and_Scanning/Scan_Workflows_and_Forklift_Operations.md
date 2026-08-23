# MSB Scan Workflows and Forklift Operations

| Document control | Value |
|---|---|
| Status | CURRENT PLANNING BASELINE — Setup/Deployment engineering pending |
| Current revision | 2026-08-22 |

## Purpose

This document defines the intended operational use of scanning for Container retrieval, storage validation, Setup/Deployment movement, and field placement.

It deliberately distinguishes **workshop/rack scanning** from **park/GPS placement**. Both environments use permanent Production Database identities, but they do not need identical location-capture methods.

## Core Workflow Principle

Scanning identifies the asset or discrete location. The application then resolves the current Production Database record and workflow context.

Do not put transient setup state, annual load numbers, or application-specific URLs into the physical label.

## Workshop / Rack Location Model

Workshop storage already uses precise rack locations and broader storage locations in the Production Database.

Expected high-volume shop input:

```text
Zebra DS3678-HD
    -> CONT:<container_id>
    -> LOC:<storage location code>
    -> Setup/Storage browser workflow
```

The purchased Zebra DS3678-HD is intended primarily for the workshop forklift. Its HID keyboard input should allow rapid browser scanning without camera use.

### Container retrieval

1. Operator scans a Container.
2. System resolves the Container and displays its expected/home storage location plus current Setup context.
3. Operator retrieves/stages the Container according to the active workflow.

### Location lookup

1. Operator scans a rack/storage Location.
2. System displays the expected Container(s) or location state.
3. Operator verifies the physical condition against the database.

### Placement validation

1. Operator scans a Location and Container, in either order when the workflow allows it.
2. The application retains temporary scan-session state.
3. The application validates the expected relationship.
4. The operator receives immediate match/mismatch guidance.
5. Any operational state change is recorded only when the Setup/Storage workflow defines that event.

Do not create generic movement history merely because two scans occurred.

## Park / Geospatial Location Model

Park destinations are expected to be materially different from workshop rack locations.

Likely field interaction:

```text
Display or Container QR
    -> permanent asset identity
        + GPS / mapped site-location context
            -> expected park destination validation
```

The park should not be forced into a physical `LOC:` barcode model at every destination simply because shop racks use location labels.

### Durable site location versus GPS coordinates

A park destination should have a durable Production Database/site identity when the Setup/GIS design requires one.

GPS coordinates are spatial evidence associated with that identity. Raw latitude/longitude should not become the permanent business key.

This matters because:

- surveyed coordinates can be refined later;
- device GPS readings vary;
- seasonal placement tolerances may differ by Display/location;
- historical movement/placement can remain associated with the same site identity even when coordinates are corrected.

### GPS roles that must be distinguished

Setup/GIS engineering should distinguish at least:

- **authoritative/reference coordinates** — surveyed/validated location data, potentially from Garmin/ExpertGPS/GIS sources;
- **operator device coordinates** — phone/tablet GPS captured during Setup as approximate operational evidence;
- **validation result** — whether the operator/asset is sufficiently close to the expected destination for the workflow.

Do not treat a consumer-device GPS fix as equivalent to surveyed site data merely because both are coordinates.

## PostgreSQL / PostGIS Direction

Production PostgreSQL has geospatial/PostGIS capability available, but the Setup/GIS operational workflow is not currently implemented.

Before schema or application work:

1. verify the exact installed PostGIS extension/version and existing geometry/geography objects;
2. inventory existing storage-location structures;
3. inventory the historical GPX/ExpertGPS/site data;
4. define durable park location identity;
5. decide whether operational validation uses `geometry`, `geography`, or another controlled representation;
6. define acceptable-distance/tolerance rules from real field requirements.

Do not design the park workflow around raw coordinate columns without reviewing the existing GIS contract.

## Scan Order and Session State

Workshop workflows may require either:

```text
Location -> Container
```

or:

```text
Container -> Location
```

The application may therefore need short-lived scan-session state.

Park workflows may instead look more like:

```text
Container/Display scan
    -> expected destination
    -> current GPS context
    -> validate / confirm
```

These are separate interaction patterns over the same underlying permanent identities. The scan platform should support both without forcing one workflow into the other's UX.

## Operator Feedback Requirements

Feedback must be immediate and unambiguous.

Workshop/forklift screens should favor:

- large text;
- high contrast;
- minimal screen touches;
- automatic reset/advance after accepted scans where safe;
- clear expected rack/location;
- obvious mismatch warnings.

Park/mobile screens should favor:

- readable asset/destination identity;
- expected versus current location context;
- map/GPS guidance only where it adds operational value;
- clear indication when GPS accuracy is insufficient;
- confirmation that does not require operators to interpret raw coordinates.

## Safety Considerations

Scanner/application design must minimize operator distraction.

The workshop system should not require the forklift operator to manipulate a touchscreen after every scan. The park system should not encourage device interaction while driving or operating equipment.

## Network Dependence

Real-time Production Database validation requires network connectivity.

Workshop coverage must include racks, staging, and loading areas. Park coverage requirements must be evaluated separately.

Offline behavior may become necessary in the park if network coverage is not dependable, but offline state synchronization must be deliberately engineered rather than added as an uncontrolled cache.

## Current Hardware Boundary

- **Workshop:** Zebra DS3678-HD plus rugged tablet/workstation; HID keyboard input is the preferred baseline.
- **Park:** rugged phone/tablet camera scanning plus GPS/site context is the likely baseline.
- A future ER/XR scanner may be justified for a specific long-range shop/field task, but the current DS3678-HD is not being treated as the universal scanning device.

See [Scanner Hardware and Tablet Integration](Scanner_Hardware_and_Tablet_Integration.md).

## Integration with Label Standards

Permanent machine-readable payloads identify the object:

```text
DISP:<display_id>
CONT:<container_id>
LOC:<location_code>
```

A `LOC:` label is appropriate for discrete labeled locations such as workshop rack positions. A park destination may be resolved through a durable GIS/site identity and GPS context without requiring a barcode mounted at every physical point.

## Known Open Work

- reconstruct the real 2026 Setup pull/stage/load/delivery process;
- document when a Container scan should cause a database state change versus lookup only;
- document current rack-location identifiers and relationships;
- define the Setup scan-session state machine only after field workflow review;
- test the DS3678-HD against actual shop Container/rack labels;
- define park durable location identity with Site Infrastructure/GIS;
- verify current PostGIS capability and existing database objects before schema changes;
- determine field GPS source/accuracy requirements;
- define expected-destination proximity/tolerance rules;
- evaluate park network coverage and offline requirements.

## Resume Development

After the FieldWiring Scan Integration closes, begin Setup/Deployment engineering by interviewing/documenting the real people/process flow. Then reconcile that workflow against:

1. current Container and Storage Location database structures;
2. existing rack-location design;
3. current scan platform and permanent payload standard;
4. the purchased Zebra workshop scanner;
5. Site Infrastructure/GIS and historical GPS data;
6. verified PostgreSQL/PostGIS capability.

Do not start by creating movement tables or GPS columns.

## Related Documents

- [Labeling and Scanning](README.md)
- [Scanner Hardware and Tablet Integration](Scanner_Hardware_and_Tablet_Integration.md)
- [Asset Identity and Scan Payload Standard](Asset_Identity_and_Scan_Payload_Standard.md)
- [Containers and Storage](../04_Containers_and_Storage/README.md)
- [Setup and Deployment](../12_Setup_and_Deployment/README.md)
- [Site Infrastructure / GIS](../11_Site_Infrastructure_GIS/README.md)
