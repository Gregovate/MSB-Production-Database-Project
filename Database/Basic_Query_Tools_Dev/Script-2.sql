ops.test_sessionselect
    ts.home_location_code,
    ts.work_location_code,
    ts.container_id
from
    ops.display_test_session dts
inner join ops.test_session ts on
    dts.test_session_id = ts.test_session_id;
