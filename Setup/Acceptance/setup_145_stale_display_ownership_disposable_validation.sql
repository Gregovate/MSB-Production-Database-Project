/*
Filename: setup_145_stale_display_ownership_disposable_validation.sql
Issue: #145
DISPOSABLE DATABASE ONLY.

Purpose:
  Prove the governed stale-row cleanup command removes exactly one expected
  ownership row and rejects a stale concurrency token. This validation rolls
  back all clone changes.
*/

\set ON_ERROR_STOP on
BEGIN;

DO $validation$
DECLARE
    v_manager_email text;
    v_display_id bigint;
    v_owner_task_id bigint;
    v_other_task_id bigint;
    v_before integer;
BEGIN
    IF to_regprocedure('ref.clear_stale_setup_task_display_owner(text,bigint,bigint)') IS NULL THEN
        RAISE EXCEPTION 'Migration 052 command is missing';
    END IF;

    SELECT lower(u.email)
      INTO v_manager_email
    FROM directus_users AS u
    JOIN LATERAL ref.setup_browser_capabilities(lower(u.email)) AS c ON true
    WHERE u.status = 'active'
      AND coalesce(c.can_manage_setup, false)
    ORDER BY u.id
    LIMIT 1;

    IF v_manager_email IS NULL THEN
        RAISE EXCEPTION 'No Manager identity is available in disposable clone';
    END IF;

    SELECT td.display_id, td.setup_task_id
      INTO v_display_id, v_owner_task_id
    FROM ref.setup_task_display AS td
    ORDER BY td.display_id
    LIMIT 1;

    IF v_display_id IS NULL THEN
        RAISE EXCEPTION 'Disposable clone has no Display ownership row to exercise';
    END IF;

    SELECT t.setup_task_id
      INTO v_other_task_id
    FROM ref.setup_task AS t
    WHERE t.setup_task_id <> v_owner_task_id
    ORDER BY t.setup_task_id
    LIMIT 1;

    SELECT count(*) INTO v_before
    FROM ref.setup_task_display
    WHERE display_id = v_display_id
      AND setup_task_id = v_owner_task_id;

    BEGIN
        PERFORM *
        FROM ref.clear_stale_setup_task_display_owner(
            v_manager_email,
            v_display_id,
            v_other_task_id
        );
        RAISE EXCEPTION 'Expected concurrency mismatch was not rejected';
    EXCEPTION
        WHEN unique_violation THEN
            NULL;
    END;

    IF (
        SELECT count(*)
        FROM ref.setup_task_display
        WHERE display_id = v_display_id
          AND setup_task_id = v_owner_task_id
    ) <> v_before THEN
        RAISE EXCEPTION 'Rejected cleanup changed the ownership row';
    END IF;

    PERFORM *
    FROM ref.clear_stale_setup_task_display_owner(
        v_manager_email,
        v_display_id,
        v_owner_task_id
    );

    IF EXISTS (
        SELECT 1
        FROM ref.setup_task_display
        WHERE display_id = v_display_id
    ) THEN
        RAISE EXCEPTION 'Expected ownership row was not removed';
    END IF;
END
$validation$;

ROLLBACK;

SELECT 'SETUP_145_STALE_DISPLAY_OWNERSHIP_DISPOSABLE_VALIDATION_PASS' AS result;
