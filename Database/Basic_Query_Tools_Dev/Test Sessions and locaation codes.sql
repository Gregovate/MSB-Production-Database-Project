select
    ts.home_location_code,
    ts.work_location_code,
    ts.container_id,
    count(dts.display_test_session_id) as child_rows,
    c.location_code
from
    ops.test_session ts
inner join "ref".container c on
    ts.container_id = c.container_id
left join ops.display_test_session dts on
    dts.test_session_id = ts.test_session_id
where
    ts.season_year = 2026
group by
    ts.home_location_code,
    ts.work_location_code,
    ts.container_id,
    c.location_code
order by
    ts.container_id;
