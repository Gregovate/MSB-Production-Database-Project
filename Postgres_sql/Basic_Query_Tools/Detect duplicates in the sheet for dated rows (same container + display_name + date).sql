-- PREVIEW: how many child rows WOULD be updated from sheet dated rows (exact-name match only).
WITH sheet_dated AS (
  SELECT DISTINCT ON (container_id_guess, display_name_clean)
    container_id_guess,
    display_name_clean,
    date_tested_text_clean,
    tested_initials_clean,
    notes_clean
  FROM (
    SELECT
      NULLIF(regexp_replace(container_id_text, '\D', '', 'g'), '')::int AS container_id_guess,
      NULLIF(btrim(new_db_display_name), '') AS display_name_clean,
      NULLIF(btrim(date_tested_text), '')    AS date_tested_text_clean,
      NULLIF(btrim(tested_initials), '')     AS tested_initials_clean,
      NULLIF(btrim(notes), '')              AS notes_clean
    FROM stage.test_plan_2026_raw
  ) x
  WHERE date_tested_text_clean IS NOT NULL
    AND display_name_clean IS NOT NULL
  ORDER BY container_id_guess, display_name_clean
),
targets AS (
  SELECT
    dts.display_test_session_id
  FROM sheet_dated s
  JOIN ref.display d
    ON btrim(d.display_name) = s.display_name_clean
  JOIN ops.test_session ts
    ON ts.season_year = 2026
   AND ts.container_id = s.container_id_guess
  JOIN ops.display_test_session dts
    ON dts.test_session_id = ts.test_session_id
   AND dts.display_id = d.display_id
  WHERE COALESCE(dts.is_spare, false) = false
    AND (dts.checked_at IS NULL)
    AND (dts.checked_date_text IS NULL OR btrim(dts.checked_date_text) = '')
)
SELECT COUNT(*) AS would_update
FROM targets;