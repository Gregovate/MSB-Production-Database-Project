/* #81 / #299: allow the existing API to resolve active Directus role/policies.
   Revision: 2026-10-27 V1.0.0
   DATABASE PERMISSION CHANGE. Apply only in an approved maintenance window.
   Does not grant any new mutation entry point or direct Directus-table access.
   Record has_function_privilege BEFORE applying; rollback only a new grant. */
BEGIN;
GRANT EXECUTE ON FUNCTION ref.setup_browser_capabilities(text)
TO lor_preflight_app;
COMMIT;
