/* MSB Setup #167 — queryable normalized procedure/spreadsheet evidence staging.
   REVIEW BEFORE PRODUCTION.

   Evidence only: this table intentionally preserves unresolved task/container
   mappings so operators can query findings before assignments are complete.
   Operational requirement/source/container tables remain separate.
*/
BEGIN;

CREATE TABLE IF NOT EXISTS ref.setup_extra_material_evidence (
    setup_extra_material_evidence_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    source_batch text NOT NULL,
    source_row_number integer NOT NULL,
    material_key text,
    stage_key text,
    source_file text,
    source_page integer,
    evidence_status text,
    evidence_text text,
    canonical_family text,
    canonical_variant text,
    catalog_status text,
    lifecycle_class text,
    legacy_container_refs text,
    current_id_refs text,
    noncurrent_or_legacy_refs text,
    evidence_source_claim text,
    proposed_current_source_container_ids integer[],
    source_mapping_status text,
    source_mapping_basis text,
    current_stage_kit_candidate_ids integer[],
    suggested_setup_task_ids bigint[],
    suggested_task_names text,
    task_mapping_status text,
    task_mapping_basis text,
    requirement_preload_state text,
    catalog_disposition text,
    verification_needed boolean,
    usage_restriction text,
    loaded_at timestamptz NOT NULL DEFAULT now(),
    loaded_by text NOT NULL DEFAULT current_user,
    CONSTRAINT uq_setup_extra_material_evidence_source_row UNIQUE (source_batch, source_row_number)
);
CREATE INDEX IF NOT EXISTS ix_setup_extra_material_evidence_stage ON ref.setup_extra_material_evidence(stage_key, source_file, source_page);
CREATE INDEX IF NOT EXISTS ix_setup_extra_material_evidence_family ON ref.setup_extra_material_evidence(canonical_family, catalog_status);
CREATE INDEX IF NOT EXISTS ix_setup_extra_material_evidence_source_status ON ref.setup_extra_material_evidence(source_mapping_status, task_mapping_status, requirement_preload_state);
CREATE INDEX IF NOT EXISTS ix_setup_extra_material_evidence_source_containers ON ref.setup_extra_material_evidence USING gin(proposed_current_source_container_ids);
CREATE INDEX IF NOT EXISTS ix_setup_extra_material_evidence_stage_kits ON ref.setup_extra_material_evidence USING gin(current_stage_kit_candidate_ids);
CREATE INDEX IF NOT EXISTS ix_setup_extra_material_evidence_tasks ON ref.setup_extra_material_evidence USING gin(suggested_setup_task_ids);
GRANT SELECT ON ref.setup_extra_material_evidence TO fieldwiring_app;
REVOKE INSERT, UPDATE, DELETE ON ref.setup_extra_material_evidence FROM fieldwiring_app;
COMMENT ON TABLE ref.setup_extra_material_evidence IS 'Issue #167 procedure/spreadsheet evidence staging. Queryable before final task/container assignments; evidence only, not accepted operational truth.';
COMMIT;
