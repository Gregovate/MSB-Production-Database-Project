# Network Infrastructure

This subsystem documents the physical network infrastructure used by the MSB production environment, including durable cable/node identity, topology relationships, test history, and integration with site location data.

## Current State

Network engineering information currently exists across Draw.io schematics, CableIQ qualification/test data, GPS waypoint relationships, and historical layout information. This is an existing engineering system distributed across specialized tools and not yet fully integrated into PostgreSQL.

## Design Intent

Preserve specialized tools where they remain useful while moving durable identity, relationships, and history into PostgreSQL.

## Current Responsibilities

- physical cable and node identity
- cable endpoint relationships
- network classification and route information
- CableIQ qualification/test history
- linkage to GPS/site waypoints
- historical infrastructure changes

## Test History Rule

CableIQ retests must not overwrite prior results. Test history is evidence and must remain historically traceable.

## Source Artifacts

Current source material includes:

- Draw.io network schematics with structured cable/topology attributes
- CableIQ original/test export data
- GPS waypoint identities shared with the site model

Both original test evidence and ingestible exports should be preserved where available.

## Related Systems

- [Controller Inventory](../08_Controller_Inventory/README.md)
- [Wiring System](../09_Wiring_System/README.md)
- [Site Infrastructure / GIS](../11_Site_Infrastructure_GIS/README.md)
- [Work Orders](../06_Work_Orders/README.md)

## Resume Development

Inventory current Draw.io, CableIQ, and waypoint data before designing database tables. Establish permanent identities and historical requirements first; do not replace specialized engineering tools merely for architectural uniformity.
