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

-- Validate existing global audit actor mechanism without replacing it.
DO $actor$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_trigger t
    JOIN pg_class c ON c.oid = t.tgrelid
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'ops'
      AND c.relname = 'setup_schedule_event'
      AND t.tgname = 'trg_setup_schedule_event_actor_insert'
      AND t.tgfoid = 'ref.set_actor_on_insert()'::regprocedure
      AND t.tgenabled IN ('O','A')
  ) THEN
    RAISE EXCEPTION 'Existing global audit actor trigger is missing, changed, or disabled';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'ops'
      AND p.proname = 'audit_setup_assignment_lifecycle'
      AND p.prosecdef
  ) THEN
    RAISE EXCEPTION 'Assignment lifecycle audit function is not SECURITY DEFINER';
  END IF;
  IF has_table_privilege('fieldwiring_app', 'ops.setup_schedule_event', 'UPDATE') THEN
    RAISE EXCEPTION 'App role unexpectedly has direct schedule event UPDATE privilege';
  END IF;
END
$actor$;

-- Inspect audit attribution and legacy movement evidence on the clone.
SELECT event_type,
       count(*) AS event_count,
       count(*) FILTER (WHERE created_by_person_id IS NULL) AS unattributed_events
FROM ops.setup_schedule_event
GROUP BY event_type
ORDER BY event_type;

-- Non-destructive evidence inspection: prior migration events remain intact.
SELECT event_type, count(*) AS events
FROM ops.setup_schedule_event
GROUP BY event_type
ORDER BY event_type;
