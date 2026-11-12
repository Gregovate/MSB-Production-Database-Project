-- #122 DBG-2026-021 / #205 / #132: MSB calendar dates are America/Chicago.
-- Function-local TimeZone fixes CURRENT_DATE without changing caller/global
-- settings or replacing accepted command bodies, privileges or history.
BEGIN;
ALTER FUNCTION ops.reject_past_setup_work_day_insert()
    SET TimeZone TO 'America/Chicago';
ALTER FUNCTION ops.add_historical_setup_work_day(text,integer,date,text)
    SET TimeZone TO 'America/Chicago';
ALTER FUNCTION ops.record_setup_task_progress(text,bigint,date,integer,integer,integer,integer,text,text,bigint,bigint,text)
    SET TimeZone TO 'America/Chicago';
ALTER FUNCTION ops.correct_setup_task_progress(text,bigint,date,integer,integer,integer,integer,text,text)
    SET TimeZone TO 'America/Chicago';
COMMIT;
