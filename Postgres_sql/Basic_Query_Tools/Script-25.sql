-- File: Drop-Old-DisplayTestSession-Checked-Trigger.sql
-- =========================================================
-- MSB Production Database
-- Audit System Repair
-- Step C2 – Drop old checked trigger from ops.display_test_session
-- Purpose:
-- Remove the legacy checked trigger so only the locked-standard
-- trigger name/function remain on this table.
-- =========================================================

DROP TRIGGER IF EXISTS trg_display_test_session_set_checked
ON ops.display_test_session;