/* ============================================================================
Label Print recovery evidence, requester provenance, incidents, and mail outbox
Issues: LabelPrintService #36; Server Management #96/#97; Database #122
Revision: 2026-10-28 V0.1.0 CANDIDATE — NOT DEPLOYED

This migration creates durable business/event state only.  It does not install
SMTP credentials, activate recipients, send mail, or reconcile an existing
ambiguous print batch.  Production execution requires the established #37
maintenance controller, validated snapshot, disposable-clone acceptance, and
separate explicit approval.
============================================================================ */

BEGIN;

DO $preflight$
BEGIN
    IF current_database() NOT IN ('msb', 'msb_label_print_preview') THEN
        RAISE EXCEPTION 'Label Print notifications: unrecognized database';
    END IF;
    IF current_database() = 'msb'
       AND current_setting('msb.label_print_notifications_approved', true)
           IS DISTINCT FROM 'approved_maintenance_snapshot' THEN
        RAISE EXCEPTION
            'Label Print notifications: approved maintenance snapshot required';
    END IF;
    IF current_database() = 'msb_label_print_preview'
       AND current_setting('msb.label_print_preview_authorized', true)
           IS DISTINCT FROM 'approved_disposable_clone' THEN
        RAISE EXCEPTION
            'Label Print notifications: disposable clone authorization required';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'printservice') THEN
        RAISE EXCEPTION 'Required role printservice is absent';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'label_print_mail') THEN
        RAISE EXCEPTION
            'Server Management must provision role label_print_mail first';
    END IF;
    IF to_regclass('ref.person') IS NULL
       OR to_regclass('ref.display') IS NULL
       OR to_regclass('ref.container') IS NULL
       OR to_regclass('ref.controller') IS NULL
       OR to_regclass('ops.display_label_batch_item') IS NULL
       OR to_regclass('ops.container_label_batch_item') IS NULL
       OR to_regclass('ops.controller_label_batch_item') IS NULL THEN
        RAISE EXCEPTION 'Required Label Print / Person tables are absent';
    END IF;
END
$preflight$;

CREATE TABLE ops.label_print_request (
    label_print_request_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    workload_type text NOT NULL
        CHECK (workload_type IN ('DISPLAY', 'CONTAINER', 'CONTROLLER')),
    asset_id bigint NOT NULL CHECK (asset_id > 0),
    requested_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    requester_person_id integer REFERENCES ref.person(person_id)
        ON UPDATE CASCADE ON DELETE SET NULL,
    requester_verified boolean NOT NULL DEFAULT false,
    provenance_source text NOT NULL
        CHECK (provenance_source IN ('ROW_AUDIT', 'LEGACY_ROW_AUDIT')),
    status text NOT NULL DEFAULT 'PENDING'
        CHECK (status IN ('PENDING', 'BATCHED', 'COMPLETED', 'CANCELLED')),
    batch_id bigint,
    completed_at timestamptz,
    CONSTRAINT ck_label_print_request_completion CHECK (
        (status IN ('PENDING', 'BATCHED') AND completed_at IS NULL)
        OR (status IN ('COMPLETED', 'CANCELLED') AND completed_at IS NOT NULL)
    )
);

CREATE UNIQUE INDEX uq_label_print_request_active_asset
    ON ops.label_print_request(workload_type, asset_id)
    WHERE status IN ('PENDING', 'BATCHED');
CREATE INDEX idx_label_print_request_requester
    ON ops.label_print_request(requester_person_id, status);

COMMENT ON TABLE ops.label_print_request IS
    'One durable request per pending physical asset label. Requester identity is frozen when print_label changes false-to-true.';
COMMENT ON COLUMN ops.label_print_request.requester_verified IS
    'Only true for request-time actor evidence. Legacy backfill remains administrator-only for notification.';

CREATE FUNCTION ops.capture_label_print_request()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, ops
AS $capture$
DECLARE
    v_workload text := TG_ARGV[0];
    v_id_column text := TG_ARGV[1];
    v_old jsonb := to_jsonb(OLD);
    v_new jsonb := to_jsonb(NEW);
    v_asset_id bigint;
    v_requester integer;
    v_completion_status text;
BEGIN
    IF v_workload NOT IN ('DISPLAY', 'CONTAINER', 'CONTROLLER') THEN
        RAISE EXCEPTION 'Unrecognized Label Print workload trigger argument';
    END IF;
    v_asset_id := (v_new ->> v_id_column)::bigint;

    IF coalesce((v_old ->> 'print_label')::boolean, false) = false
       AND coalesce((v_new ->> 'print_label')::boolean, false) = true THEN
        v_requester := nullif(v_new ->> 'updated_by_person_id', '')::integer;
        INSERT INTO ops.label_print_request (
            workload_type,
            asset_id,
            requester_person_id,
            requester_verified,
            provenance_source
        ) VALUES (
            v_workload,
            v_asset_id,
            v_requester,
            v_requester IS NOT NULL,
            'ROW_AUDIT'
        )
        ON CONFLICT (workload_type, asset_id)
            WHERE status IN ('PENDING', 'BATCHED')
        DO NOTHING;
    ELSIF coalesce((v_old ->> 'print_label')::boolean, false) = true
          AND coalesce((v_new ->> 'print_label')::boolean, false) = false THEN
        v_completion_status := CASE
            WHEN session_user = 'printservice' THEN 'COMPLETED'
            ELSE 'CANCELLED'
        END;
        UPDATE ops.label_print_request
        SET status = v_completion_status,
            completed_at = clock_timestamp()
        WHERE workload_type = v_workload
          AND asset_id = v_asset_id
          AND status IN ('PENDING', 'BATCHED');
    END IF;
    RETURN NEW;
END
$capture$;

REVOKE ALL ON FUNCTION ops.capture_label_print_request() FROM PUBLIC;

CREATE TRIGGER zz_display_label_request_capture
AFTER UPDATE OF print_label ON ref.display
FOR EACH ROW EXECUTE FUNCTION ops.capture_label_print_request(
    'DISPLAY', 'display_id'
);
CREATE TRIGGER zz_container_label_request_capture
AFTER UPDATE OF print_label ON ref.container
FOR EACH ROW EXECUTE FUNCTION ops.capture_label_print_request(
    'CONTAINER', 'container_id'
);
CREATE TRIGGER zz_controller_label_request_capture
AFTER UPDATE OF print_label ON ref.controller
FOR EACH ROW EXECUTE FUNCTION ops.capture_label_print_request(
    'CONTROLLER', 'controller_id'
);

/* Existing pending rows predate request-time capture. Preserve them, but do
   not send requester-specific mail from mutable legacy row audit evidence. */
INSERT INTO ops.label_print_request (
    workload_type, asset_id, requester_person_id,
    requester_verified, provenance_source
)
SELECT 'DISPLAY', display_id, updated_by_person_id, false, 'LEGACY_ROW_AUDIT'
FROM ref.display WHERE print_label
ON CONFLICT DO NOTHING;
INSERT INTO ops.label_print_request (
    workload_type, asset_id, requester_person_id,
    requester_verified, provenance_source
)
SELECT 'CONTAINER', container_id, updated_by_person_id, false, 'LEGACY_ROW_AUDIT'
FROM ref.container WHERE print_label
ON CONFLICT DO NOTHING;
INSERT INTO ops.label_print_request (
    workload_type, asset_id, requester_person_id,
    requester_verified, provenance_source
)
SELECT 'CONTROLLER', controller_id, updated_by_person_id, false, 'LEGACY_ROW_AUDIT'
FROM ref.controller WHERE print_label
ON CONFLICT DO NOTHING;

ALTER TABLE ops.display_label_batch_item
    ADD COLUMN label_print_request_id bigint,
    ADD COLUMN requester_person_id integer;
ALTER TABLE ops.container_label_batch_item
    ADD COLUMN label_print_request_id bigint,
    ADD COLUMN requester_person_id integer;
ALTER TABLE ops.controller_label_batch_item
    ADD COLUMN label_print_request_id bigint,
    ADD COLUMN requester_person_id integer;

ALTER TABLE ops.display_label_batch_item
    ADD CONSTRAINT fk_display_label_item_request
        FOREIGN KEY (label_print_request_id)
        REFERENCES ops.label_print_request(label_print_request_id),
    ADD CONSTRAINT fk_display_label_item_requester
        FOREIGN KEY (requester_person_id) REFERENCES ref.person(person_id);
ALTER TABLE ops.container_label_batch_item
    ADD CONSTRAINT fk_container_label_item_request
        FOREIGN KEY (label_print_request_id)
        REFERENCES ops.label_print_request(label_print_request_id),
    ADD CONSTRAINT fk_container_label_item_requester
        FOREIGN KEY (requester_person_id) REFERENCES ref.person(person_id);
ALTER TABLE ops.controller_label_batch_item
    ADD CONSTRAINT fk_controller_label_item_request
        FOREIGN KEY (label_print_request_id)
        REFERENCES ops.label_print_request(label_print_request_id),
    ADD CONSTRAINT fk_controller_label_item_requester
        FOREIGN KEY (requester_person_id) REFERENCES ref.person(person_id);

CREATE FUNCTION ops.label_print_bind_batch_requests(
    p_workload_type text,
    p_batch_id bigint
) RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, ops
AS $bind$
DECLARE
    v_item_count integer;
    v_bound_count integer;
BEGIN
    IF p_workload_type = 'DISPLAY' THEN
        UPDATE ops.display_label_batch_item i
        SET label_print_request_id = r.label_print_request_id,
            requester_person_id = CASE
                WHEN r.requester_verified THEN r.requester_person_id
                ELSE NULL
            END
        FROM ops.label_print_request r
        WHERE i.display_label_batch_id = p_batch_id
          AND r.workload_type = 'DISPLAY'
          AND r.asset_id = i.display_id
          AND r.status = 'PENDING';
        SELECT count(*), count(label_print_request_id)
          INTO v_item_count, v_bound_count
        FROM ops.display_label_batch_item
        WHERE display_label_batch_id = p_batch_id;
    ELSIF p_workload_type = 'CONTAINER' THEN
        UPDATE ops.container_label_batch_item i
        SET label_print_request_id = r.label_print_request_id,
            requester_person_id = CASE
                WHEN r.requester_verified THEN r.requester_person_id
                ELSE NULL
            END
        FROM ops.label_print_request r
        WHERE i.container_label_batch_id = p_batch_id
          AND r.workload_type = 'CONTAINER'
          AND r.asset_id = i.container_id
          AND r.status = 'PENDING';
        SELECT count(*), count(label_print_request_id)
          INTO v_item_count, v_bound_count
        FROM ops.container_label_batch_item
        WHERE container_label_batch_id = p_batch_id;
    ELSIF p_workload_type = 'CONTROLLER' THEN
        UPDATE ops.controller_label_batch_item i
        SET label_print_request_id = r.label_print_request_id,
            requester_person_id = CASE
                WHEN r.requester_verified THEN r.requester_person_id
                ELSE NULL
            END
        FROM ops.label_print_request r
        WHERE i.controller_label_batch_id = p_batch_id
          AND r.workload_type = 'CONTROLLER'
          AND r.asset_id = i.controller_id
          AND r.status = 'PENDING';
        SELECT count(*), count(label_print_request_id)
          INTO v_item_count, v_bound_count
        FROM ops.controller_label_batch_item
        WHERE controller_label_batch_id = p_batch_id;
    ELSE
        RAISE EXCEPTION 'Unrecognized workload type';
    END IF;

    IF v_item_count = 0 OR v_item_count <> v_bound_count THEN
        RAISE EXCEPTION
            'Every frozen batch item must bind one active request: items=%, bound=%',
            v_item_count, v_bound_count;
    END IF;
    UPDATE ops.label_print_request
    SET status = 'BATCHED', batch_id = p_batch_id
    WHERE label_print_request_id IN (
        SELECT label_print_request_id
        FROM ops.label_print_request
        WHERE workload_type = p_workload_type
          AND batch_id IS NULL
          AND status = 'PENDING'
    )
      AND label_print_request_id IN (
        SELECT label_print_request_id
        FROM (
            SELECT label_print_request_id
              FROM ops.display_label_batch_item
             WHERE p_workload_type = 'DISPLAY'
               AND display_label_batch_id = p_batch_id
            UNION ALL
            SELECT label_print_request_id
              FROM ops.container_label_batch_item
             WHERE p_workload_type = 'CONTAINER'
               AND container_label_batch_id = p_batch_id
            UNION ALL
            SELECT label_print_request_id
              FROM ops.controller_label_batch_item
             WHERE p_workload_type = 'CONTROLLER'
               AND controller_label_batch_id = p_batch_id
        ) bound
        WHERE label_print_request_id IS NOT NULL
    );
    RETURN v_bound_count;
END
$bind$;

CREATE TABLE ops.label_print_service_heartbeat (
    instance_key text PRIMARY KEY CHECK (instance_key = 'PRINT-SERVER'),
    service_version text NOT NULL,
    process_id integer NOT NULL CHECK (process_id > 0),
    state text NOT NULL CHECK (state IN ('STARTING', 'IDLE', 'BUSY', 'BLOCKED')),
    details jsonb NOT NULL DEFAULT '{}'::jsonb
        CHECK (jsonb_typeof(details) = 'object'),
    last_seen_at timestamptz NOT NULL
);

CREATE TABLE ops.label_print_batch_recovery (
    workload_type text NOT NULL CHECK (workload_type IN (
        'DISPLAY', 'CONTAINER', 'CONTROLLER'
    )),
    batch_id bigint NOT NULL CHECK (batch_id > 0),
    last_event text NOT NULL CHECK (last_event IN (
        'BATCH_CREATED', 'SUBMISSION_STARTED', 'SPOOLER_OBSERVED',
        'BROTHER_ACTIVE', 'SPOOLER_CLEARED', 'READY_IDLE',
        'RECOVERABLE_MEDIA', 'AMBIGUOUS_ERROR',
        'RELEASED_NO_SUBMISSION', 'COMPLETED'
    )),
    submission_started boolean NOT NULL DEFAULT false,
    spooler_observed boolean NOT NULL DEFAULT false,
    brother_active_observed boolean NOT NULL DEFAULT false,
    spooler_cleared boolean NOT NULL DEFAULT false,
    ready_idle_observed boolean NOT NULL DEFAULT false,
    recovery_state text NOT NULL CHECK (recovery_state IN (
        'PRE_SUBMISSION', 'PRINTING', 'WAITING_MEDIA',
        'VERIFYING_COMPLETION', 'RECONCILIATION_REQUIRED', 'COMPLETED'
    )),
    details jsonb NOT NULL DEFAULT '{}'::jsonb
        CHECK (jsonb_typeof(details) = 'object'),
    first_seen_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    last_seen_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    completed_at timestamptz,
    PRIMARY KEY (workload_type, batch_id),
    CONSTRAINT ck_label_print_recovery_completed CHECK (
        (recovery_state = 'COMPLETED' AND completed_at IS NOT NULL)
        OR (recovery_state <> 'COMPLETED' AND completed_at IS NULL)
    )
);

CREATE TABLE ops.label_print_batch_recovery_event (
    label_print_batch_recovery_event_id bigint
        GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    workload_type text NOT NULL,
    batch_id bigint NOT NULL,
    event_name text NOT NULL,
    details jsonb NOT NULL CHECK (jsonb_typeof(details) = 'object'),
    observed_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    FOREIGN KEY (workload_type, batch_id)
        REFERENCES ops.label_print_batch_recovery(workload_type, batch_id)
        ON DELETE RESTRICT
);

COMMENT ON TABLE ops.label_print_batch_recovery IS
    'Durable restart evidence. It supports safe continuation decisions but never proves a physical label solely from PrintOut or queue clearing.';

CREATE TABLE ops.label_print_incident (
    incident_key text PRIMARY KEY
        CHECK (incident_key ~ '^[A-Za-z0-9_.:-]{3,200}$'),
    generation integer NOT NULL DEFAULT 1 CHECK (generation > 0),
    incident_kind text NOT NULL CHECK (incident_kind IN (
        'PREFLIGHT_MEDIA', 'ACTIVE_MEDIA', 'FAILED_BATCH',
        'OBSERVATION', 'SERVICE_HEARTBEAT'
    )),
    workload_type text NOT NULL CHECK (workload_type IN (
        'DISPLAY', 'CONTAINER', 'CONTROLLER', 'SYSTEM'
    )),
    printer_name text NOT NULL,
    host_name text NOT NULL,
    batch_id bigint,
    pending_count integer NOT NULL DEFAULT 0 CHECK (pending_count >= 0),
    status text NOT NULL CHECK (status IN ('ACTIVE', 'RESOLVED')),
    severity text NOT NULL CHECK (severity IN ('WARNING', 'ERROR', 'CRITICAL')),
    first_seen_at timestamptz NOT NULL,
    last_seen_at timestamptz NOT NULL,
    resolved_at timestamptz,
    alert_available_at timestamptz NOT NULL,
    operator_action text,
    recovery_state text NOT NULL,
    details jsonb NOT NULL CHECK (jsonb_typeof(details) = 'object'),
    CONSTRAINT ck_label_print_incident_resolution CHECK (
        (status = 'ACTIVE' AND resolved_at IS NULL)
        OR (status = 'RESOLVED' AND resolved_at IS NOT NULL)
    )
);

CREATE TABLE ops.label_print_notification_admin (
    person_id integer PRIMARY KEY REFERENCES ref.person(person_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    active_flag boolean NOT NULL DEFAULT false,
    activated_at timestamptz,
    CONSTRAINT ck_label_print_admin_activation CHECK (
        (active_flag AND activated_at IS NOT NULL)
        OR (NOT active_flag)
    )
);

CREATE TABLE ops.label_print_notification_outbox (
    event_key text PRIMARY KEY CHECK (length(event_key) BETWEEN 10 AND 500),
    incident_key text REFERENCES ops.label_print_incident(incident_key),
    incident_generation integer NOT NULL,
    transition text NOT NULL CHECK (
        transition IN ('ACTIVE', 'RESOLVED', 'SUCCESS')
    ),
    audience text NOT NULL CHECK (audience IN ('REQUESTER', 'ADMIN')),
    recipient_person_id integer REFERENCES ref.person(person_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    recipient_email text,
    message_kind text NOT NULL CHECK (message_kind IN (
        'REQUESTER_ACTIVE', 'REQUESTER_RESOLVED',
        'REQUESTER_SUCCESS',
        'ADMIN_ACTIVE', 'ADMIN_RESOLVED'
    )),
    payload jsonb NOT NULL CHECK (jsonb_typeof(payload) = 'object'),
    available_at timestamptz NOT NULL,
    attempt_count integer NOT NULL DEFAULT 0 CHECK (attempt_count BETWEEN 0 AND 3),
    max_attempts integer NOT NULL DEFAULT 3 CHECK (max_attempts BETWEEN 1 AND 3),
    delivery_status text NOT NULL CHECK (delivery_status IN (
        'QUEUED', 'CANCELLED', 'MISSING_RECIPIENT', 'IN_PROGRESS', 'SMTP_ACCEPTED',
        'FAILED_BEFORE_DATA', 'REJECTED', 'UNKNOWN'
    )),
    created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    delivered_at timestamptz,
    failure_reason text
);
CREATE INDEX idx_label_print_outbox_ready
    ON ops.label_print_notification_outbox(available_at, event_key)
    WHERE delivery_status = 'QUEUED';

CREATE TABLE ops.label_print_mail_delivery (
    delivery_key text PRIMARY KEY CHECK (delivery_key ~ '^[a-f0-9]{64}$'),
    event_key text NOT NULL
        REFERENCES ops.label_print_notification_outbox(event_key),
    attempt_number integer NOT NULL CHECK (attempt_number BETWEEN 1 AND 3),
    recipient_email text NOT NULL,
    content jsonb NOT NULL CHECK (jsonb_typeof(content) = 'object'),
    status text NOT NULL CHECK (status IN (
        'IN_PROGRESS', 'SMTP_ACCEPTED', 'FAILED_BEFORE_DATA',
        'REJECTED', 'UNKNOWN'
    )),
    evidence text,
    claimed_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    finished_at timestamptz,
    UNIQUE (event_key, attempt_number)
);

CREATE FUNCTION ops.label_print_event_payload(
    p_incident ops.label_print_incident,
    p_status text,
    p_request_items jsonb DEFAULT NULL
) RETURNS jsonb
LANGUAGE sql
STABLE
AS $payload$
    SELECT jsonb_strip_nulls(jsonb_build_object(
        'incident_key', p_incident.incident_key,
        'workload_type', p_incident.workload_type,
        'status', p_status,
        'printer', p_incident.printer_name,
        'host', p_incident.host_name,
        'batch_id', p_incident.batch_id,
        'pending_count', p_incident.pending_count,
        'first_seen_at', p_incident.first_seen_at,
        'last_seen_at', p_incident.last_seen_at,
        'operator_action', p_incident.operator_action,
        'recovery_state', p_incident.recovery_state,
        'details', p_incident.details,
        'request_items', p_request_items
    ))
$payload$;

CREATE FUNCTION ops.label_print_queue_active_events(
    p_incident_key text
) RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, ops, ref
AS $queue$
DECLARE
    v_incident ops.label_print_incident%ROWTYPE;
    v_count integer := 0;
    v_added integer := 0;
BEGIN
    SELECT * INTO STRICT v_incident
    FROM ops.label_print_incident
    WHERE incident_key = p_incident_key
      AND status = 'ACTIVE';

    INSERT INTO ops.label_print_notification_outbox (
        event_key, incident_key, incident_generation, transition, audience,
        recipient_person_id, recipient_email, message_kind, payload,
        available_at, delivery_status
    )
    SELECT
        v_incident.incident_key || ':g' || v_incident.generation ||
            ':active:admin:' || a.person_id,
        v_incident.incident_key, v_incident.generation, 'ACTIVE', 'ADMIN',
        a.person_id, p.email, 'ADMIN_ACTIVE',
        ops.label_print_event_payload(v_incident, 'ACTIVE'),
        v_incident.alert_available_at,
        CASE WHEN nullif(btrim(p.email), '') IS NULL
             THEN 'MISSING_RECIPIENT' ELSE 'QUEUED' END
    FROM ops.label_print_notification_admin a
    JOIN ref.person p ON p.person_id = a.person_id
    WHERE a.active_flag AND p.active_flag
      AND v_incident.incident_kind IN (
          'FAILED_BATCH', 'OBSERVATION', 'SERVICE_HEARTBEAT'
      )
    ON CONFLICT (event_key) DO NOTHING;
    GET DIAGNOSTICS v_count = ROW_COUNT;

    WITH scoped AS (
        SELECT r.requester_person_id,
               jsonb_agg(
                   r.workload_type || ':' || r.asset_id
                   ORDER BY r.asset_id
               ) AS request_items
        FROM ops.label_print_request r
        WHERE r.requester_verified
          AND r.requester_person_id IS NOT NULL
          AND r.workload_type = v_incident.workload_type
          AND r.status IN ('PENDING', 'BATCHED')
          AND (v_incident.batch_id IS NULL OR r.batch_id = v_incident.batch_id)
        GROUP BY r.requester_person_id
    )
    INSERT INTO ops.label_print_notification_outbox (
        event_key, incident_key, incident_generation, transition, audience,
        recipient_person_id, recipient_email, message_kind, payload,
        available_at, delivery_status
    )
    SELECT
        v_incident.incident_key || ':g' || v_incident.generation ||
            ':active:requester:' || s.requester_person_id,
        v_incident.incident_key, v_incident.generation,
        'ACTIVE', 'REQUESTER', s.requester_person_id, p.email,
        'REQUESTER_ACTIVE',
        ops.label_print_event_payload(v_incident, 'ACTIVE', s.request_items),
        v_incident.alert_available_at,
        CASE WHEN nullif(btrim(p.email), '') IS NULL
             THEN 'MISSING_RECIPIENT' ELSE 'QUEUED' END
    FROM scoped s
    JOIN ref.person p ON p.person_id = s.requester_person_id
    WHERE p.active_flag
      AND v_incident.incident_kind IN (
          'PREFLIGHT_MEDIA', 'ACTIVE_MEDIA'
      )
    ON CONFLICT (event_key) DO NOTHING;
    GET DIAGNOSTICS v_added = ROW_COUNT;
    v_count := v_count + v_added;
    RETURN v_count;
END
$queue$;

CREATE FUNCTION ops.label_print_queue_success_events(
    p_workload_type text,
    p_batch_id bigint
) RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, ops, ref
AS $success$
DECLARE v_count integer;
BEGIN
    IF p_workload_type NOT IN ('DISPLAY', 'CONTAINER', 'CONTROLLER')
       OR p_batch_id <= 0 THEN
        RAISE EXCEPTION 'Invalid successful Label Print batch';
    END IF;

    INSERT INTO ops.label_print_notification_outbox (
        event_key, incident_key, incident_generation, transition, audience,
        recipient_person_id, recipient_email, message_kind, payload,
        available_at, delivery_status
    )
    SELECT
        'print-success:' || lower(p_workload_type) || ':' || p_batch_id ||
            ':requester:' || r.requester_person_id,
        NULL, 0, 'SUCCESS', 'REQUESTER', r.requester_person_id, p.email,
        'REQUESTER_SUCCESS',
        jsonb_build_object(
            'event_key',
                'print-success:' || lower(p_workload_type) || ':' || p_batch_id,
            'workload_type', p_workload_type,
            'status', 'READY',
            'batch_id', p_batch_id,
            'request_items', jsonb_agg(
                r.workload_type || ':' || r.asset_id ORDER BY r.asset_id
            )
        ),
        clock_timestamp(),
        CASE WHEN nullif(btrim(p.email), '') IS NULL
             THEN 'MISSING_RECIPIENT' ELSE 'QUEUED' END
    FROM ops.label_print_request r
    JOIN ref.person p ON p.person_id = r.requester_person_id
    WHERE r.workload_type = p_workload_type
      AND r.batch_id = p_batch_id
      AND r.status = 'COMPLETED'
      AND r.requester_verified
      AND r.requester_person_id IS NOT NULL
      AND p.active_flag
    GROUP BY r.requester_person_id, p.email
    ON CONFLICT (event_key) DO NOTHING;
    GET DIAGNOSTICS v_count = ROW_COUNT;
    RETURN v_count;
END
$success$;

CREATE FUNCTION ops.label_print_incident_upsert(
    p_incident_key text,
    p_incident_kind text,
    p_workload_type text,
    p_printer_name text,
    p_host_name text,
    p_batch_id bigint,
    p_pending_count integer,
    p_severity text,
    p_alert_delay_seconds integer,
    p_operator_action text,
    p_recovery_state text,
    p_details jsonb
) RETURNS TABLE(incident_status text, incident_generation integer, queued_events integer)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, ops
AS $upsert$
DECLARE
    v_incident ops.label_print_incident%ROWTYPE;
    v_new_transition boolean := false;
    v_queued integer := 0;
    v_now timestamptz := clock_timestamp();
BEGIN
    IF p_incident_key !~ '^[A-Za-z0-9_.:-]{3,200}$'
       OR p_incident_kind NOT IN (
           'PREFLIGHT_MEDIA', 'ACTIVE_MEDIA', 'FAILED_BATCH',
           'OBSERVATION', 'SERVICE_HEARTBEAT'
       )
       OR p_workload_type NOT IN (
           'DISPLAY', 'CONTAINER', 'CONTROLLER', 'SYSTEM'
       )
       OR p_severity NOT IN ('WARNING', 'ERROR', 'CRITICAL')
       OR p_pending_count < 0
       OR p_alert_delay_seconds NOT BETWEEN 0 AND 3600
       OR jsonb_typeof(p_details) IS DISTINCT FROM 'object' THEN
        RAISE EXCEPTION 'Invalid Label Print incident input';
    END IF;

    SELECT * INTO v_incident
    FROM ops.label_print_incident
    WHERE incident_key = p_incident_key
    FOR UPDATE;

    IF NOT FOUND THEN
        INSERT INTO ops.label_print_incident (
            incident_key, incident_kind, workload_type, printer_name,
            host_name, batch_id, pending_count, status, severity,
            first_seen_at, last_seen_at, alert_available_at,
            operator_action, recovery_state, details
        ) VALUES (
            p_incident_key, p_incident_kind, p_workload_type, p_printer_name,
            p_host_name, p_batch_id, p_pending_count, 'ACTIVE', p_severity,
            v_now, v_now, v_now + make_interval(secs => p_alert_delay_seconds),
            p_operator_action, p_recovery_state, p_details
        ) RETURNING * INTO v_incident;
        v_new_transition := true;
    ELSIF v_incident.status = 'RESOLVED' THEN
        UPDATE ops.label_print_incident
        SET generation = generation + 1,
            incident_kind = p_incident_kind,
            workload_type = p_workload_type,
            printer_name = p_printer_name,
            host_name = p_host_name,
            batch_id = p_batch_id,
            pending_count = p_pending_count,
            status = 'ACTIVE',
            severity = p_severity,
            first_seen_at = v_now,
            last_seen_at = v_now,
            resolved_at = NULL,
            alert_available_at = v_now + make_interval(secs => p_alert_delay_seconds),
            operator_action = p_operator_action,
            recovery_state = p_recovery_state,
            details = p_details
        WHERE incident_key = p_incident_key
        RETURNING * INTO v_incident;
        v_new_transition := true;
    ELSE
        UPDATE ops.label_print_incident
        SET last_seen_at = v_now,
            batch_id = p_batch_id,
            pending_count = p_pending_count,
            severity = p_severity,
            operator_action = p_operator_action,
            recovery_state = p_recovery_state,
            details = p_details
        WHERE incident_key = p_incident_key
        RETURNING * INTO v_incident;
    END IF;

    IF v_new_transition THEN
        v_queued := ops.label_print_queue_active_events(p_incident_key);
    END IF;
    RETURN QUERY SELECT v_incident.status, v_incident.generation, v_queued;
END
$upsert$;

CREATE FUNCTION ops.label_print_incident_resolve(
    p_incident_key text,
    p_recovery_state text,
    p_details jsonb
) RETURNS TABLE(incident_status text, queued_events integer)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, ops
AS $resolve$
DECLARE
    v_incident ops.label_print_incident%ROWTYPE;
    v_count integer := 0;
BEGIN
    IF jsonb_typeof(p_details) IS DISTINCT FROM 'object' THEN
        RAISE EXCEPTION 'Resolution details must be a JSON object';
    END IF;
    UPDATE ops.label_print_incident
    SET status = 'RESOLVED',
        resolved_at = clock_timestamp(),
        last_seen_at = clock_timestamp(),
        recovery_state = p_recovery_state,
        details = details || p_details
    WHERE incident_key = p_incident_key
      AND status = 'ACTIVE'
    RETURNING * INTO v_incident;
    IF NOT FOUND THEN
        RETURN QUERY SELECT 'NO_ACTIVE_INCIDENT'::text, 0;
        RETURN;
    END IF;

    UPDATE ops.label_print_notification_outbox
    SET delivery_status = 'CANCELLED',
        failure_reason = 'incident_resolved_before_send'
    WHERE incident_key = v_incident.incident_key
      AND incident_generation = v_incident.generation
      AND transition = 'ACTIVE'
      AND delivery_status = 'QUEUED';

    INSERT INTO ops.label_print_notification_outbox (
        event_key, incident_key, incident_generation, transition, audience,
        recipient_person_id, recipient_email, message_kind, payload,
        available_at, delivery_status
    )
    SELECT
        v_incident.incident_key || ':g' || v_incident.generation ||
            ':resolved:' || lower(active_event.audience) || ':' ||
            active_event.recipient_person_id,
        v_incident.incident_key, v_incident.generation, 'RESOLVED',
        active_event.audience, active_event.recipient_person_id,
        active_event.recipient_email,
        CASE active_event.audience
            WHEN 'ADMIN' THEN 'ADMIN_RESOLVED'
            ELSE 'REQUESTER_RESOLVED'
        END,
        ops.label_print_event_payload(
            v_incident,
            'RESOLVED',
            active_event.payload -> 'request_items'
        ),
        clock_timestamp(), 'QUEUED'
    FROM ops.label_print_notification_outbox active_event
    WHERE active_event.incident_key = v_incident.incident_key
      AND active_event.incident_generation = v_incident.generation
      AND active_event.transition = 'ACTIVE'
      AND active_event.delivery_status = 'SMTP_ACCEPTED'
    ON CONFLICT (event_key) DO NOTHING;
    GET DIAGNOSTICS v_count = ROW_COUNT;
    RETURN QUERY SELECT v_incident.status, v_count;
END
$resolve$;

CREATE FUNCTION ops.label_print_heartbeat(
    p_service_version text,
    p_process_id integer,
    p_state text,
    p_details jsonb
) RETURNS timestamptz
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, ops
AS $heartbeat$
DECLARE v_now timestamptz := clock_timestamp();
BEGIN
    IF nullif(btrim(p_service_version), '') IS NULL
       OR p_process_id <= 0
       OR p_state NOT IN ('STARTING', 'IDLE', 'BUSY', 'BLOCKED')
       OR jsonb_typeof(p_details) IS DISTINCT FROM 'object' THEN
        RAISE EXCEPTION 'Invalid Label Print heartbeat';
    END IF;
    INSERT INTO ops.label_print_service_heartbeat (
        instance_key, service_version, process_id, state, details, last_seen_at
    ) VALUES (
        'PRINT-SERVER', p_service_version, p_process_id, p_state, p_details, v_now
    )
    ON CONFLICT (instance_key) DO UPDATE
    SET service_version = EXCLUDED.service_version,
        process_id = EXCLUDED.process_id,
        state = EXCLUDED.state,
        details = EXCLUDED.details,
        last_seen_at = EXCLUDED.last_seen_at;
    RETURN v_now;
END
$heartbeat$;

CREATE FUNCTION ops.label_print_recovery_checkpoint(
    p_workload_type text,
    p_batch_id bigint,
    p_event_name text,
    p_details jsonb
) RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, ops
AS $checkpoint$
DECLARE
    v_state text;
    v_existing_state text;
    v_now timestamptz := clock_timestamp();
BEGIN
    IF p_workload_type NOT IN ('DISPLAY', 'CONTAINER', 'CONTROLLER')
       OR p_batch_id <= 0
       OR p_event_name NOT IN (
           'BATCH_CREATED', 'SUBMISSION_STARTED', 'SPOOLER_OBSERVED',
           'BROTHER_ACTIVE', 'SPOOLER_CLEARED', 'READY_IDLE',
           'RECOVERABLE_MEDIA', 'AMBIGUOUS_ERROR',
           'RELEASED_NO_SUBMISSION', 'COMPLETED'
       )
       OR jsonb_typeof(p_details) IS DISTINCT FROM 'object' THEN
        RAISE EXCEPTION 'Invalid Label Print recovery checkpoint';
    END IF;

    SELECT recovery_state INTO v_existing_state
    FROM ops.label_print_batch_recovery
    WHERE workload_type = p_workload_type
      AND batch_id = p_batch_id
    FOR UPDATE;
    IF v_existing_state = 'COMPLETED' AND p_event_name <> 'COMPLETED' THEN
        RAISE EXCEPTION 'Completed Label Print recovery evidence is immutable';
    END IF;

    v_state := CASE p_event_name
        WHEN 'BATCH_CREATED' THEN 'PRE_SUBMISSION'
        WHEN 'RECOVERABLE_MEDIA' THEN 'WAITING_MEDIA'
        WHEN 'SPOOLER_CLEARED' THEN 'VERIFYING_COMPLETION'
        WHEN 'READY_IDLE' THEN 'VERIFYING_COMPLETION'
        WHEN 'AMBIGUOUS_ERROR' THEN 'RECONCILIATION_REQUIRED'
        WHEN 'RELEASED_NO_SUBMISSION' THEN 'COMPLETED'
        WHEN 'COMPLETED' THEN 'COMPLETED'
        ELSE 'PRINTING'
    END;

    INSERT INTO ops.label_print_batch_recovery (
        workload_type, batch_id, last_event,
        submission_started, spooler_observed, brother_active_observed,
        spooler_cleared, ready_idle_observed, recovery_state,
        details, first_seen_at, last_seen_at, completed_at
    ) VALUES (
        p_workload_type, p_batch_id, p_event_name,
        p_event_name IN (
            'SUBMISSION_STARTED', 'SPOOLER_OBSERVED', 'BROTHER_ACTIVE',
            'SPOOLER_CLEARED', 'READY_IDLE', 'RECOVERABLE_MEDIA',
            'AMBIGUOUS_ERROR', 'COMPLETED'
        ),
        p_event_name IN ('SPOOLER_OBSERVED', 'SPOOLER_CLEARED', 'COMPLETED'),
        p_event_name = 'BROTHER_ACTIVE',
        p_event_name IN ('SPOOLER_CLEARED', 'COMPLETED'),
        p_event_name IN ('READY_IDLE', 'COMPLETED'),
        v_state, p_details, v_now, v_now,
        CASE WHEN p_event_name IN ('RELEASED_NO_SUBMISSION', 'COMPLETED')
             THEN v_now ELSE NULL END
    )
    ON CONFLICT (workload_type, batch_id) DO UPDATE
    SET last_event = EXCLUDED.last_event,
        submission_started =
            ops.label_print_batch_recovery.submission_started
            OR EXCLUDED.submission_started,
        spooler_observed =
            ops.label_print_batch_recovery.spooler_observed
            OR EXCLUDED.spooler_observed,
        brother_active_observed =
            ops.label_print_batch_recovery.brother_active_observed
            OR EXCLUDED.brother_active_observed,
        spooler_cleared =
            ops.label_print_batch_recovery.spooler_cleared
            OR EXCLUDED.spooler_cleared,
        ready_idle_observed =
            ops.label_print_batch_recovery.ready_idle_observed
            OR EXCLUDED.ready_idle_observed,
        recovery_state = EXCLUDED.recovery_state,
        details = ops.label_print_batch_recovery.details || EXCLUDED.details,
        last_seen_at = EXCLUDED.last_seen_at,
        completed_at = EXCLUDED.completed_at;

    INSERT INTO ops.label_print_batch_recovery_event (
        workload_type, batch_id, event_name, details, observed_at
    ) VALUES (
        p_workload_type, p_batch_id, p_event_name, p_details, v_now
    );
    RETURN v_state;
END
$checkpoint$;

CREATE FUNCTION ops.label_print_recovery_candidates()
RETURNS TABLE(
    workload_type text,
    batch_id bigint,
    last_event text,
    submission_started boolean,
    spooler_observed boolean,
    brother_active_observed boolean,
    spooler_cleared boolean,
    ready_idle_observed boolean,
    recovery_state text,
    details jsonb,
    last_seen_at timestamptz
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, ops
AS $recovery_candidates$
    SELECT r.workload_type, r.batch_id, r.last_event,
           r.submission_started, r.spooler_observed,
           r.brother_active_observed, r.spooler_cleared,
           r.ready_idle_observed, r.recovery_state, r.details, r.last_seen_at
    FROM ops.label_print_batch_recovery r
    WHERE r.recovery_state <> 'COMPLETED'
    ORDER BY r.first_seen_at
$recovery_candidates$;

CREATE FUNCTION ops.label_print_release_batch_requests(
    p_workload_type text,
    p_batch_id bigint
) RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, ops
AS $release$
DECLARE v_count integer;
BEGIN
    IF p_workload_type NOT IN ('DISPLAY', 'CONTAINER', 'CONTROLLER')
       OR p_batch_id <= 0 THEN
        RAISE EXCEPTION 'Invalid Label Print batch release';
    END IF;
    UPDATE ops.label_print_request
    SET status = 'PENDING', batch_id = NULL
    WHERE workload_type = p_workload_type
      AND batch_id = p_batch_id
      AND status = 'BATCHED';
    GET DIAGNOSTICS v_count = ROW_COUNT;
    RETURN v_count;
END
$release$;

CREATE FUNCTION ops.label_print_watchdog_evaluate(p_stale_seconds integer)
RETURNS TABLE(watchdog_state text, last_seen_at timestamptz, queued_events integer)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, ops
AS $watchdog$
DECLARE
    v_heartbeat ops.label_print_service_heartbeat%ROWTYPE;
    v_result record;
BEGIN
    IF p_stale_seconds NOT BETWEEN 30 AND 3600 THEN
        RAISE EXCEPTION 'Invalid heartbeat threshold';
    END IF;
    SELECT * INTO v_heartbeat
    FROM ops.label_print_service_heartbeat
    WHERE instance_key = 'PRINT-SERVER';

    IF NOT FOUND
       OR v_heartbeat.last_seen_at < clock_timestamp() -
            make_interval(secs => p_stale_seconds) THEN
        SELECT * INTO v_result FROM ops.label_print_incident_upsert(
            'service:PRINT-SERVER:heartbeat-stale',
            'SERVICE_HEARTBEAT', 'SYSTEM', 'N/A', 'PRINT-SERVER', NULL, 0,
            'CRITICAL', 0,
            'Check the MSB Label Service Scheduled Task and PRINT-SERVER host.',
            'WATCHDOG_ACTIVE',
            jsonb_build_object(
                'stale_seconds', p_stale_seconds,
                'last_seen_at', v_heartbeat.last_seen_at
            )
        );
        RETURN QUERY SELECT 'STALE'::text, v_heartbeat.last_seen_at,
            v_result.queued_events;
    ELSE
        SELECT * INTO v_result FROM ops.label_print_incident_resolve(
            'service:PRINT-SERVER:heartbeat-stale',
            'HEARTBEAT_RECOVERED',
            jsonb_build_object('last_seen_at', v_heartbeat.last_seen_at)
        );
        RETURN QUERY SELECT 'HEALTHY'::text, v_heartbeat.last_seen_at,
            v_result.queued_events;
    END IF;
END
$watchdog$;

CREATE FUNCTION ops.label_print_mail_candidates()
RETURNS TABLE(
    event_key text,
    attempt_count integer,
    recipient_email text,
    message_kind text,
    payload jsonb
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, ops
AS $candidates$
    SELECT o.event_key, o.attempt_count,
           o.recipient_email, o.message_kind, o.payload
    FROM ops.label_print_notification_outbox o
    WHERE o.delivery_status = 'QUEUED'
      AND o.available_at <= clock_timestamp()
    ORDER BY o.available_at, o.event_key
    LIMIT 50
$candidates$;

CREATE FUNCTION ops.label_print_mail_claim(
    p_delivery_key text,
    p_event_key text,
    p_attempt_number integer,
    p_recipient text,
    p_content jsonb
) RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, ops
AS $claim$
DECLARE v_outbox ops.label_print_notification_outbox%ROWTYPE;
BEGIN
    SELECT * INTO v_outbox
    FROM ops.label_print_notification_outbox
    WHERE event_key = p_event_key
    FOR UPDATE;
    IF NOT FOUND OR v_outbox.delivery_status <> 'QUEUED'
       OR v_outbox.available_at > clock_timestamp() THEN
        RETURN false;
    END IF;
    IF p_attempt_number <> v_outbox.attempt_count + 1
       OR p_attempt_number > v_outbox.max_attempts THEN
        RAISE EXCEPTION 'Invalid Label Print mail attempt number';
    END IF;
    IF lower(v_outbox.recipient_email) IS DISTINCT FROM lower(p_recipient)
       OR nullif(btrim(p_recipient), '') IS NULL THEN
        RAISE EXCEPTION 'Mail recipient differs from queued Label Print event';
    END IF;
    IF jsonb_typeof(p_content) IS DISTINCT FROM 'object'
       OR NOT (p_content ?& ARRAY[
           'subject', 'text', 'html', 'template_sha256'
       ]) THEN
        RAISE EXCEPTION 'Rendered immutable Label Print mail content required';
    END IF;
    INSERT INTO ops.label_print_mail_delivery (
        delivery_key, event_key, attempt_number,
        recipient_email, content, status
    ) VALUES (
        p_delivery_key, p_event_key, p_attempt_number,
        p_recipient, p_content, 'IN_PROGRESS'
    ) ON CONFLICT DO NOTHING;
    IF NOT FOUND THEN RETURN false; END IF;
    UPDATE ops.label_print_notification_outbox
    SET delivery_status = 'IN_PROGRESS',
        attempt_count = p_attempt_number
    WHERE event_key = p_event_key;
    RETURN true;
END
$claim$;

CREATE FUNCTION ops.label_print_mail_finish(
    p_delivery_key text,
    p_status text,
    p_evidence text
) RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, ops
AS $finish$
DECLARE v_event_key text;
BEGIN
    IF p_status NOT IN (
        'SMTP_ACCEPTED', 'FAILED_BEFORE_DATA', 'REJECTED', 'UNKNOWN'
    ) OR p_evidence IS NULL OR length(p_evidence) > 100 THEN
        RAISE EXCEPTION 'Invalid Label Print mail outcome';
    END IF;
    UPDATE ops.label_print_mail_delivery
    SET status = p_status,
        evidence = p_evidence,
        finished_at = clock_timestamp()
    WHERE delivery_key = p_delivery_key
      AND status = 'IN_PROGRESS'
    RETURNING event_key INTO v_event_key;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Mail attempt is absent or already finished';
    END IF;
    UPDATE ops.label_print_notification_outbox
    SET delivery_status = CASE
            WHEN p_status = 'FAILED_BEFORE_DATA'
             AND attempt_count < max_attempts THEN 'QUEUED'
            ELSE p_status
        END,
        available_at = CASE
            WHEN p_status = 'FAILED_BEFORE_DATA'
             AND attempt_count < max_attempts
            THEN clock_timestamp() + make_interval(secs => 60 * attempt_count)
            ELSE available_at
        END,
        delivered_at = CASE
            WHEN p_status = 'SMTP_ACCEPTED' THEN clock_timestamp()
            ELSE NULL
        END,
        failure_reason = CASE
            WHEN p_status = 'SMTP_ACCEPTED' THEN NULL
            WHEN p_status = 'FAILED_BEFORE_DATA'
             AND attempt_count < max_attempts
            THEN 'bounded_retry_scheduled_after_proven_no_send'
            ELSE p_evidence
        END
    WHERE event_key = v_event_key;
    RETURN true;
END
$finish$;

CREATE FUNCTION ops.label_print_mail_render_failure(p_event_key text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, ops
AS $render_failure$
BEGIN
    UPDATE ops.label_print_notification_outbox o
    SET delivery_status = 'FAILED_BEFORE_DATA',
        failure_reason = 'template_or_envelope_invalid_no_send'
    WHERE o.event_key = p_event_key
      AND o.delivery_status = 'QUEUED'
      AND NOT EXISTS (
          SELECT 1 FROM ops.label_print_mail_delivery d
          WHERE d.event_key = p_event_key
      );
    RETURN FOUND;
END
$render_failure$;

REVOKE ALL ON ops.label_print_request,
    ops.label_print_service_heartbeat,
    ops.label_print_batch_recovery,
    ops.label_print_batch_recovery_event,
    ops.label_print_incident,
    ops.label_print_notification_admin,
    ops.label_print_notification_outbox,
    ops.label_print_mail_delivery FROM PUBLIC;
REVOKE ALL ON FUNCTION ops.label_print_bind_batch_requests(text, bigint),
    ops.label_print_heartbeat(text, integer, text, jsonb),
    ops.label_print_queue_success_events(text, bigint),
    ops.label_print_incident_upsert(
        text, text, text, text, text, bigint, integer, text,
        integer, text, text, jsonb
    ),
    ops.label_print_incident_resolve(text, text, jsonb),
    ops.label_print_recovery_checkpoint(text, bigint, text, jsonb),
    ops.label_print_recovery_candidates(),
    ops.label_print_release_batch_requests(text, bigint),
    ops.label_print_watchdog_evaluate(integer),
    ops.label_print_mail_candidates(),
    ops.label_print_mail_claim(text, text, integer, text, jsonb),
    ops.label_print_mail_finish(text, text, text),
    ops.label_print_mail_render_failure(text),
    ops.label_print_event_payload(ops.label_print_incident, text, jsonb),
    ops.label_print_queue_active_events(text)
FROM PUBLIC;

GRANT USAGE ON SCHEMA ops TO printservice, label_print_mail;
GRANT EXECUTE ON FUNCTION ops.label_print_bind_batch_requests(text, bigint),
    ops.label_print_heartbeat(text, integer, text, jsonb),
    ops.label_print_queue_success_events(text, bigint),
    ops.label_print_recovery_checkpoint(text, bigint, text, jsonb),
    ops.label_print_recovery_candidates(),
    ops.label_print_release_batch_requests(text, bigint),
    ops.label_print_incident_upsert(
        text, text, text, text, text, bigint, integer, text,
        integer, text, text, jsonb
    ),
    ops.label_print_incident_resolve(text, text, jsonb)
TO printservice;

GRANT EXECUTE ON FUNCTION ops.label_print_watchdog_evaluate(integer),
    ops.label_print_mail_candidates(),
    ops.label_print_mail_claim(text, text, integer, text, jsonb),
    ops.label_print_mail_finish(text, text, text),
    ops.label_print_mail_render_failure(text)
TO label_print_mail;

COMMIT;
