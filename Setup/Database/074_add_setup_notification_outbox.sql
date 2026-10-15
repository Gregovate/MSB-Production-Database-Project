/* #205 under #122 -- isolated Setup delivery request ledger.
   CANDIDATE ONLY. Never run on Production without migration authorization.
   Directus items.create flow is provisioned/verified separately; this migration
   does not activate any Flow or schedule sending.
*/
BEGIN;

DO $guard$
BEGIN
  IF to_regclass('public.directus_collections') IS NULL
     OR to_regclass('public.directus_flows') IS NULL
     OR to_regclass('ops.setup_session_task') IS NULL
     OR NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='directus_app')
  THEN
     RAISE EXCEPTION 'Required Setup/Directus runtime dependencies are unavailable';
  END IF;
  IF to_regclass('public.setup_notification_outbox') IS NOT NULL THEN
     RAISE EXCEPTION 'Setup notification outbox already exists; review migration state';
  END IF;
END
$guard$;

CREATE TABLE public.setup_notification_outbox (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  message_key text NOT NULL UNIQUE,
  season_year integer NOT NULL,
  notice_date date NOT NULL,
  kind text NOT NULL CHECK (kind IN
    ('MANAGER_DAILY', 'CAPTAIN_DAILY', 'CAPTAIN_REQUEST', 'MANAGER_SELF_TEST')),
  recipient_email text NOT NULL CHECK (
    recipient_email=lower(btrim(recipient_email))
    AND recipient_email ~ '^[a-z0-9._%+\-]+@sheboyganlights[.]org$'),
  recipient_person_id integer NOT NULL REFERENCES ref.person(person_id),
  assignment_id bigint NULL REFERENCES ops.setup_work_day_task(setup_work_day_task_id),
  subject text NOT NULL CHECK (length(subject) BETWEEN 1 AND 250),
  body_text text NOT NULL CHECK (length(body_text) BETWEEN 1 AND 50000),
  /* Mail may be accepted by Directus but not delivered to an inbox. */
  dispatch_status text NOT NULL DEFAULT 'QUEUED'
     CHECK (dispatch_status IN ('QUEUED','DIRECTUS_ACCEPTED','FLOW_FAILED','DELIVERY_UNKNOWN')),
  requested_at timestamptz NOT NULL DEFAULT now(),
  directus_accepted_at timestamptz NULL,
  flow_error text NULL,
  CONSTRAINT setup_notice_key_length CHECK (length(message_key) BETWEEN 8 AND 300)
);

COMMENT ON TABLE public.setup_notification_outbox IS
  'Sensitive Setup #205 outbound mail requests. Write via dedicated Directus Items API only; unique message_key prevents repeat create-events. No delivery is implied by QUEUED.';
REVOKE ALL ON public.setup_notification_outbox FROM PUBLIC;
REVOKE ALL ON public.setup_notification_outbox FROM fieldwiring_app;
GRANT SELECT, INSERT, UPDATE ON public.setup_notification_outbox TO directus_app;
INSERT INTO public.directus_collections (collection, icon, hidden, note)
VALUES ('setup_notification_outbox','mark_email_unread',true,
        'Restricted MSB Setup notification delivery ledger; never expose to ordinary operator roles')
ON CONFLICT (collection) DO NOTHING;

-- Directus API policy and inactive Flow installation are separate governed gates.
-- Public, Production Crew, Manager, and generic app tokens must not get CREATE
-- access. Grant CREATE to a dedicated Setup notification service token only.

COMMIT;
