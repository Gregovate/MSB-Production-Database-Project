# Manager Correction SOP — Wrong Display Container With Existing Work Orders
---

Purpose

Correct displays that were assigned to the wrong container after test-session child rows and work orders already exist.

Safe-use conditions

Use only when:

ref.display.container_id has already been corrected.
stale ops.display_test_session rows still exist in the wrong session.
work orders exist and must be preserved.
the goal is to relink work orders to the correct display_test_session rows, not delete repair history.

1. Find mismatched display test rows
```SQL
SELECT
    dts.display_test_session_id,
    dts.test_session_id,
    d.display_name,
    d.container_id AS current_ref_container_id,
    ts.container_id AS test_session_container_id,
    dts.is_display_present,
    dts.test_status
FROM ops.display_test_session dts
JOIN ref.display d
  ON d.display_id = dts.display_id
JOIN ops.test_session ts
  ON ts.test_session_id = dts.test_session_id
WHERE dts.test_session_id IN (587, 676)
  AND d.container_id <> ts.container_id
ORDER BY dts.test_session_id, d.display_name;
```

2. Check whether work orders block refresh cleanup

```SQL
SELECT
    dts.display_test_session_id,
    dts.test_session_id,
    d.display_name,
    d.container_id AS current_ref_container_id,
    ts.container_id AS test_session_container_id,
    dts.is_display_present,
    dts.test_status,
    wo.work_order_id
FROM ops.display_test_session dts
JOIN ref.display d
  ON d.display_id = dts.display_id
JOIN ops.test_session ts
  ON ts.test_session_id = dts.test_session_id
LEFT JOIN ops.work_order wo
  ON wo.display_test_session_id = dts.display_test_session_id
WHERE dts.display_test_session_id IN (1972, 1838, 1844, 1841)
ORDER BY dts.test_session_id, d.display_name;

If work_order_id exists, do not delete the display_test_session rows yet.
```

3. Inspect linked work orders

```SQL
SELECT
    wo.*
FROM ops.work_order wo
WHERE wo.work_order_id IN (344, 346, 347, 349)
ORDER BY wo.work_order_id;
```

These were completed repair records, so they must be preserved.

4. Refresh affected sessions to create missing correct child rows

```SQL
SELECT ops.p_refresh_test_session(587, current_user, NULL);
SELECT ops.p_refresh_test_session(676, current_user, NULL);
```

5. Preview work-order relink target rows

```SQL
SELECT
    wo.work_order_id,
    wo.display_id,
    d.display_name,
    wo.display_test_session_id AS old_display_test_session_id,
    old_dts.test_session_id AS old_test_session_id,
    new_dts.display_test_session_id AS new_display_test_session_id,
    new_dts.test_session_id AS new_test_session_id
FROM ops.work_order wo
JOIN ref.display d
  ON d.display_id = wo.display_id
JOIN ops.display_test_session old_dts
  ON old_dts.display_test_session_id = wo.display_test_session_id
JOIN ops.test_session new_ts
  ON new_ts.container_id = d.container_id
JOIN ops.display_test_session new_dts
  ON new_dts.test_session_id = new_ts.test_session_id
 AND new_dts.display_id = wo.display_id
WHERE wo.work_order_id IN (344, 346, 347, 349)
ORDER BY wo.work_order_id;
```

Review this before updating.

6. Relink work orders to the correct display test session rows

```SQL
UPDATE ops.work_order wo
SET
    display_test_session_id = new_dts.display_test_session_id,
    updated_at = NOW(),
    updated_by = current_user
FROM ref.display d
JOIN ops.test_session new_ts
  ON new_ts.container_id = d.container_id
JOIN ops.display_test_session new_dts
  ON new_dts.test_session_id = new_ts.test_session_id
 AND new_dts.display_id = d.display_id
WHERE wo.display_id = d.display_id
  AND wo.work_order_id IN (344, 346, 347, 349);
```

7. Refresh again to remove stale wrong-container rows

```SQL
SELECT ops.p_refresh_test_session(587, current_user, NULL);
SELECT ops.p_refresh_test_session(676, current_user, NULL);
```

8. Final verification

```sql
SELECT
    dts.display_test_session_id,
    dts.test_session_id,
    d.display_name,
    d.container_id AS current_ref_container_id,
    ts.container_id AS test_session_container_id,
    dts.is_display_present,
    dts.test_status
FROM ops.display_test_session dts
JOIN ref.display d
  ON d.display_id = dts.display_id
JOIN ops.test_session ts
  ON ts.test_session_id = dts.test_session_id
WHERE dts.test_session_id IN (587, 676)
  AND d.container_id <> ts.container_id
ORDER BY dts.test_session_id, d.display_name;
```
Expected result:

0 rows

9. Confirm refresh results

```sql
SELECT
    test_session_id,
    last_refreshed_at,
    last_refresh_add_count,
    last_refresh_delete_count
FROM ops.test_session
WHERE test_session_id IN (587, 676);
```

Your successful result was:

587 deleted 1 stale row
676 deleted 3 stale rows

This is now a repeatable manager-only correction workflow.