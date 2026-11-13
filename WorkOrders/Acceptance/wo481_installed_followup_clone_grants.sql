-- #481 WO419 cloned Production 005 already installed — ACL reconstruction ONLY.
-- Must run only on owned private disposable clone; never replay migration005.
-- Existing --no-acl restore strips privileges but preserves function bodies.
BEGIN;
DO $gate$
BEGIN
  IF current_database() <> 'msb_wo419_preview'
     OR current_setting('msb.wo419_preview_authorized',true)
        IS DISTINCT FROM 'approved_disposable_clone' THEN
    RAISE EXCEPTION 'WO481 HOLD: only approved private clone can reconstruct 005 ACL';
  END IF;
  IF to_regprocedure('ops.work_management_wo_followup(text,text,text,jsonb,uuid)') IS NULL
     OR to_regprocedure('ops.work_management_duplicate(text,text,text,jsonb,uuid)') IS NULL
     OR to_regclass('ops.work_management_duplicate_link') IS NULL
     OR to_regprocedure('ops.work_management_capture_mail()') IS NULL
     OR to_regprocedure('ops.work_management_v1_activity(text,text)') IS NULL THEN
    RAISE EXCEPTION 'WO481 HOLD: installed migration005 objects missing; do not replay blindly';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='work_management_app') THEN
    RAISE EXCEPTION 'WO481 HOLD: expected disposable Work Orders role absent';
  END IF;
END $gate$;
REVOKE ALL ON FUNCTION ops.work_management_wo_followup(text,text,text,jsonb,uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION ops.work_management_duplicate(text,text,text,jsonb,uuid) FROM PUBLIC;
REVOKE ALL ON TABLE ops.work_management_duplicate_link FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ops.work_management_wo_followup(text,text,text,jsonb,uuid)
  TO work_management_app;
GRANT EXECUTE ON FUNCTION ops.work_management_duplicate(text,text,text,jsonb,uuid)
  TO work_management_app;
GRANT SELECT ON TABLE ops.work_management_duplicate_link
  TO work_management_app;
COMMIT;
