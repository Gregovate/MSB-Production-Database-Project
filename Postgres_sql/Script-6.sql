WITH child_norm AS (
    SELECT
        dts.test_session_id,
        dts.display_id,
        COALESCE(
            dts.checked_at,
            CASE
                WHEN dts.checked_date_text IS NULL OR btrim(dts.checked_date_text) = '' THEN NULL
                WHEN dts.checked_date_text ~ '^\d{4}-\d{2}-\d{2}' 
                    THEN dts.checked_date_text::timestamptz
                WHEN dts.checked_date_text ~ '^\d{1,2}/\d{1,2}/\d{4}'
                    THEN to_timestamp(dts.checked_date_text, 'MM/DD/YYYY HH12:MI AM')
                ELSE NULL
            END
        ) AS checked_ts
    FROM ops.display_test_session dts
),
rollup AS (
    SELECT
        ts.container_id,
        ts.test_session_id,
        COUNT(cn.display_id)                          AS total_children,
        COUNT(cn.checked_ts)                          AS checked_count,
        MIN(cn.checked_ts)                            AS earliest_checked,
        MAX(cn.checked_ts)                            AS latest_checked,
        CASE
            WHEN COUNT(cn.checked_ts) = 0 THEN 'NOT_STARTED'
            WHEN COUNT(cn.checked_ts) < COUNT(cn.display_id) THEN 'IN_PROGRESS'
            ELSE 'DONE'
        END AS inferred_state
    FROM ops.test_session ts
    LEFT JOIN child_norm cn
        ON cn.test_session_id = ts.test_session_id
    WHERE ts.season_year = 2026
    GROUP BY ts.container_id, ts.test_session_id
)
SELECT *
FROM rollup
ORDER BY inferred_state, container_id;