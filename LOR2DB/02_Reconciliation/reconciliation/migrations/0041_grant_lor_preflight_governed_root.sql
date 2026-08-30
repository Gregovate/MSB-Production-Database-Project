/* ============================================================================
Migration: 0041_grant_lor_preflight_governed_root.sql
Issue:     #104 Grant LOR2DB least-privilege access to governed Stage root resolver

Purpose:
  Restore the least-privilege LOR2DB application role's ability to load Stage
  review after migrations 0039/0040 introduced the governed-root resolver.

Regression:
  Migration 0039 correctly revoked PUBLIC execute on
  ops.f_lor_governed_stage_roots(bigint,text), but did not explicitly grant
  the function to lor_preflight_app. The LOR2DB Stage review view calls this
  resolver directly, so the browser could create/resume a reconciliation but
  then fail while loading Stage review with "permission denied for function
  f_lor_governed_stage_roots".

Safety:
  - Grants EXECUTE only to the existing least-privilege LOR2DB login role.
  - Does not grant EXECUTE to PUBLIC.
  - Does not modify reconciliation rows, LOR snapshots, ref.stage, or any
    production business data.
  - Does not change the function definition or SECURITY DEFINER boundary.
============================================================================ */

BEGIN;

DO $migration$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_roles
        WHERE rolname = 'lor_preflight_app'
          AND rolcanlogin
    ) THEN
        RAISE EXCEPTION
            'Required least-privilege LOR2DB login role lor_preflight_app does not exist';
    END IF;
END
$migration$;

GRANT EXECUTE ON FUNCTION
    ops.f_lor_governed_stage_roots(bigint, text)
TO lor_preflight_app;

COMMIT;

SELECT
    has_function_privilege(
        'lor_preflight_app',
        'ops.f_lor_governed_stage_roots(bigint,text)',
        'EXECUTE'
    ) AS lor_preflight_can_execute_governed_root;
