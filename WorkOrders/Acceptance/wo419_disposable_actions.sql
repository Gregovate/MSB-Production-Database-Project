-- #419 V0.3 disposable-only transaction/notification rehearsal infrastructure.
-- This is NOT a Production migration or a new master-ticket store.
-- Reuse native ops.work_order, ops.work_order_assignment and stage.work_order_intake.
-- Owns only disposable action history and no-send notification receipts.
BEGIN;
DO $$
BEGIN
 IF current_database() <> 'msb_wo419_preview'
    OR current_setting('msb.wo419_preview_authorized',true)
       IS DISTINCT FROM 'approved_disposable_clone'
    OR current_setting('msb.wo419_clone_write_token',true) !~ '^[a-f0-9]{48}$'
 THEN RAISE EXCEPTION 'WO419 STOP: disposable write fixture denied'; END IF;
END $$;
CREATE SCHEMA IF NOT EXISTS wo419_preview;
REVOKE ALL ON SCHEMA wo419_preview FROM PUBLIC;
CREATE TABLE wo419_preview.authorization (
 singleton boolean PRIMARY KEY DEFAULT true CHECK (singleton),
 token text NOT NULL CHECK (token ~ '^[a-f0-9]{48}$'),
 created_at timestamptz NOT NULL DEFAULT clock_timestamp()
);
INSERT INTO wo419_preview.authorization(singleton,token)
VALUES (true,current_setting('msb.wo419_clone_write_token'));
CREATE TABLE wo419_preview.activity (
 activity_id bigserial PRIMARY KEY,
 ticket_key text NOT NULL CHECK (ticket_key ~ '^(WO|INTAKE)-[1-9][0-9]*$'),
 event_kind text NOT NULL,
 actor_person_id integer NOT NULL REFERENCES ref.person(person_id),
 target_person_id integer REFERENCES ref.person(person_id),
 note text NOT NULL DEFAULT '',
 details jsonb NOT NULL DEFAULT '{}'::jsonb,
 created_at timestamptz NOT NULL DEFAULT clock_timestamp()
);
CREATE INDEX ON wo419_preview.activity(ticket_key,activity_id);
CREATE TABLE wo419_preview.outbox (
 outbox_id bigserial PRIMARY KEY,
 event_key text NOT NULL UNIQUE,
 ticket_key text NOT NULL,
 activity_id bigint NOT NULL REFERENCES wo419_preview.activity(activity_id),
 recipient_person_id integer REFERENCES ref.person(person_id),
 recipient_email text,
 delivery_status text NOT NULL DEFAULT 'NO_SEND_CAPTURED'
   CHECK (delivery_status IN ('NO_SEND_CAPTURED','NO_REPORTER_EMAIL')),
 created_at timestamptz NOT NULL DEFAULT clock_timestamp()
);
GRANT USAGE ON SCHEMA wo419_preview TO fieldwiring_app;
GRANT SELECT ON wo419_preview.authorization TO fieldwiring_app;
GRANT SELECT, INSERT ON wo419_preview.activity,wo419_preview.outbox TO fieldwiring_app;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA wo419_preview TO fieldwiring_app;
-- All DML grants exist ONLY on the separate restored clone.
GRANT INSERT, UPDATE ON ops.work_order TO fieldwiring_app;
GRANT INSERT, UPDATE ON ops.work_order_assignment TO fieldwiring_app;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA ops TO fieldwiring_app;
COMMIT;
