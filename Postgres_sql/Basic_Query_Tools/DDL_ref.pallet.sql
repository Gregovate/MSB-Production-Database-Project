create table if not exists ref.pallet (
    pallet_id        integer primary key,  -- spreadsheet PalletID

    rack_code        text not null unique, -- printed location label (RB-07-C etc.)

    pallet_type_id   integer not null
        references ref.pallet_type(pallet_type_id),

    pallet_size      text null,
    stackable        boolean null,
    year_built       integer null,

    notes            text null,

    created_at       timestamptz not null default now(),
    created_by       text        not null default current_user,
    updated_at       timestamptz not null default now(),
    updated_by       text        not null default current_user
);

drop trigger if exists trg_touch_pallet on ref.pallet;

create trigger trg_touch_pallet
before update on ref.pallet
for each row
execute function ref.tg_touch_row();