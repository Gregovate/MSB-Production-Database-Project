# MSB Production Database  
## LOR Snapshot Import Procedure

---

# 1. Overview

The LOR snapshot process:

LOR → SQLite (`lor_output_v6.db`) → Postgres (`lor_snap.*`) → `ref.display` rebuild

Each import:

- Creates a new `import_run_id`
- Fully rebuilds lor_snap tables
- Preserves history via `import_run_id`
- Enables run-to-run diff comparison

The snapshot is authoritative for:
- Displays (props)
- Sub-props
- Channels
- Preview assignments
- Controller/network assignments

---

# 2. Preconditions

Before running ingestion:

- LOR previews are saved
- All intended display name corrections are complete in LOR
- DeviceType=None items are intentional
- `parse_props_v6.py` runs without error

---

# 3. Step-by-Step Import

## Step 1 – Generate SQLite snapshot

Run locally:

```powershell
python parse_props_v6.py
```

Confirm:
- No parsing errors
- SQLite file updated (`lor_output_v6.db`)

---

## Step 2 – Ingest SQLite into Postgres

Run:

```powershell
.\postgres_run_ingest.ps1
```

Expected output:

```
[INFO] Created import_run_id=#
[OK] previews: inserted ###
[OK] props: inserted ###
[OK] sub_props: inserted ###
[OK] dmx_channels: inserted ###
[DONE] Ingest + views complete.
```

---

## Step 3 – Review Snapshot Diff

Run:

```sql
select * 
from lor_snap.v_props_diff_latest_prev
order by change_type, new_lor_comment;
```

Review:

- ADDED
- REMOVED
- CHANGED

If unexpected changes exist:
- Investigate in LOR before proceeding

---

## Step 4 – Rebuild ref.display from LOR

```sql
call ref.rebuild_display_from_latest_lor();
```

This:

- Truncates `ref.display`
- Seeds it from latest `lor_snap.props`
- Uses `lor_comment` as authoritative display_name

---

## Step 5 – Apply Spreadsheet Metadata (Temporary Phase Only)

Until spreadsheet is retired:

```sql
call stage.transform_display_sheet_csv_to_raw();
call ref.apply_display_metadata_from_sheet();
```

Review mismatches:

```sql
select *
from stage.v_sheet_match
where lor_prop_id is null
  and upper(coalesce(inventory_type,'LOR')) = 'LOR';
```

---

# 4. Post-Spreadsheet Future State

Once spreadsheet is eliminated:

- `ref.display` becomes authoritative
- All edits occur inside Postgres
- LOR name changes must match `ref.display` exactly
- Exceptions are reported via diff views

---

# 5. Business Rules

- Displays originate from LOR
- UUID (`prop_id`) is authoritative identity
- Display name comes from `lor_comment`
- DeviceType=None may indicate non-lit display
- Amps are manual measurement
- `est_light_count` preserved as-is (not recalculated)

---

# 6. Safety Rules

Never:

- Edit `lor_snap` tables manually
- Modify `import_run_id`
- Update `ref.display` before reviewing diff

Always:

- Review diff after ingestion
- Confirm unexpected ADDED/REMOVED rows

---

# 7. Known Edge Cases

- DeviceType=None props generate UUIDs (acceptable)
- Duplicate logical items (e.g. WhoHouseStatic) require manual consolidation
- Blank spreadsheet rows must be filtered before import