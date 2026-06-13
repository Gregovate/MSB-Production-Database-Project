SELECT
    display_test_session_id,
    test_status,
    notes,
    checked_at,
    checked_by,
    checked_by_person_id,
    updated_at,
    updated_by,
    updated_by_person_id
FROM ops.display_test_session
WHERE display_test_session_id IN (1829)
ORDER BY display_test_session_id;