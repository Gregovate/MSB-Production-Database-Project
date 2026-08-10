# Production Database System Architecture

This area contains the engineering design for the PostgreSQL Production Database and the operational systems built on it or consuming it.

The numbered subsystem tree follows the logical data/dependency flow of the current Production Database. It is not a chronology of old documents and does not preserve obsolete systems merely because they existed during development.

Operator procedures and manuals remain separate under [Operational SOPs](../02_Operational_SOPs/README.md).

Repository boundaries do not determine data authority. Dedicated applications and services may live in separate repositories while PostgreSQL, LOR, or another explicitly documented source remains authoritative. See the [System Boundary and Repository Ownership Standard](../../../System_Documentation/Standards/System_Boundary_and_Repository_Ownership_Standard.md).

## Start Here

| I want to... | Go to |
|---|---|
| Understand shared PostgreSQL architecture and database-wide contracts | [01 — Database Foundation](01_Database_Foundation/README.md) |
| Understand how LOR data enters PostgreSQL | [02 — LOR2DB Ingest](02_LOR2DB_Ingest/README.md) |
| Understand user onboarding, identity, roles, and audit attribution | [03 — People and Identity](03_People_and_Identity/README.md) |
| Understand containers, display storage, KIT containers, and physical locations | [04 — Containers and Storage](04_Containers_and_Storage/README.md) |
| Understand container/display testing | [05 — Testing System](05_Testing_System/README.md) |
| Understand Work Order intake, assignment, repair, and completion | [06 — Work Orders](06_Work_Orders/README.md) |
| Understand labels, QR/barcodes, printing, and scanning | [07 — Labeling and Scanning](07_Labeling_and_Scanning/README.md) |
| Understand physical controller inventory | [08 — Controller Inventory](08_Controller_Inventory/README.md) |
| Understand wiring presentation and LOR topology integration | [09 — Wiring System](09_Wiring_System/README.md) |
| Understand physical network infrastructure and cable-test history | [10 — Network Infrastructure](10_Network_Infrastructure/README.md) |
| Understand GPS/GIS, receptacles, power, and site infrastructure | [11 — Site Infrastructure / GIS](11_Site_Infrastructure_GIS/README.md) |
| Understand Stage-based setup/takedown documentation and planned deployment workflow | [12 — Setup and Deployment](12_Setup_and_Deployment/README.md) |
| Review project effort and estimated engineering hours | [90 — Project Hour Log](90_Project%20Hour%20Log/README.md) |

## Architecture Flow

The current high-level dependency/data flow is:

`PostgreSQL foundation -> LOR2DB ingest -> People/Identity -> Containers/Storage -> Testing -> Work Orders -> Labeling/Scanning`

Setup and Deployment is now active as a documentation area using the existing Stage folder/path convention, while most scheduling, pick-list, load-order, and forklift-scanning engineering remains planned. It will consume tested/ready inventory, container/storage relationships, identity, and scanning capabilities to control movement from storage to the park.

Controller Inventory, Wiring, Network Infrastructure, and Site Infrastructure/GIS extend the same permanent-identity and history model into the physical production environment.

LOR remains authoritative for show topology and wiring configuration. LOR2DB is the controlled bridge that brings LOR-derived data into PostgreSQL. PostgreSQL and downstream applications may store, reconcile, enrich, present, and operationally use that data without independently redefining LOR controller/channel/network topology.

## Application and Repository Boundaries

The Production Database is intentionally allowed to have dedicated applications and services in separate repositories. The important rule is to preserve the authority and dependency contract.

Current relationship patterns include:

- **Integrated upstream dependency — LOR/LOR2DB:** the Production Database relies on controlled LOR-derived data. LOR remains authoritative for show topology and wiring configuration.
- **Core database subsystem with dedicated operational UI — Work Orders:** PostgreSQL owns Work Order identities, relationships, lifecycle, and business rules. A separate task-focused Work Order application may replace inadequate Directus workflows without creating another Work Order database.
- **Database-backed presentation/field application — Wiring:** a future dedicated Wiring application should consume PostgreSQL rather than a separate SQLite operational copy. LOR remains upstream topology authority through LOR2DB.
- **External supporting subsystem — LabelPrintService:** consumes Production Database information to produce labels. It has its own repository and dedicated print server. If it is unavailable, printing stops but the Production Database remains authoritative and usable.
- **Setup and Deployment:** Stage-based setup/takedown documentation is active now in the existing Stage folder structure; the future scheduling/deployment workflow remains PostgreSQL-owned and may initially use Directus, with a dedicated field/scanning UI only if required.

This model allows application development to remain isolated from the Production Database repository without fragmenting system ownership.

## Subsystem Guide

| Subsystem | Engineering responsibility |
|---|---|
| [01_Database_Foundation](01_Database_Foundation/README.md) | Shared PostgreSQL identities, schema boundaries, audit/history/lifecycle rules, integrity, schema-snapshot verification, and the canonical index for Production Database functions/procedures/triggers |
| [02_LOR2DB_Ingest](02_LOR2DB_Ingest/README.md) | Production Database dependency on the separate LOR2DB parser/ingest/reconciliation project |
| [03_People_and_Identity](03_People_and_Identity/README.md) | Person identity, authentication linkage, Directus users/roles, onboarding, actor attribution |
| [04_Containers_and_Storage](04_Containers_and_Storage/README.md) | Containers, KIT container identity, display assignment, storage locations, and current physical storage state |
| [05_Testing_System](05_Testing_System/README.md) | Test sessions, display testing, repair outcomes, testing lifecycle, and links to the PostgreSQL objects that implement the workflow |
| [06_Work_Orders](06_Work_Orders/README.md) | Intake, triage, assignment, notifications, repair linkage, completion, and dedicated application boundary |
| [07_Labeling_and_Scanning](07_Labeling_and_Scanning/README.md) | Permanent labels, LabelPrintService integration, QR/barcodes, scanner hardware, scan workflows, and QR routing to subsystem-owned field information |
| [08_Controller_Inventory](08_Controller_Inventory/README.md) | Permanent physical controller identity, inventory, lifecycle, deployment/history |
| [09_Wiring_System](09_Wiring_System/README.md) | Wiring presentation, PostgreSQL-backed field application, shared Stage folder/path convention, and LOR-authoritative topology integration |
| [10_Network_Infrastructure](10_Network_Infrastructure/README.md) | Physical network cables/nodes, CableIQ history, structured topology relationships |
| [11_Site_Infrastructure_GIS](11_Site_Infrastructure_GIS/README.md) | GPS/GIS, receptacles, power/site assets, physical-location history |
| [12_Setup_and_Deployment](12_Setup_and_Deployment/README.md) | Existing Stage-based setup/takedown documentation plus planned setup season/session, pull scheduling, pick/load lists, repeatable load order, forklift scanning, and deployment history |
| [90_Project Hour Log](90_Project%20Hour%20Log/README.md) | Milestone-level engineering effort, historical hour estimates, and board-reporting support |

## Documentation Ownership Rules

- This tree is the engineering side of the Production Database documentation.
- Procedures/manuals belong under [Operational SOPs](../02_Operational_SOPs/README.md), even when they operate one of the systems above.
- Directus is a shared implementation platform, not a top-level business subsystem. Business-specific Directus Flows are documented with the subsystem whose process they implement.
- Dedicated application/service projects may maintain their own implementation repositories. The responsible subsystem README here documents how that project fits into Production Database architecture, what data it consumes or changes, and where authority remains.
- A separate application repository must not create a competing source of truth merely because a task-focused UI is needed.
- **Production Database functions, procedures, and triggers have one canonical documentation home under [01 — Database Foundation](01_Database_Foundation/README.md).** Business subsystems link to those documents instead of maintaining scattered authoritative copies.
- Shared/cross-system objects such as audit helpers, actor attribution, Directus-to-`ref.person` mapping, integrity helpers, and lifecycle logic must be indexed there so they remain discoverable as systems evolve.
- Standalone systems may keep implementation-specific artifacts with the standalone system when those artifacts are not shared Production Database objects. LOR2DB is the primary example.
- Current implementation details must be verified against the newest schema snapshot and/or live system rather than legacy design documents.
- Project-hour reporting uses milestone-level estimated effort rather than pretending that reconstructed history is a precise timecard. See [90 — Project Hour Log](90_Project%20Hour%20Log/README.md).

## Legacy Architecture Cleanup

The previous competing top-level numbered folders (`01_Stored_Proceedures` through `06_Scan_Workflows_and_Forklift_Operations`) have been migrated out of the active top-level tree. Centralized replacements for Production Database functions/procedures and triggers now live under [01 — Database Foundation](01_Database_Foundation/README.md), while business subsystem documentation links back to those canonical object documents.

The legacy `A_System_Blueprint.md` has been reconciled into the current [Production Database System Overview](../../00_Project_Overview/01_Production_Database_System_Overview.md) and archived as engineering history.

The legacy LOR naming contract has been moved into [LOR Preview Authoring](../../01_LOR_System/01_Preview_Authoring/README.md), where its February 2026 origin is preserved as historical engineering context while the current Naming Conventions remain authoritative.

The legacy Directus MVP documents `E_Directus_DB_Dev.md` and `F_Directus_UI_md` have been archived after their still-relevant responsibilities were assigned to the current business subsystems and Directus was documented as a shared implementation platform rather than a top-level subsystem.

The legacy `G_Work_Order_Design_Plan.md` has been reconciled into [06 — Work Orders](06_Work_Orders/README.md) and archived. The legacy `H_Asset_ID_Labeling_and_Scanning_Plan.md` has been reconciled into [07 — Labeling and Scanning](07_Labeling_and_Scanning/README.md) and archived.

The legacy `D_Database_Structure.md` has now been fully reconciled into the current numbered subsystem architecture and removed from the active tree. Its historical reconciliation record is preserved at [`archive/architecture/D_Database_Structure.md`](../../../../archive/architecture/D_Database_Structure.md), while the complete original remains available in Git history.

One loose legacy architecture document remains active during the audit:

- `B_Infrastructure.md` — retained until the Database audit is complete; server build/administration material is marked for later reconciliation in the separate `MSB-Server-Management` repository.

Historical material is archived only after current responsibilities have an authoritative owner.
