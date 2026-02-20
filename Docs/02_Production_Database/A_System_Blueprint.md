# A — Production Database — System Blueprint
Last updated: 2026-02-20  
Owner: MSB Production Crew  
Status: Design Lock – Phase 1 Foundation  

---

# 1. Purpose

The Production Database is the **operational system of record** for all physical and logistical aspects of the MSB show.

It exists to manage everything that LOR does not:

- Physical Displays
- Storage (Pallets / Rack Locations)
- Annual Maintenance Testing
- Kits and Inventory
- Controllers (hardware inventory)
- Infrastructure (panels, outlets, streetlights)
- Setup / Takedown documentation
- Reporting and historical tracking

LOR remains the authoritative source for **show topology and wiring**.  
Production DB is authoritative for **physical assets and operations**.

---

# 2. System Boundaries

## LOR Owns
- Previews
- Props
- Subprops
- Controller assignments
- Channel ranges
- Wiring topology
- LOR UUIDs

## Production DB Owns
- What a Display physically is
- Where it is stored
- Who tested it
- Whether it passed inspection
- What lights it contains
- Which pallet it belongs to
- Which rack location that pallet occupies
- Kit contents
- Controller hardware inventory
- Infrastructure dependencies

---

# 3. Core Principles

### 3.1 DisplayKey is Identity
Display identity is derived from the LOR Comment field.

DisplayKey format:

<SC>-<DisplayName>(-tokens...)


Where `<SC>` is the required 2-character Stage Code.

DisplayKey is the **primary logical key** for Production.

---

### 3.2 UUIDs Are Not Identity
LOR UUIDs are stored for traceability but are not used as primary keys.

If LOR regenerates UUIDs, Production data must remain stable.

---

### 3.3 Snapshot-Based Ingestion
Each LOR import is stored as a snapshot.

This allows:
- Year-over-year diffing
- Change detection
- Rollback safety
- Audit traceability

---

### 3.4 Separation of Concerns
Production DB must never:
- Modify LOR data
- Attempt to become the show topology source

It consumes LOR outputs and enriches them.

---

# 4. High-Level Architecture


LOR SQLite → Parser → LOR Snapshot Tables (Postgres)
↓
Display Matching
↓
Production Core Tables
↓
Reports / Apps


---

# 5. Core Domain Model

## 5.1 Stage

Represents a physical park location.

Fields:
- id
- stage_code (FC, WW, FT, DF, etc)
- stage_name
- active
- notes

Stage identity comes from the 2-character code in DisplayKey.

---

## 5.2 Display

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

Relationships:
- 1 Display → many MaintenanceRecords
- 1 Display → 0..many PalletAssignments
- 1 Display → 0..many LOR Bindings
- 1 Display → 0..many Documents
- 1 Display → 0..many Wiring Legs (via snapshot)

---

## 5.3 LOR Snapshot Tables

These are ingestion-only tables.

Example:
- lor_import_run
- lor_preview
- lor_prop
- lor_wiring_leg

Purpose:
- Preserve raw wiring truth
- Allow diffing
- Provide wiring lookup for tablet app

---

## 5.4 Storage Model

### Pallet
- id
- pallet_tag (barcode-ready)
- description
- status

### Rack Location
- id
- rack_code (A-03-02 style)
- zone
- notes

### Pallet Assignment
Tracks which display is on which pallet and when.

### Pallet Location History
Tracks pallet movement between rack locations.

---

## 5.5 Maintenance Model

### Maintenance Season
- id
- year
- start_date
- end_date
- status

### Maintenance Record
- season_id
- display_id
- tested_by
- tested_at
- result (pass/fail/repair-needed)
- notes
- minutes_spent

Key Reports:
- Untested displays
- Failed displays
- Last tested date
- Maintenance completion %

---

## 5.6 Display Attributes

Tracks physical characteristics not in LOR:

- light_technology (LED, incandescent, rope)
- color
- accurate_light_count
- vendor
- cost
- amps_estimate
- year_acquired
- power_notes

This supports:
- Annual light counts
- Power planning
- Inventory budgeting

---

## 5.7 Kit & Inventory Model

### Kit
Represents a box or grouped equipment set.

Fields:
- id
- kit_code
- typical_stage_id
- notes

### Inventory Item
- id
- item_code
- description
- category
- consumable_flag
- reorder_point

### Kit Item
Defines contents of each kit.

---

## 5.8 Controller Inventory

Tracks physical controller hardware.

Fields:
- id
- controller_tag (barcode)
- controller_type (16ch, 4ch, RGB, etc)
- firmware_version
- network
- status
- notes

This is separate from LOR controller topology.

---

## 5.9 Infrastructure Assets

Tracks seasonal dependencies:

- Streetlights to turn off
- Metered panels
- Circuits
- Outlet assignments
- Power distribution

Fields:
- id
- asset_type
- identifier
- stage_id
- seasonal_rules
- documentation_link

---

# 6. Tablet Field Wiring App (Future Layer)

The tablet app will:

Filter by Stage  
List Displays  
Show:
- Wiring legs
- Controller assignments
- Channel ranges
- Setup instructions
- Related schematics

Data source:
- LOR snapshot + Production enrichment

---

# 7. Phase Implementation Plan

## Phase 1 (Immediate Priority)
- LOR snapshot ingestion
- Display auto-creation
- Stage registry
- Basic wiring lookup

## Phase 2
- Pallets
- Rack locations
- Display storage assignment

## Phase 3
- Maintenance season + records
- Maintenance reporting

## Phase 4
- Kits + inventory
- Controller hardware inventory

## Phase 5
- Infrastructure registry
- Tablet application layer

---

# 8. Governance Rules

1. DisplayKey changes require alias tracking.
2. Stage Codes are controlled vocabulary.
3. No production table may use LOR UUID as primary identity.
4. Every ingestion run must produce a change report.
5. This document must be versioned when schema changes.

---

# 9. Long-Term Vision

The Production Database becomes:

- The authoritative physical asset registry
- The historical record of show evolution
- The operational backbone for volunteers
- The foundation for barcode scanning
- The backend for the field tablet app
- The reporting engine for annual planning

It is not just a database.

It is the operations platform for MSB.