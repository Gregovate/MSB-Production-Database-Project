/*
Procedure: ref.p2_upsert_display_from_latest_lor

Purpose:
  Upsert ref.display from latest LOR snapshot (lor_snap.props).
  LOR-owned fields always updated for props present in latest import_run:
    - display_name
    - inventory_type
    - display_status_id
    - stage_id (via props.preview_id → previews.id → ref.stage.stage_key)

  Displays not present in latest import are untouched.

Reads:
  lor_snap.import_run
  lor_snap.props
  lor_snap.previews
  ref.stage
  ref.display_status

Writes:
  ref.display (UPSERT)

Prereq:
  ref.p1_upsert_stage_from_latest_lor() must run first.

Revision History:
  2026-02-27  GAL  Join fix: constrain previews to latest import_run (previews.id repeats across runs).
  2026-02-27  GAL  Normalize + filter stage_id to match p1 (trim + canonical regex).
  2026-02-27  GAL  Defensive de-dupe to prevent ON CONFLICT "row a second time" crashes.
*/
declare
  v_run_id bigint;
  v_active_status_id integer;
  v_missing_stage_keys integer;
begin
  /* 1) Latest import */
  select max(import_run_id)
    into v_run_id
  from lor_snap.import_run;

  if v_run_id is null then
    raise exception 'No import_run_id found in lor_snap.import_run';
  end if;

  /* 2) ACTIVE display status */
  select display_status_id
    into v_active_status_id
  from ref.display_status
  where upper(display_status_name) = 'ACTIVE'
  limit 1;

  if v_active_status_id is null then
    raise exception 'ACTIVE status not found in ref.display_status';
  end if;

  /*
    pr_one:
      Pull ONLY previews from the latest run.
      Defensive DISTINCT ON (id) in case previews ever contains duplicates within a run.
      (This also prevents the join multiplying props.)
  */
  with pr_one as (
    select distinct on (pr.id)
      pr.id,
      pr.stage_id
    from lor_snap.previews pr
    where pr.import_run_id = v_run_id
    order by pr.id
  ),
  keys as (
    select distinct
      lower(btrim(pr.stage_id)) as stage_key
    from lor_snap.props p
    join pr_one pr
      on pr.id = p.preview_id
    where p.import_run_id = v_run_id
      and pr.stage_id is not null
      and btrim(pr.stage_id) <> ''
      and lower(btrim(pr.stage_id)) ~ '^0*\d{1,2}[a-z]?$'
  )
  /* 3) Guardrail: stage keys required by latest LOR must exist in ref.stage */
  select count(*)
    into v_missing_stage_keys
  from keys k
  left join ref.stage s
    on s.stage_key = k.stage_key
  where s.stage_key is null;

  if v_missing_stage_keys > 0 then
    raise exception
      'Missing % stage_key rows in ref.stage for latest import_run_id=% (run p1_upsert_stage first)',
      v_missing_stage_keys, v_run_id;
  end if;

  /* 4) Upsert displays from latest LOR snapshot */
  with pr_one as (
    select distinct on (pr.id)
      pr.id,
      pr.stage_id
    from lor_snap.previews pr
    where pr.import_run_id = v_run_id
    order by pr.id
  ),
  src as (
    /*
      Defensive DISTINCT ON (p.prop_id) so a prop can’t appear twice in the INSERT set
      (avoids ON CONFLICT "cannot affect row a second time").
    */
    select distinct on (p.prop_id)
      p.prop_id as lor_prop_id,
      coalesce(nullif(btrim(p.lor_comment), ''), p.name) as display_name,
      'LOR'::text as inventory_type,
      v_active_status_id as display_status_id,
      s.stage_id as stage_id
    from lor_snap.props p
    join pr_one pr
      on pr.id = p.preview_id
    join ref.stage s
      on s.stage_key = lower(btrim(pr.stage_id))
    where p.import_run_id = v_run_id
      and upper(coalesce(nullif(btrim(p.lor_comment), ''), p.name)) not like '%PHANTOM%'
      and pr.stage_id is not null
      and btrim(pr.stage_id) <> ''
      and lower(btrim(pr.stage_id)) ~ '^0*\d{1,2}[a-z]?$'
    order by p.prop_id
  )
  insert into ref.display (
      lor_prop_id,
      display_name,
      inventory_type,
      display_status_id,
      stage_id
  )
  select
      lor_prop_id,
      display_name,
      inventory_type,
      display_status_id,
      stage_id
  from src
  on conflict (lor_prop_id)
  do update set
      display_name      = excluded.display_name,
      inventory_type    = excluded.inventory_type,
      display_status_id = excluded.display_status_id,
      stage_id          = excluded.stage_id;

end;
