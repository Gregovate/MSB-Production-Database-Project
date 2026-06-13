-- Convenience slice: field-only rows
CREATE OR REPLACE VIEW lor_snap.preview_wiring_fieldonly_v6 AS
SELECT *
FROM lor_snap.preview_wiring_fieldmap_v6
WHERE connection_type = 'FIELD';