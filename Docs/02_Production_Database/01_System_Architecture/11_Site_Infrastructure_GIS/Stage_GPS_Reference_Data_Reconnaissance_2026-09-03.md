# Stage GPS Reference Data Reconnaissance — 2026-09-03

| Document control | Value |
|---|---|
| Status | CURRENT ENGINEERING RECONNAISSANCE — CRS confirmed; source lineage/database ingestion not yet approved |
| System | Site Infrastructure / GIS |
| Consumer | Setup Session |
| Owner | MSB Technical Team |
| Related Setup issue | [#122 — Engineer annual Setup Session planning, pick-list, movement, and park-location subsystem](https://github.com/Gregovate/MSB-Production-Database-Project/issues/122) |
| Repository baseline reviewed | `main` at `0540d3b702de68d10d78ff8e17e8bca317a9a51f` |

## Purpose

Preserve the 2026-09-03 discovery that a current `2026_Stage_GPS.csv` dataset exists with projected Easting/Northing coordinates for the park Stage/setup destinations needed by the Setup Session.

This document records the dataset structure and Setup/GIS significance established during reconnaissance. It does **not** yet declare the uploaded CSV to be the controlled authoritative source or approve database ingestion.

## Dataset Evidence

A CSV named `2026_Stage_GPS.csv` was supplied during Setup Session engineering reconnaissance.

Direct inspection of the file established:

- 31 rows;
- 31 unique `Label` values;
- every row has `Type = Stage`;
- every row has `Easting` and `Northing` populated;
- no duplicate Labels;
- projected Easting range approximately `209414.369` through `211435.629`;
- projected Northing range approximately `185623.367` through `187818.251`;
- all rows have `Name on GPS` populated;
- `Elevation` is not populated in the supplied CSV;
- the file itself does not contain an explicit CRS identifier field.

Columns present are:

```text
Label
Type
Symbol
Description
Name on GPS
Comment
Easting
Northing
Elevation
Distance to Active Point
Bearing
Distance to Active Point (Pro Data)
Bearing (Pro Data)
```

## Representative Park Destinations

The dataset includes normal Stage destinations such as:

- `04-Food Collection-FC`;
- `08-Elf Choir-EC`;
- `10-Stars-ST`;
- `14-Icicle Tunnel-IT`;
- `17-Candyland-CL`;
- `19-Santa's Workshop-SW`;
- `21-Polar Bear Playground-PB`;
- `25-Racing Arches-RA`;
- `30-Santa's Station-QV`.

It also includes sub-stage/special points such as:

- `03a-Mega Cube-MC`;
- `05a-Mega Star-MS`;
- `07a-Who Forest-WF`;
- `30-Santa's Station Entrance`.

The separate `30-Santa's Station Entrance` point is important evidence that the GIS destination model cannot be assumed to be exactly one coordinate row per `ref.stage` row. A durable park site/location identity may be needed for some operational destinations, with an optional relationship back to the Stage/setup context.

## Coordinate-System Boundary

The current Site Infrastructure / GIS contract defines the project working coordinate reference as:

`NAD83 HARN WISCRS Sheboygan County Feet (USft)`

On 2026-09-03, current field-configuration evidence was supplied showing the active GPS coordinate format selected as:

`NAD83 HARN WISCRS Sheboygan County Feet (US ft)`

The spacing in `US ft` is the application/UI label; it represents the same project working coordinate system documented as `USft` in repository engineering documentation.

This confirms that the current GPS workflow uses the established MSB projected Sheboygan County feet coordinate system. The `2026_Stage_GPS.csv` Easting/Northing values are therefore to be interpreted within that same working coordinate system unless later source-lineage evidence proves otherwise.

The CSV itself still does not embed CRS metadata, so future controlled exports/imports should preserve explicit CRS/source metadata rather than relying on operator memory or application configuration alone.

### Browser / phone / tablet coordinate input

For the browser-based Setup workflow, device coordinates returned through the standard Web Geolocation API are **WGS84** geographic coordinates, not NAD83(HARN) projected coordinates.

Operational device input should therefore be treated as:

```text
WGS84
    -> latitude / longitude
    -> decimal degrees
    -> horizontal accuracy reported in meters
```

The Setup/GIS integration must transform that WGS84 observation into the confirmed MSB working coordinate system before comparing it to Stage/site Easting/Northing reference coordinates:

```text
phone / tablet WGS84 latitude-longitude
    -> controlled coordinate transformation
        -> NAD83 HARN WISCRS Sheboygan County Feet (US ft)
            -> compare against reference Easting/Northing
```

This is a datum/projection transformation, not merely a unit conversion from meters to feet. Preserve the original WGS84 device observation and its reported accuracy as operational evidence; do not overwrite it with only the transformed result.

## Setup Session Significance

The Setup Session now has evidence for both sides of the park movement problem:

```text
selected Setup work
    -> resolve required Displays / KITs / Containers

and

selected Setup work
    -> resolve intended park Stage/setup destination
        -> reference GIS coordinate/site identity
```

This creates the future ability to answer:

- where the Stage/setup area is expected to be;
- where a Container/Display was last observed by a phone/tablet;
- how far that observation is from the intended destination;
- whether the device accuracy is good enough to make the comparison meaningful.

The Setup Session owns the business event such as delivered, relocated, or placed. Site Infrastructure / GIS owns the reference spatial identity/coordinates and spatial calculations.

## Reference Coordinates Versus Operational GPS

The supplied Stage GPS data should be treated as candidate **reference destination data**, not as the same thing as device observations captured during Setup.

Keep these classes separate:

```text
reference Stage/site coordinates
    -> durable expected destination

phone/tablet GPS observation
    -> WGS84 latitude/longitude
    -> timestamped operational evidence
    -> includes device accuracy where available

transformed operational coordinate
    -> derived projected coordinate for comparison

proximity result
    -> derived comparison between observation and reference destination
```

A phone/tablet observation must never silently overwrite the reference Stage/site coordinate.

## Identity Reconciliation Requirement

Do not parse the `Label` string and assume that every row is a direct `ref.stage` foreign key.

Before ingestion:

1. inventory current `ref.stage` identities and keys;
2. identify which CSV rows map directly to a Stage/Sub-stage;
3. identify which rows represent special operational destinations rather than distinct Stage rows;
4. create or reuse durable site/location identities where required;
5. preserve the human-readable GPS label and source naming for traceability;
6. avoid introducing a second competing Stage identity.

## Required Source Verification

Before this dataset becomes authoritative PostgreSQL reference data, establish:

1. which tool/source produced `2026_Stage_GPS.csv`;
2. whether the coordinates came directly from Garmin, ExpertGPS, county-imagery refinement, or another controlled process;
3. whether these are intended Stage center/reference points, setup anchor points, or another operational point definition;
4. who/what owns future coordinate correction;
5. whether the 2026 file supersedes or supplements older GPX/waypoint data.

The coordinate-system question is no longer open: current field configuration confirms `NAD83 HARN WISCRS Sheboygan County Feet (US ft)` for the reference Stage/site data, while browser/mobile Geolocation input is WGS84 latitude/longitude and requires controlled transformation for projected-coordinate comparison.

## 2026 Setup MVP Direction

The existence of this dataset means Setup Session does **not** need to invent Stage destination coordinates from live phone GPS.

For the first production workflow:

- use durable Stage/site reference data once reconciled and approved;
- use phone/tablet WGS84 GPS only as operational observation evidence;
- preserve the original device latitude/longitude, observation time, and reported accuracy;
- transform mobile WGS84 latitude/longitude explicitly into the confirmed project working coordinate system where a projected-coordinate comparison is performed;
- do not require exact surveyed accuracy to begin tracking where assets were last seen;
- do not mark an asset delivered/placed solely because its device coordinate is near the Stage reference point;
- keep the GIS integration narrow enough to fit the two-week Setup Session implementation window.

## Related Documents

- [Site Infrastructure / GIS](README.md)
- [Setup Session](../12_Setup_and_Deployment/Setup_Session/README.md)
- [Setup Session Engineering Reconnaissance](../12_Setup_and_Deployment/Setup_Session/engineering/Setup_Session_Engineering_Reconnaissance_2026-09-03.md)
- [Scan Workflows and Forklift Operations](../07_Labeling_and_Scanning/Scan_Workflows_and_Forklift_Operations.md)
- [#122 — Setup Session engineering issue](https://github.com/Gregovate/MSB-Production-Database-Project/issues/122)
