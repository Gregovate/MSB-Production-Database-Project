/* #205 Directus mail runtime reconnaissance. READ-ONLY; no email dispatched.
   Run on the governed current-Production clone / permitted read-only connection.
   Do NOT print tokens or operation recipient addresses to shared issue logs.
*/
BEGIN READ ONLY;

SELECT current_database() AS database_name,
       now() AT TIME ZONE 'America/Chicago' AS chicago_now;

SELECT f.name,f.status,f.trigger,
       f.accountability,
       (f.options::jsonb ->> 'type') AS trigger_type,
       (f.options::jsonb -> 'scope') AS scope,
       (f.options::jsonb -> 'collections') AS collections
FROM public.directus_flows f
WHERE f.name IN ('WOI Request Triage Email','Work Order Email Assignees',
                 'Setup Daily Accountability Email')
ORDER BY f.name;

SELECT f.name AS flow_name, o.key AS operation_key, o.type,
       o.resolve IS NOT NULL AS has_success_next,
       o.reject IS NOT NULL AS has_failure_next,
       (SELECT jsonb_agg(j.key ORDER BY j.key)
        FROM jsonb_object_keys(coalesce(o.options::jsonb,'{}'::jsonb)) j(key)
       ) AS option_keys_only
FROM public.directus_operations o
JOIN public.directus_flows f ON f.id=o.flow
WHERE f.name IN ('WOI Request Triage Email','Work Order Email Assignees',
                 'Setup Daily Accountability Email')
ORDER BY f.name,o.key;

SELECT column_name,data_type
FROM information_schema.columns
WHERE table_schema='public'
  AND table_name IN ('directus_flows','directus_operations','directus_collections',
                     'directus_permissions','directus_policies')
ORDER BY table_name,ordinal_position;

SELECT collection,hidden
FROM public.directus_collections
WHERE collection='setup_notification_outbox';

ROLLBACK;
