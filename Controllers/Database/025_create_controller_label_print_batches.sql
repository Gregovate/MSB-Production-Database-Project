/* ============================================================================
Controller label printing — execution batch contract
Issue: Gregovate/MSB_LabelPrintService#14
Revision: 2026-09-03 V0.1.0

Purpose:
  Add the Production Database objects required for LabelPrintService V4 to
  consume ref.controller.print_label safely.

Safety contract:
  - The browser continues to request labels only through
    ref.request_controller_label(text, bigint).
  - LabelPrintService snapshots the exact pending Controller IDs before print.
  - Only Controllers present in a successfully completed snapshot are cleared.
  - A failed preflight creates no batch.
  - A failed physical batch remains visible and leaves print_label set.
============================================================================ */

BEGIN;

DO $preflight$
DECLARE
    v_template_count integer;
BEGIN
    IF to_regclass('ref.controller') IS NULL THEN
        RAISE EXCEPTION 'ref.controller is required';
    END IF;
    IF to_regclass('ref.label_template') IS NULL THEN
        RAISE EXCEPTION 'ref.label_template is required';
    END IF;
    IF to_regclass('ref.person') IS NULL THEN
        RAISE EXCEPTION 'ref.person is required';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'printservice') THEN
        RAISE EXCEPTION 'Required role printservice does not exist';
    END IF;

    SELECT count(*)
      INTO v_template_count
    FROM ref.label_template
    WHERE label_template_code = 'QR_24MM_HORIZONTAL';

    IF v_template_count <> 1 THEN
        RAISE EXCEPTION
            'Expected exactly one QR_24MM_HORIZONTAL label template; found %',
            v_template_count;
    END IF;
END
$preflight$;

-- Controller permanent-ID labels all use the governed 24 mm QR family.
-- This is a controlled configuration backfill, not a user edit. Temporarily
-- suppress the row-touch trigger so the 177 existing Controller audit records
-- are not falsely rewritten as though an operator changed each Controller.
ALTER TABLE ref.controller DISABLE TRIGGER trg_controller_actor_update;

UPDATE ref.controller AS c
SET label_template_id = lt.label_template_id
FROM ref.label_template AS lt
WHERE lt.label_template_code = 'QR_24MM_HORIZONTAL'
  AND c.label_template_id IS NULL;

ALTER TABLE ref.controller ENABLE TRIGGER trg_controller_actor_update;

DO $template_assignment$
DECLARE
    v_invalid_count integer;
BEGIN
    SELECT count(*)
      INTO v_invalid_count
    FROM ref.controller AS c
    LEFT JOIN ref.label_template AS lt
      ON lt.label_template_id = c.label_template_id
    WHERE lt.label_template_code IS DISTINCT FROM 'QR_24MM_HORIZONTAL';

    IF v_invalid_count <> 0 THEN
        RAISE EXCEPTION
            'Every Controller must resolve to QR_24MM_HORIZONTAL; invalid rows=%',
            v_invalid_count;
    END IF;
END
$template_assignment$;

-- New Controller rows are created without an explicit label_template_id.
-- Resolve the accepted catalog row now and install its stable ID as the default.
DO $default_template$
DECLARE
    v_label_template_id integer;
BEGIN
    SELECT label_template_id
      INTO STRICT v_label_template_id
    FROM ref.label_template
    WHERE label_template_code = 'QR_24MM_HORIZONTAL';

    EXECUTE format(
        'ALTER TABLE ref.controller ALTER COLUMN label_template_id SET DEFAULT %s',
        v_label_template_id
    );
END
$default_template$;

CREATE TABLE ops.controller_label_batch (
    controller_label_batch_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    batch_started_at timestamptz NOT NULL DEFAULT now(),
    batch_completed_at timestamptz,
    started_by_person_id integer,
    started_by_text text,
    label_template_id integer NOT NULL,
    status text NOT NULL DEFAULT 'PENDING',
    notes text,

    CONSTRAINT fk_controller_label_batch_person
        FOREIGN KEY (started_by_person_id)
        REFERENCES ref.person(person_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_controller_label_batch_template
        FOREIGN KEY (label_template_id)
        REFERENCES ref.label_template(label_template_id),
    CONSTRAINT ck_controller_label_batch_status
        CHECK (status IN ('PENDING', 'PRINTING', 'COMPLETED', 'FAILED'))
);

CREATE INDEX idx_controller_label_batch_status
    ON ops.controller_label_batch(status);

CREATE TABLE ops.controller_label_batch_item (
    controller_label_batch_item_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    controller_label_batch_id bigint NOT NULL,
    controller_id bigint NOT NULL,
    qr_url text NOT NULL,
    line1 text NOT NULL,
    printed_flag boolean NOT NULL DEFAULT false,
    printed_at timestamptz,

    CONSTRAINT fk_controller_label_batch_item_batch
        FOREIGN KEY (controller_label_batch_id)
        REFERENCES ops.controller_label_batch(controller_label_batch_id)
        ON DELETE CASCADE,
    CONSTRAINT fk_controller_label_batch_item_controller
        FOREIGN KEY (controller_id)
        REFERENCES ref.controller(controller_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT uq_controller_label_batch_item_batch_controller
        UNIQUE (controller_label_batch_id, controller_id),
    CONSTRAINT ck_controller_label_batch_item_qr_url
        CHECK (qr_url ~ '^https://db[.]sheboyganlights[.]org/scan/CTRL/[0-9]+$'),
    CONSTRAINT ck_controller_label_batch_item_line1
        CHECK (line1 ~ '^CTRL:[0-9]+$')
);

CREATE INDEX idx_controller_label_batch_item_batch
    ON ops.controller_label_batch_item(controller_label_batch_id);

COMMENT ON TABLE ops.controller_label_batch IS
    'Immutable execution-batch header for permanent Controller ID labels.';
COMMENT ON TABLE ops.controller_label_batch_item IS
    'Frozen Controller label render intent. LabelPrintService clears only Controllers in a successfully completed batch.';
COMMENT ON COLUMN ops.controller_label_batch_item.qr_url IS
    'Full phone-compatible QR payload: https://db.sheboyganlights.org/scan/CTRL/<controller_id>.';
COMMENT ON COLUMN ops.controller_label_batch_item.line1 IS
    'Visible permanent Controller identity: CTRL:<controller_id>.';

GRANT SELECT ON ref.controller TO printservice;
GRANT UPDATE (
    print_label,
    label_print_count_cached,
    label_print_last_at_cached,
    label_print_last_by_cached_id
) ON ref.controller TO printservice;
GRANT SELECT ON ref.label_template TO printservice;

GRANT SELECT, INSERT, UPDATE, DELETE
    ON ops.controller_label_batch TO printservice;
GRANT SELECT, INSERT, UPDATE, DELETE
    ON ops.controller_label_batch_item TO printservice;
GRANT SELECT, USAGE
    ON SEQUENCE ops.controller_label_batch_controller_label_batch_id_seq
    TO printservice;
GRANT SELECT, USAGE
    ON SEQUENCE ops.controller_label_batch_item_controller_label_batch_item_id_seq
    TO printservice;

COMMIT;

SELECT
    count(*) FILTER (WHERE c.label_template_id IS NULL)
        AS controllers_without_template,
    count(*) FILTER (
        WHERE lt.label_template_code = 'QR_24MM_HORIZONTAL'
    ) AS controllers_with_24mm_template,
    count(*) FILTER (WHERE c.print_label) AS pending_controller_requests
FROM ref.controller AS c
LEFT JOIN ref.label_template AS lt
  ON lt.label_template_id = c.label_template_id;

SELECT
    to_regclass('ops.controller_label_batch') AS controller_batch_table,
    to_regclass('ops.controller_label_batch_item') AS controller_batch_item_table,
    has_table_privilege('printservice', 'ref.controller', 'SELECT')
        AS printservice_can_read_controller,
    has_column_privilege('printservice', 'ref.controller', 'print_label', 'UPDATE')
        AS printservice_can_clear_request,
    has_table_privilege('printservice', 'ops.controller_label_batch', 'INSERT')
        AS printservice_can_create_batch,
    has_table_privilege('printservice', 'ops.controller_label_batch_item', 'INSERT')
        AS printservice_can_create_items;
