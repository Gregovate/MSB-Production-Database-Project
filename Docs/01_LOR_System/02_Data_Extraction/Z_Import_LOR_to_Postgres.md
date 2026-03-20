title: LOR to Postgres Import and Promotion SOP
Filename: Z_Import_LOR_to_Postgres.md
version: 2026-03-17
author: Greg Liebig / Engineering Innovations, LLC
status: CURRENT
supersedes:
  - F_Operational_Lockdownn_procedure.md
  - F_Operational_LOR_Import_testing.md
---

# LOR to Postgres Import and Promotion SOP

This is the current operational procedure for importing LOR preview changes into:

- SQLite
- Postgres `lor_snap`
- `ref.stage`
- `ref.display`
- `ref.spare_channel`

This document replaces older spreadsheet-era and testing-era procedures.

---

## 1. Purpose

Use this SOP whenever LOR preview changes have been made and must be promoted into the database.

This includes:

- display name corrections
- naming convention cleanup
- added or removed props
- added SPARE channels
- DeviceType = Undetermined / None inventory modeling
- stage preview updates
- label-related display identity corrections

### Display Identity Rule

`ref.display.display_id` is the production identity key.

`display_name` represents the physical display identity.

`lor_prop_id` is retained only as the current linkage back to LOR snapshot data and field wiring.

Because LOR props may be recreated, rewired, or moved to a different controller type, `lor_prop_id` is not treated as a permanent production identity.

---

## 2. Scope

This SOP covers:

1. Exporting LOR previews
2. Parsing previews into SQLite
3. Ingesting SQLite into Postgres `lor_snap`
4. Reviewing latest-vs-previous snapshot changes
5. Promoting latest snapshot into `ref.stage`
6. Performing a duplicate display-name preflight check
7. Promoting latest snapshot into `ref.display`
8. Routing SPARE entries into `ref.spare_channel`
9. Handling failures before production use

This SOP does NOT cover:

- label printing
- Directus configuration
- production work-order workflows
- spreadsheet reconciliation

Spreadsheet compare is no longer authoritative.

---

## 3. Preconditions

Before starting:

- LOR preview edits are complete
- correct preview files are open and saved
- correct export destination folder is known
- Python virtual environment is active
- required Python packages are installed
- Postgres is reachable
- no one else is making uncontrolled changes during import

---

## 4. Required Tools

### 4.1 Python Scripts

- parse_props_v6.py  
- postgres_ingest_from_lor_sqlite.py  
- postgres_run_ingest.ps1  

### 4.2 Required Python Packages

At minimum:

    pip install pandas openpyxl psycopg2-binary

---

## 5. Operational Procedure

### Step 1 — Export previews from LOR

Export all required `.lorprev` files to the staging preview folder.

Required checks:

- confirm the correct preview files were exported
- confirm the export destination folder is correct
- confirm timestamps are current

If the wrong preview was exported, stop and re-export before continuing.

---

### Step 2 — Parse previews into SQLite

Run:

    python parse_props_v6.py

Success checks:

- parser completes without error  
- lor_output_v6.db is updated  
- SQLite wiring views are rebuilt  
- expected counts appear reasonable  

If parser fails, stop and fix before continuing.

---

### Step 3 — Ingest SQLite into Postgres lor_snap

Run:

    .\postgres_run_ingest.ps1

Success checks:

- a new import_run_id is created  
- previews / props / sub_props / dmx counts are displayed  
- lor_snap views are rebuilt  
- field_wiring looks reasonable  
- unassigned = 0  

If ingest fails due to missing dependency:

    pip install psycopg2-binary

Then rerun ingest.

---

### Step 4 — Review latest-vs-previous snapshot delta

Run:

    select *
    from lor_snap.v_props_diff_latest_prev
    order by change_type, new_lor_comment;

Review for:

- renamed display comments  
- added SPARE channels  
- removed display names  
- unexpected stage changes  
- controller drift  
- inventory-only bulk records  

Parser success does NOT guarantee promotable data.

---

### Step 5 — Promote latest snapshot into ref.stage

Run:

    CALL ref.p1_upsert_stage_from_latest_lor();

Purpose:

- upsert ref.stage from latest previews  
- non-destructive  
- preserves stage identity  

Must complete successfully before continuing.

---

### Step 6 — Preflight duplicate display-name check

Run BEFORE p2.

    WITH latest AS (
      SELECT max(import_run_id) AS run_id
      FROM lor_snap.import_run
    ),
    names AS (
      SELECT
        upper(btrim(coalesce(nullif(btrim(p.lor_comment), ''), p.name))) AS display_name,
        p.prop_id
      FROM lor_snap.props p
      JOIN lor_snap.previews pr
        ON pr.id = p.preview_id
      JOIN latest l
        ON p.import_run_id = l.run_id
      WHERE pr.stage_id IS NOT NULL
        AND btrim(pr.stage_id) <> ''
        AND upper(btrim(coalesce(nullif(btrim(p.lor_comment), ''), p.name))) NOT LIKE '%PHANTOM%'
        AND upper(btrim(coalesce(nullif(btrim(p.lor_comment), ''), p.name))) NOT LIKE '%SPARE%'
    )
    SELECT display_name, count(DISTINCT prop_id) AS occurrences
    FROM names
    GROUP BY display_name
    HAVING count(DISTINCT prop_id) > 1
    ORDER BY occurrences DESC;

If ANY rows return:

STOP — duplicates exist.

Fix in LOR → re-export → re-parse → re-ingest → rerun p1 → rerun check.

---

### Step 7 — Promote displays into ref.display

Run:

    CALL ref.p2_upsert_display_from_latest_lor();

Purpose:

- upsert NON-SPARE displays into ref.display  
- route SPARE into ref.spare_channel  
- ensure SPARE not left in ref.display  

Must follow successful p1 and duplicate check.

---

### Step 8 — Post-promotion validation

Confirm:

- expected renamed displays exist  
- SPARE rows are only in ref.spare_channel  
- no SPARE rows remain in ref.display  
- stage assignments look correct  

Quick check:

    SELECT count(*) AS spare_in_display
    FROM ref.display
    WHERE upper(btrim(display_name)) = 'SPARE';

Expected result: 0

---

## 6. Failure Handling

### Missing psycopg2

    pip install psycopg2-binary

---

### p2 Duplicate Display Error

Error example:

    violates unique constraint ux_ref_display_display_name

Meaning:

Multiple props promote to the same display_name.

Fix in LOR, not in the database.

---

### Wrong Preview Exported

Symptoms:

- unexpected rename flood  
- unexpected stage changes  
- duplicate conflicts  

Fix:

Re-export correct previews → rerun entire pipeline.

---

## 7. Special Identity Rules

### One Physical Display = One Production Identity

A single physical prop must not create multiple identities in ref.display.

Wiring-only variants may exist in lor_snap.

---

### SPARE Is Not a Display

SPARE belongs in ref.spare_channel only.

---

### lor_comment Defines Identity

Promotion uses:

    COALESCE(NULLIF(BTRIM(p.lor_comment), ''), p.name)

Blank Comment values are dangerous.

---

## 8. Document Control Rules

This is the current SOP.

Older documents must be marked:

    status: ARCHIVED
    superseded_by: Z_Import_LOR_to_Postgres.md

Do not maintain multiple active import procedures.

---

## 9. Revision History

- 2026-03-17  GAL  Initial unified SOP replacing legacy procedures
- 2026-03-17  GAL  Added duplicate display-name preflight check before p2
- 2026-03-17  GAL  Clarified identity rules for display_name vs lor_prop_id
