-- #447 clone-only ACL reconstruction after --no-acl restore.
-- Preserve installed Phase2 functions; never replay historical migration001.
BEGIN;
DO $guard$ BEGIN
  IF current_database()<>'msb_wo419_preview' OR
     current_setting('msb.wo419_preview_authorized',true)
       IS DISTINCT FROM 'approved_disposable_clone' THEN
    RAISE EXCEPTION 'WO447: private disposable clone required for ACL reconstruction';
  END IF;
END $guard$;
REVOKE ALL ON TABLE ops.work_management_activity, ops.work_management_outbox FROM PUBLIC;
REVOKE ALL ON FUNCTION ops.work_management_v1_actor(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION ops.work_management_v1_command(text,text,text,jsonb,uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION ops.work_management_v1_activity(text,text) FROM PUBLIC;

GRANT USAGE ON SCHEMA ops,ref,stage TO work_management_app;
GRANT EXECUTE ON FUNCTION ops.work_management_v1_actor(text),
  ops.work_management_v1_command(text,text,text,jsonb,uuid),
  ops.work_management_v1_activity(text,text)
TO work_management_app;
-- Narrow read grants for the existing shared WO read projection; absolutely
-- no INSERT/UPDATE/DELETE/sequence grants on authoritative Work Order tables.
GRANT SELECT ON ref.person,ref.stage,ref.work_area,ref.task_type,ref.container,
  ref.display,ref.lor_scene,ref.lor_scene_display,
  ref.setup_task,ref.setup_task_container_support,ref.setup_task_display,
  ref.setup_task_extra_material,ref.setup_extra_material,ref.work_order_status,
  ops.work_order,ops.work_order_assignment,ops.work_order_status_history,
  ops.setup_session,ops.setup_session_task,stage.work_order_intake
TO work_management_app;
GRANT EXECUTE ON FUNCTION ref.setup_browser_capabilities(text)
TO work_management_app;
-- The existing V1 unified read model consumes durable correction activity
-- for Manager Intake counts and Task Feedback state. Only SELECT is allowed;
-- activity/outbox mutations remain inside guarded SECURITY DEFINER commands.
GRANT SELECT ON ops.work_management_activity TO work_management_app;
REVOKE ALL ON FUNCTION ops.work_management_mail_status(text,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ops.work_management_mail_status(text,text) TO work_management_app;
COMMIT;
