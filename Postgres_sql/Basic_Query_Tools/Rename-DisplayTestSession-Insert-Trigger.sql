-- File: Rename-DisplayTestSession-Insert-Trigger.sql
-- =========================================================
-- MSB Production Database
-- Audit System Repair
-- Step C5 – Rename insert actor trigger on ops.display_test_session
-- Purpose:
-- Rename the existing insert actor trigger to the locked-standard
-- trigger name without changing function behavior.
-- =========================================================

ALTER TRIGGER trg_display_test_session_set_insert_actor
ON ops.display_test_session
RENAME TO trg_display_test_session_set_actor_insert;