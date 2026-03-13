# A — Production Database — System Blueprint
Last updated: 2026-03-09
Owner: MSB Production Crew  
Status: Operational Prototype — Database Layer Implemented

---

## 1. Purpose

The Production Database is the **operational system of record** for the physical and logistical reality of the MSB show.

It exists to manage everything **Light-O-Rama (LOR)** does *not* manage well:

- Physical Displays (what the thing actually is)
- Storage (containers / racks / zones)
- Annual Maintenance Testing
- Kits and Inventory
- Controller hardware inventory (physical assets)
- Infrastructure dependencies (panels, outlets, streetlights)
- Setup / takedown documentation
- Setup / Takedown Staging for scheduling
- Reporting and historical tracking

**Boundary statement:**
- **LOR** remains the authoritative source for *show topology and wiring*.
- **Production DB** is authoritative for *physical assets and operations*. 

### 1.1 Core Infrastructure Requirements

The Production Database project began with several core infrastructure requirements to ensure the system would be secure, maintainable, and accessible to volunteers.

Key requirements include:

• Use a modern relational database platform (PostgreSQL or MySQL)  
• Secure access from the public internet  
• Single Sign-On authentication for volunteers  
• Minimal user administration overhead  
• Integration with Google Workspace for identity management  
• Wireless access from phones, tablets, and laptops via a web browser  
• Ability to support shop-floor usage while working on displays  

The system was designed from the beginning to operate as a **browser-based application**, allowing volunteers to access the system anywhere in the shop using standard devices without installing software.

Authentication is handled through **Google Workspace Single Sign-On**, allowing volunteers to log in with their MSB Google accounts.

External access is protected using **Cloudflare**, which provides DNS, TLS security, and network protection for the application.

The system is also integrated with the MSB operations portal:

my.sheboyganlights.org

This portal serves as the operational entry point for volunteers and links to the production database and other internal tools.

### 1.2 LOR Data Extraction Foundation

In 2025 a custom parser was developed to extract structured data from Light-O-Rama preview files.

This parser converts LOR preview data into a structured database format, allowing the system to use LOR as the authoritative source of truth for show topology while enabling operational data management within the Production Database.

The parser produces snapshot imports of the LOR preview data, allowing the system to:

• preserve historical versions of the show wiring  
• detect changes between seasons  
• safely integrate LOR data into operational workflows

This work established the data foundation that makes the Production Database possible.

---

## 2. System Boundaries

### LOR owns
- Previews
- Props / Subprops
- Controller assignments
- Channel ranges
- Wiring topology
- LOR UUIDs

### Production DB owns
- Display definition (what it physically is)
- Storage assignments + history
- Maintenance seasons + test results
- Physical attributes (lights, power, vendor/cost, etc.)
- Kit definitions + kit contents
- Controller hardware inventory (physical tagging, status)
- Infrastructure dependencies by stage 
---

## 3. Core Principles

### 3.1 DisplayKey is identity (Production identity)
Display identity is derived from the **LOR Comment** field.

**DisplayKey format:**
`<SC>-<DisplayName>(-tokens...)`

Where:
- `<SC>` = required 2-character Stage Code (controlled vocabulary)

Production identity keys:
- `display_id` (normalized + unique) 
- `display_name` (foundational tie between LOR and Display)

### 3.2 UUIDs are not identity

LOR UUIDs are stored for traceability but **never used** as Production identity.
- `lor_prop_id` (original)
- `preview_id` (original)
If LOR regenerates UUIDs, Production must remain stable.

### 3.3 Snapshot-based ingestion
Each LOR import is stored as a snapshot so we can:
- diff year-over-year
- detect changes
- roll back safely
- audit what changed and when

### 3.4 Separation of concerns
Production DB must never:
- modify LOR data
- try to become show topology

It consumes LOR outputs and enriches them. 

---

## 4. High-Level Architecture

The Production Database integrates several layers that move data from the show design system into operational tools used by volunteers.

**Architecture flow**:

Light-O-Rama (LOR)  
↓  
LOR Parser  
↓  
PostgreSQL Snapshot Tables (`lor_snap`)  
↓  
Production Core Tables (`ref`, `ops`)  
↓  
Directus Application Layer  
↓  
Web Browser Access (phones / tablets / laptops)

**Infrastructure Layer**:

Internet  
↓  
Cloudflare (DNS, TLS security, protection)  
↓  
MSB Production Server  
↓  
Directus + PostgreSQL

Authentication Layer:

Google Workspace  
↓  
Single Sign-On (SSO)  
↓  
Directus Roles and Permissions

---

## 5. Core Domain Model

### 5.1 Stage

Represents a physical park location.

Fields:
- id
- stage_code (FC, WW, FT, DF, WW, etc)
- stage_name
- active
- notes

Stage identity comes from the 2-character Stage Code in DisplayKey.

---

### 5.2 Display

Represents a single physical buildable/storable item.

Fields:
- id
- display_key_raw
- display_key_norm (unique)
- display_name
- stage_id (default stage)
- status (active / retired / archived)
- year_built
- designer
- notes

Relationships (conceptual):
- 1 Display → many Maintenance Records
- 1 Display → 0..many container Assignments
- 1 Display → 0..many LOR Bindings
- 1 Display → 0..many Documents
- 1 Display → 0..many Wiring Legs (via snapshot)

---

### 5.3 LOR Snapshot Tables (Postgres)

Ingestion-only tables; raw truth preserved.

Examples:
- lor_import_run
- lor_preview
- lor_prop
- lor_wiring_leg

Purpose:
- preserve raw wiring truth
- allow diffing
- provide wiring lookup for the future tablet app 

---

### 5.4 Storage Model

#### Container

- id
- container_tag (barcode-ready)
- description
- status

#### Storage Location

Represents where a container is physically stored.

- location_code (RF01-A-01 style)
- type_code (R = rack location, Z = zone area)
- zone (building or defined area such as B-East, B-West, Mezzanine)
- description / notes

Rules:
• One location per container  
• Zones may contain multiple containers

#### Container Assignment

Tracks which Display is on which Container and when.

#### Container Location History

Tracks Container movement between rack locations.

---

### Testing Process Purpose

The annual **Testing process** serves multiple operational purposes beyond verifying that displays function correctly.

Testing is used to:

• confirm each display is present on the correct container  
• detect packing mistakes that may have occurred during seasonal takedown  
• reconcile and correct inaccurate legacy spreadsheet records  
• validate and standardize display naming conventions  
• identify displays requiring repair before setup season  
• prepare containers for efficient deployment during show setup  

This process significantly reduces setup delays and prevents situations where crews must search for missing displays during installation.

Within the production crew this situation is commonly referred to as **“LFS” (Looking For Stuff)**.

By validating container contents during the off-season testing period, containers can be deployed to the park with confidence that their contents are complete and correctly documented.

### 5.5 Testing Model

#### Testing Season

- id
- year
- start_date
- end_date
- status

#### Testing Record

- season_id
- display_id
- tested_by
- tested_at
- result (OK / OK-REPAIRED / REPAIR-W/O / DEFERR / WRONG CONTAINER)
- notes
- minutes_spent

Key Reports:
- untested displays
- failed displays
- last tested date
- maintenance completion %

---

### 5.6 Display Attributes (Enrichment)

Physical characteristics not in LOR, used for planning/budget/power:

- designer
- year introduced
- vendor (supplies FUTURE)
- cost (FUTURE)
- amps measured
- estimated light count
- dumb controllers
- notes

Supports:
- annual light counts
- power planning
- inventory budgeting

---

### 5.7 Kit & Inventory Model (Future Phase)

#### Kit

Represents a box or grouped equipment set.

Fields:
- id
- kit_code
- typical_stage_id
- notes

#### Inventory Item

- id
- item_code
- description
- category
- consumable_flag
- reorder_point

#### Kit Item

Defines contents of each kit. 

---

### 5.8 Controller Inventory (Future Phase)

Tracks physical controller hardware (not LOR topology).

Fields:
- id
- controller_tag (barcode)
- controller_type (16ch, 4ch, RGB, etc)
- firmware_version
- network
- status
- notes
---

### 5.9 Infrastructure Assets (Future Phase)

Tracks seasonal dependencies:
- streetlights to turn off
- metered panels
- circuits
- outlet assignments
- power distribution

Fields:
- id
- asset_type
- identifier
- stage_id
- seasonal_rules
- documentation_link 

---

## 6. Tablet Field Wiring App (2026 Setup)

Tablet app goals:
- filter by Stage
- list Displays
- show wiring legs, controller assignments, channel ranges
- show setup instructions + related schematics

Data source:
- LOR snapshot + Production enrichment

---

## 7. Phase Implementation Plan

This section reflects implementation order, not architectural layers.
(Architectural phases are defined in D_Database_Structure.md.)

### Development Status Clarification

Within this document the terms **COMPLETE** or **IMPLEMENTED** refer to the **database architecture and core schema being implemented and validated**.

This indicates that:

• database tables and relationships exist  
• core workflows function at the database level  
• the data model has been tested and debugged  

It does **not** mean the overall system is finished.

Significant development work remains in:

• user interface (UI) development  
• user experience (UX) improvements  
• operational workflow refinement  
• volunteer usability testing  
• ongoing debugging and enhancements

The current system should be considered an **operational prototype under active development**.

---

### Phase 1 — Snapshot Foundation (Implemented 26-02-21)

Delivered:
- LOR SQLite parser (v6)
- Postgres `lor_snap` ingestion pipeline
- Atomic import runs (`import_run_id`)
- Wiring leg derivation
- Basic wiring lookup capability
- Stage registry

Notes:
- Snapshot layer is immutable and versioned.
- Wiring structure is now stable.
- This phase is closed.

---

### Phase 2 — Display Reconciliation & Core Production Mapping (Database Implemented)

Purpose:
Bridge snapshot data to production entities.

Includes:
- Display reconciliation workflow
  - Review required for new/mismatched DisplayKeys
- ref.display normalization
- ref.stage validation enforcement
- Display-to-stage consistency controls
- Production display registry (`ops.display`)

Goal:
Stabilize identity mapping between LOR data and operational records.

---

### Phase 3 — Storage & Physical Logistics (Database Implemented)

Includes:
- Container registry
- Rack location registry
- Display storage assignment
- Rack slot conventions (2-digit slot numbers)
- Physical location lookup

Goal:
Answer:
"Where is this display physically located right now?"

---

### Phase 4 — Maintenance & Work Management (Database Implemented — UI automation pending)

Includes:
- Convert Google Sheets Work Order System to PostgreSQL (database migration complete)
- Add Display Repairs as a work order to Work Order System based on test_status=REPAIR - W/O
- Maintenance records
- Work Orders / Task System
- Roles, skills, priorities
- Operational workflow tracking Mark Repaired displays as Repaired when completed See Document G_2026-Containter Repair V3.md
- Reporting

Goal:
Track lifecycle and repair history of displays and infrastructure.

---

### Phase 5 — Inventory & Hardware Tracking

Includes:
- Kits
- Controller hardware inventory
- Light technology inventory
- Vendor + acquisition metadata
- Cost tracking

Goal:
Tie physical components to financial and operational context.

---

### Phase 6 — Infrastructure & Application Layer

Includes:
- Infrastructure registry (power, network, controllers)
- Tablet / shop-floor application layer
- Barcode / QR integration
- Lookup & reporting dashboards
- Role-based access interface

Goal:
Make the system usable in the field.

## 8. Governance Rules

1. DisplayKey changes require alias tracking.
2. Stage Codes are controlled vocabulary.
3. No Production table may use LOR UUID as primary identity.
4. Every ingestion run must produce a change report.
5. This document must be versioned when design changes.

---

## 9. Long-Term Vision

The Production Database becomes:

- authoritative physical asset registry
- historical record of show evolution
- operational backbone for volunteers
- foundation for barcode scanning
- backend for the field tablet app
- reporting engine for annual planning

It is not just a database.
It is the operations platform for MSB. 

## 10. Change Log

This document reflects the evolving architecture of the MSB Production Database as the system moved from concept to operational prototype.

---

### 2026-03-08 — Operational Testing Milestone

System status: Entering operational testing with production volunteers.

Key additions:

• Hybrid audit system combining Directus hooks and PostgreSQL triggers  
• Actor stamping (`created_by`, `updated_by`, `*_person_id`)  
• Workflow audit tracking (`checked_at`, `checked_by`, `checked_by_person_id`)  
• Container pull operational workflow  
• Validation requiring work location before container pull  
• Container testing dashboards in Directus  
• Display testing workflow stabilization  
• Work order integration with display testing results  

Additional work:

• Directus UI enhancements and bookmarks  
• Role and policy refinement  
• Schema documentation updates  
• Database documentation revisions  

System status: **Ready for operational testing with production volunteers.**

---

### 2026-03-07 — Container Workflow Implementation

Operational container workflow designed and implemented.

Added:

• Container pull mechanism  
• Work location tracking for pulled containers  
• Status tracking for testing progress  
• Integration with display testing workflow  

Database updates:

• Schema adjustments for container workflow  
• UI development within Directus for container operations

---

### 2026-03-05 → 2026-03-06 — Directus Operational Layer Development

Major progress integrating Directus as the operational application layer.

Implemented:

• Directus deployment on production server  
• User authentication and Google SSO integration  
• Role definitions (Admin, Manager, Production Crew, Browser)  
• Collection configuration and permissions model  
• Initial operational dashboards  

Additional work:

• UI improvements and testing workflows  
• Data model adjustments based on real usage

---

### 2026-03-01 → 2026-03-04 — Operational System Expansion

Expanded system from ingestion pipeline to full operational platform.

Added:

• Container registry and storage tracking  
• Rack location registry  
• Display storage assignment model  
• Work order system migration from Google Sheets  
• Repair workflow integration with display testing  

System now capable of tracking:

• Display testing results  
• Repair needs  
• Storage locations  
• Container movement

---

### 2026-02-20 → 2026-02-28 — Foundation Architecture

Initial system design and infrastructure build.

Major accomplishments:

• Dedicated production database server built  
• PostgreSQL installed and configured  
• Core database architecture designed  
• Schema separation defined (`lor_snap`, `ref`, `stage`, `ops`)  
• LOR parser and ingestion pipeline implemented  
• Snapshot-based ingestion model created  
• Wiring leg derivation and lookup capability established  

This phase established the architectural foundation for the operational system.

---