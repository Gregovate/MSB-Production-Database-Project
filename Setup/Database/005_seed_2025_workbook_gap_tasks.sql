/* ============================================================================
MSB Setup Session — 2025 workbook-gap seed
Issues: #122, #126
Status: IMPLEMENTATION CANDIDATE — DO NOT APPLY BEFORE 001-004 ARE REVIEWED
Revision: 2026-09-06 V0.1.0

Purpose:
  Add current Working/Candidate task definitions present in the controlled
  reconstruction workbook but omitted from the original UI-oriented 004 seed.

Source:
  MSB_Setup_Task_Reconstruction_Working_Basis_Controlled_Stage_Lookup_v2
  Task List current Working/Candidate section.

Important:
  - These rows are provisional reusable definitions, not verified 2025 truth.
  - Their 2025 annual rows start UNVERIFIED.
  - Historical-evidence rows are not imported by this script.
  - Existing tasks are not renamed or replaced here; 2025 Manager verification
    remains the place to combine/split/correct task boundaries.
============================================================================ */

BEGIN;

DO $preflight$
DECLARE
    v_session_id bigint;
BEGIN
    IF to_regclass('ref.setup_task') IS NULL
       OR to_regclass('ref.setup_task_dependency') IS NULL
       OR to_regclass('ref.setup_resource') IS NULL
       OR to_regclass('ref.setup_task_resource') IS NULL
       OR to_regclass('ops.setup_session') IS NULL
       OR to_regclass('ops.setup_session_task') IS NULL THEN
        RAISE EXCEPTION 'Setup core migration 001 is required first';
    END IF;

    SELECT setup_session_id INTO v_session_id
    FROM ops.setup_session
    WHERE season_year = 2025;

    IF v_session_id IS NULL THEN
        RAISE EXCEPTION '2025 Setup Session seed 004 is required first';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM ref.setup_task t
        JOIN ref.stage s ON s.stage_id = t.stage_id
        WHERE (s.stage_key = '04' AND t.task_name = 'Perimeter / Bracket Work')
           OR (s.stage_key = '05' AND t.task_name = 'Individual Tree Wrap Tasks')
           OR (s.stage_key = '02' AND t.task_name IN (
                'Prepare / Load Light Strings',
                'Erect / Position Mega Tree Structure',
                'Hang and Secure Light Strings',
                'Complete Electrical / Network Connections'
           ))
    ) THEN
        RAISE EXCEPTION 'One or more workbook-gap Setup tasks already exist; refuse duplicate seed';
    END IF;
END
$preflight$;

CREATE TEMP TABLE _setup_2025_gap_task (
    seed_key text PRIMARY KEY,
    stage_key text NOT NULL,
    task_name text NOT NULL,
    display_order integer NOT NULL,
    normal_crew_min integer,
    normal_crew_max integer,
    expected_duration_minutes integer,
    completion_point text,
    readiness_note text,
    reusable_notes text
) ON COMMIT DROP;

INSERT INTO _setup_2025_gap_task VALUES
(
    'FC-01', '04', 'Perimeter / Bracket Work', 25,
    NULL, NULL, NULL,
    'Perimeter/bracket work complete',
    'Earlier Setup window',
    'Workbook key FC-01; Candidate. Established phased-work example: can be done earlier than traffic-lane work. Physical scope: only assets required for perimeter/bracket phase. Crew, captain, time, equipment, and exact assets require verification.'
),
(
    'TW-01', '05', 'Individual Tree Wrap Tasks', 10,
    NULL, NULL, NULL,
    'Assigned tree wrap complete',
    NULL,
    'Workbook key TW-01; Candidate. Many tree-wrap tasks are independent and can run in parallel; captain and volunteer count are the main planning constraints. Final task granularity, crew sizing, time, equipment, and material mapping require verification.'
),
(
    'MT-01', '02', 'Prepare / Load Light Strings', 10,
    NULL, 4, 120,
    'Light strings loaded and secured for transport',
    'Day before or morning of installation',
    'Workbook key MT-01; Candidate from Procedure. Current Mega Tree procedure recommends 4 people when preparing lights and says loading takes about 2 hours. Evidence mentions one lift for loading and a light-transport trailer. Physical scope: 48 light strings / transport load.'
),
(
    'MT-02', '02', 'Erect / Position Mega Tree Structure', 20,
    2, 3, NULL,
    'Trailer/mast/ball/rings structurally ready',
    NULL,
    'Workbook key MT-02; Candidate from Procedure. Procedure evidence indicates 2 people, maybe 3 when securing the Mega Ball, and SkyTrak plus one lift. Physical scope: Mega Tree trailer, mast, ball, rings, outriggers. Elapsed time and current asset mapping require verification.'
),
(
    'MT-03', '02', 'Hang and Secure Light Strings', 30,
    5, 6, NULL,
    'All light strings hung and secured',
    'Lights brought to park the day they are installed',
    'Workbook key MT-03; Candidate from Procedure. Procedure recommends 5-6 people and two lifts when hanging the 48 light strings. Captain, elapsed time, and current asset mapping require verification.'
),
(
    'MT-04', '02', 'Complete Electrical / Network Connections', 40,
    NULL, NULL, NULL,
    'Power/network/controller connections complete',
    NULL,
    'Workbook key MT-04; Candidate from Procedure. Current Mega Tree procedure ends with controller, network, and power connection steps. Crew, captain, time, equipment, and exact asset mapping require verification.'
);

CREATE TEMP TABLE _setup_2025_gap_map (
    seed_key text PRIMARY KEY,
    setup_task_id bigint NOT NULL
) ON COMMIT DROP;

DO $load$
DECLARE
    r record;
    v_task_id bigint;
BEGIN
    FOR r IN
        SELECT * FROM _setup_2025_gap_task
        ORDER BY stage_key, display_order, seed_key
    LOOP
        INSERT INTO ref.setup_task (
            task_name,
            stage_id,
            task_action_type,
            display_order,
            normal_crew_min,
            normal_crew_max,
            expected_duration_minutes,
            completion_point,
            readiness_note,
            reusable_notes
        )
        SELECT
            r.task_name,
            s.stage_id,
            'WORK',
            r.display_order,
            r.normal_crew_min,
            r.normal_crew_max,
            r.expected_duration_minutes,
            r.completion_point,
            r.readiness_note,
            '[2025 controlled workbook gap ' || r.seed_key || '] ' || r.reusable_notes
        FROM ref.stage s
        WHERE s.stage_key = r.stage_key
        RETURNING setup_task_id INTO v_task_id;

        IF v_task_id IS NULL THEN
            RAISE EXCEPTION 'Stage key % did not resolve for seed %', r.stage_key, r.seed_key;
        END IF;

        INSERT INTO _setup_2025_gap_map(seed_key, setup_task_id)
        VALUES (r.seed_key, v_task_id);
    END LOOP;
END
$load$;

INSERT INTO ref.setup_task_dependency (
    setup_task_id,
    prerequisite_setup_task_id,
    dependency_note
)
SELECT final_task.setup_task_id, prior_task.setup_task_id,
       'Workbook prerequisite MT-03 complete as applicable; verify during 2025 review.'
FROM _setup_2025_gap_map final_task
JOIN _setup_2025_gap_map prior_task ON prior_task.seed_key = 'MT-03'
WHERE final_task.seed_key = 'MT-04';

/* Reuse the small normalized resource catalog created by 004. Raw workbook
   equipment wording remains preserved in reusable_notes. */
INSERT INTO ref.setup_task_resource (
    setup_task_id,
    setup_resource_id,
    quantity_required,
    requirement_type,
    notes
)
SELECT m.setup_task_id, r.setup_resource_id, x.quantity_required, 'REQUIRED',
       'Seeded from controlled workbook Procedure evidence; verify during 2025 review.'
FROM (VALUES
    ('MT-01','Boom Lift',1),
    ('MT-02','SkyTrak',1),
    ('MT-02','Boom Lift',1),
    ('MT-03','Boom Lift',2)
) AS x(task_key, resource_name, quantity_required)
JOIN _setup_2025_gap_map m ON m.seed_key = x.task_key
JOIN ref.setup_resource r ON r.resource_name = x.resource_name;

INSERT INTO ops.setup_session_task (
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
    'Loaded from the controlled current Working/Candidate workbook section for 2025 historical verification. Verify task boundary and actual 2025 date(s), crew, duration, and notes.'
FROM ops.setup_session ss
CROSS JOIN _setup_2025_gap_map m
WHERE ss.season_year = 2025;

COMMIT;

SELECT
    ss.season_year,
    count(*) AS total_2025_session_tasks,
    count(*) FILTER (WHERE sst.verification_state = 'UNVERIFIED') AS unverified
FROM ops.setup_session ss
JOIN ops.setup_session_task sst
  ON sst.setup_session_id = ss.setup_session_id
WHERE ss.season_year = 2025
GROUP BY ss.season_year;
