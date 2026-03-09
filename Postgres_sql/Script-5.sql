select
    ts.container_id,
    c.description,
    d.display_name,
    dts.lor_prop_id
from
    ops.test_session ts
left join ref.container c on
    c.container_id = ts.container_id
left join ref.display d on
    d.container_id = ts.container_id
inner join ops.display_test_session dts on
    d.lor_prop_id = dts.lor_prop_id
where
    ts.season_year = 2026
group by
    ts.container_id,
    c.description,
    d.display_name,
    dts.lor_prop_id
having
    count(d.display_name) = 0
order by
    ts.container_id;
