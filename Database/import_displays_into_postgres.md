Good call. Do both:

Stored procedures give you a repeatable, DB-native pipeline you can run from pgAdmin.

Python gives you the missing piece: reliable CSV load (COPY) + “generate report + email” later.

Below is a clean starter set you can drop into Postgres now.

1) Stored procedures
1A) Reset staging tables
create or replace procedure stage.reset_display_sheet()

```sql
as $$
begin
  truncate table stage.display_sheet_csv;
  truncate table stage.display_sheet_raw;
end;
$$;
```

1B) Transform CSV → RAW (handles commas like 1,304, strips junk, casts types)
create or replace procedure stage.transform_display_sheet_csv_to_raw()
language plpgsql
as $$
begin
  truncate table stage.display_sheet_raw;

  insert into stage.display_sheet_raw (
    display_name, inventory_type, display_status,
    designer_name, theme_name, frame_name,
    pallet_id_raw, year_built, amps_measured, est_light_count,
    dumb_controller, notes
  )
  select
    nullif(btrim(display_name),''),
    nullif(btrim(inventory_type),''),
    nullif(btrim(display_status),''),

    nullif(btrim(designer_id),'') as designer_name,
    nullif(btrim(theme_id),'')    as theme_name,
    nullif(btrim(frame_id),'')    as frame_name,

    nullif(btrim(pallet_id),'')   as pallet_id_raw,

    nullif(regexp_replace(btrim(coalesce(year_built,'')), '[^0-9]', '', 'g'), '')::integer,

    nullif(regexp_replace(btrim(coalesce(amps_measured,'')), '[^0-9\.]', '', 'g'), '')::numeric(8,2),

    nullif(regexp_replace(btrim(coalesce(est_light_count,'')), '[^0-9]', '', 'g'), '')::integer,

    nullif(btrim(dumb_controller),''),
    nullif(btrim(notes),'')
  from stage.display_sheet_csv;
end;
$$;
1C) Rebuild ref.display from latest LOR snapshot (truncate + seed)
create or replace procedure ref.rebuild_display_from_latest_lor()
language plpgsql
as $$
declare
  v_run_id integer;
  v_active_status_id integer;
begin
  select max(import_run_id) into v_run_id from lor_snap.import_run;

  select display_status_id
    into v_active_status_id
  from ref.display_status
  where upper(display_status_name) = 'ACTIVE'
  limit 1;

  if v_active_status_id is null then
    raise exception 'ACTIVE status not found in ref.display_status';
  end if;

  truncate table ref.display;

  insert into ref.display (lor_prop_id, display_name, inventory_type, display_status_id)
  select
    p.prop_id,
    coalesce(nullif(btrim(p.lor_comment), ''), p.name) as display_name,
    'LOR',
    v_active_status_id
  from lor_snap.props p
  where p.import_run_id = v_run_id;
end;
$$;
1D) Apply spreadsheet metadata onto ref.display (matched rows only)

This assumes you already created stage.v_sheet_match (view). If not, create it first (same as earlier).

create or replace procedure ref.apply_display_metadata_from_sheet()
language plpgsql
as $$
begin
  -- Update direct fields (including pallet_id normalization "1.0" → "1")
  update ref.display d
  set
    year_built      = m.year_built,
    amps_measured   = m.amps_measured,
    est_light_count = m.est_light_count,
    dumb_controller = m.dumb_controller,
    notes           = m.notes,
    pallet_id       = nullif(regexp_replace(coalesce(m.pallet_id_raw,''), '\.0$', ''), ''),
    updated_at      = now(),
    updated_by      = current_user
  from stage.v_sheet_match m
  where m.lor_prop_id = d.lor_prop_id;

  -- Status name → id
  update ref.display d
  set
    display_status_id = ds.display_status_id,
    updated_at = now(),
    updated_by = current_user
  from stage.v_sheet_match m
  join ref.display_status ds
    on upper(ds.display_status_name) = upper(m.display_status)
  where m.lor_prop_id = d.lor_prop_id
    and m.display_status is not null;

  -- Theme name → theme_id
  update ref.display d
  set
    theme_id = t.theme_id,
    updated_at = now(),
    updated_by = current_user
  from stage.v_sheet_match m
  join ref.theme t
    on upper(t.theme_name) = upper(m.theme_name)
  where m.lor_prop_id = d.lor_prop_id
    and m.theme_name is not null;

  -- Designer "First Last" → person_id
  update ref.display d
  set
    designer_id = p.person_id,
    updated_at = now(),
    updated_by = current_user
  from stage.v_sheet_match m
  join ref.person p
    on upper(p.first_name || ' ' || p.last_name) = upper(m.designer_name)
  where m.lor_prop_id = d.lor_prop_id
    and m.designer_name is not null;

  -- Frame mapping: adjust column name if needed
  -- If ref.frame has frame_name:
  update ref.display d
  set
    frame_id = f.frame_id,
    updated_at = now(),
    updated_by = current_user
  from stage.v_sheet_match m
  join ref.frame f
    on upper(f.frame_name) = upper(m.frame_name)
  where m.lor_prop_id = d.lor_prop_id
    and m.frame_name is not null;

end;
$$;
2) “One command” run order in pgAdmin

After you import the CSV into stage.display_sheet_csv (via pgAdmin Import/Export UI):

call stage.reset_display_sheet();              -- optional if you already truncated
-- (import CSV into stage.display_sheet_csv)
call stage.transform_display_sheet_csv_to_raw();

call ref.rebuild_display_from_latest_lor();
call ref.apply_display_metadata_from_sheet();

-- then look at exceptions:
select * from public.rpt_sheet_lor_unmatched;  -- if you created it
-- OR directly:
select * from stage.v_sheet_match
where upper(coalesce(inventory_type,'LOR'))='LOR' and lor_prop_id is null
order by display_name;

That supports your “truncate and start over again a few times” workflow cleanly.

3) Python routine (loads CSV + calls procedures)

This is what you’ll eventually extend to “email the report”.

Here’s a minimal skeleton using psycopg (v3). It does:

COPY into stage.display_sheet_csv

call the procedures in order

import pathlib
import psycopg

CSV_PATH = pathlib.Path(r"C:\path\to\Table Design and Actual Data - Active Version - Displays (1).csv")

CONN_STR = "host=... dbname=... user=... password=... port=5432"

def main() -> None:
    if not CSV_PATH.exists():
        raise FileNotFoundError(CSV_PATH)

    with psycopg.connect(CONN_STR) as conn:
        with conn.cursor() as cur:
            # Reset stage tables
            cur.execute("call stage.reset_display_sheet();")

            # COPY into landing table (fast + reliable)
            with CSV_PATH.open("rb") as f:
                cur.copy(
                    "copy stage.display_sheet_csv from stdin with (format csv, header true, encoding 'utf8')",
                    f
                )

            # Transform + rebuild + apply
            cur.execute("call stage.transform_display_sheet_csv_to_raw();")
            cur.execute("call ref.rebuild_display_from_latest_lor();")
            cur.execute("call ref.apply_display_metadata_from_sheet();")

            # Example: fetch unmatched count
            cur.execute("""
                select count(*)
                from stage.v_sheet_match
                where upper(coalesce(inventory_type,'LOR'))='LOR'
                  and lor_prop_id is null;
            """)
            (unmatched,) = cur.fetchone()
            print(f"Unmatched sheet LOR rows: {unmatched}")

        conn.commit()

if __name__ == "__main__":
    main()

One important thing to decide now

Do you want the “truncate ref.display” step to be:

always truncate (what I coded, fastest for iteration), or

upsert (safer later when ops tables start referencing displays)

For your current phase (rebuilding a few times): truncate is correct.

When ops tables exist, we’ll switch to upsert and protect references.

If you want, paste your ref.frame column list (just like you did for previews) and I’ll lock the frame join line so it can’t fail.