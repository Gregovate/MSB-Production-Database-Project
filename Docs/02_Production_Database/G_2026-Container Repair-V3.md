# MSB Production DB — Container Testing & Repair Workflow (Go-Live Draft)
Version: 2026-02-28 (V3)
Owner: Greg
Scope: Volunteer-facing operational workflow + the one key system decision (when child rows get created)

Related docs (source material / earlier drafts):
- G_2026_Testing_SOP.md
- G_2026_Rev_A_Container Testing & Repair Operations Guide_rev_A.md

---

## 1) What we’re solving (in plain English)

We are moving from a legacy spreadsheet that acted like “one big seasonal checklist” to a database workflow that:
- tracks containers being worked over multiple days,
- supports multiple volunteers working the same container,
- preserves history by season,
- and reduces tribal knowledge.

For 2026 we must **not lose work already done** (legacy sheet entries), but we also must stop the drift and go live with a consistent process.

---

## 2) Definitions volunteers must understand

### Container
A physical unit (pallet/tote/box/etc.) identified by **container_id** in the system.

### Home Location
Where the container **normally lives in storage** when not being worked.
- Stored on the parent record as `home_location_code`.
- If the container ends up living somewhere else permanently, that is a **move/update event**, not “just a note.”

### Work Location
Where the container is being worked **right now** (example: TEST-FLOOR, REPAIR-AREA, BENCH-2).
- Stored on the parent record as `work_location_code`.
- This supports “pull to work area” and helps everyone find what’s in progress.

### Status (non-demeaning, volunteer-friendly)
A container can be:
- **NOT_STARTED**: nobody has started checking displays yet.
- **IN_PROGRESS**: someone started, but it’s not fully complete.
- **DONE**: container is complete for the season.

### Tag State (the physical/visual interpretation)
Stored on the parent record (because you need it for filtering and printing tags):
- **GREEN** = Ready for season (all required checks done, no unresolved issues)
- **YELLOW** = anything incomplete, deferred, missing, or repair required
- **RED** = Obsolete / removed from show (not part of seasonal testing workflow)

> “Deferred” must be written as **workflow reality**, not volunteer failure:
> - Deferred can mean missing display (out for repair), missing controller, missing equipment/skill on the floor that day, or a test that must be completed later.

---

## 3) The key decision (THIS is what you asked for)

### Decision: When do child rows get created?

**Answer / Recommendation (go-live practical + long-term sane):**

✅ **Create child rows at the moment the season’s container session is created (“snapshot checklist”).**  
Not dynamic-on-open.

Why:
- You need a stable checklist for the season (what should be on the container for 2026).
- You need to support “what was expected vs what was found” (missing display detection).
- It avoids drift mid-session when ref assignments change.
- It makes “DONE” calculation straightforward and auditable.

**Long-term:** we can introduce “Add Display to Session” (allowed for volunteers) to handle real-world changes without rewriting history.

---

## 4) Who does what (roles)

### Forklift operator (or anyone able to move containers safely)
- Moves the container from Home Location to Work Location.
- In the UI, they record the move (they don’t need to be a “manager”).

### Volunteers (testers / repair helpers)
- Work the checklist (child rows).
- Record results, notes, presence/absence, and what was replaced.

### Manager (initially Greg; later delegated)
- Approves/queues structural corrections (container/display assignment corrections) when needed.
- Resolves weird edge cases (found-on-wrong-container, duplicates, etc.).

---

## 5) Volunteer workflow (what happens in my.sheboyganlights.org)

### 5.1 Pull a container to the work area (starts/opens the session)
In the UI (my.sheboyganlights.org):
1) Find container in **Testing Queue**
2) Set:
   - `work_location_code` = where it’s going
   - optional: `pulled_by` (name/initials)
   - optional: note (“moved for testing”)

**Important:** For the new workflow, “pulled_at” reflects when work actually begins (first check), not “we moved it.”  
(For 2026 backfill, we’ll derive pulled_at from the earliest checked record.)

### 5.2 Test/check displays (child checklist)
For each display row on the container:
- Mark **present / not present**
- Record:
  - test result (PASS/FAIL/DEFERRED as appropriate)
  - checked time + who
  - notes (what was replaced, symptoms, etc.)

If a quick repair is completed in place:
- write what was replaced (ex: “replaced 2× 100ct mini strings”)
- if applicable: trigger/record a new amp measurement (later system step can prompt this)

### 5.3 If something is missing / can’t be finished today (Deferred)
Use **YELLOW** without blaming:
- Missing display (likely in repair area / moved during teardown / found elsewhere)
- Controller not tested yet (needs bench time / right cable / skilled volunteer)
- Requires equipment that’s not available today

### 5.4 If repair is required (Red)
- Mark the affected display row as needing repair (or FAIL + notes).
- If the item must be moved off the container:
  - mark “moved_to_repair_area” (or equivalent note/state)
  - physically move the display to the repair area process (work orders can be created/linked later)

### 5.5 When a repaired item is finished
Two possibilities:

A) **Repair finished before container goes back**
- Put display back on its container.
- Update the child row to PASS (or “retested OK”).
- Update amps/light-count if changed.

B) **Repair finished later**
- The container may sit YELLOW (incomplete) until the display returns,
  OR it can be moved back home with a YELLOW tag if that’s operationally necessary.
- When the display returns, the volunteer updates the checklist row to complete it.

### 5.6 Return container to storage (closing loop)
When work pauses or completes, a forklift operator (or assigned volunteer) moves the container:
- Back to `home_location_code` (normal case), or
- To a new location (exception case)

In the UI:
- set `work_location_code` (or clear it)
- if moved back to storage:
  - set `returned_to_storage_at`
  - set `returned_to_storage_by`

If the container’s **new permanent home** is different:
- this is a **location correction workflow** (manager/queue), not a “testing” action.

---

## 6) System behavior we will implement (Postgres + Directus)

### 6.1 Creating the season snapshot (parents + children)
For season 2026:
1) Build/refresh the parent list from containers (one row per container for season)
2) For each parent, auto-create child rows from **ref.display assignments**:
   - match on `ref.display.container_id`
   - exclude anything SPARE (already removed from ref.display; but still guard it anyway)
   - only include “real” displays intended for work/testing

This creates the checklist that volunteers work from.

### 6.2 Completing a container

A container becomes:

- **GREEN + DONE**  
  All required child rows are checked, no missing displays, and no unresolved repair or deferred items.

- **YELLOW + NOT_STARTED / IN_PROGRESS / DONE (as applicable)**  
  Any of the following:
  - Incomplete testing
  - Deferred items
  - Missing display(s)
  - Repair required
  - Waiting on controller testing
  - Work paused

- **RED (Inventory State Only)**  
  RED is not a testing workflow state.  
  It represents an obsolete or removed-from-show display in inventory and is handled in reference data, not container testing.

## 7) 2026 Backfill (so we don’t lose what’s already been done)

We will backfill in two layers:

### Layer 1 — Normalize parent sessions for 2026
- Set `pulled_at` and `done_at` based on child activity:
  - `pulled_at` = earliest checked time (or earliest checked_date_text converted if that’s all we have)
  - `done_at`   = latest checked time (same rule)
- Use `pulled_by = 'LEGACY'` (or similar) so everyone knows it was pre-cutover.
- Set status/tag state based on the checklist completeness rules above.

### Layer 2 — Align child records with authoritative reference data
For each `ops.display_test_session` row:
- populate `stage_id`, `amps_measured`, `light_count` from `ref.display`
- never overwrite volunteer-entered results; only fill blanks or derived fields

**Critical guardrails:**
- SPARE items are excluded from any work list and any “DONE” calculation.
- If legacy rows reference displays that don’t match ref.display/container assignments, they must be flagged for review (queue), not silently forced.

---

## 8) What we still need to decide (small but required)

1) If a container is moved to a new home location during the season:
   - do we allow “manager update home_location_code” immediately,
   - or do we require a queued move request?
   (Recommendation: queue for now; later add a clean utility UI.)

2) How we represent “controller testing” separately (future).
   For go-live, it can be captured as:
   - deferred + notes,
   - or a minimal extra field later.

---

## 9) Go-live checklist

We can go live when:
- A fresh 2026 snapshot exists (parents + children) driven from ref.display container assignments
- Legacy work is ingested/backfilled so “touched vs untouched” is real
- Work location + home location are visible in the parent view
- Volunteers can:
  - pick a container
  - work the checklist
  - mark deferred/repair without shame language
  - return container and close the loop

---

## 10) One-line answer to the “child table grows or static?” question

**Child rows are created once per season per container when the session snapshot is created, and then they only change by volunteer updates (plus allowed ‘add display to session’).**