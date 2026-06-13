-- before
select count(*) as sessions_2026,
       count(home_location_code) as with_home
from ops.test_session
where season_year = 2026;