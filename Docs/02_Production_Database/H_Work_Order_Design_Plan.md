# MSB Work Order System — Database Design Spec (v1)
**Project:** MSB Database (Production Ops)  
**Owner:** Greg (Production Crew)  
**Status:** Final — approved for DDL + Import build  
**Scope:** Data model + constraints + import/validation rules. (No UI how-to here.)

---

## 1) Purpose
Stand up a DB-first work order system that supports:
- Display repair tickets (primary immediate need)
- Non-display operational tasks (facility, office, shop, command center, etc.)
- Long-term planning items (target year) and short-term urgency (triage)
- Manager-controlled assignments
- Clean completion capture (who + when + what was done)
- Import of all existing history from Google Sheets (To do + Completed)

The database becomes the single source of truth for creating, assigning, completing, and tracking work orders.

---

## 2) Source-of-truth and boundaries
### 2.1 Source-of-truth
- Postgres is the single system of record for work orders.

### 2.2 Legacy systems
- Google Form + Google Sheets currently contain historical work orders and can remain as intake temporarily.
- Once DB intake/UI is live, Google can be retired or left as “legacy read-only intake.”

### 2.3 No “done flag”
- There is no separate done boolean.
- Completion is derived from `date_completed`:
  - Open: `date_completed IS NULL`
  - Completed: `date_completed IS NOT NULL`

---

## 3) Entities and responsibilities
### 3.1 Reference entities (canonical lists)
#### A) `ref.stage` (EXISTS)
- Canonical list of park stages.
- Stages remain concepts year-round even if physical items are removed off-season.

#### B) `ref.work_area` (NEW — NON-STAGE locations only)
Represents operational locations that are NOT stages, such as:
- Office
- Command Center
- Wood Shop / Workshop
- Food Bank facility / ramp
- Volunteer trailer
- Storage trailer / container

**Important:** stages are **not duplicated** in `ref.work_area`.

#### C) `ref.task_type` (NEW)
Canonical list of work categories:
- Repair, Build, Setup, Design, Testing, Wiring, Purchasing, Maintenance, etc.

#### D) `ref.person` (EXISTS — includes manager boolean)
- Contains identity and permission fields.
- There is no separate `ref.user` table (it was merged into `ref.person`).
- Must include:
  - unique email
  - manager boolean (true/false)

---

## 4) Core operational tables
### 4.1 `ops.work_order` (NEW) — the main work record
A work order is a single actionable item:
- repair ticket
- build/setup task
- planning item

A work order answers:
- Where is it? (stage OR non-stage work area)
- What is it? (optional display link)
- What kind of work is it? (task_type)
- How urgent is it? (optional urgency)
- When do we want to do it? (optional target_year)
- Is it complete? (date_completed + completed_by)
- What was done? (completion_notes)

### 4.2 `ops.work_order_assignee` (NEW) — assignment normalization
Assignments are 0..N people per work order.
- This matches reality and avoids comma-separated assignment text.

---

## 5) Location model (FOUNDATIONAL — Option 1 locked)
We do not maintain stage IDs in a separate work-area table.

### 5.1 XOR rule
Each work order must reference **exactly one** of:
- `stage_id` (FK → ref.stage)  
**OR**
- `work_area_id` (FK → ref.work_area)

**Constraint:** exactly one must be non-null.

### 5.2 Rationale
- Avoid duplicate maintenance of stage keys like WV-07A.
- Allow non-stage operational work orders cleanly.
- Off-season naturally shifts to non-stage areas (shop/storage/etc.), without needing to “disable stages.”

---

## 6) Priority model (FOUNDATIONAL — split locked)
Legacy “Priority” field represented two different concepts. We store them separately.

### 6.1 Urgency (triage)
- `urgency` nullable integer, allowed values 1–4.
- 1 = most urgent (do now)
- 4 = least urgent (still urgent-ish)
- NULL = not triaged / no urgency assigned

### 6.2 Target year (planning)
- `target_year` nullable integer (e.g., 2026, 2027)
- used for long-term plans and reporting views
- independent of urgency (either/both/neither may be set)

### 6.3 Preserve raw legacy value
- `legacy_priority_raw` nullable text to preserve imported value exactly.

---

## 7) Completion model (FOUNDATIONAL)
### 7.1 Completion fields
- `date_completed` nullable timestamp
- `completed_by_person_id` nullable FK → ref.person
- `completion_notes` nullable text (but required by UI at completion time)

### 7.2 Completion button behavior (UI contract)
When a user clicks “Complete”:
- set `date_completed = now()`
- set `completed_by_person_id` based on authenticated user’s email → ref.person
- require “what was done” to be captured (completion_notes)

### 7.3 Backfill rule for imported completed rows
Completed items must not come in “completed” without a completion date.

---

## 8) Assignment + permission model (FOUNDATIONAL)
### 8.1 Create rights
- Any authenticated user in my.sheboyganlights.org may create a work order.

### 8.2 Assignment rights
- Only managers may assign work orders.
- Manager is defined by `ref.person.manager = true`.

### 8.3 Assignment implementation
- `ops.work_order_assignee` supports multiple assignees.
- Assignment at creation is allowed if the creator is a manager.

---

## 9) Display linkage (important, but optional)
### 9.1 `display_id` on work orders
- `display_id` is nullable.
- Used heavily for repair tickets and automated test-generated work orders.
- Not all work orders are display-related.

### 9.2 Why include now
- Prevents “display name in notes” drift.
- Enables reporting by display and integration with testing/repair systems.

---

## 10) Import and history migration rules
### 10.1 Source tabs
- “To do” tab = open work
- “Completed” tab = closed history

### 10.2 Import mapping logic (high level)
- To do → ops.work_order with `date_completed = NULL`
- Completed → ops.work_order with `date_completed NOT NULL`

### 10.3 Completed-tab validation + backfill
During import, detect any rows in Completed with blank completion date.

**Backfill rule:**
1) If `date_added` present → set `date_completed = date_added`
2) Else → set `date_completed = import_timestamp`

Record that a backfill happened (import audit note or a flag in staging).

### 10.4 Legacy priority parsing
- Keep raw value in `legacy_priority_raw`
- Attempt parse:
  - If looks like year (>= 2020) → target_year
  - Else if looks like integer small or P# → urgency
- If unparseable → leave urgency/target_year NULL

### 10.5 Photos
- Store photo hyperlink/URL as text.
- No blob storage in v1.

---

## 11) Views (derived “plans” and ops filters)
We do not create a “plan” table in v1.
We create views/filters based on `target_year`, `urgency`, and completion.

Examples:
- “2026 Plan (Open)” → target_year=2026 AND date_completed IS NULL
- “Urgent Open” → urgency in (1,2) AND date_completed IS NULL
- “Unassigned Open” → no rows in assignee table AND date_completed IS NULL
- “Stage Work Open” → stage_id IS NOT NULL AND date_completed IS NULL
- “Non-stage Work Open” → work_area_id IS NOT NULL AND date_completed IS NULL

---

## 12) Build order (what we implement next)
1) Ensure `ref.person` fields needed are present (email unique, manager boolean)
2) Create `ref.work_area`
3) Create `ref.task_type`
4) Create `ops.work_order` with XOR constraint (stage vs work_area)
5) Create `ops.work_order_assignee`
6) Create staging tables for import
7) Run import + validation/backfill
8) Create initial views/filters

---
**End Design Spec**