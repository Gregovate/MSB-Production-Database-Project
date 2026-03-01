-- ============================================================
-- ops.work_order_assignee — 0..N assignees per work order
-- ============================================================

-- Step 3.2 — ops.work_order_assignee

create table if not exists ops.work_order_assignee (
  work_order_id         bigint not null,
  person_id             bigint not null,
  assigned_at           timestamptz not null default now(),
  assigned_by_person_id bigint null,  -- nullable for imports / system assigns later

  primary key (work_order_id, person_id),

  constraint fk_woa_work_order foreign key (work_order_id)
    references ops.work_order(work_order_id) on delete cascade,

  constraint fk_woa_person foreign key (person_id)
    references ref.person(person_id),

  constraint fk_woa_assigned_by foreign key (assigned_by_person_id)
    references ref.person(person_id)
);

create index if not exists ix_woa_person
on ops.work_order_assignee (person_id);