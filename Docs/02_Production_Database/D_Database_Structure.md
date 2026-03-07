# D — Database Structure (Production DB)
Last updated: 2026-03-03
Owner: MSB Production Crew
Status: Draft (Phase 1–3 scope locked)

## Change Block

- 2026-03-07
  - Established standard audit model for all writable tables in the `ref` and `ops` schemas.
  - Added relational attribution fields (`*_person_id`) referencing `ref.person.person_id`.
  - Defined fallback behavior where text audit fields (`*_by`) record the PostgreSQL session user when no `ref.person` mapping exists.
  - Documented audit trigger resolution order (Directus user → mapped PostgreSQL login → PostgreSQL session user fallback).

- 2026-03-06
  - Revised section 4.6 Storage Location to include new Zone Codes
  - 
- 2026-03-01:
  - Added `ref.display.display_id` as an IDENTITY surrogate key to support stable internal FK relationships for ops tables.
  - Kept `ref.display.lor_prop_id` as the LOR-authoritative natural key used for LOR upserts.
  - Clarified that downstream ops tables should reference `display_id` (not `lor_prop_id`) to avoid coupling ops workflows to LOR identifiers.

- 2026-02-28:
  - Introduced canonical `display_id` (identity surrogate key) on `ref.display`.
  - Preserved `lor_prop_id` as LOR ingestion key (remains primary key for Phase 1 stability).
  - Enforced `display_name` uniqueness at the database level.
  - Began migration of `ops.display_test_session` to reference `ref.display.display_id` instead of `lor_prop_id`.
  - Established architectural boundary:
    - `lor_snap` = ingestion layer (LOR-coupled)
    - `ref` = canonical reference layer
    - `ops` = operational history layer (must not depend on LOR keys)
  - Declared `lor_prop_id` usage in `ops` tables as transitional only (2026 backfill compatibility).
  
- 2026-02-21:
  - Completed **LOR Snapshot → Postgres ingestion pipeline**.
  - Implemented atomic snapshot loading with single end-of-run commit.
  - Formalized `lor_snap` as immutable, run-versioned schema.
  - Snapshot now sourced from `lor_output_v6.db` (SQLite parser v6).
  - Wiring layer standardized as derived `lor_wiring_leg` representation (mirrors `preview_wiring_sorted_v6`).
  - Views rebuilt automatically during ingestion.

- 2026-02-21:
  - Added **Work Orders / Task System** as a first-class Production module
    (users/roles, priorities/task types/skills, operational workflow, notification outbox).

- Notes:
  - Snapshot layer changes are structural but additive.
  - No existing opsuction modules removed.
  - No backward-breaking changes to Production schema.

# 1. Scope and Intent

This document defines the **MSB Production Database structure** in PostgreSQL.

## Guiding Rules

- **LOR remains the source of truth for show topology and wiring.**
- The Production Database is the source of truth for **physical assets and operations**.
- LOR data is ingested as **immutable snapshots** per import run.
- Physical **Display identity is the `display_key`** (derived from LOR comment conventions).

---

## Audit Model

All writable tables in the **`ref`** and **`ops`** schemas must include standard audit fields to track data creation and modification.

Audit fields provide two attribution layers:

1. **Relational attribution** through `ref.person` (`*_person_id` fields reference `ref.person.person_id`)
2. **Text fallback attribution** using the PostgreSQL session user

This ensures that every change can be attributed whether it originates from:

- Directus UI
- database administration tools (DBeaver / pgAdmin)
- automated scripts or procedures

---

## Required Audit Columns

Every writable table in `ref` and `ops` must include the following audit columns.


created_at timestamptz not null default now()
created_by text not null default current_user
created_by_person_id bigint

updated_at timestamptz not null default now()
updated_by text not null default current_user
updated_by_person_id bigint


For workflow tables where a **specific operational action** is recorded (such as inspection or testing), the following fields are also used:


checked_at timestamptz
checked_by text
checked_by_person_id bigint


---

## Attribution Resolution Rules

Audit triggers determine the acting user using the following resolution order:

1. **Directus user context**

   When changes originate from Directus, the logged-in Directus user UUID is resolved to a corresponding row in `ref.person`.

2. **Mapped PostgreSQL login**

   If the PostgreSQL login name exists in `ref.person`, that record is used.

3. **PostgreSQL session user fallback**

   If no mapping exists, the PostgreSQL session user (`current_user`) is written to the text audit field.

This approach ensures:

- relational integrity when user identity is known
- readable attribution for administrative database edits
- no loss of attribution for manual SQL operations

---

## Audit Field Behavior

- `created_*` fields are populated when a row is first inserted.
- `updated_*` fields are updated on every modification.
- workflow fields such as `checked_*` are populated according to table-specific business rules.

Example rule:

- `checked_at` and `checked_by` are populated when a status field transitions from `NULL` to a defined value.

The text audit fields (`*_by`) **always contain a value** when a write occurs.

The relational fields (`*_person_id`) are populated when the acting user can be resolved to a row in `ref.person`.  

If no mapping exists, the `*_person_id` field may remain `NULL` while the text field records the PostgreSQL session user.

---

## System Purpose

This structure is written to support the current priorities:

1. Ingest LOR snapshots into PostgreSQL  
2. Enrich Displays with physical attributes  
3. Assign Displays → Containers → Storage Locations  
4. Support maintenance season testing, repair workflow, and reporting

---

# 2. Schema Layout (Logical)

Recommended logical schemas (namespaces):
- `lor_snap` — LOR snapshot tables (ingestion-only, append-only by run)
- `prod` — Production operational tables (source-of-truth)
- `ref` — Reference/master tables (governed lists: controlled vocabularies **and** resources such as Displays, Users, Locations, Racks)

> If you don’t want multiple schemas initially, keep everything in `public` and prefix tables:
> - `lor_*`, `prod_*`, `ref_*`

## 2.1 Table naming rules (Design Lock)

- `ref.*` = governed master tables (controlled vocabularies **and** resources users reference repeatedly: Displays, Users, Skills, Locations, Racks).
- `prod.*` = operational transactions/history/workflows (assignments, events, maintenance/testing records, work orders, notifications).
- `lor_snap.*` = immutable snapshot ingestion tables (append-only by import run).

Relationship table naming conventions this section is not used anymore except for _history:

- `*_assignment` — assignment intent between entities, often with time or history tracking  
  *(example: display_container_assignment)*

- `*_link` — pure many-to-many relationship with no operational meaning beyond association  
  *(example: display_skill_link)*

- `*_history` — time-based movement or state history  
  *(example: container_location_history)*

Design rule:

If users repeatedly **select an item from a list**, that entity belongs in `ref.*` and must be referenced via a foreign key.

Operational tables must **never duplicate reference attributes** that already exist in `ref.*`.

# 3. Key Entities and Relationships

High-level relationship map:

- `lor_snap.lor_import_run`
  ↳ `lor_snap.lor_preview`, `lor_snap.lor_prop`, `lor_snap.lor_wiring_leg` (per run)

- `ref.display` (unique by `display_key_norm`)
  ↔ joins to `lor_snap.lor_wiring_leg` by DisplayKey for wiring lookup
  ↳ `ops.maintenance_record`
  ↳ `ops.pallet_assignment`
  ↳ `ops.display_document_link` (FK → ref.display)

- `ref.container`
  ↔ `ops.pallet_location_history` → `ref.storage_location`

- `ref.season`
  ↳ `ops.maintenance_record`
  ↳ `ops.display_season_status`
  ↳ `ops.pallet_season_status`

---

# 4. Reference Tables (ref_*)

## 4.0 ref.display

Represents a single physical display (stable physical identity).

This table is the canonical record for a physical object, independent of LOR UUIDs, wiring changes, controller changes, or stage reassignment.

**Fields**
- `display_id` (PK)
- `display_key_raw` (text)
- `display_key_norm` (text, UNIQUE, NOT NULL) — canonical identity key
- `display_title` (text, nullable)
- `stage_id_default` (FK → ref.stage)
- `status_code` (FK → ref.display_status)
- `year_built` (int, nullable)

**Designer**
- `designer_user_id` (FK → ref.user, nullable)
- `designer` (text, nullable) — legacy/free-text, optional

**Physical / Electrical / Cost (Phase 1–3: stored on master record)**
- `tech_code` (FK → ref.light_technology, nullable)
- `color` (text, nullable)
- `amps_measured` (numeric, nullable)
- `light_count_estimated` (int, nullable)
- `manufacturer` (text, nullable)
- `vendor` (text, nullable)
- `cost` (numeric, nullable)
- `inventory_source` (text, nullable)
- `year_acquired` (int, nullable)
- `power_notes` (text, nullable)
- `notes` (text, nullable)

**Rules**
- Display identity is `display_key_norm`.
- This table must never be auto-mutated by ingestion without reconciliation approval.

# MSB DB — Fixing ops.display_test_session Keying (Stop using lor_prop_id in ops)

Date: 2026-02-28
Owner: Greg
Status: DO-NOW (required before backfill + go-live UI)

## Problem

`ref.display` currently uses `lor_prop_id` as its PRIMARY KEY.
`ops.display_test_session` also stores `lor_prop_id`.

This couples ops tables to LOR internals and makes future changes painful.
It also caused confusion when trying to populate `display_id`:
- `ref.display` does NOT have `display_id` today
- so `update ... set display_id = d.display_id` fails (correctly)

## Decision

- `ref.display` gets a canonical surrogate key: `display_id` (integer identity)
- `display_name` remains the human-visible natural key and stays UNIQUE
- `lor_prop_id` remains the LOR linkage and stays UNIQUE
- ops tables reference `display_id` (not `lor_prop_id`, not `display_name`)

This is the correct boundary:
LOR → lor_snap (authoritative source) → ref.display (canonical mapping) → ops (operational history)

## Implementation Plan (Minimal Disruption)

### Step 1 — Add display_id to ref.display

```sql
alter table ref.display
  add column display_id bigint generated always as identity;

-- must be UNIQUE to be FK target (does not have to be PK)
alter table ref.display
  add constraint uq_ref_display_display_id unique (display_id);

-- enforce your “names are unique” rule at the DB layer
alter table ref.display
  add constraint uq_ref_display_display_name unique (display_name);
---

## 4.1 ref.stage

Controlled list of stage codes (build + wiring/setup unit).

**Fields**
- `stage_id` (PK)
- `stage_code` (UNIQUE) — 2 characters (FC, WW, FT, DF, …)
- `stage_name` — Preview Name used in LOR Previews
- `short_code` (text, nullable) 2 digit Sequence of stage in park. Split stages can have a trailing alpha
- `folder_name` human name — canonical folder name used by crew 
- `folder_path` (text, nullable) — relative path in repo/share (preferred)
- `setup_doc_path` (text, nullable) — primary setup/wiring doc reference (optional)
- `default_location_id` (FK → ref.location, nullable) — typical installed park area
- `active` (bool)
- `notes`

**Used by**
- `ref.display.stage_id_default`
- validation of DisplayKey stage code
- setup/wiring documentation navigation

---

## 4.2 ref.display_status

Controlled lifecycle status for Displays.

**Fields**
- `status_code` (PK) — ACTIVE / RETIRED / RECYCLED / ARCHIVED
- `description`

**Definitions**
- ACTIVE — currently in service and deployable.
- RETIRED — permanently removed from active use but preserved historically.
- RECYCLED — physical components reused to create a new Display identity.
- ARCHIVED — legacy record retained for administrative/history purposes only.

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

## 4.6 ref.location (Operational Location)

Controlled list of operational Locations used across assignments and Work Orders.

**Fields**
- `location_id` (PK)
- `location_key` (UNIQUE) — e.g., `07-Whoville-WV`, `00-HWY 42-HW`
- `location_name` (text)
- `location_type` (text) — PARK_AREA / FACILITY / ORG_PARTNER / ASSET / OTHER
- `stage_id_default` (FK → ref.stage, nullable) — optional tie to a stage code when applicable
- `short_code` (text, nullable)
- `folder_name` (text, nullable)
- `folder_path` (text, nullable)
- `active` (bool)
- `notes` (text, nullable)

R locations must be fully specified (rack_row_code + column_num + shelf_level_code + slot_bin_num all NOT NULL)

Z locations are bucket locations and must have:

  - rack_row_code NOT NULL
  - column_num NULL
  - slot_bin_num NULL
  - (shelf_level_code can be whatever / NULL — not constrained here)

So YES: using UNKNOWN is the safest move until the UI exists.
---

## 4.61 ref.container

Represents one physical container used for storage/staging/deployment.

Pallets are governed resources (they exist independent of assignment events).
Operational movement and assignment are tracked in `ops.*`.

**Fields**

- `container_id` (PK)
- `container_tag` (text, UNIQUE, NOT NULL) — human-visible identifier (barcode-ready)
- `container_type` (text, nullable) — STANDARD / OVERSIZE / CUSTOM / OTHER
- `active` (bool, default true)
- `notes` (text, nullable)

---

## 4.62 ref.storage_location

Represents one physical storage or staging location in the shop.

There are two supported location types:

- **R = Rack Slot** (single-occupancy)
- **Z = Zone** (multi-occupancy)

---

### Generated Identity

`location_code` is a **GENERATED column** and must never be manually inserted or updated.

Its value is derived from component columns based on `type_code`.

#### Generated rule (simplified)

- For `type_code = 'R'`:
  R<rack_row_code><column_num 2-digit>-<shelf_level_code>-<slot_bin_num 2-digit>


- For `type_code = 'Z'`:
  Z-<rack_row_code>[-<shelf_level_code>]


The exact formatting is enforced by the database expression and is authoritative.

---

## R — Rack Slot Rules

Rack slots represent precise physical positions in the rack system.

**Required columns when `type_code = 'R'`:**

- `rack_row_code`      (ex: RA, RB, RC…)
- `column_num`         (integer; rendered as 2-digit)
- `shelf_level_code`   (A..Z; A = bottom)
- `slot_bin_num`       (integer; rendered as 2-digit)

**Important convention:**
Every rack location must have at least one slot.
The minimum slot is `slot_bin_num = 1` (renders as `-01`).

Rack slots are treated as **single-occupancy locations**.
Only one container may occupy a rack slot at a time (enforced by operational logic / constraints).

---

## Z — Zone Rules

Zones represent logical or temporary storage areas.

Examples:
- FIX LOCATION
- MEZZANINE
- TRAILER
- WORK AREA
- UNKNOWN
- STANDALONE DISPLAY

**Required columns when `type_code = 'Z'`:**

- `rack_row_code`      (used as the zone name / grouping label)

**Optional column:**

- `shelf_level_code`   (used as a zone sub-label; may be NULL)

**Must be NULL for Z:**

- `column_num`
- `slot_bin_num`

Zone locations are **multi-occupancy**.
Multiple containers may share the same Z location.

---

## Insert Rules (Critical)

Because `location_code` is GENERATED:

- Never insert or update `location_code`
- Always insert only the component columns required by the type
- Follow the R vs Z NULL/NOT NULL rules strictly

Violating these rules will trigger CHECK constraint or generated column errors.

---

## Operational Distinction

- `ref.container.location_code` represents a container’s **home rack location** (typically R).
- `ops.test_session.work_location_code` typically references a **Z zone** (e.g., WORK AREA) during active testing or repair.
---

## 4.7 ref.work_priority

**Fields**

- `priority_id` (PK) — 1..N
- `priority_label` (text, nullable)
- `notify_on_assign` (bool) — typically true for Priority 1
- `notes` (text, nullable)

---

## 4.8 ref.work_task_type

**Fields**
- `task_type_id` (PK)
- `task_type_key` (UNIQUE)
- `task_type_label` (text)
- `active` (bool)
- `notes` (text, nullable)

---

## 4.9 ref.skill

**Fields**
- `skill_id` (PK)
- `skill_key` (UNIQUE)
- `skill_label` (text)
- `active` (bool)
- `notes` (text, nullable)

---

## 4.10 ref.skill_level (Optional)

**Fields**
- `skill_level_id` (PK)
- `level_key` (UNIQUE) — LOW / MED / HIGH
- `rank` (int)

---

## 4.11 ref.season

Controlled list of opsuction seasons (typically one per calendar year).

**Fields**
- `season_id` (PK)
- `season_year` (UNIQUE) — e.g., 2025, 2026
- `season_start_date` (date, nullable but recommended)
- `season_end_date` (date, nullable but recommended)
- `is_active` (bool)
- `is_locked` (bool)
- `notes` (nullable)

**Rules**
- Only **one** season should be marked `is_active = true` at a time.
- Once a season is complete (all displays returned to shop and put away), mark it `is_locked = true` to prevent accidental changes.

---

## 4.12 ref.user (Authorized Users)

**Fields**
- `user_id` (PK)
- `username` (UNIQUE, NOT NULL)
- `email` (UNIQUE, NOT NULL)
- `full_name` (text)
- `last_name` (text, nullable)
- `nickname` (text, nullable)
- `active` (bool)
- `notes` (text, nullable)

---

## 4.13 ref.role

**Fields**
- `role_id` (PK)
- `role_key` (UNIQUE) — VIEWER / MAINTAINER / MANAGER / ADMIN
- `role_name` (text)
- `notes` (text, nullable)

---

## 4.14 ref.user_role

**Fields**
- `user_id` (FK → ref.user)
- `role_id` (FK → ref.role)
- `granted_at` (timestamp)
- `granted_by_user_id` (FK → ref.user, nullable)

**Keys**
- PK: (`user_id`, `role_id`)

---

## 4.15 ref.user_skill

**Fields**
- `user_id` (FK → ref.user)
- `skill_id` (FK → ref.skill)
- `skill_level_id` (FK → ref.skill_level, nullable)
- `notes` (text, nullable)

**Keys**
- PK: (`user_id`, `skill_id`)

---

# 5. LOR Snapshot Layer (lor_snap.*)

The `lor_snap` schema represents immutable snapshot data imported
from the authoritative LOR SQLite database (`lor_output_v6.db`).

This data is:

- Derived from `parse_props_v6.py`
- Ingested into Postgres via the snapshot ingestion script
- Stored per `import_run_id`
- Never manually edited

Each ingest is atomic and versioned.

---

## 5.0 Snapshot Architecture

Source of truth:
- SQLite file: `lor_output_v6.db`
- Built by: `parse_props_v6.py`
- Includes:
  - previews
  - props
  - subProps
  - dmxChannels
  - preview_wiring_map_v6
  - preview_wiring_sorted_v6 (field-ready output)

Postgres ingestion:
- Creates one row in `lor_snap.lor_import_run`
- Bulk loads snapshot tables
- Rebuilds derived wiring views
- Commits once (atomic run)

If ingestion fails, no partial state remains.

---

## 5.1 lor_snap.lor_import_run

Represents one LOR ingestion event.

One row per snapshot load.

### Fields

- `import_run_id` (PK, serial)
- `imported_at` (timestamp with time zone, default now())
- `source_name` (text) — SQLite filename or build identifier
- `source_version` (text) — parser version / git hash
- `notes` (text, optional)

### Rules

- Never updated
- Never deleted
- All snapshot tables reference this ID

---

## 5.2 lor_snap.lor_preview

Raw preview metadata per import run.

### Fields

- `import_run_id` (FK → lor_import_run)
- `lor_preview_uuid` (text)
- `preview_name` (text)
- `stage_id` (text, derived in parser)
- `revision` (text, optional)
- `brightness` (numeric, optional)
- `background_file` (text, optional)

### Keys

- PK: (`import_run_id`, `lor_preview_uuid`)

---

## 5.3 lor_snap.lor_prop

Raw LOR props from SQLite `props` table.

Includes:
- LOR
- DMX
- DeviceType = None (inventory-only objects)

### Fields

- `import_run_id` (FK)
- `lor_prop_uuid` (text)
- `lor_preview_uuid` (text)
- `prop_name` (text)
- `lor_comment` (text)
- `device_type` (text)
- `network` (text, nullable)
- `controller_uid` (text, nullable)
- `start_channel` (int, nullable)
- `end_channel` (int, nullable)
- `max_channels` (int, nullable)
- `lights` (int, nullable)
- `tag` (text, nullable)
- `raw_json` (jsonb, optional future enhancement)

### Keys

- PK: (`import_run_id`, `lor_prop_uuid`)

---

## 5.4 lor_snap.lor_sub_prop

Materialized sub-props from SQLite `subProps`.

Represents:
- Multi-channel grid splits
- Cross-reuse wiring legs

### Fields

- `import_run_id` (FK)
- `lor_subprop_uuid` (text)
- `master_prop_uuid` (text)
- `lor_preview_uuid` (text)
- `prop_name` (text)
- `lor_comment` (text)
- `device_type` (text)
- `network` (text)
- `controller_uid` (text)
- `start_channel` (int)
- `end_channel` (int)
- `tag` (text, nullable)

### Keys

- PK: (`import_run_id`, `lor_subprop_uuid`)

---

## 5.5 lor_snap.lor_dmx_channel

Materialized DMX channel ranges from SQLite `dmxChannels`.

### Fields

- `import_run_id` (FK)
- `lor_prop_uuid` (text)
- `network` (text)
- `universe` (int)
- `start_channel` (int)
- `end_channel` (int)

### Keys

- PK: (`import_run_id`, `lor_prop_uuid`, `universe`, `start_channel`)

---

## 5.6 lor_snap.lor_wiring_leg (Derived)

Structured field-ready wiring representation.

Built from:

- lor_prop
- lor_sub_prop
- lor_dmx_channel

Equivalent to SQLite view `preview_wiring_sorted_v6`.

### Fields

- `import_run_id` (FK)
- `preview_name` (text)
- `stage_code` (text, derived from display naming contract)
- `display_key_norm` (text)
- `lor_name` (text)
- `network` (text)
- `controller_id` (text)
- `start_channel` (int)
- `end_channel` (int)
- `device_type` (text)
- `source` (PROP | SUBPROP | DMX)
- `lor_tag` (text, nullable)

### Keys

- PK:
  (`import_run_id`,
   `preview_name`,
   `controller_id`,
   `start_channel`)

### Indexes

- (`import_run_id`, `preview_name`)
- (`display_key_norm`)
- (`controller_id`)

---

## Snapshot Layer Rules

1. Immutable per import_run_id
2. No manual edits
3. No business logic
4. Pure representation of LOR state
5. Downstream layers (prod.*) reference specific runs

---


# 6. Production Operational Tables (prod.*)

These tables are **hand-managed** and represent the system of record for physical assets and operations.

---

## 6.1 prod.display_reconciliation (Required)

Captures ingest-time decisions when LOR snapshot data does not cleanly match an existing Display.

This table prevents:
- silent auto-creation
- silent renaming
- accidental duplication due to spelling errors

This is the governance layer for matching LOR snapshot records to canonical Displays.

**Fields**
- `reconciliation_id` (PK)
- `import_run_id` (FK → lor_snap.lor_import_run)
- `lor_display_key_raw` (text)
- `lor_display_key_norm` (text)
- `suggested_display_id` (FK → ref.display, nullable)
- `resolved_display_id` (FK → ref.display, nullable)
- `decision_status` (text)
  - SUGGESTED
  - CONFIRMED_MATCH
  - NEW_DISPLAY
  - CORRECTED_KEY
  - REJECTED
- `decided_by` (text, nullable)
- `decided_at` (timestamp, nullable)
- `notes` (text, nullable)

**Rules**
- Exact matches may auto-confirm (optional).
- Non-exact matches must generate a reconciliation record.
- New physical Displays are created only after a decision is recorded.
- Spelling corrections update `ref.display.display_key_norm` directly (no alias required unless structural).

---

## 6.2 prod.display_alias (Rare / Structural Renames Only)

Tracks intentional canonical DisplayKey changes where historical traceability matters.

Use this only when:
- A display is intentionally renamed for structural reasons.
- A stage code is permanently changed.
- Two displays are merged or split.

Do NOT use this for minor typo corrections.

**Fields**
- `alias_id` (PK)
- `display_id` (FK → ref.display)
- `old_display_key_norm` (text, NOT NULL)
- `old_display_key_raw` (text, nullable)
- `new_display_key_norm` (text, NOT NULL)
- `new_display_key_raw` (text, nullable)
- `changed_at` (timestamp)
- `changed_by` (text)
- `reason` (text)

---

---

## 6.4 prod.pallet_assignment
Maps Displays to Pallets over time.

**Fields**
- `container_assignment_id` (PK)
- `container_id` (FK → ref.container)
- `display_id` (FK → ref.display)
- `assigned_at` (timestamp)
- `removed_at` (timestamp, nullable)
- `condition_notes` (text, nullable)

**Rules**
- A display can be on **0 or 1 container** at a time (enforce with constraint or app logic).
- A container can contain **many displays**.

---

## 6.5 prod.container_location_history
Tracks where pallets are stored (movement/history).

**Fields**
- `container_location_id` (PK)
- `container_id` (FK → ref.container)
- `rack_location_id` (FK → ref.storage_location)
- `moved_at` (timestamp)
- `moved_by` (FK → ref.user, nullable)
- `note` (text, nullable)

**Rule**
- Current container location is the most recent `moved_at` record.

## 6.6 ops.maintenance_record
Annual testing record per display.

**Fields**
- `maintenance_id` (PK)
- `season_id` (FK → ref.season)
- `display_id` (FK → ref.display)
- `tested_by` (text)
- `tested_at` (timestamp)
- `result_code` (FK → ref.maintenance_result)
- `minutes_spent` (int, nullable)
- `notes` (text, nullable)

**Constraints**
- Recommended uniqueness: (`season_id`, `display_id`) unless you allow multiple test attempts.
  - If multiple attempts allowed, add `attempt_number` or allow many rows.

---

## 6.7 ops.kit
**Fields**
- `kit_id` (PK)
- `kit_code` (text, UNIQUE)
- `kit_name` (text)
- `stage_id_typical` (FK → ref.stage, nullable)
- `notes` (text, nullable)

---

## 6.8 ops.inventory_item
**Fields**
- `item_id` (PK)
- `item_code` (text, UNIQUE)
- `description` (text)
- `category_code` (FK → ref.inventory_category)
- `consumable_flag` (bool, default false)
- `reorder_point` (int, nullable)
- `notes` (text, nullable)

---

## 6.9 ops.kit_item
**Fields**
- `kit_id` (FK → ops.kit)
- `item_id` (FK → ops.inventory_item)
- `quantity` (int)
- `notes` (text, nullable)

**Keys**
- PK: (`kit_id`, `item_id`)

---

## 6.10 ops.controller
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

## 6.11 ops.document
Generic document registry (drawio, pdf, photos, etc).

**Fields**
- `document_id` (PK)
- `doc_type` (text) — DRAWIO, PDF, IMAGE, TEXT, OTHER
- `title` (text)
- `path_or_url` (text)
- `tags` (text, nullable)
- `notes` (text, nullable)

---

## 6.12 ops.display_document_link
Links documents to displays (many-to-many).

**Fields**
- `display_id` (FK → ref.display)
- `document_id` (FK → ops.document)
- `relationship` (text, nullable) — SCHEMATIC, SETUP, TAKEDOWN, PHOTO, etc

**Keys**
- PK: (`display_id`, `document_id`)

---

# 6A. Work Orders Module (ops.work_*)

Separate functional module for operational task intake, assignment, completion, and history.
Relies on shared masters in `ref.*` (including Users), and can optionally link to `ref.display`.

Workflow is modeled by status + timestamps (no row-moving).

---

## 6A.1 ops.work_order

**Fields**
- `work_order_id` (PK)
- `created_at` (timestamp)
- `created_by_user_id` (FK → ref.user)
- `priority_id` (FK → ref.work_priority)
- `task_type_id` (FK → ref.work_task_type)
- `location_id` (FK → ref.location)
- `display_id` (FK → ref.display, nullable)
- `summary` (text)
- `details` (text)
- `notes` (text, nullable)
- `photo_url` (text, nullable)
- `status_code` (text) — NEW / ASSIGNED / IN_PROGRESS / COMPLETED / CANCELED
- `completed_at` (timestamp, nullable)
- `completed_by_user_id` (FK → ref.user, nullable)

**Indexes**
- (`status_code`, `priority_id`)
- (`location_id`, `status_code`)
- (`display_id`)
- (`created_at`)

---

## 6A.2 ops.work_order_assignment

**Fields**
- `work_order_id` (FK → ops.work_order)
- `assignee_user_id` (FK → ref.user)
- `assigned_at` (timestamp)
- `assigned_by_user_id` (FK → ref.user)
- `is_primary` (bool, default false)

**Keys**
- PK: (`work_order_id`, `assignee_user_id`)

---

## 6A.3 ops.work_order_required_skill (Optional)

**Fields**
- `work_order_id` (FK → ops.work_order)
- `skill_id` (FK → ref.skill)
- `min_skill_level_id` (FK → ref.skill_level, nullable)

**Keys**
- PK: (`work_order_id`, `skill_id`)

---

## 6A.4 ops.work_order_event

**Fields**
- `event_id` (PK)
- `work_order_id` (FK → ops.work_order)
- `event_type` (text)
- `event_at` (timestamp)
- `actor_user_id` (FK → ref.user)
- `payload` (jsonb, nullable)

---

## 6A.5 ops.notification_outbox

**Fields**
- `outbox_id` (PK)
- `event_type` (text) — PRIORITY1_ASSIGNED / WORK_COMPLETED
- `work_order_id` (FK → ops.work_order)
- `payload` (jsonb)
- `status_code` (text) — PENDING / SENT / FAILED
- `attempt_count` (int)
- `last_error` (text, nullable)
- `created_at` (timestamp)
- `sent_at` (timestamp, nullable)

---

# 8. Seasonal Testing & Tagging Tables

## 8.1 ops.display_season_status

Tracks testing status for each display per season.

**Fields**
- `season_id` (FK → ref.season)
- `display_id` (FK → ref.display)
- `test_status` (UNTESTED / PASS / NEEDS_REPAIR / RETEST_REQUIRED)
- `active_repair_work_order_id` (FK → ops.work_order, nullable)
- `last_updated_at` (timestamp)
- `last_updated_by` (FK → ref.user)

**Keys**
- PK: (`season_id`, `display_id`)

---

## 8.2 prod.pallet_season_status

Tracks deployment readiness at container level.

**Fields**
- `season_id` (FK → ref.season)
- `container_id` (FK → ref.container)
- `ready_status` (NOT_READY / READY)
- `ready_at` (timestamp, nullable)
- `ready_by` (FK → ref.user, nullable)
- `ready_tag_applied` (bool, default false)
- `notes` (nullable)

**Keys**
- PK: (`season_id`, `container_id`)

---

## 8.3 ops.label_print_job (Optional but Recommended)

Queue and audit table for LAN-based label printing.

**Fields**
- `print_job_id` (PK)
- `created_at` (timestamp)
- `created_by_user_id` (FK → ref.user)
- `template_key` (nullable)
- `season_id` (nullable)
- `display_id` (nullable)
- `container_id` (nullable)
- `work_order_id` (nullable)
- `payload` (jsonb)
- `status` (QUEUED / PRINTED / FAILED / CANCELED)
- `printed_at` (timestamp, nullable)
- `error` (nullable)

---

# 9. Notes / Deferred Items (Future Phases)

Not included in Phase 1–3 schema unless needed immediately:
- Security camera inventory/config
- Tool checkout
- Infrastructure metering rules beyond a basic registry
- Fine-grained setup scheduling system

These can be added after the core is stable.

---

# 10. Open Decisions (Design Lock Items)

1) Do we allow multiple maintenance attempts per season per display?
2) Do we enforce “one container per display at a time” via DB constraint or app logic?
3) Where do we store Stage derivation truth if DisplayKey and Preview naming disagree?

Record answers in this doc when decided.

# 11. Operational Automation Rules (ops schema)

These rules describe automated behavior implemented through database triggers
and constraints in the `ops` schema.

They document the expected system behavior for container testing and repair
workflow so future developers and operators understand how the database
automatically manages work orders and testing status.

## ops — Testing Repairs → Work Orders (Automation)

**Current state (as of 2026-03-05):**
- There are **no triggers** on `ops.display_test_session`.
- Setting `ops.display_test_session.test_status = 'REPAIR'` currently **does not** auto-create a work order.

**Planned automation (MVP):**
1) When a checklist row is set to `test_status = 'REPAIR'`, create an **open** `ops.work_order` linked by `work_order.display_test_session_id`.
2) Enforce “one open work order per checklist row” using the existing unique partial index:
   - `ux_work_order_open_per_checklist_line` on `(display_test_session_id)` where `date_completed IS NULL`.
3) When the linked work order is completed (`date_completed` + `completed_by_person_id`), update the checklist row to `test_status = 'OK-REPAIRED'`.
4) When all checklist rows for a `test_session_id` are resolved, roll up the container status to DONE.

This section exists to prevent “documented behavior” from being mistaken as “implemented behavior”.

When editing display checklist rows inside a Test Session form, changes are not committed until the parent Test Session record is saved. Repair work orders are created only after the full Test Session edit is saved.

---

## 11.1 Repair Detection → Work Order Creation

When a display is tested during container testing, results are stored in:

`ops.display_test_session`

If a tester sets:

`test_result = 'REPAIR'`

the system will automatically create a repair work order in:

`ops.work_order`

The work order is linked to the checklist row via:

`work_order.display_test_session_id`

### Duplicate Protection

The system enforces:

- Only **one open work order per checklist row**.

This is implemented with the index:


ux_work_order_open_per_checklist_line
(display_test_session_id)
WHERE display_test_session_id IS NOT NULL
AND date_completed IS NULL


If a repair work order already exists and is still open,
no additional work order will be created.

Once the existing work order is completed,
a new repair can be created if the display fails testing again.

---

## 11.2 Work Order Completion → Display Repair Status

When a repair work order is completed:

- `date_completed`
- `completed_by_person_id`

are populated in `ops.work_order`.

The system then updates the linked checklist row:


ops.display_test_session.test_result


from


REPAIR


to


OK-REPAIRED


This indicates the display has been repaired successfully.

When editing display checklist rows inside a Test Session form, changes are not committed until the parent Test Session record is saved. Repair work orders are created only after the full Test Session edit is saved.
---

## 11.3 Container Test Session Completion

Each container testing session is tracked in:

`ops.test_session`

A container test session can be marked **DONE** when all checklist rows
in the associated `ops.display_test_session` records meet the completion rules.

Allowed final statuses:


OK
OK-REPAIRED


Blocking statuses:


REPAIR
NULL


If any checklist row remains in a blocking state,
the container test session remains incomplete.

Operationally this corresponds to the container retaining a **Yellow Tag**.

Once all rows meet the completion rules,
the container can be **Green Tagged** and the session is recorded as:


status = 'DONE'
done_at
done_by


Containers marked DONE are removed from the active testing queue.

---

## 11.4 Physical vs System State

The database tracks operational state,
but certain actions remain physical workflow steps.

Examples:

Physical actions
- moving a display to the repair area
- wiring Yellow Tags to displays or containers
- returning displays to containers

System actions
- creating work orders
- updating checklist status
- marking container testing sessions DONE

The SOP document defines the human workflow that corresponds to these system states.