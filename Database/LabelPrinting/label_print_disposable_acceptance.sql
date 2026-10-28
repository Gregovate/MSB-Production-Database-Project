\set ON_ERROR_STOP on

INSERT INTO ops.label_print_notification_admin(
    person_id, active_flag, activated_at
) VALUES (17, true, clock_timestamp());

/* Request-time provenance belongs to Rick, not the later batch actor. */
SET SESSION AUTHORIZATION directus_app;
UPDATE ref.controller
SET print_label = true, updated_by_person_id = 15
WHERE controller_id = 1001;
RESET SESSION AUTHORIZATION;

DO $assert$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM ops.label_print_request
        WHERE workload_type = 'CONTROLLER'
          AND asset_id = 1001
          AND requester_person_id = 15
          AND requester_verified
          AND status = 'PENDING'
    ) THEN
        RAISE EXCEPTION 'request-time requester was not captured';
    END IF;
END
$assert$;

INSERT INTO ops.controller_label_batch_item(
    controller_label_batch_id, controller_id
) VALUES (1, 1001);

SET SESSION AUTHORIZATION printservice;
SELECT ops.label_print_bind_batch_requests('CONTROLLER', 1);
SELECT ops.label_print_recovery_checkpoint(
    'CONTROLLER', 1, 'BATCH_CREATED', '{"test":true}'::jsonb
);
RESET SESSION AUTHORIZATION;

/* Wrong stock: requester only, exact required stock, no duplicate polling. */
SET SESSION AUTHORIZATION printservice;
SELECT * FROM ops.label_print_incident_upsert(
    'preflight:PRINT-SERVER:controller', 'PREFLIGHT_MEDIA', 'CONTROLLER',
    'Brother PT-P950NW', 'PRINT-SERVER', NULL, 1, 'WARNING', 0,
    'Replace the cassette with 24 mm laminated tape. Detected: 36 mm laminated tape.',
    'WAITING_FOR_CORRECT_MEDIA',
    '{"required_width_mm":24,"detected_width_mm":36}'::jsonb
);
SELECT * FROM ops.label_print_incident_upsert(
    'preflight:PRINT-SERVER:controller', 'PREFLIGHT_MEDIA', 'CONTROLLER',
    'Brother PT-P950NW', 'PRINT-SERVER', NULL, 1, 'WARNING', 0,
    'Replace the cassette with 24 mm laminated tape. Detected: 36 mm laminated tape.',
    'WAITING_FOR_CORRECT_MEDIA',
    '{"required_width_mm":24,"detected_width_mm":36}'::jsonb
);
RESET SESSION AUTHORIZATION;

DO $assert$
DECLARE v_count integer;
BEGIN
    SELECT count(*) INTO v_count
    FROM ops.label_print_notification_outbox
    WHERE incident_key = 'preflight:PRINT-SERVER:controller';
    IF v_count <> 1 THEN
        RAISE EXCEPTION 'wrong-stock polling was not deduplicated: %', v_count;
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM ops.label_print_notification_outbox
        WHERE incident_key = 'preflight:PRINT-SERVER:controller'
          AND audience = 'REQUESTER'
          AND recipient_person_id = 15
          AND message_kind = 'REQUESTER_ACTIVE'
          AND payload ->> 'operator_action' LIKE '%24 mm%'
          AND payload ->> 'operator_action' LIKE '%36 mm%'
    ) OR EXISTS (
        SELECT 1 FROM ops.label_print_notification_outbox
        WHERE incident_key = 'preflight:PRINT-SERVER:controller'
          AND audience = 'ADMIN'
    ) THEN
        RAISE EXCEPTION 'wrong-stock audience/action contract failed';
    END IF;
END
$assert$;

/* Recovery before delivery cancels the stale notice. */
SET SESSION AUTHORIZATION printservice;
SELECT * FROM ops.label_print_incident_resolve(
    'preflight:PRINT-SERVER:controller',
    'AUTOMATIC_PREFLIGHT_RECOVERY',
    '{"correct_stock_detected":true}'::jsonb
);
RESET SESSION AUTHORIZATION;

DO $assert$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM ops.label_print_notification_outbox
        WHERE incident_key = 'preflight:PRINT-SERVER:controller'
          AND delivery_status = 'CANCELLED'
    ) THEN
        RAISE EXCEPTION 'resolved queued media notice was not cancelled';
    END IF;
END
$assert$;

/* Successful finalization produces a requester-only ready notification. */
SET SESSION AUTHORIZATION printservice;
UPDATE ref.controller SET print_label = false WHERE controller_id = 1001;
SELECT ops.label_print_recovery_checkpoint(
    'CONTROLLER', 1, 'COMPLETED', '{"physical_ready_idle":true}'::jsonb
);
SELECT ops.label_print_queue_success_events('CONTROLLER', 1);
RESET SESSION AUTHORIZATION;

DO $assert$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM ops.label_print_request
        WHERE workload_type = 'CONTROLLER' AND asset_id = 1001
          AND status = 'COMPLETED' AND completed_at IS NOT NULL
    ) OR NOT EXISTS (
        SELECT 1 FROM ops.label_print_notification_outbox
        WHERE transition = 'SUCCESS'
          AND audience = 'REQUESTER'
          AND recipient_person_id = 15
          AND message_kind = 'REQUESTER_SUCCESS'
          AND payload ->> 'status' = 'READY'
    ) THEN
        RAISE EXCEPTION 'successful ready-notification contract failed';
    END IF;
END
$assert$;

/* Exhausted/ambiguous recovery escalates to Greg, not the requester. */
SET SESSION AUTHORIZATION printservice;
SELECT * FROM ops.label_print_incident_upsert(
    'failed-batch:controller:1', 'FAILED_BATCH', 'CONTROLLER',
    'Brother PT-P950NW', 'PRINT-SERVER', 1, 1, 'ERROR', 0,
    'Engineering reconciliation required.', 'RECONCILIATION_REQUIRED',
    '{"failure_reason":"physical completion uncertain"}'::jsonb
);
RESET SESSION AUTHORIZATION;

DO $assert$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM ops.label_print_notification_outbox
        WHERE incident_key = 'failed-batch:controller:1'
          AND audience = 'ADMIN' AND recipient_person_id = 17
          AND message_kind = 'ADMIN_ACTIVE'
    ) OR EXISTS (
        SELECT 1 FROM ops.label_print_notification_outbox
        WHERE incident_key = 'failed-batch:controller:1'
          AND audience = 'REQUESTER'
    ) THEN
        RAISE EXCEPTION 'administrator escalation boundary failed';
    END IF;
END
$assert$;

/* Proven pre-DATA failure retries twice; second attempt accepts. */
SET SESSION AUTHORIZATION label_print_mail;
SELECT ops.label_print_mail_claim(
    repeat('a', 64),
    (SELECT event_key FROM ops.label_print_notification_outbox
      WHERE transition = 'SUCCESS'),
    1, 'rick@example.invalid',
    '{"subject":"ready","text":"ready","html":"<p>ready</p>","template_sha256":"test"}'::jsonb
);
SELECT ops.label_print_mail_finish(
    repeat('a', 64), 'FAILED_BEFORE_DATA', 'connection_or_tls_failure'
);
RESET SESSION AUTHORIZATION;

UPDATE ops.label_print_notification_outbox
SET available_at = clock_timestamp()
WHERE transition = 'SUCCESS';

SET SESSION AUTHORIZATION label_print_mail;
SELECT ops.label_print_mail_claim(
    repeat('b', 64),
    (SELECT event_key FROM ops.label_print_notification_outbox
      WHERE transition = 'SUCCESS'),
    2, 'rick@example.invalid',
    '{"subject":"ready","text":"ready","html":"<p>ready</p>","template_sha256":"test"}'::jsonb
);
SELECT ops.label_print_mail_finish(
    repeat('b', 64), 'SMTP_ACCEPTED', 'send_message_returned_accepted'
);
RESET SESSION AUTHORIZATION;

DO $assert$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM ops.label_print_notification_outbox
        WHERE transition = 'SUCCESS' AND attempt_count = 2
          AND delivery_status = 'SMTP_ACCEPTED'
    ) OR (
        SELECT count(*) FROM ops.label_print_mail_delivery
        WHERE event_key = (
            SELECT event_key FROM ops.label_print_notification_outbox
            WHERE transition = 'SUCCESS'
        )
    ) <> 2 THEN
        RAISE EXCEPTION 'bounded proven-no-send retry failed';
    END IF;
END
$assert$;

/* Pre-submission release returns the original request without replaying it. */
SET SESSION AUTHORIZATION directus_app;
UPDATE ref.controller
SET print_label = true, updated_by_person_id = 15
WHERE controller_id = 1002;
RESET SESSION AUTHORIZATION;
INSERT INTO ops.controller_label_batch_item(
    controller_label_batch_id, controller_id
) VALUES (2, 1002);
SET SESSION AUTHORIZATION printservice;
SELECT ops.label_print_bind_batch_requests('CONTROLLER', 2);
SELECT ops.label_print_recovery_checkpoint(
    'CONTROLLER', 2, 'BATCH_CREATED', '{}'::jsonb
);
SELECT ops.label_print_release_batch_requests('CONTROLLER', 2);
SELECT ops.label_print_recovery_checkpoint(
    'CONTROLLER', 2, 'RELEASED_NO_SUBMISSION', '{}'::jsonb
);
RESET SESSION AUTHORIZATION;

DO $assert$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM ops.label_print_request
        WHERE workload_type = 'CONTROLLER' AND asset_id = 1002
          AND status = 'PENDING' AND batch_id IS NULL
    ) OR EXISTS (
        SELECT 1 FROM ops.label_print_recovery_candidates()
        WHERE workload_type = 'CONTROLLER' AND batch_id = 2
    ) THEN
        RAISE EXCEPTION 'safe pre-submission release failed';
    END IF;
END
$assert$;

/* Least privilege: worker has functions, not raw outbox/table access. */
DO $assert$
BEGIN
    IF has_table_privilege(
        'label_print_mail', 'ops.label_print_notification_outbox', 'SELECT'
    ) OR NOT has_function_privilege(
        'label_print_mail', 'ops.label_print_mail_candidates()', 'EXECUTE'
    ) OR has_table_privilege(
        'printservice', 'ops.label_print_notification_outbox', 'INSERT'
    ) THEN
        RAISE EXCEPTION 'least-privilege boundary failed';
    END IF;
END
$assert$;

\echo 'PASS: Label Print migration, requester media/success mail, admin escalation, bounded retry, recovery and permissions'

