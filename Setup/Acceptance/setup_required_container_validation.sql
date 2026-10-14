-- Disposable-clone ONLY. Roll back all test relationships; no real schedule/movement changes.
BEGIN;
DO $test$
DECLARE
    v_task bigint;
    v_count integer;
    v_actor text := 'gliebig@sheboyganlights.org';
BEGIN
    IF NOT has_function_privilege('fieldwiring_app',
       'ref.set_setup_task_required_container(text,bigint,integer,boolean,text)', 'EXECUTE') THEN
        RAISE EXCEPTION 'Required Container command grant is missing';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM ref.container WHERE container_id=106) THEN
        RAISE EXCEPTION 'Acceptance source C106 is missing';
    END IF;
    SELECT t.setup_task_id INTO v_task FROM ref.setup_task t
    WHERE t.active_flag AND NOT EXISTS (
        SELECT 1 FROM ref.setup_task_container_support tc
        WHERE tc.setup_task_id=t.setup_task_id AND tc.container_id=106)
    ORDER BY t.setup_task_id LIMIT 1;
    IF v_task IS NULL THEN RAISE EXCEPTION 'No unlinked active task for disposable test'; END IF;
    PERFORM * FROM ref.set_setup_task_required_container(v_actor,v_task,106,true,NULL);
    PERFORM * FROM ref.set_setup_task_required_container(v_actor,v_task,106,true,NULL);
    SELECT count(*) INTO v_count FROM ref.setup_task_container_support tc
    WHERE tc.setup_task_id=v_task AND tc.container_id=106 AND tc.relationship_type='REQUIRED_CONTAINER';
    IF v_count<>1 THEN RAISE EXCEPTION 'Repeated save must retain one relationship'; END IF;
    PERFORM * FROM ref.set_setup_task_required_container(v_actor,v_task,106,false,NULL);
    IF EXISTS (SELECT 1 FROM ref.setup_task_container_support tc
               WHERE tc.setup_task_id=v_task AND tc.container_id=106) THEN
        RAISE EXCEPTION 'Removal did not remove direct requirement';
    END IF;
END $test$;
ROLLBACK;
SELECT 'PASS: C106 clone-only required Container save, repeated save, removal, rollback' AS result;
