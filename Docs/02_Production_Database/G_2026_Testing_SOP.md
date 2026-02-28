# MSB Production Database  
# 2026 Transitional Container Testing SOP + Backfill Plan  
### Version: 2026-02-27  
### Author: Greg Liebig  
### Purpose: Stabilize 2026 season data and formalize workflow while transitioning from legacy spreadsheet system to database-driven testing.

---

# 1. OVERVIEW

The 2026 season is a transitional year.

- Containers were pre-created in `ops.test_session`.
- Child display test results exist partially in `ops.display_test_session`.
- A legacy spreadsheet was used during early testing.
- Parent records were not updated during early testing.

This document defines:

A) The official 2026 workflow moving forward  
B) The backfill process to correct existing parent records  

This allows the system to go live within 48 hours without losing work already completed.

---

# 2. DATA MODEL (2026 Transitional)

## Parent Table
`ops.test_session`

One row per container for season 2026.

Represents:
> “This container must be tested for 2026.”

Key fields used for 2026:

- season_year
- container_id
- status (NOT_STARTED | IN_PROGRESS | COMPLETE)
- pulled_at
- pulled_by
- done_at
- done_by
- notes

---

## Child Table
`ops.display_test_session`

One row per display per container.

Represents:
> The test result for a specific display on that container.

Key fields:

- test_session_id
- lor_prop_id
- is_display_present
- checked_at
- checked_by
- stage_id
- test_result
- amps_measured
- light_count
- notes

Displays marked as SPARE are excluded from completeness calculations.

---

# 3. 2026 WORKFLOW (OFFICIAL SOP)

## 3.1 Container States

Each container has:

### Status
- NOT_STARTED
- IN_PROGRESS
- COMPLETE

### Tag State (stored on parent)
- GREEN  → Ready for season
- YELLOW → Partial / Deferred / Transition
- RED    → Repair required

---

## 3.2 When a Container Is First Worked

If no child records have `checked_at`:
- status = NOT_STARTED
- pulled_at = NULL
- done_at = NULL

When first display is checked:
- pulled_at = first checked_at timestamp
- status = IN_PROGRESS

---

## 3.3 During Testing

Volunteers:

- Mark display present/not present
- Record test result
- Record repair needed if applicable
- Add notes as needed
- Update amps if changed
- Update light count if strings replaced

If simple repairs are done on the floor:
- Record what was replaced
- Update amp reading if required

---

## 3.4 Completion Rules

A container is COMPLETE when:

- Every non-SPARE display has been checked
- No displays are marked repair-required
- No displays are deferred

When COMPLETE:
- done_at = latest checked_at
- status = COMPLETE
- tag_state = GREEN

If any display requires repair:
- tag_state = RED
- status remains IN_PROGRESS

If incomplete but no repair:
- tag_state = YELLOW
- status = IN_PROGRESS

---

# 4. BACKFILL PLAN (2026 DATA CORRECTION)

This must be executed before go-live.

## Step 1 – Reset Parent Fields

For 2026:

- pulled_at = NULL
- done_at = NULL
- status = NOT_STARTED

This removes artificial “pre-pulled” values.

---

## Step 2 – Derive Parent Pulled Date

For each container:

If ANY child row has checked_at:

- pulled_at = MIN(checked_at)
- status = IN_PROGRESS

If NONE have checked_at:
- status remains NOT_STARTED

---

## Step 3 – Derive Completion

For each container:

If ALL non-SPARE displays are checked:

- done_at = MAX(checked_at)

Then:

If no repair flags:
    status = COMPLETE
    tag_state = GREEN

If repair flags exist:
    status = IN_PROGRESS
    tag_state = RED

If incomplete:
    status = IN_PROGRESS
    tag_state = YELLOW

---

## Step 4 – Backfill Child Derived Fields

For each row in `ops.display_test_session`:

Populate from `ref.display`:

- stage_id
- light_count
- amps_measured (only if NULL)

This aligns legacy data with authoritative reference tables.

---

# 5. IMPORTANT RULES

1. SPARE displays are excluded from:
   - Completion checks
   - Repair checks
   - Amp calculations
   - Light count totals

2. Parent records are derived from children.

3. No containers are deleted.

4. No sessions are regenerated.

5. 2026 remains single-session-per-container.

Multi-session-per-container can be introduced in 2027.

---

# 6. GO-LIVE CONDITION

The system is ready for go-live when:

- Parent records correctly reflect touched/not touched containers
- Completed containers show COMPLETE + GREEN
- Incomplete containers show IN_PROGRESS
- Repair containers show RED
- Directus views reflect parent status
- No legacy spreadsheet edits continue after cutover

---

# 7. FUTURE (2027+)

After season close:

- Introduce per-pull test sessions
- Implement repair ticket module
- Remove spreadsheet dependency entirely
- Fully automate snapshot at session start

---

