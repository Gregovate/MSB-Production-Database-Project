-- Q1: Show dated sheet rows that still don't match any ref.display by display_name (edge-case list).
WITH s AS (
  SELECT
    NULLIF(regexp_replace(container_id_text, '\D', '', 'g'), '')::int AS container_id,
    NULLIF(btrim(new_db_display_name), '') AS display_name,
    NULLIF(btrim(date_tested_text), '')    AS date_tested_text,
    NULLIF(btrim(tested_initials), '')     AS tested_initials,
    NULLIF(btrim(notes), '')              AS notes
  FROM stage.test_plan_2026_raw
)
SELECT
  s.container_id,
  s.display_name,
  s.date_tested_text,
  s.tested_initials,
  s.notes
FROM s
LEFT JOIN ref.display d
  ON btrim(d.display_name) = s.display_name
WHERE s.date_tested_text IS NOT NULL
  AND d.display_id IS NULL
ORDER BY s.container_id, s.display_name;