/* ============================================================================
Object:       Stage root-name authority validation
Filename:     34_stage_folder_authority_validation.sql
Type:         Read-only post-install validation
Migration:    0039_repair_stage_folder_authority.sql
Issue:        #96

Purpose:
  Prove the narrow repair:
  - accepted permanent Stage/Sub-stage stage_name and folder_name are the exact
    governed Google Drive root basename;
  - ADD_NEW_STAGE is gated by frozen governed Drive-root evidence;
  - P1 no longer synthesizes Stage names from LOR Preview/Scene names;
  - excluded/special Stage identities were not folded into the repair.

Safety:
  SELECT/DO validation only. Does not start/finish reconciliation, record
  decisions, modify ref/lor_snap data, or alter FieldWiring/Procedures.
============================================================================ */

/* Validation 1: installed authority definitions. All booleans must be true. */
SELECT
    position('lor_snap.previews' IN pg_get_functiondef(
        'ops.f_lor_governed_stage_roots(bigint,text)'::regprocedure
    )) > 0 AS root_reads_frozen_previews,
    position('lor_snap.scenes' IN pg_get_functiondef(
        'ops.f_lor_governed_stage_roots(bigint,text)'::regprocedure
    )) > 0 AS root_reads_frozen_scenes,
    position('shared drives' IN lower(pg_get_functiondef(
        'ops.f_lor_governed_stage_roots(bigint,text)'::regprocedure
    ))) > 0 AS root_requires_display_folders_authority,
    position('c.folder_name AS stage_name' IN pg_get_functiondef(
        'ops.f_lor_governed_stage_roots(bigint,text)'::regprocedure
    )) > 0 AS stage_name_is_exact_root_basename,
    position('f_lor_governed_stage_roots' IN pg_get_functiondef(
        'ops.f_stage_group_can_add_new_stage(bigint)'::regprocedure
    )) > 0 AS add_new_stage_is_root_gated,
    position('governed_folder_path' IN pg_get_functiondef(
        'ref.p1_promote_stage_from_reconciliation(bigint)'::regprocedure
    )) > 0 AS p1_rechecks_frozen_root_payload,
    position('f_normalize_lor_stage_name' IN pg_get_functiondef(
        'ref.p1_promote_stage_from_reconciliation(bigint)'::regprocedure
    )) = 0 AS p1_has_no_source_name_fallback;

/* Validation 2: exact accepted Stage/Sub-stage root names.
   mismatch_count must be zero. */
WITH expected(stage_key, governed_root_name) AS (
    VALUES
      ('00','00-HWY 42-HW'),
      ('01','01-Front Entrance-FE'),
      ('02','02-Triangle-TR'),
      ('03','03-Welcome Area-WA'),
      ('04','04-Food Collection-FC'),
      ('05','05-Festive Trees-FT'),
      ('05a','05a-Mega Star-MS'),
      ('06','06-Post Office-PO'),
      ('07','07-Whoville-WV'),
      ('07a','07a-Who Forest-WF'),
      ('08','08-Elf Choir-EC'),
      ('09','09-Global Warming-GW'),
      ('10','10-Stars-ST'),
      ('11','11-Sledders-SL'),
      ('13','13-Winter Wonderland-WW'),
      ('14','14-Icicle Tunnel-IT'),
      ('15','15-Church-Bells-CH'),
      ('16','16-Northern Lights-NL'),
      ('17','17-Candyland-CL'),
      ('18','18-Dancing Forest-DF'),
      ('19','19-Santa''s Workshop-SW'),
      ('20','20-Snow Storm-SS'),
      ('21','21-Polar Bear Playground-PB'),
      ('22','22-Glistening Grove-GG'),
      ('23','23-Peanuts-PN'),
      ('24','24-Traditional Christmas-TC'),
      ('25','25-Racing Arches-RA'),
      ('26','26-Magic Igloo-MI'),
      ('30','30-Santa''s Station-QV')
)
SELECT count(*) AS mismatch_count
FROM expected AS e
LEFT JOIN ref.stage AS s ON s.stage_key = e.stage_key
WHERE s.stage_id IS NULL
   OR s.stage_name IS DISTINCT FROM e.governed_root_name
   OR s.folder_name IS DISTINCT FROM e.governed_root_name;

/* Validation 3: no accepted repair row retains Preview-derived naming.
   bad_preview_derived_name_count must be zero. */
SELECT count(*) AS bad_preview_derived_name_count
FROM ref.stage
WHERE stage_key IN (
    '00','01','02','03','04','05','05a','06','07','07a','08','09','10','11',
    '13','14','15','16','17','18','19','20','21','22','23','24','25','26','30'
)
AND (
    stage_name ILIKE '%Show Background Stage %'
    OR stage_name ILIKE '%RGB Plus Stage %'
    OR folder_name ILIKE '%Show Background Stage %'
    OR folder_name ILIKE '%RGB Plus Stage %'
);

/* Validation 4: special/excluded rows remain visible for separate review.
   This query intentionally does not assert or modify their values. */
SELECT
    stage_id,
    stage_key,
    stage_name,
    folder_name,
    folder_path,
    park_order,
    sub_order
FROM ref.stage
WHERE stage_key IN ('12','39','40','90','91','92','93','94')
ORDER BY park_order, sub_order, stage_key;

/* Validation 5: show governed-root evidence in the latest snapshot.
   After the corrected 03a parser output is ingested, 03a must resolve exactly:
     G:\Shared drives\Display Folders\03-Welcome Area-WA\03a-Mega Cube-MC
   This is read-only evidence; zero rows before that ingest is expected. */
WITH current_run AS (
    SELECT max(import_run_id) AS import_run_id
    FROM lor_snap.v_current_run
), keys(stage_key) AS (
    VALUES ('03a'),('05a'),('07a'),('17'),('39'),('40')
)
SELECT
    cr.import_run_id,
    k.stage_key,
    count(r.folder_path) AS governed_root_count,
    string_agg(r.stage_name, '; ' ORDER BY r.stage_name) AS governed_stage_names,
    string_agg(r.folder_name, '; ' ORDER BY r.folder_name) AS governed_roots,
    string_agg(r.folder_path, '; ' ORDER BY r.folder_path) AS governed_paths
FROM current_run AS cr
CROSS JOIN keys AS k
LEFT JOIN LATERAL ops.f_lor_governed_stage_roots(
    cr.import_run_id,
    k.stage_key
) AS r ON true
GROUP BY cr.import_run_id, k.stage_key
ORDER BY k.stage_key;

/* Validation 6: if 03a has been promoted, permanent metadata must preserve
   the exact governed Sub-stage root name. Empty output is expected beforehand. */
SELECT
    stage_id,
    stage_key,
    stage_name,
    folder_name,
    folder_path,
    park_order,
    sub_order,
    (stage_name = '03a-Mega Cube-MC'
     AND folder_name = '03a-Mega Cube-MC'
     AND folder_path = E'G:\\Shared drives\\Display Folders\\03-Welcome Area-WA\\03a-Mega Cube-MC')
        AS exact_03a_authority
FROM ref.stage
WHERE stage_key = '03a';
