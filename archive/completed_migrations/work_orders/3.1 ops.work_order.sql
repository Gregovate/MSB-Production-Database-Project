-- Step 3.1a — ops.work_order (no display FK yet)

create table if not exists ops.work_order (
  work_order_id  bigserial primary key,

  -- Location (Option 1 XOR)
  stage_id       bigint null,   -- FK → ref.stage(stage_id)
  work_area_id   bigint null,   -- FK → ref.work_area(work_area_id)

  -- Classification
  task_type_id   bigint not null, -- FK → ref.task_type(task_type_id)

  -- Asset link (optional; FK added later when display table is confirmed)
  display_id     bigint null,

  -- Scheduling / planning
  urgency        integer null,    -- 1..4, NULL = not triaged
  target_year    integer null,    -- e.g., 2026
  legacy_priority_raw text null,

  -- Content
  problem        text not null,
  notes          text null,
  photo_url      text null,

  -- Completion (no done_flag)
  date_completed          timestamptz null,
  completed_by_person_id  bigint null,  -- FK → ref.person(person_id)
  completion_notes        text null,

  -- Audit
  created_at              timestamptz not null default now(),
  created_by_person_id    bigint not null, -- FK → ref.person(person_id)
  updated_at              timestamptz not null default now(),
  updated_by_person_id    bigint not null  -- FK → ref.person(person_id)
);

-- Foreign keys (safe ones)
alter table ops.work_order
  add constraint fk_work_order_stage
  foreign key (stage_id) references ref.stage(stage_id);

alter table ops.work_order
  add constraint fk_work_order_work_area
  foreign key (work_area_id) references ref.work_area(work_area_id);

alter table ops.work_order
  add constraint fk_work_order_task_type
  foreign key (task_type_id) references ref.task_type(task_type_id);

alter table ops.work_order
  add constraint fk_work_order_completed_by
  foreign key (completed_by_person_id) references ref.person(person_id);

alter table ops.work_order
  add constraint fk_work_order_created_by
  foreign key (created_by_person_id) references ref.person(person_id);

alter table ops.work_order
  add constraint fk_work_order_updated_by
  foreign key (updated_by_person_id) references ref.person(person_id);

-- Constraints
alter table ops.work_order
  add constraint ck_work_order_location_xor
  check (
    (stage_id is not null and work_area_id is null)
    or
    (stage_id is null and work_area_id is not null)
  );

alter table ops.work_order
  add constraint ck_work_order_urgency_range
  check (urgency is null or urgency between 1 and 4);

alter table ops.work_order
  add constraint ck_work_order_target_year_reasonable
  check (target_year is null or target_year between 2000 and 2100);

alter table ops.work_order
  add constraint ck_work_order_completion_required
  check (
    date_completed is null
    or (
      completed_by_person_id is not null
      and completion_notes is not null
      and btrim(completion_notes) <> ''
    )
  );

-- Indexes
create index if not exists ix_work_order_open
on ops.work_order (date_completed) where date_completed is null;

create index if not exists ix_work_order_stage_open
on ops.work_order (stage_id) where date_completed is null;

create index if not exists ix_work_order_work_area_open
on ops.work_order (work_area_id) where date_completed is null;

create index if not exists ix_work_order_target_year
on ops.work_order (target_year);

create index if not exists ix_work_order_urgency_open
on ops.work_order (urgency) where date_completed is null;

create index if not exists ix_work_order_display
on ops.work_order (display_id);