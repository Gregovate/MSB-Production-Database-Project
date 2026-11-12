CREATE TABLE IF NOT EXISTS lor_snap.sub_props (
  import_run_id       BIGINT NOT NULL REFERENCES lor_snap.import_run(import_run_id) ON DELETE CASCADE,

  int_sub_prop_id     BIGINT NOT NULL,
  sub_prop_id         TEXT   NOT NULL,
  name                TEXT,
  lor_comment         TEXT,
  device_type         TEXT,
  bulb_shape          TEXT,

  network             TEXT,
  uid                 TEXT,
  start_channel       INTEGER,
  end_channel         INTEGER,
  unknown             TEXT,
  color               TEXT,

  custom_bulb_color   TEXT,
  dimming_curve_name  TEXT,
  individual_channels BOOLEAN,
  legacy_sequence_method TEXT,
  max_channels        INTEGER,
  opacity             DOUBLE PRECISION,
  master_dimmable     BOOLEAN,
  preview_bulb_size   DOUBLE PRECISION,
  rgb_order           TEXT,
  master_prop_id      TEXT,
  separate_ids        BOOLEAN,
  start_location      TEXT,
  string_type         TEXT,
  traditional_colors  TEXT,
  traditional_type    TEXT,
  effect_bulb_size    DOUBLE PRECISION,
  tag                 TEXT,
  parm1               TEXT,
  parm2               TEXT,
  parm3               TEXT,
  parm4               TEXT,
  parm5               TEXT,
  parm6               TEXT,
  parm7               TEXT,
  parm8               TEXT,
  lights              INTEGER,

  preview_id          TEXT,

  PRIMARY KEY (import_run_id, int_sub_prop_id),
  UNIQUE (import_run_id, sub_prop_id),

  FOREIGN KEY (import_run_id, master_prop_id)
    REFERENCES lor_snap.props(import_run_id, prop_id)
    ON DELETE RESTRICT,

  FOREIGN KEY (import_run_id, preview_id)
    REFERENCES lor_snap.previews(import_run_id, id)
    ON DELETE RESTRICT
);