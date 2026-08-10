-- CHECK: does ops.work_order already have display_id / display_test_session_id?
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema='ops'
  AND table_name='work_order'
  AND column_name IN ('display_id','display_test_session_id','display_lor_prop_id')
ORDER BY column_name;