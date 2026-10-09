-- #205 disposable post-migration structural validation (read-only).
-- Execute against disposable clone AFTER migration 072, never as a Production write.
DO $check$
BEGIN
  IF to_regclass('ops.setup_schedule_event') IS NULL
     OR to_regclass('ops.preview_setup_schedule_churn_v1') IS NULL THEN
    RAISE EXCEPTION 'Schedule lifecycle audit relation/view missing';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger t
    JOIN pg_class c ON c.oid = t.tgrelid
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'ops' AND c.relname = 'setup_work_day_task'
      AND t.tgname = 'trg_setup_assignment_lifecycle_insert'
      AND NOT t.tgisinternal
  ) OR NOT EXISTS (
    SELECT 1 FROM pg_trigger t
    JOIN pg_class c ON c.oid = t.tgrelid
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'ops' AND c.relname = 'setup_work_day_task'
      AND t.tgname = 'trg_setup_assignment_lifecycle_delete'
      AND NOT t.tgisinternal
  ) THEN
    RAISE EXCEPTION 'Schedule lifecycle audit trigger missing';
  END IF;
  IF has_table_privilege('fieldwiring_app', 'ops.setup_schedule_event', 'INSERT') THEN
    RAISE EXCEPTION 'App role unexpectedly has direct schedule event INSERT privilege';
  END IF;
  IF has_table_privilege('fieldwiring_app', 'ops.setup_schedule_event', 'DELETE') THEN
    RAISE EXCEPTION 'App role unexpectedly has schedule event DELETE privilege';
  END IF;
END
$check$;

-- Non-destructive evidence inspection: prior migration events remain intact.
SELECT event_type, count(*) AS events
FROM ops.setup_schedule_event
GROUP BY event_type
ORDER BY event_type;
