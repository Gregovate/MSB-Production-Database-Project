# Functions and Procedures

This folder is the canonical engineering index for PostgreSQL functions and stored procedures implemented in the MSB Production Database.

## Documentation Ownership Rule

Database-level functions and procedures are documented here so there is one predictable place to find them as the system evolves.

Subsystem documentation such as Testing, Work Orders, People and Identity, Containers and Storage, or Setup and Deployment should link to the relevant document here rather than keep a second authoritative copy.

This includes functions and procedures that support one business workflow when the database object itself is part of the shared Production Database implementation.

Standalone systems may keep their own implementation artifacts when those artifacts are owned by that standalone system. LOR2DB is the primary example: its parser, reconciliation, promotion, validation, and reporting artifacts remain with the LOR2DB subsystem/repository.

## Current Documents

- [P_Refresh_Test_Session](P_Refresh_Test_Session.md)
- [P_Cleanup_Recycled_Standalone_Display](P_Cleanup_Recycled_Standalone_Display.md)

## Shared Database Examples

Examples of database-level objects that belong in this area include:

- audit and actor-attribution helpers;
- `ref.person` / Directus identity lookup and mapping helpers;
- shared integrity and lifecycle procedures;
- database procedures used by multiple user interfaces or operational systems.

## Authoritative Source

The live PostgreSQL function/procedure definition is implementation truth. These documents explain purpose, business contract, dependencies, and operational relationships without replacing the executable SQL definition.

## Related Documentation

- [Database Foundation](../README.md)
- [Triggers](../02_Triggers/README.md)
- [Production Database Architecture](../../README.md)
