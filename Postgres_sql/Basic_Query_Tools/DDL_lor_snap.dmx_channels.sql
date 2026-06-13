CREATE TABLE IF NOT EXISTS lor_snap.dmx_channels (
  import_run_id      BIGINT NOT NULL REFERENCES lor_snap.import_run(import_run_id) ON DELETE CASCADE,

  int_dmx_channel_id BIGINT NOT NULL,
  prop_id            TEXT,
  network            TEXT,
  start_universe     INTEGER,
  start_channel      INTEGER,
  end_channel        INTEGER,
  unknown            TEXT,
  preview_id         TEXT,

  PRIMARY KEY (import_run_id, int_dmx_channel_id),

  FOREIGN KEY (import_run_id, prop_id)
    REFERENCES lor_snap.props(import_run_id, prop_id)
    ON DELETE RESTRICT,

  FOREIGN KEY (import_run_id, preview_id)
    REFERENCES lor_snap.previews(import_run_id, id)
    ON DELETE RESTRICT
);