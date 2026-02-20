# A — Production Database — System Blueprint
Last updated: 2026-02-20  
Owner: MSB Production Crew  
Status: Design Lock — Phase 1 Foundation

---

## 1. Purpose

The Production Database is the **operational system of record** for the physical and logistical reality of the MSB show.

It exists to manage everything LOR does *not* manage well:

- Physical Displays (what the thing actually is)
- Storage (pallets / racks / zones)
- Annual Maintenance Testing
- Kits and Inventory
- Controller hardware inventory (physical assets)
- Infrastructure dependencies (panels, outlets, streetlights)
- Setup / takedown documentation
- Reporting and historical tracking

**Boundary statement:**
- **LOR** remains the authoritative source for *show topology and wiring*.
- **Production DB** is authoritative for *physical assets and operations*. 【turn12file6†A_System_Blueprint.md†L10-L25】

---

## 2. System Boundaries

### LOR owns
- Previews
- Props / Subprops
- Controller assignments
- Channel ranges
- Wiring topology
- LOR UUIDs 【turn12file6†A_System_Blueprint.md†L30-L38】

### Production DB owns
- Display definition (what it physically is)
- Storage assignments + history
- Maintenance seasons + test results
- Physical attributes (lights, power, vendor/cost, etc.)
- Kit definitions + kit contents
- Controller hardware inventory (physical tagging, status)
- Infrastructure dependencies by stage 【turn12file6†A_System_Blueprint.md†L39-L50】

---

## 3. Core Principles

### 3.1 DisplayKey is identity (Production identity)
Display identity is derived from the **LOR Comment** field.

**DisplayKey format:**
`<SC>-<DisplayName>(-tokens...)`

Where:
- `<SC>` = required 2-character Stage Code (controlled vocabulary)

Production identity keys:
- `display_key_raw` (original)
- `display_key_norm` (normalized + unique) 【turn12file6†A_System_Blueprint.md†L55-L67】

### 3.2 UUIDs are not identity
LOR UUIDs are stored for traceability but **never used** as Production identity.
If LOR regenerates UUIDs, Production must remain stable. 【turn12file4†A_System_Blueprint.md†L3-L8】

### 3.3 Snapshot-based ingestion
Each LOR import is stored as a snapshot so we can:
- diff year-over-year
- detect changes
- roll back safely
- audit what changed and when 【turn12file4†A_System_Blueprint.md†L10-L18】

### 3.4 Separation of concerns
Production DB must never:
- modify LOR data
- try to become show topology

It consumes LOR outputs and enriches them. 【turn12file4†A_System_Blueprint.md†L21-L27】

---

## 4. High-Level Architecture

LOR SQLite → Parser → LOR Snapshot Tables (Postgres)  
↓  
Display Matching  
↓  
Production Core Tables  
↓  
Reports / Apps 【turn12file4†A_System_Blueprint.md†L30-L40】

---

## 5. Core Domain Model

### 5.1 Stage
Represents a physical park location.

Fields:
- id
- stage_code (FC, WW, FT, DF, etc)
- stage_name
- active
- notes

Stage identity comes from the 2-character Stage Code in DisplayKey. 【turn12file6†A_System_Blueprint.md†L112-L124】

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
- 1 Display → many MaintenanceRecords
- 1 Display → 0..many PalletAssignments
- 1 Display → 0..many LOR Bindings
- 1 Display → 0..many Documents
- 1 Display → 0..many Wiring Legs (via snapshot) 【turn12file6†A_System_Blueprint.md†L127-L148】

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
- provide wiring lookup for the future tablet app 【turn12file6†A_System_Blueprint.md†L151-L168】【turn12file9†A_System_Blueprint.md†L1-L11】

---

### 5.4 Storage Model (Future Phase)
#### Pallet
- id
- pallet_tag (barcode-ready)
- description
- status

#### Rack Location
- id
- rack_code (A-03-02 style)
- zone
- notes

#### Pallet Assignment
Tracks which Display is on which pallet and when.

#### Pallet Location History
Tracks pallet movement between rack locations. 【turn12file6†A_System_Blueprint.md†L102-L122】【turn12file9†A_System_Blueprint.md†L14-L33】

---

### 5.5 Maintenance Model (Future Phase)
#### Maintenance Season
- id
- year
- start_date
- end_date
- status

#### Maintenance Record
- season_id
- display_id
- tested_by
- tested_at
- result (pass / fail / repair-needed)
- notes
- minutes_spent

Key Reports:
- untested displays
- failed displays
- last tested date
- maintenance completion % 【turn12file6†A_System_Blueprint.md†L124-L147】

---

### 5.6 Display Attributes (Enrichment)
Physical characteristics not in LOR, used for planning/budget/power:

- light_technology (LED, incandescent, rope)
- color
- accurate_light_count
- vendor
- cost
- amps_estimate
- year_acquired
- power_notes

Supports:
- annual light counts
- power planning
- inventory budgeting 【turn12file6†A_System_Blueprint.md†L150-L167】

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
Defines contents of each kit. 【turn12file4†A_System_Blueprint.md†L170-L192】

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
- notes 【turn12file9†A_System_Blueprint.md†L106-L121】

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
- documentation_link 【turn12file1†A_System_Blueprint.md†L3-L20】

---

## 6. Tablet Field Wiring App (Future Layer)

Tablet app goals:
- filter by Stage
- list Displays
- show wiring legs, controller assignments, channel ranges
- show setup instructions + related schematics

Data source:
- LOR snapshot + Production enrichment 【turn12file1†A_System_Blueprint.md†L23-L38】

---

## 7. Phase Implementation Plan

### Phase 1 (Immediate Priority)
- LOR snapshot ingestion
- Display auto-creation
- Stage registry
- basic wiring lookup

### Phase 2
- pallets
- rack locations
- display storage assignment

### Phase 3
- maintenance season + records
- maintenance reporting

### Phase 4
- kits + inventory
- controller hardware inventory

### Phase 5
- infrastructure registry
- tablet application layer 【turn12file1†A_System_Blueprint.md†L41-L65】

---

## 8. Governance Rules

1. DisplayKey changes require alias tracking.
2. Stage Codes are controlled vocabulary.
3. No Production table may use LOR UUID as primary identity.
4. Every ingestion run must produce a change report.
5. This document must be versioned when schema changes. 【turn12file1†A_System_Blueprint.md†L68-L75】

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