-- File: Check-Person-ID-Default.sql
-- =========================================================
-- MSB Production Database
-- Primary Key / Sequence Check
-- Purpose:
-- Verify whether ref.person.person_id already has an identity
-- or sequence-backed default before wiring auto-number behavior.
-- =========================================================

SELECT
    c.column_name,
    c.data_type,
    c.column_default,
    c.is_nullable,
    c.is_identity,
    c.identity_generation,
    pg_get_serial_sequence('ref.person', 'person_id') AS sequence_name
FROM information_schema.columns c
WHERE c.table_schema = 'ref'
  AND c.table_name = 'person'
  AND c.column_name = 'person_id';