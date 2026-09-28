/*
MSB Production Database — Directus Flow Configuration Reconnaissance
Purpose:
  Read-only reconstruction of a Directus Flow and its operation chain directly
  from the Directus metadata tables. This is intended for DBeaver/psql
  engineering reconnaissance when screenshots are insufficient.

Issue context:
  First added during Setup #172 / PR #236 to inspect
  "WOI Request Triage Email" and determine whether Setup-origin inserts into
  stage.work_order_intake will trigger the same manager-notification workflow
  as the public Google Work Order Request path.

Safety:
  - SELECT only.
  - Runs inside a READ ONLY transaction.
  - Does not edit Directus metadata, Work Order Intake, or Production data.
  - ROLLBACK is included at the end.

To inspect a different Flow later:
  Replace the literal flow name 'WOI Request Triage Email' in the target_flow
  CTEs below.
*/

BEGIN TRANSACTION READ ONLY;

/* -------------------------------------------------------------------------
   1. Discover the actual Directus metadata tables/columns on this server.
   Run this first if Directus was upgraded or the queries below fail.
   ------------------------------------------------------------------------- */
SELECT
    c.table_schema,
    c.table_name,
    c.ordinal_position,
    c.column_name,
    c.data_type,
    c.udt_name
FROM information_schema.columns c
WHERE c.table_name IN ('directus_flows', 'directus_operations')
ORDER BY c.table_schema, c.table_name, c.ordinal_position;

/* -------------------------------------------------------------------------
   2. Exact target Flow metadata.

   For an event-driven Flow, the important fields are normally:
     trigger      = event/manual/webhook/schedule/operation/etc.
     options      = event scope + collection filters
     operation    = root operation UUID

   If options show collection=work_order_intake and scope=items.create, then
   this Flow is a Directus item-create event hook. A row inserted directly by
   PostgreSQL would not itself traverse the Directus item-create request path.
   ------------------------------------------------------------------------- */
WITH target_flow AS (
    SELECT f.*
    FROM public.directus_flows f
    WHERE f.name = 'WOI Request Triage Email'
)
SELECT
    f.id,
    f.name,
    f.status,
    f.trigger,
    f.accountability,
    f.operation AS root_operation_id,
    f.options,
    f.description,
    f.date_created,
    f.user_created
FROM target_flow f;

/* -------------------------------------------------------------------------
   3. All operations belonging to the target Flow.

   "key" is Directus' internal operation key.
   "type" tells what each node does (mail, condition, read-data, transform,
   request, etc. depending on installed Directus version).
   "options" contains the operation-specific configuration.
   ------------------------------------------------------------------------- */
WITH target_flow AS (
    SELECT f.id
    FROM public.directus_flows f
    WHERE f.name = 'WOI Request Triage Email'
)
SELECT
    o.id,
    o.name,
    o.key,
    o.type,
    o.position_x,
    o.position_y,
    o.resolve,
    o.reject,
    o.options,
    o.date_created,
    o.user_created
FROM public.directus_operations o
JOIN target_flow f
  ON f.id = o.flow
ORDER BY o.position_y NULLS LAST, o.position_x NULLS LAST, o.name, o.id;

/* -------------------------------------------------------------------------
   4. Walk the operation graph from the Flow's root operation.

   edge_from_parent:
     ROOT    = f.operation
     RESOLVE = parent's successful branch
     REJECT  = parent's failure/alternate branch

   The path guard prevents an accidental cycle from looping forever.
   ------------------------------------------------------------------------- */
WITH RECURSIVE
target_flow AS (
    SELECT f.id AS flow_id, f.operation AS root_operation_id
    FROM public.directus_flows f
    WHERE f.name = 'WOI Request Triage Email'
),
walk AS (
    SELECT
        0 AS depth,
        'ROOT'::text AS edge_from_parent,
        o.id,
        o.name,
        o.key,
        o.type,
        o.options,
        o.resolve,
        o.reject,
        ARRAY[o.id]::uuid[] AS path
    FROM target_flow f
    JOIN public.directus_operations o
      ON o.id = f.root_operation_id

    UNION ALL

    SELECT
        w.depth + 1,
        CASE
            WHEN child.id = w.resolve THEN 'RESOLVE'
            WHEN child.id = w.reject THEN 'REJECT'
            ELSE 'UNKNOWN'
        END,
        child.id,
        child.name,
        child.key,
        child.type,
        child.options,
        child.resolve,
        child.reject,
        w.path || child.id
    FROM walk w
    JOIN public.directus_operations child
      ON child.id = w.resolve
      OR child.id = w.reject
    WHERE NOT child.id = ANY(w.path)
)
SELECT
    depth,
    edge_from_parent,
    id,
    name,
    key,
    type,
    resolve,
    reject,
    options
FROM walk
ORDER BY depth, edge_from_parent, name, id;

/* -------------------------------------------------------------------------
   5. Find every Directus Flow/operation that references work_order_intake.

   This is intentionally broader than the named Flow. It catches:
   - another event Flow on the same collection;
   - a Flow whose name changed;
   - operations that read/update the Intake collection;
   - literal URLs/collection names embedded in operation options.
   ------------------------------------------------------------------------- */
SELECT
    'FLOW' AS object_kind,
    f.id::text AS object_id,
    f.name AS object_name,
    f.trigger AS object_type,
    f.options AS configuration
FROM public.directus_flows f
WHERE coalesce(f.options::text, '') ILIKE '%work_order_intake%'
   OR coalesce(f.name, '') ILIKE '%work order intake%'
   OR coalesce(f.description, '') ILIKE '%work order intake%'

UNION ALL

SELECT
    'OPERATION' AS object_kind,
    o.id::text AS object_id,
    coalesce(o.name, o.key, '(unnamed operation)') AS object_name,
    o.type AS object_type,
    o.options AS configuration
FROM public.directus_operations o
WHERE coalesce(o.options::text, '') ILIKE '%work_order_intake%'

ORDER BY object_kind, object_name, object_id;

/* -------------------------------------------------------------------------
   6. Compact interpretation view for the named Flow.

   This does not guess at business meaning; it simply exposes the event trigger
   and root-operation metadata in one row for capture into an issue/PR.
   ------------------------------------------------------------------------- */
WITH target_flow AS (
    SELECT f.*
    FROM public.directus_flows f
    WHERE f.name = 'WOI Request Triage Email'
),
root_operation AS (
    SELECT o.*
    FROM public.directus_operations o
    JOIN target_flow f
      ON o.id = f.operation
)
SELECT
    f.id AS flow_id,
    f.name AS flow_name,
    f.status AS flow_status,
    f.trigger AS flow_trigger,
    f.options AS flow_trigger_options,
    r.id AS root_operation_id,
    r.name AS root_operation_name,
    r.key AS root_operation_key,
    r.type AS root_operation_type,
    r.options AS root_operation_options
FROM target_flow f
LEFT JOIN root_operation r ON true;


/* -------------------------------------------------------------------------
   7. Recent Directus activity for Work Order Intake creates.

   Purpose:
   - prove whether public-form Intake rows entered through Directus ItemsService;
   - identify the Directus user/service identity involved;
   - compare created item IDs to stage.work_order_intake.

   No token/secret columns are selected.
   ------------------------------------------------------------------------- */
SELECT
    a.id AS activity_id,
    a.timestamp,
    a.action,
    a.collection,
    a.item,
    a.user AS directus_user_id,
    u.email AS directus_user_email,
    u.first_name AS directus_user_first_name,
    u.last_name AS directus_user_last_name,
    a.ip,
    a.user_agent,
    a.origin
FROM public.directus_activity a
LEFT JOIN public.directus_users u
  ON u.id = a.user
WHERE a.collection = 'work_order_intake'
  AND a.action = 'create'
ORDER BY a.timestamp DESC
LIMIT 25;

/* -------------------------------------------------------------------------
   8. Candidate Directus service identities.

   This intentionally reports only whether a static token exists, never the
   token value. A token-bearing service identity may explain how the public
   Google Form / Apps Script calls Directus.

   Review names/emails/role IDs only. Do not copy secrets into tickets/chat.
   ------------------------------------------------------------------------- */
SELECT
    u.id,
    u.email,
    u.first_name,
    u.last_name,
    u.status,
    u.role,
    (u.token IS NOT NULL) AS has_static_token
FROM public.directus_users u
WHERE u.token IS NOT NULL
   OR coalesce(u.email, '') ILIKE ANY (
        ARRAY['%work%order%', '%form%', '%script%', '%service%', '%automation%']
   )
   OR coalesce(u.first_name, '') ILIKE ANY (
        ARRAY['%work%order%', '%form%', '%script%', '%service%', '%automation%']
   )
   OR coalesce(u.last_name, '') ILIKE ANY (
        ARRAY['%work%order%', '%form%', '%script%', '%service%', '%automation%']
   )
ORDER BY u.status, u.email NULLS LAST, u.id;

ROLLBACK;
