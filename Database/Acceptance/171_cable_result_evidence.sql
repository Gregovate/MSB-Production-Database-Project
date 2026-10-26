-- Bounded read-only retained-source inspection. No ingest and no source-file edits.
-- Run against the disposable preview clone and retain notices with its report.
BEGIN READ ONLY;
DO $evidence$
DECLARE item record;
BEGIN
 -- LinkWare screenshot supplied by Greg, October 26: FAIL/PASS/INFO anchors.
 FOR item IN SELECT tester_original_name,test_time_local,length_ft,test_standard,test_status_code
 FROM ops.linkiq_test WHERE lower(btrim(tester_original_name)) IN ('lpfc-03 to fc-00 reg','po to lpft-ps aux-i','larrys antena')
 ORDER BY tester_original_name,test_time_local LIMIT 30 LOOP
  RAISE NOTICE 'LinkWare match: name=% date=% length_ft=% standard=% stored_code=%',item.tester_original_name,item.test_time_local,item.length_ft,item.test_standard,item.test_status_code;
 END LOOP;
 IF NOT EXISTS(SELECT 1 FROM information_schema.columns WHERE table_schema='ops' AND table_name='linkiq_test' AND column_name='original_result') THEN
  RAISE NOTICE 'FLW outcome decoding: retained original_result not present in this fixture';
  RETURN;
 END IF;
 FOR item IN EXECUTE $query$
 WITH RECURSIVE samples AS (
  SELECT * FROM (SELECT test_uuid,test_status_code,original_result,row_number() OVER(PARTITION BY test_status_code ORDER BY test_time_local DESC NULLS LAST,test_uuid) n FROM ops.linkiq_test) t WHERE n<=2 ORDER BY test_status_code,test_uuid LIMIT 8
 ), tree(test_uuid,code,path,value,depth) AS (
  SELECT test_uuid,test_status_code,ARRAY[]::text[],original_result,0 FROM samples
  UNION ALL
  SELECT t.test_uuid,t.code,t.path||c.key,c.value,t.depth+1 FROM tree t CROSS JOIN LATERAL (
   SELECT key,value FROM jsonb_each(CASE WHEN jsonb_typeof(t.value)='object' THEN t.value ELSE '{}'::jsonb END)
   UNION ALL SELECT (ordinality-1)::text,value FROM jsonb_array_elements(CASE WHEN jsonb_typeof(t.value)='array' THEN t.value ELSE '[]'::jsonb END) WITH ORDINALITY
  ) c WHERE t.depth<12
 ) SELECT test_uuid,code,array_to_string(path,'.') path,left(value::text,160) value FROM tree
 WHERE jsonb_typeof(value) IN ('string','number','boolean') AND array_to_string(path,'.') ~* '(result|status|pass|fail|speed|standard|rate)' ORDER BY code,test_uuid,path LIMIT 160
 $query$ LOOP
  RAISE NOTICE 'FLW result evidence: code=% test=% path=% value=%',item.code,item.test_uuid,item.path,item.value;
 END LOOP;
 RAISE NOTICE 'Numeric PASS/FAIL mapping remains unverified until these retained source outcomes are reconciled. Do not infer it from fixture status codes.';
END $evidence$;
ROLLBACK;
