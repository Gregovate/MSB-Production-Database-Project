# MSB Ops — 2026 Bridge Plan (Legacy → Go-Live)
**Date:** 2026-02-27  
**Author:** GAL  
**Scope:** Backfill 2026 testing so we don’t lose work already done, while switching to the new SOP + Directus workflow next week.

---

## 0) What we know is true right now

### Tables in play
**Parent:** `ops.test_session`
- `test_session_id` (bigint)
- `season_year` (int)
- `container_id` (int)
- `status` (text)
- `home_location_code` (text)
- `work_location_code` (text)
- `pulled_at` (timestamptz)
- `pulled_by` (text)
- `returned_to_storage_at` (timestamptz)
- `returned_to_storage_by` (text)
- `remaining_notes` (text)
- `done_at` (timestamptz)
- `done_by` (text)
- `notes` (text)

**Child:** `ops.display_test_session`
- `display_test_session_id` (bigint)
- `test_session_id` (bigint)
- `lor_prop_id` (text)
- `is_display_present` (boolean)
- `checked_at` (timestamptz)
- `checked_by` (text)
- `notes` (text)
- `checked_date_text` (text)
- `stage_id` (**currently integer — wrong for 07a**)
- `test_result` (text)
- `amps_measured` (numeric)
- `light_count` (int)

**Legacy Raw:** `stage.test_plan_2026_raw`
- Per-row spreadsheet snapshot (container-level + display-level mixed together)
- Has `date_tested_text` (text), but spreadsheet itself used validated date format.

### Design principles (non-negotiable)
1. **LOR is authoritative** for stage and display identity.
2. `ref.display` is the latest reference snapshot (LOR-owned attributes update on import; non-LOR attributes preserved).
3. We do **not** rewrite history:
   - What’s already marked done stays done.
4. 2026 legacy data is a bridge. We will tag it clearly using `pulled_by = 'LEGACY'`.

---

## 1) Key decision: How child rows are created going forward

### New system (go-live)
- A `test_session` is created when a container is *pulled for work* (or scheduled/started).
- At creation time, we create the checklist rows in `ops.display_test_session` by snapshotting “what is on the container” from `ref.display` at that moment.
  - This preserves the checklist for multi-day work.
  - Supports multiple people working the same container.
  - Supports “NOT_PRESENT” and “found later” scenarios.
- Child rows are then updated as volunteers test/inspect.

**Why snapshot is preferred:**  
A dynamic checklist changes under your feet if container assignments are being corrected while the session is underway. Snapshot keeps the session stable and auditable.

---

## 2) 2026 Bridge Strategy (how we keep what’s already been done)

We have:
- 2026 sessions already created (parent list of containers)
- Some child tests already entered (spreadsheet / partial child rows)
- Parent pulled/done fields are mostly empty or wrong because the SOP wasn’t finalized when data entry started.

### Bridge goal
Backfill parent rows from child work *without losing anything*.

### Bridge rules
For `season_year = 2026` only:

1. **pulled_at** = earliest known “worked” timestamp for that container/session  
   - derived from child `checked_at` if present  
   - else derived from parsing child `checked_date_text` when possible  
   - else NULL (container truly untouched)

2. **pulled_by** = `'LEGACY'` if we set `pulled_at` via backfill  
   - This clearly marks “pre go-live” activity.

3. **done_at** = latest known “worked” timestamp for that container/session  
   - same sources as above

4. **done_by** = `'LEGACY'` when done_at is set by backfill

5. **status** is set based on child completion state:
   - If no child rows show work: `NOT_STARTED` (or keep existing if you already use something else)
   - If some work exists but not complete: `IN_PROGRESS`
   - If all required non-spare displays are complete: `COMPLETE`

6. “SPARE” rows are excluded from completion logic.
   - Detect SPARE via display name or channel name containing `spare` (case-insensitive).
   - These should not block completion of a container.

---

## 3) Required schema tweaks to make this sane (minimal)

### A) Fix stage typing on child table
`ops.display_test_session.stage_id` cannot be integer if stage keys include `07a`.

**Preferred for 2026:** store `stage_key` as TEXT on child rows.
- Either change `stage_id` to text
- OR add `stage_key text` and stop using int stage_id in ops child rows

### B) Add a `is_spare` boolean on the child table (recommended)
Stops “SPARE” logic from being duplicated everywhere.

---

## 4) Backfill Plan (high level steps)

### Step 1 — Ensure reference data is current
- Run LOR import workflow (latest import_run)
- Run stage upsert from latest LOR
- Run display upsert from latest LOR
- Confirm `ref.display.stage_id` is populated where applicable

### Step 2 — Populate child attributes from `ref.display` (safe fills)
For 2026 child rows:
- Fill `amps_measured` where NULL using `ref.display.amps_measured`
- Fill `light_count` where NULL using `ref.display.est_light_count` (or accurate count if exists)
- Fill stage (as text key or mapped id) using `ref.display.stage_id`

**Rule:** only fill NULLs in ops child table (do not overwrite real work).

### Step 3 — Backfill parent pulled/done fields from child activity
For each `ops.test_session` in 2026:
- Determine earliest activity timestamp
- Determine latest activity timestamp
- If earliest exists and `pulled_at` is NULL → set pulled_at and pulled_by='LEGACY'
- If latest exists and container is complete → set done_at and done_by='LEGACY'
- Set `status` accordingly

### Step 4 — Lock in 2026 “bridge state”
Once backfill is correct:
- Treat existing 2026 sessions as the official tracking set until go-live
- New sessions after go-live follow the SOP (not marked LEGACY)

---

## 5) SOP Notes (for team meeting)

### Roles
- **Volunteer (Forklift-capable):** can pull containers and start sessions
- **Volunteer (Testing):** can mark displays present/checked, add notes, flag repairs
- **Manager (initially Greg):** can approve/perform container assignment corrections

### Real-world constraints supported
- Multiple volunteers can work one container simultaneously
- Containers can be worked across multiple days
- Displays can be removed for repair (container becomes YELLOW/RED until resolved)
- A session may be returned to storage while not complete (deferred/transition state)

---

## 6) Open items to finalize (last mile)

1. Define “complete” precisely for 2026:
   - What child fields mean “tested enough”
   - Minimum required to mark GREEN (vs YELLOW/RED)

2. Decide how to represent “missing display” and “moved for repair”
   - One field state is preferred over many booleans (KISS)

3. Decide how we queue container assignment corrections
   - For now: queue is safest; manager approves

---

## 7) Why we use pulled_by = 'LEGACY'
Because 2026 already has work done before the new UI/SOP is live.
We need a permanent marker to separate:
- Backfilled activity derived from the legacy spreadsheet
vs
- True system-driven activity after go-live.

This is not a person; it’s a provenance tag.

---