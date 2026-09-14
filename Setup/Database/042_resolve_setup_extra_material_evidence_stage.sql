/* MSB Setup #167 — resolve procedure evidence to authoritative ref.stage identity.
   Every staged procedure already belongs to a known Stage; only task/step mapping
   may remain unresolved. */
BEGIN;

ALTER TABLE ref.setup_extra_material_evidence_source
    ADD COLUMN IF NOT EXISTS stage_id integer REFERENCES ref.stage(stage_id);

UPDATE ref.setup_extra_material_evidence_source e
SET stage_id = s.stage_id
FROM ref.stage s
WHERE e.stage_id IS NULL
  AND s.stage_key = e.stage_key;

DO $proof$
DECLARE
    v_missing integer;
BEGIN
    SELECT count(*) INTO v_missing
    FROM ref.setup_extra_material_evidence_source
    WHERE source_batch='MSB_Setup_Extra_Materials_Normalization_Staging_2026-09-13_v6.xlsx'
      AND stage_id IS NULL;
    IF v_missing <> 0 THEN
        RAISE EXCEPTION 'Procedure evidence has % row(s) without resolved ref.stage identity', v_missing;
    END IF;
END
$proof$;

ALTER TABLE ref.setup_extra_material_evidence_source
    ALTER COLUMN stage_key SET NOT NULL;

CREATE INDEX IF NOT EXISTS ix_setup_extra_material_evidence_source_stage_id
ON ref.setup_extra_material_evidence_source(stage_id, source_file);

COMMENT ON COLUMN ref.setup_extra_material_evidence_source.stage_id IS
'Authoritative Stage identity derived from the procedure/folder source context. Task/step mapping may remain unresolved.';

COMMIT;

SELECT count(*) AS resolved_procedure_stage_rows
FROM ref.setup_extra_material_evidence_source
WHERE source_batch='MSB_Setup_Extra_Materials_Normalization_Staging_2026-09-13_v6.xlsx'
  AND stage_id IS NOT NULL;
