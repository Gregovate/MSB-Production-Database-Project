/*
Schema: ref / lor_snap / ops
Object: Current P2 procedure safety audit
Filename: 08_current_p2_procedure_safety_audit.sql
Type: Read-only procedure-definition validation
Owner: msbadmin

Purpose:
  Inspect the currently installed ref.p2_upsert_display_from_latest_lor
  procedure and report whether it complies with the approved V7 production
  reconciliation safety rules before any rewrite or execution is authorized.

Safety:
  SELECT only. Does not call P2, create objects, or modify production data.

Rules validated:
  - P2 must read the established lor_snap.v_current_* source contract.
  - P2 must not select max(import_run_id) or independently rediscover a run.
  - SPARE and PHANTOM rows must never enter ref.display writes.
  - P2 must not delete ref.display rows.
  - P2 must not force display_status_id to ACTIVE.
  - P2 must not substitute props.name for a blank LOR comment.
  - P2 must preserve ref.display.display_id.
  - P2 must consume approved reconciliation classifications rather than blindly
    upserting every current physical source row.

Notes:
  This audit does not prohibit ref.spare_channel maintenance. It validates the
  separate and absolute rule that nonphysical rows never reach ref.display.

Result:
  Returns one row per safety rule with PASS, FAIL, or REVIEW_REQUIRED.

Revision History:
  2026-08-01  GAL / OpenAI  Correct SPARE validation: test exclusion from
                           ref.display rather than prohibiting spare-channel work.
  2026-08-01  GAL / OpenAI  Initial current P2 procedure safety audit.
*/

WITH procedure_definition AS (
    SELECT
        p.oid AS procedure_oid,
        n.nspname AS procedure_schema,
        p.proname AS procedure_name,
        pg_get_functiondef(p.oid) AS definition
    FROM pg_proc AS p
    JOIN pg_namespace AS n
      ON n.oid = p.pronamespace
    WHERE n.nspname = 'ref'
      AND p.proname = 'p2_upsert_display_from_latest_lor'
),
checks AS (
    SELECT
        1 AS check_order,
        'P2_PROCEDURE_EXISTS'::text AS check_code,
        CASE WHEN EXISTS (SELECT 1 FROM procedure_definition)
             THEN 'PASS' ELSE 'FAIL' END AS check_status,
        CASE WHEN EXISTS (SELECT 1 FROM procedure_definition)
             THEN 'Installed ref.p2_upsert_display_from_latest_lor procedure was found.'
             ELSE 'Installed ref.p2_upsert_display_from_latest_lor procedure was not found.'
        END AS details

    UNION ALL

    SELECT
        2,
        'USES_CURRENT_SNAPSHOT_VIEWS',
        CASE
            WHEN pd.definition ~* 'lor_snap\.v_current_(run|props|previews)'
                THEN 'PASS'
            ELSE 'FAIL'
        END,
        CASE
            WHEN pd.definition ~* 'lor_snap\.v_current_(run|props|previews)'
                THEN 'P2 references the established lor_snap.v_current_* contract.'
            ELSE 'P2 still reads base snapshot objects instead of lor_snap.v_current_*.'
        END
    FROM procedure_definition AS pd

    UNION ALL

    SELECT
        3,
        'DOES_NOT_SELECT_MAX_IMPORT_RUN',
        CASE
            WHEN pd.definition ~* 'max\s*\(\s*import_run_id\s*\)'
                THEN 'FAIL'
            ELSE 'PASS'
        END,
        CASE
            WHEN pd.definition ~* 'max\s*\(\s*import_run_id\s*\)'
                THEN 'P2 independently selects max(import_run_id); it must use the current-view contract.'
            ELSE 'P2 does not independently select max(import_run_id).'
        END
    FROM procedure_definition AS pd

    UNION ALL

    SELECT
        4,
        'EXCLUDES_NONPHYSICAL_FROM_REF_DISPLAY',
        CASE
            WHEN pd.definition ~* 'c\.is_spare\s*=\s*false'
             AND pd.definition ~* 'upper\s*\([^)]*phantom'
                THEN 'PASS'
            WHEN pd.definition ~* 'c\.is_spare\s*=\s*false'
                THEN 'REVIEW_REQUIRED'
            ELSE 'FAIL'
        END,
        CASE
            WHEN pd.definition ~* 'c\.is_spare\s*=\s*false'
             AND pd.definition ~* 'upper\s*\([^)]*phantom'
                THEN 'SPARE and PHANTOM rows are excluded before ref.display writes.'
            WHEN pd.definition ~* 'c\.is_spare\s*=\s*false'
                THEN 'SPARE exclusion is present, but PHANTOM exclusion requires definition review.'
            ELSE 'No reliable nonphysical-row exclusion was detected before ref.display writes.'
        END
    FROM procedure_definition AS pd

    UNION ALL

    SELECT
        5,
        'DOES_NOT_DELETE_DISPLAY',
        CASE
            WHEN regexp_replace(pd.definition, '--[^\n]*', '', 'g') ~* 'delete\s+from\s+ref\.display'
                THEN 'FAIL'
            ELSE 'PASS'
        END,
        CASE
            WHEN regexp_replace(pd.definition, '--[^\n]*', '', 'g') ~* 'delete\s+from\s+ref\.display'
                THEN 'P2 contains active DELETE logic targeting ref.display.'
            ELSE 'P2 contains no active DELETE logic targeting ref.display.'
        END
    FROM procedure_definition AS pd

    UNION ALL

    SELECT
        6,
        'DOES_NOT_FORCE_ACTIVE_STATUS',
        CASE
            WHEN pd.definition ~* 'v_active_status_id'
                THEN 'FAIL'
            ELSE 'PASS'
        END,
        CASE
            WHEN pd.definition ~* 'v_active_status_id'
                THEN 'P2 resolves ACTIVE and assigns it during display writes; status requires reconciliation policy.'
            ELSE 'P2 does not force display status to ACTIVE.'
        END
    FROM procedure_definition AS pd

    UNION ALL

    SELECT
        7,
        'REQUIRES_NONBLANK_LOR_COMMENT',
        CASE
            WHEN pd.definition ~* 'coalesce\s*\(\s*nullif\s*\(\s*btrim\s*\(\s*p\.lor_comment'
                THEN 'FAIL'
            WHEN pd.definition ~* 'nullif\s*\(\s*btrim\s*\(\s*p\.lor_comment'
                THEN 'PASS'
            ELSE 'REVIEW_REQUIRED'
        END,
        CASE
            WHEN pd.definition ~* 'coalesce\s*\(\s*nullif\s*\(\s*btrim\s*\(\s*p\.lor_comment'
                THEN 'P2 substitutes props.name when lor_comment is blank; this violates the display-name contract.'
            WHEN pd.definition ~* 'nullif\s*\(\s*btrim\s*\(\s*p\.lor_comment'
                THEN 'P2 explicitly requires a nonblank lor_comment.'
            ELSE 'The procedure definition does not clearly establish the nonblank lor_comment rule.'
        END
    FROM procedure_definition AS pd

    UNION ALL

    SELECT
        8,
        'PRESERVES_DISPLAY_ID',
        CASE
            WHEN pd.definition ~* 'update\s+ref\.display'
             AND pd.definition !~* 'set[^;]*display_id\s*='
                THEN 'PASS'
            ELSE 'REVIEW_REQUIRED'
        END,
        CASE
            WHEN pd.definition ~* 'update\s+ref\.display'
             AND pd.definition !~* 'set[^;]*display_id\s*='
                THEN 'No assignment to ref.display.display_id was detected.'
            ELSE 'Display identity preservation requires manual review of the procedure definition.'
        END
    FROM procedure_definition AS pd

    UNION ALL

    SELECT
        9,
        'CONSUMES_RECONCILIATION_CLASSIFICATIONS',
        CASE
            WHEN pd.definition ~* 'ops\.v_lor_display_reconciliation'
              OR pd.definition ~* 'classification_code'
                THEN 'PASS'
            ELSE 'FAIL'
        END,
        CASE
            WHEN pd.definition ~* 'ops\.v_lor_display_reconciliation'
              OR pd.definition ~* 'classification_code'
                THEN 'P2 consumes the reconciliation classification layer.'
            ELSE 'P2 does not consume the reconciliation classification layer and can blindly write physical source rows.'
        END
    FROM procedure_definition AS pd
)
SELECT
    current_database() AS database_name,
    current_user AS database_user,
    now() AS checked_at,
    check_code,
    check_status,
    details
FROM checks
ORDER BY check_order;
