/* ============================================================
MSB Database — Development Helper Queries
Author: Greg Liebig
Purpose:
  Reusable diagnostic and schema lookup queries.
  This replaces the need for a visual query builder.

NOTE:
  Change schema/table literals as needed.
============================================================ */


/* ------------------------------------------------------------
1) SHOW TABLE COLUMNS
Purpose:
  Quickly list columns and types for any table.
Use:
  Change table_schema + table_name.
------------------------------------------------------------ */
select
  column_name,
  data_type
from information_schema.columns
where table_schema = 'ref'
  and table_name   = 'container'
order by ordinal_position;



/* ------------------------------------------------------------
2) SHOW FOREIGN KEYS FOR TABLE
Purpose:
  See relationships (Paradox-style awareness).
------------------------------------------------------------ */
select
  tc.constraint_name,
  kcu.column_name,
  ccu.table_schema as foreign_schema,
  ccu.table_name as foreign_table,
  ccu.column_name as foreign_column
from information_schema.table_constraints tc
join information_schema.key_column_usage kcu
  on tc.constraint_name = kcu.constraint_name
join information_schema.constraint_column_usage ccu
  on ccu.constraint_name = tc.constraint_name
where tc.table_schema = 'ref'
  and tc.table_name = 'container'
  and tc.constraint_type = 'FOREIGN KEY';



/* ------------------------------------------------------------
3) CONTAINER → DISPLAY COUNTS (REFERENCE TRUTH)
Purpose:
  Shows how many displays are assigned to each container
  according to ref.display.
------------------------------------------------------------ */
select
  c.container_id,
  c.description as container_description,
  count(d.display_id) as ref_display_count
from ref.container c
left join ref.display d
  on d.container_id = c.container_id
group by c.container_id, c.description
order by ref_display_count desc;



/* ------------------------------------------------------------
4) 2026 SESSION CHILD COUNTS (ACTUAL WORK RECORDED)
Purpose:
  Shows how many child rows currently exist per container
  in ops.display_test_session for season 2026.
------------------------------------------------------------ */
select
  ts.container_id,
  count(dts.*) as actual_child_rows
from ops.test_session ts
left join ops.display_test_session dts
  on dts.test_session_id = ts.test_session_id
where ts.season_year = 2026
group by ts.container_id
order by actual_child_rows desc;



/* ------------------------------------------------------------
5) EXPECTED vs ACTUAL CHECKLIST SIZE (CRITICAL DIAGNOSTIC)
Purpose:
  Compares ref.display truth vs legacy child rows.
  If actual > expected = problem.
  If actual < expected = incomplete snapshot.
------------------------------------------------------------ */
with expected as (
  select container_id, count(*) as expected_count
  from ref.display
  group by container_id
),
actual as (
  select ts.container_id, count(dts.*) as actual_count
  from ops.test_session ts
  left join ops.display_test_session dts
    on dts.test_session_id = ts.test_session_id
  where ts.season_year = 2026
  group by ts.container_id
)
select
  c.container_id,
  c.description,
  coalesce(e.expected_count,0) as expected_from_ref,
  coalesce(a.actual_count,0) as actual_from_legacy,
  coalesce(a.actual_count,0) - coalesce(e.expected_count,0) as delta
from ref.container c
left join expected e on e.container_id = c.container_id
left join actual a   on a.container_id = c.container_id
order by abs(coalesce(a.actual_count,0) - coalesce(e.expected_count,0)) desc;