/* ============================================================================
MSB Setup Session — provisional 2025 historical-verification seed
Issues: #122, #126
Status: IMPLEMENTATION CANDIDATE — DO NOT APPLY BEFORE 001-003 ARE REVIEWED
Revision: 2026-09-06 V0.1.0

Purpose:
  Load the first shared Setup Session with the provisional 2025 reconstruction
  so Managers can verify/correct reusable tasks and 2025 actuals in the real UI.

Important:
  - This seed is deliberately PROVISIONAL, not historical truth.
  - Every annual row starts UNVERIFIED.
  - Missing Stages/tasks remain gaps; this script does not invent task work.
  - Current Display->Container truth is not copied or snapshotted here.
  - This is a guarded one-time bootstrap. It refuses to run if reusable Setup
    tasks or a 2025 Setup Session already exist.
============================================================================ */

BEGIN;

DO $preflight$
BEGIN
    IF to_regclass('ref.setup_task') IS NULL
       OR to_regclass('ref.setup_task_dependency') IS NULL
       OR to_regclass('ref.setup_resource') IS NULL
       OR to_regclass('ref.setup_task_resource') IS NULL
       OR to_regclass('ops.setup_session') IS NULL
       OR to_regclass('ops.setup_session_task') IS NULL THEN
        RAISE EXCEPTION 'Setup core migration 001 is required first';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM ref.season WHERE season_year = 2025) THEN
        RAISE EXCEPTION 'ref.season 2025 is required';
    END IF;

    IF EXISTS (SELECT 1 FROM ref.setup_task) THEN
        RAISE EXCEPTION 'ref.setup_task is not empty; refuse bootstrap seed';
    END IF;

    IF EXISTS (SELECT 1 FROM ops.setup_session WHERE season_year = 2025) THEN
        RAISE EXCEPTION '2025 Setup Session already exists; refuse duplicate seed';
    END IF;
END
$preflight$;

CREATE TEMP TABLE _setup_2025_seed_task (
    seed_key text PRIMARY KEY,
    stage_key text NOT NULL,
    task_name text NOT NULL,
    task_action_type text NOT NULL,
    display_order integer NOT NULL,
    normal_crew_min integer,
    normal_crew_max integer,
    expected_duration_minutes integer,
    completion_point text,
    readiness_note text,
    weather_note text,
    reusable_notes text
) ON COMMIT DROP;

INSERT INTO _setup_2025_seed_task VALUES
('FE-ARCH','01','Erect Front Entrance Arch','WORK',10,6,6,90,
 'Front Entrance arch is erected and secured for the next applicable Setup work.',
 NULL,NULL,
 'Field knowledge: about 6 people, about 1.5 hours, SkyTrak and one boom lift. Verify final task wording and completion point.'),

('MC-FRAME','03a','Install Mega Cube Frame and Panels','WORK',10,NULL,NULL,NULL,
 'Mega Cube frame and panels are installed and ready for controller/final hookup work.',NULL,NULL,
 'Representative reusable task reconstructed from Setup planning discussion; verify exact task boundary.'),
('MC-CONTROLLER','03a','Controller / Final Hookup','WORK',20,NULL,NULL,NULL,
 'Mega Cube controller/final hookup work is complete.',NULL,NULL,
 'Verify whether this is independently schedulable or belongs in the frame/panel task.'),

('OPS-FOOD','04','Arrange Volunteer Food','SUPPORT',10,NULL,NULL,NULL,
 'Volunteer food arrangements for the applicable Setup period are confirmed.',NULL,NULL,
 'Inventory-independent support task with Stage 04 general-area context.'),
('OPS-RENTALS','04','Arrange Rental Equipment','SUPPORT',20,NULL,NULL,NULL,
 'Required rental equipment and availability are confirmed.',NULL,NULL,
 'Inventory-independent support task with Stage 04 general-area context.'),
('OPS-VOLTRAILER','04','Position Volunteer Trailer','SUPPORT',30,NULL,NULL,NULL,
 'Volunteer Trailer is positioned in the intended Stage 04 general area.',NULL,NULL,
 'Inventory-independent support task with field context.'),
('FC-UNLOAD','04','Unload Food Collection','UNLOAD_CONTAINER',40,NULL,NULL,NULL,
 'Expected Food Collection Displays are unloaded at Food Collection; other Display groups remain with Container 34.',NULL,NULL,
 'Reusable mixed-load movement task for Container 34; expected group count from current evidence is 8 Displays.'),
('FC-ARCHES','04','Install Food Collection Arches','WORK',50,NULL,NULL,NULL,
 'Food Collection arches are installed in their intended field positions.',NULL,NULL,
 'Late-season timing may apply; verify exact date window and relationship to traffic-lane work.'),
('FC-TRAFFIC','04','Set Food Collection Traffic Lanes','WORK',60,NULL,NULL,NULL,
 'Food Collection traffic lanes are configured for the intended event flow.',
 'Intentionally delayed until near VIP night.',NULL,
 'Verify exact reusable date/window guidance.'),

('WH-SCAFFOLD','07','Set Whoville Scaffold','WORK',10,NULL,NULL,NULL,
 'Required Whoville scaffold is positioned and ready for dependent work.',NULL,NULL,
 'Verify exact relationship to Mt Crumpit and other Whoville work.'),
('WH-CRUMPIT','07','Install Mt Crumpit Panels','WORK',20,NULL,NULL,NULL,
 'Mt Crumpit panels are installed.',NULL,NULL,'Provisional task boundary.'),
('WH-SPIRAL','07','Install Who Spiral Tree and Star','WORK',30,NULL,NULL,NULL,
 'Who Spiral Tree and Star are installed.',NULL,NULL,'Provisional task boundary.'),
('WH-CHARACTERS','07','Place Whoville Characters','WORK',40,NULL,NULL,NULL,
 'Whoville character Displays are placed in their intended field locations.',NULL,NULL,'Provisional reusable task.'),
('WH-WHOHOUSE','07','Build / Finish Who House on Arch Trailer','WORK',50,NULL,NULL,NULL,
 'Arch Trailer is empty and in Whoville, and the Who House is built/finished on the trailer base.',NULL,NULL,
 'Container 34 becomes the Who House base only after its cargo is unloaded. Who House material is stored elsewhere and must not be assigned to Container 34.'),

('EC-SCAFFOLD','08','Set Scaffold and Elves','WORK',10,NULL,NULL,NULL,
 'Elf Choir scaffold and elf Displays are installed.',NULL,NULL,
 'Verify final wording and whether scaffold and elves remain one practical task.'),
('EC-NOTES','08','Install Notes and Conductor','WORK',20,NULL,NULL,NULL,
 'Notes and conductor Displays are installed.',NULL,NULL,'Provisional reusable task.'),

('ST-UNLOAD','10','Unload Stars','UNLOAD_CONTAINER',10,NULL,NULL,NULL,
 'The 24 expected Star Displays are unloaded at Stars; other Display groups remain with Container 34.',NULL,NULL,
 'Reusable mixed-load movement task for Container 34.'),
('ST-HARNESS','10','Install Star Harness','WORK',20,NULL,NULL,NULL,
 'Star harness is installed and ready for the 24 stars.',NULL,NULL,'Provisional task boundary.'),
('ST-HANG','10','Put Up 24 Stars','WORK',30,NULL,NULL,NULL,
 'All 24 Star Stage stars are installed.',NULL,NULL,
 'All 24 stars are carried on Container 34 during transport.'),

('IT-UNLOAD','14','Unload Icicle Tunnel','UNLOAD_CONTAINER',10,NULL,NULL,NULL,
 'The 36 expected Icicle Tunnel Displays are unloaded at Icicle Tunnel; other Display groups remain with Container 34.',NULL,NULL,
 'Reusable mixed-load movement task for Container 34.'),
('IT-INSTALL','14','Install Icicle Tunnel','WORK',20,NULL,NULL,NULL,
 'Icicle Tunnel Display group is installed.',NULL,NULL,'Provisional reusable task after bulk unload.'),

('CL-UNLOAD','17','Unload Candyland','UNLOAD_CONTAINER',10,NULL,NULL,NULL,
 'The 2 expected Candyland arch Displays are unloaded at Candyland; other Display groups remain with Container 34.',NULL,NULL,
 'Reusable mixed-load movement task for Container 34.'),
('CL-ARCH','17','Install Candyland Arch and Pinwheels','WORK',20,NULL,NULL,NULL,
 'Candyland arch and pinwheels are installed.',NULL,NULL,'Provisional reusable task.'),
('CL-LOLLIPOP','17','Position Lollipop Trailer','WORK',30,NULL,NULL,NULL,
 'Lollipop Trailer is positioned in Candyland.',NULL,NULL,'Verify exact task/material relationship.'),
('CL-BENCHES','17','Set Tree Benches','WORK',40,NULL,NULL,NULL,
 'Candyland tree benches are placed.',NULL,NULL,'Provisional reusable task.'),
('CL-GINGERBREAD','17','Install Gingerbread House and Panels','WORK',50,NULL,NULL,NULL,
 'Gingerbread House and panels are installed.',NULL,NULL,'Provisional reusable task.'),
('CL-CANES','17','Install Candy Canes','WORK',60,NULL,NULL,NULL,
 'Candy cane Displays are installed.',NULL,NULL,'Provisional reusable task.'),

('PB-UNLOAD','21','Unload Polar Bear Playground','UNLOAD_CONTAINER',10,NULL,NULL,NULL,
 'The 3 expected Polar Bear Playground arch Displays are unloaded; other Display groups remain with Container 34.',NULL,NULL,
 'Reusable mixed-load movement task for Container 34.'),
('PB-THROW','21','Install Throwing Bears and Arch','WORK',20,NULL,NULL,NULL,
 'Throwing Bears and Polar Bear arch are installed.',NULL,NULL,'Provisional reusable task.'),
('PB-IGLOOS','21','Install Polar Bear Igloos','WORK',30,NULL,NULL,NULL,
 'Polar Bear igloos are installed.',NULL,NULL,'Provisional reusable task.'),
('PB-PANELS','21','Install Polar Bear Panels','WORK',40,NULL,NULL,NULL,
 'Polar Bear Playground panels are installed.',NULL,NULL,'Provisional reusable task.'),

('RA-UNLOAD','25','Unload Racing Arches','UNLOAD_CONTAINER',10,NULL,NULL,NULL,
 'The 48 expected Racing Arches Displays are unloaded at Racing Arches; other Display groups remain with Container 34.',NULL,NULL,
 'Reusable mixed-load movement task for Container 34.'),
('RA-HARNESS','25','Install Racing Arch Harness','WORK',20,NULL,NULL,NULL,
 'Racing Arch harness/support is installed and ready for arches.',NULL,NULL,'Provisional reusable task.'),
('RA-ARCHES','25','Install Racing Arches','WORK',30,NULL,NULL,NULL,
 'Racing Arches are installed.',NULL,NULL,'Provisional reusable task after harness/support work.'),

('MI-LOCATES','26','Locates / Field Cleared','WORK',5,NULL,NULL,NULL,
 'Required field locates/clearance for Magic Igloo work are complete.',NULL,NULL,
 'Beginning readiness task; technical locating remains owned by the applicable site/GIS process.'),
('MI-FRAME','26','Layout / Erect Frame / Strap Down','WORK',10,8,10,240,
 'Magic Igloo structure is laid out, erected, secured, and ready for skins.',NULL,NULL,
 'Reusable definition reconstructed from field knowledge; verify wording, crew, equipment, and exact completion point.'),
('MI-SKINS','26','Install Skins and Bungees','WORK',20,4,6,360,
 'Skins and required bungees are installed and the enclosure is ready for finish work.',NULL,
 'Warm weather preferred because skins are easier to handle.',
 'Verify whether bungees remain in this same practical task.'),
('MI-FINISH','26','Install Lighting, Cameras, Mats, Signs, and Finish Setup','WORK',30,2,3,NULL,
 'Lighting, security cameras, mats, signs, and other reviewed finish items are installed and the area is operationally ready.',NULL,NULL,
 'May need to split if lighting/cameras and mats/signs prove independently schedulable.'),
('MI-POWER','26','Plug In / Power Up / Test','WORK',40,NULL,NULL,NULL,
 'Magic Igloo applicable installed work is powered/tested and verified ready.',
 'Power-up eligibility is task-specific; exact grass-cutting/readiness rule still requires leader review.',NULL,
 'Provisional reusable task.'),

('CMD-DELIVER','40','Deliver Command Center','SUPPORT',10,NULL,NULL,NULL,
 'Command Center is delivered to its Stage 40 field context.',NULL,NULL,
 'Inventory-independent support/placement task with Stage 40 context.');

DO $stage_gate$
DECLARE
    v_missing text;
BEGIN
    SELECT string_agg(DISTINCT s.stage_key, ', ' ORDER BY s.stage_key)
      INTO v_missing
    FROM _setup_2025_seed_task AS s
    LEFT JOIN ref.stage AS r ON r.stage_key = s.stage_key
    WHERE r.stage_id IS NULL;

    IF v_missing IS NOT NULL THEN
        RAISE EXCEPTION 'Seed Stage keys are missing from ref.stage: %', v_missing;
    END IF;
END
$stage_gate$;

CREATE TEMP TABLE _setup_2025_task_map (
    seed_key text PRIMARY KEY,
    setup_task_id bigint NOT NULL
) ON COMMIT DROP;

DO $load_tasks$
DECLARE
    r record;
    v_setup_task_id bigint;
BEGIN
    FOR r IN SELECT * FROM _setup_2025_seed_task ORDER BY stage_key, display_order, seed_key LOOP
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
            weather_note,
            reusable_notes
        )
        SELECT
            r.task_name,
            s.stage_id,
            r.task_action_type,
            r.display_order,
            r.normal_crew_min,
            r.normal_crew_max,
            r.expected_duration_minutes,
            r.completion_point,
            r.readiness_note,
            r.weather_note,
            '[2025 provisional reconstruction ' || r.seed_key || '] ' || coalesce(r.reusable_notes, '')
        FROM ref.stage AS s
        WHERE s.stage_key = r.stage_key
        RETURNING setup_task_id INTO v_setup_task_id;

        INSERT INTO _setup_2025_task_map(seed_key, setup_task_id)
        VALUES (r.seed_key, v_setup_task_id);
    END LOOP;
END
$load_tasks$;

CREATE TEMP TABLE _setup_2025_seed_dependency (
    task_key text NOT NULL,
    prerequisite_key text NOT NULL,
    PRIMARY KEY (task_key, prerequisite_key)
) ON COMMIT DROP;

INSERT INTO _setup_2025_seed_dependency VALUES
('MC-CONTROLLER','MC-FRAME'),
('FC-ARCHES','FC-UNLOAD'),
('WH-CRUMPIT','WH-SCAFFOLD'),
('WH-WHOHOUSE','RA-UNLOAD'),
('WH-WHOHOUSE','PB-UNLOAD'),
('WH-WHOHOUSE','IT-UNLOAD'),
('WH-WHOHOUSE','ST-UNLOAD'),
('WH-WHOHOUSE','CL-UNLOAD'),
('WH-WHOHOUSE','FC-UNLOAD'),
('EC-NOTES','EC-SCAFFOLD'),
('ST-HARNESS','ST-UNLOAD'),
('ST-HANG','ST-HARNESS'),
('IT-INSTALL','IT-UNLOAD'),
('CL-ARCH','CL-UNLOAD'),
('PB-THROW','PB-UNLOAD'),
('RA-HARNESS','RA-UNLOAD'),
('RA-ARCHES','RA-HARNESS'),
('MI-FRAME','MI-LOCATES'),
('MI-SKINS','MI-FRAME'),
('MI-FINISH','MI-SKINS'),
('MI-POWER','MI-FINISH');

INSERT INTO ref.setup_task_dependency (
    setup_task_id,
    prerequisite_setup_task_id,
    dependency_note
)
SELECT
    task_map.setup_task_id,
    prerequisite_map.setup_task_id,
    'Provisional 2025 reconstruction dependency; verify in Manager UI.'
FROM _setup_2025_seed_dependency AS d
JOIN _setup_2025_task_map AS task_map ON task_map.seed_key = d.task_key
JOIN _setup_2025_task_map AS prerequisite_map
  ON prerequisite_map.seed_key = d.prerequisite_key;

/* Small resource catalog only where current field knowledge is already useful. */
INSERT INTO ref.setup_resource(resource_name, resource_type, notes) VALUES
('SkyTrak','EQUIPMENT','Reusable Setup resource; seeded from current field knowledge.'),
('Boom Lift','EQUIPMENT','Reusable Setup resource; quantity is task-specific.'),
('Tool Cat','EQUIPMENT','Reusable Setup resource; availability is annual/day-specific.'),
('Truck','VEHICLE','Reusable Setup resource; exact task relationships require review.'),
('Trailer','TRAILER','Generic planning resource; physical Containers/trailers remain separate permanent identities.')
ON CONFLICT (resource_name) DO NOTHING;

INSERT INTO ref.setup_task_resource (
    setup_task_id,
    setup_resource_id,
    quantity_required,
    requirement_type,
    notes
)
SELECT m.setup_task_id, r.setup_resource_id, x.quantity_required, 'REQUIRED',
       'Seeded from current field knowledge; verify during 2025 review.'
FROM (VALUES
    ('FE-ARCH','SkyTrak',1),
    ('FE-ARCH','Boom Lift',1),
    ('MI-FRAME','SkyTrak',1),
    ('MI-FRAME','Boom Lift',1),
    ('MI-SKINS','Boom Lift',1),
    ('MI-FINISH','Boom Lift',1)
) AS x(task_key, resource_name, quantity_required)
JOIN _setup_2025_task_map AS m ON m.seed_key = x.task_key
JOIN ref.setup_resource AS r ON r.resource_name = x.resource_name;

/* Container 34 is a reviewed reusable support relationship for the six unload
   tasks and later becomes the Who House base. Exact Display links are left for
   the current Production DB material-resolution pass rather than guessed here. */
INSERT INTO ref.setup_task_container_support (
    setup_task_id,
    container_id,
    relationship_type,
    notes
)
SELECT
    m.setup_task_id,
    34,
    CASE WHEN m.seed_key = 'WH-WHOHOUSE' THEN 'SUPPORT' ELSE 'REQUIRED_CONTAINER' END,
    CASE WHEN m.seed_key = 'WH-WHOHOUSE'
         THEN 'Arch Trailer becomes the Who House base after its reviewed cargo is unloaded.'
         ELSE 'Mixed-load Arch Trailer; task unloads only its reviewed Display group.'
    END
FROM _setup_2025_task_map AS m
WHERE m.seed_key IN (
    'FC-UNLOAD','ST-UNLOAD','IT-UNLOAD','CL-UNLOAD','PB-UNLOAD','RA-UNLOAD','WH-WHOHOUSE'
);

INSERT INTO ops.setup_session (
    season_year,
    session_status,
    notes
) VALUES (
    2025,
    'HISTORICAL_VERIFICATION',
    'Provisional reconstruction loaded for Manager verification. 2026 Setup Session is created only after reusable-task verification is sufficiently complete.'
);

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
    '2025 historical occurrence is provisional. Verify actual date(s), crew, duration, notes, task boundary, and reusable knowledge in the Manager UI.'
FROM ops.setup_session AS ss
CROSS JOIN _setup_2025_task_map AS m
WHERE ss.season_year = 2025;

COMMIT;

/* Read-only immediate evidence. */
SELECT
    ss.season_year,
    ss.session_status,
    count(*) AS seeded_session_tasks,
    count(*) FILTER (WHERE sst.verification_state = 'UNVERIFIED') AS unverified
FROM ops.setup_session AS ss
JOIN ops.setup_session_task AS sst
  ON sst.setup_session_id = ss.setup_session_id
WHERE ss.season_year = 2025
GROUP BY ss.season_year, ss.session_status;
