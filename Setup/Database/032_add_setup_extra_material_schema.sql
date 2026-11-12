/* MSB Setup #167 — Extra Material schema foundation. REVIEW BEFORE PRODUCTION. */
BEGIN;

DO $preflight$
BEGIN
    IF to_regclass('ref.setup_task') IS NULL
       OR to_regclass('ref.container') IS NULL
       OR to_regclass('ref.person') IS NULL
       OR to_regprocedure('ref.set_actor_on_insert()') IS NULL
       OR to_regprocedure('ref.set_actor_on_update()') IS NULL THEN
        RAISE EXCEPTION 'Current Setup/container/audit foundation is required first';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'fieldwiring_app') THEN
        RAISE EXCEPTION 'Required application role fieldwiring_app does not exist';
    END IF;
END
$preflight$;

/* One catalog row per normalized material family. Size/length/color live on
   task requirement and Container expected-content rows. */
CREATE TABLE IF NOT EXISTS ref.setup_extra_material (
    setup_extra_material_id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    material_name text NOT NULL UNIQUE,
    lifecycle_class text NOT NULL DEFAULT 'REUSABLE',
    default_uom text NOT NULL DEFAULT 'EA',
    active_flag boolean NOT NULL DEFAULT true,
    display_order integer NOT NULL DEFAULT 100,
    notes text,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by text NOT NULL DEFAULT current_user,
    updated_at timestamptz NOT NULL DEFAULT now(),
    updated_by text NOT NULL DEFAULT current_user,
    created_by_person_id integer REFERENCES ref.person(person_id),
    updated_by_person_id integer REFERENCES ref.person(person_id),
    CONSTRAINT ck_setup_extra_material_lifecycle CHECK (
        lifecycle_class IN ('REUSABLE','CONSUMABLE','TEMP_REUSABLE','SPARE_REPLACEMENT')
    ),
    CONSTRAINT ck_setup_extra_material_uom CHECK (btrim(default_uom) <> ''),
    CONSTRAINT ck_setup_extra_material_order CHECK (display_order >= 0)
);

CREATE INDEX IF NOT EXISTS ix_setup_extra_material_catalog
ON ref.setup_extra_material(active_flag, display_order, material_name, setup_extra_material_id);

CREATE TABLE IF NOT EXISTS ref.setup_task_extra_material (
    setup_task_extra_material_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    setup_task_id bigint NOT NULL REFERENCES ref.setup_task(setup_task_id),
    setup_extra_material_id integer NOT NULL REFERENCES ref.setup_extra_material(setup_extra_material_id),
    quantity_required numeric(12,3),
    quantity_uom text NOT NULL DEFAULT 'EA',
    size_text text,
    length_value numeric(12,3),
    length_unit text,
    color text,
    quantity_qualifier text NOT NULL DEFAULT 'EXACT',
    verification_state text NOT NULL DEFAULT 'UNVERIFIED',
    notes text,
    active_flag boolean NOT NULL DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by text NOT NULL DEFAULT current_user,
    updated_at timestamptz NOT NULL DEFAULT now(),
    updated_by text NOT NULL DEFAULT current_user,
    created_by_person_id integer REFERENCES ref.person(person_id),
    updated_by_person_id integer REFERENCES ref.person(person_id),
    CONSTRAINT ck_setup_task_extra_material_qty CHECK (quantity_required IS NULL OR quantity_required > 0),
    CONSTRAINT ck_setup_task_extra_material_uom CHECK (btrim(quantity_uom) <> ''),
    CONSTRAINT ck_setup_task_extra_material_length CHECK (
        (length_value IS NULL AND length_unit IS NULL)
        OR (length_value > 0 AND length_unit IN ('IN','FT','MM','CM','M'))
    ),
    CONSTRAINT ck_setup_task_extra_material_qualifier CHECK (
        quantity_qualifier IN ('EXACT','MINIMUM','CONDITIONAL','SPARE')
    ),
    CONSTRAINT ck_setup_task_extra_material_verify CHECK (
        verification_state IN ('UNVERIFIED','VERIFIED','NEEDS_REVIEW')
    )
);
CREATE INDEX IF NOT EXISTS ix_setup_task_extra_material_task
ON ref.setup_task_extra_material(setup_task_id, active_flag, setup_extra_material_id);

/* Source allocation is independent of existing task->KIT assignment and permits
   shared stock (for example T-post pallet 36) or split sources. */
CREATE TABLE IF NOT EXISTS ref.setup_task_extra_material_source (
    setup_task_extra_material_source_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    setup_task_extra_material_id bigint NOT NULL REFERENCES ref.setup_task_extra_material(setup_task_extra_material_id),
    container_id integer NOT NULL REFERENCES ref.container(container_id),
    expected_quantity numeric(12,3),
    verification_state text NOT NULL DEFAULT 'UNVERIFIED',
    notes text,
    active_flag boolean NOT NULL DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by text NOT NULL DEFAULT current_user,
    updated_at timestamptz NOT NULL DEFAULT now(),
    updated_by text NOT NULL DEFAULT current_user,
    created_by_person_id integer REFERENCES ref.person(person_id),
    updated_by_person_id integer REFERENCES ref.person(person_id),
    CONSTRAINT ck_setup_task_extra_material_source_qty CHECK (expected_quantity IS NULL OR expected_quantity > 0),
    CONSTRAINT ck_setup_task_extra_material_source_verify CHECK (
        verification_state IN ('UNVERIFIED','VERIFIED','NEEDS_REVIEW')
    )
);
CREATE INDEX IF NOT EXISTS ix_setup_task_extra_material_source_requirement
ON ref.setup_task_extra_material_source(setup_task_extra_material_id, active_flag, container_id);

/* Existing ref.container identity owns expected contents. Multiple rows for one
   material are valid when size/length/color differ. */
CREATE TABLE IF NOT EXISTS ref.setup_container_extra_material (
    setup_container_extra_material_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    container_id integer NOT NULL REFERENCES ref.container(container_id),
    setup_extra_material_id integer NOT NULL REFERENCES ref.setup_extra_material(setup_extra_material_id),
    expected_quantity numeric(12,3),
    quantity_uom text NOT NULL DEFAULT 'EA',
    size_text text,
    length_value numeric(12,3),
    length_unit text,
    color text,
    verification_state text NOT NULL DEFAULT 'UNVERIFIED',
    notes text,
    active_flag boolean NOT NULL DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by text NOT NULL DEFAULT current_user,
    updated_at timestamptz NOT NULL DEFAULT now(),
    updated_by text NOT NULL DEFAULT current_user,
    created_by_person_id integer REFERENCES ref.person(person_id),
    updated_by_person_id integer REFERENCES ref.person(person_id),
    CONSTRAINT ck_setup_container_extra_material_qty CHECK (expected_quantity IS NULL OR expected_quantity > 0),
    CONSTRAINT ck_setup_container_extra_material_uom CHECK (btrim(quantity_uom) <> ''),
    CONSTRAINT ck_setup_container_extra_material_length CHECK (
        (length_value IS NULL AND length_unit IS NULL)
        OR (length_value > 0 AND length_unit IN ('IN','FT','MM','CM','M'))
    ),
    CONSTRAINT ck_setup_container_extra_material_verify CHECK (
        verification_state IN ('UNVERIFIED','VERIFIED','NEEDS_REVIEW')
    )
);
CREATE INDEX IF NOT EXISTS ix_setup_container_extra_material_container
ON ref.setup_container_extra_material(container_id, active_flag, setup_extra_material_id);

/* One temporary free-text reconciliation record per Container. This is not an
   Extra Material identity and can be deleted once physical verification resolves it. */
CREATE TABLE IF NOT EXISTS ref.setup_container_extra_material_review (
    container_id integer PRIMARY KEY REFERENCES ref.container(container_id),
    unverified_items_text text NOT NULL CHECK (btrim(unverified_items_text) <> ''),
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by text NOT NULL DEFAULT current_user,
    updated_at timestamptz NOT NULL DEFAULT now(),
    updated_by text NOT NULL DEFAULT current_user,
    created_by_person_id integer REFERENCES ref.person(person_id),
    updated_by_person_id integer REFERENCES ref.person(person_id)
);

/* Append-only durable inventory ledger. Expected contents and requirements are
   never rewritten by inventory loss/correction events. */
CREATE TABLE IF NOT EXISTS ops.setup_extra_material_inventory_event (
    setup_extra_material_inventory_event_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    setup_container_extra_material_id bigint NOT NULL REFERENCES ref.setup_container_extra_material(setup_container_extra_material_id),
    event_type text NOT NULL,
    quantity_delta numeric(12,3) NOT NULL,
    event_note text,
    occurred_at timestamptz NOT NULL DEFAULT now(),
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by text NOT NULL DEFAULT current_user,
    updated_at timestamptz NOT NULL DEFAULT now(),
    updated_by text NOT NULL DEFAULT current_user,
    created_by_person_id integer REFERENCES ref.person(person_id),
    updated_by_person_id integer REFERENCES ref.person(person_id),
    CONSTRAINT ck_setup_extra_material_inventory_event_type CHECK (
        event_type IN ('INITIAL_COUNT','RECEIPT','RETURN','COUNT_CORRECTION','DAMAGE_LOSS','CONSUMPTION','TRANSFER_IN','TRANSFER_OUT','OTHER')
    ),
    CONSTRAINT ck_setup_extra_material_inventory_event_nonzero CHECK (quantity_delta <> 0),
    CONSTRAINT ck_setup_extra_material_inventory_event_sign CHECK (
        (event_type IN ('INITIAL_COUNT','RECEIPT','RETURN','TRANSFER_IN') AND quantity_delta > 0)
        OR (event_type IN ('DAMAGE_LOSS','CONSUMPTION','TRANSFER_OUT') AND quantity_delta < 0)
        OR event_type IN ('COUNT_CORRECTION','OTHER')
    )
);
CREATE INDEX IF NOT EXISTS ix_setup_extra_material_inventory_event_content
ON ops.setup_extra_material_inventory_event(setup_container_extra_material_id, occurred_at, setup_extra_material_inventory_event_id);

CREATE OR REPLACE VIEW ops.setup_extra_material_inventory_balance AS
SELECT
    cem.setup_container_extra_material_id,
    cem.container_id,
    cem.setup_extra_material_id,
    m.material_name,
    cem.size_text,
    cem.length_value,
    cem.length_unit,
    cem.color,
    cem.quantity_uom,
    count(e.setup_extra_material_inventory_event_id) AS inventory_event_count,
    CASE WHEN count(e.setup_extra_material_inventory_event_id) = 0 THEN NULL
         ELSE sum(e.quantity_delta) END AS on_hand_quantity,
    max(e.occurred_at) AS last_inventory_event_at
FROM ref.setup_container_extra_material cem
JOIN ref.setup_extra_material m ON m.setup_extra_material_id = cem.setup_extra_material_id
LEFT JOIN ops.setup_extra_material_inventory_event e
  ON e.setup_container_extra_material_id = cem.setup_container_extra_material_id
WHERE cem.active_flag
GROUP BY cem.setup_container_extra_material_id, cem.container_id,
         cem.setup_extra_material_id, m.material_name, cem.size_text,
         cem.length_value, cem.length_unit, cem.color, cem.quantity_uom;

DO $triggers$
DECLARE v_table text;
BEGIN
    FOREACH v_table IN ARRAY ARRAY[
        'setup_extra_material','setup_task_extra_material',
        'setup_task_extra_material_source','setup_container_extra_material',
        'setup_container_extra_material_review'
    ] LOOP
        EXECUTE format('DROP TRIGGER IF EXISTS %I ON ref.%I', 'trg_'||v_table||'_actor_insert', v_table);
        EXECUTE format('CREATE TRIGGER %I BEFORE INSERT ON ref.%I FOR EACH ROW EXECUTE FUNCTION ref.set_actor_on_insert()', 'trg_'||v_table||'_actor_insert', v_table);
        EXECUTE format('DROP TRIGGER IF EXISTS %I ON ref.%I', 'trg_'||v_table||'_actor_update', v_table);
        EXECUTE format('CREATE TRIGGER %I BEFORE UPDATE ON ref.%I FOR EACH ROW EXECUTE FUNCTION ref.set_actor_on_update()', 'trg_'||v_table||'_actor_update', v_table);
    END LOOP;
END
$triggers$;

DROP TRIGGER IF EXISTS trg_setup_extra_material_inventory_event_actor_insert ON ops.setup_extra_material_inventory_event;
CREATE TRIGGER trg_setup_extra_material_inventory_event_actor_insert
BEFORE INSERT ON ops.setup_extra_material_inventory_event
FOR EACH ROW EXECUTE FUNCTION ref.set_actor_on_insert();

GRANT SELECT ON ref.setup_extra_material, ref.setup_task_extra_material,
    ref.setup_task_extra_material_source, ref.setup_container_extra_material,
    ref.setup_container_extra_material_review TO fieldwiring_app;
GRANT SELECT ON ops.setup_extra_material_inventory_event,
    ops.setup_extra_material_inventory_balance TO fieldwiring_app;

REVOKE INSERT, UPDATE, DELETE ON ref.setup_extra_material,
    ref.setup_task_extra_material, ref.setup_task_extra_material_source,
    ref.setup_container_extra_material, ref.setup_container_extra_material_review
    FROM fieldwiring_app;
REVOKE INSERT, UPDATE, DELETE ON ops.setup_extra_material_inventory_event FROM fieldwiring_app;

COMMENT ON TABLE ref.setup_task_extra_material IS
'Reusable task Extra Material requirements. Procedure/verified installation quantities such as T-post totals belong at task/installation scope, not as 2 posts per Display.';
COMMENT ON TABLE ref.setup_container_extra_material IS
'Expected normalized Extra Material contents of an existing ref.container; expected quantity is not a physical inventory count.';
COMMENT ON TABLE ref.setup_container_extra_material_review IS
'Temporary unverified-items text per Container; not an Extra Material catalog identity.';
COMMENT ON TABLE ops.setup_extra_material_inventory_event IS
'Append-only durable physical inventory adjustments; loss during takedown reduces on-hand inventory without changing reusable requirements.';
COMMENT ON VIEW ops.setup_extra_material_inventory_balance IS
'Current inventory balance derived from ledger events. NULL on_hand_quantity means no physical count is recorded; it is not zero.';

COMMIT;

SELECT
    to_regclass('ref.setup_extra_material') IS NOT NULL AS catalog_exists,
    to_regclass('ref.setup_container_extra_material') IS NOT NULL AS container_contents_exists,
    to_regclass('ops.setup_extra_material_inventory_event') IS NOT NULL AS inventory_ledger_exists,
    has_table_privilege('fieldwiring_app','ref.setup_extra_material','INSERT') AS broad_catalog_insert,
    has_table_privilege('fieldwiring_app','ops.setup_extra_material_inventory_event','UPDATE') AS broad_inventory_update;
