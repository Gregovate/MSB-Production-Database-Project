/* ============================================================================
MSB Setup Session — Command Center + Park Infrastructure review seed
Issue: #122
Status: IMPLEMENTATION CANDIDATE — DISPOSABLE REVIEW ONLY UNTIL ACCEPTED
Revision: 2026-09-07 V0.3.1

Purpose:
  Add the Setup work explicitly identified during Manager review while preserving
  the correct scope boundary:
  - Command Center / connectivity work belongs to existing Stage 40; and
  - only truly park-wide/no-Stage work belongs to Site-wide / Infrastructure.

Evidence / operator facts supplied during review:
  - `40-CommandCenter` has a real LOR Preview and is a legitimate Stage even
    though that Preview currently has no wired inventory items.
  - Command Center trailer must be delivered to the park and set up.
  - WiFi antenna is installed in the tree by one person on a boom lift and aimed
    toward Larry's house chimney approximately 800 feet away.
  - Gateway installation / internet test follows antenna installation.
  - Hotspots deploy after internet connectivity is verified.
  - Street-light removal, street-light fuse conversion to show power, and site
    breaker turn-on are genuinely park-wide Setup work with no required LOR
    Stage/Scene owner.
  - For 2026, Command Center / internet work must be near the beginning of the
    annual planned order because the new Setup system depends on connectivity.

These rows start UNVERIFIED for the 2025 historical review. Crew/time/resource
facts not explicitly established remain NULL rather than invented.
============================================================================ */

BEGIN;

DO $preflight$
DECLARE
    v_session_id bigint;
    v_stage40_id integer;
BEGIN
    IF to_regclass('ref.setup_task') IS NULL
       OR to_regclass('ref.setup_task_dependency') IS NULL
       OR to_regclass('ref.setup_task_resource') IS NULL
       OR to_regclass('ref.setup_resource') IS NULL
       OR to_regclass('ops.setup_session_task') IS NULL
       OR to_regprocedure('ops.set_setup_session_task_planned_order(text,bigint,integer,text)') IS NULL THEN
        RAISE EXCEPTION 'Setup migrations through 011 are required first';
    END IF;

    SELECT setup_session_id INTO v_session_id
    FROM ops.setup_session
    WHERE season_year = 2025;

    IF v_session_id IS NULL THEN
        RAISE EXCEPTION '2025 Setup Session is required for review seed 012';
    END IF;

    SELECT stage_id INTO v_stage40_id
    FROM ref.stage
    WHERE stage_key = '40';

    IF v_stage40_id IS NULL THEN
        RAISE EXCEPTION 'Stage 40 CommandCenter was not found';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM ref.setup_task
        WHERE task_name IN (
            'Deliver and Set Up Command Center Trailer',
            'Install WiFi Antenna',
            'Install Gateway and Test Internet Connection',
            'Deploy Hotspots',
            'Remove Street Lights',
            'Convert Street Lights to Show Power',
            'Turn On Site Breakers'
        )
    ) THEN
        RAISE EXCEPTION 'One or more Command Center / Park Infrastructure review tasks already exist; refuse duplicate seed';
    END IF;
END
$preflight$;

CREATE TEMP TABLE _setup_review_task (
    seed_key text PRIMARY KEY,
    stage_key text,
    task_name text NOT NULL,
    display_order integer NOT NULL,
    baseline_plan_order integer NOT NULL,
    normal_crew_min integer,
    normal_crew_max integer,
    expected_duration_minutes integer,
    completion_point text,
    readiness_note text,
    reusable_notes text
) ON COMMIT DROP;

INSERT INTO _setup_review_task VALUES
(
    'CC-10', '40',
    'Deliver and Set Up Command Center Trailer',
    10, 10,
    NULL, NULL, NULL,
    'Command Center trailer delivered to the park and operationally set up',
    NULL,
    'Stage 40 Command Center Setup work. A real LOR Preview exists even though the Preview currently has no wired inventory items. 2026 planning note: complete near the beginning of Setup because the Setup system depends on field connectivity.'
),
(
    'CC-20', '40',
    'Install WiFi Antenna',
    20, 20,
    1, 1, NULL,
    'WiFi antenna installed in the tree and aimed toward the remote endpoint',
    'Command Center trailer set up',
    'Stage 40 Command Center Setup work. One person on a boom lift installs the antenna and aims it toward Larry''s house chimney approximately 800 feet away.'
),
(
    'CC-30', '40',
    'Install Gateway and Test Internet Connection',
    30, 30,
    NULL, NULL, NULL,
    'Gateway installed and usable internet connection verified',
    'WiFi antenna installed and aimed',
    'Stage 40 Command Center Setup work. Internet connectivity must be verified before hotspot deployment.'
),
(
    'CC-40', '40',
    'Deploy Hotspots',
    40, 40,
    NULL, NULL, NULL,
    'Required park hotspots deployed and connected',
    'Internet connection tested successfully',
    'Stage 40 Command Center / connectivity Setup work. Deploy only after gateway/internet verification.'
),
(
    'PI-10', NULL,
    'Remove Street Lights',
    10, 50,
    NULL, NULL, NULL,
    'Required street lights removed for show Setup',
    NULL,
    'Site-wide / Park Infrastructure task. No LOR Stage/Scene owner is required. Exact crew/time/resources remain to be verified.'
),
(
    'PI-20', NULL,
    'Convert Street Lights to Show Power',
    20, 60,
    NULL, NULL, NULL,
    'Street-light power conversion completed by switching the required fuses',
    NULL,
    'Site-wide / Park Infrastructure task. No LOR Stage/Scene owner is required. Conversion is performed by switching fuses. Exact crew/time/resources remain to be verified.'
),
(
    'PI-30', NULL,
    'Turn On Site Breakers',
    30, 70,
    NULL, NULL, NULL,
    'Required site breakers turned on for Setup/show power',
    NULL,
    'Site-wide / Park Infrastructure task. No LOR Stage/Scene owner is required. Exact crew/time/resources and any safety prerequisites remain to be verified.'
);

CREATE TEMP TABLE _setup_review_map (
    seed_key text PRIMARY KEY,
    setup_task_id bigint NOT NULL
) ON COMMIT DROP;

DO $load$
DECLARE
    r record;
    v_task_id bigint;
    v_stage_id integer;
BEGIN
    FOR r IN SELECT * FROM _setup_review_task ORDER BY baseline_plan_order, seed_key LOOP
        v_stage_id := NULL;
        IF r.stage_key IS NOT NULL THEN
            SELECT stage_id INTO v_stage_id
            FROM ref.stage
            WHERE stage_key = r.stage_key;

            IF v_stage_id IS NULL THEN
                RAISE EXCEPTION 'Stage key % did not resolve for seed %', r.stage_key, r.seed_key;
            END IF;
        END IF;

        INSERT INTO ref.setup_task (
            task_name,
            stage_id,
            lor_scene_id,
            task_action_type,
            display_order,
            baseline_plan_order,
            normal_crew_min,
            normal_crew_max,
            expected_duration_minutes,
            completion_point,
            readiness_note,
            reusable_notes
        ) VALUES (
            r.task_name,
            v_stage_id,
            NULL,
            'WORK',
            r.display_order,
            r.baseline_plan_order,
            r.normal_crew_min,
            r.normal_crew_max,
            r.expected_duration_minutes,
            r.completion_point,
            r.readiness_note,
            '[Setup review seed ' || r.seed_key || '] ' || r.reusable_notes
        )
        RETURNING setup_task_id INTO v_task_id;

        INSERT INTO _setup_review_map(seed_key, setup_task_id)
        VALUES (r.seed_key, v_task_id);
    END LOOP;
END
$load$;

/* Command Center connectivity sequence explicitly established during review. */
INSERT INTO ref.setup_task_dependency(setup_task_id, prerequisite_setup_task_id, dependency_note)
SELECT current_task.setup_task_id, prior_task.setup_task_id, x.note
FROM (VALUES
    ('CC-20','CC-10','Command Center trailer setup precedes antenna installation.'),
    ('CC-30','CC-20','WiFi antenna installation precedes gateway/internet testing.'),
    ('CC-40','CC-30','Internet connectivity must be verified before hotspot deployment.')
) AS x(task_key, prerequisite_key, note)
JOIN _setup_review_map current_task ON current_task.seed_key = x.task_key
JOIN _setup_review_map prior_task ON prior_task.seed_key = x.prerequisite_key;

/* The only structured equipment fact established so far: one Boom Lift for the
   WiFi antenna task. */
INSERT INTO ref.setup_task_resource(
    setup_task_id,
    setup_resource_id,
    quantity_required,
    requirement_type,
    notes
)
SELECT m.setup_task_id, r.setup_resource_id, 1, 'REQUIRED',
       'One boom lift established during Manager review for WiFi antenna installation.'
FROM _setup_review_map m
JOIN ref.setup_resource r ON r.resource_name = 'Boom Lift'
WHERE m.seed_key = 'CC-20';

/* Add the 2025 annual occurrences as historical-review rows. They are not
   asserted as verified 2025 actuals. */
INSERT INTO ops.setup_session_task(
    setup_session_id,
    setup_task_id,
    verification_state,
    execution_status,
    annual_notes,
    planned_order
)
SELECT
    ss.setup_session_id,
    m.setup_task_id,
    'UNVERIFIED',
    'COMPLETE',
    CASE
        WHEN t.stage_id IS NULL THEN
            'Park Infrastructure work added from 2026 Manager review. Verify whether this task occurred in 2025 and correct the annual actual as needed.'
        ELSE
            'Stage 40 Command Center work added from 2026 Manager review. Verify whether this task occurred in 2025 and correct the annual actual as needed.'
    END,
    t.baseline_plan_order
FROM ops.setup_session ss
CROSS JOIN _setup_review_map m
JOIN ref.setup_task t ON t.setup_task_id = m.setup_task_id
WHERE ss.season_year = 2025;

/* Final browser-review usability: leave the Command Center connectivity chain
   incomplete/ready enough to exercise rolling planning and Captain completion
   in the disposable clone. This is not Production acceptance of 2025 execution. */
UPDATE ops.setup_session_task st
   SET execution_status = CASE
       WHEN m.seed_key = 'CC-10' THEN 'READY'
       ELSE 'NOT_READY'
   END,
       actual_completed_at = NULL,
       completed_by_person_id = NULL,
       completion_note = NULL
FROM _setup_review_map m
JOIN ops.setup_session ss ON ss.season_year = 2025
WHERE st.setup_session_id = ss.setup_session_id
  AND st.setup_task_id = m.setup_task_id
  AND m.seed_key IN ('CC-10','CC-20','CC-30','CC-40');

COMMIT;

SELECT
    t.setup_task_id,
    t.task_name,
    s.stage_key,
    t.stage_id,
    t.baseline_plan_order,
    st.planned_order,
    st.verification_state,
    st.execution_status
FROM ref.setup_task t
JOIN ops.setup_session_task st ON st.setup_task_id = t.setup_task_id
JOIN ops.setup_session ss ON ss.setup_session_id = st.setup_session_id
LEFT JOIN ref.stage s ON s.stage_id = t.stage_id
WHERE ss.season_year = 2025
  AND t.setup_task_id IN (SELECT setup_task_id FROM _setup_review_map)
ORDER BY st.planned_order, t.setup_task_id;
