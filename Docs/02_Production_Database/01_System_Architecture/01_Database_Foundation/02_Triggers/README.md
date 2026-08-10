# Database Triggers

This folder is the canonical engineering index for PostgreSQL triggers implemented in the MSB Production Database.

## Documentation Ownership Rule

Database-level triggers are documented here so there is one predictable place to find them as the system evolves.

Subsystem documentation should link to the relevant trigger document here rather than keep a second authoritative copy. The business workflow may belong to Testing, Work Orders, People and Identity, or another subsystem, but the PostgreSQL trigger documentation remains centralized under Database Foundation.

Standalone systems may keep their own implementation artifacts when those artifacts are owned by that standalone system rather than the shared Production Database. LOR2DB is the primary example.

## Trigger Design Rule

Triggers should remain lightweight when practical. Their responsibility is normally to detect a database event, enforce a narrow integrity rule, stamp required database-owned values, or invoke the appropriate function/procedure. Larger business logic should remain in clearly documented functions/procedures where practical.

## Current Documents

- [T_After_Refresh_Test_Session](T_After_Refresh_Test_Session.md)

## Shared Database Examples

Examples that belong in this centralized area include:

- audit/actor stamping triggers;
- Directus-to-`ref.person` attribution triggers or helpers;
- shared lifecycle and integrity triggers;
- workflow entry-point triggers that invoke documented Production Database procedures.

## Authoritative Source

The live PostgreSQL trigger definition is implementation truth. These documents explain event, conditions, invoked logic, purpose, and dependencies.

## Related Documentation

- [Database Foundation](../README.md)
- [Functions and Procedures](../01_Functions_and_Procedures/README.md)
- [Production Database Architecture](../../README.md)
