# Pallet Repair Workflow (Seasonal)

## Purpose

Define the official workflow for testing and repairing displays grouped by pallet for a given show season.

This document establishes:
- Source-of-truth rules
- Seasonal repair session behavior
- Display-level testing logic
- Pallet movement and return policy
- Completion rules

---

# 1. Sources of Truth

## Park Placement
Authoritative source of where a display is installed in the park:
- `lor_snap.props`

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
- pallet assignment

## Pallet Storage Location
Authoritative storage location:
- `ref.pallet.location_code`
- FK to `ref.location.location_code`

This represents the pallet's home storage location.

## Operational State
All repair/testing state is stored in:
- `ops.pallet_repair`
- `ops.pallet_repair_display`

No operational flags are stored in `ref.*` tables.

---

# 2. Seasonal Repair Concept

A **Pallet Repair Session** represents:

> "This pallet was pulled for testing/repair for Season YYYY."

Each pallet may have **only one repair session per season**.

Enforced by:

unique (season_year, pallet_id)


This prevents duplicate testing sessions for the same pallet within the same season.

---

# 3. Pulling a Pallet for Testing

When a pallet is pulled:

1. Create a row in `ops.pallet_repair`
2. Snapshot:
   - `home_location_code` = `ref.pallet.location_code`
3. Set:
   - `work_location_code` = testing location (ex: `WORK-AREA`)
4. Auto-populate child rows from displays assigned to the pallet

The pallet is considered "In Testing" when:

exists active ops.pallet_repair row


No flag is stored in `ref.pallet`.

---

# 4. Display-Level Testing (Child Grid)

Each display row must show:

## Read-Only Columns
- display_name
- amps_measured
- light_count
- stage (from `lor_snap.props`)

## Editable Columns
- found_on_pallet
- tested_ok
- repair_needed
- relabel_done
- moved_to_repair_area
- done
- notes

Stage is always read-only and comes from LOR data.

---

# 5. Repair Handling

If a display:
- Fails testing
- Has lights out
- Needs relabeling

Then:

1. Mark `repair_needed = true`
2. Optionally print red repair tag
3. Move display to repair area
4. Mark `moved_to_repair_area = true`

The display remains logically assigned to the pallet during the session.

---

# 6. Missing Displays

If a display is not found during testing:
- `found_on_pallet = false`
- `missing_display_flag = true` on the parent pallet_repair

This allows reporting of incomplete pallets.

---

# 7. Completing a Pallet

A pallet is complete when:

- All displays are tested
- Repairs are identified
- Missing items are flagged
- Green tag printed

Then:
- `status = 'done'`
- `done_at` and `done_by` recorded

Completed pallets do not appear in the active repair queue.

---

# 8. Return to Storage Rule

When testing is complete:

- Pallet must be returned to `home_location_code`
- The system should validate return location matches snapshot

If relocation is required, it must be handled through the pallet move workflow.

---

# 9. Pallet Move Workflow (Future)

When assigning a pallet to a storage location:

1. Select rack / column / shelf / slot
2. If slot does not exist, allow creation
3. If slot occupied:
   - Prompt to unassign existing pallet
4. Assign pallet
5. Record move event in `ops.pallet_move`

This ensures safe, auditable pallet reassignment.

---

# 10. Key Principles

- LOR controls park placement.
- ref.* controls identity and structure.
- ops.* controls seasonal workflow.
- No operational flags are stored in reference tables.
- A pallet has one repair session per season.
- Completion locks the pallet for that season.

---

# Status

Initial repair workflow design finalized prior to table creation.