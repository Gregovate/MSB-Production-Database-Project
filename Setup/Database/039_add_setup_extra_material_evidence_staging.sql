/* MSB Setup #167 — queryable source-document evidence index.
   REVIEW BEFORE PRODUCTION.

   This is deliberately broader than accepted task/Container assignments. It
   makes normalized findings queryable while final ownership remains unresolved.
*/
BEGIN;
DROP TABLE IF EXISTS ref.setup_extra_material_evidence;
DROP TABLE IF EXISTS ref.setup_extra_material_evidence_source;
CREATE TABLE ref.setup_extra_material_evidence_source (
    setup_extra_material_evidence_source_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    source_batch text NOT NULL,
    stage_key text,
    source_file text NOT NULL,
    source_pages integer[],
    material_families text[],
    material_keys text[],
    family_page_index text,
    legacy_container_refs text[],
    current_id_refs text[],
    noncurrent_or_legacy_refs text[],
    proposed_current_source_container_ids integer[],
    current_stage_kit_candidate_ids integer[],
    suggested_setup_task_ids bigint[],
    source_mapping_statuses text[],
    task_mapping_statuses text[],
    requirement_preload_states text[],
    catalog_dispositions text[],
    catalog_statuses text[],
    verification_needed boolean NOT NULL DEFAULT false,
    usage_restrictions text[],
    loaded_at timestamptz NOT NULL DEFAULT now(),
    loaded_by text NOT NULL DEFAULT current_user,
    CONSTRAINT uq_setup_extra_material_evidence_source UNIQUE (source_batch, source_file)
);
CREATE INDEX ix_setup_extra_material_evidence_source_stage ON ref.setup_extra_material_evidence_source(stage_key, source_file);
CREATE INDEX ix_setup_extra_material_evidence_source_families ON ref.setup_extra_material_evidence_source USING gin(material_families);
CREATE INDEX ix_setup_extra_material_evidence_source_proposed_containers ON ref.setup_extra_material_evidence_source USING gin(proposed_current_source_container_ids);
CREATE INDEX ix_setup_extra_material_evidence_source_stage_kits ON ref.setup_extra_material_evidence_source USING gin(current_stage_kit_candidate_ids);
CREATE INDEX ix_setup_extra_material_evidence_source_tasks ON ref.setup_extra_material_evidence_source USING gin(suggested_setup_task_ids);
GRANT SELECT ON ref.setup_extra_material_evidence_source TO fieldwiring_app;
REVOKE INSERT, UPDATE, DELETE ON ref.setup_extra_material_evidence_source FROM fieldwiring_app;
COMMENT ON TABLE ref.setup_extra_material_evidence_source IS 'Issue #167 source-document evidence index from normalized procedure/spreadsheet findings. Queryable before final task/container assignments; not accepted operational truth.';
COMMIT;
