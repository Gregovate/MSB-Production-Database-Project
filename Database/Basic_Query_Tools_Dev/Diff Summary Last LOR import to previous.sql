with runs as (
  select
    (select max(import_run_id) from lor_snap.import_run) as run_new,
    (select max(import_run_id) - 1 from lor_snap.import_run) as run_old
),
newp as (
  select * from lor_snap.props
  where import_run_id = (select run_new from runs)
),
oldp as (
  select * from lor_snap.props
  where import_run_id = (select run_old from runs)
),
joined as (
  select
    coalesce(n.prop_id, o.prop_id) as prop_id,
    n.prop_id is not null as in_new,
    o.prop_id is not null as in_old,

    -- fields you care about for "did it change"
    n.lor_comment as new_lor_comment,
    o.lor_comment as old_lor_comment,
    n.device_type as new_device_type,
    o.device_type as old_device_type,
    n.start_channel as new_start_channel,
    o.start_channel as old_start_channel,
    n.end_channel as new_end_channel,
    o.end_channel as old_end_channel,
    n.network as new_network,
    o.network as old_network,
    n.uid as new_uid,
    o.uid as old_uid
  from newp n
  full outer join oldp o using (prop_id)
)
select
  sum(case when in_new and not in_old then 1 else 0 end) as added,
  sum(case when in_old and not in_new then 1 else 0 end) as removed,
  sum(case
        when in_new and in_old and (
          new_lor_comment is distinct from old_lor_comment
          or new_device_type is distinct from old_device_type
          or new_start_channel is distinct from old_start_channel
          or new_end_channel is distinct from old_end_channel
          or new_network is distinct from old_network
          or new_uid is distinct from old_uid
        )
        then 1 else 0 end) as changed
from joined;