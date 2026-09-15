/* MSB Setup #167 — complete current procedure-backed T-Post requirements and stock variants.
   REVIEW BEFORE PRODUCTION.

   Rules:
   - task/installation scope owns requirement truth;
   - durable setup_task_id + expected Stage/real-Scene scope is authoritative;
   - editable task names are diagnostic only;
   - shared normal panel stock is Container 36, split into meaningful length rows;
   - Container 118 remains unresolved special short stock;
   - explicit current-procedure Kit/Container T-Post contents are allowed where supported;
   - conflicting procedure dimensions remain NEEDS_REVIEW, never guessed;
   - no physical inventory event and no 2026 Setup Session are created here.
*/
BEGIN;

DO $preflight$
DECLARE
    v_count integer;
    r record;
BEGIN
    IF to_regclass('ref.setup_task_extra_material') IS NULL
       OR to_regclass('ref.setup_task_extra_material_source') IS NULL
       OR to_regclass('ref.setup_container_extra_material') IS NULL
       OR to_regclass('ref.setup_extra_material') IS NULL THEN
        RAISE EXCEPTION 'Durable #184 Extra Material foundation is required first';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM ref.setup_extra_material
        WHERE material_name='T-Post' AND active_flag
    ) THEN
        RAISE EXCEPTION 'Normalized active T-Post Extra Material is required';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM ref.setup_container_extra_material cem
        JOIN ref.setup_extra_material m USING (setup_extra_material_id)
        JOIN ops.setup_extra_material_inventory_event e
          ON e.setup_container_extra_material_id=cem.setup_container_extra_material_id
        WHERE cem.container_id=36
          AND cem.active_flag
          AND m.material_name='T-Post'
          AND cem.length_value IS NULL
          AND cem.length_unit IS NULL
          AND coalesce(btrim(cem.size_text),'')=''
    ) THEN
        RAISE EXCEPTION 'Cannot split generic Container 36 T-Post stock after physical inventory history exists';
    END IF;

    /* Durable task identity checks. Task names are labels only; Stage and real-Scene
       scope are the fail-closed boundaries for this one-time reconstruction. */
    WITH expected(setup_task_id, stage_key, scene_name, semantic_label) AS (
        VALUES
            (73::bigint,  '15'::text, NULL::text, 'Church RGB Tree'::text),
            (136::bigint, '24'::text, NULL::text, 'Traditional Christmas panels'::text),
            (195::bigint, '00'::text, NULL::text, 'HWY42 Traffic Signs'::text),
            (210::bigint, '17'::text, NULL::text, 'Tumbling Gingerbread'::text),
            (127::bigint, '13'::text, '13-Polar Express'::text, 'Setup Polar Express (Grover Train)'::text),
            (173::bigint, '13'::text, '13-Christmas Story'::text, 'Install Christmas Story panels'::text),
            (194::bigint, '13'::text, '13-Christmas Story'::text, 'Setup Flick and Flagpole'::text),
            (147::bigint, '13'::text, '13-Christmas With the Kranks'::text, 'Kranks VW Setup'::text),
            (160::bigint, '30'::text, '30-Santa''s Station Building'::text, 'Santa''s Station exterior setup'::text)
    )
    SELECT count(*) INTO v_count
    FROM expected e
    JOIN ref.setup_task t
      ON t.setup_task_id=e.setup_task_id
     AND t.active_flag
    JOIN ref.stage s
      ON s.stage_id=t.stage_id
     AND s.stage_key=e.stage_key
    LEFT JOIN ref.lor_scene ls
      ON ls.lor_scene_id=t.lor_scene_id
    WHERE e.scene_name IS NULL OR ls.scene_name=e.scene_name;

    IF v_count <> 9 THEN
        FOR r IN
            WITH expected(setup_task_id, stage_key, scene_name, semantic_label) AS (
                VALUES
                    (73::bigint,  '15'::text, NULL::text, 'Church RGB Tree'::text),
                    (136::bigint, '24'::text, NULL::text, 'Traditional Christmas panels'::text),
                    (195::bigint, '00'::text, NULL::text, 'HWY42 Traffic Signs'::text),
                    (210::bigint, '17'::text, NULL::text, 'Tumbling Gingerbread'::text),
                    (127::bigint, '13'::text, '13-Polar Express'::text, 'Setup Polar Express (Grover Train)'::text),
                    (173::bigint, '13'::text, '13-Christmas Story'::text, 'Install Christmas Story panels'::text),
                    (194::bigint, '13'::text, '13-Christmas Story'::text, 'Setup Flick and Flagpole'::text),
                    (147::bigint, '13'::text, '13-Christmas With the Kranks'::text, 'Kranks VW Setup'::text),
                    (160::bigint, '30'::text, '30-Santa''s Station Building'::text, 'Santa''s Station exterior setup'::text)
            )
            SELECT e.setup_task_id, e.stage_key AS expected_stage_key,
                   e.scene_name AS expected_scene_name, e.semantic_label,
                   t.active_flag, t.task_name,
                   s.stage_key AS actual_stage_key,
                   ls.scene_name AS actual_scene_name
            FROM expected e
            LEFT JOIN ref.setup_task t ON t.setup_task_id=e.setup_task_id
            LEFT JOIN ref.stage s ON s.stage_id=t.stage_id
            LEFT JOIN ref.lor_scene ls ON ls.lor_scene_id=t.lor_scene_id
            WHERE t.setup_task_id IS NULL
               OR NOT coalesce(t.active_flag,false)
               OR s.stage_key IS DISTINCT FROM e.stage_key
               OR (e.scene_name IS NOT NULL AND ls.scene_name IS DISTINCT FROM e.scene_name)
            ORDER BY e.setup_task_id
        LOOP
            RAISE NOTICE 'T-Post final task mismatch: task_id=% semantic_label=% expected_stage=% actual_stage=% expected_scene=% actual_scene=% active=% current_task_name=%',
                r.setup_task_id, r.semantic_label, r.expected_stage_key,
                r.actual_stage_key, r.expected_scene_name, r.actual_scene_name,
                r.active_flag, r.task_name;
        END LOOP;
        RAISE EXCEPTION 'One or more durable final T-Post task identities/scopes changed; reconcile before preload';
    END IF;
END
$preflight$;

/* Replace generic normal-panel stock with countable length-specific rows. */
UPDATE ref.setup_container_extra_material cem
SET active_flag=false,
    notes=concat_ws(' ', cem.notes,
        '[#167 TPOST STOCK SPLIT] Replaced by 5/6/7/8-ft stock rows so physical counts can be maintained by meaningful length.')
FROM ref.setup_extra_material m
WHERE cem.setup_extra_material_id=m.setup_extra_material_id
  AND cem.container_id=36
  AND cem.active_flag
  AND m.material_name='T-Post'
  AND cem.length_value IS NULL
  AND cem.length_unit IS NULL
  AND coalesce(btrim(cem.size_text),'')='';

WITH lengths(length_value) AS (VALUES (5::numeric),(6::numeric),(7::numeric),(8::numeric)),
tpost AS (
    SELECT setup_extra_material_id, default_uom
    FROM ref.setup_extra_material
    WHERE material_name='T-Post' AND active_flag
)
INSERT INTO ref.setup_container_extra_material(
    container_id, setup_extra_material_id, expected_quantity, quantity_uom,
    size_text, length_value, length_unit, verification_state, notes, active_flag
)
SELECT
    36, m.setup_extra_material_id, NULL, m.default_uom,
    'shared normal panel stock', l.length_value, 'FT', 'UNVERIFIED',
    '[#167 TPOST STOCK SPLIT] Shared normal panel T-Post stock. Physical on-hand count remains unrecorded until inventory is performed.',
    true
FROM lengths l CROSS JOIN tpost m
WHERE NOT EXISTS (
    SELECT 1 FROM ref.setup_container_extra_material cem
    WHERE cem.container_id=36
      AND cem.setup_extra_material_id=m.setup_extra_material_id
      AND cem.quantity_uom=m.default_uom
      AND cem.length_value=l.length_value
      AND cem.length_unit='FT'
      AND cem.color IS NULL
      AND cem.active_flag
);

/* Explicit current-procedure physical T-Post contents outside shared Container 36. */
WITH seed(container_id, expected_quantity, size_text, length_value, length_unit, verification_state, evidence_note) AS (
    VALUES
        (58, NULL::numeric, 'Candy Cane support posts; exact count/length unresolved'::text,
         NULL::numeric, NULL::text, 'NEEDS_REVIEW'::text,
         '17-Candyland-CL Rev 20260513 says a T-post included in the Candyland kit is driven at each flagged Gingerbread House candy-cane location; exact post count/length is not stated.'::text),
        (105, 2::numeric, 'Nutcracker ornaments/gifts small posts'::text,
         6::numeric, 'FT'::text, 'UNVERIFIED'::text,
         '23-Traditional Christmas-TC Rev 20260813: re-add two small T-posts for Nutcracker in Traditional Kit C105; detailed table identifies them as 2 x 6-ft.'::text),
        (145, 3::numeric, 'Church tree guy-wire posts'::text,
         NULL::numeric, NULL::text, 'UNVERIFIED'::text,
         '15-Church RGB Tree procedure: Church Tree Kit C145 contains 3 T-posts; exact length is not stated.'::text),
        (146, 4::numeric, 'Santa Station SSR Train posts'::text,
         5::numeric, 'FT'::text, 'UNVERIFIED'::text,
         '26-Santa''s Station-QV Rev 20260611: 4 x 5-ft fence posts for SSR Train panels.'::text),
        (146, 9::numeric, 'Santa Station panel posts physically listed in C146'::text,
         6::numeric, 'FT'::text, 'UNVERIFIED'::text,
         '26-Santa''s Station-QV Rev 20260611 current C146 inventory explicitly lists 9 x 6-ft T-posts; procedure task total says 11 x 6-ft, leaving a 2-post source gap.'::text)
), tpost AS (
    SELECT setup_extra_material_id, default_uom
    FROM ref.setup_extra_material
    WHERE material_name='T-Post' AND active_flag
)
INSERT INTO ref.setup_container_extra_material(
    container_id, setup_extra_material_id, expected_quantity, quantity_uom,
    size_text, length_value, length_unit, verification_state, notes, active_flag
)
SELECT
    s.container_id, m.setup_extra_material_id, s.expected_quantity, m.default_uom,
    s.size_text, s.length_value, s.length_unit, s.verification_state,
    '[#167 EXPLICIT TPOST CONTENT] ' || s.evidence_note,
    true
FROM seed s CROSS JOIN tpost m
WHERE EXISTS (SELECT 1 FROM ref.container c WHERE c.container_id=s.container_id)
  AND NOT EXISTS (
      SELECT 1 FROM ref.setup_container_extra_material cem
      WHERE cem.container_id=s.container_id
        AND cem.setup_extra_material_id=m.setup_extra_material_id
        AND cem.quantity_uom=m.default_uom
        AND coalesce(lower(btrim(cem.size_text)), '')=coalesce(lower(btrim(s.size_text)), '')
        AND coalesce(cem.length_value,-1::numeric)=coalesce(s.length_value,-1::numeric)
        AND coalesce(cem.length_unit,'')=coalesce(s.length_unit,'')
        AND cem.color IS NULL
        AND cem.active_flag
  );

/* Current procedure-backed task requirements. Conflict rows intentionally keep
   length NULL and describe the alternatives instead of guessing. */
WITH seed(
    setup_task_id, quantity_required, quantity_qualifier, size_text,
    length_value, length_unit, verification_state, evidence_note
) AS (
    VALUES
        (195::bigint,20::numeric,'EXACT'::text,'HWY42 traffic-sign panel posts'::text,5::numeric,'FT'::text,'UNVERIFIED'::text,
         '00-HWY 42 Signs Rev 20260629 explicitly requires 20 x 5-ft T-Posts and excludes Front Entrance panels.'::text),
        (210,4,'EXACT','orange Tumbling Gingerbread fence posts',NULL,NULL,'UNVERIFIED',
         '17-Candyland-CL Rev 20260513 Tumbling Gingerbread section explicitly lists 4 orange Fence Posts on the Gingerbread pallet; current physical source identity remains unresolved.'),
        (73,2,'MINIMUM','rear guy-wire posts; possible third front post',NULL,NULL,'NEEDS_REVIEW',
         '15-Church RGB Tree procedure says drive 2 fence posts for rear guy wires; Kit C145 contains 3 T-posts and procedure discusses possibly adding another front post.'),
        (136,6,'EXACT','Traditional Christmas procedure summary',6,'FT','NEEDS_REVIEW',
         '23-Traditional Christmas-TC Rev 20260813 summary says 6 x 6-ft posts; detailed table contains conflicting totals, so retain review state.'),
        (136,16,'EXACT','Traditional Christmas procedure summary',7,'FT','NEEDS_REVIEW',
         '23-Traditional Christmas-TC Rev 20260813 summary says 16 x 7-ft posts; detailed table contains conflicting totals, so retain review state.'),
        (127,13,'EXACT','Polar Express procedure summary; hose inclusion unresolved',5,'FT','NEEDS_REVIEW',
         '13-Polar Express Rev 20260630 explicitly lists 13 x 5-ft Fence Posts. Procedure separately says Hose 1/2 use 3 T-posts; whether those are included in summary totals is unresolved.'),
        (127,9,'EXACT','Polar Express procedure summary; hose inclusion unresolved',7,'FT','NEEDS_REVIEW',
         '13-Polar Express Rev 20260630 explicitly lists 9 x 7-ft Fence Posts for RR Crossings, Condor and VW; hose-post inclusion in summary totals remains unresolved.'),
        (173,2,'EXACT','Fragile Box posts',5,'FT','UNVERIFIED',
         '13-Winter Wonderland detailed table explicitly lists Fragile Box 2 x 5-ft T-Posts; current task 173 Install Christmas Story panels owns the general Christmas Story panel work.'),
        (194,1,'EXACT','Flick post: 5-ft detail vs 6-ft summary conflict',NULL,NULL,'NEEDS_REVIEW',
         '13-Winter Wonderland detailed table lists Flick 1 x 5-ft post while the material summary says 1 x 6-ft; current task 194 Setup Flick and Flagpole owns this work.'),
        (173,2,'EXACT','Ralphie posts: 7-ft detail vs 8-ft summary conflict',NULL,NULL,'NEEDS_REVIEW',
         '13-Winter Wonderland detailed table lists Ralphie 2 x 7-ft posts while the material summary groups Ralphie under 8-ft posts; current task 173 owns general Christmas Story panel work.'),
        (147,2,'EXACT','Kranks VW side posts: 5-ft summary vs 6-ft detail conflict',NULL,NULL,'NEEDS_REVIEW',
         '13-Winter Wonderland summary says the 5-ft total includes two for Kranks VW; detailed row says two 6-ft side posts; current task 147 Kranks VW Setup owns this work.'),
        (147,1,'EXACT','Kranks VW center support: 7-ft cell vs 8-ft note/summary conflict',NULL,NULL,'NEEDS_REVIEW',
         '13-Winter Wonderland detailed cell shows one 7-ft center post while notes/material summary describe an 8-ft center support; current task 147 owns this work.'),
        (160,4,'EXACT','Santa Station SSR Train posts',5,'FT','NEEDS_REVIEW',
         '26-Santa''s Station-QV Rev 20260611 says 4 x 5-ft fence posts for SSR Train panels; current Container C146 explicitly supports this quantity; current task 160 Santa''s Station exterior setup owns the work.'),
        (160,11,'EXACT','Santa Station remaining panel posts',6,'FT','NEEDS_REVIEW',
         '26-Santa''s Station-QV Rev 20260611 says 11 x 6-ft fence posts for remaining panels, but current C146 inventory explicitly lists only 9 x 6-ft T-posts; current task 160 owns the work.')
), tpost AS (
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
    s.size_text, s.length_value, s.length_unit, NULL, s.quantity_qualifier,
    s.verification_state,
    '[TPOST_FINAL_RECON_2026_09_14] ' || s.evidence_note,
    true
FROM seed s CROSS JOIN tpost m
WHERE NOT EXISTS (
    SELECT 1 FROM ref.setup_task_extra_material tm
    WHERE tm.setup_task_id=s.setup_task_id
      AND tm.setup_extra_material_id=m.setup_extra_material_id
      AND tm.quantity_uom='EA'
      AND coalesce(lower(btrim(tm.size_text)), '')=coalesce(lower(btrim(s.size_text)), '')
      AND coalesce(tm.length_value,-1::numeric)=coalesce(s.length_value,-1::numeric)
      AND coalesce(tm.length_unit,'')=coalesce(s.length_unit,'')
      AND tm.color IS NULL
      AND tm.active_flag
);

/* Expected source allocation is separate from task requirement truth and from
   physical inventory. Omitted source means the evidence does not safely identify one. */
WITH source_seed(
    setup_task_id, size_text, length_value, length_unit,
    container_id, expected_quantity, verification_state, note
) AS (
    VALUES
        (195::bigint,'HWY42 traffic-sign panel posts'::text,5::numeric,'FT'::text,36,20::numeric,'UNVERIFIED'::text,'Shared normal panel stock.'::text),
        (73,'rear guy-wire posts; possible third front post',NULL,NULL,145,2,'NEEDS_REVIEW','Church Kit C145 explicitly contains 3 posts; minimum task use is 2 with possible third.'),
        (136,'Traditional Christmas procedure summary',6,'FT',105,2,'NEEDS_REVIEW','Traditional Kit C105 explicitly carries the two Nutcracker 6-ft posts.'),
        (136,'Traditional Christmas procedure summary',6,'FT',36,4,'NEEDS_REVIEW','Remaining four 6-ft posts expected from shared normal stock; procedure detail conflicts keep review state.'),
        (136,'Traditional Christmas procedure summary',7,'FT',36,16,'NEEDS_REVIEW','Shared normal panel stock.'),
        (127,'Polar Express procedure summary; hose inclusion unresolved',5,'FT',36,13,'NEEDS_REVIEW','Shared normal panel stock; hose inclusion ambiguity retained.'),
        (127,'Polar Express procedure summary; hose inclusion unresolved',7,'FT',36,9,'NEEDS_REVIEW','Shared normal panel stock; hose inclusion ambiguity retained.'),
        (173,'Fragile Box posts',5,'FT',36,2,'UNVERIFIED','Shared normal panel stock.'),
        (194,'Flick post: 5-ft detail vs 6-ft summary conflict',NULL,NULL,36,1,'NEEDS_REVIEW','Shared normal stock expected; exact length unresolved.'),
        (173,'Ralphie posts: 7-ft detail vs 8-ft summary conflict',NULL,NULL,36,2,'NEEDS_REVIEW','Shared normal stock expected; exact length unresolved.'),
        (147,'Kranks VW side posts: 5-ft summary vs 6-ft detail conflict',NULL,NULL,36,2,'NEEDS_REVIEW','Shared normal stock expected; exact length unresolved.'),
        (147,'Kranks VW center support: 7-ft cell vs 8-ft note/summary conflict',NULL,NULL,36,1,'NEEDS_REVIEW','Shared normal stock expected; exact length unresolved.'),
        (160,'Santa Station SSR Train posts',5,'FT',146,4,'NEEDS_REVIEW','Current C146 explicitly covers all four 5-ft SSR Train posts.'),
        (160,'Santa Station remaining panel posts',6,'FT',146,9,'NEEDS_REVIEW','Current C146 explicitly contains 9 of the 11 required 6-ft posts; two-post source gap remains reviewable.')
), requirements AS (
    SELECT s.*, tm.setup_task_extra_material_id
    FROM source_seed s
    JOIN ref.setup_extra_material m
      ON m.material_name='T-Post' AND m.active_flag
    JOIN ref.setup_task_extra_material tm
      ON tm.setup_task_id=s.setup_task_id
     AND tm.setup_extra_material_id=m.setup_extra_material_id
     AND tm.quantity_uom='EA'
     AND coalesce(lower(btrim(tm.size_text)), '')=coalesce(lower(btrim(s.size_text)), '')
     AND coalesce(tm.length_value,-1::numeric)=coalesce(s.length_value,-1::numeric)
     AND coalesce(tm.length_unit,'')=coalesce(s.length_unit,'')
     AND tm.color IS NULL
     AND tm.active_flag
)
INSERT INTO ref.setup_task_extra_material_source(
    setup_task_extra_material_id, container_id, expected_quantity,
    verification_state, notes, active_flag
)
SELECT
    r.setup_task_extra_material_id, r.container_id, r.expected_quantity,
    r.verification_state,
    '[TPOST_FINAL_RECON_2026_09_14] ' || r.note ||
    ' Physical on-hand inventory remains independent.',
    true
FROM requirements r
WHERE NOT EXISTS (
    SELECT 1 FROM ref.setup_task_extra_material_source src
    WHERE src.setup_task_extra_material_id=r.setup_task_extra_material_id
      AND src.container_id=r.container_id
      AND src.active_flag
);

DO $proof$
DECLARE
    v_new_requirements integer;
    v_c36_variants integer;
BEGIN
    SELECT count(*) INTO v_new_requirements
    FROM ref.setup_task_extra_material tm
    JOIN ref.setup_extra_material m USING (setup_extra_material_id)
    WHERE tm.active_flag
      AND m.material_name='T-Post'
      AND tm.notes LIKE '[TPOST_FINAL_RECON_2026_09_14]%';
    IF v_new_requirements <> 14 THEN
        RAISE EXCEPTION 'Expected 14 final T-Post requirement rows, got %', v_new_requirements;
    END IF;

    SELECT count(*) INTO v_c36_variants
    FROM ref.setup_container_extra_material cem
    JOIN ref.setup_extra_material m USING (setup_extra_material_id)
    WHERE cem.container_id=36
      AND cem.active_flag
      AND m.material_name='T-Post'
      AND cem.length_unit='FT'
      AND cem.length_value IN (5,6,7,8);
    IF v_c36_variants <> 4 THEN
        RAISE EXCEPTION 'Expected four active Container 36 T-Post length variants, got %', v_c36_variants;
    END IF;

    IF EXISTS (
        SELECT 1
        FROM ref.setup_container_extra_material cem
        JOIN ref.setup_extra_material m USING (setup_extra_material_id)
        WHERE cem.container_id=36
          AND cem.active_flag
          AND m.material_name='T-Post'
          AND cem.length_value IS NULL
          AND cem.length_unit IS NULL
          AND coalesce(btrim(cem.size_text),'')=''
    ) THEN
        RAISE EXCEPTION 'Generic Container 36 T-Post row remains active after stock split';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM ref.setup_container_extra_material cem
        JOIN ref.setup_extra_material m USING (setup_extra_material_id)
        WHERE cem.container_id=118
          AND cem.active_flag
          AND m.material_name='T-Post'
          AND cem.size_text='special short stock'
    ) THEN
        RAISE EXCEPTION 'Container 118 special short T-Post stock row is missing';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM ref.setup_container_extra_material cem
        JOIN ref.setup_extra_material m USING (setup_extra_material_id)
        WHERE cem.container_id=105 AND cem.active_flag AND m.material_name='T-Post'
          AND cem.expected_quantity=2 AND cem.length_value=6 AND cem.length_unit='FT'
    ) OR NOT EXISTS (
        SELECT 1 FROM ref.setup_container_extra_material cem
        JOIN ref.setup_extra_material m USING (setup_extra_material_id)
        WHERE cem.container_id=145 AND cem.active_flag AND m.material_name='T-Post'
          AND cem.expected_quantity=3
    ) OR NOT EXISTS (
        SELECT 1 FROM ref.setup_container_extra_material cem
        JOIN ref.setup_extra_material m USING (setup_extra_material_id)
        WHERE cem.container_id=146 AND cem.active_flag AND m.material_name='T-Post'
          AND cem.expected_quantity=4 AND cem.length_value=5
    ) OR NOT EXISTS (
        SELECT 1 FROM ref.setup_container_extra_material cem
        JOIN ref.setup_extra_material m USING (setup_extra_material_id)
        WHERE cem.container_id=146 AND cem.active_flag AND m.material_name='T-Post'
          AND cem.expected_quantity=9 AND cem.length_value=6
    ) THEN
        RAISE EXCEPTION 'One or more explicit task-specific T-Post Container contents are missing';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM ops.setup_extra_material_inventory_event e
        JOIN ref.setup_container_extra_material cem
          ON cem.setup_container_extra_material_id=e.setup_container_extra_material_id
        WHERE cem.notes LIKE '[#167 TPOST STOCK SPLIT]%'
           OR cem.notes LIKE '[#167 EXPLICIT TPOST CONTENT]%'
    ) THEN
        RAISE EXCEPTION 'T-Post completion migration unexpectedly created physical inventory history';
    END IF;

    IF EXISTS (SELECT 1 FROM ops.setup_session WHERE season_year=2026) THEN
        RAISE EXCEPTION '#167 T-Post completion unexpectedly created a 2026 Setup Session';
    END IF;
END
$proof$;

COMMIT;

SELECT
    s.stage_key,
    tm.setup_task_id,
    t.task_name,
    ls.scene_name,
    tm.quantity_required,
    tm.quantity_qualifier,
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
LEFT JOIN ref.lor_scene ls ON ls.lor_scene_id=t.lor_scene_id
LEFT JOIN ref.setup_task_extra_material_source src
  ON src.setup_task_extra_material_id=tm.setup_task_extra_material_id
 AND src.active_flag
WHERE tm.active_flag
  AND m.material_name='T-Post'
ORDER BY s.park_order NULLS LAST, s.sub_order NULLS LAST,
         t.display_order, t.setup_task_id,
         tm.length_value NULLS LAST, tm.setup_task_extra_material_id;
