-- File: Add-Display-Update-Actor-Trigger.sql
-- =========================================================
-- MSB Production Database
-- Audit System Repair
-- Step C22 – Add update actor trigger to ref.display
-- Purpose:
-- Add the locked-standard update actor trigger to ref.display.
-- Inserts remain owned by the P2 lor_snap process, while Directus
-- edits to curated metadata must record the acting person.
-- =========================================================

CREATE TRIGGER trg_display_set_actor_update
BEFORE UPDATE ON ref.display
FOR EACH ROW
EXECUTE FUNCTION ref.set_actor_on_update();