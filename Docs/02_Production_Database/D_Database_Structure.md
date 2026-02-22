# D — Database Structure (Production DB)
Last updated: 2026-02-21
Owner: MSB Production Crew
Status: Draft (Phase 1–3 scope locked)

## Change Block
- 2026-02-21: Added **Work Orders / Task System** as a first-class Production module (users/roles, priorities/task types/skills, operational workflow, notification outbox).
- Notes: Additive change only. No existing modules removed.

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
- `ref` — Reference/master tables (governed lists: controlled vocabularies **and** resources such as Displays, Users, Locations, Racks)

> If you don’t want multiple schemas initially, keep everything in `public` and prefix tables:
> - `lor_*`, `prod_*`, `ref_*`

## 2.1 Table naming rules (Design Lock)

- `ref.*` = governed master tables (controlled vocabularies **and** resources users reference repeatedly: Displays, Users, Skills, Locations, Racks).
- `prod.*` = operational transactions/history/workflows (assignments, events, maintenance/testing records, work orders, notifications).
- `lor_snap.*` = immutable snapshot ingestion tables (append-only by import run).

Relationship table naming:
- `*_assignment` = assignment intent (often time/history driven)
- `*_link` = pure many-to-many
- `*_history` = time-tracked movement/history

Rule: if users select it repeatedly, it belongs in `ref.*` and is referenced by FK.

---

# 3. Key Entities and Relationships

High-level relationship map:

- `lor_snap.lor_import_run`
  ↳ `lor_snap.lor_preview`, `lor_snap.lor_prop`, `lor_snap.lor_wiring_leg` (per run)

- `ref.display` (unique by `display_key_norm`)
  ↔ joins to `lor_snap.lor_wiring_leg` by DisplayKey for wiring lookup
  ↳ `prod.maintenance_record`
  ↳ `prod.pallet_assignment`
  ↳ `prod.display_document_link` (FK → ref.display)

- `ref.pallet`
  ↔ `prod.pallet_location_history` → `ref.rack_location`

- `ref.season`
  ↳ `prod.maintenance_record`
  ↳ `prod.display_season_status`
  ↳ `prod.pallet_season_status`

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

---

## 4.1 ref.stage

Controlled list of stage codes (build + wiring/setup unit).

**Fields**
- `stage_id` (PK)
- `stage_code` (UNIQUE) — 2 characters (FC, WW, FT, DF, …)
- `stage_name` — human name
- `short_code` (text, nullable)
- `folder_name` (text, nullable) — canonical folder name used by crew
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

---

## 4.61 ref.pallet

Represents one physical pallet used for storage/staging/deployment.

Pallets are governed resources (they exist independent of assignment events).
Operational movement and assignment are tracked in `prod.*`.

**Fields**

- `pallet_id` (PK)
- `pallet_tag` (text, UNIQUE, NOT NULL) — human-visible identifier (barcode-ready)
- `pallet_type` (text, nullable) — STANDARD / OVERSIZE / CUSTOM / OTHER
- `active` (bool, default true)
- `notes` (text, nullable)

---

## 4.62 ref.rack_location

Represents one physical rack location in the shop storage system.

This table supports:
- pallet storage (typical: no slot)
- shelf/bin storage (optional: slot within a location)

**Identity rule**
- The authoritative identity is (`rack_letter`, `column_num`, `row_code`, `slot_num`).
- `rack_code` is DERIVED and must not be manually edited.

### Rack conventions

- `rack_letter`: RA, RB, RC… (rack identifier)
- `column_num`: 1..N  
  - Column numbering is consistent within a rack.
  - Direction is defined by shop layout (West→East or South→North).
- `row_code`: A..Z  
  - A = bottom / floor-up
- `slot_num`: 1..N (nullable)  
  - Only used when a shelf position contains multiple bins/boxes.
  - Pallets typically use NULL (occupies the whole position).

### Fields

- `rack_location_id` (PK)
- `rack_letter` (text, NOT NULL) — RA, RB, …
- `column_num` (int, NOT NULL)
- `row_code` (text, NOT NULL) — A, B, C…
- `slot_num` (int, nullable) — 1..N
- `rack_code` (text, UNIQUE, NOT NULL) — DERIVED
- `active` (bool, default true)
- `notes` (text, nullable)

### Derived naming

Base (no slot):
- `rack_code` format: `<rack_letter>-<column_num:02>-<row_code>`
  - Example: `RA-03-B`

With slot:
- `rack_code` format: `<rack_letter>-<column_num:02>-<row_code>-<slot_num:02>`
  - Example: `RE-03-B-04`

### Constraints (recommended)

- UNIQUE (`rack_letter`, `column_num`, `row_code`, `slot_num`)
- CHECK (`column_num` > 0)
- CHECK (`slot_num` IS NULL OR slot_num > 0)

### Notes

- `rack_code` is stored for convenience/search/sorting, but is always derived from the authoritative fields.
- Slot is optional and should only be used where bins/boxes share a shelf location.
**Fields**

- `rack_location_id` (PK)

**Authoritative components**

- `rack_letter` (text, NOT NULL)
- `column_num` (int, NOT NULL)
- `row_num` (int, NOT NULL)

**Derived**

- `rack_code` (text, GENERATED / COMPUTED) — derived from the three fields above

**Optional context**
- `zone` (text, nullable) — optional shop/warehouse section label
- `active` (bool, default true)
- `notes` (text, nullable)

**Constraints**
- UNIQUE (`rack_letter`, `column_num`, `row_num`)
- (Optional) UNIQUE (`rack_code`) if stored/generated as a column
  
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

Controlled list of production seasons (typically one per calendar year).

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
- `display_key_norm` (text) — normalized for joins (must match ref.display)
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
- `pallet_assignment_id` (PK)
- `pallet_id` (FK → ref.pallet)
- `display_id` (FK → ref.display)
- `assigned_at` (timestamp)
- `removed_at` (timestamp, nullable)
- `condition_notes` (text, nullable)

**Rules**
- A display can be on **0 or 1 pallet** at a time (enforce with constraint or app logic).
- A pallet can contain **many displays**.

---

## 6.5 prod.pallet_location_history
Tracks where pallets are stored (movement/history).

**Fields**
- `pallet_location_id` (PK)
- `pallet_id` (FK → ref.pallet)
- `rack_location_id` (FK → ref.rack_location)
- `moved_at` (timestamp)
- `moved_by` (FK → ref.user, nullable)
- `note` (text, nullable)

**Rule**
- Current pallet location is the most recent `moved_at` record.

## 6.6 prod.maintenance_record
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

## 6.7 prod.kit
**Fields**
- `kit_id` (PK)
- `kit_code` (text, UNIQUE)
- `kit_name` (text)
- `stage_id_typical` (FK → ref.stage, nullable)
- `notes` (text, nullable)

---

## 6.8 prod.inventory_item
**Fields**
- `item_id` (PK)
- `item_code` (text, UNIQUE)
- `description` (text)
- `category_code` (FK → ref.inventory_category)
- `consumable_flag` (bool, default false)
- `reorder_point` (int, nullable)
- `notes` (text, nullable)

---

## 6.9 prod.kit_item
**Fields**
- `kit_id` (FK → prod.kit)
- `item_id` (FK → prod.inventory_item)
- `quantity` (int)
- `notes` (text, nullable)

**Keys**
- PK: (`kit_id`, `item_id`)

---

## 6.10 prod.controller
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

## 6.11 prod.document
Generic document registry (drawio, pdf, photos, etc).

**Fields**
- `document_id` (PK)
- `doc_type` (text) — DRAWIO, PDF, IMAGE, TEXT, OTHER
- `title` (text)
- `path_or_url` (text)
- `tags` (text, nullable)
- `notes` (text, nullable)

---

## 6.12 prod.display_document_link
Links documents to displays (many-to-many).

**Fields**
- `display_id` (FK → ref.display)
- `document_id` (FK → prod.document)
- `relationship` (text, nullable) — SCHEMATIC, SETUP, TAKEDOWN, PHOTO, etc

**Keys**
- PK: (`display_id`, `document_id`)

---

# 6A. Work Orders Module (prod.work_*)

Separate functional module for operational task intake, assignment, completion, and history.
Relies on shared masters in `ref.*` (including Users), and can optionally link to `ref.display`.

Workflow is modeled by status + timestamps (no row-moving).

---

## 6A.1 prod.work_order

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

## 6A.2 prod.work_order_assignment

**Fields**
- `work_order_id` (FK → prod.work_order)
- `assignee_user_id` (FK → ref.user)
- `assigned_at` (timestamp)
- `assigned_by_user_id` (FK → ref.user)
- `is_primary` (bool, default false)

**Keys**
- PK: (`work_order_id`, `assignee_user_id`)

---

## 6A.3 prod.work_order_required_skill (Optional)

**Fields**
- `work_order_id` (FK → prod.work_order)
- `skill_id` (FK → ref.skill)
- `min_skill_level_id` (FK → ref.skill_level, nullable)

**Keys**
- PK: (`work_order_id`, `skill_id`)

---

## 6A.4 prod.work_order_event

**Fields**
- `event_id` (PK)
- `work_order_id` (FK → prod.work_order)
- `event_type` (text)
- `event_at` (timestamp)
- `actor_user_id` (FK → ref.user)
- `payload` (jsonb, nullable)

---

## 6A.5 prod.notification_outbox

**Fields**
- `outbox_id` (PK)
- `event_type` (text) — PRIORITY1_ASSIGNED / WORK_COMPLETED
- `work_order_id` (FK → prod.work_order)
- `payload` (jsonb)
- `status_code` (text) — PENDING / SENT / FAILED
- `attempt_count` (int)
- `last_error` (text, nullable)
- `created_at` (timestamp)
- `sent_at` (timestamp, nullable)

---

# 8. Seasonal Testing & Tagging Tables

## 8.1 prod.display_season_status

Tracks testing status for each display per season.

**Fields**
- `season_id` (FK → ref.season)
- `display_id` (FK → ref.display)
- `test_status` (UNTESTED / PASS / NEEDS_REPAIR / RETEST_REQUIRED)
- `active_repair_work_order_id` (FK → prod.work_order, nullable)
- `last_updated_at` (timestamp)
- `last_updated_by` (FK → ref.user)

**Keys**
- PK: (`season_id`, `display_id`)

---

## 8.2 prod.pallet_season_status

Tracks deployment readiness at pallet level.

**Fields**
- `season_id` (FK → ref.season)
- `pallet_id` (FK → ref.pallet)
- `ready_status` (NOT_READY / READY)
- `ready_at` (timestamp, nullable)
- `ready_by` (FK → ref.user, nullable)
- `ready_tag_applied` (bool, default false)
- `notes` (nullable)

**Keys**
- PK: (`season_id`, `pallet_id`)

---

## 8.3 prod.label_print_job (Optional but Recommended)

Queue and audit table for LAN-based label printing.

**Fields**
- `print_job_id` (PK)
- `created_at` (timestamp)
- `created_by_user_id` (FK → ref.user)
- `template_key` (nullable)
- `season_id` (nullable)
- `display_id` (nullable)
- `pallet_id` (nullable)
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
2) Do we enforce “one pallet per display at a time” via DB constraint or app logic?
3) Where do we store Stage derivation truth if DisplayKey and Preview naming disagree?

Record answers in this doc when decided.