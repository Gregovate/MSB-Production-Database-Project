/* MSB Setup #167 — forward correction for omitted Elf Choir T-Post requirement.
   REVIEW BEFORE PRODUCTION.

   Browser integration review exposed that the accepted #167 proof case was only
   represented on the stock side (Containers 36/118). The reusable task
   requirement itself was missing.

   Confirmed procedure/reconciliation fact:
   - reusable task 16, Install Notes and Conductor, Stage 08 Elf Choir;
   - 20 T-Posts total: 18 Note panels + 2 Conductor panels;
   - T-Post length/height is not stated and remains unresolved;
   - normal panel T-Post stock is separate from Kit 60 and is sourced from the
     shared panel T-Post stock Container 36;
   - no physical inventory count is created by this migration.
*/
BEGIN;

DO $preflight$
BEGIN
    IF to_regclass('ref.setup_task_extra_material') IS NULL
       OR to_regclass('ref.setup_task_extra_material_source') IS NULL
       OR to_regclass('ref.setup_extra_material') IS NULL THEN
        RAISE EXCEPTION 'Durable #184 Extra Material foundation is required first';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM ref.setup_task t
        JOIN ref.stage s ON s.stage_id=t.stage_id
        WHERE t.setup_task_id=16
          AND t.active_flag
          AND s.stage_key='08'
          AND t.task_name='Install Notes and Conductor'
    ) THEN
        RAISE EXCEPTION 'Expected active Elf Choir reusable task 16 / Install Notes and Conductor was not found';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM ref.setup_extra_material
        WHERE material_name='T-Post' AND active_flag
    ) THEN
        RAISE EXCEPTION 'Normalized active T-Post Extra Material is required';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM ref.container WHERE container_id=36) THEN
        RAISE EXCEPTION 'Shared panel T-Post stock Container 36 is required';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM ref.setup_task_extra_material tm
        JOIN ref.setup_extra_material m USING (setup_extra_material_id)
        WHERE tm.setup_task_id=16
          AND tm.active_flag
          AND m.material_name='T-Post'
          AND (
              tm.quantity_required IS DISTINCT FROM 20::numeric
              OR tm.quantity_uom <> 'EA'
              OR tm.length_value IS NOT NULL
              OR tm.length_unit IS NOT NULL
          )
    ) THEN
        RAISE EXCEPTION 'Existing Elf Choir T-Post requirement conflicts with confirmed 20 EA / unresolved-length evidence';
    END IF;
END
$preflight$;

INSERT INTO ref.setup_task_extra_material(
    setup_task_id,
    setup_extra_material_id,
    quantity_required,
    quantity_uom,
    size_text,
    length_value,
    length_unit,
    color,
    quantity_qualifier,
    verification_state,
    notes,
    active_flag
)
SELECT
    16,
    m.setup_extra_material_id,
    20,
    'EA',
    NULL,
    NULL,
    NULL,
    NULL,
    'EXACT',
    'UNVERIFIED',
    '08-Elf Choir-EC procedure: 20 T-Posts required for Install Notes and Conductor (18 Note panels + 2 Conductor panels). Length/height is not stated and remains unresolved.',
    true
FROM ref.setup_extra_material m
WHERE m.material_name='T-Post'
  AND m.active_flag
  AND NOT EXISTS (
      SELECT 1
      FROM ref.setup_task_extra_material tm
      WHERE tm.setup_task_id=16
        AND tm.setup_extra_material_id=m.setup_extra_material_id
        AND tm.active_flag
  );

WITH requirement AS (
    SELECT tm.setup_task_extra_material_id
    FROM ref.setup_task_extra_material tm
    JOIN ref.setup_extra_material m USING (setup_extra_material_id)
    WHERE tm.setup_task_id=16
      AND tm.active_flag
      AND m.material_name='T-Post'
)
INSERT INTO ref.setup_task_extra_material_source(
    setup_task_extra_material_id,
    container_id,
    expected_quantity,
    verification_state,
    notes,
    active_flag
)
SELECT
    r.setup_task_extra_material_id,
    36,
    20,
    'UNVERIFIED',
    'Shared T-Post stock used for panel work. Physical on-hand count remains independent of this 20-post task requirement.',
    true
FROM requirement r
WHERE NOT EXISTS (
    SELECT 1
    FROM ref.setup_task_extra_material_source src
    WHERE src.setup_task_extra_material_id=r.setup_task_extra_material_id
      AND src.container_id=36
      AND src.active_flag
);

DO $proof$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM ref.setup_task_extra_material tm
        JOIN ref.setup_extra_material m USING (setup_extra_material_id)
        WHERE tm.setup_task_id=16
          AND tm.active_flag
          AND m.material_name='T-Post'
          AND tm.quantity_required=20
          AND tm.quantity_uom='EA'
          AND tm.length_value IS NULL
          AND tm.length_unit IS NULL
          AND tm.verification_state='UNVERIFIED'
    ) THEN
        RAISE EXCEPTION 'Elf Choir 20 EA unresolved-length T-Post task requirement is missing';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM ref.setup_task_extra_material tm
        JOIN ref.setup_extra_material m USING (setup_extra_material_id)
        JOIN ref.setup_task_extra_material_source src
          ON src.setup_task_extra_material_id=tm.setup_task_extra_material_id
        WHERE tm.setup_task_id=16
          AND tm.active_flag
          AND m.material_name='T-Post'
          AND src.container_id=36
          AND src.expected_quantity=20
          AND src.verification_state='UNVERIFIED'
          AND src.active_flag
    ) THEN
        RAISE EXCEPTION 'Elf Choir T-Post requirement is not linked to shared panel stock Container 36';
    END IF;

    IF EXISTS (SELECT 1 FROM ops.setup_session WHERE season_year=2026) THEN
        RAISE EXCEPTION '#167 Elf Choir correction unexpectedly created a 2026 Setup Session';
    END IF;
END
$proof$;

COMMIT;

SELECT
    tm.setup_task_id,
    m.material_name,
    tm.quantity_required,
    tm.quantity_uom,
    tm.length_value,
    tm.length_unit,
    tm.verification_state,
    src.container_id AS source_container_id,
    src.expected_quantity AS source_expected_quantity
FROM ref.setup_task_extra_material tm
JOIN ref.setup_extra_material m USING (setup_extra_material_id)
LEFT JOIN ref.setup_task_extra_material_source src
  ON src.setup_task_extra_material_id=tm.setup_task_extra_material_id
 AND src.active_flag
WHERE tm.setup_task_id=16
  AND tm.active_flag
  AND m.material_name='T-Post';
