# MSB Work Order System — Database Design Spec (v1.1)
**Project:** MSB Database (Production Ops)  
**Owner:** Greg (Production Crew)  
**Status:** Final — approved for DDL + Import build  
**Scope:** Data model + constraints + import/validation rules. (No UI how-to here.)

---

# 1) Purpose
Stand up a DB-first work order system that supports:

- Display repair tickets (primary immediate need)
- Non-display operational tasks (facility, office, shop, command center, etc.)
- Long-term planning items (target year) and short-term urgency (triage)
- Manager-controlled assignments
- Clean completion capture (who + when + what was done)
- Import of all existing history from Google Sheets (To do + Completed)
- Automatic integration with **display testing repair workflow**

The database becomes the single source of truth for creating, assigning, completing, and tracking work orders.

---

# 2) Source-of-truth and boundaries

## 2.1 Source-of-truth
Postgres is the single system of record for work orders.

## 2.2 Legacy systems
Google Form + Google Sheets currently contain historical work orders and can remain as intake temporarily.

Once DB intake/UI is live, Google can be retired or left as **legacy read-only intake**.

## 2.3 Completion detection
Completion is derived from `date_completed`.

| Status | Rule |
|------|------|
Open | `date_completed IS NULL` |
Completed | `date_completed IS NOT NULL` |

The system may populate completion fields automatically through database triggers.

---

# 3) Entities and responsibilities

## 3.1 Reference entities (canonical lists)

### A) `ref.stage` (EXISTS)

Canonical list of park stages.

Stages remain conceptual locations year-round even if physical items are removed during the off-season.

---

### B) `ref.work_area` (NEW — NON-STAGE locations only)

Represents operational locations that are NOT stages.

Examples:

- Office
- Command Center
- Wood Shop / Workshop
- Food Bank facility / ramp
- Volunteer trailer
- Storage trailer / container

**Important:** stages are **not duplicated** in `ref.work_area`.

---

### C) `ref.task_type` (NEW)

Canonical list of work categories.

Examples:

- Repair
- Build
- Setup
- Design
- Testing
- Wiring
- Purchasing
- Maintenance

---

### D) `ref.person` (EXISTS)

Contains identity and permission fields.

There is no separate `ref.user` table.

Must include:

- unique email
- manager boolean

---

# 4) Core operational tables

## 4.1 `ops.work_order` (MAIN TABLE)

A work order represents a single actionable task.

Examples:

- display repair ticket
- build/setup task
- maintenance item
- operational facility work
- planning task

A work order answers:

- Where is the work? (stage OR work_area)
- What is the work? (optional display link)
- What category? (task_type)
- How urgent? (urgency)
- When should it happen? (target_year)
- Is it complete? (completion fields)
- What work was done? (completion_notes)

---

## 4.2 `ops.work_order_assignee`

Assignments are normalized.

A work order may have **zero, one, or many assignees**.

This avoids comma-separated assignment lists and reflects real volunteer work patterns.

---

# 5) Location model (FOUNDATIONAL — Option 1 locked)

Each work order must reference **exactly one** location.

## XOR rule

Exactly one of these must be set:

- `stage_id`
- `work_area_id`

Constraint enforces mutual exclusivity.

---

# 6) Priority model (FOUNDATIONAL — split locked)

Legacy "Priority" field represented two different concepts.

These are separated.

## 6.1 Urgency

Triaging indicator.

Values:

| Value | Meaning |
|------|------|
1 | Immediate |
2 | High |
3 | Medium |
4 | Low |

`NULL` = not triaged

---

## 6.2 Target Year

Planning horizon.

Examples:


2026
2027


Independent from urgency.

---

## 6.3 Preserve raw legacy value

Legacy imports store the original value in:


legacy_priority_raw


---

# 7) Completion model (FINAL IMPLEMENTATION)

## 7.1 Completion fields

| Field | Purpose |
|------|------|
date_completed | timestamp when work finished |
completed_by_person_id | who completed the work |
completion_notes | description of work performed |

---

## 7.2 Completion trigger mechanism

Work orders include an operational checkbox:


repair_complete boolean NOT NULL DEFAULT false


When this field becomes **true**, a database trigger automatically:

1. Sets `date_completed = now()` if empty
2. Sets `completed_by_person_id` if empty
3. Leaves existing values unchanged

This allows:

- rapid completion for current repairs
- historical backfill without overwriting entered values

---

## 7.3 Completion workflow

Typical repair completion flow:


Technician performs repair
↓
Technician enters completion notes
↓
Technician checks "Repair Complete"
↓
Database trigger stamps:
date_completed
completed_by_person_id


---

# 8) Assignment + permission model

## 8.1 Create rights

Any authenticated volunteer may create work orders.

---

## 8.2 Assignment rights

Only managers may assign work orders.

Manager defined by:


ref.person.manager = true


---

## 8.3 Assignment structure

`ops.work_order_assignee`

Allows multiple people to be assigned.

---

# 9) Display linkage

## 9.1 `display_id`

Nullable reference to display.

Used heavily for:

- automated repair tickets from testing
- tracking repair history per display

---

## 9.2 Why included

Prevents:

- display name drift
- repair tracking errors
- spreadsheet inconsistencies

Allows reporting by display.

---

# 10) Testing System Integration

Automated display testing may generate repair work orders.

When a display test session is marked:


test_status = REPAIR


a work order is automatically created.

When the repair work order is completed:

1. Work order completion fields populate automatically.
2. A Directus flow detects completion.
3. If `display_test_session_id` exists, the system updates the testing record:


test_status = OK_REPAIRED


The display test session notes are updated to prepend repair notes and preserve original testing notes.

---

# 11) Import and history migration rules

## 11.1 Source tabs

Google Sheets tabs:

- **To Do**
- **Completed**

---

## 11.2 Import mapping

To Do → open work orders

Completed → closed work orders

---

## 11.3 Completed-tab validation

Completed rows missing dates must be backfilled.

Backfill rules:

1. Use `date_added` if available
2. Otherwise use import timestamp

---

## 11.4 Legacy priority parsing

Original values stored in:


legacy_priority_raw


Parsing logic attempts to extract:

- `target_year`
- `urgency`

Unparseable values remain NULL.

---

## 11.5 Photos

Photos stored as URLs only.

No blob storage in v1.

---

# 12) Views and operational filters

Derived views replace planning tables.

Examples:

| View | Rule |
|-----|-----|
2026 Plan Open | target_year=2026 AND date_completed IS NULL |
Urgent Work | urgency IN (1,2) AND date_completed IS NULL |
Unassigned | no assignee AND open |
Stage Work | stage_id NOT NULL |
Non-stage Work | work_area_id NOT NULL |

---

# 13) Build order

1. Validate `ref.person` fields
2. Create `ref.work_area`
3. Create `ref.task_type`
4. Create `ops.work_order`
5. Add XOR location constraint
6. Add `repair_complete` column
7. Add DB trigger for completion autofill
8. Create `ops.work_order_assignee`
9. Import legacy history
10. Create views and filters

---

### 2026-03-10 — Repair Workflow Automation + Testing Integration

Display repair workflow completed and integrated with the display testing system.

Key additions:

• `repair_complete` boolean added to `ops.work_order`  
• PostgreSQL trigger to auto-fill `date_completed` and `completed_by_person_id`  
• Trigger designed to **not overwrite manually entered historical values**  
• Simplified repair workflow for technicians using a **Repair Complete checkbox**

Display testing integration:

• Automated creation of repair work orders when testing status = `REPAIR`  
• Completion of repair work orders automatically updates testing results  
• `display_test_session.test_status` updated to `OK_REPAIRED` when repair completed  
• Testing notes updated to prepend repair notes while preserving original testing notes  

Operational improvements:

• Rapid technician completion workflow using **Repair Complete checkbox**  
• Preservation of legacy historical repair records during backfill  
• Closed-loop repair tracking between testing and work order systems  

Outstanding work:

• Core work order operational workflow (assignment and notification system)  
• Email notifications for assigned work orders  
• Full ingestion pipeline from Google Forms / legacy intake  
• Manager assignment UI and workflow finalization  

System status: **Repair workflow operational. Core work order management workflow still in development.**

### 2026-03-03  v1.0  Greg  Initial finalized design specification for work order system. 

---

**End Design Spec**