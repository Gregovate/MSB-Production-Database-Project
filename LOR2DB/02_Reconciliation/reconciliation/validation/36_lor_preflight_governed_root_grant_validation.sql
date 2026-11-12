/* ============================================================================
Validation: 36_lor_preflight_governed_root_grant_validation.sql
Migration:  0041_grant_lor_preflight_governed_root.sql
Issue:      #104

Purpose:
  Prove the least-privilege LOR2DB application role can execute the governed
  Stage-root resolver and load the Stage review view, while PUBLIC remains
  denied.

Execution:
  Read-only validation. Run as msbadmin after migration 0041.
============================================================================ */

BEGIN READ ONLY;

SELECT
    has_function_privilege(
        'lor_preflight_app',
        'ops.f_lor_governed_stage_roots(bigint,text)',
        'EXECUTE'
    ) AS lor_preflight_can_execute_governed_root,
    NOT EXISTS (
        SELECT 1
        FROM pg_proc AS p
        CROSS JOIN LATERAL aclexplode(
            coalesce(p.proacl, acldefault('f', p.proowner))
        ) AS a
        WHERE p.oid =
              'ops.f_lor_governed_stage_roots(bigint,text)'::regprocedure
          AND a.grantee = 0
          AND a.privilege_type = 'EXECUTE'
    ) AS public_execute_remains_revoked;

DO $validation$
BEGIN
    IF NOT has_function_privilege(
        'lor_preflight_app',
        'ops.f_lor_governed_stage_roots(bigint,text)',
        'EXECUTE'
    ) THEN
        RAISE EXCEPTION
            'lor_preflight_app cannot execute ops.f_lor_governed_stage_roots(bigint,text)';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM pg_proc AS p
        CROSS JOIN LATERAL aclexplode(
            coalesce(p.proacl, acldefault('f', p.proowner))
        ) AS a
        WHERE p.oid =
              'ops.f_lor_governed_stage_roots(bigint,text)'::regprocedure
          AND a.grantee = 0
          AND a.privilege_type = 'EXECUTE'
    ) THEN
        RAISE EXCEPTION
            'PUBLIC unexpectedly has EXECUTE on governed-root resolver';
    END IF;
END
$validation$;

/* Exercise the exact browser read boundary under the actual application role. */
SET LOCAL ROLE lor_preflight_app;

SELECT
    lor_reconciliation_run_id,
    import_run_id,
    lor_reconciliation_group_id,
    source_stage_key,
    proposed_stage_name,
    proposed_folder_name
FROM ops.v_lor_reconciliation_operator_stage_review
ORDER BY lor_reconciliation_run_id DESC,
         lor_reconciliation_group_id,
         lor_reconciliation_stage_candidate_id
LIMIT 10;

RESET ROLE;

ROLLBACK;
