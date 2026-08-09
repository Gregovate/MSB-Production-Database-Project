# Site Infrastructure / GIS

This subsystem documents permanent physical-site identities, location history, power/site infrastructure relationships, and future PostgreSQL integration of MSB GIS/GPS data.

## Current State

Substantial historical field/site information exists outside PostgreSQL, including GPX data going back to at least 2015, waypoints and tracks, receptacles, network tracks, power tracks, utility meters, distribution panels, circuit identifiers, and seasonal energization requirements.

Field collection uses a Garmin GPSMAP 66sr. ExpertGPS and county aerial imagery are used for validation/refinement.

## Coordinate-System Contract

The working coordinate reference is:

`NAD83 HARN WISCRS Sheboygan County Feet (USft)`

This contract must be preserved when historical or new field data is integrated.

## Design Intent

PostgreSQL should provide durable identity, relationships, and history for physical site infrastructure while preserving useful survey/GIS tools for collection and visualization.

## Identity Requirement

Historical display/location data does not consistently use the Production Database permanent `display_id`. Future integration must reconcile to permanent Production Database identities rather than introduce another competing identity.

## Current/Future Responsibilities

- permanent site/location identities
- GPS waypoints and track history
- receptacles and power infrastructure
- utility meters, panels, and circuits
- seasonal energization requirements
- relationships to Network Infrastructure, Wiring, Controller Inventory, Displays, and Work Orders

## Related Systems

- [Network Infrastructure](../10_Network_Infrastructure/README.md)
- [Controller Inventory](../08_Controller_Inventory/README.md)
- [Wiring System](../09_Wiring_System/README.md)
- [Work Orders](../06_Work_Orders/README.md)

## Resume Development

Do not design the GIS database schema from assumptions. First inventory the existing GPX/ExpertGPS data, waypoint conventions, power/site records, coordinate-system usage, and cross-links to Network Infrastructure and Production Database identities.
