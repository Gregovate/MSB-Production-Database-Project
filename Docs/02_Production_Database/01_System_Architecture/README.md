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
| Understand containers, display storage, and physical locations | [04 — Containers and Storage](04_Containers_and_Storage/README.md) |
| Understand container/display testing | [05 — Testing System](05_Testing_System/README.md) |
| Understand Work Order intake, assignment, repair, and completion | [06 — Work Orders](06_Work_Orders/README.md) |
| Understand labels, QR/barcodes, printing, and scanning | [07 — Labeling and Scanning](07_Labeling_and_Scanning/README.md) |
| Understand physical controller inventory | [08 — Controller Inventory](08_Controller_Inventory/README.md) |
| Understand wiring presentation and LOR topology integration | [09 — Wiring System](09_Wiring_System/README.md) |
| Understand physical network infrastructure and cable-test history | [10 — Network Infrastructure](10_Network_Infrastructure/README.md) |
| Understand GPS/GIS, receptacles, power, and site infrastructure | [11 — Site Infrastructure / GIS](11_Site_Infrastructure_GIS/README.md) |
| Understand planned setup scheduling, pick lists, load order, and deployment scanning | [12 — Setup and Deployment](12_Setup_and_Deployment/README.md) |

## Architecture Flow

The current high-level dependency/data flow is:

`PostgreSQL foundation -> LOR2DB ingest -> People/Identity -> Containers/Storage -> Testing -> Work Orders -> Labeling/Scanning`

Setup and Deployment is a planned downstream operational subsystem that will consume tested/ready inventory, container/storage relationships, identity, and scanning capabilities to schedule and control movement from storage to the park.

Controller Inventory, Wiring, Network Infrastructure, and Site Infrastructure/GIS extend the same permanent-identity and history model into the physical production environment.

LOR remains authoritative for show topology and wiring configuration. LOR2DB is the controlled bridge that brings LOR-derived data into PostgreSQL. PostgreSQL and downstream applications may store, reconcile, enrich, present, and operationally use that data without independently redefining LOR controller/channel/network topology.

## Application and Repository Boundaries

The Production Database is intentionally allowed to have dedicated applications and services in separate repositories. The important rule is to preserve the authority and dependency contract.

Current relationship patterns include:

- **Integrated upstream dependency — LOR/LOR2DB:** the Production Database relies on controlled LOR-derived data. LOR remains authoritative for show topology and wiring configuration.
- **Core database subsystem with dedicated operational UI — Work Orders:** PostgreSQL owns Work Order identities, relationships, lifecycle, and business rules. A separate task-focused Work Order application may replace inadequate Directus workflows without creating another Work Order database.
- **Database-backed presentation/field application — Wiring:** a future dedicated Wiring application should consume PostgreSQL rather than a separate SQLite operational copy. LOR remains upstream topology authority through LOR2DB.
- **External supporting subsystem — LabelPrintService:** consumes Production Database information to produce labels. It has its own repository and dedicated print server. If it is unavailable, printing stops but the Production Database remains authoritative and usable.
- **Planned Directus-managed operational subsystem — Setup and Deployment:** PostgreSQL will remain authoritative for deployment scheduling/history. Directus is expected to provide the initial management interface, with a dedicated field/scanning UI only if required by forklift operations.

This model allows application development to remain isolated from the Production Database repository without fragmenting system ownership.

## Subsystem Guide

| Subsystem | Engineering responsibility |
|---|---|
| [01_Database_Foundation](01_Database_Foundation/README.md) | Shared PostgreSQL identities, schema boundaries, audit rules, integrity, shared database-wide mechanisms |
| [02_LOR2DB_Ingest](02_LOR2DB_Ingest/README.md) | Production Database dependency on the separate LOR2DB parser/ingest/reconciliation project |
| [03_People_and_Identity](03_People_and_Identity/README.md) | Person identity, authentication linkage, Directus users/roles, onboarding, actor attribution |
| [04_Containers_and_Storage](04_Containers_and_Storage/README.md) | Containers, display assignment, storage locations, physical state/history |
| [05_Testing_System](05_Testing_System/README.md) | Test sessions, display testing, repair outcomes, testing lifecycle, testing-specific procedures/triggers |
| [06_Work_Orders](06_Work_Orders/README.md) | Intake, triage, assignment, notifications, repair linkage, completion, and dedicated application boundary |
| [07_Labeling_and_Scanning](07_Labeling_and_Scanning/README.md) | Permanent labels, LabelPrintService integration, QR/barcodes, scanner hardware, scan workflows |
| [08_Controller_Inventory](08_Controller_Inventory/README.md) | Permanent physical controller identity, inventory, lifecycle, deployment/history |
| [09_Wiring_System](09_Wiring_System/README.md) | Wiring presentation, PostgreSQL-backed field application, and LOR-authoritative topology integration |
| [10_Network_Infrastructure](10_Network_Infrastructure/README.md) | Physical network cables/nodes, CableIQ history, structured topology relationships |
| [11_Site_Infrastructure_GIS](11_Site_Infrastructure_GIS/README.md) | GPS/GIS, receptacles, power/site assets, physical-location history |
| [12_Setup_and_Deployment](12_Setup_and_Deployment/README.md) | Planned setup season/session, pull scheduling, pick/load lists, repeatable load order, forklift scanning, and deployment history |
| [90_Project Hour Log](90_Project%20Hour%20Log/) | Project effort and development history |

## Documentation Ownership Rules

- This tree is the engineering side of the Production Database documentation.
- Procedures/manuals belong under [Operational SOPs](../02_Operational_SOPs/README.md), even when they operate one of the systems above.
- Directus is a shared implementation platform, not a top-level business subsystem. Business-specific Directus Flows are documented with the subsystem whose process they implement.
- Dedicated application/service projects may maintain their own implementation repositories. The responsible subsystem README here documents how that project fits into Production Database architecture, what data it consumes or changes, and where authority remains.
- A separate application repository must not create a competing source of truth merely because a task-focused UI is needed.
- Shared database mechanisms belong under Database Foundation only when they are truly cross-system. Business-specific procedures/triggers belong with their owning subsystem.

## Legacy Architecture Cleanup

The previous competing numbered folders (`01_Stored_Proceedures` through `06_Scan_Workflows_and_Forklift_Operations`) have been migrated into their owning current subsystems and removed from the active tree.

The remaining loose A–H architecture documents are being reconciled separately. Historical material will be archived only after current responsibilities have an authoritative owner in this tree.
