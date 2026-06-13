select
    coalesce(test_result, '<<NULL>>') as test_result,
    count(*) as count
from ops.display_test_session
group by test_result
order by test_result;