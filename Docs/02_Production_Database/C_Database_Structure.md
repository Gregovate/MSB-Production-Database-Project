# C — Database Structure (Production DB)
Last updated: 2026-02-20  
Owner: MSB Production Crew  
Status: Draft (Phase 1–3 scope locked)

---

# 1. Scope and Intent

This document defines the **Production Database structure** (Postgres) for MSB.

Guiding rules:
- **LOR remains source-of-truth for show topology and wiring.**
- Production DB is source-of-truth for **physical assets and operations**.
- LOR data is ingested as **immutable snapshots** per import run.
- Physical **Display identity is the DisplayKey** (derived from LOR Comment conventions).

This structure is written to support the current priorities:
1) Ingest LOR snapshot into Postgres  
2) Enrich Displays with physical attributes  
3) Assign Displays → Pallets → Rack Locations  
4) Maintenance season testing & reporting

---

# 2. Schema Layout (Logical)

Recommended logical schemas (namespaces):
- `lor_snap` — LOR snapshot tables (ingestion-only, append-only by run)
- `prod` — Production operational tables (source-of-truth)
- `ref` — Reference lists (controlled vocabularies / enums)

> If you don’t want multiple schemas initially, keep everything in `public` and prefix tables:
> - `lor_*`, `prod_*`, `ref_*`

---

# 3. Key Entities and Relationships

High-level relationship map:

- `lor_snap.lor_import_run`  
  ↳ `lor_snap.lor_preview`, `lor_snap.lor_prop`, `lor_snap.lor_wiring_leg` (per run)

- `prod.display` (unique by `display_key_norm`)  
  ↔ joins to `lor_snap.lor_wiring_leg` by DisplayKey for wiring lookup  
  ↳ `prod.maintenance_record`  
  ↳ `prod.pallet_assignment`  
  ↳ `prod.display_attribute`  
  ↳ `prod.display_document_link`

- `prod.storage_pallet`  
  ↔ `prod.pallet_location_history` → `prod.storage_rack_location`

- `prod.maintenance_season`  
  ↳ `prod.maintenance_record`

---

# 4. Reference Tables (ref_*)

## 4.1 ref.stage
Controlled list of stage codes.

**Fields**
- `stage_id` (PK)
- `stage_code` (UNIQUE) — 2 characters (FC, WW, FT, DF, …)
- `stage_name` — human name
- `active` (bool)
- `notes`

**Used by**
- `prod.display.stage_id_default`
- validation of DisplayKey stage code

---

## 4.2 ref.display_status
**Fields**
- `status_code` (PK) — ACTIVE / RETIRED / ARCHIVED
- `description`

---

## 4.3 ref.maintenance_result
**Fields**
- `result_code` (PK) — PASS / FAIL / REPAIR_NEEDED / NOT_TESTED / N_A
- `description`

---

## 4.4 ref.light_technology
**Fields**
- `tech_code` (PK) — LED / INCANDESCENT / ROPE / RGB / OTHER
- `description`

---

## 4.5 ref.inventory_category
**Fields**
- `category_code` (PK) — CORD / STAKE / CABLE / TOOL / TIE / POWER / NETWORK / OTHER
- `description`

---

# 5. LOR Snapshot Tables (lor_snap.*)

These tables store ingestion results per import run.
They are **not hand-edited**.

## 5.1 lor_snap.lor_import_run
Represents one LOR ingest event.

**Fields**
- `import_run_id` (PK)
- `imported_at` (timestamp)
- `source_name` (text) — which file/DB/build produced it
- `source_version` (text) — parser version, git hash, etc
- `notes` (text)

---

## 5.2 lor_snap.lor_preview
**Fields**
- `import_run_id` (FK → lor_import_run)
- `lor_preview_uuid` (text)
- `preview_name` (text)
- `created_at` (timestamp, optional if available)
- `notes` (text)

**Keys**
- PK: (`import_run_id`, `lor_preview_uuid`)

---

## 5.3 lor_snap.lor_prop
Represents raw LOR props (and optionally subprops if you store them here too).

**Fields**
- `import_run_id` (FK)
- `lor_prop_uuid` (text)
- `lor_preview_uuid` (text)
- `prop_name` (text)
- `comment_raw` (text)
- `display_key_raw` (text) — derived from comment conventions
- `display_key_norm` (text) — normalized for joins (must match prod.display)
- `device_type` (text)
- `max_channels` (int, optional)
- `tag` (text, optional)
- `notes` (text)

**Keys**
- PK: (`import_run_id`, `lor_prop_uuid`)

**Notes**
- DeviceType = "None" indicates inventory-only objects; excluded from wiring legs.

---

## 5.4 lor_snap.lor_wiring_leg
This table is the structured representation of field wiring output.  
It should be sourced from your existing wiring views/logic.

**Fields**
- `import_run_id` (FK)
- `lor_preview_uuid` (text) OR `preview_name` (text)
- `stage_code` (text) — derived from DisplayKey OR preview naming (contract rules)
- `display_key_norm` (text)
- `display_key_raw` (text, optional)
- `lor_name` (text) — original LOR channel/prop naming used for reference
- `network` (text)
- `controller_id` (text)
- `start_channel` (int)
- `end_channel` (int)
- `device_type` (text)

**Keys**
- PK: (`import_run_id`, `stage_code`, `display_key_norm`, `network`, `controller_id`, `start_channel`)

**Indexes**
- (`import_run_id`, `stage_code`)
- (`display_key_norm`)
- (`controller_id`)

---

# 6. Production Operational Tables (prod.*)

These tables are **hand-managed** and represent the system of record for operations.

## 6.1 prod.display
Represents a single physical display.

**Fields**
- `display_id` (PK)
- `display_key_raw` (text)
- `display_key_norm` (text, UNIQUE, NOT NULL)
- `display_name` (text) — friendly label if different from key
- `stage_id_default` (FK → ref.stage)
- `status_code` (FK → ref.display_status)
- `year_built` (int, nullable)
- `designer` (text, nullable)
- `active_flag` (bool) — optional; can be implied by status
- `notes` (text)

**Constraints**
- `display_key_norm` must be unique.
- Stage code inside DisplayKey must exist in `ref.stage` (validated during ingestion / data entry).

---

## 6.2 prod.display_alias (optional but recommended)
Tracks DisplayKey renames without losing history.

**Fields**
- `alias_id` (PK)
- `display_id` (FK → prod.display)
- `old_display_key_norm` (text)
- `old_display_key_raw` (text)
- `changed_at` (timestamp)
- `changed_by` (text)
- `reason` (text)

---

## 6.3 prod.display_attribute
Physical and cost attributes not in LOR.

**Fields**
- `display_id` (FK → prod.display)
- `tech_code` (FK → ref.light_technology)
- `color` (text, nullable)
- `accurate_light_count` (int, nullable)
- `amps_estimate` (numeric, nullable)
- `vendor` (text, nullable)
- `cost` (numeric, nullable)
- `inventory_source` (text, nullable)
- `year_acquired` (int, nullable)
- `power_notes` (text, nullable)
- `notes` (text, nullable)

**Keys**
- PK: (`display_id`)
  - (One row per display; if you need history, add a history table later.)

---

## 6.4 prod.storage_pallet
**Fields**
- `pallet_id` (PK)
- `pallet_tag` (text, UNIQUE) — barcode-ready identifier
- `description` (text)
- `status_code` (text, nullable) — if you want (ACTIVE/RETIRED/etc)
- `notes` (text)

---

## 6.5 prod.storage_rack_location
**Fields**
- `rack_location_id` (PK)
- `rack_code` (text, UNIQUE) — e.g., A-03-02
- `zone` (text, nullable)
- `description` (text, nullable)
- `notes` (text)

---

## 6.6 prod.pallet_assignment
Maps Displays to Pallets over time.

**Fields**
- `pallet_assignment_id` (PK)
- `pallet_id` (FK → prod.storage_pallet)
- `display_id` (FK → prod.display)
- `assigned_at` (timestamp)
- `removed_at` (timestamp, nullable)
- `condition_notes` (text, nullable)

**Rules**
- A display can be on **0 or 1 pallet** at a time (enforce with constraint or app logic).
- A pallet can contain **many displays**.

---

## 6.7 prod.pallet_location_history
Tracks where pallets are stored.

**Fields**
- `pallet_location_id` (PK)
- `pallet_id` (FK → prod.storage_pallet)
- `rack_location_id` (FK → prod.storage_rack_location)
- `moved_at` (timestamp)
- `moved_by` (text, nullable)
- `note` (text, nullable)

**Rule**
- Current pallet location is the most recent `moved_at` record.

---

## 6.8 prod.maintenance_season
**Fields**
- `season_id` (PK)
- `season_year` (int, UNIQUE)
- `start_date` (date, nullable)
- `end_date` (date, nullable)
- `status_code` (text, nullable) — PLANNED/ACTIVE/CLOSED
- `notes` (text, nullable)

---

## 6.9 prod.maintenance_record
Annual testing record per display.

**Fields**
- `maintenance_id` (PK)
- `season_id` (FK → prod.maintenance_season)
- `display_id` (FK → prod.display)
- `tested_by` (text)
- `tested_at` (timestamp)
- `result_code` (FK → ref.maintenance_result)
- `minutes_spent` (int, nullable)
- `notes` (text, nullable)

**Constraints**
- Recommended uniqueness: (`season_id`, `display_id`) unless you allow multiple test attempts.
  - If multiple attempts allowed, add `attempt_number` or allow many rows.

---

## 6.10 prod.kit
**Fields**
- `kit_id` (PK)
- `kit_code` (text, UNIQUE)
- `kit_name` (text)
- `stage_id_typical` (FK → ref.stage, nullable)
- `notes` (text, nullable)

---

## 6.11 prod.inventory_item
**Fields**
- `item_id` (PK)
- `item_code` (text, UNIQUE)
- `description` (text)
- `category_code` (FK → ref.inventory_category)
- `consumable_flag` (bool, default false)
- `reorder_point` (int, nullable)
- `notes` (text, nullable)

---

## 6.12 prod.kit_item
**Fields**
- `kit_id` (FK → prod.kit)
- `item_id` (FK → prod.inventory_item)
- `quantity` (int)
- `notes` (text, nullable)

**Keys**
- PK: (`kit_id`, `item_id`)

---

## 6.13 prod.controller
Hardware inventory for controllers.

**Fields**
- `controller_pk` (PK)
- `controller_tag` (text, UNIQUE) — barcode-ready identifier
- `controller_type` (text) — 16ch, 4ch, RGB, etc
- `firmware_version` (text, nullable)
- `network` (text, nullable)
- `status_code` (text, nullable)
- `notes` (text, nullable)

---

## 6.14 prod.document
Generic document registry (drawio, pdf, photos, etc).

**Fields**
- `document_id` (PK)
- `doc_type` (text) — DRAWIO, PDF, IMAGE, TEXT, OTHER
- `title` (text)
- `path_or_url` (text)
- `tags` (text, nullable)
- `notes` (text, nullable)

---

## 6.15 prod.display_document_link
Links documents to displays (many-to-many).

**Fields**
- `display_id` (FK → prod.display)
- `document_id` (FK → prod.document)
- `relationship` (text, nullable) — SCHEMATIC, SETUP, TAKEDOWN, PHOTO, etc

**Keys**
- PK: (`display_id`, `document_id`)

---

# 7. Views (Phase 1–3)

Recommended production views (names are suggestions):

## 7.1 prod.v_display_current_pallet
- display_id
- pallet_id (current, if assigned)
- pallet_tag
- assigned_at

## 7.2 prod.v_pallet_current_location
- pallet_id
- pallet_tag
- rack_location_id (current)
- rack_code
- moved_at

## 7.3 prod.v_maintenance_progress_by_stage
- stage_code
- total_displays
- tested_count
- failed_count
- percent_complete

## 7.4 prod.v_field_wiring_current
Joins latest `lor_snap.lor_import_run` to displays.

Outputs:
- stage_code
- display_key
- network
- controller_id
- start_channel
- end_channel
- plus: pallet_tag / rack_code (optional join) for “find it” workflow

---

# 8. Notes / Deferred Items (Future Phases)

Not included in Phase 1–3 schema unless needed immediately:
- Security camera inventory/config
- Tool checkout
- Infrastructure metering rules beyond a basic registry
- Fine-grained setup scheduling system

These can be added after the core is stable.

---

# 9. Open Decisions (Design Lock Items)

1) Do we allow multiple maintenance attempts per season per display?
2) Do we enforce “one pallet per display at a time” via DB constraint or app logic?
3) Where do we store Stage derivation truth if DisplayKey and Preview naming disagree?

Record answers in this doc when decided.

---