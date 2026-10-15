/* #205 migration 074 -- rollback-only checks against current-Production clone.
   No Directus Items API request is made; no email is sent by this SQL.
   This does not substitute for authenticated Directus Flow/browser acceptance. */
BEGIN;

DO $guard$
DECLARE
  v_manager record;
  v_notice_id uuid;
  v_dummy_key text;
BEGIN
  IF to_regclass('public.setup_notification_outbox') IS NULL
     OR to_regprocedure('ops.guard_setup_notification_outbox()') IS NULL
     OR to_regprocedure('ops.prevent_setup_notification_retarget()') IS NULL
  THEN
    RAISE EXCEPTION 'Setup notification migration 074 is incomplete';
  END IF;
  IF has_table_privilege('fieldwiring_app','public.setup_notification_outbox','INSERT')
     OR has_table_privilege('PUBLIC','public.setup_notification_outbox','INSERT')
  THEN
    RAISE EXCEPTION 'Setup browser/Public database role can insert delivery requests';
  END IF;
  IF NOT has_table_privilege('directus_app','public.setup_notification_outbox','INSERT') THEN
    RAISE EXCEPTION 'Directus database role cannot create authenticated outbox row';
  END IF;
  IF NOT EXISTS(
     SELECT 1 FROM public.directus_collections
     WHERE collection='setup_notification_outbox' AND hidden IS TRUE
  ) THEN
    RAISE EXCEPTION 'Dedicated Directus notification collection metadata absent';
  END IF;

  SELECT p.person_id,lower(p.email) AS email
  INTO v_manager
  FROM ref.person p
  JOIN public.directus_users u ON u.id=p.directus_user_id
  JOIN LATERAL ref.setup_browser_capabilities(lower(p.email)) cap ON true
  WHERE p.active_flag AND u.status='active' AND u.provider='google'
    AND lower(u.external_identifier)=lower(p.email)
    AND lower(u.email)=lower(p.email)
    AND lower(p.email) LIKE '%@sheboyganlights.org'
    AND cap.can_manage_setup
  ORDER BY p.person_id LIMIT 1;
  IF v_manager.person_id IS NULL THEN
    RAISE EXCEPTION 'No current verified active Setup Manager: cannot accept outbox design';
  END IF;

  v_dummy_key := '2026|2026-10-15|MANAGER_SELF_TEST|'||v_manager.email;
  INSERT INTO public.setup_notification_outbox (
    message_key,season_year,notice_date,kind,recipient_email,
    recipient_person_id,subject,body_text
  ) VALUES (
    v_dummy_key,2026,'2026-10-15','MANAGER_SELF_TEST',
    v_manager.email,v_manager.person_id,'Disposable only','DO NOT SEND'
  ) RETURNING id INTO v_notice_id;

  IF (SELECT dispatch_status FROM public.setup_notification_outbox
      WHERE id=v_notice_id) <> 'QUEUED' THEN
    RAISE EXCEPTION 'New outbox row incorrectly claims mail transport acceptance';
  END IF;

  BEGIN
    INSERT INTO public.setup_notification_outbox (
      message_key,season_year,notice_date,kind,recipient_email,
      recipient_person_id,subject,body_text
    ) VALUES (v_dummy_key,2026,'2026-10-15','MANAGER_SELF_TEST',
      v_manager.email,v_manager.person_id,'Repeat','DO NOT SEND');
    RAISE EXCEPTION 'DUPLICATE WAS ACCEPTED';
  EXCEPTION WHEN unique_violation THEN
    NULL;
  END;

  BEGIN
    UPDATE public.setup_notification_outbox
    SET recipient_email='spoof@sheboyganlights.org'
    WHERE id=v_notice_id;
    RAISE EXCEPTION 'OUTBOX RECIPIENT RETARGET WAS ACCEPTED';
  EXCEPTION WHEN insufficient_privilege THEN
    NULL;
  END;

  BEGIN
    INSERT INTO public.setup_notification_outbox (
      message_key,season_year,notice_date,kind,recipient_email,
      recipient_person_id,subject,body_text
    ) VALUES (
      '2026|2026-10-15|MANAGER_SELF_TEST|spoof@sheboyganlights.org',
      2026,'2026-10-15','MANAGER_SELF_TEST',
      'spoof@sheboyganlights.org',v_manager.person_id,
      'Spoofed','DO NOT SEND');
    RAISE EXCEPTION 'INVALID MANAGER ADDRESS WAS ACCEPTED';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;

  BEGIN
    INSERT INTO public.setup_notification_outbox (
      message_key,season_year,notice_date,kind,recipient_email,
      recipient_person_id,subject,body_text
    ) VALUES (
      'totally-invented-key',2026,'2026-10-15','MANAGER_SELF_TEST',
      v_manager.email,v_manager.person_id,'Wrong key','DO NOT SEND');
    RAISE EXCEPTION 'INVALID IDEMPOTENCY KEY WAS ACCEPTED';
  EXCEPTION WHEN invalid_parameter_value THEN NULL;
  END;
END
$guard$;

ROLLBACK;
