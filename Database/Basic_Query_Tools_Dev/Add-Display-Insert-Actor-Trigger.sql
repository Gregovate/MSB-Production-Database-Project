-- File: Add-Display-Insert-Actor-Trigger.sql
-- =========================================================
-- MSB Production Database
-- Audit System Repair
-- Step C20 – Add insert actor trigger to ref.display
-- Purpose:
-- Add the locked-standard insert actor trigger to ref.display
-- without touching update behavior yet.
-- =========================================================

CREATE TRIGGER trg_display_set_actor_insert
BEFORE INSERT ON ref.display
FOR EACH ROW
EXECUTE FUNCTION ref.set_actor_on_insert();