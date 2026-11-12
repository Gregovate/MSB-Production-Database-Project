-- #447 / #419: authorized entry consumes the shared People #385 resolver.
-- Candidate only. Production requires the existing #37 maintenance/snapshot gate.
BEGIN;
DO $preflight$
BEGIN
  IF current_database() NOT IN ('msb', 'msb_wo419_preview') THEN
    RAISE EXCEPTION 'WO447: unrecognized database';
  END IF;
  IF current_database() = 'msb' AND
     current_setting('msb.wo419_v1_migration_approved', true)
       IS DISTINCT FROM 'approved_maintenance_snapshot' THEN
    RAISE EXCEPTION 'WO447: Production maintenance snapshot/approval required';
  END IF;
  IF current_database() = 'msb_wo419_preview' AND
     current_setting('msb.wo419_preview_authorized', true)
       IS DISTINCT FROM 'approved_disposable_clone' THEN
    RAISE EXCEPTION 'WO447: disposable authorization required';
  END IF;
  IF to_regprocedure('ref.reconcile_directus_person_identity(text)') IS NULL OR
     to_regprocedure('ops.work_management_v1_actor(text)') IS NULL THEN
    RAISE EXCEPTION 'WO447: shared People reconciler/native actor absent';
  END IF;
END $preflight$;

-- Do not make the STABLE native actor (also used by mail/status reads) a writer.
-- This separate entry function grants no new business capability or table DML.
CREATE OR REPLACE FUNCTION ops.work_management_reconcile_actor(p_email text)
RETURNS TABLE(person_id integer, directus_user_id uuid, can_manage boolean)
LANGUAGE plpgsql VOLATILE SECURITY DEFINER
SET search_path = pg_catalog,ops,ref
AS $entry$
DECLARE
  v_email text := lower(btrim(coalesce(p_email,'')));
BEGIN
  IF v_email !~ '^[a-z0-9._%+-]+@sheboyganlights[.]org$' THEN
    RAISE EXCEPTION 'Work Orders: verified organization identity required'
      USING ERRCODE='42501';
  END IF;
  -- Authorization must precede every possible identity mutation.
  IF NOT EXISTS (SELECT 1 FROM ref.setup_browser_capabilities(v_email) c
                 WHERE c.can_read_setup) THEN
    RAISE EXCEPTION 'Work Orders: browser access denied' USING ERRCODE='42501';
  END IF;
  -- The historical shared helper selects one Person. Refuse ambiguity before
  -- calling it, including an inactive duplicate, rather than choosing a row.
  IF (SELECT count(*) FROM ref.person p WHERE lower(p.email)=v_email) <> 1 THEN
    RAISE EXCEPTION 'Work Orders: unique exact-email Person required'
      USING ERRCODE='42501';
  END IF;
  PERFORM ref.reconcile_directus_person_identity(v_email);
  RETURN QUERY SELECT a.* FROM ops.work_management_v1_actor(v_email) a;
END $entry$;
REVOKE ALL ON FUNCTION ops.work_management_reconcile_actor(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ops.work_management_reconcile_actor(text)
  TO work_management_app;
COMMENT ON FUNCTION ops.work_management_reconcile_actor(text) IS
  '#447 authorized entry only: shared audited identity reconciliation, no role changes';
COMMIT;
