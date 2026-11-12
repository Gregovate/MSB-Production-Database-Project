# MSB Ops — Directus Database Architecture (MVP)

## Overview

This document defines the database objects that power the Directus UI for:

- Container Testing
- Display Testing (child records)
- Work Orders (Repairs)
- Stage/Container browsing

This architecture separates:

- Reference data (`ref` schema)
- Operational data (`ops` schema)
- UI-facing views (`ops.v_*`)

No year-based naming is used in views.

---

# 1. Core Reference Tables (ref schema)

These are stable structural tables.

## ref.container
Represents a physical container (pallet, kit, etc).

Key fields:
- container_id (PK)
- location_code
- container_type_id
- goes_to (endpoint)
- width_in_override
- depth_in_override
- height_in_override
- display_pallet
- testing_after_takedown

---

## ref.container_type
Defines default dimensions.

Key fields:
- container_type_id (PK)
- containter_type_name
- default_width_in
- default_depth_in
- default_height_in
- is_stackable_default

---

## ref.container_endpoint
Defines setup endpoint/destination.

Key fields:
- endpoint_id
- endpoint_name

---

## ref.display
Represents a physical display.

Key fields:
- display_id (PK)
- lor_prop_id
- display_name
- container_id
- stage_id
- string_type  (Traditional, DumbRGB, RGB)
- color
- inventory_type
- display_status_id

string_type and color are LOR-owned read-only fields.

---

## ref.stage
Stage metadata.

Key fields:
- stage_id
- stage_name
- stage_key

---

## ref.person
Users / volunteers.

Key fields:
- person_id
- first_name
- last_name
- preferred_name
- is_manager
- is_team
- active_flag

---

# 2. Operational Tables (ops schema)

## ops.test_session
Represents a container testing session.

Key fields:
- test_session_id (PK)
- container_id
- status (NOT_STARTED / IN_PROGRESS / DONE)
- season_year
- done_at
- done_by

One session per container per season.

---

## ops.display_test_session
Child records for testing displays within a container.

Key fields:
- display_test_session_id (PK)
- test_session_id (FK)
- display_id (FK)
- stage_id
- test_result (OK / REPAIR / REPAIRED / DEFER / etc.)
- checked_at
- checked_by
- amps_measured
- notes

Represents one display’s test result within a session.

---

## ops.work_order
Repair workflow table.

Key fields:
- work_order_id (PK)
- display_test_session_id (FK)
- display_id (FK)
- stage_id
- work_area_id
- urgency
- problem
- notes
- photo_url
- date_completed
- completed_by_person_id
- completion_notes

When completed, the linked display_test_session row is updated to:
- test_result = 'REPAIRED'
- checked_at (if null)
- checked_by (derived from ref.person)

---

# 3. UI-Facing Views (ops.v_*)

These views are designed specifically for Directus.

## ops.v_container_testing_summary

One row per container testing session.

Includes:
- test_session_id
- container_id
- container_status
- endpoint_name
- container_type_name
- resolved dimensions
- display_total
- display_checked
- display_remaining
- last_checked_at
- flags (display_pallet, testing_after_takedown)

Purpose:
Container Testing Dashboard.

---

## ops.v_container_testing_displays

Child grid view for displays within a container.

Includes:
- display_name
- stage_name
- string_type
- color
- checked_at
- test_result
- amps_measured
- notes

Purpose:
Container Focus screen (child grid).

---

## ops.v_stage_container_contents

Stage-based browse tool.

Includes:
- stage_name
- container_id
- container_status
- display_name
- string_type
- color

Purpose:
Choose container by skill level.

---

## ops.v_work_order_open

Open work orders queue.

Includes:
- work_order_id
- urgency
- stage_name
- display_name
- container_id
- problem
- created_at

Purpose:
Work Orders queue screen.

---

# 4. Data Flow Rules

## Testing Flow

1. Container session exists.
2. display_test_session rows exist.
3. Users update checked_at, test_result, amps_measured.
4. Container status rolls up from child rows.

---

## Repair Flow

1. display_test_session marked REPAIR.
2. Work order created.
3. Work order completed.
4. Linked display_test_session updated to REPAIRED.

No DB triggers. Directus Flow handles update.

---

# 5. Naming Rules

- No year-based view names.
- Views prefixed with v_.
- Tables meaningful and stable.
- UI improvements do not require schema changes unless functional.

---

# End of Document