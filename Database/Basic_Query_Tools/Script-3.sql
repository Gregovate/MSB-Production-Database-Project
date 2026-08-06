-- A) If it's a constraint:
select
  con.conname,
  con.contype,
  con.conrelid::regclass as on_table,
  pg_get_constraintdef(con.oid) as def
from pg_constraint con
where con.conname = 'ux_pallet_location_code';