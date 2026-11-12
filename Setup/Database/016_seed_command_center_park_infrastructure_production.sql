/* ============================================================================
MSB Setup Session — Production-safe Command Center + Park Infrastructure seed
Issue: #122
Status: PRODUCTION CANDIDATE — REVIEW BEFORE APPLY
Revision: 2026-09-07 V0.3.3

Purpose:
  Promote the durable Setup work established during Manager review without any
  disposable-preview execution resets or fake scheduling data.

Scope boundary:
  - Stage 40 Command Center owns Command Center / connectivity Setup work.
  - Site-wide / Park Infrastructure owns only work with no appropriate LOR
    Stage/Scene owner.

2025 historical rule:
  The annual 2025 occurrences are inserted as UNVERIFIED and COMPLETE. This
  matches the existing historical-verification convention: the work is known to
  belong in the 2025 review set, but crew/time/date evidence remains subject to
  Manager verification.

2026 rule:
  This migration creates no 2026 Setup Session and no 2026 annual rows.
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
        RAISE EXCEPTION '2025 Setup Session is required';
    END IF;

    IF EXISTS (SELECT 1 FROM ops.setup_session WHERE season_year = 2026) THEN
        RAISE EXCEPTION '2026 Setup Session already exists; this production seed must be reviewed before continuing';
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
        RAISE EXCEPTION 'One or more Command Center / Park Infrastructure tasks already exist; refuse duplicate seed';
    END IF;
END
$preflight$;

CREATE TEMP TABLE _setup_prod_task (
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

INSERT INTO _setup_prod_task VALUES
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

CREATE TEMP TABLE _setup_prod_map (
    seed_key text PRIMARY KEY,
    setup_task_id bigint NOT NULL
) ON COMMIT DROP;

DO $load$
DECLARE
    r record;
    v_task_id bigint;
    v_stage_id integer;
BEGIN
    FOR r IN SELECT * FROM _setup_prod_task ORDER BY baseline_plan_order, seed_key LOOP
        v_stage_id := NULL;
        IF r.stage_key IS NOT NULL THEN
            SELECT stage_id INTO v_stage_id
            FROM ref.stage
            WHERE stage_key = r.stage_key;
            IF v_stage_id IS NULL THEN
                RAISE EXCEPTION 'Stage key % did not resolve for seed %', r.stage_key, r.seed_key;
            END IF;
        END IF;

        INSERT INTO ref.setup_task(
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
            '[Production reconstruction ' || r.seed_key || '] ' || r.reusable_notes
        )
        RETURNING ref.setup_task.setup_task_id INTO v_task_id;

        INSERT INTO _setup_prod_map(seed_key, setup_task_id)
        VALUES (r.seed_key, v_task_id);
    END LOOP;
END
$load$;

INSERT INTO ref.setup_task_dependency(setup_task_id, prerequisite_setup_task_id, dependency_note)
SELECT current_task.setup_task_id, prior_task.setup_task_id, x.note
FROM (VALUES
    ('CC-20','CC-10','Command Center trailer setup precedes antenna installation.'),
    ('CC-30','CC-20','WiFi antenna installation precedes gateway/internet testing.'),
    ('CC-40','CC-30','Internet connectivity must be verified before hotspot deployment.')
) AS x(task_key, prerequisite_key, note)
JOIN _setup_prod_map current_task ON current_task.seed_key = x.task_key
JOIN _setup_prod_map prior_task ON prior_task.seed_key = x.prerequisite_key;

INSERT INTO ref.setup_task_resource(
    setup_task_id,
    setup_resource_id,
    quantity_required,
    requirement_type,
    notes
)
SELECT m.setup_task_id, r.setup_resource_id, 1, 'REQUIRED',
       'One Boom Lift established during Manager review for WiFi antenna installation.'
FROM _setup_prod_map m
JOIN ref.setup_resource r ON r.resource_name = 'Boom Lift'
WHERE m.seed_key = 'CC-20';

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
            'Park Infrastructure work added from 2026 Manager reconstruction. Verify 2025 crew/time/date evidence and correct the annual actual as needed.'
        ELSE
            'Stage 40 Command Center work added from 2026 Manager reconstruction. Verify 2025 crew/time/date evidence and correct the annual actual as needed.'
    END,
    t.baseline_plan_order
FROM ops.setup_session ss
CROSS JOIN _setup_prod_map m
JOIN ref.setup_task t ON t.setup_task_id = m.setup_task_id
WHERE ss.season_year = 2025;

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
  AND t.reusable_notes LIKE '[Production reconstruction %'
ORDER BY st.planned_order, t.setup_task_id;
