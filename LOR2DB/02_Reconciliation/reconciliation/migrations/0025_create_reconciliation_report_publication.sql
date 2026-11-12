/* ============================================================================
File:       0025_create_reconciliation_report_publication.sql
Migration:  Reconciliation HTML report publication lifecycle

Purpose:
  Record the immutable report publication only after the HTML file has been
  written successfully, then advance REPORTING to its terminal status.

Safety:
  - Does not run P1, P2, P3, P4, Finish, or Cancel.
  - Accepts one explicitly retained reconciliation-run context.
  - Rejects fixed/latest-run selection and non-REPORTING runs.
  - Publication is idempotent only for the identical path, URL, and SHA-256.

Revision History:
  2026-08-03  GAL / OpenAI  Initial report-publication lifecycle.
============================================================================ */

BEGIN;

ALTER TABLE ops.lor_reconciliation_run
    ADD COLUMN IF NOT EXISTS report_sha256 text;

ALTER TABLE ops.lor_reconciliation_run
    DROP CONSTRAINT IF EXISTS ck_lor_reconciliation_report_sha256;

ALTER TABLE ops.lor_reconciliation_run
    ADD CONSTRAINT ck_lor_reconciliation_report_sha256
    CHECK (report_sha256 IS NULL OR report_sha256 ~ '^[0-9a-f]{64}$');

CREATE OR REPLACE PROCEDURE ops.p_publish_lor_reconciliation_report(
    p_lor_reconciliation_run_id bigint,
    p_report_path text,
    p_report_url text,
    p_report_sha256 text,
    p_published_by_application text DEFAULT NULL
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, ops
AS $procedure$
DECLARE
    v_run ops.lor_reconciliation_run%ROWTYPE;
    v_path text := nullif(btrim(p_report_path), '');
    v_url text := nullif(btrim(p_report_url), '');
    v_sha text := lower(nullif(btrim(p_report_sha256), ''));
    v_terminal_status text;
BEGIN
    PERFORM pg_advisory_xact_lock(
        hashtext('ops.lor_reconciliation.report'),
        (p_lor_reconciliation_run_id % 2147483647)::integer
    );

    SELECT * INTO v_run
    FROM ops.lor_reconciliation_run
    WHERE lor_reconciliation_run_id = p_lor_reconciliation_run_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Reconciliation run % does not exist',
            p_lor_reconciliation_run_id;
    END IF;

    IF v_path IS NULL OR v_url IS NULL THEN
        RAISE EXCEPTION 'Report path and URL are required';
    END IF;

    IF v_sha IS NULL OR v_sha !~ '^[0-9a-f]{64}$' THEN
        RAISE EXCEPTION 'A lowercase 64-character SHA-256 is required';
    END IF;

    IF v_run.status IN ('COMPLETED', 'COMPLETED_WITH_EXCEPTIONS', 'CANCELLED') THEN
        IF v_run.report_path = v_path
           AND v_run.report_url = v_url
           AND v_run.report_sha256 = v_sha THEN
            RETURN;
        END IF;
        RAISE EXCEPTION 'Reconciliation run % already published to %',
            p_lor_reconciliation_run_id, v_run.report_path;
    END IF;

    IF v_run.status <> 'REPORTING' THEN
        RAISE EXCEPTION 'Reconciliation run % is %, not REPORTING',
            p_lor_reconciliation_run_id, v_run.status;
    END IF;

    IF v_run.validation_state <> 'PASSED' THEN
        RAISE EXCEPTION 'Reconciliation run % validation is %, not PASSED',
            p_lor_reconciliation_run_id, v_run.validation_state;
    END IF;

    IF v_run.cancelled_at IS NOT NULL THEN
        v_terminal_status := 'CANCELLED';
    ELSIF v_run.blocked_count <> 0
       OR v_run.deferred_count <> 0
       OR v_run.unresolved_count <> 0 THEN
        v_terminal_status := 'COMPLETED_WITH_EXCEPTIONS';
    ELSE
        v_terminal_status := 'COMPLETED';
    END IF;

    INSERT INTO ops.lor_reconciliation_result (
        lor_reconciliation_run_id, import_run_id, entity_type, entity_key,
        result_class, reason_code, operator_message, committed
    ) VALUES (
        v_run.lor_reconciliation_run_id, v_run.import_run_id, 'RUN',
        v_run.lor_reconciliation_run_id::text, 'REPORT_PUBLISHED',
        'TIMESTAMPED_HTML_REPORT_PUBLISHED',
        format('HTML report published to %s (SHA-256 %s; application %s).',
               v_path, v_sha,
               coalesce(nullif(btrim(p_published_by_application), ''), 'unspecified')),
        true
    );

    UPDATE ops.lor_reconciliation_run
       SET status = v_terminal_status,
           completed_at = CASE
               WHEN v_terminal_status IN ('COMPLETED', 'COMPLETED_WITH_EXCEPTIONS')
                   THEN now()
               ELSE completed_at
           END,
           report_path = v_path,
           report_url = v_url,
           report_sha256 = v_sha,
           report_published_at = now()
     WHERE lor_reconciliation_run_id = p_lor_reconciliation_run_id;
END;
$procedure$;

COMMENT ON PROCEDURE ops.p_publish_lor_reconciliation_report(bigint,text,text,text,text) IS
'Records a successfully written immutable HTML report and performs the REPORTING-to-terminal transition for one retained reconciliation run.';

REVOKE EXECUTE ON PROCEDURE
    ops.p_publish_lor_reconciliation_report(bigint,text,text,text,text)
    FROM PUBLIC;

COMMIT;

SELECT
    '2026-08-03-reconciliation-report-publication-v1'::text AS installed_revision,
    to_regprocedure(
        'ops.p_publish_lor_reconciliation_report(bigint,text,text,text,text)'
    ) IS NOT NULL AS has_report_publication_procedure;
