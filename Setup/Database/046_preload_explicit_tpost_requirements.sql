/* MSB Setup #167 — preload explicit/reviewable T-Post task requirements.
   REVIEW BEFORE PRODUCTION.

   Boundary:
   - task / installation scope owns the 2026 requirement;
   - durable setup_task_id + Stage identity is authoritative for this one-time preload;
   - editable task names are diagnostic labels and must not make a valid durable task fail;
   - frame geometry is comparison evidence, not automatic quantity authority;
   - normal panel stock is sourced from Container 36 where supported;
   - Northern Lights shortened stock is provisionally sourced from Container 118;
   - conflicts and unresolved lengths remain NEEDS_REVIEW rather than guessed;
   - no physical inventory count and no 2026 Setup Session are created here.
*/
BEGIN;

DO $preflight$
DECLARE
    v_missing integer;
    r record;
BEGIN
    IF to_regclass('ref.setup_task_extra_material') IS NULL
       OR to_regclass('ref.setup_task_extra_material_source') IS NULL
       OR to_regclass('ref.setup_extra_material') IS NULL THEN
        RAISE EXCEPTION 'Durable #184 Extra Material foundation is required first';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM ref.setup_extra_material
        WHERE material_name='T-Post' AND active_flag
    ) THEN
        RAISE EXCEPTION 'Normalized active T-Post Extra Material is required';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM ref.container WHERE container_id=36)
       OR NOT EXISTS (SELECT 1 FROM ref.container WHERE container_id=118) THEN
        RAISE EXCEPTION 'Current T-Post stock Containers 36 and 118 are required';
    END IF;

    /* Task names are editable durable Catalog data. The one-time preload keys to the
       durable setup_task_id and verifies that the task is still active in the expected
       Stage. This specifically tolerates the accepted task-112 rename from Setup Panels
       to Setup Sledder Panels while still failing closed if the durable task moved or
       disappeared. */
    WITH expected(setup_task_id, stage_key, semantic_label) AS (
        VALUES
            (1::bigint,   '01'::text, 'Setup Front Entrance Arch'::text),
            (65::bigint,  '01'::text, 'Setup Front Entrance Signs'::text),
            (109::bigint, '09'::text, 'Setup Panels'::text),
            (112::bigint, '11'::text, 'Setup Sledder Panels'::text),
            (132::bigint, '16'::text, 'Setup Northern Lights'::text),
            (200::bigint, '03'::text, 'Install Welcome to Rotary Making Spirits Bright Panels'::text)
    )
    SELECT count(*) INTO v_missing
    FROM expected e
    LEFT JOIN ref.setup_task t
      ON t.setup_task_id=e.setup_task_id
     AND t.active_flag
    LEFT JOIN ref.stage s
      ON s.stage_id=t.stage_id
    WHERE t.setup_task_id IS NULL
       OR s.stage_key IS DISTINCT FROM e.stage_key;

    IF v_missing <> 0 THEN
        FOR r IN
            WITH expected(setup_task_id, stage_key, semantic_label) AS (
                VALUES
                    (1::bigint,   '01'::text, 'Setup Front Entrance Arch'::text),
                    (65::bigint,  '01'::text, 'Setup Front Entrance Signs'::text),
                    (109::bigint, '09'::text, 'Setup Panels'::text),
                    (112::bigint, '11'::text, 'Setup Sledder Panels'::text),
                    (132::bigint, '16'::text, 'Setup Northern Lights'::text),
                    (200::bigint, '03'::text, 'Install Welcome to Rotary Making Spirits Bright Panels'::text)
            )
            SELECT e.setup_task_id, e.stage_key AS expected_stage_key,
                   e.semantic_label, t.active_flag, t.task_name,
                   s.stage_key AS actual_stage_key, s.stage_name AS actual_stage_name
            FROM expected e
            LEFT JOIN ref.setup_task t ON t.setup_task_id=e.setup_task_id
            LEFT JOIN ref.stage s ON s.stage_id=t.stage_id
            WHERE t.setup_task_id IS NULL
               OR NOT coalesce(t.active_flag,false)
               OR s.stage_key IS DISTINCT FROM e.stage_key
            ORDER BY e.setup_task_id
        LOOP
            RAISE NOTICE 'T-Post task mismatch: task_id=% expected_stage=% semantic_label=% actual_active=% actual_stage=% actual_stage_name=% actual_task_name=%',
                r.setup_task_id, r.expected_stage_key, r.semantic_label,
                r.active_flag, r.actual_stage_key, r.actual_stage_name, r.task_name;
        END LOOP;
        RAISE EXCEPTION 'One or more durable reusable T-Post task identities are missing/inactive or moved to another Stage; reconcile before preload';
    END IF;

    FOR r IN
        SELECT t.setup_task_id, s.stage_key, t.task_name
        FROM ref.setup_task t
        JOIN ref.stage s ON s.stage_id=t.stage_id
        WHERE t.setup_task_id IN (1,65,109,112,132,200)
        ORDER BY t.setup_task_id
    LOOP
        RAISE NOTICE 'T-Post preload target: task_id=% stage=% current_task_name=%',
            r.setup_task_id, r.stage_key, r.task_name;
    END LOOP;
END
$preflight$;

/*
Twelve specification rows supported by current procedures/current durable task identity.
Migration 044 already owns the separate Elf Choir task-16 20-post requirement.

NEEDS_REVIEW is used where the procedure itself carries a conflict/exception:
- Front Arch: quantity 2 is stable, but 5-ft vs 6-ft wording conflicts;
- Sledders: terrain/layout exception with a questioned six-post subgroup;
- Northern Lights: quantity 64 is explicit, exact shortened length/source class remains reviewable.
*/
CREATE TEMP TABLE _tpost_046_seed(
    setup_task_id bigint NOT NULL,
    quantity_required numeric NOT NULL,
    length_value numeric,
    length_unit text,
    size_text text,
    verification_state text NOT NULL,
    source_container_id integer NOT NULL,
    evidence_note text NOT NULL
) ON COMMIT DROP;

INSERT INTO _tpost_046_seed VALUES
    (1::bigint,   2::numeric,  NULL::numeric, NULL::text, NULL::text,
     'NEEDS_REVIEW'::text, 36,
     '01-Front Arch Setup Procedure REV 20260515: 2 tie-down T-Posts are required; procedure conflicts between 5 ft and 6 ft, so length remains unresolved.'),
    (65::bigint,  5::numeric,  5::numeric, 'FT'::text, NULL::text,
     'UNVERIFIED'::text, 36,
     'Front Entrance Panels subsection: 5 x 5-ft T-Posts for current Front Entrance panel scope.'),
    (65::bigint,  3::numeric,  6::numeric, 'FT'::text, NULL::text,
     'UNVERIFIED'::text, 36,
     'Front Entrance Panels subsection: 3 x 6-ft posts for current Front Entrance panel scope; legacy Y-Post wording is normalized to T-Post family.'),
    (200::bigint, 6::numeric,  5::numeric, 'FT'::text, NULL::text,
     'UNVERIFIED'::text, 36,
     '03-Welcome Area-WA Setup procedure: 6 x 5-ft T-Posts.'),
    (109::bigint, 6::numeric,  5::numeric, 'FT'::text, NULL::text,
     'UNVERIFIED'::text, 36,
     '09-Global Warming-GW procedure: 6 x 5-ft T-Posts for Tree 3, 4 and 5.'),
    (109::bigint, 8::numeric,  6::numeric, 'FT'::text, NULL::text,
     'UNVERIFIED'::text, 36,
     '09-Global Warming-GW procedure: 8 x nominal 6-ft T-Posts for remaining panels.'),
    (109::bigint, 4::numeric,  8::numeric, 'FT'::text, NULL::text,
     'UNVERIFIED'::text, 36,
     '09-Global Warming-GW procedure: 4 x 8-ft T-Posts used with OMW and Heat Mister panels.'),
    (112::bigint, 1::numeric,  5::numeric, 'FT'::text, NULL::text,
     'NEEDS_REVIEW'::text, 36,
     '11-Sledders-SL REV 202607: explicit terrain/layout exception total includes 1 x 5-ft post.'),
    (112::bigint, 18::numeric, 6::numeric, 'FT'::text, NULL::text,
     'NEEDS_REVIEW'::text, 36,
     '11-Sledders-SL REV 202607: top material total says 18 x 6-ft posts; detailed six-post subgroup is marked with question marks, so retain review state.'),
    (112::bigint, 5::numeric,  7::numeric, 'FT'::text, NULL::text,
     'NEEDS_REVIEW'::text, 36,
     '11-Sledders-SL REV 202607: explicit terrain/layout exception total includes 5 x 7-ft posts.'),
    (112::bigint, 5::numeric,  8::numeric, 'FT'::text, NULL::text,
     'NEEDS_REVIEW'::text, 36,
     '11-Sledders-SL REV 202607: explicit terrain/layout exception total includes 5 x 8-ft posts.'),
    (132::bigint, 64::numeric, NULL::numeric, NULL::text, 'shortened stock'::text,
     'NEEDS_REVIEW'::text, 118,
     '16-Northern Lights-NL REV 20260808: 64 shortened fence/T-Posts for 66 light positions. Exact post length is not stated; Container 118 is the current shortened-stock source candidate.');

WITH tpost AS (
    SELECT setup_extra_material_id
    FROM ref.setup_extra_material
    WHERE material_name='T-Post' AND active_flag
)
INSERT INTO ref.setup_task_extra_material(
    setup_task_id, setup_extra_material_id, quantity_required, quantity_uom,
    size_text, length_value, length_unit, color, quantity_qualifier,
    verification_state, notes, active_flag
)
SELECT
    s.setup_task_id, m.setup_extra_material_id, s.quantity_required, 'EA',
    s.size_text, s.length_value, s.length_unit, NULL, 'EXACT',
    s.verification_state, '[TPOST_RECON_2026_09_14] ' || s.evidence_note, true
FROM _tpost_046_seed s
CROSS JOIN tpost m
WHERE NOT EXISTS (
    SELECT 1
    FROM ref.setup_task_extra_material tm
    WHERE tm.setup_task_id=s.setup_task_id
      AND tm.setup_extra_material_id=m.setup_extra_material_id
      AND tm.quantity_uom='EA'
      AND coalesce(lower(btrim(tm.size_text)), '')=coalesce(lower(btrim(s.size_text)), '')
      AND coalesce(tm.length_value, -1::numeric)=coalesce(s.length_value, -1::numeric)
      AND coalesce(tm.length_unit, '')=coalesce(s.length_unit, '')
      AND tm.color IS NULL
      AND tm.active_flag
);

WITH requirements AS (
    SELECT s.*, tm.setup_task_extra_material_id
    FROM _tpost_046_seed s
    JOIN ref.setup_extra_material m
      ON m.material_name='T-Post' AND m.active_flag
    JOIN ref.setup_task_extra_material tm
      ON tm.setup_task_id=s.setup_task_id
     AND tm.setup_extra_material_id=m.setup_extra_material_id
     AND tm.quantity_uom='EA'
     AND coalesce(lower(btrim(tm.size_text)), '')=coalesce(lower(btrim(s.size_text)), '')
     AND coalesce(tm.length_value, -1::numeric)=coalesce(s.length_value, -1::numeric)
     AND coalesce(tm.length_unit, '')=coalesce(s.length_unit, '')
     AND tm.color IS NULL
     AND tm.active_flag
)
INSERT INTO ref.setup_task_extra_material_source(
    setup_task_extra_material_id, container_id, expected_quantity,
    verification_state, notes, active_flag
)
SELECT
    r.setup_task_extra_material_id, r.source_container_id, r.quantity_required,
    r.verification_state,
    '[TPOST_RECON_2026_09_14] ' || r.evidence_note ||
    ' Physical on-hand inventory remains independent.',
    true
FROM requirements r
WHERE NOT EXISTS (
    SELECT 1
    FROM ref.setup_task_extra_material_source src
    WHERE src.setup_task_extra_material_id=r.setup_task_extra_material_id
      AND src.container_id=r.source_container_id
      AND src.active_flag
);

DO $proof$
DECLARE
    v_requirement_rows integer;
    v_source_rows integer;
BEGIN
    SELECT count(*) INTO v_requirement_rows
    FROM ref.setup_task_extra_material tm
    JOIN ref.setup_extra_material m USING (setup_extra_material_id)
    WHERE tm.active_flag
      AND m.material_name='T-Post'
      AND tm.notes LIKE '[TPOST_RECON_2026_09_14]%';

    SELECT count(*) INTO v_source_rows
    FROM ref.setup_task_extra_material_source src
    WHERE src.active_flag
      AND src.notes LIKE '[TPOST_RECON_2026_09_14]%';

    IF v_requirement_rows <> 12 THEN
        RAISE EXCEPTION 'Expected 12 explicit T-Post requirement preload rows, got %', v_requirement_rows;
    END IF;
    IF v_source_rows <> 12 THEN
        RAISE EXCEPTION 'Expected 12 explicit T-Post source preload rows, got %', v_source_rows;
    END IF;

    IF EXISTS (
        SELECT 1
        FROM _tpost_046_seed e
        WHERE NOT EXISTS (
            SELECT 1
            FROM ref.setup_task_extra_material tm
            JOIN ref.setup_extra_material m USING (setup_extra_material_id)
            JOIN ref.setup_task_extra_material_source src
              ON src.setup_task_extra_material_id=tm.setup_task_extra_material_id
             AND src.active_flag
            WHERE tm.setup_task_id=e.setup_task_id
              AND tm.active_flag
              AND m.material_name='T-Post'
              AND tm.quantity_required=e.quantity_required
              AND tm.quantity_uom='EA'
              AND coalesce(lower(btrim(tm.size_text)), '')=coalesce(lower(btrim(e.size_text)), '')
              AND coalesce(tm.length_value, -1::numeric)=coalesce(e.length_value, -1::numeric)
              AND coalesce(tm.length_unit, '')=coalesce(e.length_unit, '')
              AND tm.verification_state=e.verification_state
              AND src.container_id=e.source_container_id
              AND src.expected_quantity=e.quantity_required
        )
    ) THEN
        RAISE EXCEPTION 'One or more explicit T-Post requirement/source rows do not match the reconciled candidate set';
    END IF;

    IF EXISTS (SELECT 1 FROM ops.setup_session WHERE season_year=2026) THEN
        RAISE EXCEPTION '#167 T-Post preload unexpectedly created a 2026 Setup Session';
    END IF;
END
$proof$;

COMMIT;

SELECT
    s.stage_key,
    t.setup_task_id,
    t.task_name,
    tm.quantity_required,
    tm.quantity_uom,
    tm.size_text,
    tm.length_value,
    tm.length_unit,
    tm.verification_state,
    src.container_id AS source_container_id,
    src.expected_quantity AS source_expected_quantity
FROM ref.setup_task_extra_material tm
JOIN ref.setup_extra_material m USING (setup_extra_material_id)
JOIN ref.setup_task t USING (setup_task_id)
LEFT JOIN ref.stage s ON s.stage_id=t.stage_id
LEFT JOIN ref.setup_task_extra_material_source src
  ON src.setup_task_extra_material_id=tm.setup_task_extra_material_id
 AND src.active_flag
WHERE tm.active_flag
  AND m.material_name='T-Post'
  AND t.setup_task_id IN (1,16,65,109,112,132,200)
ORDER BY s.park_order NULLS LAST, s.sub_order NULLS LAST,
         t.display_order, t.setup_task_id,
         tm.length_value NULLS LAST, tm.setup_task_extra_material_id;
