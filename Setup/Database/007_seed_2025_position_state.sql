/* ============================================================================
MSB Setup Session — 2025 annual position-state seed
Issue: #122
Status: IMPLEMENTATION CANDIDATE — RUN AFTER 004
Revision: 2026-09-06 V0.1.0

Purpose:
  Make the special 2025 Historical Verification session structurally consistent
  with sessions created later through ops.create_setup_session().

Important:
  - No historical movement is invented.
  - No ref.display.container_id value is copied into annual Display state.
  - Displays begin WITH_CONTAINER with no Setup location observation.
  - Containers begin with no Setup location observation.
============================================================================ */

BEGIN;

DO $preflight$
DECLARE
    v_session_id bigint;
BEGIN
    IF to_regclass('ops.setup_session') IS NULL
       OR to_regclass('ops.setup_display_state') IS NULL
       OR to_regclass('ops.setup_container_state') IS NULL THEN
        RAISE EXCEPTION 'Setup core schema 001 is required first';
    END IF;

    SELECT setup_session_id
      INTO v_session_id
    FROM ops.setup_session
    WHERE season_year = 2025;

    IF v_session_id IS NULL THEN
        RAISE EXCEPTION '2025 Historical Verification session 004 is required first';
    END IF;

    IF EXISTS (
        SELECT 1 FROM ops.setup_display_state
        WHERE setup_session_id = v_session_id
    ) OR EXISTS (
        SELECT 1 FROM ops.setup_container_state
        WHERE setup_session_id = v_session_id
    ) THEN
        RAISE EXCEPTION '2025 position state already exists; refuse duplicate seed';
    END IF;
END
$preflight$;

INSERT INTO ops.setup_display_state(setup_session_id, display_id)
SELECT ss.setup_session_id, d.display_id
FROM ops.setup_session ss
CROSS JOIN ref.display d
JOIN ref.display_status ds
  ON ds.display_status_id = d.display_status_id
WHERE ss.season_year = 2025
  AND ds.display_status_name <> 'RECYCLED'
ORDER BY d.display_id;

INSERT INTO ops.setup_container_state(setup_session_id, container_id)
SELECT ss.setup_session_id, c.container_id
FROM ops.setup_session ss
CROSS JOIN ref.container c
WHERE ss.season_year = 2025
ORDER BY c.container_id;

COMMIT;

SELECT
    ss.season_year,
    (SELECT count(*) FROM ops.setup_display_state ds
      WHERE ds.setup_session_id = ss.setup_session_id) AS display_state_rows,
    (SELECT count(*) FROM ops.setup_container_state cs
      WHERE cs.setup_session_id = ss.setup_session_id) AS container_state_rows,
    (SELECT count(*) FROM ops.setup_movement_event me
      WHERE me.setup_session_id = ss.setup_session_id) AS movement_event_rows
FROM ops.setup_session ss
WHERE ss.season_year = 2025;
