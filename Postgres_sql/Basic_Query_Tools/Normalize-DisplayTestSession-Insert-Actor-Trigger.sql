-- File: Normalize-DisplayTestSession-Insert-Actor-Trigger.sql
-- =========================================================
-- MSB Production Database
-- Audit System Repair
-- Step C3 – Normalize insert actor trigger on ops.display_test_session
-- Purpose:
-- Replace the legacy insert trigger name with the locked-standard
-- trigger name while keeping the same ref.set_actor_on_insert() function.
-- =========================================================

DROP TRIGGER IF EXISTS trg_display_test_session_set_insert_actor
ON ops.display_test_session;

CREATE TRIGGER trg_display_test_session_set_actor_insert
BEFORE INSERT ON ops.display_test_session
FOR EACH ROW
EXECUTE FUNCTION ref.set_actor_on_insert();