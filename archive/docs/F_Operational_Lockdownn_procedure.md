# MSB Production Database  
## LOR Snapshot Import – Production Lockdown Mode

---

# Purpose

This document defines the **permanent production workflow** for importing LOR data into the MSB Production Database.

This version assumes:

- The display spreadsheet is retired.
- All display metadata lives in Postgres.
- LOR is authoritative for structure.
- Postgres is authoritative for metadata.

No manual spreadsheet reconciliation is allowed.

---

# System Model

LOR → SQLite Snapshot → Postgres `lor_snap` → Rebuild `ref.display` → Apply Metadata (internal only)

---

# Authoritative Sources

| Data Type | Source of Truth |
|------------|-----------------|
| Display Identity (UUID / prop_id) | LOR |
| Display Name | LOR (`lor_comment`) |
| Device Type | LOR |
| Channels / Wiring | LOR |
| Amps Measured | Postgres |
| Estimated Light Count | Postgres |
| Theme | Postgres |
| Designer | Postgres |
| Pallet Assignment | Postgres |
| Frame | Postgres |
| Notes | Postgres |

---

# PRODUCTION IMPORT PROCEDURE

---

## Step 1 – Generate SQLite Snapshot

On approved machine:

```powershell
python parse_props_v6.py
```

Confirm:
- No parser errors
- `lor_output_v6.db` updated

---

## Step 2 – Ingest into Postgres

```powershell
.\postgres_run_ingest.ps1
```

Expected:

```
[INFO] Created import_run_id=#
[OK] previews: inserted ###
[OK] props: inserted ###
[OK] sub_props: inserted ###
[OK] dmx_channels: inserted ###
[DONE] Ingest + views complete.
```

---

## Step 3 – Mandatory Diff Review (NO EXCEPTIONS)

```sql
select *
from lor_snap.v_props_diff_latest_prev
order by change_type, new_lor_comment;
```

You MUST review:

- ADDED
- REMOVED
- CHANGED

If unexpected changes exist:
STOP.  
Fix in LOR.  
Re-run snapshot.

---

## Step 4 – Rebuild `ref.display`

```sql
call ref.rebuild_stage_from_latest_lor();

```

This:

- Truncates `ref.display`
- Re-seeds from latest LOR snapshot
- Preserves UUID identity
- Sets default status to ACTIVE

---

## Step 5 – Reapply Metadata (Internal Only)

Spreadsheet no longer exists.

Metadata comes from existing `ref.display` before rebuild.

If future enhancements require metadata persistence across rebuilds,
a preservation routine must be implemented.

No manual spreadsheet overlay allowed.

---

# STRICT RULES

---

## NEVER:

- Edit `lor_snap` tables manually
- Modify `import_run_id`
- Rename displays in Postgres
- Use spreadsheet for reconciliation
- Override UUID-based identity

---

## ALWAYS:

- Review diff before rebuild
- Keep display naming consistent in LOR
- Fix naming in LOR — never in Postgres
- Treat UUID (`prop_id`) as immutable identity

---

# Naming Enforcement Policy

Display names must match exactly between:

- LOR
- `ref.display.display_name`

If name correction is required:

1. Fix in LOR
2. Re-run snapshot
3. Review diff
4. Rebuild

No manual rename patches allowed.

---

# Non-Lit Displays Policy

If a display:

- Has `DeviceType=None`
- Has no channels
- Has no controller

It is considered non-lit.

Amp measurement may be NULL.
This is acceptable.

Amp planning queries must filter on:
- Displays with measurable load
- OR displays with controller assignment

---

# Safety Model

The database is append-only at the `lor_snap` level.

Every snapshot is preserved via `import_run_id`.

No historical snapshot is ever deleted.

---

# Emergency Rollback

If a rebuild introduces an error:

1. Identify previous `import_run_id`
2. Manually re-run rebuild using that run
   (future function may automate this)

Do NOT edit `ref.display` manually to patch mistakes.

---

# Future Enhancements (Planned)

- Parameterized diff: compare run X vs run Y
- Metadata preservation table
- Locked production mode toggle
- Web UI for metadata editing
- Automatic exception email report

---

# System Philosophy

LOR defines structure.  
Postgres defines operations.  

No dual-source truth.  
No spreadsheet drift.  
No manual reconciliation.

Production mode means deterministic imports only.