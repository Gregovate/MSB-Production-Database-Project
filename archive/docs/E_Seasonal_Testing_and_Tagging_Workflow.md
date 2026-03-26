# E_Seasonal_Testing_and_Physical_Tagging_Workflow (Phase 3)

Status: Draft  
Owner: Production System  
Related Documents:
- A_System_Blueprint.md
- D_Database_Structure.md
- (Future) F_Staging_Waves_and_Picklists.md

> STATUS: REFERENCE / ARCHIVE ONLY — DO NOT USE AS LIVE SOP
---

## Change Log

### v0.1 – Initial Definition
- Defined seasonal testing lifecycle
- Defined repair tag vs pallet green tag model
- Defined LAN-based label printing integration
- Linked workflow to Work Orders module

---

## 1. Purpose

At the beginning of each season, all displays are tested in the shop prior to staging and deployment.

The system must support large-scale tracking (900+ displays) with clear operational visibility and auditable status reporting.

This workflow governs:
- Display-level testing
- Repair identification and tracking
- Pallet readiness determination
- Physical tagging alignment with system state

---

## 2. Season Definition (Calendar-Based with Mid-January Closeout)

- Seasons are labeled by calendar year (e.g., **2025**, **2026**).
- Operationally, the prior season ends when all displays are returned to the workshop and put away (typically mid-January).
- The next season begins immediately after closeout.
- The system shall treat one season as **Active** at a time for:
  - Testing work order generation
  - Staging plans
  - Reporting and dashboards

Season identity and lifecycle are governed by `ref.season`.

---

## 3. Display-Level Testing Workflow

### 3.1 Test Initialization

- One testing work order is generated per display at season start.
- Each display receives a seasonal testing status record.

Initial status:
- `UNTESTED`

### 3.2 Testing Outcomes

During testing:

- If the display passes → `PASS`
- If issues are found → `NEEDS_REPAIR`

When `NEEDS_REPAIR`:
- A repair tag is physically wired to the display.
- The same work order remains open.
- The work order may transition:

  `TEST → REPAIR → RETEST → PASS`

Repair status remains open until:
- The issue is corrected
- The display is successfully re-tested

### 3.3 Display Status States

Seasonal display status values:

- `UNTESTED`
- `PASS`
- `NEEDS_REPAIR`
- `RETEST_REQUIRED` (optional intermediate state)

Display seasonal status is stored in:
- `prod.display_season_status`

---

## 4. Pallet-Level Readiness

A pallet is considered **READY** only when all displays assigned to the pallet have `PASS` status for the active season.

### 4.1 Readiness Rules

- If any display is `UNTESTED` → pallet is NOT READY
- If any display is `NEEDS_REPAIR` → pallet is NOT READY
- Only when all displays are `PASS` → pallet becomes READY

Pallet seasonal readiness is stored in:
- `prod.pallet_season_status`

### 4.2 Physical Green Tag

When a pallet becomes READY:

- A green physical tag is applied to the pallet.
- An optional black printed label may be generated for identification.
- Tag application may optionally be recorded in the system (`ready_tag_applied = true`).

---

## 5. Label Printing (LAN Printer Support)

The system supports LAN-based red/black sticker printing.

### 5.1 Repair Labels
- Printed when a display transitions to `NEEDS_REPAIR`
- Red emphasis for visibility
- Applied to wired repair tags attached to the display

### 5.2 READY Labels
- Printed when a pallet transitions to READY
- Black format for pallet identification
- Applied to the physical green pallet tag

### 5.3 Audit

All print actions are logged in:
- `prod.label_print_job`

The database state remains authoritative regardless of physical tag presence.

---

## 6. Design Principles

- Database state is authoritative.
- Physical tags reflect system state but do not replace it.
- Seasonal testing status must be fully queryable and reportable.
- Repair tracking must remain tied to Work Orders.
- Pallet readiness must be deterministically derived from display status.

---

## 7. System Dependencies

- `ref.season`
- `prod.display`
- `prod.display_season_status`
- `prod.pallet_season_status`
- `prod.work_order`
- `prod.label_print_job`