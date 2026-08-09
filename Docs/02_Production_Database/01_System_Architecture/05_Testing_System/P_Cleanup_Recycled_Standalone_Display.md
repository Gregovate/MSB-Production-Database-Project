# P_Cleanup_Recycled_Standalone_Display

**Database:** MSB Production Database  
**Schema:** `ops`  
**Object:** `ops.p_cleanup_recycled_standalone_display(bigint)`  
**Document Type:** Stored procedure architecture and business-rule specification  
**Status:** Production  
**Owner:** MSB Database Administrator  
**Current Revision:** 2026-08-07

## Purpose

`ops.p_cleanup_recycled_standalone_display` removes operational database objects that exist only to support testing of a stand-alone display after that display has been marked `RECYCLED`.

A stand-alone display uses a synthetic `ref.container` so it can participate in the normal container-based testing workflow. The synthetic container is not an independent physical pallet, bin, crate, trailer, or reusable container. When the display is recycled, the synthetic container and its active testing relationships must be removed while the permanent `ref.display` identity is retained for history.

## Business Rule

The procedure applies only when both conditions are true:

1. the display lifecycle status is `RECYCLED`; and
2. its assigned container has governed type `Standalone Display`.

For a qualifying display:

- preserve the `ref.display` row permanently;
- remove matching operational `ops.display_test_session` rows when referential integrity permits;
- remove test sessions associated with the synthetic container;
- clear the display-to-container relationship;
- delete the synthetic `ref.container` row.

The procedure must never delete a normal physical container.

## Procedure Signature

```sql
ops.p_cleanup_recycled_standalone_display(
    p_display_id bigint
)
```

Return type: `void`.

`p_display_id` is the canonical `ref.display.display_id`. The procedure does not change lifecycle status; the display must already be `RECYCLED`.

## Operational Model

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
ops.display_test_session    DELETED when allowed by FK dependencies
```

## Safety Guards

The procedure is intentionally defensive:

- fail if the display does not exist;
- fail unless lifecycle status is `RECYCLED`;
- return if `display.container_id` is already `NULL`;
- fail unless the assigned container type is exactly `Standalone Display`;
- fail if another non-RECYCLED display shares the synthetic container;
- do not bypass PostgreSQL foreign-key protection.

Existing `RESTRICT` or `NO ACTION` foreign keys remain the final protection against deleting data still required for historical relationships.

## Work Order Protection

If a historical `ops.work_order` references a matching `ops.display_test_session`, PostgreSQL foreign-key enforcement prevents that testing row from being deleted. This is intentional.

The cleanup procedure does not automatically close, rewrite, or destroy work orders. Any dependent work order must be resolved through the normal Work Order workflow before cleanup can complete.

## Procedure Algorithm

```text
1. Resolve the display, lifecycle status, assigned container, and container type.
2. Fail if the display does not exist.
3. Fail unless display status = RECYCLED.
4. Return if container_id is already NULL.
5. Fail unless container type = Standalone Display.
6. Count other non-RECYCLED displays assigned to the same container.
7. Fail if the container is shared by another operational display.
8. Delete eligible display_test_session rows for this display/container.
9. Delete test sessions for the synthetic container.
10. Set ref.display.container_id = NULL.
11. Delete the synthetic ref.container row.
12. Return.
```

## Validation Expectations

Before cleanup, the target should show:

```text
display_status_name = RECYCLED
container_type_name = Standalone Display
container_id IS NOT NULL
```

After successful cleanup:

```text
display_status_name = RECYCLED
container_id = NULL
```

The former synthetic container and its active testing objects should no longer exist.

## Relationship to Test-Session Refresh

`ops.p_refresh_test_session` and `ops.p_cleanup_recycled_standalone_display` have separate responsibilities.

- `ops.p_refresh_test_session` synchronizes display-test rows within an existing test session.
- `ops.p_cleanup_recycled_standalone_display` removes the synthetic stand-alone container and its operational testing objects after the display has been recycled.

Normal execution path:

```text
Directus
    ↓
Refresh Displays to Test
    ↓
trg_after_refresh_test_session
    ↓
ops.p_refresh_test_session()
    ↓
ops.p_cleanup_recycled_standalone_display()
```

## Design Invariant

> A synthetic stand-alone container exists only while the physical stand-alone display exists operationally.

When the display becomes `RECYCLED`, the permanent display identity remains, but the synthetic container must not remain in container inventory, storage assignments, or active testing queues.

## Scope Limitation

This is not a general container-deletion procedure. It must never be used to remove pallets, bins, boxes, crates, trailers, racks, shared containers, or any other physical container that exists independently of a display.

## Related Documentation

- [`P_Refresh_Test_Session.md`](P_Refresh_Test_Session.md)
- [`T_After_Refresh_Test_Session.md`](T_After_Refresh_Test_Session.md)
