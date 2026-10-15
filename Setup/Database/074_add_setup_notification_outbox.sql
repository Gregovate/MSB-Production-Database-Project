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

/* Defense in depth: Directus token CREATE permission cannot dictate arbitrary
   recipient identity, bypass current Manager/Captain access or fabricate a
   distinct idempotency key for a repeat notice. */
CREATE OR REPLACE FUNCTION ops.guard_setup_notification_outbox()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, ops, ref, public
AS $fn$
DECLARE
  v_manager boolean := false;
  v_reader boolean := false;
  v_expected_key text;
  v_matching boolean := false;
BEGIN
  IF NEW.season_year <> 2026 OR NEW.notice_date IS NULL THEN
    RAISE EXCEPTION 'Setup notifications require the reviewed 2026 season/date'
      USING ERRCODE='22023';
  END IF;

  SELECT coalesce(cap.can_manage_setup,false),
         coalesce(cap.can_read_setup,false)
  INTO v_manager,v_reader
  FROM ref.person p
  JOIN public.directus_users u ON u.id=p.directus_user_id
  JOIN LATERAL ref.setup_browser_capabilities(lower(btrim(p.email))) cap ON true
  WHERE p.person_id=NEW.recipient_person_id
    AND p.active_flag IS TRUE AND u.status='active' AND u.provider='google'
    AND lower(btrim(p.email))=NEW.recipient_email
    AND lower(btrim(u.email))=NEW.recipient_email
    AND lower(btrim(u.external_identifier))=NEW.recipient_email
  LIMIT 1;

  IF NEW.kind IN ('MANAGER_DAILY','MANAGER_SELF_TEST') THEN
    IF v_manager IS NOT TRUE OR NEW.assignment_id IS NOT NULL THEN
      RAISE EXCEPTION 'Manager notification recipient or context not authorized'
        USING ERRCODE='42501';
    END IF;
  ELSIF NEW.kind IN ('CAPTAIN_DAILY','CAPTAIN_REQUEST') THEN
    IF v_reader IS NOT TRUE THEN
      RAISE EXCEPTION 'Captain notification identity is not Setup-authorized'
        USING ERRCODE='42501';
    END IF;
    SELECT EXISTS (
      SELECT 1
      FROM ops.setup_work_day_task a
      JOIN ops.setup_work_day wd ON wd.setup_work_day_id=a.setup_work_day_id
      JOIN ops.setup_session ss ON ss.setup_session_id=wd.setup_session_id
      JOIN ops.setup_work_day_crew c
        ON c.setup_work_day_crew_id=a.setup_work_day_crew_id
      WHERE ss.season_year=2026
        AND c.captain_person_id=NEW.recipient_person_id
        AND (NEW.kind='CAPTAIN_DAILY' OR a.setup_work_day_task_id=NEW.assignment_id)
        AND wd.work_date < NEW.notice_date
        AND wd.day_status <> 'CANCELLED'
        AND NOT EXISTS (
          SELECT 1 FROM ops.setup_task_progress p
          WHERE p.setup_work_day_task_id=a.setup_work_day_task_id
             OR (p.setup_work_day_task_id IS NULL
                 AND p.setup_work_day_id=a.setup_work_day_id
                 AND p.setup_session_task_id=a.setup_session_task_id
                 AND p.shift_code=a.shift_code)
        )
    ) INTO v_matching;
    IF v_matching IS NOT TRUE
       OR (NEW.kind='CAPTAIN_REQUEST' AND NEW.assignment_id IS NULL)
       OR (NEW.kind='CAPTAIN_DAILY' AND NEW.assignment_id IS NOT NULL) THEN
      RAISE EXCEPTION 'No authorized still-unreported historical Captain occurrence'
        USING ERRCODE='42501';
    END IF;
  ELSE
    RAISE EXCEPTION 'Unsupported Setup notification kind'
      USING ERRCODE='22023';
  END IF;

  v_expected_key := NEW.season_year::text || '|' || NEW.notice_date::text
     || '|' || NEW.kind || '|' || NEW.recipient_email
     || CASE WHEN NEW.kind='CAPTAIN_REQUEST'
             THEN '|' || NEW.assignment_id::text ELSE '' END;
  IF NEW.message_key IS DISTINCT FROM v_expected_key THEN
    RAISE EXCEPTION 'Setup notification daily deduplication identity is invalid'
      USING ERRCODE='22023';
  END IF;
  RETURN NEW;
END
$fn$;

CREATE TRIGGER trg_guard_setup_notification_outbox
BEFORE INSERT ON public.setup_notification_outbox
FOR EACH ROW EXECUTE FUNCTION ops.guard_setup_notification_outbox();

CREATE OR REPLACE FUNCTION ops.prevent_setup_notification_retarget()
RETURNS trigger LANGUAGE plpgsql
SECURITY DEFINER SET search_path=pg_catalog,ops,public
AS $fn$
BEGIN
  IF ROW(NEW.id,NEW.message_key,NEW.season_year,NEW.notice_date,
         NEW.kind,NEW.recipient_email,NEW.recipient_person_id,
         NEW.assignment_id,NEW.subject,NEW.body_text,NEW.requested_at)
     IS DISTINCT FROM
     ROW(OLD.id,OLD.message_key,OLD.season_year,OLD.notice_date,
         OLD.kind,OLD.recipient_email,OLD.recipient_person_id,
         OLD.assignment_id,OLD.subject,OLD.body_text,OLD.requested_at)
  THEN
    RAISE EXCEPTION 'Setup notification recipient and payload are immutable after enqueue'
      USING ERRCODE='42501';
  END IF;
  RETURN NEW;
END
$fn$;
CREATE TRIGGER trg_setup_notice_immutable
BEFORE UPDATE ON public.setup_notification_outbox
FOR EACH ROW EXECUTE FUNCTION ops.prevent_setup_notification_retarget();

REVOKE ALL ON FUNCTION ops.guard_setup_notification_outbox() FROM PUBLIC;
REVOKE ALL ON FUNCTION ops.prevent_setup_notification_retarget() FROM PUBLIC;

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
