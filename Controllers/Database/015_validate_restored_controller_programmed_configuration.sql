/* ============================================================================
Controller Inventory: validate restored programmed controller configuration
Issue: #110

014_restore_controller_programmed_configuration.sql commits before its final
human-readable diagnostic SELECT. PostgreSQL 16 reports to_hex(smallint) as
ambiguous, so this standalone validation casts the stored SMALLINT values to
INTEGER explicitly.

READ ONLY.
============================================================================ */

SELECT
    count(*) AS controllers,
    count(*) FILTER (WHERE lor_uid_start IS NOT NULL) AS lor_uid_configured,
    count(*) FILTER (WHERE management_ip IS NOT NULL) AS management_ip_configured,
    count(*) FILTER (
        WHERE programmed_config_verification_state = 'RECORDED_UNVERIFIED'
    ) AS config_recorded_unverified
FROM ref.controller;

SELECT
    c.controller_id,
    m.model_code,
    m.lor_uid_capacity,
    c.lor_network,
    CASE
        WHEN c.lor_uid_start IS NULL THEN NULL
        ELSE upper(lpad(to_hex(c.lor_uid_start::integer), 2, '0'))
    END AS first_uid,
    c.lor_uid_count,
    CASE
        WHEN c.lor_uid_end IS NULL THEN NULL
        ELSE upper(lpad(to_hex(c.lor_uid_end::integer), 2, '0'))
    END AS last_uid,
    host(c.management_ip) AS management_ip,
    c.programmed_config_verification_state
FROM ref.controller c
JOIN ref.controller_model m
  ON m.controller_model_id = c.controller_model_id
WHERE c.controller_id IN (
    1015,1016,
    1058,1059,1060,1061,
    1112,1113,
    1134,1135,1136,
    1141,1142,
    1143,1144,
    1163,1164,
    1176
)
ORDER BY c.controller_id;

SELECT
    m.model_code,
    m.lor_uid_capacity,
    count(c.controller_id) AS controller_count,
    max(c.lor_uid_count) FILTER (WHERE c.lor_uid_count IS NOT NULL) AS max_configured_uid_count
FROM ref.controller_model m
LEFT JOIN ref.controller c
  ON c.controller_model_id = m.controller_model_id
WHERE m.lor_uid_capacity IS NOT NULL
GROUP BY m.controller_model_id, m.model_code, m.lor_uid_capacity
ORDER BY m.model_code;

SELECT
    count(*) AS invalid_model_capacity_rows
FROM ref.controller c
JOIN ref.controller_model m
  ON m.controller_model_id = c.controller_model_id
WHERE c.lor_uid_count IS NOT NULL
  AND (
      m.lor_uid_capacity IS NULL
      OR c.lor_uid_count > m.lor_uid_capacity
      OR c.lor_uid_start < 1
      OR c.lor_uid_end > 240
  );