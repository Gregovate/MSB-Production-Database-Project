\set ON_ERROR_STOP on
-- #445 disposable-only data correction candidate. NOT a Production migration.
-- Explicit clone guard prevents accidental Production execution.
BEGIN;
DO $gate$
DECLARE v_session bigint;
BEGIN
 IF current_database() !~* '(disposable|clone|preview|acceptance)' THEN
   RAISE EXCEPTION '#445 STOP: run only on named disposable PostgreSQL clone; database=%',current_database();
 END IF;
 IF (SELECT count(*) FROM ops.setup_session WHERE season_year=2026) <> 1 THEN
   RAISE EXCEPTION '#445 STOP: expected exactly one 2026 season';
 END IF;
 IF (SELECT count(*) FROM ref.setup_task WHERE setup_task_id IN (17,20,32,126,306) AND active_flag) <> 5 THEN
   RAISE EXCEPTION '#445 STOP: five redundant Catalog tasks must still be active';
 END IF;
 IF NOT EXISTS (SELECT 1 FROM ref.setup_task WHERE setup_task_id=122 AND active_flag
                AND task_name='Unload Arch Trailer') THEN
   RAISE EXCEPTION '#445 STOP: shared Arch trailer task #122 mismatch';
 END IF;
 IF NOT EXISTS (SELECT 1 FROM ref.setup_task WHERE setup_task_id=387 AND active_flag
                AND task_name ILIKE '%Drop Off Antenna Trailer%') THEN
   RAISE EXCEPTION '#445 STOP: standalone #387 trailer drop-off task mismatch';
 END IF;
 IF EXISTS (SELECT 1 FROM ref.setup_task WHERE task_name='Unload Antenna Trailer') THEN
   RAISE EXCEPTION '#445 STOP: Antenna unload already exists; no duplicate creation';
 END IF;
 IF (SELECT count(*) FROM ref.setup_task_container_support WHERE setup_task_id=20
    AND relationship_type='REQUIRED_CONTAINER') <> 1 OR
    (SELECT count(*) FROM ref.setup_task_container_support WHERE setup_task_id=32
    AND relationship_type='REQUIRED_CONTAINER') <> 1 OR
    (SELECT count(*) FROM ref.setup_task_display WHERE setup_task_id=32 AND display_id BETWEEN 785 AND 832) <> 48 OR
    EXISTS (SELECT 1 FROM ref.setup_task_display WHERE setup_task_id=32 AND display_id NOT BETWEEN 785 AND 832) THEN
    RAISE EXCEPTION '#445 STOP: required container / 48 Racing displays differ from recorded evidence';
 END IF;
 IF (SELECT container_id FROM ref.setup_task_container_support WHERE setup_task_id=20
      AND relationship_type='REQUIRED_CONTAINER') IS DISTINCT FROM
    (SELECT container_id FROM ref.setup_task_container_support WHERE setup_task_id=32
      AND relationship_type='REQUIRED_CONTAINER') THEN
   RAISE EXCEPTION '#445 STOP: C034 relationship mismatch';
 END IF;
 IF NOT EXISTS(SELECT 1 FROM ref.setup_task_container_support WHERE setup_task_id=19
                AND relationship_type='REQUIRED_CONTAINER'
                AND container_id=(SELECT container_id FROM ref.setup_task_container_support
                                  WHERE setup_task_id=20 AND relationship_type='REQUIRED_CONTAINER'))
 OR EXISTS(SELECT 1 FROM ref.setup_task_container_support WHERE setup_task_id=17) THEN
   RAISE EXCEPTION '#445 STOP: Greg''s manual C034 #17 to #19 reassignment differs';
 END IF;
 IF EXISTS (SELECT 1 FROM ops.setup_session_task st JOIN ops.setup_session ss USING(setup_session_id)
            WHERE ss.season_year=2025 AND st.setup_task_id IN (17,20,32,126,306)
            AND st.included_flag IS FALSE) THEN
   RAISE EXCEPTION '#445 STOP: unexpected prior historical state; review first';
 END IF;
END $gate$;

-- Installation owns inventory; never delete requirements.
INSERT INTO ref.setup_task_container_support(setup_task_id,container_id,relationship_type,notes)
SELECT CASE WHEN src.setup_task_id=20 THEN 21 ELSE 34 END,
       src.container_id,src.relationship_type,
       coalesce(src.notes,'') || ' [#445 reassigned from redundant unload #' || src.setup_task_id || ']'
FROM ref.setup_task_container_support src
WHERE src.setup_task_id IN (20,32)
ON CONFLICT ON CONSTRAINT pk_setup_task_container_support DO NOTHING;

INSERT INTO ref.setup_task_display(setup_task_id,display_id,relationship_type,notes)
SELECT 34,src.display_id,src.relationship_type,
       coalesce(src.notes,'') || ' [#445 Racing installation from redundant unload #32]'
FROM ref.setup_task_display src WHERE src.setup_task_id=32
ON CONFLICT ON CONSTRAINT pk_setup_task_display DO NOTHING;

-- Fail closed if existing installation ownership conflicts with source semantics.
DO $verify$
BEGIN
 IF EXISTS (
 SELECT 1 FROM ref.setup_task_container_support s
 JOIN ref.setup_task_container_support d ON d.container_id=s.container_id
 WHERE s.setup_task_id IN (20,32)
 AND d.setup_task_id=CASE WHEN s.setup_task_id=20 THEN 21 ELSE 34 END
 AND d.relationship_type IS DISTINCT FROM s.relationship_type) THEN
  RAISE EXCEPTION '#445 STOP: conflicting installation container relationships';
 END IF;
 IF EXISTS (SELECT 1 FROM ref.setup_task_display s JOIN ref.setup_task_display d
 ON d.display_id=s.display_id AND d.setup_task_id=34
 WHERE s.setup_task_id=32 AND d.relationship_type IS DISTINCT FROM s.relationship_type) THEN
  RAISE EXCEPTION '#445 STOP: conflicting Racing display relationships';
 END IF;
END $verify$;

-- One reusable Antenna unload, deliberately separate from #86 setup and #387 drop-off.
CREATE TEMP TABLE msb445_new_task (id bigint) ON COMMIT DROP;
WITH inserted AS (
 INSERT INTO ref.setup_task(task_name,task_action_type,display_order,active_flag,
 normal_crew_min,normal_crew_max,reusable_notes)
 VALUES ('Unload Antenna Trailer','UNLOAD_CONTAINER',100,true,7,7,
 '#445: one Stage-to-Stage delivery/unload run; scan at each stage; separate from #387 parking drop-off')
 RETURNING setup_task_id
) INSERT INTO msb445_new_task SELECT setup_task_id FROM inserted;

-- Change only affected reusable prerequisites, leaving unrelated prerequisites intact.
DELETE FROM ref.setup_task_dependency WHERE
 (setup_task_id=29 AND prerequisite_setup_task_id=126) OR
 (setup_task_id=34 AND prerequisite_setup_task_id=32) OR
 (setup_task_id=213 AND prerequisite_setup_task_id=306) OR
 prerequisite_setup_task_id IN (17,20,32,126,306);
INSERT INTO ref.setup_task_dependency(setup_task_id,prerequisite_setup_task_id,dependency_note)
VALUES (18,122,'#445 shared Arch trailer unload'),
       (21,122,'#445 shared Arch trailer unload'),
       (29,122,'#445 shared Arch trailer unload'),
       (34,122,'#445 shared Arch trailer unload'),
       (34,33,'#445 preserve Racing Harness prerequisite')
ON CONFLICT ON CONSTRAINT pk_setup_task_dependency DO NOTHING;
INSERT INTO ref.setup_task_dependency(setup_task_id,prerequisite_setup_task_id,dependency_note)
SELECT 213,id,'#445 Stage-to-Stage Antenna trailer unload'
FROM msb445_new_task
ON CONFLICT ON CONSTRAINT pk_setup_task_dependency DO NOTHING;

-- Retire only Catalog visibility; preserve original definitions and material/history.
UPDATE ref.setup_task SET active_flag=false, updated_at=now(),
 reusable_notes=concat_ws(E'\n',nullif(reusable_notes,''),'Retired from future planning by #445; existing 2026 work evidence preserved.')
WHERE setup_task_id IN (17,20,32,126,306);

-- Add the single new annual unloading task in the existing 2026 season.
INSERT INTO ops.setup_session_task(setup_session_id,setup_task_id,included_flag,
 execution_status,annual_notes)
SELECT ss.setup_session_id,n.id,true,'NOT_READY',
 '#445: one trailer crew and Stage-to-Stage unload; no inferred completed work.'
FROM ops.setup_session ss CROSS JOIN msb445_new_task n WHERE ss.season_year=2026;

-- Rewrite 2026 edges directly, without overwriting historical 2025 dependencies.
DELETE FROM ops.setup_session_task_dependency d USING
 ops.setup_session_task dst,ops.setup_session_task src,ops.setup_session ss
WHERE d.setup_session_task_id=dst.setup_session_task_id
AND d.prerequisite_setup_session_task_id=src.setup_session_task_id
AND dst.setup_session_id=ss.setup_session_id AND src.setup_session_id=ss.setup_session_id
AND ss.season_year=2026
AND src.setup_task_id IN (17,20,32,126,306);

INSERT INTO ops.setup_session_task_dependency
(setup_session_task_id,prerequisite_setup_session_task_id,dependency_origin,dependency_note)
SELECT dst.setup_session_task_id,src.setup_session_task_id,'ANNUAL','#445 shared trailer unloading'
FROM ops.setup_session_task dst JOIN ops.setup_session ss ON ss.setup_session_id=dst.setup_session_id
JOIN ops.setup_session_task src ON src.setup_session_id=ss.setup_session_id
WHERE ss.season_year=2026 AND
 ((dst.setup_task_id IN (18,21,29,34) AND src.setup_task_id=122)
 OR (dst.setup_task_id=34 AND src.setup_task_id=33)
 OR (dst.setup_task_id=213 AND src.setup_task_id=(SELECT id FROM msb445_new_task)))
ON CONFLICT ON CONSTRAINT pk_setup_session_task_dependency DO NOTHING;

-- Keep original annual rows and ALL progress, reports, workday, movement and audit rows.
-- Only remove these five from current season planning visibility.
UPDATE ops.setup_session_task st SET included_flag=false,
 plan_change_reason=concat_ws(E'\n',nullif(st.plan_change_reason,''),'#445: retired redundant Stage unload; actual work retained.')
FROM ops.setup_session ss
WHERE ss.setup_session_id=st.setup_session_id AND ss.season_year=2026
AND st.setup_task_id IN (17,20,32,126,306);

-- No dangling prerequisites in active Catalog/current annual graph.
DO $post$
BEGIN
 IF EXISTS (SELECT 1 FROM ref.setup_task_dependency d
 JOIN ref.setup_task t ON t.setup_task_id=d.setup_task_id
 WHERE t.active_flag AND d.prerequisite_setup_task_id IN (17,20,32,126,306))
 OR EXISTS (SELECT 1 FROM ops.setup_session_task_dependency d
 JOIN ops.setup_session_task target ON target.setup_session_task_id=d.setup_session_task_id
 JOIN ops.setup_session_task source ON source.setup_session_task_id=d.prerequisite_setup_session_task_id
 JOIN ops.setup_session ss ON ss.setup_session_id=target.setup_session_id
 WHERE ss.season_year=2026 AND target.included_flag AND source.setup_task_id IN (17,20,32,126,306)) THEN
 RAISE EXCEPTION '#445 STOP: dangling retired dependency';
 END IF;
 IF NOT EXISTS(SELECT 1 FROM ref.setup_task_dependency WHERE setup_task_id=34 AND prerequisite_setup_task_id=33) THEN
 RAISE EXCEPTION '#445 STOP: Racing Harness #33 prerequisite not preserved';
 END IF;
END $post$;

SELECT 'SETUP_445_DISPOSABLE_CANDIDATE_PASS' AS result,
 (SELECT id FROM msb445_new_task) AS unload_antenna_catalog_id;
ROLLBACK; -- deliberately rolls back every mutation, even on clone.
