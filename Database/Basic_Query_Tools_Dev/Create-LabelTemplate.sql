/* ======================================================================
   Create ref.label_template

   Status: REVIEWED CANDIDATE — NOT YET APPLIED TO PRODUCTION
   Subsystem: Labeling and Scanning
   Schema basis:
     Database/Schema_Snapshots/msb_production_schema-2026-08-08.sql

   Purpose:
     Define the governed physical label format selected by Production
     Database records/workflows without storing the PRINT-SERVER installation
     root or Windows printer queue on each source asset.

   Key model:
     label_template_id is the integer generated primary key used by foreign
     keys from Display, Controller, and other governed assets.

     label_template_code is a separate UNIQUE stable integration code used to
     describe the semantic template meaning, for example:
       DISPLAY_36MM_HORIZONTAL
       CONTAINER_36MM_VERTICAL

   Runtime path contract:
     config.local.ini on PRINT-SERVER owns the machine-local template root:
       C:\MSB_LabelService\templates

     ref.label_template.template_relative_path stores only the path below
     that root, using forward slashes, for example:
       pt_p950nw/QR_display_labels_2_line_24mm.lbx

   IMPORTANT:
     - This creates a NEW production reference table only.
     - It does NOT alter ref.display, ref.container, or ref.controller.
     - Controller templates are intentionally not seeded until the physical
       Controller label size/orientation is decided and accepted.
     - Printer queue names and the C:\MSB_LabelService root do not belong in
       this table.
   ====================================================================== */

BEGIN;

DO $$
BEGIN
    IF to_regnamespace('ref') IS NULL THEN
        RAISE EXCEPTION 'Required schema ref does not exist';
    END IF;

    IF to_regclass('ref.person') IS NULL THEN
        RAISE EXCEPTION 'Required table ref.person does not exist';
    END IF;

    IF to_regprocedure('ref.set_actor_on_insert()') IS NULL THEN
        RAISE EXCEPTION 'Required trigger function ref.set_actor_on_insert() does not exist';
    END IF;

    IF to_regprocedure('ref.set_actor_on_update()') IS NULL THEN
        RAISE EXCEPTION 'Required trigger function ref.set_actor_on_update() does not exist';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'msbadmin') THEN
        RAISE EXCEPTION 'Required owner role msbadmin does not exist';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'directus_app') THEN
        RAISE EXCEPTION 'Required application role directus_app does not exist';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'printservice') THEN
        RAISE EXCEPTION 'Required service role printservice does not exist';
    END IF;

    IF to_regclass('ref.label_template') IS NOT NULL THEN
        RAISE EXCEPTION 'ref.label_template already exists; stop and inspect the existing object before proceeding';
    END IF;
END
$$;

CREATE TABLE ref.label_template (
    label_template_id integer GENERATED ALWAYS AS IDENTITY NOT NULL,
    label_template_code text NOT NULL,
    label_template_name text NOT NULL,
    label_class text NOT NULL,
    media_width_mm smallint NOT NULL,
    label_orientation text NOT NULL,
    media_type text NOT NULL,
    template_relative_path text NOT NULL,
    description text,
    active_flag boolean NOT NULL DEFAULT true,

    created_at timestamp with time zone NOT NULL DEFAULT now(),
    created_by text NOT NULL DEFAULT CURRENT_USER,
    created_by_person_id bigint,
    updated_at timestamp with time zone NOT NULL DEFAULT now(),
    updated_by text NOT NULL DEFAULT CURRENT_USER,
    updated_by_person_id bigint,

    CONSTRAINT label_template_pkey
        PRIMARY KEY (label_template_id),
    CONSTRAINT uq_label_template_code
        UNIQUE (label_template_code),
    CONSTRAINT uq_label_template_relative_path
        UNIQUE (template_relative_path),
    CONSTRAINT ck_label_template_code_not_blank
        CHECK (btrim(label_template_code) <> ''),
    CONSTRAINT ck_label_template_name_not_blank
        CHECK (btrim(label_template_name) <> ''),
    CONSTRAINT ck_label_template_class_not_blank
        CHECK (btrim(label_class) <> ''),
    CONSTRAINT ck_label_template_media_width_positive
        CHECK (media_width_mm > 0),
    CONSTRAINT ck_label_template_orientation
        CHECK (label_orientation = ANY (ARRAY['VERTICAL'::text, 'HORIZONTAL'::text])),
    CONSTRAINT ck_label_template_media_type_not_blank
        CHECK (btrim(media_type) <> ''),
    CONSTRAINT ck_label_template_relative_path_not_blank
        CHECK (btrim(template_relative_path) <> ''),
    CONSTRAINT ck_label_template_relative_path_not_windows_absolute
        CHECK (
            template_relative_path !~ '^[A-Za-z]:[\\/]'
            AND template_relative_path !~ '^[/\\]{2}'
        )
);

ALTER TABLE ref.label_template OWNER TO msbadmin;

COMMENT ON TABLE ref.label_template IS
'Governed physical label-template lookup shared by Display, Container, Controller, Location, Wiring, and future label classes. Foreign keys use the generated integer label_template_id. Machine-local PRINT-SERVER root paths and Windows printer queue names are not stored here.';

COMMENT ON COLUMN ref.label_template.label_template_id IS
'PostgreSQL-generated integer primary key used by asset foreign-key relationships.';

COMMENT ON COLUMN ref.label_template.label_template_code IS
'Stable unique integration code describing the semantic physical label format, for example DISPLAY_36MM_HORIZONTAL or CONTAINER_36MM_VERTICAL.';

COMMENT ON COLUMN ref.label_template.label_template_name IS
'Human-readable administrative name for the physical label format.';

COMMENT ON COLUMN ref.label_template.label_class IS
'Label purpose/class such as DISPLAY, CONTAINER, CONTROLLER, LOCATION, or WIRING.';

COMMENT ON COLUMN ref.label_template.media_width_mm IS
'Nominal required print-media width in millimeters.';

COMMENT ON COLUMN ref.label_template.label_orientation IS
'Physical label layout orientation: HORIZONTAL or VERTICAL.';

COMMENT ON COLUMN ref.label_template.media_type IS
'Governed media family/description code, for example LAMINATED_TAPE. Operators do not select printers from this table.';

COMMENT ON COLUMN ref.label_template.template_relative_path IS
'LBX implementation path relative to the LabelPrintService template_dir root. Store a relative path such as pt_p950nw/QR_container_vertical.lbx; do not store C:\MSB_LabelService or a UNC share.';

COMMENT ON COLUMN ref.label_template.active_flag IS
'False retires a template from new assignment without destroying historical meaning.';

ALTER TABLE ONLY ref.label_template
    ADD CONSTRAINT fk_label_template_created_by_person
    FOREIGN KEY (created_by_person_id)
    REFERENCES ref.person(person_id);

ALTER TABLE ONLY ref.label_template
    ADD CONSTRAINT fk_label_template_updated_by_person
    FOREIGN KEY (updated_by_person_id)
    REFERENCES ref.person(person_id);

CREATE TRIGGER trg_label_template_set_actor_insert
BEFORE INSERT ON ref.label_template
FOR EACH ROW
EXECUTE FUNCTION ref.set_actor_on_insert();

CREATE TRIGGER trg_label_template_set_actor_update
BEFORE UPDATE ON ref.label_template
FOR EACH ROW
EXECUTE FUNCTION ref.set_actor_on_update();

INSERT INTO ref.label_template (
    label_template_code,
    label_template_name,
    label_class,
    media_width_mm,
    label_orientation,
    media_type,
    template_relative_path,
    description
)
VALUES
(
    'DISPLAY_36MM_HORIZONTAL',
    'Display Label - 36 mm Horizontal',
    'DISPLAY',
    36,
    'HORIZONTAL',
    'LAMINATED_TAPE',
    'pt_p950nw/QR_display_labels_2_line_36mm.lbx',
    'Current standard Display identity label using 36 mm laminated P-touch media.'
),
(
    'DISPLAY_24MM_HORIZONTAL',
    'Display Label - 24 mm Horizontal',
    'DISPLAY',
    24,
    'HORIZONTAL',
    'LAMINATED_TAPE',
    'pt_p950nw/QR_display_labels_2_line_24mm.lbx',
    'Narrow Display identity label using 24 mm laminated P-touch media.'
),
(
    'CONTAINER_36MM_HORIZONTAL',
    'Container Label - 36 mm Horizontal',
    'CONTAINER',
    36,
    'HORIZONTAL',
    'LAMINATED_TAPE',
    'pt_p950nw/QR_container_horizontal.lbx',
    'Current horizontal Container identity label using 36 mm laminated P-touch media.'
),
(
    'CONTAINER_36MM_VERTICAL',
    'Container Label - 36 mm Vertical',
    'CONTAINER',
    36,
    'VERTICAL',
    'LAMINATED_TAPE',
    'pt_p950nw/QR_container_vertical.lbx',
    'Current vertical Container identity label using 36 mm laminated P-touch media.'
);

GRANT SELECT ON TABLE ref.label_template TO directus_app;
GRANT SELECT ON TABLE ref.label_template TO printservice;
GRANT SELECT, USAGE ON SEQUENCE ref.label_template_label_template_id_seq TO directus_app;

COMMIT;

SELECT
    label_template_id,
    label_template_code,
    label_template_name,
    label_class,
    media_width_mm,
    label_orientation,
    media_type,
    template_relative_path,
    active_flag,
    created_at,
    created_by,
    created_by_person_id,
    updated_at,
    updated_by,
    updated_by_person_id
FROM ref.label_template
ORDER BY label_template_id;
