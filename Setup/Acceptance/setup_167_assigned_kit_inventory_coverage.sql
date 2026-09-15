/*
Issue #167 — read-only assigned Kit inventory reconstruction coverage

Purpose:
- use current reusable task -> KIT assignments as the reconciliation anchor;
- show whether each assigned physical Kit Box has normalized expected Extra
  Material rows and/or durable procedure remainder evidence;
- keep current physical Display contents visible but separate;
- identify assigned Kits that still have no reconstructed inventory evidence;
- do not treat shared T-Post/spacer stock as KIT assignments.

READ ONLY. Safe for Production verification.
*/
\set ON_ERROR_STOP on

WITH assigned_kits AS (
    SELECT
        tc.container_id,
        count(*) AS assignment_count,
        string_agg(
            format(
                'Task %s | Stage %s - %s | %s',
                t.setup_task_id,
                coalesce(s.stage_key, '—'),
                coalesce(s.stage_name, 'Unscoped'),
                t.task_name
            ),
            E'\n'
            ORDER BY
                s.park_order NULLS LAST,
                s.sub_order NULLS LAST,
                t.display_order,
                t.setup_task_id
        ) AS assigned_tasks
    FROM ref.setup_task_container_support tc
    JOIN ref.setup_task t
      ON t.setup_task_id = tc.setup_task_id
    LEFT JOIN ref.stage s
      ON s.stage_id = t.stage_id
    WHERE tc.relationship_type = 'KIT'
      AND t.active_flag
    GROUP BY tc.container_id
),
expected AS (
    SELECT
        cem.container_id,
        count(*) FILTER (WHERE cem.active_flag) AS active_expected_rows,
        count(*) FILTER (
            WHERE cem.active_flag
              AND (
                    cem.notes LIKE 'Procedure-derived Kit preload v6.%'
                 OR cem.notes LIKE 'Preloaded from MSB_Setup_Extra_Materials_Normalization_Staging_2026-09-13_v6.xlsx.%'
              )
        ) AS reconstructed_expected_rows,
        string_agg(
            concat_ws(
                ' | ',
                m.material_name,
                CASE
                    WHEN cem.expected_quantity IS NULL THEN 'qty unverified'
                    ELSE trim(to_char(cem.expected_quantity, 'FM999999990.###')) || ' ' || cem.quantity_uom
                END,
                nullif(cem.size_text, ''),
                CASE
                    WHEN cem.length_value IS NULL THEN NULL
                    ELSE trim(to_char(cem.length_value, 'FM999999990.###')) || ' ' || cem.length_unit
                END,
                nullif(cem.color, ''),
                cem.verification_state
            ),
            E'\n'
            ORDER BY m.material_name, cem.setup_container_extra_material_id
        ) FILTER (WHERE cem.active_flag) AS expected_materials
    FROM ref.setup_container_extra_material cem
    JOIN ref.setup_extra_material m
      ON m.setup_extra_material_id = cem.setup_extra_material_id
    GROUP BY cem.container_id
),
remainders AS (
    SELECT
        r.container_id,
        true AS has_remainder,
        r.unverified_items_text
    FROM ref.setup_container_extra_material_review r
),
displays AS (
    SELECT
        d.container_id,
        count(*) FILTER (
            WHERE upper(coalesce(ds.display_status_name, '')) <> 'RECYCLED'
        ) AS active_display_count,
        string_agg(
            d.display_name,
            ', '
            ORDER BY d.display_name
        ) FILTER (
            WHERE upper(coalesce(ds.display_status_name, '')) <> 'RECYCLED'
        ) AS stored_displays
    FROM ref.display d
    LEFT JOIN ref.display_status ds
      ON ds.display_status_id = d.display_status_id
    WHERE d.container_id IS NOT NULL
    GROUP BY d.container_id
)
SELECT
    c.container_id,
    c.description AS kit_name,
    c.location_code AS home_location,
    a.assignment_count,
    a.assigned_tasks,
    coalesce(e.active_expected_rows, 0) AS active_expected_rows,
    coalesce(e.reconstructed_expected_rows, 0) AS reconstructed_expected_rows,
    coalesce(r.has_remainder, false) AS has_remainder,
    CASE
        WHEN coalesce(e.reconstructed_expected_rows, 0) > 0 AND coalesce(r.has_remainder, false)
            THEN 'EXPECTED + REMAINDER'
        WHEN coalesce(e.reconstructed_expected_rows, 0) > 0
            THEN 'EXPECTED CONTENTS'
        WHEN coalesce(r.has_remainder, false)
            THEN 'REMAINDER ONLY'
        ELSE 'NO RECONSTRUCTED INVENTORY'
    END AS reconstruction_coverage,
    coalesce(d.active_display_count, 0) AS active_display_count,
    e.expected_materials,
    r.unverified_items_text,
    d.stored_displays
FROM assigned_kits a
JOIN ref.container c
  ON c.container_id = a.container_id
LEFT JOIN expected e
  ON e.container_id = a.container_id
LEFT JOIN remainders r
  ON r.container_id = a.container_id
LEFT JOIN displays d
  ON d.container_id = a.container_id
WHERE c.container_type_id = 2
ORDER BY
    CASE
        WHEN coalesce(e.reconstructed_expected_rows, 0) = 0 AND NOT coalesce(r.has_remainder, false) THEN 0
        WHEN coalesce(e.reconstructed_expected_rows, 0) = 0 THEN 1
        ELSE 2
    END,
    c.container_id;

/* Shared-stock verification remains intentionally outside KIT assignment. */
SELECT
    c.container_id,
    c.description,
    c.location_code,
    m.material_name,
    cem.size_text,
    cem.expected_quantity,
    cem.quantity_uom,
    cem.verification_state,
    cem.notes
FROM ref.setup_container_extra_material cem
JOIN ref.container c
  ON c.container_id = cem.container_id
JOIN ref.setup_extra_material m
  ON m.setup_extra_material_id = cem.setup_extra_material_id
WHERE cem.active_flag
  AND (
      (m.material_name = 'T-Post' AND c.container_id IN (36,118))
      OR c.container_id IN (123,124,125,128,129)
  )
ORDER BY c.container_id, m.material_name, cem.setup_container_extra_material_id;
