/* MSB Setup #167 — queryable procedure/spreadsheet evidence index.
   REVIEW BEFORE PRODUCTION.

   Evidence only: this table intentionally preserves unresolved task/container
   mappings so operators can query findings before assignments are complete.
   Operational requirement/source/container tables remain separate.
*/
BEGIN;
DROP TABLE IF EXISTS ref.setup_extra_material_evidence;
CREATE TABLE ref.setup_extra_material_evidence (
    setup_extra_material_evidence_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    source_batch text NOT NULL,
    evidence_group_key text NOT NULL,
    stage_key text,
    source_file text NOT NULL,
    canonical_family text,
    canonical_variants text[],
    source_pages integer[],
    evidence_text text,
    material_keys text[],
    legacy_container_refs text,
    current_id_refs text,
    noncurrent_or_legacy_refs text,
    evidence_source_claims text[],
    proposed_current_source_container_ids integer[],
    current_stage_kit_candidate_ids integer[],
    suggested_setup_task_ids bigint[],
    source_mapping_statuses text[],
    source_mapping_basis text,
    task_mapping_statuses text[],
    task_mapping_basis text,
    requirement_preload_states text[],
    catalog_dispositions text[],
    catalog_statuses text[],
    lifecycle_classes text[],
    verification_needed boolean NOT NULL DEFAULT false,
    usage_restrictions text[],
    loaded_at timestamptz NOT NULL DEFAULT now(),
    loaded_by text NOT NULL DEFAULT current_user,
    CONSTRAINT uq_setup_extra_material_evidence_group UNIQUE (source_batch, evidence_group_key)
);
CREATE INDEX ix_setup_extra_material_evidence_stage ON ref.setup_extra_material_evidence(stage_key, source_file);
CREATE INDEX ix_setup_extra_material_evidence_family ON ref.setup_extra_material_evidence(canonical_family);
CREATE INDEX ix_setup_extra_material_evidence_source_containers ON ref.setup_extra_material_evidence USING gin(proposed_current_source_container_ids);
CREATE INDEX ix_setup_extra_material_evidence_stage_kits ON ref.setup_extra_material_evidence USING gin(current_stage_kit_candidate_ids);
CREATE INDEX ix_setup_extra_material_evidence_tasks ON ref.setup_extra_material_evidence USING gin(suggested_setup_task_ids);
CREATE INDEX ix_setup_extra_material_evidence_source_status ON ref.setup_extra_material_evidence USING gin(source_mapping_statuses);
CREATE INDEX ix_setup_extra_material_evidence_task_status ON ref.setup_extra_material_evidence USING gin(task_mapping_statuses);
GRANT SELECT ON ref.setup_extra_material_evidence TO fieldwiring_app;
REVOKE INSERT, UPDATE, DELETE ON ref.setup_extra_material_evidence FROM fieldwiring_app;
COMMENT ON TABLE ref.setup_extra_material_evidence IS 'Issue #167 queryable evidence index from normalized procedures/spreadsheets. One row per Stage + source document + canonical family. Evidence may be unresolved and is not accepted operational truth.';
COMMIT;
