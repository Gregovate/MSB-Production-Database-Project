# MSB Production Database — Live LOR Import Testing Procedure

| Document control | Value |
|---|---|
| Repository path | `Postgres_sql/Upsert Procedures/01_MSB_Live_LOR_Import_Testing_Procedure.md` |
| Document type | Administrator execution and validation runbook |
| Status | DRAFT — production execution blocked pending procedure and preflight review |
| Owner / author | GAL |
| Initial release | 2026-07-28 |
| Current revision | 2026-07-31 |
| Database | PostgreSQL database `msb` |
| Production host | `192.168.5.9` (`db.sheboyganlights.org`, where DNS/VPN access is available) |
| Repository | `Gregovate/MSB-Production-Database-Project` |

## Revision History

| Date | Author | Revision |
|---|---|---|
| 2026-07-28 | GAL | Initial live-import testing procedure. |
| 2026-07-31 | GAL | Added controlled document header and permanent display-identity gate requirements for V7 reconciliation. |

## Non-Negotiable Display Identity Contract

- `display_id` is the permanent database identity and the foreign key used by relational tables.
- `display_name` is the meaningful human-facing identity.
- `lor_prop_id` is only the current LOR UUID association stored in `ref.display`.
- No other production relational tables may depend on `lor_prop_id`.
- A display rename or LOR UUID change must preserve `display_id`.

Stop the procedure if any proposed action would violate this contract. Do not run P1, P2, or P3 until reconciliation passes for the exact imported `import_run_id`.

## 1. Purpose

This runbook controls the safe import of updated Light-O-Rama preview data into the live MSB PostgreSQL database.

It covers:

1. Creating and validating the SQLite snapshot.
2. Appending the snapshot to `lor_snap`.
3. Reviewing all incoming stage and display identity changes.
4. Promoting stages with `ref.p1_upsert_stage_from_latest_lor()`.
5. Promoting displays with `ref.p2_upsert_display_from_latest_lor()`.
6. Validating the three new displays.
7. Rolling back or recovering if any result is wrong.

This is an operator change procedure. It is not authorization to alter production.

> **HARD STOP**
>
> Do not load a new production snapshot, replace a procedure, call `p1`, or call `p2` until:
>
> - the installed `p1` and `p2` definitions have been captured;
> - the installed definitions have been compared with the intended repository versions;
> - the `p2` historical-preview join defect described in Section 3 has been corrected;
> - all read-only preflight results have been reviewed;
> - a current production backup has completed successfully.

## 2. Current Repository Findings

Repository state reviewed at commit:

```text
5e7caaf26036ea6aad5f32a036ce315d55161aba
```

### 2.1 Procedure copies

| Procedure | Repository file | Finding |
| --- | --- | --- |
| `p1` | `Utilities/procedures_ref_schema/p1_upsert_stage_from_latest_lor.sql` | Same executable body as the `Postgres_sql` copy; newer explanatory header. Candidate authoritative body. |
| `p1` | `Postgres_sql/Upsert Procedures/p1_upsert_stage_from_latest_lor.sql` | Same executable body as Utilities copy. |
| `p2` | `Utilities/procedures_ref_schema/p2_upsert_display_from_latest_lor.sql` | Newest intended matching model: PropID, then display name, then insert. Destructive SPARE delete is commented out. Contains the join defect in Section 3. File contains only the procedure body, not a complete `CREATE OR REPLACE PROCEDURE` statement. |
| `p2` | `Postgres_sql/Upsert Procedures/p2_upsert_display_from_latest_lor_v2.sql` | **UNSAFE.** Deletes matching production rows from `ref.display` when classified as SPARE. Also contains the join defect in Section 3. |
| `p2` | `Postgres_sql/Upsert Procedures/p2_upsert_display_from_latest_lor_v1.sql` | Older PropID-only upsert. Does not implement the intended staged identity matching or current SPARE behavior. |

### 2.2 Authority decision

For this production import:

- The intended `p1` logic is the body in `Utilities/procedures_ref_schema/p1_upsert_stage_from_latest_lor.sql`.
- The intended `p2` logic is the staged matching model in `Utilities/procedures_ref_schema/p2_upsert_display_from_latest_lor.sql`, **after the join defect is fixed and the result is made into a complete deployable procedure definition**.
- `Postgres_sql/Upsert Procedures/p2_upsert_display_from_latest_lor_v2.sql` must not be installed or executed.
- `Postgres_sql/Upsert Procedures/p2_upsert_display_from_latest_lor_v1.sql` is not authoritative for the current identity rules.
- The repository should ultimately contain one deployable authoritative file per procedure; obsolete copies should be moved to `archive` or clearly marked unsafe.

This authority decision identifies the intended logic. It does not prove what is installed on production. Section 6 must establish that separately.

### 2.3 Ingest-version conflict

The current repository runner is:

```text
postgres_run_ingest_v7.ps1
```

It:

- defaults to `lor_output_v7.db`;
- explicitly aborts if any other SQLite filename is supplied;
- targets host `192.168.5.9`, database `msb`, user `msbadmin`;
- calls `postgres_ingest_from_lor_sqlite.py`;
- commits the new `lor_snap` run atomically.

The older current-status SOP still refers to:

```text
parse_props_v6.py
lor_output_v6.db
postgres_run_ingest.ps1
```

Do not mix the V6 parser/output with the V7 runner. The exact parser and SQLite artifact selected for production must be resolved before snapshot loading.

## 3. Blocking `p2` Join Defect

The Utilities `p2` body currently contains joins equivalent to:

```sql
JOIN lor_snap.previews pr
  ON pr.id = p.preview_id
WHERE p.import_run_id = v_run_id
```

`lor_snap.previews.id` is unique only within an import run. Preview IDs can repeat in historical runs. The safe join is:

```sql
JOIN lor_snap.previews pr
  ON pr.import_run_id = p.import_run_id
 AND pr.id = p.preview_id
WHERE p.import_run_id = v_run_id
  AND pr.import_run_id = v_run_id
```

The same run constraint must be used in:

- the missing-stage guard query;
- the classified source query;
- every preflight query joining current props to previews.

> **STOP:** Do not install or call `p2` until the complete intended definition contains the run-scoped join in every applicable location.

## 4. Change Record

Complete before work begins.

| Item | Value |
| --- | --- |
| Operator | |
| Reviewer | |
| Change date/time | |
| Maintenance window | |
| Git commit reviewed | `5e7caaf26036ea6aad5f32a036ce315d55161aba` |
| Parser/version | |
| SQLite file | |
| SQLite SHA-256 | |
| Preview source folder | |
| Previous `import_run_id` | |
| New `import_run_id` | |
| Backup filename | |
| Backup SHA-256 | |
| Three expected display names | |
| Three expected PropIDs | |
| Expected stage keys | |
| Decision | `GO` / `NO-GO` |

## 5. Connect to PostgreSQL

### 5.1 PowerShell and `psql`

Use a secure password prompt. Do not put the password in command history.

```powershell
$env:PGHOST = "192.168.5.9"
$env:PGPORT = "5432"
$env:PGDATABASE = "msb"
$env:PGUSER = "msbadmin"
psql -W
```

If connecting through public DNS is required:

```powershell
$env:PGHOST = "db.sheboyganlights.org"
psql -W
```

Clear the session variables when finished:

```powershell
Remove-Item Env:\PGHOST -ErrorAction SilentlyContinue
Remove-Item Env:\PGPORT -ErrorAction SilentlyContinue
Remove-Item Env:\PGDATABASE -ErrorAction SilentlyContinue
Remove-Item Env:\PGUSER -ErrorAction SilentlyContinue
Remove-Item Env:\PGPASSWORD -ErrorAction SilentlyContinue
```

### 5.2 pgAdmin

Create or select a server connection with:

```text
Host:             192.168.5.9
Port:             5432
Maintenance DB:   msb
Username:         msbadmin
SSL:              use the production server's existing required setting
```

Open Query Tool against database `msb`. Verify the query window title before running SQL.

## 6. Identify the Server, Database, Schemas, and Installed Procedures

All SQL in this section is read-only.

### 6.1 Confirm connection identity

```sql
SELECT
    current_database()                         AS database_name,
    current_user                               AS login_role,
    session_user                               AS session_role,
    inet_server_addr()                         AS server_address,
    inet_server_port()                         AS server_port,
    current_setting('server_version')          AS postgres_version,
    current_setting('TimeZone')                AS server_timezone,
    pg_is_in_recovery()                        AS server_is_replica,
    now()                                      AS checked_at;
```

Expected:

- `database_name = msb`
- `server_is_replica = false`
- server address is the production PostgreSQL server

Stop if any value is unexpected.

### 6.2 List active schemas

```sql
SELECT
    nspname AS schema_name,
    pg_get_userbyid(nspowner) AS owner
FROM pg_namespace
WHERE nspname NOT LIKE 'pg_%'
  AND nspname <> 'information_schema'
ORDER BY nspname;
```

Required for this operation:

```text
lor_snap
ref
```

### 6.3 Confirm required objects and kinds

```sql
SELECT
    n.nspname AS schema_name,
    c.relname AS object_name,
    CASE c.relkind
        WHEN 'r' THEN 'table'
        WHEN 'v' THEN 'view'
        WHEN 'm' THEN 'materialized view'
        WHEN 'p' THEN 'partitioned table'
        ELSE c.relkind::text
    END AS object_type
FROM pg_class c
JOIN pg_namespace n
  ON n.oid = c.relnamespace
WHERE (n.nspname, c.relname) IN (
    ('lor_snap', 'import_run'),
    ('lor_snap', 'previews'),
    ('lor_snap', 'props'),
    ('ref', 'stage'),
    ('ref', 'display'),
    ('ref', 'spare_channel'),
    ('ref', 'display_status')
)
ORDER BY n.nspname, c.relname;
```

Expected: seven rows.

### 6.4 Identify installed procedure signatures

```sql
SELECT
    n.nspname AS procedure_schema,
    p.proname AS procedure_name,
    pg_get_function_identity_arguments(p.oid) AS identity_arguments,
    pg_get_userbyid(p.proowner) AS owner,
    l.lanname AS language,
    p.prokind,
    p.oid
FROM pg_proc p
JOIN pg_namespace n
  ON n.oid = p.pronamespace
JOIN pg_language l
  ON l.oid = p.prolang
WHERE n.nspname = 'ref'
  AND p.proname IN (
      'p1_upsert_stage_from_latest_lor',
      'p2_upsert_display_from_latest_lor'
  )
ORDER BY p.proname, pg_get_function_identity_arguments(p.oid);

SELECT
    n.nspname AS schema_name,
    p.proname AS object_name,
    CASE p.prokind
        WHEN 'p' THEN 'PROCEDURE'
        WHEN 'f' THEN 'FUNCTION'
        ELSE p.prokind::text
    END AS object_type,
    pg_get_userbyid(p.proowner) AS owner,
    pg_get_function_identity_arguments(p.oid) AS identity_arguments,
    pg_get_function_result(p.oid) AS result_type
FROM pg_proc p
JOIN pg_namespace n
  ON n.oid = p.pronamespace
WHERE n.nspname = 'ref'
  AND p.proname IN (
      'p1_upsert_stage_from_latest_lor',
      'p2_upsert_display_from_latest_lor'
  )
ORDER BY p.proname, p.oid;
```

Expected:

- exactly one zero-argument row for `p1`;
- exactly one zero-argument row for `p2`;
- `prokind = 'p'`.

Stop if overloads or duplicate signatures exist.

### 6.5 Capture complete installed definitions

```sql
SELECT
    n.nspname AS procedure_schema,
    p.proname AS procedure_name,
    pg_get_function_identity_arguments(p.oid) AS identity_arguments,
    pg_get_functiondef(p.oid) AS installed_definition
FROM pg_proc p
JOIN pg_namespace n
  ON n.oid = p.pronamespace
WHERE n.nspname = 'ref'
  AND p.proname IN (
      'p1_upsert_stage_from_latest_lor',
      'p2_upsert_display_from_latest_lor'
  )
ORDER BY p.proname, pg_get_function_identity_arguments(p.oid);
```

Save the unedited result as:

```text
installed_ref_p1_p2_before_import_YYYY-MM-DD.sql
```

Also capture stable database-side hashes:

```sql
SELECT
    n.nspname AS procedure_schema,
    p.proname AS procedure_name,
    pg_get_function_identity_arguments(p.oid) AS identity_arguments,
    md5(pg_get_functiondef(p.oid)) AS installed_definition_md5
FROM pg_proc p
JOIN pg_namespace n
  ON n.oid = p.pronamespace
WHERE n.nspname = 'ref'
  AND p.proname IN (
      'p1_upsert_stage_from_latest_lor',
      'p2_upsert_display_from_latest_lor'
  )
ORDER BY p.proname, pg_get_function_identity_arguments(p.oid);
```

### 6.6 Installed `p2` safety checks

These checks inspect the stored source text. A returned `true` is not proof of full correctness, but a wrong value is a definite stop.

```sql
WITH installed AS (
    SELECT
        p.proname,
        pg_get_functiondef(p.oid) AS ddl
    FROM pg_proc p
    JOIN pg_namespace n
      ON n.oid = p.pronamespace
    WHERE n.nspname = 'ref'
      AND p.proname = 'p2_upsert_display_from_latest_lor'
      AND pg_get_function_identity_arguments(p.oid) = ''
)
SELECT
    proname,
    ddl ~* 'delete[[:space:]]+from[[:space:]]+ref\.display' AS contains_display_delete,
    ddl ~* 'd\.lor_prop_id[[:space:]]*=[[:space:]]*c\.lor_prop_id' AS has_propid_match,
    ddl ~* 'upper\(btrim\(d\.display_name\)\)[[:space:]]*=[[:space:]]*upper\(btrim\(c\.display_name\)\)' AS has_name_match,
    ddl ~* 'pr\.import_run_id[[:space:]]*=[[:space:]]*p\.import_run_id' AS has_run_scoped_preview_join
FROM installed;
```

Required result:

| Check | Required |
| --- | --- |
| `contains_display_delete` | `false` |
| `has_propid_match` | `true` |
| `has_name_match` | `true` |
| `has_run_scoped_preview_join` | `true` |

Regardless of these booleans, manually compare the complete installed definition with the reviewed, corrected authoritative SQL.

> **NO-GO:** If the installed `p2` deletes from `ref.display`, lacks staged identity matching, lacks current-run preview joins, or differs in any unexplained way, do not call it.

## 7. Verify the Existing Latest `lor_snap` Run

Run this before generating or loading a new snapshot.

### 7.1 Latest runs and actual counts

```sql
SELECT
    r.import_run_id,
    r.run_ts,
    r.notes,
    (SELECT count(*) FROM lor_snap.previews p
      WHERE p.import_run_id = r.import_run_id) AS preview_count,
    (SELECT count(*) FROM lor_snap.props p
      WHERE p.import_run_id = r.import_run_id) AS prop_count,
    (SELECT count(*) FROM lor_snap.sub_props sp
      WHERE sp.import_run_id = r.import_run_id) AS sub_prop_count,
    (SELECT count(*) FROM lor_snap.dmx_channels dc
      WHERE dc.import_run_id = r.import_run_id) AS dmx_channel_count
FROM lor_snap.import_run r
ORDER BY r.import_run_id DESC
LIMIT 5;
```

Record the current maximum `import_run_id`:

```sql
SELECT max(import_run_id) AS previous_latest_run_id
FROM lor_snap.import_run;
```

### 7.2 Verify views resolve to the same run

```sql
SELECT * FROM lor_snap.v_current_run;

SELECT
    (SELECT count(*) FROM lor_snap.v_current_previews) AS previews,
    (SELECT count(*) FROM lor_snap.v_current_props) AS props,
    (SELECT count(*) FROM lor_snap.v_current_sub_props) AS sub_props,
    (SELECT count(*) FROM lor_snap.v_current_dmx_channels) AS dmx_channels;
```

Stop if the current views do not represent the maximum committed `import_run_id`.

## 8. Prepare and Validate the SQLite Snapshot

The production parser/output version is unresolved because:

- updated inputs are described as V6.6 previews;
- V7 parser and scene work exist;
- `postgres_run_ingest_v7.ps1` enforces `lor_output_v7.db`;
- the older SOP references V6 artifacts.

Before continuing, record an explicit decision:

```text
Parser selected:
Parser version:
SQLite output filename:
Reason:
Reviewed by:
```

### 8.1 Generate the selected SQLite snapshot

Use only the reviewed parser command for the selected version. Do not infer the command from an obsolete SOP.

### 8.2 Record file identity

PowerShell:

```powershell
Get-Item "G:\Shared drives\MSB Database\database\lor_output_v7.db" |
    Select-Object FullName, Length, LastWriteTime

Get-FileHash `
    -Algorithm SHA256 `
    "G:\Shared drives\MSB Database\database\lor_output_v7.db"
```

Change the path only if the approved parser/output decision explicitly selects a different file.

### 8.3 Read-only SQLite validation

Use Python so the database is opened in read-only mode:

```powershell
python -c "import sqlite3; p=r'G:\Shared drives\MSB Database\database\lor_output_v7.db'; c=sqlite3.connect('file:'+p.replace(chr(92),'/')+'?mode=ro', uri=True); print(c.execute('PRAGMA integrity_check').fetchone()[0]); print({t:c.execute(f'SELECT count(*) FROM {t}').fetchone()[0] for t in ('previews','props','subProps','dmxChannels')}); c.close()"
```

Expected:

- `PRAGMA integrity_check` returns `ok`;
- all required tables exist;
- counts are plausible compared with the preceding accepted run;
- the three new displays are present in `props`;
- their display comments, PropIDs, and preview assignments are correct.

Do not load the snapshot if any result is unclear.

## 9. Backup Before Production Work

### 9.1 Required full logical backup

Run from PowerShell on a machine with PostgreSQL client tools:

```powershell
$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backup = "G:\Shared drives\MSB Database\database\backups\msb_before_lor_import_$stamp.dump"

pg_dump `
    --host "192.168.5.9" `
    --port 5432 `
    --username "msbadmin" `
    --dbname "msb" `
    --format custom `
    --verbose `
    --file "$backup"

if ($LASTEXITCODE -ne 0) {
    throw "pg_dump failed. STOP."
}

Get-Item "$backup" | Select-Object FullName, Length, LastWriteTime
Get-FileHash -Algorithm SHA256 "$backup"
```

Do not continue unless:

- `pg_dump` exits with code `0`;
- the backup file exists and is nonzero;
- the SHA-256 is recorded in the change record.

### 9.2 Optional focused safety export

This does not replace the full backup.

```powershell
$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$refBackup = "G:\Shared drives\MSB Database\database\backups\msb_ref_lor_before_$stamp.dump"

pg_dump `
    --host "192.168.5.9" `
    --port 5432 `
    --username "msbadmin" `
    --dbname "msb" `
    --format custom `
    --verbose `
    --table "ref.stage" `
    --table "ref.display" `
    --table "ref.spare_channel" `
    --file "$refBackup"

if ($LASTEXITCODE -ne 0) {
    throw "Focused pg_dump failed. STOP."
}
```

## 10. Load the New Snapshot into `lor_snap`

This step changes production by appending a new snapshot run. Perform it only after Sections 1–9 pass and approval is recorded.

### 10.1 Run the approved wrapper

For the repository's currently enforced V7 path:

```powershell
Set-Location "C:\path\to\MSB-Production-Database-Project"

.\postgres_run_ingest_v7.ps1 `
    -SQLitePath "G:\Shared drives\MSB Database\database\lor_output_v7.db" `
    -Notes "2026-07-28 controlled LOR production import; operator=NAME; SQLite SHA256=HASH"
```

Expected:

```text
[INFO] Created import_run_id=...
[OK] previews: inserted ...
[OK] props: inserted ...
[OK] sub_props: inserted ...
[OK] dmx_channels: inserted ...
[DONE] Ingest + views complete. import_run_id=...
```

The Python ingest uses one transaction. An exception rolls back the new import run and all snapshot rows.

### 10.2 Verify exactly one new run

```sql
SELECT
    import_run_id,
    run_ts,
    notes
FROM lor_snap.import_run
ORDER BY import_run_id DESC
LIMIT 5;
```

Confirm:

- exactly one new run exists;
- its notes identify this change;
- its ID is greater than the recorded previous maximum.

Record this ID as `NEW_RUN_ID`.

### 10.3 Verify loaded counts

Replace `:NEW_RUN_ID` in pgAdmin manually, or use `\set` in `psql`.

`psql`:

```sql
\set NEW_RUN_ID 123
```

```sql
SELECT
    :'NEW_RUN_ID'::bigint AS import_run_id,
    (SELECT count(*) FROM lor_snap.previews
      WHERE import_run_id = :'NEW_RUN_ID'::bigint) AS previews,
    (SELECT count(*) FROM lor_snap.props
      WHERE import_run_id = :'NEW_RUN_ID'::bigint) AS props,
    (SELECT count(*) FROM lor_snap.sub_props
      WHERE import_run_id = :'NEW_RUN_ID'::bigint) AS sub_props,
    (SELECT count(*) FROM lor_snap.dmx_channels
      WHERE import_run_id = :'NEW_RUN_ID'::bigint) AS dmx_channels;
```

For pgAdmin, substitute the numeric ID:

```sql
SELECT
    123::bigint AS import_run_id,
    (SELECT count(*) FROM lor_snap.previews WHERE import_run_id = 123) AS previews,
    (SELECT count(*) FROM lor_snap.props WHERE import_run_id = 123) AS props,
    (SELECT count(*) FROM lor_snap.sub_props WHERE import_run_id = 123) AS sub_props,
    (SELECT count(*) FROM lor_snap.dmx_channels WHERE import_run_id = 123) AS dmx_channels;
```

### 10.4 Pin all review work to the recorded run

Do not rely silently on `max(import_run_id)` during review. Every preflight below derives a latest run but displays its ID. Confirm that it equals the recorded `NEW_RUN_ID` before interpreting results.

If another import appears during the maintenance window, stop.

## 11. Read-Only Preflight

Run every query in this section after snapshot load and before `p1`.

### 11.1 Snapshot summary and previous actual run

This selects the two highest actual run IDs. It does not assume IDs are consecutive.

```sql
WITH ranked_runs AS (
    SELECT
        import_run_id,
        run_ts,
        notes,
        row_number() OVER (ORDER BY import_run_id DESC) AS rn
    FROM lor_snap.import_run
)
SELECT *
FROM ranked_runs
WHERE rn <= 2
ORDER BY rn;
```

### 11.2 Incoming normalized stages

This reproduces `p1` selection logic and exposes the selected preview.

```sql
WITH latest AS (
    SELECT max(import_run_id) AS run_id
    FROM lor_snap.import_run
),
incoming AS (
    SELECT DISTINCT ON (lower(btrim(p.stage_id)))
        l.run_id,
        lower(btrim(p.stage_id)) AS stage_key,
        p.stage_id AS stage_id_raw,
        p.name AS preview_name
    FROM lor_snap.previews p
    CROSS JOIN latest l
    WHERE p.import_run_id = l.run_id
      AND p.stage_id IS NOT NULL
      AND btrim(p.stage_id) <> ''
    ORDER BY
        lower(btrim(p.stage_id)),
        (p.name ~* '^\s*stage\b') DESC,
        length(p.name) DESC,
        p.name DESC
)
SELECT *
FROM incoming
ORDER BY stage_key;
```

Review noncanonical stage keys separately:

```sql
WITH latest AS (
    SELECT max(import_run_id) AS run_id
    FROM lor_snap.import_run
)
SELECT
    p.import_run_id,
    p.id AS preview_id,
    p.stage_id,
    p.name AS preview_name
FROM lor_snap.previews p
CROSS JOIN latest l
WHERE p.import_run_id = l.run_id
  AND (
      p.stage_id IS NULL
      OR btrim(p.stage_id) = ''
      OR lower(btrim(p.stage_id)) !~ '^0*\d{1,2}[a-z]?$'
  )
ORDER BY p.name;
```

Every returned row requires review.

### 11.3 New stages

```sql
WITH latest AS (
    SELECT max(import_run_id) AS run_id
    FROM lor_snap.import_run
),
incoming AS (
    SELECT DISTINCT ON (lower(btrim(p.stage_id)))
        l.run_id,
        lower(btrim(p.stage_id)) AS stage_key,
        p.stage_id AS stage_id_raw,
        p.name AS preview_name
    FROM lor_snap.previews p
    CROSS JOIN latest l
    WHERE p.import_run_id = l.run_id
      AND p.stage_id IS NOT NULL
      AND btrim(p.stage_id) <> ''
    ORDER BY
        lower(btrim(p.stage_id)),
        (p.name ~* '^\s*stage\b') DESC,
        length(p.name) DESC,
        p.name DESC
)
SELECT
    i.run_id,
    i.stage_key,
    i.stage_id_raw,
    i.preview_name
FROM incoming i
LEFT JOIN ref.stage s
  ON s.stage_key = i.stage_key
WHERE s.stage_id IS NULL
ORDER BY i.stage_key;
```

Expected: only specifically planned new stages. If the three new displays use existing stages, expected result is zero rows.

### 11.4 Changed stage names

This calculates the values that `p1` intends to write.

```sql
WITH latest AS (
    SELECT max(import_run_id) AS run_id
    FROM lor_snap.import_run
),
one_per_stage AS (
    SELECT DISTINCT ON (lower(btrim(p.stage_id)))
        l.run_id,
        lower(btrim(p.stage_id)) AS stage_key,
        p.stage_id AS stage_id_raw,
        p.name AS preview_name
    FROM lor_snap.previews p
    CROSS JOIN latest l
    WHERE p.import_run_id = l.run_id
      AND p.stage_id IS NOT NULL
      AND btrim(p.stage_id) <> ''
    ORDER BY
        lower(btrim(p.stage_id)),
        (p.name ~* '^\s*stage\b') DESC,
        length(p.name) DESC,
        p.name DESC
),
derived AS (
    SELECT
        run_id,
        stage_key,
        preview_name,
        COALESCE(
            NULLIF(
                btrim(
                    regexp_replace(
                        regexp_replace(
                            preview_name,
                            '(?i)^\s*stage\s*0*' || stage_id_raw || '\s*',
                            ''
                        ),
                        '\s+(with|w/)\s+.*$',
                        '',
                        'i'
                    )
                ),
                ''
            ),
            'Stage ' || stage_id_raw
        ) AS proposed_stage_name
    FROM one_per_stage
)
SELECT
    d.run_id,
    d.stage_key,
    s.stage_name AS current_stage_name,
    d.proposed_stage_name,
    d.preview_name
FROM derived d
JOIN ref.stage s
  ON s.stage_key = d.stage_key
WHERE s.stage_name IS DISTINCT FROM d.proposed_stage_name
ORDER BY d.stage_key;
```

Every row is an intentional production name change or a stop.

### 11.5 Missing stage keys required by incoming displays

```sql
WITH latest AS (
    SELECT max(import_run_id) AS run_id
    FROM lor_snap.import_run
),
required_keys AS (
    SELECT DISTINCT
        l.run_id,
        lower(btrim(pr.stage_id)) AS stage_key
    FROM lor_snap.props p
    JOIN latest l
      ON p.import_run_id = l.run_id
    JOIN lor_snap.previews pr
      ON pr.import_run_id = p.import_run_id
     AND pr.id = p.preview_id
    WHERE pr.stage_id IS NOT NULL
      AND btrim(pr.stage_id) <> ''
      AND lower(btrim(pr.stage_id)) ~ '^0*\d{1,2}[a-z]?$'
)
SELECT
    k.run_id,
    k.stage_key
FROM required_keys k
LEFT JOIN ref.stage s
  ON s.stage_key = k.stage_key
WHERE s.stage_id IS NULL
ORDER BY k.stage_key;
```

Before `p1`, rows should correspond exactly to approved new stages. After `p1`, this query must return zero rows.

### 11.6 Duplicate incoming display names

This uses the same effective display name and SPARE classification intended for `p2`.

```sql
WITH latest AS (
    SELECT max(import_run_id) AS run_id
    FROM lor_snap.import_run
),
incoming AS (
    SELECT
        l.run_id,
        p.prop_id AS lor_prop_id,
        coalesce(nullif(btrim(p.lor_comment), ''), p.name) AS display_name,
        p.name AS prop_name,
        p.lor_comment AS prop_comment
    FROM lor_snap.props p
    JOIN latest l
      ON p.import_run_id = l.run_id
    JOIN lor_snap.previews pr
      ON pr.import_run_id = p.import_run_id
     AND pr.id = p.preview_id
    WHERE upper(coalesce(nullif(btrim(p.lor_comment), ''), p.name)) NOT LIKE '%PHANTOM%'
      AND pr.stage_id IS NOT NULL
      AND btrim(pr.stage_id) <> ''
      AND lower(btrim(pr.stage_id)) ~ '^0*\d{1,2}[a-z]?$'
),
non_spare AS (
    SELECT *
    FROM incoming
    WHERE NOT (
        display_name ILIKE '%spare%'
        OR coalesce(prop_name, '') ILIKE '%spare%'
        OR coalesce(prop_comment, '') ILIKE '%spare%'
    )
)
SELECT
    run_id,
    upper(btrim(display_name)) AS normalized_display_name,
    count(*) AS row_count,
    count(DISTINCT lor_prop_id) AS distinct_propids,
    array_agg(DISTINCT lor_prop_id ORDER BY lor_prop_id) AS propids
FROM non_spare
GROUP BY run_id, upper(btrim(display_name))
HAVING count(*) > 1
    OR count(DISTINCT lor_prop_id) > 1
ORDER BY normalized_display_name;
```

Required result: zero rows.

### 11.7 Duplicate incoming PropIDs

The table constraint normally prevents this within a run, but verify it explicitly.

```sql
WITH latest AS (
    SELECT max(import_run_id) AS run_id
    FROM lor_snap.import_run
)
SELECT
    p.import_run_id,
    p.prop_id,
    count(*) AS row_count,
    array_agg(p.int_prop_id ORDER BY p.int_prop_id) AS internal_ids
FROM lor_snap.props p
JOIN latest l
  ON p.import_run_id = l.run_id
GROUP BY p.import_run_id, p.prop_id
HAVING count(*) > 1
ORDER BY p.prop_id;
```

Required result: zero rows.

Also reject blank PropIDs:

```sql
WITH latest AS (
    SELECT max(import_run_id) AS run_id
    FROM lor_snap.import_run
)
SELECT
    p.import_run_id,
    p.int_prop_id,
    p.prop_id,
    p.name,
    p.lor_comment
FROM lor_snap.props p
JOIN latest l
  ON p.import_run_id = l.run_id
WHERE p.prop_id IS NULL
   OR btrim(p.prop_id) = ''
ORDER BY p.int_prop_id;
```

Required result: zero rows.

### 11.8 Renamed displays with the same PropID

These rows will be matched by `p2` step 7A and will retain `display_id`.

```sql
WITH latest AS (
    SELECT max(import_run_id) AS run_id
    FROM lor_snap.import_run
),
incoming AS (
    SELECT DISTINCT ON (p.prop_id)
        l.run_id,
        p.prop_id AS lor_prop_id,
        coalesce(nullif(btrim(p.lor_comment), ''), p.name) AS incoming_display_name,
        lower(btrim(pr.stage_id)) AS incoming_stage_key
    FROM lor_snap.props p
    JOIN latest l
      ON p.import_run_id = l.run_id
    JOIN lor_snap.previews pr
      ON pr.import_run_id = p.import_run_id
     AND pr.id = p.preview_id
    WHERE upper(coalesce(nullif(btrim(p.lor_comment), ''), p.name)) NOT LIKE '%PHANTOM%'
      AND pr.stage_id IS NOT NULL
      AND btrim(pr.stage_id) <> ''
      AND lower(btrim(pr.stage_id)) ~ '^0*\d{1,2}[a-z]?$'
      AND NOT (
          coalesce(nullif(btrim(p.lor_comment), ''), p.name) ILIKE '%spare%'
          OR coalesce(p.name, '') ILIKE '%spare%'
          OR coalesce(p.lor_comment, '') ILIKE '%spare%'
      )
    ORDER BY
        p.prop_id,
        (nullif(btrim(p.lor_comment), '') IS NOT NULL) DESC,
        length(coalesce(p.lor_comment, '')) DESC,
        p.name DESC
)
SELECT
    i.run_id,
    d.display_id,
    i.lor_prop_id,
    d.display_name AS current_display_name,
    i.incoming_display_name,
    s.stage_key AS current_stage_key,
    i.incoming_stage_key
FROM incoming i
JOIN ref.display d
  ON d.lor_prop_id = i.lor_prop_id
LEFT JOIN ref.stage s
  ON s.stage_id = d.stage_id
WHERE d.display_name IS DISTINCT FROM i.incoming_display_name
ORDER BY d.display_name;
```

Every row must be an approved rename.

### 11.9 Existing display names with changed PropIDs

These rows will be matched by `p2` step 7B and should retain `display_id` while changing `lor_prop_id`.

```sql
WITH latest AS (
    SELECT max(import_run_id) AS run_id
    FROM lor_snap.import_run
),
incoming AS (
    SELECT DISTINCT ON (p.prop_id)
        l.run_id,
        p.prop_id AS incoming_lor_prop_id,
        coalesce(nullif(btrim(p.lor_comment), ''), p.name) AS incoming_display_name,
        lower(btrim(pr.stage_id)) AS incoming_stage_key
    FROM lor_snap.props p
    JOIN latest l
      ON p.import_run_id = l.run_id
    JOIN lor_snap.previews pr
      ON pr.import_run_id = p.import_run_id
     AND pr.id = p.preview_id
    WHERE upper(coalesce(nullif(btrim(p.lor_comment), ''), p.name)) NOT LIKE '%PHANTOM%'
      AND pr.stage_id IS NOT NULL
      AND btrim(pr.stage_id) <> ''
      AND lower(btrim(pr.stage_id)) ~ '^0*\d{1,2}[a-z]?$'
      AND NOT (
          coalesce(nullif(btrim(p.lor_comment), ''), p.name) ILIKE '%spare%'
          OR coalesce(p.name, '') ILIKE '%spare%'
          OR coalesce(p.lor_comment, '') ILIKE '%spare%'
      )
    ORDER BY
        p.prop_id,
        (nullif(btrim(p.lor_comment), '') IS NOT NULL) DESC,
        length(coalesce(p.lor_comment, '')) DESC,
        p.name DESC
)
SELECT
    i.run_id,
    d.display_id,
    d.display_name,
    d.lor_prop_id AS current_lor_prop_id,
    i.incoming_lor_prop_id,
    s.stage_key AS current_stage_key,
    i.incoming_stage_key
FROM incoming i
JOIN ref.display d
  ON upper(btrim(d.display_name)) = upper(btrim(i.incoming_display_name))
WHERE d.lor_prop_id IS DISTINCT FROM i.incoming_lor_prop_id
ORDER BY d.display_name;
```

Every row must represent a known LOR prop recreation or intentional PropID replacement.

### 11.10 Cross-identity collision check

This catches the dangerous case where an incoming PropID matches one production display but its incoming name matches a different production display.

```sql
WITH latest AS (
    SELECT max(import_run_id) AS run_id
    FROM lor_snap.import_run
),
incoming AS (
    SELECT DISTINCT ON (p.prop_id)
        l.run_id,
        p.prop_id AS lor_prop_id,
        coalesce(nullif(btrim(p.lor_comment), ''), p.name) AS display_name
    FROM lor_snap.props p
    JOIN latest l
      ON p.import_run_id = l.run_id
    JOIN lor_snap.previews pr
      ON pr.import_run_id = p.import_run_id
     AND pr.id = p.preview_id
    WHERE upper(coalesce(nullif(btrim(p.lor_comment), ''), p.name)) NOT LIKE '%PHANTOM%'
      AND pr.stage_id IS NOT NULL
      AND btrim(pr.stage_id) <> ''
      AND lower(btrim(pr.stage_id)) ~ '^0*\d{1,2}[a-z]?$'
      AND NOT (
          coalesce(nullif(btrim(p.lor_comment), ''), p.name) ILIKE '%spare%'
          OR coalesce(p.name, '') ILIKE '%spare%'
          OR coalesce(p.lor_comment, '') ILIKE '%spare%'
      )
    ORDER BY
        p.prop_id,
        (nullif(btrim(p.lor_comment), '') IS NOT NULL) DESC,
        length(coalesce(p.lor_comment, '')) DESC,
        p.name DESC
)
SELECT
    i.run_id,
    i.lor_prop_id,
    i.display_name AS incoming_display_name,
    by_id.display_id AS propid_matched_display_id,
    by_id.display_name AS propid_matched_display_name,
    by_name.display_id AS name_matched_display_id,
    by_name.lor_prop_id AS name_matched_lor_prop_id
FROM incoming i
JOIN ref.display by_id
  ON by_id.lor_prop_id = i.lor_prop_id
JOIN ref.display by_name
  ON upper(btrim(by_name.display_name)) = upper(btrim(i.display_name))
WHERE by_id.display_id <> by_name.display_id
ORDER BY i.display_name;
```

Required result: zero rows.

### 11.11 Brand-new displays

These rows match neither production PropID nor normalized production display name and are the only rows `p2` should insert.

```sql
WITH latest AS (
    SELECT max(import_run_id) AS run_id
    FROM lor_snap.import_run
),
incoming AS (
    SELECT DISTINCT ON (p.prop_id)
        l.run_id,
        p.prop_id AS lor_prop_id,
        coalesce(nullif(btrim(p.lor_comment), ''), p.name) AS display_name,
        p.name AS prop_name,
        p.lor_comment AS prop_comment,
        lower(btrim(pr.stage_id)) AS stage_key,
        p.string_type,
        p.color
    FROM lor_snap.props p
    JOIN latest l
      ON p.import_run_id = l.run_id
    JOIN lor_snap.previews pr
      ON pr.import_run_id = p.import_run_id
     AND pr.id = p.preview_id
    WHERE upper(coalesce(nullif(btrim(p.lor_comment), ''), p.name)) NOT LIKE '%PHANTOM%'
      AND pr.stage_id IS NOT NULL
      AND btrim(pr.stage_id) <> ''
      AND lower(btrim(pr.stage_id)) ~ '^0*\d{1,2}[a-z]?$'
      AND NOT (
          coalesce(nullif(btrim(p.lor_comment), ''), p.name) ILIKE '%spare%'
          OR coalesce(p.name, '') ILIKE '%spare%'
          OR coalesce(p.lor_comment, '') ILIKE '%spare%'
      )
    ORDER BY
        p.prop_id,
        (nullif(btrim(p.lor_comment), '') IS NOT NULL) DESC,
        length(coalesce(p.lor_comment, '')) DESC,
        p.name DESC
)
SELECT
    i.*
FROM incoming i
WHERE NOT EXISTS (
    SELECT 1
    FROM ref.display d
    WHERE d.lor_prop_id = i.lor_prop_id
)
AND NOT EXISTS (
    SELECT 1
    FROM ref.display d
    WHERE upper(btrim(d.display_name)) = upper(btrim(i.display_name))
)
ORDER BY i.stage_key, i.display_name;
```

Expected for this change: exactly three rows, one for each new physical display.

Stop if:

- fewer than three rows return;
- more than three rows return;
- any name, PropID, stage, string type, or color is wrong;
- a row expected to be new instead appears in a rename or changed-PropID query.

### 11.12 SPARE classifications

```sql
WITH latest AS (
    SELECT max(import_run_id) AS run_id
    FROM lor_snap.import_run
)
SELECT
    l.run_id,
    p.prop_id AS lor_prop_id,
    coalesce(nullif(btrim(p.lor_comment), ''), p.name) AS display_name,
    p.name AS prop_name,
    p.lor_comment AS prop_comment,
    lower(btrim(pr.stage_id)) AS stage_key,
    p.string_type,
    p.color,
    d.display_id AS conflicting_production_display_id,
    d.display_name AS conflicting_production_display_name,
    sc.lor_prop_id AS existing_spare_prop_id
FROM lor_snap.props p
JOIN latest l
  ON p.import_run_id = l.run_id
JOIN lor_snap.previews pr
  ON pr.import_run_id = p.import_run_id
 AND pr.id = p.preview_id
LEFT JOIN ref.display d
  ON d.lor_prop_id = p.prop_id
LEFT JOIN ref.spare_channel sc
  ON sc.lor_prop_id = p.prop_id
WHERE upper(coalesce(nullif(btrim(p.lor_comment), ''), p.name)) NOT LIKE '%PHANTOM%'
  AND (
      coalesce(nullif(btrim(p.lor_comment), ''), p.name) ILIKE '%spare%'
      OR coalesce(p.name, '') ILIKE '%spare%'
      OR coalesce(p.lor_comment, '') ILIKE '%spare%'
  )
ORDER BY stage_key, display_name, lor_prop_id;
```

Every classification must be intentional.

Any non-null `conflicting_production_display_id` is a manual-review conflict. The safe procedure must not delete that production display.

### 11.13 Production displays missing from the latest LOR snapshot

This procedure intentionally leaves missing production displays untouched. The query is an exception report, not a delete list.

```sql
WITH latest AS (
    SELECT max(import_run_id) AS run_id
    FROM lor_snap.import_run
),
incoming AS (
    SELECT DISTINCT
        p.prop_id AS lor_prop_id,
        upper(btrim(coalesce(nullif(btrim(p.lor_comment), ''), p.name))) AS normalized_display_name
    FROM lor_snap.props p
    JOIN latest l
      ON p.import_run_id = l.run_id
    JOIN lor_snap.previews pr
      ON pr.import_run_id = p.import_run_id
     AND pr.id = p.preview_id
    WHERE upper(coalesce(nullif(btrim(p.lor_comment), ''), p.name)) NOT LIKE '%PHANTOM%'
      AND pr.stage_id IS NOT NULL
      AND btrim(pr.stage_id) <> ''
      AND lower(btrim(pr.stage_id)) ~ '^0*\d{1,2}[a-z]?$'
      AND NOT (
          coalesce(nullif(btrim(p.lor_comment), ''), p.name) ILIKE '%spare%'
          OR coalesce(p.name, '') ILIKE '%spare%'
          OR coalesce(p.lor_comment, '') ILIKE '%spare%'
      )
)
SELECT
    d.display_id,
    d.display_name,
    d.lor_prop_id,
    d.inventory_type,
    ds.display_status_name,
    s.stage_key,
    s.stage_name
FROM ref.display d
LEFT JOIN ref.display_status ds
  ON ds.display_status_id = d.display_status_id
LEFT JOIN ref.stage s
  ON s.stage_id = d.stage_id
WHERE upper(coalesce(d.inventory_type, '')) = 'LOR'
  AND NOT EXISTS (
      SELECT 1
      FROM incoming i
      WHERE i.lor_prop_id = d.lor_prop_id
         OR i.normalized_display_name = upper(btrim(d.display_name))
  )
ORDER BY s.park_order, s.sub_order, d.display_name;
```

Every row must be explained. Common possibilities include:

- intentionally retired display;
- preview not included in the new snapshot;
- accidental deletion from LOR;
- renamed display with both name and PropID changed;
- invalid or blank stage assignment;
- SPARE misclassification.

Do not proceed merely because `p2` leaves these rows untouched.

### 11.14 Latest-versus-previous snapshot delta

Do not use `max(import_run_id) - 1`; run IDs may have gaps. Use ranked actual runs:

```sql
WITH ranked_runs AS (
    SELECT
        import_run_id,
        row_number() OVER (ORDER BY import_run_id DESC) AS rn
    FROM lor_snap.import_run
),
runs AS (
    SELECT
        max(import_run_id) FILTER (WHERE rn = 1) AS run_new,
        max(import_run_id) FILTER (WHERE rn = 2) AS run_old
    FROM ranked_runs
),
newp AS (
    SELECT p.*
    FROM lor_snap.props p
    CROSS JOIN runs r
    WHERE p.import_run_id = r.run_new
),
oldp AS (
    SELECT p.*
    FROM lor_snap.props p
    CROSS JOIN runs r
    WHERE p.import_run_id = r.run_old
),
j AS (
    SELECT
        coalesce(n.prop_id, o.prop_id) AS prop_id,
        n.prop_id IS NOT NULL AS in_new,
        o.prop_id IS NOT NULL AS in_old,
        o.lor_comment AS old_lor_comment,
        n.lor_comment AS new_lor_comment,
        o.name AS old_name,
        n.name AS new_name,
        o.device_type AS old_device_type,
        n.device_type AS new_device_type,
        o.start_channel AS old_start_channel,
        n.start_channel AS new_start_channel,
        o.end_channel AS old_end_channel,
        n.end_channel AS new_end_channel,
        o.network AS old_network,
        n.network AS new_network,
        o.uid AS old_uid,
        n.uid AS new_uid,
        o.preview_id AS old_preview_id,
        n.preview_id AS new_preview_id
    FROM newp n
    FULL OUTER JOIN oldp o
      USING (prop_id)
)
SELECT
    CASE
        WHEN in_new AND NOT in_old THEN 'ADDED'
        WHEN in_old AND NOT in_new THEN 'REMOVED'
        ELSE 'CHANGED'
    END AS change_type,
    *
FROM j
WHERE NOT (
    in_new
    AND in_old
    AND old_lor_comment IS NOT DISTINCT FROM new_lor_comment
    AND old_name IS NOT DISTINCT FROM new_name
    AND old_device_type IS NOT DISTINCT FROM new_device_type
    AND old_start_channel IS NOT DISTINCT FROM new_start_channel
    AND old_end_channel IS NOT DISTINCT FROM new_end_channel
    AND old_network IS NOT DISTINCT FROM new_network
    AND old_uid IS NOT DISTINCT FROM new_uid
    AND old_preview_id IS NOT DISTINCT FROM new_preview_id
)
ORDER BY change_type, coalesce(new_lor_comment, old_lor_comment, new_name, old_name);
```

Review all rows, not only the three additions.

## 12. GO/NO-GO Gate Before Promotion

Promotion is permitted only when every answer is `YES`.

| Gate | YES/NO |
| --- | --- |
| Correct production server and database confirmed | |
| Installed `p1` definition captured and reviewed | |
| Installed `p2` definition captured and reviewed | |
| Installed `p2` contains no production display delete | |
| Installed `p2` uses PropID → name → insert matching | |
| Installed `p2` joins previews on both run ID and preview ID | |
| Parser and SQLite version explicitly approved | |
| SQLite integrity and counts passed | |
| New snapshot run ID and counts verified | |
| Full backup completed and hashed | |
| New-stage list approved | |
| Stage-name changes approved | |
| Duplicate display names = 0 | |
| Duplicate/blank PropIDs = 0 | |
| Same-PropID renames approved | |
| Same-name changed-PropID rows approved | |
| Cross-identity collisions = 0 | |
| Brand-new display list contains exactly the expected three | |
| SPARE classifications approved | |
| Missing-production-display exception report approved | |
| Latest-versus-previous delta approved | |
| Reviewer authorizes transaction test | |

Any `NO` means stop.

## 13. Safely Run `p1` and `p2`

Run this in one pgAdmin query session or one `psql` session. Do not use autocommit.

The transaction holds both promotions until validation is complete. Any error or session disconnect before `COMMIT` rolls back both calls.

### 13.1 Start protected transaction

```sql
BEGIN;

SET LOCAL lock_timeout = '10s';
SET LOCAL statement_timeout = '10min';
SET LOCAL idle_in_transaction_session_timeout = '30min';

SELECT
    txid_current() AS transaction_id,
    current_database() AS database_name,
    current_user AS operator,
    now() AS transaction_started;
```

### 13.2 Capture before counts inside the transaction

```sql
CREATE TEMP TABLE import_control_counts AS
SELECT
    (SELECT max(import_run_id) FROM lor_snap.import_run) AS import_run_id,
    (SELECT count(*) FROM ref.stage) AS stage_count_before,
    (SELECT count(*) FROM ref.display) AS display_count_before,
    (SELECT count(*) FROM ref.spare_channel) AS spare_count_before;

TABLE import_control_counts;
```

### 13.3 Run `p1`

```sql
CALL ref.p1_upsert_stage_from_latest_lor();
```

### 13.4 Validate `p1` before `p2`

Required stage keys now missing:

```sql
WITH latest AS (
    SELECT max(import_run_id) AS run_id
    FROM lor_snap.import_run
),
required_keys AS (
    SELECT DISTINCT lower(btrim(pr.stage_id)) AS stage_key
    FROM lor_snap.props p
    JOIN latest l
      ON p.import_run_id = l.run_id
    JOIN lor_snap.previews pr
      ON pr.import_run_id = p.import_run_id
     AND pr.id = p.preview_id
    WHERE pr.stage_id IS NOT NULL
      AND btrim(pr.stage_id) <> ''
      AND lower(btrim(pr.stage_id)) ~ '^0*\d{1,2}[a-z]?$'
)
SELECT k.stage_key
FROM required_keys k
LEFT JOIN ref.stage s
  ON s.stage_key = k.stage_key
WHERE s.stage_id IS NULL
ORDER BY k.stage_key;
```

Expected: zero rows.

Stage count:

```sql
SELECT
    c.stage_count_before,
    count(*) AS stage_count_after_p1,
    count(*) - c.stage_count_before AS net_stage_change
FROM ref.stage
CROSS JOIN import_control_counts c
GROUP BY c.stage_count_before;
```

Inspect all stages affected in this transaction:

```sql
SELECT
    stage_id,
    stage_key,
    stage_name,
    folder_name,
    park_order,
    sub_order,
    updated_at,
    updated_by
FROM ref.stage
WHERE updated_at >= transaction_timestamp()
ORDER BY park_order, sub_order, stage_key;
```

Expected:

- all incoming existing stages may show an update because `p1` updates conflicts;
- names and folders exactly match approved preflight results;
- only approved new stages increase the count.

If wrong:

```sql
ROLLBACK;
```

Stop and investigate.

### 13.5 Run `p2`

Only after `p1` validation passes:

```sql
CALL ref.p2_upsert_display_from_latest_lor();
```

### 13.6 Validate `p2` before commit

Counts:

```sql
SELECT
    c.display_count_before,
    (SELECT count(*) FROM ref.display) AS display_count_after_p2,
    (SELECT count(*) FROM ref.display) - c.display_count_before AS net_display_change,
    c.spare_count_before,
    (SELECT count(*) FROM ref.spare_channel) AS spare_count_after_p2,
    (SELECT count(*) FROM ref.spare_channel) - c.spare_count_before AS net_spare_change
FROM import_control_counts c;
```

For the current change, expected `net_display_change = 3` only if:

- all three new displays are genuinely unmatched;
- no other new display is present;
- no production row is deleted.

Verify no production display disappeared by count:

```sql
SELECT
    CASE
        WHEN (SELECT count(*) FROM ref.display)
             < (SELECT display_count_before FROM import_control_counts)
        THEN 'FAIL: ref.display count decreased'
        ELSE 'PASS'
    END AS display_delete_guard;
```

Expected: `PASS`.

Verify current non-SPARE incoming identities resolve one-to-one:

```sql
WITH latest AS (
    SELECT max(import_run_id) AS run_id
    FROM lor_snap.import_run
),
incoming AS (
    SELECT DISTINCT ON (p.prop_id)
        p.prop_id AS lor_prop_id,
        coalesce(nullif(btrim(p.lor_comment), ''), p.name) AS display_name,
        lower(btrim(pr.stage_id)) AS stage_key,
        p.string_type,
        p.color
    FROM lor_snap.props p
    JOIN latest l
      ON p.import_run_id = l.run_id
    JOIN lor_snap.previews pr
      ON pr.import_run_id = p.import_run_id
     AND pr.id = p.preview_id
    WHERE upper(coalesce(nullif(btrim(p.lor_comment), ''), p.name)) NOT LIKE '%PHANTOM%'
      AND pr.stage_id IS NOT NULL
      AND btrim(pr.stage_id) <> ''
      AND lower(btrim(pr.stage_id)) ~ '^0*\d{1,2}[a-z]?$'
      AND NOT (
          coalesce(nullif(btrim(p.lor_comment), ''), p.name) ILIKE '%spare%'
          OR coalesce(p.name, '') ILIKE '%spare%'
          OR coalesce(p.lor_comment, '') ILIKE '%spare%'
      )
    ORDER BY
        p.prop_id,
        (nullif(btrim(p.lor_comment), '') IS NOT NULL) DESC,
        length(coalesce(p.lor_comment, '')) DESC,
        p.name DESC
)
SELECT
    i.lor_prop_id,
    i.display_name AS incoming_display_name,
    i.stage_key AS incoming_stage_key,
    d.display_id,
    d.display_name AS production_display_name,
    d.lor_prop_id AS production_lor_prop_id,
    s.stage_key AS production_stage_key,
    d.string_type,
    d.color
FROM incoming i
LEFT JOIN ref.display d
  ON d.lor_prop_id = i.lor_prop_id
LEFT JOIN ref.stage s
  ON s.stage_id = d.stage_id
WHERE d.display_id IS NULL
   OR upper(btrim(d.display_name)) <> upper(btrim(i.display_name))
   OR s.stage_key IS DISTINCT FROM i.stage_key
   OR d.string_type IS DISTINCT FROM i.string_type
   OR d.color IS DISTINCT FROM i.color
ORDER BY i.display_name;
```

Expected: zero rows.

Verify SPARE source rows exist in `ref.spare_channel`:

```sql
WITH latest AS (
    SELECT max(import_run_id) AS run_id
    FROM lor_snap.import_run
),
incoming_spares AS (
    SELECT DISTINCT ON (p.prop_id)
        p.prop_id AS lor_prop_id,
        coalesce(nullif(btrim(p.lor_comment), ''), p.name) AS display_name,
        lower(btrim(pr.stage_id)) AS stage_key,
        p.string_type,
        p.color
    FROM lor_snap.props p
    JOIN latest l
      ON p.import_run_id = l.run_id
    JOIN lor_snap.previews pr
      ON pr.import_run_id = p.import_run_id
     AND pr.id = p.preview_id
    WHERE upper(coalesce(nullif(btrim(p.lor_comment), ''), p.name)) NOT LIKE '%PHANTOM%'
      AND (
          coalesce(nullif(btrim(p.lor_comment), ''), p.name) ILIKE '%spare%'
          OR coalesce(p.name, '') ILIKE '%spare%'
          OR coalesce(p.lor_comment, '') ILIKE '%spare%'
      )
    ORDER BY
        p.prop_id,
        (nullif(btrim(p.lor_comment), '') IS NOT NULL) DESC,
        length(coalesce(p.lor_comment, '')) DESC,
        p.name DESC
)
SELECT
    i.*,
    sc.lor_prop_id AS stored_lor_prop_id,
    sc.display_name AS stored_display_name,
    s.stage_key AS stored_stage_key
FROM incoming_spares i
LEFT JOIN ref.spare_channel sc
  ON sc.lor_prop_id = i.lor_prop_id
LEFT JOIN ref.stage s
  ON s.stage_id = sc.stage_id
WHERE sc.lor_prop_id IS NULL
   OR sc.display_name IS DISTINCT FROM i.display_name
   OR s.stage_key IS DISTINCT FROM i.stage_key
   OR sc.string_type IS DISTINCT FROM i.string_type
   OR sc.color IS DISTINCT FROM i.color
ORDER BY i.display_name;
```

Expected: zero rows.

Inspect all production display rows updated or inserted in this transaction:

```sql
SELECT
    d.display_id,
    d.display_name,
    d.lor_prop_id,
    d.inventory_type,
    ds.display_status_name,
    s.stage_key,
    s.stage_name,
    d.string_type,
    d.color,
    d.updated_at,
    d.updated_by
FROM ref.display d
LEFT JOIN ref.display_status ds
  ON ds.display_status_id = d.display_status_id
LEFT JOIN ref.stage s
  ON s.stage_id = d.stage_id
WHERE d.updated_at >= transaction_timestamp()
ORDER BY s.park_order, s.sub_order, d.display_name;
```

Review the complete result before commit.

### 13.7 Validate the three new displays explicitly

Fill in the three exact approved PropIDs:

```sql
SELECT
    d.display_id,
    d.display_name,
    d.lor_prop_id,
    d.inventory_type,
    ds.display_status_name,
    s.stage_key,
    s.stage_name,
    d.string_type,
    d.color,
    d.created_at,
    d.created_by,
    d.updated_at,
    d.updated_by
FROM ref.display d
LEFT JOIN ref.display_status ds
  ON ds.display_status_id = d.display_status_id
LEFT JOIN ref.stage s
  ON s.stage_id = d.stage_id
WHERE d.lor_prop_id IN (
    'REPLACE_WITH_NEW_DISPLAY_1_PROPID',
    'REPLACE_WITH_NEW_DISPLAY_2_PROPID',
    'REPLACE_WITH_NEW_DISPLAY_3_PROPID'
)
ORDER BY d.display_name;
```

Required:

- exactly three rows;
- each has a newly assigned `display_id`;
- each name exactly matches its approved physical display identity;
- each PropID exactly matches LOR;
- each stage is correct;
- `inventory_type = 'LOR'`;
- status is `ACTIVE`;
- string type and color match the snapshot;
- no duplicate production identity was created.

Confirm no name duplicates:

```sql
SELECT
    upper(btrim(display_name)) AS normalized_display_name,
    count(*) AS row_count,
    array_agg(display_id ORDER BY display_id) AS display_ids,
    array_agg(lor_prop_id ORDER BY lor_prop_id) AS propids
FROM ref.display
GROUP BY upper(btrim(display_name))
HAVING count(*) > 1
ORDER BY normalized_display_name;
```

Required result: zero rows unless a previously documented and explicitly accepted legacy exception exists. No new display may create an exception.

Confirm no PropID duplicates:

```sql
SELECT
    lor_prop_id,
    count(*) AS row_count,
    array_agg(display_id ORDER BY display_id) AS display_ids
FROM ref.display
WHERE lor_prop_id IS NOT NULL
GROUP BY lor_prop_id
HAVING count(*) > 1
ORDER BY lor_prop_id;
```

Required result: zero rows.

### 13.8 Commit or roll back

If every validation passes and the reviewer approves:

```sql
COMMIT;
```

If any result is wrong, unclear, or unexpected:

```sql
ROLLBACK;
```

Do not attempt an improvised repair inside the open production transaction.

## 14. Post-Commit Verification

Open a new query session so results cannot be coming from an uncommitted transaction.

### 14.1 Confirm connection and latest run

```sql
SELECT
    current_database() AS database_name,
    current_user AS login_role,
    inet_server_addr() AS server_address,
    now() AS checked_at;

SELECT *
FROM lor_snap.import_run
ORDER BY import_run_id DESC
LIMIT 3;
```

### 14.2 Repeat final counts

```sql
SELECT
    (SELECT count(*) FROM ref.stage) AS stages,
    (SELECT count(*) FROM ref.display) AS displays,
    (SELECT count(*) FROM ref.spare_channel) AS spare_channels,
    (SELECT count(*) FROM lor_snap.v_current_previews) AS current_previews,
    (SELECT count(*) FROM lor_snap.v_current_props) AS current_props,
    (SELECT count(*) FROM lor_snap.v_current_sub_props) AS current_sub_props,
    (SELECT count(*) FROM lor_snap.v_current_dmx_channels) AS current_dmx_channels;
```

### 14.3 Verify no incoming non-SPARE is unresolved

Repeat the one-to-one validation query from Section 13.6. Expected: zero rows.

### 14.4 Verify the three new displays

Repeat Section 13.7 with the real PropIDs. Expected: exactly three correct rows.

### 14.5 Verify SPARE conflicts remain non-destructive

```sql
WITH latest AS (
    SELECT max(import_run_id) AS run_id
    FROM lor_snap.import_run
),
incoming_spares AS (
    SELECT DISTINCT p.prop_id AS lor_prop_id
    FROM lor_snap.props p
    JOIN latest l
      ON p.import_run_id = l.run_id
    JOIN lor_snap.previews pr
      ON pr.import_run_id = p.import_run_id
     AND pr.id = p.preview_id
    WHERE upper(coalesce(nullif(btrim(p.lor_comment), ''), p.name)) NOT LIKE '%PHANTOM%'
      AND (
          coalesce(nullif(btrim(p.lor_comment), ''), p.name) ILIKE '%spare%'
          OR coalesce(p.name, '') ILIKE '%spare%'
          OR coalesce(p.lor_comment, '') ILIKE '%spare%'
      )
)
SELECT
    d.display_id,
    d.display_name,
    d.lor_prop_id
FROM ref.display d
JOIN incoming_spares i
  ON i.lor_prop_id = d.lor_prop_id
ORDER BY d.display_name;
```

Any row represents a classified conflict retained for manual review. Its presence is not authorization to delete it.

### 14.6 Application-level checks

Verify through the production application:

- all three new displays are visible once;
- their stages are correct;
- renamed displays retained their existing production identity/history;
- displays whose PropIDs changed retained their existing `display_id`;
- existing work orders, testing records, labels, and other foreign-key relationships still resolve;
- no existing display unexpectedly disappeared;
- wiring/report views resolve to the new latest snapshot.

Do not edit production rows merely to make the UI appear correct. Investigate the source and procedure result first.

## 15. Rollback and Recovery

### 15.1 Error before snapshot ingest commits

The ingest script rolls back its transaction automatically.

Actions:

1. Record the error.
2. Verify no new `import_run_id` exists.
3. Correct the parser, SQLite artifact, credentials, schema mismatch, or ingest code.
4. Restart from SQLite validation.

### 15.2 Bad snapshot committed, but `p1`/`p2` not committed

Preferred response:

1. Do not run promotion.
2. Preserve the bad snapshot temporarily for evidence.
3. Correct LOR/parser data.
4. Create a new append-only snapshot.
5. Re-run all preflights against the new maximum run.

Because current-state views and procedures select `max(import_run_id)`, leaving a known-bad run as maximum blocks operation until a corrected newer run exists.

If an explicit decision is made to remove the bad run instead, first prove the exact target:

```sql
SELECT
    r.import_run_id,
    r.run_ts,
    r.notes,
    (SELECT count(*) FROM lor_snap.previews p
      WHERE p.import_run_id = r.import_run_id) AS previews,
    (SELECT count(*) FROM lor_snap.props p
      WHERE p.import_run_id = r.import_run_id) AS props,
    (SELECT count(*) FROM lor_snap.sub_props sp
      WHERE sp.import_run_id = r.import_run_id) AS sub_props,
    (SELECT count(*) FROM lor_snap.dmx_channels dc
      WHERE dc.import_run_id = r.import_run_id) AS dmx_channels
FROM lor_snap.import_run r
WHERE r.import_run_id = 123;
```

Deletion is destructive and must be separately approved. If approved:

```sql
BEGIN;

DELETE FROM lor_snap.import_run
WHERE import_run_id = 123
RETURNING import_run_id, run_ts, notes;

-- Verify the correct previous run is current before committing.
SELECT *
FROM lor_snap.import_run
ORDER BY import_run_id DESC
LIMIT 3;

-- COMMIT only after review.
ROLLBACK;
```

The example ends in `ROLLBACK` intentionally. Change it to `COMMIT` only under a separately reviewed recovery authorization.

### 15.3 `p1` or `p2` validation fails before commit

Run:

```sql
ROLLBACK;
```

Then:

1. Verify production `ref.stage`, `ref.display`, and `ref.spare_channel` counts returned to their before values.
2. Save the failed query results.
3. Correct the procedure or source data outside the failed transaction.
4. Repeat installed-definition inspection and all preflights.

### 15.4 Wrong promotion was committed

Stop application writes if operationally practical and preserve evidence.

Do not:

- rerun a different procedure blindly;
- delete the three new rows without checking dependent foreign keys;
- change `display_id`;
- truncate `ref.display`;
- restore only one table without analyzing relationships.

Recovery order:

1. Record the bad import run, commit time, operator, and observed fault.
2. Capture current database and procedure definitions.
3. Identify all rows changed by the import using timestamps, audit fields, the approved preflight, and the backup.
4. Check foreign-key dependencies before reversing rows:

```sql
SELECT
    conrelid::regclass AS referencing_table,
    conname AS constraint_name,
    pg_get_constraintdef(oid) AS constraint_definition
FROM pg_constraint
WHERE contype = 'f'
  AND confrelid IN (
      'ref.stage'::regclass,
      'ref.display'::regclass,
      'ref.spare_channel'::regclass
  )
ORDER BY conrelid::regclass::text, conname;
```

5. Restore to a separate recovery database first:

```powershell
createdb `
    --host "192.168.5.9" `
    --port 5432 `
    --username "msbadmin" `
    "msb_lor_recovery"

pg_restore `
    --host "192.168.5.9" `
    --port 5432 `
    --username "msbadmin" `
    --dbname "msb_lor_recovery" `
    --verbose `
    "G:\Shared drives\MSB Database\database\backups\msb_before_lor_import_TIMESTAMP.dump"
```

6. Compare recovered `ref` rows with production.
7. Write a targeted, reviewed repair transaction that preserves `display_id` and dependent records.
8. Validate the repair in the recovery database.
9. Back up production again.
10. Execute the approved targeted repair in one transaction with before/after validation.

A full production restore is a last resort and requires a separate outage and restore plan.

## 16. Final Verification Checklist

### Source and snapshot

- [ ] Correct preview set exported.
- [ ] Parser version recorded.
- [ ] SQLite filename and SHA-256 recorded.
- [ ] SQLite integrity check returned `ok`.
- [ ] SQLite counts were plausible.
- [ ] New `lor_snap.import_run` is uniquely identified.
- [ ] Snapshot counts match ingest output.
- [ ] Latest-versus-previous delta was reviewed completely.

### Procedure control

- [ ] Installed `p1` definition captured.
- [ ] Installed `p2` definition captured.
- [ ] Installed definitions match reviewed authoritative definitions.
- [ ] `p2` contains no destructive `ref.display` delete.
- [ ] `p2` uses PropID → display name → insert matching.
- [ ] Every current props-to-previews join includes `import_run_id`.
- [ ] Repository commit used for comparison is recorded.

### Preflight

- [ ] New stages approved.
- [ ] Changed stage names approved.
- [ ] Missing stage keys understood before `p1`.
- [ ] Duplicate incoming display names = 0.
- [ ] Duplicate incoming PropIDs = 0.
- [ ] Blank incoming PropIDs = 0.
- [ ] Same-PropID renames approved.
- [ ] Same-name changed-PropID rows approved.
- [ ] Cross-identity collisions = 0.
- [ ] Brand-new display preflight returned exactly three approved rows.
- [ ] SPARE classifications approved.
- [ ] Production displays absent from latest snapshot reviewed.

### Protection and execution

- [ ] Full `pg_dump` completed with exit code `0`.
- [ ] Backup file and SHA-256 recorded.
- [ ] `p1` and `p2` ran in one explicit transaction.
- [ ] `p1` validation passed before `p2`.
- [ ] `p2` validation passed before commit.
- [ ] `ref.display` count did not decrease.
- [ ] Reviewer approved `COMMIT`.

### Post-import

- [ ] New session confirms committed values.
- [ ] Exactly three new production displays exist.
- [ ] New display names, PropIDs, stages, types, colors, and statuses are correct.
- [ ] Existing renamed displays retained `display_id`.
- [ ] Existing displays with replaced PropIDs retained `display_id`.
- [ ] No new duplicate display names exist.
- [ ] No duplicate PropIDs exist.
- [ ] SPARE rows are represented in `ref.spare_channel`.
- [ ] SPARE conflicts did not delete production displays.
- [ ] Missing snapshot displays remain available pending separate disposition.
- [ ] Application, work-order, label, test-history, and wiring checks passed.
- [ ] Change record and query results were retained.

## 17. Repository Cleanup Required After the Production Test

This cleanup is not part of the production import transaction, but it is required to prevent recurrence:

1. Create complete deployable SQL files using `CREATE OR REPLACE PROCEDURE`.
2. Correct the current-run preview joins in `p2`.
3. Retain one authoritative `p1` file and one authoritative `p2` file.
4. Move the destructive `p2` v2 file to `archive` and mark it unsafe.
5. Archive or remove the PropID-only `p2` v1 from active procedure directories.
6. Update `Z_Import_LOR_to_Postgres.md` for the approved V7 parser/SQLite path.
7. Replace any `max(import_run_id) - 1` comparison with ranking of actual run IDs.
8. Add an automated preflight script that exits nonzero on:
   - duplicate names;
   - duplicate or blank PropIDs;
   - missing stage keys;
   - cross-identity collisions;
   - unresolved SPARE conflicts;
   - unexpected brand-new display count.

## 18. Known Unresolved Inputs

The following must be supplied or confirmed before this runbook can move from DRAFT to APPROVED:

- the production-installed `p1` definition;
- the production-installed `p2` definition;
- the corrected complete authoritative `p2` deployment SQL;
- the approved parser version;
- the approved SQLite filename;
- the current SQLite snapshot;
- the exact names, PropIDs, and expected stage keys for the three new displays;
- actual read-only preflight output;
- backup completion evidence;
- operator and reviewer approval.
