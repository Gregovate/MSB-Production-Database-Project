-- ============================================================
-- ref.task_type — Repair / Build / Setup / Design / Testing / etc.
-- ============================================================

create table if not exists ref.task_type (
  task_type_id   bigserial primary key,
  task_type_key  text not null,                 -- stable key: REPAIR, BUILD, SETUP, DESIGN...
  task_type_name text not null,
  active_flag    boolean not null default true,
  sort_order     integer not null default 100,
  notes          text null,

  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);

create unique index if not exists ux_task_type_key
on ref.task_type (upper(btrim(task_type_key)));