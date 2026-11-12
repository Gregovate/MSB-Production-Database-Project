/* ============================================================================
MSB Setup Session — browser-review corrections for Stage 02 and Elf Choir
Issue: #122
Status: IMPLEMENTATION CANDIDATE — apply only after migration 009 is accepted
Revision: 2026-09-07 V0.2.0

Purpose:
  Promote operator-confirmed browser-review findings into the provisional 2025
  reconstruction so the next disposable review demonstrates Scene organization
  and missing reusable work instead of requiring repeated manual recreation.

Confirmed working facts represented here:
  - Existing Mega Tree tasks belong to current Scene "02-Mega Tree".
  - Fred's Stars was Setup work in 2025; normal crew 2-3, one Boom Lift, no
    locates required.
  - General Stage 02 panel installation requires locates, no lift, one powered
    stake pounder; exact crew and choice of short/tall stake pounder remain to
    verify.
  - Elf Choir scaffold work requires Locates first.

All newly created 2025 annual rows remain UNVERIFIED. This script organizes and
adds known work; it does not claim verified historical crew/duration/dates.
============================================================================ */

BEGIN;

DO $preflight$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'ref' AND table_name = 'setup_task'
          AND column_name = 'lor_scene_id'
    ) THEN
        RAISE EXCEPTION 'Migration 009 is required first';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM ops.setup_session WHERE season_year = 2025) THEN
        RAISE EXCEPTION '2025 Setup Session is required';
    END IF;
END
$preflight$;

DO $scene_gate$
DECLARE
    v_stage_id integer;
    v_mega_count integer;
    v_fred_count integer;
BEGIN
    SELECT stage_id INTO v_stage_id FROM ref.stage WHERE stage_key = '02';
    IF v_stage_id IS NULL THEN
        RAISE EXCEPTION 'Stage 02 was not found';
    END IF;

    SELECT count(*) INTO v_mega_count
    FROM ref.lor_scene
    WHERE stage_id = v_stage_id AND scene_name = '02-Mega Tree';
    SELECT count(*) INTO v_fred_count
    FROM ref.lor_scene
    WHERE stage_id = v_stage_id AND scene_name = '02-Fred''s Stars';

    IF v_mega_count <> 1 OR v_fred_count <> 1 THEN
        RAISE EXCEPTION 'Expected exactly one current Stage 02 Mega Tree Scene and one Fred''s Stars Scene; found Mega Tree %, Fred''s Stars %',
            v_mega_count, v_fred_count;
    END IF;
END
$scene_gate$;

/* Reorganize the four existing Mega Tree reusable tasks under the current Scene. */
UPDATE ref.setup_task t
SET lor_scene_id = s.lor_scene_id
FROM ref.stage st
JOIN ref.lor_scene s
  ON s.stage_id = st.stage_id
 AND s.scene_name = '02-Mega Tree'
WHERE st.stage_key = '02'
  AND t.stage_id = st.stage_id
  AND t.task_name IN (
      'Prepare / Load Light Strings',
      'Erect / Position Mega Tree Structure',
      'Hang and Secure Light Strings',
      'Complete Electrical / Network Connections'
  );

CREATE TEMP TABLE _review_added_task (
    task_key text PRIMARY KEY,
    setup_task_id bigint NOT NULL
) ON COMMIT DROP;

DO $add_tasks$
DECLARE
    v_stage02 integer;
    v_stage08 integer;
    v_fred_scene bigint;
    v_task_id bigint;
BEGIN
    SELECT stage_id INTO v_stage02 FROM ref.stage WHERE stage_key = '02';
    SELECT stage_id INTO v_stage08 FROM ref.stage WHERE stage_key = '08';
    SELECT s.lor_scene_id INTO v_fred_scene
    FROM ref.lor_scene s
    WHERE s.stage_id = v_stage02
      AND s.scene_name = '02-Fred''s Stars';

    /* Fred's Stars */
    SELECT t.setup_task_id INTO v_task_id
    FROM ref.setup_task t
    WHERE t.stage_id = v_stage02
      AND t.task_name = 'Install Fred''s Stars'
    LIMIT 1;

    IF v_task_id IS NULL THEN
        INSERT INTO ref.setup_task(
            task_name, stage_id, lor_scene_id, task_action_type, display_order,
            normal_crew_min, normal_crew_max, expected_duration_minutes,
            completion_point, readiness_note, reusable_notes
        ) VALUES (
            'Install Fred''s Stars', v_stage02, v_fred_scene, 'WORK', 10,
            2, 3, NULL,
            'Fred''s Stars are installed and secured in their intended Scene positions.',
            'No locates required.',
            '[2025 browser-review correction] Fred''s Stars was a real Setup task. One Boom Lift is normally required. Duration remains to verify.'
        ) RETURNING setup_task_id INTO v_task_id;
    ELSE
        UPDATE ref.setup_task
        SET lor_scene_id = v_fred_scene,
            normal_crew_min = 2,
            normal_crew_max = 3,
            readiness_note = 'No locates required.'
        WHERE setup_task_id = v_task_id;
    END IF;
    INSERT INTO _review_added_task VALUES ('FRED', v_task_id);

    /* Stage 02 locates */
    v_task_id := NULL;
    SELECT t.setup_task_id INTO v_task_id
    FROM ref.setup_task t
    WHERE t.stage_id = v_stage02
      AND t.lor_scene_id IS NULL
      AND t.task_name = 'Locates'
    LIMIT 1;
    IF v_task_id IS NULL THEN
        INSERT INTO ref.setup_task(
            task_name, stage_id, task_action_type, display_order,
            completion_point, readiness_note, reusable_notes
        ) VALUES (
            'Locates', v_stage02, 'WORK', 10,
            'Required Stage 02 field locates are complete for work that depends on them.',
            NULL,
            '[2025 browser-review correction] Stage-level locates prerequisite. Fred''s Stars explicitly does not require this prerequisite.'
        ) RETURNING setup_task_id INTO v_task_id;
    END IF;
    INSERT INTO _review_added_task VALUES ('STAGE02-LOCATES', v_task_id);

    /* General Stage 02 panels */
    v_task_id := NULL;
    SELECT t.setup_task_id INTO v_task_id
    FROM ref.setup_task t
    WHERE t.stage_id = v_stage02
      AND t.lor_scene_id IS NULL
      AND t.task_name = 'Install Stage 02 Panels'
    LIMIT 1;
    IF v_task_id IS NULL THEN
        INSERT INTO ref.setup_task(
            task_name, stage_id, task_action_type, display_order,
            completion_point, readiness_note, reusable_notes
        ) VALUES (
            'Install Stage 02 Panels', v_stage02, 'WORK', 20,
            'Stage 02 general panel Displays are installed and secured.',
            'Locates required before panel installation. No lift required.',
            '[2025 browser-review correction] Requires a larger crew (count still to verify) and one powered stake pounder. MSB has separate Short Stake Pounder and Tall Stake Pounder resources; which one is used is task/field-condition specific and is not guessed here.'
        ) RETURNING setup_task_id INTO v_task_id;
    END IF;
    INSERT INTO _review_added_task VALUES ('STAGE02-PANELS', v_task_id);

    /* Elf Choir locates */
    v_task_id := NULL;
    SELECT t.setup_task_id INTO v_task_id
    FROM ref.setup_task t
    WHERE t.stage_id = v_stage08
      AND t.task_name = 'Locates'
    LIMIT 1;
    IF v_task_id IS NULL THEN
        INSERT INTO ref.setup_task(
            task_name, stage_id, task_action_type, display_order,
            completion_point, reusable_notes
        ) VALUES (
            'Locates', v_stage08, 'WORK', 5,
            'Required Elf Choir field locates are complete before scaffold work begins.',
            '[2025 browser-review correction] Required prerequisite for Set Scaffold and Elves.'
        ) RETURNING setup_task_id INTO v_task_id;
    END IF;
    INSERT INTO _review_added_task VALUES ('ELF-LOCATES', v_task_id);
END
$add_tasks$;

/* Add annual 2025 occurrences without asserting verification. */
INSERT INTO ops.setup_session_task(
    setup_session_id,
    setup_task_id,
    verification_state,
    execution_status,
    annual_notes
)
SELECT
    ss.setup_session_id,
    m.setup_task_id,
    'UNVERIFIED',
    'COMPLETE',
    'Added/reorganized from 2026 browser-review knowledge to improve the 2025 historical verification structure. Historical details remain to verify.'
FROM ops.setup_session ss
CROSS JOIN _review_added_task m
WHERE ss.season_year = 2025
ON CONFLICT (setup_session_id, setup_task_id) DO NOTHING;

/* Fred's Stars requires one Boom Lift. */
INSERT INTO ref.setup_task_resource(
    setup_task_id, setup_resource_id, quantity_required, requirement_type, notes
)
SELECT m.setup_task_id, r.setup_resource_id, 1, 'REQUIRED',
       'Confirmed during Setup browser review: one Boom Lift.'
FROM _review_added_task m
JOIN ref.setup_resource r ON r.resource_name = 'Boom Lift'
WHERE m.task_key = 'FRED'
ON CONFLICT (setup_task_id, setup_resource_id)
DO UPDATE SET quantity_required = 1,
              requirement_type = 'REQUIRED',
              notes = EXCLUDED.notes;

/* Stage 02 panel work depends on Stage 02 locates. */
INSERT INTO ref.setup_task_dependency(setup_task_id, prerequisite_setup_task_id, dependency_note)
SELECT panels.setup_task_id, locates.setup_task_id,
       'Stage 02 panel installation requires locates first.'
FROM _review_added_task panels
JOIN _review_added_task locates ON locates.task_key = 'STAGE02-LOCATES'
WHERE panels.task_key = 'STAGE02-PANELS'
ON CONFLICT (setup_task_id, prerequisite_setup_task_id)
DO UPDATE SET dependency_note = EXCLUDED.dependency_note;

/* Elf Choir scaffold depends on its Locates task. */
INSERT INTO ref.setup_task_dependency(setup_task_id, prerequisite_setup_task_id, dependency_note)
SELECT scaffold.setup_task_id, locates.setup_task_id,
       'Elf Choir scaffold work requires locates first.'
FROM ref.setup_task scaffold
JOIN ref.stage s ON s.stage_id = scaffold.stage_id AND s.stage_key = '08'
CROSS JOIN _review_added_task locates
WHERE scaffold.task_name = 'Set Scaffold and Elves'
  AND locates.task_key = 'ELF-LOCATES'
ON CONFLICT (setup_task_id, prerequisite_setup_task_id)
DO UPDATE SET dependency_note = EXCLUDED.dependency_note;

COMMIT;

SELECT
    ss.season_year,
    count(*) AS annual_tasks,
    count(*) FILTER (WHERE st.verification_state = 'UNVERIFIED') AS unverified
FROM ops.setup_session ss
JOIN ops.setup_session_task st ON st.setup_session_id = ss.setup_session_id
WHERE ss.season_year = 2025
GROUP BY ss.season_year;
