# MSB Production DB — Container Testing & Repair Workflow (Go-Live Draft)
Version: 2026-02-28 (V3)
Owner: Greg
Scope: Volunteer-facing operational workflow + the one key system decision (when child rows get created)

Related docs (source material / earlier drafts):
- Revised 2026-03-02 for final workflow
- G_2026_Testing_SOP.md
- G_2026_Rev_A_Container Testing & Repair Operations Guide_rev_A.md

---
## Purpose

Define the official workflow for testing and repairing displays grouped by container for a given show season.

This document establishes:
- Source-of-truth rules
- Seasonal repair session behavior
- Display-level testing logic
- Container movement and return policy
- Completion rules

---

## 1) What we’re solving (in plain English)

We are moving from a legacy spreadsheet that acted like “one big seasonal checklist” to a database workflow that:
- tracks containers being worked over multiple days,
- supports multiple volunteers working the same container,
- preserves history by season,
- and reduces tribal knowledge.

For 2026 we must **not lose work already done** (legacy sheet entries), but we also must stop the drift and go live with a consistent process.

### Key Principles

- LOR controls park placement.
- ref.* controls identity and structure.
- ops.* controls seasonal workflow.
- No operational flags are stored in reference tables.
- A container has one repair session per season.
- Completion locks the pallet for that season.
---

## 2) Definitions volunteers must understand
 1. Sources of Truth

## Light O Rama
Authoritative source of where a display is installed in the park:
- `lor_snap.props`
- `lor_snap.previews'
- `lor_snap.DMX Channels`
- 

This data is read-only for operations.

## Display Identity
Authoritative source of display metadata:
- `ref.display`

Includes:
- display_name
- amps_measured
- light count
- theme
- frame
- designer
- year built
- status
- string type (Traditiional, DumbRGB, RGB)
- container assignment
  
## Container Storage Location
Authoritative storage location:
- `ref.container.location_code`
- FK to `ref.storage_location.location_code`

This represents the pallet's home storage location.
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

### Status 
A container can be:
- **NOT_STARTED**: nobody has started checking displays yet.
- **IN_PROGRESS**: someone started, but it’s not fully completed
- **DEFERRED**: Testing started but could not be completed due to additional testing RGB, or waiting for repair to be completed
- **DONE**: container is complete for the season.

### Tag State (the physical/visual interpretation)
Stored on the parent record (because you need it for filtering and printing tags):
- **GREEN** = Ready for season (all required checks done, no unresolved issues)
- **YELLOW** = anything incomplete, deferred, missing, or repair required
- **RED** = Obsolete / removed from show (not part of seasonal testing workflow)

> “Deferred” must be written as **workflow reality**, not volunteer failure:
> Deferred can mean missing display (out for repair), missing controller, missing equipment/skill on the floor that day, or a test that must be completed later.

---

## 3) The key decision (THIS is what you asked for)

### Decision: When do child rows get created?

**Answer / Recommendation (go-live practical + long-term sane):**

✅ **Create child rows at the moment the container is pulled for testing**  
- Need a function and button to do this
  
---

## 4) Who does what (roles)

### Forklift operator (or anyone able to move containers safely)
- Moves the container from Home Location to Work Location.
- In the UI, they record the move "Container pulled" (they don’t need to be a “manager”).

### Volunteers (testers / repair helpers)
- Work the checklist (child rows).
- Record results, notes, presence/absence, and what was replaced.

### Manager (initially Greg; later delegated)
- Approves/queues structural corrections (container/display assignment corrections) when needed.
- Resolves weird edge cases (found-on-wrong-container, duplicates, etc.).

---

## 5) Volunteer workflow (what happens in my.sheboyganlights.org)

### 5.1 Pull a container to the work area (starts/opens the session)
In the UI (db.sheboyganlights.org):
1) Find container in **Test Session**
2) Set:
   - `work_location_code` = where it’s going
   - optional: `pulled_by` (name/initials auto completed by system)
   - optional: note (“moved for testing”)

**Important:** For the new workflow, “pulled_at” reflects when container pulled and put into work area.

### 5.2 Test/check displays (child checklist)
For each display row on the container:
- Mark **present / not present**
- If a display is not found during testing:
- `found_on_pallet = false`
- `missing_display_flag = true` on the parent pallet_repair

- Record:
  - test result (OK/REPAIR/DEFER as appropriate)
  - checked time + who (Auto complete by user logged in and timestamped)
  - notes (what was replaced (on-floor repairs not needing designed wiring), symptoms, etc.)

If a quick repair is completed in place:
- write what was replaced (ex: “replaced 2× 100ct mini strings”)
- if applicable: trigger/record a new amp measurement (later system step can prompt this)

### 5.3 If something is missing / can’t be finished today (Deferred)
Use **YELLOW** without blaming:
- Missing display (likely in repair area / moved during teardown / found elsewhere)
- Controller not tested yet (needs bench time / right cable / skilled volunteer)
- Requires equipment that’s not available today

### 5.4 If repair is required (YELLOW)
- Mark the affected display row as needing repair (or REPAIR + notes).
- If the item must be moved off the container:
  - Fill out (print) YELLOW TAG and wire to display
  - Work order auto created
  - mark “moved_to_repair_area” on Yellow tag and wire to container 
  - physically move the display to the repair area process 

### 5.5 When a repaired item is finished
Two possibilities:

A) **Repair finished before container goes back**
- Complete work order, this sets the flag on the diplay to OK
- Put display back on its container.
- Update amps/light-count if changed.

B) **Repair finished later**
- The container may sit YELLOW (incomplete) until the display returns,
  OR it can be moved back home with a YELLOW tag if that’s operationally necessary.
- When the display returns, put the display back on the container and remove yellow tag if only waiting for that display to return.

### 5.6 Return container to storage (closing loop)
When work pauses or completes, a forklift operator (or assigned volunteer) moves the container:
- Back to `home_location_code` (normal case), or
- To a new location (and update container to a new home location)

In the UI:
- set `work_location_code` (or clear it)
- if moved back to storage:
  - set `returned_to_storage_at`
  - set `returned_to_storage_by`

If the container’s **new permanent home** is different:
- this is a **location correction workflow** (manager/queue), not a “testing” action.

A pallet is complete when:

- All displays are tested
- Repairs are identified
- Missing items are flagged
- Green tag printed

Then:
- `status = 'done'`
- `done_at` and `done_by` recorded

Completed pallets do not appear in the active repair queue.

# 5.7 Pallet Move Workflow (Future)

When assigning a pallet to a storage location:

1. Select rack / column / shelf / slot
2. If slot does not exist, allow creation
3. If slot occupied:
   - Prompt to unassign existing pallet
4. Assign pallet
5. Record move event in `ops.pallet_move`

This ensures safe, auditable pallet reassignment.

---

## 6) System behavior we will implement (Postgres + Directus)

### 6.1 Creating the season snapshot (parents + children)
For season 2026:
1) Build/refresh the parent list from containers (one row per container for season)
2) For each parent, auto-create child rows when container is pulled for testing from **ref.display assignments**:
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

**Child rows are created once per season
 per container when the container is pulled for testing, and then they only change by volunteer updates (plus allowed ‘add display to session’).**