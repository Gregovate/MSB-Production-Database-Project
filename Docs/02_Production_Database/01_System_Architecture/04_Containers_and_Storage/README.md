# Containers and Storage

This subsystem documents physical container identity, display-to-container relationships, storage locations, container state, and the operational data needed before container-based testing or deployment can occur.

## Current State

Containers and storage locations are active Production Database entities used by operational workflows and Directus views/bookmarks.

A container is a physical storage/deployment unit. Some containers hold Displays. A container may also have type **KIT**, meaning it contains loose setup materials rather than Displays, such as cords, plugs, string lights, bull line, stakes, hardware, or other supplies needed to set up displays. The KIT type already exists; detailed kit-contents inventory is not currently engineered or documented and is not part of this audit.

Storage locations include precise rack locations and broader zone/bucket locations. The current location model is primarily the container's home/intended storage location rather than a generic movement-history system.

## Design Intent

Provide durable answers to:

- what physical container is being referenced;
- where a container belongs in storage;
- which displays are currently associated with a container;
- what physical state is required before testing and deployment workflows proceed.

Current state should stay on the owning record unless a workflow genuinely needs reconstructable history. The system does not need generic container movement history or full display-to-container assignment history merely because current assignments change.

## Dependencies

- [Database Foundation](../01_Database_Foundation/README.md)
- [LOR2DB Ingest](../02_LOR2DB_Ingest/README.md) for display data entering the Production Database
- [People and Identity](../03_People_and_Identity/README.md) for authenticated operational activity and audit attribution

## Current Implementation

Current implementation includes PostgreSQL reference/operational data plus Directus presentation, bookmarks, and operational views. Detailed table/field/constraint names must be verified against the current schema snapshot before engineering changes.

Container and storage behavior includes these current practical rules and limitations:

- not all storage slots have complete physical dimensions recorded;
- some containers require specific locations because of their size;
- floor/rack space may sometimes be shareable or stackable;
- additional/manual storage locations have sometimes been created when more than one container can fit a physical slot or when containers can be stacked;
- incomplete dimensions prevent reliable automated fit/capacity decisions today.

These are known operational limitations to preserve for future engineering rather than assumptions to hide in a generic movement-history model.

## Related Systems

- [Testing System](../05_Testing_System/README.md)
- [Labeling and Scanning](../07_Labeling_and_Scanning/README.md)
- [Setup and Deployment](../12_Setup_and_Deployment/README.md)
- [Operational SOPs](../../02_Operational_SOPs/README.md)

## Known Open Work

- document the current storage-location field/constraint model from the schema snapshot;
- document current handling of shared/stackable/oversize storage locations;
- determine whether container dimensions and location dimensions should support future fit/capacity checks;
- leave KIT contents inventory as a future operational need until the real workflow is ready to be engineered;
- keep temporary setup/deployment movement events with the Setup and Deployment workflow rather than creating a generic container-movement history system.

## Resume Development

Inspect the current PostgreSQL container/storage structures and real storage workflow before changing this subsystem. Use the newest schema snapshot for exact object names. Do not reconstruct the old pallet/history model from the archived database-structure document.
