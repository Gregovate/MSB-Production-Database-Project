/* MSB Setup #167 — preserve current Production Kit assignments during one-time reconstruction.
   REVIEW BEFORE PRODUCTION.

   Historical note:
   An earlier disposable workbench captured 20 candidate task -> Kit relationships.
   Managers subsequently completed the real reusable task -> KIT assignments through
   the Production Setup UI. Those current Production relationships are now the
   authoritative operator record and supersede the earlier disposable capture.

   Boundary:
   - this migration MUST NOT insert, update, or delete task -> KIT assignments;
   - current ref.setup_task_container_support rows are preserved exactly as found;
   - relationship_type='KIT' remains the only authoritative Kit assignment contract;
   - invalid current KIT rows fail closed for review instead of being repaired here;
   - no task, Container, Display, Extra Material, inventory event, or 2026 Setup
     Session identity is created here.
*/
BEGIN;

DO $preflight$
DECLARE
    v_invalid_kit_containers integer;
    v_invalid_tasks integer;
BEGIN
    IF to_regclass('ref.setup_task_container_support') IS NULL
       OR to_regclass('ref.setup_task') IS NULL
       OR to_regclass('ref.container') IS NULL THEN
        RAISE EXCEPTION 'Current Setup task/container assignment foundation is required';
    END IF;

    SELECT count(*) INTO v_invalid_kit_containers
    FROM ref.setup_task_container_support tc
    JOIN ref.container c ON c.container_id=tc.container_id
    WHERE tc.relationship_type='KIT'
      AND c.container_type_id <> 2;

    IF v_invalid_kit_containers <> 0 THEN
        RAISE EXCEPTION 'Current Production contains % KIT relationships to non-Kit-Box Containers; reconcile before #167 migration',
            v_invalid_kit_containers;
    END IF;

    SELECT count(*) INTO v_invalid_tasks
    FROM ref.setup_task_container_support tc
    LEFT JOIN ref.setup_task t ON t.setup_task_id=tc.setup_task_id
    WHERE tc.relationship_type='KIT'
      AND (t.setup_task_id IS NULL OR NOT t.active_flag OR t.stage_id IS NULL);

    IF v_invalid_tasks <> 0 THEN
        RAISE EXCEPTION 'Current Production contains % KIT relationships to missing/inactive/unscoped reusable tasks; reconcile before #167 migration',
            v_invalid_tasks;
    END IF;
END
$preflight$;

DO $proof$
BEGIN
    IF EXISTS (SELECT 1 FROM ops.setup_session WHERE season_year=2026) THEN
        RAISE EXCEPTION '#167 Kit-assignment preservation step unexpectedly found a 2026 Setup Session';
    END IF;
END
$proof$;

COMMIT;

/* Read-only evidence of the authoritative current Production KIT assignments. */
SELECT
    tc.setup_task_id,
    s.stage_key,
    t.task_name,
    tc.container_id,
    c.description AS container_description,
    tc.relationship_type,
    tc.notes
FROM ref.setup_task_container_support tc
JOIN ref.setup_task t ON t.setup_task_id=tc.setup_task_id
LEFT JOIN ref.stage s ON s.stage_id=t.stage_id
JOIN ref.container c ON c.container_id=tc.container_id
WHERE tc.relationship_type='KIT'
ORDER BY s.park_order NULLS LAST, s.sub_order NULLS LAST,
         t.display_order, tc.setup_task_id, tc.container_id;
