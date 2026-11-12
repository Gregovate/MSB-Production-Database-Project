/* MSB Setup #167 — Production Crew / Manager inventory commands. REVIEW BEFORE PRODUCTION. */
BEGIN;

DO $preflight$
BEGIN
    IF to_regclass('ops.setup_extra_material_inventory_event') IS NULL
       OR to_regclass('ref.setup_container_extra_material') IS NULL
       OR to_regclass('ref.person') IS NULL THEN
        RAISE EXCEPTION 'Migration 032 Extra Material inventory schema is required first';
    END IF;
END
$preflight$;

/* Separate from the current movement capability because that capability also
   includes Volunteer. Durable Extra Material inventory adjustment is limited to
   Production Crew, Manager and Administrator. */
CREATE OR REPLACE FUNCTION ref.setup_inventory_actor(
    p_email text,
    p_require_manager boolean DEFAULT false
)
RETURNS TABLE (
    directus_user_id uuid,
    person_id integer,
    display_name text,
    can_manage_setup boolean
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, ref
AS $function$
DECLARE
    v_email text := lower(btrim(p_email));
    v_directus_user_id uuid;
    v_person_id integer;
    v_display_name text;
    v_role_name text;
    v_policy_names text[] := ARRAY[]::text[];
    v_can_inventory boolean := false;
    v_can_manage boolean := false;
BEGIN
    IF v_email IS NULL OR v_email='' THEN
        RAISE EXCEPTION USING ERRCODE='42501', MESSAGE='Authenticated Setup operator email is required';
    END IF;

    SELECT
        u.id,
        nullif(btrim(concat_ws(' ',u.first_name,u.last_name)),''),
        r.name,
        ARRAY(
            SELECT DISTINCT p.name
            FROM public.directus_access a
            JOIN public.directus_policies p ON p.id=a.policy
            WHERE a."user"=u.id OR (u.role IS NOT NULL AND a.role=u.role)
            ORDER BY p.name
        )
      INTO v_directus_user_id, v_display_name, v_role_name, v_policy_names
    FROM public.directus_users u
    LEFT JOIN public.directus_roles r ON r.id=u.role
    WHERE u.status='active' AND lower(u.email)=v_email
    LIMIT 1;

    IF v_directus_user_id IS NULL THEN
        RAISE EXCEPTION USING ERRCODE='42501', MESSAGE='Setup inventory operator is not an active Directus user';
    END IF;

    v_can_manage :=
        v_role_name IN ('Manager','Administrator')
        OR v_policy_names && ARRAY['Manager','Administrator'];
    v_can_inventory :=
        v_can_manage
        OR v_role_name='Production Crew'
        OR 'Production Crew'=ANY(v_policy_names);

    IF NOT v_can_inventory THEN
        RAISE EXCEPTION USING ERRCODE='42501', MESSAGE='Setup Extra Material inventory adjustment is not authorized for this account';
    END IF;
    IF coalesce(p_require_manager,false) AND NOT v_can_manage THEN
        RAISE EXCEPTION USING ERRCODE='42501', MESSAGE='Setup Extra Material definition maintenance requires Manager access';
    END IF;

    SELECT p.person_id INTO v_person_id
    FROM ref.person p
    WHERE p.directus_user_id=v_directus_user_id
    LIMIT 1;

    IF v_person_id IS NULL THEN
        RAISE EXCEPTION USING ERRCODE='42501', MESSAGE='Authenticated Setup inventory operator is not mapped to an MSB person';
    END IF;

    RETURN QUERY SELECT
        v_directus_user_id,
        v_person_id,
        coalesce(v_display_name,v_email),
        v_can_manage;
END;
$function$;

REVOKE ALL ON FUNCTION ref.setup_inventory_actor(text,boolean) FROM PUBLIC;
REVOKE ALL ON FUNCTION ref.setup_inventory_actor(text,boolean) FROM fieldwiring_app;

CREATE OR REPLACE FUNCTION ops.record_setup_extra_material_inventory_event(
    p_email text,
    p_setup_container_extra_material_id bigint,
    p_event_type text,
    p_quantity_delta numeric,
    p_event_note text DEFAULT NULL,
    p_occurred_at timestamptz DEFAULT NULL
)
RETURNS TABLE (
    setup_extra_material_inventory_event_id bigint,
    setup_container_extra_material_id bigint,
    on_hand_quantity numeric,
    operator_display_name text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, ops, ref
AS $function$
DECLARE
    v_directus_user_id uuid;
    v_person_id integer;
    v_display_name text;
    v_event_id bigint;
    v_event_type text := upper(btrim(coalesce(p_event_type,'OTHER')));
    v_event_count integer;
    v_current_balance numeric;
    v_on_hand numeric;
BEGIN
    SELECT a.directus_user_id, a.person_id, a.display_name
      INTO v_directus_user_id, v_person_id, v_display_name
    FROM ref.setup_inventory_actor(p_email,false) a;

    IF NOT EXISTS (
        SELECT 1 FROM ref.setup_container_extra_material cem
        WHERE cem.setup_container_extra_material_id=p_setup_container_extra_material_id
          AND cem.active_flag
    ) THEN
        RAISE EXCEPTION USING ERRCODE='P0002', MESSAGE='Active Container Extra Material row was not found';
    END IF;
    IF p_quantity_delta IS NULL OR p_quantity_delta=0 THEN
        RAISE EXCEPTION USING ERRCODE='22023', MESSAGE='Inventory quantity delta must be nonzero';
    END IF;
    IF v_event_type NOT IN (
        'INITIAL_COUNT','RECEIPT','RETURN','COUNT_CORRECTION',
        'DAMAGE_LOSS','CONSUMPTION','TRANSFER_IN','TRANSFER_OUT','OTHER'
    ) THEN
        RAISE EXCEPTION USING ERRCODE='22023', MESSAGE='Invalid Extra Material inventory event type';
    END IF;
    IF v_event_type IN ('INITIAL_COUNT','RECEIPT','RETURN','TRANSFER_IN') AND p_quantity_delta<=0 THEN
        RAISE EXCEPTION USING ERRCODE='22023', MESSAGE='This inventory event type requires a positive quantity';
    END IF;
    IF v_event_type IN ('DAMAGE_LOSS','CONSUMPTION','TRANSFER_OUT') AND p_quantity_delta>=0 THEN
        RAISE EXCEPTION USING ERRCODE='22023', MESSAGE='This inventory event type requires a negative quantity';
    END IF;

    SELECT count(*), coalesce(sum(e.quantity_delta),0)
      INTO v_event_count, v_current_balance
    FROM ops.setup_extra_material_inventory_event e
    WHERE e.setup_container_extra_material_id=p_setup_container_extra_material_id;

    IF v_event_count=0 AND v_event_type <> 'INITIAL_COUNT' THEN
        RAISE EXCEPTION USING
            ERRCODE='22023',
            MESSAGE='Initial physical count must be recorded before inventory adjustments';
    END IF;
    IF v_event_count>0 AND v_event_type='INITIAL_COUNT' THEN
        RAISE EXCEPTION USING
            ERRCODE='22023',
            MESSAGE='Initial physical count already exists; use Count Correction for later recounts';
    END IF;
    IF v_event_count>0 AND v_current_balance + p_quantity_delta < 0 THEN
        RAISE EXCEPTION USING
            ERRCODE='22023',
            MESSAGE='Inventory adjustment would make physical on-hand quantity negative';
    END IF;

    PERFORM pg_catalog.set_config('app.directus_user_uuid',v_directus_user_id::text,true);
    INSERT INTO ops.setup_extra_material_inventory_event(
        setup_container_extra_material_id,event_type,quantity_delta,event_note,occurred_at
    ) VALUES (
        p_setup_container_extra_material_id,v_event_type,p_quantity_delta,
        nullif(btrim(p_event_note),''),coalesce(p_occurred_at,now())
    )
    RETURNING ops.setup_extra_material_inventory_event.setup_extra_material_inventory_event_id INTO v_event_id;

    SELECT b.on_hand_quantity INTO v_on_hand
    FROM ops.setup_extra_material_inventory_balance b
    WHERE b.setup_container_extra_material_id=p_setup_container_extra_material_id;

    RETURN QUERY SELECT v_event_id,p_setup_container_extra_material_id,v_on_hand,v_display_name;
END;
$function$;

REVOKE ALL ON FUNCTION ops.record_setup_extra_material_inventory_event(text,bigint,text,numeric,text,timestamptz) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ops.record_setup_extra_material_inventory_event(text,bigint,text,numeric,text,timestamptz) TO fieldwiring_app;

COMMIT;

SELECT
    has_function_privilege('fieldwiring_app','ops.record_setup_extra_material_inventory_event(text,bigint,text,numeric,text,timestamptz)','EXECUTE') AS can_record_inventory,
    has_table_privilege('fieldwiring_app','ops.setup_extra_material_inventory_event','INSERT') AS broad_inventory_insert;
