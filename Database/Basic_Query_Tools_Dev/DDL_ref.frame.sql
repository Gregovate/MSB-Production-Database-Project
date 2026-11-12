-- ============================================================
-- ref.frame
-- - frame_code is the canonical human key (matches spreadsheet dropdown)
-- - w_ft/h_ft are only populated for standard frames
-- - Custom/None have NULL dimensions
-- - Tracks who/when (no history table yet)
-- ============================================================

create table if not exists ref.frame (
    frame_id     integer generated always as identity primary key,

    frame_code   text not null,          -- e.g. '4 x 8', 'Custom', 'None'
    w_ft         integer null,
    h_ft         integer null,

    created_at   timestamptz not null default now(),
    created_by   text        not null default current_user,
    updated_at   timestamptz not null default now(),
    updated_by   text        not null default current_user,

    constraint uq_frame_code unique (frame_code),

    -- prevent duplicate standard sizes (allows multiple NULL/NULL rows, but we disallow via check below)
    constraint uq_frame_size unique (w_ft, h_ft)
);

-- Dimension rules:
-- - If frame_code is a standard size like '4 x 8' then w_ft and h_ft must be present
-- - If frame_code is 'Custom' or 'None' then w_ft and h_ft must be NULL
alter table ref.frame
add constraint chk_frame_dimensions
check (
    (
        frame_code in ('Custom', 'None')
        and w_ft is null and h_ft is null
    )
    or
    (
        frame_code not in ('Custom', 'None')
        and w_ft is not null and h_ft is not null
    )
);

-- Auto-maintain updated_* on UPDATE
create or replace function ref.set_updated_fields()
returns trigger as $$
begin
    new.updated_at := now();
    new.updated_by := current_user;
    return new;
end;
$$ language plpgsql;

drop trigger if exists trg_frame_set_updated on ref.frame;

create trigger trg_frame_set_updated
before update on ref.frame
for each row
execute function ref.set_updated_fields();