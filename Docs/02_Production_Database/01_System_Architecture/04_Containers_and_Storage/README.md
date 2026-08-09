# Containers and Storage

This subsystem documents physical container identity, display-to-container relationships, storage locations, container movement/state, and the operational data needed before container-based testing can occur.

## Current State

Containers and storage locations are active Production Database entities used by operational workflows and Directus views/bookmarks.

## Design Intent

Provide durable answers to:

- what is stored on each container;
- where a container belongs and where it is currently located;
- which displays are associated with a container;
- what physical state is required before testing and deployment workflows proceed.

## Dependencies

- [Database Foundation](../01_Database_Foundation/README.md)
- [LOR2DB Ingest](../02_LOR2DB_Ingest/README.md) for display data entering the Production Database
- [People and Identity](../03_People_and_Identity/README.md) for authenticated operational activity and audit attribution

## Current Implementation

Current implementation includes PostgreSQL reference/operational data plus Directus presentation, bookmarks, and operational views. Business-specific database procedures, triggers, and Directus flows should be documented here when they implement container/storage behavior.

## Related Systems

- [Testing System](../05_Testing_System/README.md)
- [Labeling and Scanning](../07_Labeling_and_Scanning/README.md)
- [Operational SOPs](../../02_Operational_SOPs/README.md)

## Known Open Work

Reconcile current container/storage schema and workflow documentation from the legacy architecture documents into this subsystem, then update this README with authoritative object names and current limitations.
