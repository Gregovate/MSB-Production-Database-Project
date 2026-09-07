/* ============================================================================
MSB Setup Session — Site-wide / Infrastructure review seed
Issue: #122
Status: IMPLEMENTATION CANDIDATE — DISPOSABLE REVIEW ONLY UNTIL ACCEPTED
Revision: 2026-09-07 V0.3.0

Purpose:
  Add the non-LOR Setup work explicitly identified during Manager review so the
  final disposable browser candidate exercises Site-wide / Infrastructure task
  scope rather than forcing this work into a fake Stage or Scene.

Evidence / operator facts supplied during review:
  - Command Center trailer must be delivered to the park and set up.
  - WiFi antenna is installed in the tree by one person on a boom lift and aimed
    toward Larry's house chimney approximately 800 feet away.
  - Gateway installation / internet test follows antenna installation.
  - Hotspots deploy after internet connectivity is verified.
  - Street-light removal, street-light fuse conversion to show power, and site
    breaker turn-on are also real site-wide Setup work.
  - For 2026, Command Center / internet work must be near the beginning of the
    annual planned order because the new Setup system depends on connectivity.

These rows start UNVERIFIED for the 2025 historical review. Crew/time/resource
facts not explicitly established remain NULL rather than invented.
============================================================================ */

BEGIN;

DO $preflight$
DECLARE
    v_session_id bigint;
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

    IF EXISTS (
        SELECT 1
        FROM ref.setup_task
        WHERE stage_id IS NULL
          AND task_name IN (
              'Deliver and Set Up Command Center Trailer',
              'Install WiFi Antenna',
              'Install Gateway and Test Internet Connection',
              'Deploy Hotspots',
              'Remove Street Lights',
              'Convert Street Lights to Show Power',
              'Turn On Site Breakers'
          )
    ) THEN
        RAISE EXCEPTION 'One or more Site Infrastructure review tasks already exist; refuse duplicate seed';
    END IF;
END
$preflight$;

CREATE TEMP TABLE _site_task (
    seed_key text PRIMARY KEY,
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

INSERT INTO _site_task VALUES
(
    'SITE-10',
    'Deliver and Set Up Command Center Trailer',
    10, 10,
    NULL, NULL, NULL,
    'Command Center trailer delivered to the park and operationally set up',
    NULL,
    'Site-wide / Infrastructure task. Non-LOR work. 2026 planning note: complete near the beginning of Setup because the Setup system depends on field connectivity.'
),
(
    'SITE-20',
    'Install WiFi Antenna',
    20, 20,
    1, 1, NULL,
    'WiFi antenna installed in the tree and aimed toward the remote endpoint',
    'Command Center trailer set up',
    'Site-wide / Infrastructure task. One person on a boom lift installs the antenna and aims it toward Larry''s house chimney approximately 800 feet away.'
),
(
    'SITE-30',
    'Install Gateway and Test Internet Connection',
    30, 30,
    NULL, NULL, NULL,
    'Gateway installed and usable internet connection verified',
    'WiFi antenna installed and aimed',
    'Site-wide / Infrastructure task. Internet connectivity must be verified before hotspot deployment.'
),
(
    'SITE-40',
    'Deploy Hotspots',
    40, 40,
    NULL, NULL, NULL,
    'Required park hotspots deployed and connected',
    'Internet connection tested successfully',
    'Site-wide / Infrastructure task. Deploy only after gateway/internet verification.'
),
(
    'SITE-50',
    'Remove Street Lights',
    50, 50,
    NULL, NULL, NULL,
    'Required street lights removed for show Setup',
    NULL,
    'Site-wide / Infrastructure task. Exact crew/time/resources remain to be verified.'
),
(
    'SITE-60',
    'Convert Street Lights to Show Power',
    60, 60,
    NULL, NULL, NULL,
    'Street-light power conversion completed by switching the required fuses',
    NULL,
    'Site-wide / Infrastructure task. Conversion is performed by switching fuses. Exact crew/time/resources remain to be verified.'
),
(
    'SITE-70',
    'Turn On Site Breakers',
    70, 70,
    NULL, NULL, NULL,
    'Required site breakers turned on for Setup/show power',
    NULL,
    'Site-wide / Infrastructure task. Exact crew/time/resources and any safety prerequisites remain to be verified.'
);

CREATE TEMP TABLE _site_map (
    seed_key text PRIMARY KEY,
    setup_task_id bigint NOT NULL
) ON COMMIT DROP;

DO $load$
DECLARE
    r record;
    v_task_id bigint;
BEGIN
    FOR r IN SELECT * FROM _site_task ORDER BY display_order LOOP
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
            NULL,
            NULL,
            'WORK',
            r.display_order,
            r.baseline_plan_order,
            r.normal_crew_min,
            r.normal_crew_max,
            r.expected_duration_minutes,
            r.completion_point,
            r.readiness_note,
            '[Site Infrastructure review seed ' || r.seed_key || '] ' || r.reusable_notes
        )
        RETURNING setup_task_id INTO v_task_id;

        INSERT INTO _site_map(seed_key, setup_task_id) VALUES (r.seed_key, v_task_id);
    END LOOP;
END
$load$;

/* Operational sequence explicitly established during review. */
INSERT INTO ref.setup_task_dependency(setup_task_id, prerequisite_setup_task_id, dependency_note)
SELECT current_task.setup_task_id, prior_task.setup_task_id, x.note
FROM (VALUES
    ('SITE-20','SITE-10','Command Center trailer setup precedes antenna installation.'),
    ('SITE-30','SITE-20','WiFi antenna installation precedes gateway/internet testing.'),
    ('SITE-40','SITE-30','Internet connectivity must be verified before hotspot deployment.')
) AS x(task_key, prerequisite_key, note)
JOIN _site_map current_task ON current_task.seed_key = x.task_key
JOIN _site_map prior_task ON prior_task.seed_key = x.prerequisite_key;

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
FROM _site_map m
JOIN ref.setup_resource r ON r.resource_name = 'Boom Lift'
WHERE m.seed_key = 'SITE-20';

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
    'Site-wide / Infrastructure work added from 2026 Manager review. Verify whether this task occurred in 2025 and correct the annual actual as needed.',
    t.baseline_plan_order
FROM ops.setup_session ss
CROSS JOIN _site_map m
JOIN ref.setup_task t ON t.setup_task_id = m.setup_task_id
WHERE ss.season_year = 2025;

/* Final browser-review usability: leave the connectivity chain incomplete/ready
   enough to exercise rolling planning and Captain completion in the disposable
   clone. This seed is not Production acceptance of 2025 execution state. */
UPDATE ops.setup_session_task st
   SET execution_status = CASE
       WHEN m.seed_key = 'SITE-10' THEN 'READY'
       ELSE 'NOT_READY'
   END,
       actual_completed_at = NULL,
       completed_by_person_id = NULL,
       completion_note = NULL
FROM _site_map m
JOIN ops.setup_session ss ON ss.season_year = 2025
WHERE st.setup_session_id = ss.setup_session_id
  AND st.setup_task_id = m.setup_task_id
  AND m.seed_key IN ('SITE-10','SITE-20','SITE-30','SITE-40');

COMMIT;

SELECT
    t.setup_task_id,
    t.task_name,
    t.stage_id,
    t.baseline_plan_order,
    st.planned_order,
    st.verification_state,
    st.execution_status
FROM ref.setup_task t
JOIN ops.setup_session_task st ON st.setup_task_id = t.setup_task_id
JOIN ops.setup_session ss ON ss.setup_session_id = st.setup_session_id
WHERE ss.season_year = 2025
  AND t.stage_id IS NULL
ORDER BY st.planned_order, t.setup_task_id;
