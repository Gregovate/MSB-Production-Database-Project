-- --- Confirm required columns exist (adjust names if yours differ)
-- Expect at minimum: person_id PK, email unique, manager boolean

select column_name, data_type
from information_schema.columns
where table_schema = 'ref'
  and table_name   = 'person'
order by ordinal_position;

-- --- Confirm email uniqueness (should return 0 rows)
select lower(btrim(email)) as email_norm, count(*) as n
from ref.person
where email is not null and btrim(email) <> ''
group by 1
having count(*) > 1;

-- --- Confirm manager boolean exists (or equivalent)
-- If your column is named differently (e.g., is_manager), adjust.
select column_name, data_type
from information_schema.columns
where table_schema = 'ref'
  and table_name   = 'person'
  and lower(column_name) like '%manager%';