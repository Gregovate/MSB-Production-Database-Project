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
j as (
  select
    coalesce(n.prop_id, o.prop_id) as prop_id,

    n.prop_id is not null as in_new,
    o.prop_id is not null as in_old,

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
    o.uid as old_uid,

    n.name as new_name,
    o.name as old_name
  from newp n
  full outer join oldp o using (prop_id)
)
select
  case
    when in_new and not in_old then 'ADDED'
    when in_old and not in_new then 'REMOVED'
    when in_new and in_old and (
      new_lor_comment is distinct from old_lor_comment
      or new_device_type is distinct from old_device_type
      or new_start_channel is distinct from old_start_channel
      or new_end_channel is distinct from old_end_channel
      or new_network is distinct from old_network
      or new_uid is distinct from old_uid
      or new_name is distinct from old_name
    ) then 'CHANGED'
    else 'SAME'
  end as change_type,

  prop_id,

  old_lor_comment, new_lor_comment,
  old_device_type, new_device_type,
  old_start_channel, new_start_channel,
  old_end_channel, new_end_channel,
  old_network, new_network,
  old_uid, new_uid,
  old_name, new_name

from j
where not (
  in_new and in_old and
  new_lor_comment is not distinct from old_lor_comment and
  new_device_type is not distinct from old_device_type and
  new_start_channel is not distinct from old_start_channel and
  new_end_channel is not distinct from old_end_channel and
  new_network is not distinct from old_network and
  new_uid is not distinct from old_uid and
  new_name is not distinct from old_name
)
order by change_type, coalesce(new_lor_comment, old_lor_comment);