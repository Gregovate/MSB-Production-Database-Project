-- ============================================================
-- ref.work_area — NON-stage operational areas only
-- Examples: Office, Command Center, Wood Shop, Food Bank Facility, Volunteer Trailer
-- ============================================================

create table if not exists ref.work_area (
  work_area_id   bigserial primary key,
  work_area_key  text not null,                 -- stable key: OFFICE, CC, WOOD_SHOP, FOOD_BANK, VOL_TRAILER
  work_area_name text not null,                 -- display name
  active_flag    boolean not null default true,
  sort_order     integer not null default 100,  -- let you pin common ones higher/lower in UI
  notes          text null,

  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);

create unique index if not exists ux_work_area_key
on ref.work_area (upper(btrim(work_area_key)));

-- Lightweight "touch" trigger can be added later; for now keep it simple.