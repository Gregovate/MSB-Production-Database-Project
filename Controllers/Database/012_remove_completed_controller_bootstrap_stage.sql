/* ============================================================================
Controller Inventory completed-bootstrap cleanup
Issue: #110

Purpose:
  Remove the temporary Controller bootstrap/review objects from the live stage
  schema after successful permanent promotion and relationship correction.

Why:
  These objects were engineering scaffolding, not operational Controller
  Inventory. Leaving them live causes Directus to discover collections named
  Controller Bootstrap / Controller Model Reference and creates unnecessary
  future confusion.

Permanent authority retained:
  ref.controller
  ref.controller_model
  ref.controller_status
  ref.controller_firmware_version
  ref.controller_display
  ref.controller_firmware_history

Evidence retained outside the live stage schema:
  - Controller Inventory source CSV/workbook reconciliation artifacts;
  - migration/bootstrap SQL in this repository;
  - Issue #110 engineering/acceptance record;
  - permanent promoted Controller Inventory rows.

Safety:
  - NO CASCADE is used.
  - The script refuses to run unless the accepted 177-controller permanent
    population exists at IDs 1001..1177.
  - Any unexpected dependency will make PostgreSQL stop rather than remove it.
============================================================================ */

BEGIN;

DO $preflight$
DECLARE
    v_count integer;
    v_min bigint;
    v_max bigint;
BEGIN
    IF to_regclass('ref.controller') IS NULL THEN
        RAISE EXCEPTION 'ref.controller does not exist; bootstrap cleanup is not authorized';
    END IF;

    SELECT count(*), min(controller_id), max(controller_id)
      INTO v_count, v_min, v_max
    FROM ref.controller;

    IF v_count <> 177 OR v_min <> 1001 OR v_max <> 1177 THEN
        RAISE EXCEPTION
            'Permanent Controller acceptance gate failed: expected 177 rows at 1001..1177; found count %, min %, max %',
            v_count, v_min, v_max;
    END IF;
END
$preflight$;

-- Views first because they depend on the stage tables below.
DROP VIEW IF EXISTS stage.v_controller_firmware_review;
DROP VIEW IF EXISTS stage.v_controller_model_reference_summary;
DROP VIEW IF EXISTS stage.v_controller_bootstrap_review;

-- Bootstrap-only ordering helper.
DROP FUNCTION IF EXISTS stage.prepare_controller_bootstrap_order();

-- Tables in dependency-safe order. No CASCADE by design.
DROP TABLE IF EXISTS stage.controller_bootstrap_display;
DROP TABLE IF EXISTS stage.controller_model_reference;
DROP TABLE IF EXISTS stage.controller_bootstrap;

COMMIT;

SELECT
    to_regclass('stage.controller_bootstrap') AS controller_bootstrap,
    to_regclass('stage.controller_bootstrap_display') AS controller_bootstrap_display,
    to_regclass('stage.controller_model_reference') AS controller_model_reference,
    to_regclass('stage.v_controller_bootstrap_review') AS bootstrap_review_view,
    to_regclass('stage.v_controller_model_reference_summary') AS model_summary_view,
    to_regclass('stage.v_controller_firmware_review') AS firmware_review_view;
