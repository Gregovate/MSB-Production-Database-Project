select dts.display_test_session_id,
       dts.display_id,
       d.display_name
from ops.display_test_session dts
left join ref.display d
  on d.display_id = dts.display_id
where d.display_id is null
limit 10;