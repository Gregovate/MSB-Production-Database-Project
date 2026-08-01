/*
Object: ref.lor_scene, ref.lor_scene_display
Type: Production current-state table DDL
Owner: msbadmin

Purpose:
  Create the production projection for current LOR scenes and current
  scene-to-display assignments.

Rules:
  - Production stores current state only; snapshot history remains in lor_snap.
  - A preview can contain multiple scenes.
  - A display can belong to only one scene within a preview.
  - Deleting a production scene deletes its current assignments.
  - Display identity remains ref.display.display_id.

Revision History:
  2026-07-31  GAL / OpenAI  Initial V7 scene-production DDL draft.
*/

BEGIN;

CREATE TABLE ref.lor_scene (
    lor_scene_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    preview_uuid text NOT NULL,
    scene_uuid text NOT NULL,
    stage_id integer NOT NULL,
    scene_name text NOT NULL,
    scene_section text,
    background_file text,
    h_scroll integer,
    v_scroll integer,
    zoom integer,
    create_grid_view text,
    source_import_run_id bigint NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT CURRENT_USER NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_by text DEFAULT CURRENT_USER NOT NULL,

    CONSTRAINT uq_lor_scene_preview_scene
        UNIQUE (preview_uuid, scene_uuid),
    CONSTRAINT uq_lor_scene_id_preview
        UNIQUE (lor_scene_id, preview_uuid),
    CONSTRAINT fk_lor_scene_stage
        FOREIGN KEY (stage_id)
        REFERENCES ref.stage (stage_id),
    CONSTRAINT fk_lor_scene_import_run
        FOREIGN KEY (source_import_run_id)
        REFERENCES lor_snap.import_run (import_run_id)
);

COMMENT ON TABLE ref.lor_scene IS
    'Current production LOR scenes. Historical definitions remain in lor_snap.scenes.';

COMMENT ON COLUMN ref.lor_scene.preview_uuid IS
    'LOR preview identity. Combined with scene_uuid to identify a scene.';

COMMENT ON COLUMN ref.lor_scene.scene_uuid IS
    'LOR scene identity scoped to preview_uuid; not assumed globally unique.';

CREATE TABLE ref.lor_scene_display (
    lor_scene_id bigint NOT NULL,
    preview_uuid text NOT NULL,
    display_id bigint NOT NULL,
    scene_prop_ordinal integer,
    scene_role text,
    source text,
    source_import_run_id bigint NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT CURRENT_USER NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_by text DEFAULT CURRENT_USER NOT NULL,

    CONSTRAINT pk_lor_scene_display
        PRIMARY KEY (lor_scene_id, display_id),
    CONSTRAINT uq_lor_scene_display_preview_display
        UNIQUE (preview_uuid, display_id),
    CONSTRAINT fk_lor_scene_display_scene
        FOREIGN KEY (lor_scene_id, preview_uuid)
        REFERENCES ref.lor_scene (lor_scene_id, preview_uuid)
        ON DELETE CASCADE,
    CONSTRAINT fk_lor_scene_display_display
        FOREIGN KEY (display_id)
        REFERENCES ref.display (display_id),
    CONSTRAINT fk_lor_scene_display_import_run
        FOREIGN KEY (source_import_run_id)
        REFERENCES lor_snap.import_run (import_run_id)
);

COMMENT ON TABLE ref.lor_scene_display IS
    'Current scene assignment for permanent displays; one scene per display within a preview.';

COMMENT ON COLUMN ref.lor_scene_display.preview_uuid IS
    'Duplicated parent preview identity used to enforce one current scene per display per preview.';

CREATE INDEX ix_lor_scene_stage
    ON ref.lor_scene (stage_id);

CREATE INDEX ix_lor_scene_source_run
    ON ref.lor_scene (source_import_run_id);

CREATE INDEX ix_lor_scene_display_display
    ON ref.lor_scene_display (display_id);

CREATE INDEX ix_lor_scene_display_source_run
    ON ref.lor_scene_display (source_import_run_id);

COMMIT;

