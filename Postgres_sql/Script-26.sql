-- File: Add-Container-Update-Actor-Trigger.sql
-- =========================================================
-- MSB Production Database
-- Audit System Repair
-- Step C15 – Add update actor trigger to ref.container
-- Purpose:
-- Add the locked-standard update actor trigger to ref.container
-- without changing any other existing trigger behavior.
-- =========================================================

CREATE TRIGGER trg_container_set_actor_update
BEFORE UPDATE ON ref.container
FOR EACH ROW
EXECUTE FUNCTION ref.set_actor_on_update();