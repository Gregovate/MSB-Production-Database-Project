/* ============================================================================
Label Print human-readable requester item identities
Issues: LabelPrintService #36; Database #122
Revision: 2026-10-28 V0.1.0 CANDIDATE

Requester emails may include durable IDs for traceability, but never without
the corresponding human-readable asset identity.
============================================================================ */

BEGIN;

DO $preflight$
BEGIN
    IF current_database() NOT IN ('msb', 'msb_label_print_preview') THEN
        RAISE EXCEPTION 'Label Print item names: unrecognized database';
    END IF;
    IF current_database() = 'msb'
       AND current_setting('msb.label_print_notifications_approved', true)
           IS DISTINCT FROM 'approved_maintenance_snapshot' THEN
        RAISE EXCEPTION
            'Label Print item names: approved maintenance snapshot required';
    END IF;
    IF current_database() = 'msb_label_print_preview'
       AND current_setting('msb.label_print_preview_authorized', true)
           IS DISTINCT FROM 'approved_disposable_clone' THEN
        RAISE EXCEPTION
            'Label Print item names: disposable clone authorization required';
    END IF;
    IF to_regclass('ops.label_print_notification_outbox') IS NULL
       OR to_regclass('ref.display') IS NULL
       OR to_regclass('ref.container') IS NULL
       OR to_regclass('ref.controller') IS NULL
       OR to_regclass('ref.controller_model') IS NULL THEN
        RAISE EXCEPTION 'Required Label Print asset identity tables are absent';
    END IF;
END
$preflight$;

CREATE FUNCTION ops.label_print_request_item_display(
    p_workload_type text,
    p_asset_id bigint
) RETURNS text
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, ref
AS $display$
DECLARE
    v_display text;
BEGIN
    IF p_workload_type = 'DISPLAY' THEN
        SELECT format('%s (Display ID %s)', d.display_name, d.display_id)
          INTO v_display
        FROM ref.display d
        WHERE d.display_id = p_asset_id;
    ELSIF p_workload_type = 'CONTAINER' THEN
        SELECT format(
                   '%s (C%s)',
                   coalesce(
                       nullif(btrim(c.description), ''),
                       nullif(btrim(c.location_code), ''),
                       'Container'
                   ),
                   lpad(c.container_id::text, 3, '0')
               )
          INTO v_display
        FROM ref.container c
        WHERE c.container_id = p_asset_id;
    ELSIF p_workload_type = 'CONTROLLER' THEN
        SELECT format(
                   '%s — %s (CTRL:%s)',
                   m.model_code,
                   m.model_name,
                   c.controller_id
               )
          INTO v_display
        FROM ref.controller c
        JOIN ref.controller_model m
          ON m.controller_model_id = c.controller_model_id
        WHERE c.controller_id = p_asset_id;
    ELSE
        RAISE EXCEPTION 'Unsupported Label Print workload type: %',
            p_workload_type;
    END IF;

    RETURN coalesce(
        v_display,
        format('%s name unavailable (ID %s)', initcap(p_workload_type), p_asset_id)
    );
END
$display$;

COMMENT ON FUNCTION ops.label_print_request_item_display(text, bigint) IS
    'Returns a human-readable asset name plus its durable ID for requester mail.';

CREATE FUNCTION ops.label_print_humanize_outbox_request_items()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, ops
AS $humanize$
DECLARE
    v_items jsonb;
BEGIN
    IF NEW.audience <> 'REQUESTER'
       OR jsonb_typeof(NEW.payload -> 'request_items') IS DISTINCT FROM 'array'
    THEN
        RETURN NEW;
    END IF;

    SELECT jsonb_agg(
               CASE
                   WHEN item.value ~ '^(DISPLAY|CONTAINER|CONTROLLER):[0-9]+$'
                   THEN to_jsonb(ops.label_print_request_item_display(
                       split_part(item.value, ':', 1),
                       split_part(item.value, ':', 2)::bigint
                   ))
                   ELSE to_jsonb(item.value)
               END
               ORDER BY item.ordinality
           )
      INTO v_items
    FROM jsonb_array_elements_text(
             NEW.payload -> 'request_items'
         ) WITH ORDINALITY AS item(value, ordinality);

    NEW.payload := jsonb_set(
        NEW.payload,
        '{request_items}',
        coalesce(v_items, '[]'::jsonb),
        true
    );
    RETURN NEW;
END
$humanize$;

COMMENT ON FUNCTION ops.label_print_humanize_outbox_request_items() IS
    'Replaces internal-only request item IDs with names plus IDs before mail delivery.';

DROP TRIGGER IF EXISTS trg_label_print_humanize_outbox_request_items
    ON ops.label_print_notification_outbox;
CREATE TRIGGER trg_label_print_humanize_outbox_request_items
BEFORE INSERT OR UPDATE OF payload
ON ops.label_print_notification_outbox
FOR EACH ROW
EXECUTE FUNCTION ops.label_print_humanize_outbox_request_items();

REVOKE ALL ON FUNCTION
    ops.label_print_request_item_display(text, bigint),
    ops.label_print_humanize_outbox_request_items()
FROM PUBLIC;

COMMIT;
