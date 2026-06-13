create table if not exists ref.location (
    -- atomic parts (authoritative)
    type_code      text    not null,          -- e.g. 'R'
    rack_code      text    not null,          -- e.g. 'A','B','C' or 'RA','RB' depending on your sheet
    column_num     integer not null,
    shelf_code     text    not null,          -- A..E
    slot_bin_num   integer null,              -- optional

    -- derived label (for printing / human use)
    location_code  text generated always as (
        type_code || rack_code || lpad(column_num::text, 2, '0') || '-' || shelf_code ||
        case when slot_bin_num is null then '' else '-' || lpad(slot_bin_num::text, 2, '0') end
    ) stored,

    description    text null,
    notes          text null,

    created_at     timestamptz not null default now(),
    created_by     text        not null default current_user,
    updated_at     timestamptz not null default now(),
    updated_by     text        not null default current_user,

    constraint pk_location primary key (location_code),
    constraint uq_location_parts unique (type_code, rack_code, column_num, shelf_code, slot_bin_num)
);

drop trigger if exists trg_touch_location on ref.location;
create trigger trg_touch_location
before update on ref.location
for each row
execute function ref.tg_touch_row();