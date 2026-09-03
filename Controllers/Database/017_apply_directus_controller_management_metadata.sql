/* ============================================================================
Controller Inventory — Apply Directus-style management metadata
Issue: #110

Purpose:
  Turn the registered ref.controller* collections into a usable Directus
  management surface modeled on the existing Display/Container edit forms.

Safety boundaries:
  - ref.controller asset DELETE remains denied.
  - ref.controller_display DELETE is allowed only so a Manager can unassign a
    Display relationship without deleting the Controller asset.
  - raw numeric LOR UID storage remains read-only in Directus until the accepted
    hexadecimal operator edit workflow exists.
  - pre-change Directus metadata is backed up in stage.* before mutation.
============================================================================ */

BEGIN;

DO $preflight$
DECLARE
    manager_policy_count integer;
BEGIN
    IF to_regclass('public.directus_fields') IS NULL
       OR to_regclass('public.directus_relations') IS NULL
       OR to_regclass('public.directus_collections') IS NULL
       OR to_regclass('public.directus_permissions') IS NULL
       OR to_regclass('public.directus_policies') IS NULL THEN
        RAISE EXCEPTION 'Required Directus metadata tables are missing';
    END IF;

    IF to_regclass('ref.controller') IS NULL
       OR to_regclass('ref.controller_display') IS NULL
       OR to_regclass('ref.controller_firmware_history') IS NULL THEN
        RAISE EXCEPTION 'Permanent Controller Inventory tables are missing';
    END IF;

    SELECT count(*) INTO manager_policy_count
    FROM public.directus_policies
    WHERE name='Manager';
    IF manager_policy_count <> 1 THEN
        RAISE EXCEPTION 'Expected exactly one Manager policy, found %', manager_policy_count;
    END IF;
END
$preflight$;

CREATE TABLE IF NOT EXISTS stage.controller_directus_collections_backup_20260831 AS
SELECT * FROM public.directus_collections
WHERE collection IN (
    'controller','controller_display','controller_model','controller_status',
    'controller_firmware_version','controller_firmware_history'
);

CREATE TABLE IF NOT EXISTS stage.controller_directus_fields_backup_20260831 AS
SELECT * FROM public.directus_fields
WHERE collection IN (
    'controller','controller_display','controller_model','controller_status',
    'controller_firmware_version','controller_firmware_history'
);

CREATE TABLE IF NOT EXISTS stage.controller_directus_relations_backup_20260831 AS
SELECT * FROM public.directus_relations
WHERE many_collection IN ('controller','controller_display','controller_firmware_history')
   OR one_collection='controller';

CREATE TABLE IF NOT EXISTS stage.controller_directus_permissions_backup_20260831 AS
SELECT * FROM public.directus_permissions
WHERE collection IN ('controller','controller_display','controller_firmware_history');

UPDATE public.directus_collections
SET icon='memory',
    note='Permanent physical Controller inventory and maintenance',
    display_template='CTRL {{controller_id}}',
    sort=5,
    hidden=false,
    collapse='open'
WHERE collection='controller';

UPDATE public.directus_collections
SET display_template='{{model_code}} — {{model_name}}',
    note='Controlled Controller model catalog'
WHERE collection='controller_model';

UPDATE public.directus_collections
SET display_template='{{controller_status_name}}',
    note='Controlled Controller operational status catalog'
WHERE collection='controller_status';

UPDATE public.directus_collections
SET display_template='{{firmware_version}}',
    note='Controlled Controller firmware catalog'
WHERE collection='controller_firmware_version';

UPDATE public.directus_collections
SET hidden=true,
    note='Controller-to-Display assignment relationship; manage through Controller'
WHERE collection='controller_display';

INSERT INTO public.directus_fields
    (collection, field, interface, options, display, display_options,
     readonly, hidden, sort, width, note, required, "group", searchable)
SELECT
    'controller', v.field, v.interface, v.options::json, v.display,
    v.display_options::json, v.readonly, v.hidden, v.sort, v.width,
    v.note, v.required, v.group_name, true
FROM (VALUES
    ('lor_network', 'input', '{"softLength":20}', NULL, NULL, false, false, 1, 'half',
     'Current programmed LOR network. This is configuration, not permanent identity.', false, 'Programmed_Config'),
    ('lor_uid_start', 'input', NULL, NULL, NULL, true, false, 2, 'half',
     'Numeric storage value for First UID. Read-only here because operator UID entry is hexadecimal.', false, 'Programmed_Config'),
    ('lor_uid_count', 'input', NULL, NULL, NULL, true, false, 3, 'half',
     'Stored UID count. Read-only here until the hexadecimal programmed-config edit workflow is implemented.', false, 'Programmed_Config'),
    ('lor_uid_end', 'input', NULL, NULL, NULL, true, false, 4, 'half',
     'Database-generated numeric ending UID. Never edit directly.', false, 'Programmed_Config'),
    ('management_ip', 'input', '{"softLength":39}', NULL, NULL, false, false, 5, 'half',
     'Current controller management IP when applicable.', false, 'Programmed_Config'),
    ('programmed_config_verification_state', 'select-dropdown',
     '{"choices":[{"text":"Unknown","value":"UNKNOWN"},{"text":"Recorded - Unverified","value":"RECORDED_UNVERIFIED"},{"text":"Verified","value":"VERIFIED"}]}',
     NULL, NULL, false, false, 6, 'half',
     'Verification state for current programmed configuration.', true, 'Programmed_Config'),
    ('programmed_config_verified_at', 'datetime', '{"format":"short","use24":false}', NULL, NULL,
     true, false, 7, 'half', 'Verification timestamp.', false, 'Programmed_Config'),
    ('programmed_config_verified_by_person_id', 'select-dropdown-m2o', NULL, 'related-values',
     '{"template":"{{preferred_name}}"}', true, false, 8, 'half',
     'Person who verified the programmed configuration.', false, 'Programmed_Config'),
    ('programmed_config_source_note', 'input', '{"softLength":120}', NULL, NULL,
     false, false, 9, 'full', 'Source/evidence for recorded programmed configuration.', false, 'Programmed_Config')
) AS v(field, interface, options, display, display_options, readonly, hidden, sort, width, note, required, group_name)
WHERE NOT EXISTS (
    SELECT 1 FROM public.directus_fields f
    WHERE f.collection='controller' AND f.field=v.field
);

INSERT INTO public.directus_fields
    (collection, field, special, interface, options, readonly, hidden, sort, width, required, searchable)
SELECT 'controller', v.field, 'alias,no-data,group', 'group-detail', v.options::json,
       false, false, v.sort, 'full', false, true
FROM (VALUES
    ('Controller_Details', '{"headerIcon":"edit_square","headerColor":"#FFC23B"}', 2),
    ('Operational_State', '{"headerIcon":"inventory_2","headerColor":"#2ECDA7"}', 3),
    ('Programmed_Config', '{"headerIcon":"settings_ethernet","headerColor":"#6644FF"}', 4),
    ('Firmware', '{"headerIcon":"memory","headerColor":"#6E75D1"}', 5),
    ('Display_Assignments', '{"headerIcon":"hub","headerColor":"#2F81F7"}', 6),
    ('Label_Management', '{"headerIcon":"print","headerColor":"#FFA439"}', 7),
    ('Audit_Fields', '{"start":"closed","headerColor":"#A2B5CD","headerIcon":"balance"}', 8)
) AS v(field, options, sort)
WHERE NOT EXISTS (
    SELECT 1 FROM public.directus_fields f
    WHERE f.collection='controller' AND f.field=v.field
);

INSERT INTO public.directus_fields
    (collection, field, special, interface, options, display, display_options,
     readonly, hidden, sort, width, note, required, "group", searchable)
SELECT
    'controller', v.field, 'o2m', 'list-o2m', v.options::json,
    'related-values', v.display_options::json,
    false, false, v.sort, 'full', v.note, false, v.group_name, true
FROM (VALUES
    ('display_assignments', '{"enableCreate":true}', '{"template":"{{display_id.display_name}}"}', 1,
     'Current physical Controller-to-Display assignments.', 'Display_Assignments'),
    ('firmware_history', '{"enableCreate":true}', '{"template":"{{controller_firmware_version_id.firmware_version}}"}', 6,
     'Recorded firmware history for this physical Controller.', 'Firmware')
) AS v(field, options, display_options, sort, note, group_name)
WHERE NOT EXISTS (
    SELECT 1 FROM public.directus_fields f
    WHERE f.collection='controller' AND f.field=v.field
);

UPDATE public.directus_fields SET readonly=true, hidden=false, sort=1, width='half', "group"=NULL,
    note='Permanent PostgreSQL-generated identity. Never edit or reuse.'
WHERE collection='controller' AND field='controller_id';

UPDATE public.directus_fields SET interface='select-dropdown-m2o',
    options='{"template":"{{model_code}} — {{model_name}}"}'::json,
    display='related-values', display_options='{"template":"{{model_code}} — {{model_name}}"}'::json,
    readonly=false, hidden=false, sort=1, width='half', "group"='Controller_Details', required=true,
    note='Controlled physical Controller model.'
WHERE collection='controller' AND field='controller_model_id';

UPDATE public.directus_fields SET interface='input', options='{"softLength":30}'::json,
    readonly=false, hidden=false, sort=2, width='half', "group"='Controller_Details'
WHERE collection='controller' AND field='hardware_revision';

UPDATE public.directus_fields SET interface='input', options='{"softLength":40}'::json,
    readonly=false, hidden=false, sort=3, width='half', "group"='Controller_Details'
WHERE collection='controller' AND field='serial_number';

UPDATE public.directus_fields SET readonly=false, hidden=false, sort=4, width='half', "group"='Controller_Details',
    note='First-known deployment / first use; not manufacture year.'
WHERE collection='controller' AND field='year_deployed';

UPDATE public.directus_fields SET readonly=false, hidden=false, sort=5, width='full', "group"='Controller_Details'
WHERE collection='controller' AND field='notes';

UPDATE public.directus_fields SET interface='select-dropdown-m2o',
    options='{"template":"{{controller_status_name}}"}'::json,
    display='related-values', display_options='{"template":"{{controller_status_name}}"}'::json,
    readonly=false, hidden=false, sort=1, width='half', "group"='Operational_State', required=true
WHERE collection='controller' AND field='controller_status_id';

UPDATE public.directus_fields SET interface='select-dropdown-m2o',
    options='{"template":"{{location_code}} — {{description}}","filter":{"_and":[{"is_active":{"_eq":true}}]}}'::json,
    display='related-values', display_options='{"template":"{{location_code}} — {{description}}"}'::json,
    readonly=false, hidden=false, sort=2, width='half', "group"='Operational_State'
WHERE collection='controller' AND field='current_location_code';

UPDATE public.directus_fields SET interface='boolean',
    options='{"colorOn":"#2ECDA7","colorOff":"#E35169"}'::json,
    display='boolean', readonly=false, hidden=false, sort=3, width='half', "group"='Operational_State'
WHERE collection='controller' AND field='is_display_attached';

UPDATE public.directus_fields SET interface='select-dropdown',
    options='{"choices":[{"text":"Engineering Accepted","value":"ENGINEERING_ACCEPTED"},{"text":"Field Verification Required","value":"FIELD_VERIFICATION_REQUIRED"},{"text":"Physically Verified","value":"PHYSICALLY_VERIFIED"}]}'::json,
    readonly=false, hidden=false, sort=4, width='half', "group"='Operational_State', required=true
WHERE collection='controller' AND field='verification_state';

UPDATE public.directus_fields SET interface='select-dropdown-m2o',
    options='{"template":"{{firmware_version}}"}'::json,
    display='related-values', display_options='{"template":"{{firmware_version}}"}'::json,
    readonly=false, hidden=false, sort=1, width='half', "group"='Firmware'
WHERE collection='controller' AND field='installed_firmware_version_id';

UPDATE public.directus_fields SET interface='select-dropdown',
    options='{"choices":[{"text":"Unknown","value":"UNKNOWN"},{"text":"Recorded - Unverified","value":"RECORDED_UNVERIFIED"},{"text":"Verified","value":"VERIFIED"}]}'::json,
    readonly=false, hidden=false, sort=2, width='half', "group"='Firmware', required=true
WHERE collection='controller' AND field='firmware_verification_state';

UPDATE public.directus_fields SET interface='datetime', options='{"format":"short","use24":false}'::json,
    readonly=true, hidden=false, sort=3, width='half', "group"='Firmware'
WHERE collection='controller' AND field='firmware_verified_at';

UPDATE public.directus_fields SET interface='select-dropdown-m2o', display='related-values',
    display_options='{"template":"{{preferred_name}}"}'::json,
    readonly=true, hidden=false, sort=4, width='half', "group"='Firmware'
WHERE collection='controller' AND field='firmware_verified_by_person_id';

UPDATE public.directus_fields SET interface='input', options='{"softLength":120}'::json,
    readonly=false, hidden=false, sort=5, width='full', "group"='Firmware'
WHERE collection='controller' AND field='firmware_verification_note';

UPDATE public.directus_fields SET interface='boolean',
    options='{"colorOn":"#2ECDA7","colorOff":"#E35169"}'::json,
    display='boolean', display_options='{"labelOn":"Yes","labelOff":"No"}'::json,
    readonly=false, hidden=false, sort=1, width='half', "group"='Label_Management'
WHERE collection='controller' AND field='label_required';

UPDATE public.directus_fields SET interface='boolean',
    options='{"colorOn":"#2ECDA7","colorOff":"#E35169"}'::json,
    display='boolean',
    display_options='{"labelOn":"Print","labelOff":"Don''t Print","colorOn":"#2ECDA7","colorOff":"#E35169","iconOn":"print_connect","iconOff":"print_disabled"}'::json,
    readonly=false, hidden=false, sort=2, width='half', "group"='Label_Management'
WHERE collection='controller' AND field='print_label';

UPDATE public.directus_fields SET interface='select-dropdown-m2o', readonly=false, hidden=false,
    sort=3, width='half', "group"='Label_Management'
WHERE collection='controller' AND field='label_template_id';

UPDATE public.directus_fields SET readonly=true, hidden=false, sort=4, width='half', "group"='Label_Management'
WHERE collection='controller' AND field='label_print_count_cached';

UPDATE public.directus_fields SET interface='datetime', options='{"format":"short","use24":false}'::json,
    readonly=true, hidden=false, sort=5, width='half', "group"='Label_Management'
WHERE collection='controller' AND field='label_print_last_at_cached';

UPDATE public.directus_fields SET interface='select-dropdown-m2o', display='related-values',
    display_options='{"template":"{{preferred_name}}"}'::json,
    readonly=true, hidden=false, sort=6, width='half', "group"='Label_Management'
WHERE collection='controller' AND field='label_print_last_by_cached_id';

UPDATE public.directus_fields
SET readonly=true, hidden=false, width='half', "group"='Audit_Fields'
WHERE collection='controller'
  AND field IN ('created_at','created_by','updated_at','updated_by','created_by_person_id','updated_by_person_id');

UPDATE public.directus_fields SET sort=1 WHERE collection='controller' AND field='created_at';
UPDATE public.directus_fields SET sort=2 WHERE collection='controller' AND field='created_by';
UPDATE public.directus_fields SET sort=3 WHERE collection='controller' AND field='created_by_person_id';
UPDATE public.directus_fields SET sort=4 WHERE collection='controller' AND field='updated_at';
UPDATE public.directus_fields SET sort=5 WHERE collection='controller' AND field='updated_by';
UPDATE public.directus_fields SET sort=6 WHERE collection='controller' AND field='updated_by_person_id';

UPDATE public.directus_fields SET interface='select-dropdown-m2o', display='related-values',
    display_options='{"template":"{{preferred_name}}"}'::json
WHERE collection='controller' AND field IN ('created_by_person_id','updated_by_person_id');

INSERT INTO public.directus_fields
    (collection, field, interface, options, display, display_options,
     readonly, hidden, sort, width, note, required, searchable)
SELECT 'controller_display', v.field, v.interface, v.options::json, v.display,
       v.display_options::json, v.readonly, v.hidden, v.sort, v.width,
       v.note, v.required, true
FROM (VALUES
    ('controller_id', 'select-dropdown-m2o', '{"template":"CTRL {{controller_id}}"}', 'related-values', '{"template":"CTRL {{controller_id}}"}', true, true, 1, 'half', 'Parent permanent Controller identity.', true),
    ('display_id', 'select-dropdown-m2o', '{"template":"{{display_name}}","enableCreate":false}', 'related-values', '{"template":"{{display_name}}"}', false, false, 2, 'full', 'Physical Display served by this Controller.', true),
    ('wiring_source_display_id', 'select-dropdown-m2o', '{"template":"{{display_name}}","enableCreate":false}', 'related-values', '{"template":"{{display_name}}"}', false, false, 3, 'full', 'Use only for reviewed copied-channel/duplicated-wiring cases.', false),
    ('placement_note', 'input', '{"softLength":100}', NULL, NULL, false, false, 4, 'full', 'Optional physical placement note.', false),
    ('notes', 'input', '{"softLength":120}', NULL, NULL, false, false, 5, 'full', 'Relationship notes.', false)
) AS v(field, interface, options, display, display_options, readonly, hidden, sort, width, note, required)
WHERE NOT EXISTS (
    SELECT 1 FROM public.directus_fields f
    WHERE f.collection='controller_display' AND f.field=v.field
);

UPDATE public.directus_fields f
SET interface=v.interface,
    options=v.options::json,
    display=v.display,
    display_options=v.display_options::json,
    readonly=v.readonly,
    hidden=v.hidden,
    sort=v.sort,
    width=v.width,
    note=v.note,
    required=v.required
FROM (VALUES
    ('controller_id', 'select-dropdown-m2o', '{"template":"CTRL {{controller_id}}"}', 'related-values', '{"template":"CTRL {{controller_id}}"}', true, true, 1, 'half', 'Parent permanent Controller identity.', true),
    ('display_id', 'select-dropdown-m2o', '{"template":"{{display_name}}","enableCreate":false}', 'related-values', '{"template":"{{display_name}}"}', false, false, 2, 'full', 'Physical Display served by this Controller.', true),
    ('wiring_source_display_id', 'select-dropdown-m2o', '{"template":"{{display_name}}","enableCreate":false}', 'related-values', '{"template":"{{display_name}}"}', false, false, 3, 'full', 'Use only for reviewed copied-channel/duplicated-wiring cases.', false),
    ('placement_note', 'input', '{"softLength":100}', NULL, NULL, false, false, 4, 'full', 'Optional physical placement note.', false),
    ('notes', 'input', '{"softLength":120}', NULL, NULL, false, false, 5, 'full', 'Relationship notes.', false)
) AS v(field, interface, options, display, display_options, readonly, hidden, sort, width, note, required)
WHERE f.collection='controller_display' AND f.field=v.field;

INSERT INTO public.directus_relations
    (many_collection, many_field, one_collection, one_field, one_deselect_action)
SELECT v.many_collection, v.many_field, v.one_collection, v.one_field, v.deselect_action
FROM (VALUES
    ('controller', 'controller_model_id', 'controller_model', NULL, 'nullify'),
    ('controller', 'controller_status_id', 'controller_status', NULL, 'nullify'),
    ('controller', 'installed_firmware_version_id', 'controller_firmware_version', NULL, 'nullify'),
    ('controller', 'current_location_code', 'storage_location', NULL, 'nullify'),
    ('controller', 'firmware_verified_by_person_id', 'person', NULL, 'nullify'),
    ('controller', 'programmed_config_verified_by_person_id', 'person', NULL, 'nullify'),
    ('controller', 'label_print_last_by_cached_id', 'person', NULL, 'nullify'),
    ('controller', 'label_template_id', 'label_template', NULL, 'nullify'),
    ('controller', 'created_by_person_id', 'person', NULL, 'nullify'),
    ('controller', 'updated_by_person_id', 'person', NULL, 'nullify'),
    ('controller_display', 'controller_id', 'controller', 'display_assignments', 'delete'),
    ('controller_display', 'display_id', 'display', NULL, 'nullify'),
    ('controller_display', 'wiring_source_display_id', 'display', NULL, 'nullify'),
    ('controller_firmware_history', 'controller_id', 'controller', 'firmware_history', 'delete'),
    ('controller_firmware_history', 'controller_firmware_version_id', 'controller_firmware_version', NULL, 'nullify'),
    ('controller_firmware_history', 'verified_by_person_id', 'person', NULL, 'nullify')
) AS v(many_collection, many_field, one_collection, one_field, deselect_action)
WHERE NOT EXISTS (
    SELECT 1 FROM public.directus_relations r
    WHERE r.many_collection=v.many_collection
      AND r.many_field=v.many_field
      AND r.one_collection=v.one_collection
      AND COALESCE(r.one_field,'')=COALESCE(v.one_field,'')
);

GRANT DELETE ON ref.controller_display TO directus_app;
REVOKE DELETE, TRUNCATE ON ref.controller FROM directus_app;

INSERT INTO public.directus_permissions
    (collection, action, permissions, validation, presets, fields, policy)
SELECT 'controller_display', 'delete', NULL, NULL, NULL, '*', p.id
FROM public.directus_policies p
WHERE p.name='Manager'
  AND NOT EXISTS (
      SELECT 1 FROM public.directus_permissions dp
      WHERE dp.collection='controller_display'
        AND dp.action='delete'
        AND dp.policy=p.id
  );

DO $assertions$
DECLARE
    relation_count integer;
BEGIN
    IF has_table_privilege('directus_app','ref.controller','DELETE') THEN
        RAISE EXCEPTION 'Controller asset DELETE must remain denied';
    END IF;
    IF NOT has_table_privilege('directus_app','ref.controller_display','DELETE') THEN
        RAISE EXCEPTION 'Assignment DELETE is required for controlled unassign';
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM public.directus_fields
        WHERE collection='controller' AND field='display_assignments' AND interface='list-o2m'
    ) THEN
        RAISE EXCEPTION 'Controller display_assignments O2M metadata missing';
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM public.directus_fields
        WHERE collection='controller' AND field='print_label' AND interface='boolean'
    ) THEN
        RAISE EXCEPTION 'Controller print_label boolean UI missing';
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM public.directus_fields
        WHERE collection='controller' AND field='lor_uid_start' AND readonly=true
    ) THEN
        RAISE EXCEPTION 'Raw numeric lor_uid_start must remain read-only';
    END IF;

    SELECT count(*) INTO relation_count
    FROM (VALUES
        ('controller', 'controller_model_id', 'controller_model'),
        ('controller', 'controller_status_id', 'controller_status'),
        ('controller', 'installed_firmware_version_id', 'controller_firmware_version'),
        ('controller', 'current_location_code', 'storage_location'),
        ('controller', 'firmware_verified_by_person_id', 'person'),
        ('controller', 'programmed_config_verified_by_person_id', 'person'),
        ('controller', 'label_print_last_by_cached_id', 'person'),
        ('controller', 'label_template_id', 'label_template'),
        ('controller', 'created_by_person_id', 'person'),
        ('controller', 'updated_by_person_id', 'person'),
        ('controller_display', 'controller_id', 'controller'),
        ('controller_display', 'display_id', 'display'),
        ('controller_display', 'wiring_source_display_id', 'display'),
        ('controller_firmware_history', 'controller_id', 'controller'),
        ('controller_firmware_history', 'controller_firmware_version_id', 'controller_firmware_version'),
        ('controller_firmware_history', 'verified_by_person_id', 'person')
    ) AS v(many_collection, many_field, one_collection)
    WHERE EXISTS (
        SELECT 1 FROM public.directus_relations r
        WHERE r.many_collection=v.many_collection
          AND r.many_field=v.many_field
          AND r.one_collection=v.one_collection
    );
    IF relation_count <> 16 THEN
        RAISE EXCEPTION 'Expected 16 Controller relation mappings, found %', relation_count;
    END IF;
END
$assertions$;

COMMIT;

SELECT
    has_table_privilege('directus_app','ref.controller','DELETE') AS controller_delete,
    has_table_privilege('directus_app','ref.controller_display','DELETE') AS assignment_delete,
    EXISTS (
        SELECT 1 FROM public.directus_fields
        WHERE collection='controller' AND field='display_assignments'
    ) AS display_assignments_registered,
    EXISTS (
        SELECT 1 FROM public.directus_fields
        WHERE collection='controller' AND field='firmware_history'
    ) AS firmware_history_registered;
