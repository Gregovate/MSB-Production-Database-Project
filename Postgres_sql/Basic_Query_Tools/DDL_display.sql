drop table if exists ref.display cascade;

create table ref.display (
  lor_prop_id       text primary key,
  display_name      text not null,

  inventory_type    text not null,        -- FK later
  display_status_id integer not null,     -- FK later

  designer_id       integer null,         -- FK later
  theme_id          integer null,         -- FK later
  frame_id          integer null,         -- FK later
  pallet_id         integer null,         -- FK later

  year_built        integer null,
  amps_measured     numeric(8,2) null,

  est_light_count   integer null,
  dumb_controller   text null,

  notes             text null,

  created_at        timestamptz not null default now(),
  created_by        text not null default current_user,
  updated_at        timestamptz not null default now(),
  updated_by        text not null default current_user
);