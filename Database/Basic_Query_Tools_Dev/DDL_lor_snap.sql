CREATE SCHEMA IF NOT EXISTS lor_snap;

CREATE TABLE IF NOT EXISTS lor_snap.import_run (
  import_run_id  BIGSERIAL PRIMARY KEY,
  run_ts         TIMESTAMPTZ NOT NULL DEFAULT now(),
  notes          TEXT
);

-- quick sanity check
INSERT INTO lor_snap.import_run (notes) VALUES ('schema smoke test');
SELECT * FROM lor_snap.import_run ORDER BY import_run_id DESC LIMIT 5;