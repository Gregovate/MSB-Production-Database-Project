# Network Infrastructure

This subsystem documents the physical network infrastructure used by the MSB production environment, including durable cable/node identity, topology relationships, test history, and integration with site location data.

## Current State

Network engineering information currently exists across Draw.io schematics, CableIQ qualification/test data, GPS waypoint relationships, and historical layout information. This is an existing engineering system distributed across specialized tools and not yet fully integrated into PostgreSQL.

## Design Intent

The database-backed application is the required reference editor under unfinished
#230, with #171 owning GIS/infrastructure reconciliation. Maintain physical cable,
waypoint, network and device reference identities/relationships in governed ref
tables; preserve tests and observations as separate evidence/history.
Follow the [required editing-authority rule](../11_Site_Infrastructure_GIS/README.md#required-reference-data-editing-authority--171--230).
External tools remain collection/interchange/presentation tools after accepted
cutover, not competing editable masters.

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

## October 9 engineering resume point

[Current source reconciliation](../11_Site_Infrastructure_GIS/engineering/Network_Source_Reconciliation_2026-10-09.md)
preserves the supplied draw.io and SQL hashes, legacy-edge gaps, endpoint conflicts,
confirmed ownership/alias rules and the candidate map cross-reference boundary.
PR #318 provides read-only network search; draft PR #319 owns CableIQ validation.
Neither implements the physical inventory database or editable Wiring integration.

## Resume Development

Inventory current Draw.io, CableIQ, and waypoint data before designing database tables. Establish permanent identities and historical requirements first; do not replace specialized engineering tools merely for architectural uniformity.
