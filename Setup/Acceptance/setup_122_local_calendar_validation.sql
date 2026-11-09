-- #122 DBG-2026-021: run only through the existing DISPOSABLE Setup runner.
-- Exercises the installed trigger on rollback-only temporary rows; no annual
-- work/history rows are written. Full report/correction workflow remains a
-- separate current-clone browser acceptance gate.
\set ON_ERROR_STOP on
BEGIN;
DO $checks$
DECLARE
    signature text;
    configured text[];
BEGIN
    FOREACH signature IN ARRAY ARRAY[
        'ops.reject_past_setup_work_day_insert()',
        'ops.add_historical_setup_work_day(text,integer,date,text)',
        'ops.record_setup_task_progress(text,bigint,date,integer,integer,integer,integer,text,text,bigint,bigint,text)',
        'ops.correct_setup_task_progress(text,bigint,date,integer,integer,integer,integer,text,text)'
    ] LOOP
        SELECT proconfig INTO configured FROM pg_proc
        WHERE oid = to_regprocedure(signature);
        IF NOT FOUND OR NOT coalesce(configured @> ARRAY['TimeZone=America/Chicago'], false) THEN
            RAISE EXCEPTION 'Missing Chicago function boundary: %', signature;
        END IF;
    END LOOP;
END
$checks$;
CREATE TEMP TABLE local_calendar_probe(work_date date) ON COMMIT DROP;
CREATE TRIGGER local_calendar_guard BEFORE INSERT ON local_calendar_probe
FOR EACH ROW EXECUTE FUNCTION ops.reject_past_setup_work_day_insert();
SELECT set_config('app.setup_allow_past_work_day', '0', true);
DO $checks$
DECLARE
    caller_zone text;
    park_today date := (now() AT TIME ZONE 'America/Chicago')::date;
BEGIN
    -- Widely separated caller zones prove the installed guard does not inherit
    -- connection timezone. CURRENT_DATE is transaction-stable by design.
    FOREACH caller_zone IN ARRAY ARRAY['UTC', 'America/Chicago', 'Pacific/Kiritimati', 'Pacific/Honolulu'] LOOP
        PERFORM set_config('TimeZone', caller_zone, true);
        INSERT INTO local_calendar_probe VALUES (park_today), (park_today + 1);
        BEGIN
            INSERT INTO local_calendar_probe VALUES (park_today - 1);
            RAISE EXCEPTION 'Past day unexpectedly accepted from %', caller_zone;
        EXCEPTION WHEN SQLSTATE '22023' THEN
            IF SQLERRM <> 'Setup work days cannot be added in the past' THEN
                RAISE;
            END IF;
        END;
        IF current_setting('TimeZone') <> caller_zone THEN
            RAISE EXCEPTION 'Function leaked timezone into caller';
        END IF;
    END LOOP;
    IF (SELECT count(*) FROM local_calendar_probe) <> 8 THEN
        RAISE EXCEPTION 'Unexpected accepted/rejected day count';
    END IF;
END
$checks$;
ROLLBACK;
SELECT 'PASS: four Chicago function configurations; actual insert trigger today/future/past; caller timezone restored' AS result;
