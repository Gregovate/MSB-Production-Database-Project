/* ============================================================
Procedure: ref.p2_upsert_display_from_latest_lor()

Purpose:
  Upsert NON-SPARE displays into ref.display from latest LOR snapshot.
  Route SPARE items into ref.spare_channel.
  Ensure NO SPARE rows remain in ref.display for latest run set.

Revision History:
  2026-02-27 GAL  Fix CTE scope bug by materializing tmp_classified.
  2026-02-28 GAL  Dedupe lor_prop_id to prevent ON CONFLICT double-update.
============================================================ */

drop procedure if exists ref.p2_upsert_display_from_latest_lor();

create procedure ref.p2_upsert_display_from_latest_lor()
language plpgsql
as $$
declare
  v_run_id bigint;
  v_active_status_id integer;
  v_missing_stage_keys integer;
begin
  /* 1) Latest import */
  select max(import_run_id) into v_run_id
  from lor_snap.import_run;

  if v_run_id is null then
    raise exception 'No import_run_id found in lor_snap.import_run';
  end if;

  /* 2) ACTIVE display status */
  select display_status_id into v_active_status_id
  from ref.display_status
  where upper(display_status_name) = 'ACTIVE'
  limit 1;

  if v_active_status_id is null then
    raise exception 'ACTIVE status not found in ref.display_status';
  end if;

  /* 3) Guardrail: stage keys must exist */
  select count(*) into v_missing_stage_keys
  from (
    select distinct lower(btrim(pr.stage_id)) as stage_key
    from lor_snap.props p
    join lor_snap.previews pr on pr.id = p.preview_id
    where p.import_run_id = v_run_id
      and pr.stage_id is not null
      and btrim(pr.stage_id) <> ''
      and lower(btrim(pr.stage_id)) ~ '^0*\d{1,2}[a-z]?$'
  ) k
  left join ref.stage s on s.stage_key = k.stage_key
  where s.stage_key is null;

  if v_missing_stage_keys > 0 then
    raise exception
      'Missing % stage_key rows in ref.stage for latest import_run_id=% (run p1_upsert_stage first)',
      v_missing_stage_keys, v_run_id;
  end if;

  /* 4) Materialize a deterministic, deduped classified set for this run */
  create temporary table tmp_classified (
    lor_prop_id text,
    display_name text,
    prop_name text,
    prop_comment text,
    preview_stage_key text,
    is_spare boolean
  ) on commit drop;

  insert into tmp_classified (lor_prop_id, display_name, prop_name, prop_comment, preview_stage_key, is_spare)
  select
    lr.lor_prop_id,
    lr.display_name,
    lr.prop_name,
    lr.prop_comment,
    lr.preview_stage_key,
    case
      when lr.display_name ilike '%spare%'
        or coalesce(lr.prop_name,'') ilike '%spare%'
        or coalesce(lr.prop_comment,'') ilike '%spare%'
      then true else false
    end as is_spare
  from (
    select distinct on (p.prop_id)
      p.prop_id as lor_prop_id,
      coalesce(nullif(btrim(p.lor_comment), ''), p.name) as display_name,
      p.name as prop_name,
      p.lor_comment as prop_comment,
      lower(btrim(pr.stage_id)) as preview_stage_key
    from lor_snap.props p
    join lor_snap.previews pr
      on pr.id = p.preview_id
    where p.import_run_id = v_run_id
      and upper(coalesce(nullif(btrim(p.lor_comment), ''), p.name)) not like '%PHANTOM%'
      and pr.stage_id is not null
      and btrim(pr.stage_id) <> ''
      and lower(btrim(pr.stage_id)) ~ '^0*\d{1,2}[a-z]?$'
    order by
      p.prop_id,
      (nullif(btrim(p.lor_comment), '') is not null) desc,
      length(coalesce(p.lor_comment, '')) desc,
      p.name desc
  ) lr;

  /* 5) Upsert SPARE into ref.spare_channel */
  insert into ref.spare_channel (
      lor_prop_id,
      display_name,
      inventory_type,
      display_status_id,
      stage_id
  )
  select
      c.lor_prop_id,
      c.display_name,
      'LOR',
      v_active_status_id,
      s.stage_id
  from tmp_classified c
  join ref.stage s
    on s.stage_key = c.preview_stage_key
  where c.is_spare = true
  on conflict (lor_prop_id)
  do update set
      display_name      = excluded.display_name,
      inventory_type    = excluded.inventory_type,
      display_status_id = excluded.display_status_id,
      stage_id          = excluded.stage_id;

  /* 6) Ensure SPARE rows are NOT in ref.display (latest run set only) */
  delete from ref.display d
  using tmp_classified c
  where c.is_spare = true
    and d.lor_prop_id = c.lor_prop_id;

  /* 7) Upsert NON-SPARE into ref.display */
  insert into ref.display (
      lor_prop_id,
      display_name,
      inventory_type,
      display_status_id,
      stage_id
  )
  select
      c.lor_prop_id,
      c.display_name,
      'LOR',
      v_active_status_id,
      s.stage_id
  from tmp_classified c
  join ref.stage s
    on s.stage_key = c.preview_stage_key
  where c.is_spare = false
  on conflict (lor_prop_id)
  do update set
      display_name      = excluded.display_name,
      inventory_type    = excluded.inventory_type,
      display_status_id = excluded.display_status_id,
      stage_id          = excluded.stage_id;

end;
$$;