CREATE TABLE IF NOT EXISTS lor_snap.dmx_channels (
  import_run_id           BIGINT NOT NULL REFERENCES lor_snap.import_run(import_run_id) ON DELETE CASCADE,

  int_dmx_channel_id      BIGINT NOT NULL,
  prop_id                 TEXT,
  network                 TEXT,
  start_universe          INTEGER,
  start_channel           INTEGER,
  end_channel             INTEGER,
  unknown                 TEXT,
  preview_id              TEXT,
  raw_prop_id             TEXT,
  channel_name            TEXT,
  channel_grid_row_number INTEGER,

  PRIMARY KEY (import_run_id, int_dmx_channel_id),

  FOREIGN KEY (import_run_id, prop_id)
    REFERENCES lor_snap.props(import_run_id, prop_id)
    ON DELETE RESTRICT,

  FOREIGN KEY (import_run_id, preview_id)
    REFERENCES lor_snap.previews(import_run_id, id)
    ON DELETE RESTRICT
);

COMMENT ON COLUMN lor_snap.dmx_channels.raw_prop_id IS
'Originating raw LOR PropClass.id for this DMX Channel Grid Row. Source wiring provenance only; not permanent Display or controller identity and intentionally not foreign-keyed to lor_snap.props.';

COMMENT ON COLUMN lor_snap.dmx_channels.channel_name IS
'Originating LOR PropClass.Name (Channel Name) that supplied this DMX Channel Grid Row.';

COMMENT ON COLUMN lor_snap.dmx_channels.channel_grid_row_number IS
'1-based serialized Channel Grid Row Number local to the originating PropClass. Restarts for each source PropClass; gaps may exist when a nonblank serialized row is invalid and therefore not materialized.';
