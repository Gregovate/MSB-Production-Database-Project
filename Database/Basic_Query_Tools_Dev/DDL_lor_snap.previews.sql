CREATE TABLE IF NOT EXISTS lor_snap.previews (
  import_run_id   BIGINT NOT NULL REFERENCES lor_snap.import_run(import_run_id) ON DELETE CASCADE,

  int_preview_id  BIGINT NOT NULL,
  id              TEXT   NOT NULL,
  stage_id        TEXT,
  name            TEXT,
  revision        TEXT,
  brightness      DOUBLE PRECISION,
  background_file TEXT,

  PRIMARY KEY (import_run_id, int_preview_id),
  UNIQUE (import_run_id, id)
);