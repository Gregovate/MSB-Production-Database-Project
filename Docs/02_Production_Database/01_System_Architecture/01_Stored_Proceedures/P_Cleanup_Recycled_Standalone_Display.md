# P_Cleanup_Recycled_Standalone_Display

**Database:** MSB Production Database  
**Schema:** `ops`  
**Object:** `ops.p_cleanup_recycled_standalone_display(bigint)`  
**Document Type:** Stored procedure architecture and business-rule specification  
**Status:** Production  
**Owner:** MSB Database Administrator  
**Current Revision:** 2026-08-07  

---

## Revision History

| Date | Author | Change |
|---|---|---|
| 2026-08-07 | GAL / OpenAI | Initial documentation of the production cleanup procedure for RECYCLED stand-alone displays and their synthetic containers. |

---

# 1. Purpose

`ops.p_cleanup_recycled_standalone_display` removes the operational database objects that exist only to support testing of a stand-alone display after that display has been marked `RECYCLED`.

A stand-alone display requires a synthetic `ref.container` record so the normal container-testing workflow can create an `ops.test_session`. That synthetic container does not represent a separate physical pallet, bin, crate, trailer, or other reusable container. It exists only because the stand-alone display itself must participate in the container-based testing workflow.

When the stand-alone display is recycled, the physical display no longer exists. Therefore its synthetic container also no longer represents a physical object and must be removed.

The procedure preserves the permanent `ref.display` identity for historical purposes while removing the obsolete operational relationships and synthetic container.

---

# 2. Business Rule

This procedure applies **only** to displays that meet both conditions:

1. the display's current lifecycle status is `RECYCLED`; and
2. the display is assigned to a container whose governed type is `Standalone Display`.

For such a display:

- the `ref.display` row is preserved permanently as historical identity;
- display testing rows associated with the stand-alone container are removed;
- test sessions associated with the stand-alone container are removed;
- the display-to-container relationship is cleared;
- the synthetic `ref.container` row is deleted.

The procedure must never delete a normal physical container.

---

# 3. Procedure Signature

```sql
ops.p_cleanup_recycled_standalone_display(
    p_display_id bigint
)
```

Return type:

```sql
void
```

---

# 4. Input

## `p_display_id`

The canonical `ref.display.display_id` of the recycled stand-alone display.

The display must already exist and must already have lifecycle status:

```text
RECYCLED
```

The procedure does not mark the display RECYCLED. It performs cleanup only after the lifecycle change has already occurred.

---

# 5. Operational Model

Before recycling:

```text
ref.display
    |
    | container_id
    v
ref.container
(type = Standalone Display)
    |
    v
ops.test_session
    |
    v
ops.display_test_session
```

After cleanup:

```text
ref.display
(status = RECYCLED, container_id = NULL)

ref.container               DELETED
ops.test_session            DELETED
ops.display_test_session    DELETED
```

The `ref.display` row remains as the permanent historical identity.

---

# 6. Safety Guards

The procedure is intentionally defensive.

## 6.1 Display Must Exist

If `p_display_id` does not exist in `ref.display`, the procedure raises an exception.

## 6.2 Display Must Be RECYCLED

The procedure refuses to run unless:

```text
display_status_name = RECYCLED
```

This prevents accidental cleanup of an active or retired display.

## 6.3 Container Must Be Standalone Display

Automatic deletion is allowed only when:

```text
container_type_name = Standalone Display
```

If the display is assigned to any other container type, the procedure raises an exception.

This protects real pallets, bins, boxes, trailers, crates, and other reusable physical containers.

## 6.4 Shared-Container Protection

Before deletion, the procedure counts other non-RECYCLED displays assigned to the same container.

If any exist, cleanup is aborted.

A valid synthetic stand-alone container must not contain another operational display.

## 6.5 Foreign Keys Remain Final Protection

The procedure does not bypass database referential integrity.

Existing `RESTRICT` or `NO ACTION` foreign keys remain authoritative and may prevent deletion when historical dependencies still require the test-session or container record.

---

# 7. Work-Order Rule

The procedure deletes matching `ops.display_test_session` rows.

If a historical `ops.work_order` still references one of those rows, PostgreSQL foreign-key enforcement prevents the delete.

This is intentional.

An open work order should first be resolved through the normal work-order workflow, for example with a terminal outcome such as:

```text
Damaged Beyond Repair
```

The procedure does not automatically close or rewrite work orders.

Historical work-order data must not be destroyed merely to remove the stand-alone container.

---

# 8. Procedure Algorithm

```text
1. Resolve display:
      - current container
      - container type
      - display lifecycle status
      - display name

2. Fail if display does not exist.

3. Fail unless display status = RECYCLED.

4. Return immediately if display.container_id is already NULL.

5. Fail unless container type = Standalone Display.

6. Count other non-RECYCLED displays assigned to the container.

7. Fail if any other operational display shares the container.

8. Delete display_test_session rows for this display that belong to
   test sessions on the synthetic container.

9. Delete test sessions for the synthetic container.

10. Set ref.display.container_id = NULL.

11. Delete the synthetic ref.container row.

12. Return.
```

---

# 9. Production Function

```sql
CREATE OR REPLACE FUNCTION ops.p_cleanup_recycled_standalone_display(
    p_display_id bigint
)
RETURNS void
LANGUAGE plpgsql
AS $function$
DECLARE
    v_container_id integer;
    v_container_type_name text;
    v_display_status_name text;
    v_display_name text;
    v_other_display_count integer;
BEGIN
    /*
     * Resolve the display, its lifecycle state, and its current container.
     */
    SELECT
        d.container_id,
        ct.container_type_name,
        ds.display_status_name,
        d.display_name
    INTO
        v_container_id,
        v_container_type_name,
        v_display_status_name,
        v_display_name
    FROM ref.display d
    JOIN ref.display_status ds
      ON ds.display_status_id = d.display_status_id
    LEFT JOIN ref.container c
      ON c.container_id = d.container_id
    LEFT JOIN ref.container_type ct
      ON ct.container_type_id = c.container_type_id
    WHERE d.display_id = p_display_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'Display % does not exist',
            p_display_id;
    END IF;

    /*
     * This cleanup is valid only after the display lifecycle has actually
     * been changed to RECYCLED.
     */
    IF v_display_status_name <> 'RECYCLED' THEN
        RAISE EXCEPTION
            'Display % (%) is %, not RECYCLED',
            p_display_id,
            v_display_name,
            v_display_status_name;
    END IF;

    /*
     * A recycled display without a current container needs no synthetic
     * container cleanup.
     */
    IF v_container_id IS NULL THEN
        RETURN;
    END IF;

    /*
     * Critical safety guard:
     * Never delete a real pallet, bin, box, trailer, crate, etc.
     */
    IF v_container_type_name IS DISTINCT FROM 'Standalone Display' THEN
        RAISE EXCEPTION
            'Display % (%) is assigned to container % of type %. '
            'Automatic container deletion is allowed only for Standalone Display containers.',
            p_display_id,
            v_display_name,
            v_container_id,
            COALESCE(v_container_type_name, '<NULL>');
    END IF;

    /*
     * A synthetic stand-alone container must not contain another display.
     * If it does, stop rather than deleting shared operational data.
     */
    SELECT COUNT(*)
      INTO v_other_display_count
    FROM ref.display d
    WHERE d.container_id = v_container_id
      AND d.display_id <> p_display_id
      AND d.display_status_id <> (
          SELECT display_status_id
          FROM ref.display_status
          WHERE display_status_name = 'RECYCLED'
      );

    IF v_other_display_count > 0 THEN
        RAISE EXCEPTION
            'Standalone container % for display % contains % other non-RECYCLED display(s); cleanup aborted',
            v_container_id,
            p_display_id,
            v_other_display_count;
    END IF;

    /*
     * Remove display-test rows belonging to the stand-alone display.
     *
     * A historical work order FK will intentionally prevent deletion.
     * Such a work order must first be resolved according to the normal
     * work-order workflow, for example "Damaged Beyond Repair".
     */
    DELETE FROM ops.display_test_session dts
    WHERE dts.display_id = p_display_id
      AND EXISTS (
          SELECT 1
          FROM ops.test_session ts
          WHERE ts.test_session_id = dts.test_session_id
            AND ts.container_id = v_container_id
      );

    /*
     * Remove test sessions for the synthetic stand-alone container.
     *
     * At this point the container represents no physical object and must
     * not remain in testing queues.
     */
    DELETE FROM ops.test_session
    WHERE container_id = v_container_id;

    /*
     * Break the current operational display -> container relationship.
     * The display record itself remains as permanent RECYCLED history.
     */
    UPDATE ref.display
       SET container_id = NULL
     WHERE display_id = p_display_id;

    /*
     * Delete the synthetic container.
     *
     * Existing RESTRICT/NO ACTION foreign keys remain the final protection
     * against destroying historical dependencies.
     */
    DELETE FROM ref.container
    WHERE container_id = v_container_id;

END;
$function$;
```

---

# 10. Example Usage

```sql
SELECT ops.p_cleanup_recycled_standalone_display(597);
```

Expected successful result:

- the `ref.display` row remains;
- `display_status_name` remains `RECYCLED`;
- `ref.display.container_id` becomes `NULL`;
- matching `ops.display_test_session` rows are removed;
- test sessions for the synthetic container are removed;
- the synthetic `ref.container` row is removed.

---

# 11. Validation Queries

## 11.1 Before Cleanup

```sql
SELECT
    d.display_id,
    d.display_name,
    d.container_id,
    ds.display_status_name,
    c.description AS container_description,
    ct.container_type_name
FROM ref.display d
JOIN ref.display_status ds
  ON ds.display_status_id = d.display_status_id
LEFT JOIN ref.container c
  ON c.container_id = d.container_id
LEFT JOIN ref.container_type ct
  ON ct.container_type_id = c.container_type_id
WHERE d.display_id = <DISPLAY_ID>;
```

Expected before cleanup:

```text
display_status_name = RECYCLED
container_type_name = Standalone Display
container_id IS NOT NULL
```

## 11.2 Work-Order Dependency Check

```sql
SELECT
    dts.display_test_session_id,
    dts.test_session_id,
    wo.work_order_id,
    wo.date_completed
FROM ops.display_test_session dts
LEFT JOIN ops.work_order wo
  ON wo.display_test_session_id = dts.display_test_session_id
WHERE dts.display_id = <DISPLAY_ID>
ORDER BY dts.test_session_id, wo.work_order_id;
```

Any work-order dependency must be reviewed before cleanup.

## 11.3 After Cleanup

```sql
SELECT
    d.display_id,
    d.display_name,
    d.container_id,
    ds.display_status_name
FROM ref.display d
JOIN ref.display_status ds
  ON ds.display_status_id = d.display_status_id
WHERE d.display_id = <DISPLAY_ID>;
```

Expected result:

```text
display_status_name = RECYCLED
container_id = NULL
```

The former synthetic container should no longer exist.

---

# 12. Relationship to Test-Session Refresh

`ops.p_refresh_test_session` and `ops.p_cleanup_recycled_standalone_display` have separate responsibilities.

## `ops.p_refresh_test_session`

Synchronizes the child display-test rows within an existing container test session.

It may remove a RECYCLED display from `ops.display_test_session`.

## `ops.p_cleanup_recycled_standalone_display`

Removes the synthetic stand-alone container itself, along with the container's operational testing objects.

A refresh alone is not sufficient to remove the synthetic container unless the refresh workflow explicitly invokes this cleanup procedure.

---

# 13. Design Invariant

For stand-alone displays:

> The synthetic container exists only while the physical stand-alone display exists operationally.

When the display becomes `RECYCLED`:

- the display historical identity remains;
- the synthetic container must not remain in `ref.container`;
- the synthetic container must not remain assigned to a storage location;
- no active test session should remain for that synthetic container.

This prevents non-existent stand-alone displays from polluting container inventory, storage-location assignments, and testing queues.

---

# 14. Scope Limitation

This procedure is **not** a general container deletion procedure.

It must never be used to remove:

- pallets;
- bins;
- boxes;
- crates;
- trailers;
- racks;
- shared containers; or
- any other physical container that exists independently of a display.

Its scope is strictly:

```text
RECYCLED display
+
container_type = Standalone Display
```

---

END OF DOCUMENT
