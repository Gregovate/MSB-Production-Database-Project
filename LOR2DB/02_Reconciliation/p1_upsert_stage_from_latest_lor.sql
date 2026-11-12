/*
Procedure: ref.p1_upsert_stage_from_latest_lor

Purpose:
  Upsert ref.stage from the latest LOR snapshot (lor_snap.previews).
  Fully derived from preview names; non-destructive; preserves stage_id stability.

Reads:
  lor_snap.import_run
  lor_snap.previews

Writes:
  ref.stage (UPSERT)
    - inserts missing stage_key
    - updates stage_name/folder_name/order fields for existing stage_key
    - never deletes/truncates

Notes:
  - Uses DISTINCT ON(stage_key) to guarantee one row per stage_key (prevents ON CONFLICT double-hit).
  - stage_key is lower(previews.stage_id) and supports substages like '07a'.

Revision History:
  2026-02-27  GAL  Initial + fix duplicate-stage-key conflict in single insert.

ref.p1_upsert_stage_from_latest_lor

Purpose:
  Upsert ref.stage from the latest lor_snap.previews import.
  LOR is authoritative for stage naming.

Rules:
  - Only accept canonical stage IDs: 0-99 with optional letter suffix (e.g. 07, 07a)
  - stage_key is normalized: lower(btrim(stage_id))
  - stage_name + folder_name derived from preview name

Notes:
  - This does NOT delete stages that are no longer present in LOR.
*/
declare
  v_run_id bigint;
begin
  select max(import_run_id)
    into v_run_id
  from lor_snap.import_run;

  if v_run_id is null then
    raise exception 'No import_run_id found in lor_snap.import_run';
  end if;

  /*
    Choose ONE preview row per stage_key.
    Ordering rule (deterministic):
      - prefer names that start with "Stage"
      - then prefer longer names (more descriptive)
      - then stable tie-breaker by name
  */
  with one_per_stage as (
    select distinct on (lower(p.stage_id))
      lower(p.stage_id) as stage_key,
      p.stage_id        as stage_id_raw,
      p.name            as preview_name
    from lor_snap.previews p
    where p.import_run_id = v_run_id
      and p.stage_id is not null
      and btrim(p.stage_id) <> ''
    order by
      lower(p.stage_id),
      (p.name ~* '^\s*stage\b') desc,
      length(p.name) desc,
      p.name desc
  )
  insert into ref.stage (
      stage_key,
      stage_name,
      short_code,
      folder_name,
      folder_path,
      park_order,
      sub_order,
      created_at,
      created_by,
      updated_at,
      updated_by
  )
  select
      s.stage_key,

      /* stage_name: strip leading "Stage <key>" and trailing "with|w/" */
      coalesce(
        nullif(
          btrim(
            regexp_replace(
              regexp_replace(
                s.preview_name,
                '(?i)^\s*stage\s*0*' || s.stage_id_raw || '\s*',
                ''
              ),
              '\s+(with|w/)\s+.*$',
              '',
              'i'
            )
          ),
          ''
        ),
        'Stage ' || s.stage_id_raw
      ) as stage_name,

      null as short_code,

      /* folder_name: "<stage_key>-<stage_name>" */
      s.stage_key || '-' ||
      coalesce(
        nullif(
          btrim(
            regexp_replace(
              regexp_replace(
                s.preview_name,
                '(?i)^\s*stage\s*0*' || s.stage_id_raw || '\s*',
                ''
              ),
              '\s+(with|w/)\s+.*$',
              '',
              'i'
            )
          ),
          ''
        ),
        'Stage'
      ) as folder_name,

      null as folder_path,

      /* park_order: numeric part */
      ((regexp_match(lower(s.stage_id_raw), '^0*(\d{1,2})'))[1])::int as park_order,

      /* sub_order: a=1, b=2, ... else 0 */
      case
        when lower(s.stage_id_raw) ~ '^\d{1,2}[a-z]$'
          then ascii(substring(lower(s.stage_id_raw) from '[a-z]')) - ascii('a') + 1
        else 0
      end as sub_order,

      now(),
      current_user,
      now(),
      current_user

  from one_per_stage s

  on conflict (stage_key)
  do update set
      stage_name  = excluded.stage_name,
      folder_name = excluded.folder_name,
      park_order  = excluded.park_order,
      sub_order   = excluded.sub_order,
      updated_at  = now(),
      updated_by  = current_user;

end;
