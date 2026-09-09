/* ============================================================================
MSB People Manager — capability, qualification, and Setup-role metadata
Issue: #130
Status: IMPLEMENTATION CANDIDATE — DO NOT APPLY TO PRODUCTION WITHOUT REVIEW
Revision: 2026-09-09 V0.2.0

Purpose:
  Complete the People Manager person-metadata slice established by issue #130:
  - reusable capability catalog and person capability relationships;
  - formal qualification catalog and dated person qualification records;
  - Setup/Takedown participation and leadership-eligibility roles;
  - read-only visibility of existing reusable-task Captain/Alternate/Advisor
    assignments.

Boundaries:
  - ref.person remains the durable identity/contact authority.
  - Capabilities are not formal qualifications.
  - Setup participation/eligibility is not Captain assignment.
  - Existing ref.setup_task_captain remains the actual reusable-task leadership
    authority.
  - No capability, qualification, Setup role, or Captain relationship is inferred
    from shorthand names or historical crew text.
  - No person delete or person merge command is introduced here.
============================================================================ */

BEGIN;

DO $preflight$
BEGIN
    IF to_regclass('ref.person') IS NULL THEN
        RAISE EXCEPTION 'ref.person is required';
    END IF;

    IF to_regclass('ref.setup_task') IS NULL
       OR to_regclass('ref.setup_task_captain') IS NULL THEN
        RAISE EXCEPTION
            'Current Setup reusable-task and Captain tables are required for People leadership visibility';
    END IF;

    IF to_regprocedure('ref.people_management_actor(text)') IS NULL THEN
        RAISE EXCEPTION 'People Manager base contract must be installed first';
    END IF;

    IF to_regprocedure('ref.set_actor_on_insert()') IS NULL
       OR to_regprocedure('ref.set_actor_on_update()') IS NULL THEN
        RAISE EXCEPTION 'Existing MSB actor/audit functions are required';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'people_app') THEN
        RAISE EXCEPTION 'Required role people_app does not exist';
    END IF;
END
$preflight$;

/* --------------------------------------------------------------------------
   GLOBAL CAPABILITY CATALOG
   -------------------------------------------------------------------------- */

CREATE TABLE IF NOT EXISTS ref.person_capability_type (
    person_capability_type_id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    capability_name text NOT NULL,
    capability_category text NOT NULL DEFAULT 'OTHER',
    notes text,
    active_flag boolean NOT NULL DEFAULT true,
    sort_order integer NOT NULL DEFAULT 100,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by text NOT NULL DEFAULT current_user,
    updated_at timestamptz NOT NULL DEFAULT now(),
    updated_by text NOT NULL DEFAULT current_user,
    created_by_person_id integer,
    updated_by_person_id integer,

    CONSTRAINT fk_person_capability_type_created_by_person
        FOREIGN KEY (created_by_person_id) REFERENCES ref.person(person_id),
    CONSTRAINT fk_person_capability_type_updated_by_person
        FOREIGN KEY (updated_by_person_id) REFERENCES ref.person(person_id),
    CONSTRAINT ck_person_capability_type_name
        CHECK (btrim(capability_name) <> ''),
    CONSTRAINT ck_person_capability_type_category
        CHECK (capability_category IN (
            'TRADE', 'TECHNICAL', 'DISPLAY_BUILD_KNOWLEDGE', 'EQUIPMENT', 'OTHER'
        )),
    CONSTRAINT ck_person_capability_type_sort
        CHECK (sort_order >= 0)
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_person_capability_type_name_ci
    ON ref.person_capability_type(lower(btrim(capability_name)));

CREATE INDEX IF NOT EXISTS ix_person_capability_type_active_sort
    ON ref.person_capability_type(active_flag, sort_order, capability_name);

CREATE TABLE IF NOT EXISTS ref.person_capability (
    person_id integer NOT NULL,
    person_capability_type_id integer NOT NULL,
    active_flag boolean NOT NULL DEFAULT true,
    notes text,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by text NOT NULL DEFAULT current_user,
    updated_at timestamptz NOT NULL DEFAULT now(),
    updated_by text NOT NULL DEFAULT current_user,
    created_by_person_id integer,
    updated_by_person_id integer,

    CONSTRAINT pk_person_capability
        PRIMARY KEY (person_id, person_capability_type_id),
    CONSTRAINT fk_person_capability_person
        FOREIGN KEY (person_id) REFERENCES ref.person(person_id),
    CONSTRAINT fk_person_capability_type
        FOREIGN KEY (person_capability_type_id)
        REFERENCES ref.person_capability_type(person_capability_type_id),
    CONSTRAINT fk_person_capability_created_by_person
        FOREIGN KEY (created_by_person_id) REFERENCES ref.person(person_id),
    CONSTRAINT fk_person_capability_updated_by_person
        FOREIGN KEY (updated_by_person_id) REFERENCES ref.person(person_id)
);

CREATE INDEX IF NOT EXISTS ix_person_capability_type_person
    ON ref.person_capability(person_capability_type_id, active_flag, person_id);

/* --------------------------------------------------------------------------
   GLOBAL QUALIFICATION CATALOG
   -------------------------------------------------------------------------- */

CREATE TABLE IF NOT EXISTS ref.person_qualification_type (
    person_qualification_type_id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    qualification_name text NOT NULL,
    notes text,
    active_flag boolean NOT NULL DEFAULT true,
    sort_order integer NOT NULL DEFAULT 100,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by text NOT NULL DEFAULT current_user,
    updated_at timestamptz NOT NULL DEFAULT now(),
    updated_by text NOT NULL DEFAULT current_user,
    created_by_person_id integer,
    updated_by_person_id integer,

    CONSTRAINT fk_person_qualification_type_created_by_person
        FOREIGN KEY (created_by_person_id) REFERENCES ref.person(person_id),
    CONSTRAINT fk_person_qualification_type_updated_by_person
        FOREIGN KEY (updated_by_person_id) REFERENCES ref.person(person_id),
    CONSTRAINT ck_person_qualification_type_name
        CHECK (btrim(qualification_name) <> ''),
    CONSTRAINT ck_person_qualification_type_sort
        CHECK (sort_order >= 0)
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_person_qualification_type_name_ci
    ON ref.person_qualification_type(lower(btrim(qualification_name)));

CREATE INDEX IF NOT EXISTS ix_person_qualification_type_active_sort
    ON ref.person_qualification_type(active_flag, sort_order, qualification_name);

CREATE TABLE IF NOT EXISTS ref.person_qualification (
    person_qualification_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    person_id integer NOT NULL,
    person_qualification_type_id integer NOT NULL,
    completed_on date,
    valid_from date,
    expires_on date,
    qualification_role text,
    certificate_number text,
    evidence_reference text,
    active_flag boolean NOT NULL DEFAULT true,
    notes text,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by text NOT NULL DEFAULT current_user,
    updated_at timestamptz NOT NULL DEFAULT now(),
    updated_by text NOT NULL DEFAULT current_user,
    created_by_person_id integer,
    updated_by_person_id integer,

    CONSTRAINT fk_person_qualification_person
        FOREIGN KEY (person_id) REFERENCES ref.person(person_id),
    CONSTRAINT fk_person_qualification_type
        FOREIGN KEY (person_qualification_type_id)
        REFERENCES ref.person_qualification_type(person_qualification_type_id),
    CONSTRAINT fk_person_qualification_created_by_person
        FOREIGN KEY (created_by_person_id) REFERENCES ref.person(person_id),
    CONSTRAINT fk_person_qualification_updated_by_person
        FOREIGN KEY (updated_by_person_id) REFERENCES ref.person(person_id),
    CONSTRAINT ck_person_qualification_dates
        CHECK (
            expires_on IS NULL
            OR valid_from IS NULL
            OR expires_on >= valid_from
        )
);

CREATE INDEX IF NOT EXISTS ix_person_qualification_person_active
    ON ref.person_qualification(person_id, active_flag, person_qualification_type_id);

CREATE INDEX IF NOT EXISTS ix_person_qualification_expiry
    ON ref.person_qualification(active_flag, expires_on)
    WHERE expires_on IS NOT NULL;

/* --------------------------------------------------------------------------
   SETUP / TAKEDOWN PARTICIPATION AND ELIGIBILITY
   -------------------------------------------------------------------------- */

CREATE TABLE IF NOT EXISTS ref.person_setup_role (
    person_id integer NOT NULL,
    setup_role text NOT NULL,
    active_flag boolean NOT NULL DEFAULT true,
    notes text,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by text NOT NULL DEFAULT current_user,
    updated_at timestamptz NOT NULL DEFAULT now(),
    updated_by text NOT NULL DEFAULT current_user,
    created_by_person_id integer,
    updated_by_person_id integer,

    CONSTRAINT pk_person_setup_role PRIMARY KEY (person_id, setup_role),
    CONSTRAINT fk_person_setup_role_person
        FOREIGN KEY (person_id) REFERENCES ref.person(person_id),
    CONSTRAINT fk_person_setup_role_created_by_person
        FOREIGN KEY (created_by_person_id) REFERENCES ref.person(person_id),
    CONSTRAINT fk_person_setup_role_updated_by_person
        FOREIGN KEY (updated_by_person_id) REFERENCES ref.person(person_id),
    CONSTRAINT ck_person_setup_role_code
        CHECK (setup_role IN (
            'SETUP_VOLUNTEER',
            'TAKEDOWN_VOLUNTEER',
            'CAPTAIN_CANDIDATE',
            'ADVISOR_CANDIDATE'
        ))
);

CREATE INDEX IF NOT EXISTS ix_person_setup_role_role_active
    ON ref.person_setup_role(setup_role, active_flag, person_id);

/* --------------------------------------------------------------------------
   AUDIT TRIGGERS
   -------------------------------------------------------------------------- */

DROP TRIGGER IF EXISTS trg_person_capability_type_set_actor_insert
    ON ref.person_capability_type;
CREATE TRIGGER trg_person_capability_type_set_actor_insert
BEFORE INSERT ON ref.person_capability_type
FOR EACH ROW EXECUTE FUNCTION ref.set_actor_on_insert();

DROP TRIGGER IF EXISTS trg_person_capability_type_set_actor_update
    ON ref.person_capability_type;
CREATE TRIGGER trg_person_capability_type_set_actor_update
BEFORE UPDATE ON ref.person_capability_type
FOR EACH ROW EXECUTE FUNCTION ref.set_actor_on_update();

DROP TRIGGER IF EXISTS trg_person_capability_set_actor_insert
    ON ref.person_capability;
CREATE TRIGGER trg_person_capability_set_actor_insert
BEFORE INSERT ON ref.person_capability
FOR EACH ROW EXECUTE FUNCTION ref.set_actor_on_insert();

DROP TRIGGER IF EXISTS trg_person_capability_set_actor_update
    ON ref.person_capability;
CREATE TRIGGER trg_person_capability_set_actor_update
BEFORE UPDATE ON ref.person_capability
FOR EACH ROW EXECUTE FUNCTION ref.set_actor_on_update();

DROP TRIGGER IF EXISTS trg_person_qualification_type_set_actor_insert
    ON ref.person_qualification_type;
CREATE TRIGGER trg_person_qualification_type_set_actor_insert
BEFORE INSERT ON ref.person_qualification_type
FOR EACH ROW EXECUTE FUNCTION ref.set_actor_on_insert();

DROP TRIGGER IF EXISTS trg_person_qualification_type_set_actor_update
    ON ref.person_qualification_type;
CREATE TRIGGER trg_person_qualification_type_set_actor_update
BEFORE UPDATE ON ref.person_qualification_type
FOR EACH ROW EXECUTE FUNCTION ref.set_actor_on_update();

DROP TRIGGER IF EXISTS trg_person_qualification_set_actor_insert
    ON ref.person_qualification;
CREATE TRIGGER trg_person_qualification_set_actor_insert
BEFORE INSERT ON ref.person_qualification
FOR EACH ROW EXECUTE FUNCTION ref.set_actor_on_insert();

DROP TRIGGER IF EXISTS trg_person_qualification_set_actor_update
    ON ref.person_qualification;
CREATE TRIGGER trg_person_qualification_set_actor_update
BEFORE UPDATE ON ref.person_qualification
FOR EACH ROW EXECUTE FUNCTION ref.set_actor_on_update();

DROP TRIGGER IF EXISTS trg_person_setup_role_set_actor_insert
    ON ref.person_setup_role;
CREATE TRIGGER trg_person_setup_role_set_actor_insert
BEFORE INSERT ON ref.person_setup_role
FOR EACH ROW EXECUTE FUNCTION ref.set_actor_on_insert();

DROP TRIGGER IF EXISTS trg_person_setup_role_set_actor_update
    ON ref.person_setup_role;
CREATE TRIGGER trg_person_setup_role_set_actor_update
BEFORE UPDATE ON ref.person_setup_role
FOR EACH ROW EXECUTE FUNCTION ref.set_actor_on_update();

/* --------------------------------------------------------------------------
   READ CONTRACTS
   -------------------------------------------------------------------------- */

CREATE OR REPLACE FUNCTION ref.people_capability_catalog(
    p_operator_email text,
    p_include_inactive boolean DEFAULT false
)
RETURNS TABLE (
    person_capability_type_id integer,
    capability_name text,
    capability_category text,
    notes text,
    active_flag boolean,
    sort_order integer,
    updated_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, ref
AS $function$
BEGIN
    PERFORM 1 FROM ref.people_management_actor(p_operator_email);

    RETURN QUERY
    SELECT
        t.person_capability_type_id,
        t.capability_name,
        t.capability_category,
        t.notes,
        t.active_flag,
        t.sort_order,
        t.updated_at
    FROM ref.person_capability_type t
    WHERE coalesce(p_include_inactive, false) OR t.active_flag
    ORDER BY t.sort_order, t.capability_name, t.person_capability_type_id;
END;
$function$;

CREATE OR REPLACE FUNCTION ref.people_qualification_catalog(
    p_operator_email text,
    p_include_inactive boolean DEFAULT false
)
RETURNS TABLE (
    person_qualification_type_id integer,
    qualification_name text,
    notes text,
    active_flag boolean,
    sort_order integer,
    updated_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, ref
AS $function$
BEGIN
    PERFORM 1 FROM ref.people_management_actor(p_operator_email);

    RETURN QUERY
    SELECT
        t.person_qualification_type_id,
        t.qualification_name,
        t.notes,
        t.active_flag,
        t.sort_order,
        t.updated_at
    FROM ref.person_qualification_type t
    WHERE coalesce(p_include_inactive, false) OR t.active_flag
    ORDER BY t.sort_order, t.qualification_name, t.person_qualification_type_id;
END;
$function$;

CREATE OR REPLACE FUNCTION ref.people_person_capabilities(
    p_operator_email text,
    p_person_id integer,
    p_include_inactive boolean DEFAULT true
)
RETURNS TABLE (
    person_id integer,
    person_capability_type_id integer,
    capability_name text,
    capability_category text,
    active_flag boolean,
    notes text,
    updated_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, ref
AS $function$
BEGIN
    PERFORM 1 FROM ref.people_management_actor(p_operator_email);

    IF NOT EXISTS (SELECT 1 FROM ref.person p WHERE p.person_id = p_person_id) THEN
        RAISE EXCEPTION USING ERRCODE = 'P0002', MESSAGE = 'Person was not found';
    END IF;

    RETURN QUERY
    SELECT
        c.person_id,
        c.person_capability_type_id,
        t.capability_name,
        t.capability_category,
        c.active_flag,
        c.notes,
        c.updated_at
    FROM ref.person_capability c
    JOIN ref.person_capability_type t
      ON t.person_capability_type_id = c.person_capability_type_id
    WHERE c.person_id = p_person_id
      AND (coalesce(p_include_inactive, true) OR c.active_flag)
    ORDER BY
        CASE WHEN c.active_flag THEN 0 ELSE 1 END,
        t.sort_order,
        t.capability_name;
END;
$function$;

CREATE OR REPLACE FUNCTION ref.people_person_qualifications(
    p_operator_email text,
    p_person_id integer,
    p_include_inactive boolean DEFAULT true
)
RETURNS TABLE (
    person_qualification_id bigint,
    person_id integer,
    person_qualification_type_id integer,
    qualification_name text,
    completed_on date,
    valid_from date,
    expires_on date,
    qualification_role text,
    certificate_number text,
    evidence_reference text,
    active_flag boolean,
    notes text,
    updated_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, ref
AS $function$
BEGIN
    PERFORM 1 FROM ref.people_management_actor(p_operator_email);

    IF NOT EXISTS (SELECT 1 FROM ref.person p WHERE p.person_id = p_person_id) THEN
        RAISE EXCEPTION USING ERRCODE = 'P0002', MESSAGE = 'Person was not found';
    END IF;

    RETURN QUERY
    SELECT
        q.person_qualification_id,
        q.person_id,
        q.person_qualification_type_id,
        t.qualification_name,
        q.completed_on,
        q.valid_from,
        q.expires_on,
        q.qualification_role,
        q.certificate_number,
        q.evidence_reference,
        q.active_flag,
        q.notes,
        q.updated_at
    FROM ref.person_qualification q
    JOIN ref.person_qualification_type t
      ON t.person_qualification_type_id = q.person_qualification_type_id
    WHERE q.person_id = p_person_id
      AND (coalesce(p_include_inactive, true) OR q.active_flag)
    ORDER BY
        CASE WHEN q.active_flag THEN 0 ELSE 1 END,
        t.sort_order,
        t.qualification_name,
        coalesce(q.expires_on, DATE '9999-12-31'),
        q.person_qualification_id;
END;
$function$;

CREATE OR REPLACE FUNCTION ref.people_person_setup_roles(
    p_operator_email text,
    p_person_id integer
)
RETURNS TABLE (
    setup_role text,
    active_flag boolean,
    notes text,
    updated_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, ref
AS $function$
BEGIN
    PERFORM 1 FROM ref.people_management_actor(p_operator_email);

    IF NOT EXISTS (SELECT 1 FROM ref.person p WHERE p.person_id = p_person_id) THEN
        RAISE EXCEPTION USING ERRCODE = 'P0002', MESSAGE = 'Person was not found';
    END IF;

    RETURN QUERY
    WITH role_codes(setup_role, sort_order) AS (
        VALUES
            ('SETUP_VOLUNTEER'::text, 10),
            ('TAKEDOWN_VOLUNTEER'::text, 20),
            ('CAPTAIN_CANDIDATE'::text, 30),
            ('ADVISOR_CANDIDATE'::text, 40)
    )
    SELECT
        r.setup_role,
        coalesce(pr.active_flag, false),
        pr.notes,
        pr.updated_at
    FROM role_codes r
    LEFT JOIN ref.person_setup_role pr
      ON pr.person_id = p_person_id
     AND pr.setup_role = r.setup_role
    ORDER BY r.sort_order;
END;
$function$;

CREATE OR REPLACE FUNCTION ref.people_person_task_leadership(
    p_operator_email text,
    p_person_id integer
)
RETURNS TABLE (
    setup_task_id bigint,
    task_name text,
    stage_id integer,
    captain_role text,
    sort_order integer,
    notes text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, ref
AS $function$
BEGIN
    PERFORM 1 FROM ref.people_management_actor(p_operator_email);

    IF NOT EXISTS (SELECT 1 FROM ref.person p WHERE p.person_id = p_person_id) THEN
        RAISE EXCEPTION USING ERRCODE = 'P0002', MESSAGE = 'Person was not found';
    END IF;

    RETURN QUERY
    SELECT
        c.setup_task_id,
        t.task_name,
        t.stage_id,
        c.captain_role,
        c.sort_order,
        c.notes
    FROM ref.setup_task_captain c
    JOIN ref.setup_task t
      ON t.setup_task_id = c.setup_task_id
    WHERE c.person_id = p_person_id
    ORDER BY c.sort_order, t.task_name, c.setup_task_id;
END;
$function$;

/* --------------------------------------------------------------------------
   GOVERNED WRITE CONTRACTS
   -------------------------------------------------------------------------- */

CREATE OR REPLACE FUNCTION ref.upsert_people_capability_type(
    p_operator_email text,
    p_person_capability_type_id integer,
    p_capability_name text,
    p_capability_category text DEFAULT 'OTHER',
    p_notes text DEFAULT NULL,
    p_active_flag boolean DEFAULT true,
    p_sort_order integer DEFAULT 100
)
RETURNS TABLE (
    person_capability_type_id integer,
    capability_name text,
    capability_category text,
    active_flag boolean,
    updated_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, ref
AS $function$
DECLARE
    v_directus_user_id uuid;
    v_actor_person_id integer;
    v_name text := btrim(coalesce(p_capability_name, ''));
    v_category text := upper(btrim(coalesce(p_capability_category, 'OTHER')));
    v_id integer;
BEGIN
    SELECT a.directus_user_id, a.person_id
      INTO v_directus_user_id, v_actor_person_id
    FROM ref.people_management_actor(p_operator_email) a;

    IF v_name = '' THEN
        RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Capability name is required';
    END IF;
    IF v_category NOT IN ('TRADE','TECHNICAL','DISPLAY_BUILD_KNOWLEDGE','EQUIPMENT','OTHER') THEN
        RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Capability category is invalid';
    END IF;
    IF coalesce(p_sort_order, 100) < 0 THEN
        RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Capability sort order cannot be negative';
    END IF;

    PERFORM pg_catalog.set_config('app.directus_user_uuid', v_directus_user_id::text, true);

    IF p_person_capability_type_id IS NULL THEN
        INSERT INTO ref.person_capability_type(
            capability_name, capability_category, notes, active_flag, sort_order
        )
        VALUES(
            v_name, v_category, nullif(btrim(p_notes), ''),
            coalesce(p_active_flag, true), coalesce(p_sort_order, 100)
        )
        RETURNING ref.person_capability_type.person_capability_type_id
          INTO v_id;
    ELSE
        UPDATE ref.person_capability_type t
           SET capability_name = v_name,
               capability_category = v_category,
               notes = nullif(btrim(p_notes), ''),
               active_flag = coalesce(p_active_flag, t.active_flag),
               sort_order = coalesce(p_sort_order, t.sort_order)
         WHERE t.person_capability_type_id = p_person_capability_type_id
         RETURNING t.person_capability_type_id INTO v_id;

        IF v_id IS NULL THEN
            RAISE EXCEPTION USING ERRCODE = 'P0002', MESSAGE = 'Capability type was not found';
        END IF;
    END IF;

    RETURN QUERY
    SELECT
        t.person_capability_type_id,
        t.capability_name,
        t.capability_category,
        t.active_flag,
        t.updated_at
    FROM ref.person_capability_type t
    WHERE t.person_capability_type_id = v_id;
END;
$function$;

CREATE OR REPLACE FUNCTION ref.set_people_person_capability(
    p_operator_email text,
    p_person_id integer,
    p_person_capability_type_id integer,
    p_active_flag boolean DEFAULT true,
    p_notes text DEFAULT NULL
)
RETURNS TABLE (
    person_id integer,
    person_capability_type_id integer,
    active_flag boolean,
    updated_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, ref
AS $function$
DECLARE
    v_directus_user_id uuid;
    v_actor_person_id integer;
BEGIN
    SELECT a.directus_user_id, a.person_id
      INTO v_directus_user_id, v_actor_person_id
    FROM ref.people_management_actor(p_operator_email) a;

    IF NOT EXISTS (SELECT 1 FROM ref.person p WHERE p.person_id = p_person_id) THEN
        RAISE EXCEPTION USING ERRCODE = 'P0002', MESSAGE = 'Person was not found';
    END IF;
    IF NOT EXISTS (
        SELECT 1
        FROM ref.person_capability_type t
        WHERE t.person_capability_type_id = p_person_capability_type_id
    ) THEN
        RAISE EXCEPTION USING ERRCODE = 'P0002', MESSAGE = 'Capability type was not found';
    END IF;

    PERFORM pg_catalog.set_config('app.directus_user_uuid', v_directus_user_id::text, true);

    INSERT INTO ref.person_capability(
        person_id, person_capability_type_id, active_flag, notes
    )
    VALUES(
        p_person_id, p_person_capability_type_id,
        coalesce(p_active_flag, true), nullif(btrim(p_notes), '')
    )
    ON CONFLICT ON CONSTRAINT pk_person_capability
    DO UPDATE SET
        active_flag = EXCLUDED.active_flag,
        notes = EXCLUDED.notes;

    RETURN QUERY
    SELECT c.person_id, c.person_capability_type_id, c.active_flag, c.updated_at
    FROM ref.person_capability c
    WHERE c.person_id = p_person_id
      AND c.person_capability_type_id = p_person_capability_type_id;
END;
$function$;

CREATE OR REPLACE FUNCTION ref.upsert_people_qualification_type(
    p_operator_email text,
    p_person_qualification_type_id integer,
    p_qualification_name text,
    p_notes text DEFAULT NULL,
    p_active_flag boolean DEFAULT true,
    p_sort_order integer DEFAULT 100
)
RETURNS TABLE (
    person_qualification_type_id integer,
    qualification_name text,
    active_flag boolean,
    updated_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, ref
AS $function$
DECLARE
    v_directus_user_id uuid;
    v_actor_person_id integer;
    v_name text := btrim(coalesce(p_qualification_name, ''));
    v_id integer;
BEGIN
    SELECT a.directus_user_id, a.person_id
      INTO v_directus_user_id, v_actor_person_id
    FROM ref.people_management_actor(p_operator_email) a;

    IF v_name = '' THEN
        RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Qualification name is required';
    END IF;
    IF coalesce(p_sort_order, 100) < 0 THEN
        RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Qualification sort order cannot be negative';
    END IF;

    PERFORM pg_catalog.set_config('app.directus_user_uuid', v_directus_user_id::text, true);

    IF p_person_qualification_type_id IS NULL THEN
        INSERT INTO ref.person_qualification_type(
            qualification_name, notes, active_flag, sort_order
        )
        VALUES(
            v_name, nullif(btrim(p_notes), ''),
            coalesce(p_active_flag, true), coalesce(p_sort_order, 100)
        )
        RETURNING ref.person_qualification_type.person_qualification_type_id
          INTO v_id;
    ELSE
        UPDATE ref.person_qualification_type t
           SET qualification_name = v_name,
               notes = nullif(btrim(p_notes), ''),
               active_flag = coalesce(p_active_flag, t.active_flag),
               sort_order = coalesce(p_sort_order, t.sort_order)
         WHERE t.person_qualification_type_id = p_person_qualification_type_id
         RETURNING t.person_qualification_type_id INTO v_id;

        IF v_id IS NULL THEN
            RAISE EXCEPTION USING ERRCODE = 'P0002', MESSAGE = 'Qualification type was not found';
        END IF;
    END IF;

    RETURN QUERY
    SELECT
        t.person_qualification_type_id,
        t.qualification_name,
        t.active_flag,
        t.updated_at
    FROM ref.person_qualification_type t
    WHERE t.person_qualification_type_id = v_id;
END;
$function$;

CREATE OR REPLACE FUNCTION ref.upsert_people_person_qualification(
    p_operator_email text,
    p_person_qualification_id bigint,
    p_person_id integer,
    p_person_qualification_type_id integer,
    p_completed_on date DEFAULT NULL,
    p_valid_from date DEFAULT NULL,
    p_expires_on date DEFAULT NULL,
    p_qualification_role text DEFAULT NULL,
    p_certificate_number text DEFAULT NULL,
    p_evidence_reference text DEFAULT NULL,
    p_active_flag boolean DEFAULT true,
    p_notes text DEFAULT NULL
)
RETURNS TABLE (
    person_qualification_id bigint,
    person_id integer,
    person_qualification_type_id integer,
    active_flag boolean,
    updated_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, ref
AS $function$
DECLARE
    v_directus_user_id uuid;
    v_actor_person_id integer;
    v_id bigint;
BEGIN
    SELECT a.directus_user_id, a.person_id
      INTO v_directus_user_id, v_actor_person_id
    FROM ref.people_management_actor(p_operator_email) a;

    IF NOT EXISTS (SELECT 1 FROM ref.person p WHERE p.person_id = p_person_id) THEN
        RAISE EXCEPTION USING ERRCODE = 'P0002', MESSAGE = 'Person was not found';
    END IF;
    IF NOT EXISTS (
        SELECT 1
        FROM ref.person_qualification_type t
        WHERE t.person_qualification_type_id = p_person_qualification_type_id
    ) THEN
        RAISE EXCEPTION USING ERRCODE = 'P0002', MESSAGE = 'Qualification type was not found';
    END IF;
    IF p_expires_on IS NOT NULL
       AND p_valid_from IS NOT NULL
       AND p_expires_on < p_valid_from THEN
        RAISE EXCEPTION USING ERRCODE = '22023',
            MESSAGE = 'Qualification expiration cannot be before valid-from date';
    END IF;

    PERFORM pg_catalog.set_config('app.directus_user_uuid', v_directus_user_id::text, true);

    IF p_person_qualification_id IS NULL THEN
        INSERT INTO ref.person_qualification(
            person_id,
            person_qualification_type_id,
            completed_on,
            valid_from,
            expires_on,
            qualification_role,
            certificate_number,
            evidence_reference,
            active_flag,
            notes
        )
        VALUES(
            p_person_id,
            p_person_qualification_type_id,
            p_completed_on,
            p_valid_from,
            p_expires_on,
            nullif(btrim(p_qualification_role), ''),
            nullif(btrim(p_certificate_number), ''),
            nullif(btrim(p_evidence_reference), ''),
            coalesce(p_active_flag, true),
            nullif(btrim(p_notes), '')
        )
        RETURNING ref.person_qualification.person_qualification_id INTO v_id;
    ELSE
        UPDATE ref.person_qualification q
           SET person_qualification_type_id = p_person_qualification_type_id,
               completed_on = p_completed_on,
               valid_from = p_valid_from,
               expires_on = p_expires_on,
               qualification_role = nullif(btrim(p_qualification_role), ''),
               certificate_number = nullif(btrim(p_certificate_number), ''),
               evidence_reference = nullif(btrim(p_evidence_reference), ''),
               active_flag = coalesce(p_active_flag, q.active_flag),
               notes = nullif(btrim(p_notes), '')
         WHERE q.person_qualification_id = p_person_qualification_id
           AND q.person_id = p_person_id
         RETURNING q.person_qualification_id INTO v_id;

        IF v_id IS NULL THEN
            RAISE EXCEPTION USING ERRCODE = 'P0002',
                MESSAGE = 'Qualification record was not found for this person';
        END IF;
    END IF;

    RETURN QUERY
    SELECT
        q.person_qualification_id,
        q.person_id,
        q.person_qualification_type_id,
        q.active_flag,
        q.updated_at
    FROM ref.person_qualification q
    WHERE q.person_qualification_id = v_id;
END;
$function$;

CREATE OR REPLACE FUNCTION ref.set_people_person_setup_role(
    p_operator_email text,
    p_person_id integer,
    p_setup_role text,
    p_active_flag boolean DEFAULT true,
    p_notes text DEFAULT NULL
)
RETURNS TABLE (
    person_id integer,
    setup_role text,
    active_flag boolean,
    updated_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, ref
AS $function$
DECLARE
    v_directus_user_id uuid;
    v_actor_person_id integer;
    v_role text := upper(btrim(coalesce(p_setup_role, '')));
BEGIN
    SELECT a.directus_user_id, a.person_id
      INTO v_directus_user_id, v_actor_person_id
    FROM ref.people_management_actor(p_operator_email) a;

    IF NOT EXISTS (SELECT 1 FROM ref.person p WHERE p.person_id = p_person_id) THEN
        RAISE EXCEPTION USING ERRCODE = 'P0002', MESSAGE = 'Person was not found';
    END IF;
    IF v_role NOT IN (
        'SETUP_VOLUNTEER',
        'TAKEDOWN_VOLUNTEER',
        'CAPTAIN_CANDIDATE',
        'ADVISOR_CANDIDATE'
    ) THEN
        RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Setup role is invalid';
    END IF;

    PERFORM pg_catalog.set_config('app.directus_user_uuid', v_directus_user_id::text, true);

    INSERT INTO ref.person_setup_role(person_id, setup_role, active_flag, notes)
    VALUES(
        p_person_id, v_role, coalesce(p_active_flag, true),
        nullif(btrim(p_notes), '')
    )
    ON CONFLICT ON CONSTRAINT pk_person_setup_role
    DO UPDATE SET
        active_flag = EXCLUDED.active_flag,
        notes = EXCLUDED.notes;

    RETURN QUERY
    SELECT r.person_id, r.setup_role, r.active_flag, r.updated_at
    FROM ref.person_setup_role r
    WHERE r.person_id = p_person_id
      AND r.setup_role = v_role;
END;
$function$;

/* --------------------------------------------------------------------------
   LEAST-PRIVILEGE BOUNDARY
   -------------------------------------------------------------------------- */

REVOKE ALL ON TABLE ref.person_capability_type FROM people_app;
REVOKE ALL ON TABLE ref.person_capability FROM people_app;
REVOKE ALL ON TABLE ref.person_qualification_type FROM people_app;
REVOKE ALL ON TABLE ref.person_qualification FROM people_app;
REVOKE ALL ON TABLE ref.person_setup_role FROM people_app;
REVOKE ALL ON TABLE ref.setup_task FROM people_app;
REVOKE ALL ON TABLE ref.setup_task_captain FROM people_app;

REVOKE ALL ON FUNCTION ref.people_capability_catalog(text, boolean) FROM PUBLIC;
REVOKE ALL ON FUNCTION ref.people_qualification_catalog(text, boolean) FROM PUBLIC;
REVOKE ALL ON FUNCTION ref.people_person_capabilities(text, integer, boolean) FROM PUBLIC;
REVOKE ALL ON FUNCTION ref.people_person_qualifications(text, integer, boolean) FROM PUBLIC;
REVOKE ALL ON FUNCTION ref.people_person_setup_roles(text, integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION ref.people_person_task_leadership(text, integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION ref.upsert_people_capability_type(text, integer, text, text, text, boolean, integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION ref.set_people_person_capability(text, integer, integer, boolean, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION ref.upsert_people_qualification_type(text, integer, text, text, boolean, integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION ref.upsert_people_person_qualification(text, bigint, integer, integer, date, date, date, text, text, text, boolean, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION ref.set_people_person_setup_role(text, integer, text, boolean, text) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION ref.people_capability_catalog(text, boolean) TO people_app;
GRANT EXECUTE ON FUNCTION ref.people_qualification_catalog(text, boolean) TO people_app;
GRANT EXECUTE ON FUNCTION ref.people_person_capabilities(text, integer, boolean) TO people_app;
GRANT EXECUTE ON FUNCTION ref.people_person_qualifications(text, integer, boolean) TO people_app;
GRANT EXECUTE ON FUNCTION ref.people_person_setup_roles(text, integer) TO people_app;
GRANT EXECUTE ON FUNCTION ref.people_person_task_leadership(text, integer) TO people_app;
GRANT EXECUTE ON FUNCTION ref.upsert_people_capability_type(text, integer, text, text, text, boolean, integer) TO people_app;
GRANT EXECUTE ON FUNCTION ref.set_people_person_capability(text, integer, integer, boolean, text) TO people_app;
GRANT EXECUTE ON FUNCTION ref.upsert_people_qualification_type(text, integer, text, text, boolean, integer) TO people_app;
GRANT EXECUTE ON FUNCTION ref.upsert_people_person_qualification(text, bigint, integer, integer, date, date, date, text, text, text, boolean, text) TO people_app;
GRANT EXECUTE ON FUNCTION ref.set_people_person_setup_role(text, integer, text, boolean, text) TO people_app;

COMMIT;

SELECT
    '2026-09-09-people-metadata-v0.2.0' AS applied_revision,
    current_user AS applied_by,
    has_table_privilege('people_app', 'ref.person_capability', 'INSERT')
        AS people_app_direct_capability_insert,
    has_function_privilege(
        'people_app',
        'ref.set_people_person_capability(text,integer,integer,boolean,text)',
        'EXECUTE'
    ) AS people_app_can_set_capability,
    has_function_privilege(
        'people_app',
        'ref.upsert_people_person_qualification(text,bigint,integer,integer,date,date,date,text,text,text,boolean,text)',
        'EXECUTE'
    ) AS people_app_can_set_qualification;
