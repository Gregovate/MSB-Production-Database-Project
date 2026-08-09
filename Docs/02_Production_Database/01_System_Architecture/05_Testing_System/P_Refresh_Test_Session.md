# Purpose

`ops.p_refresh_test_session` synchronizes the display testing records for a single
container test session with the current operational display inventory.

The procedure is executed when a Directus user requests **Refresh Displays to Test**
for an active-season container.

Its purpose is to ensure that the active test session accurately reflects the
current operational state of the assigned container while preserving valid
testing history, work-order integrity, and audit information.

The procedure performs five primary functions:

1. Resolves the active-season container associated with the requested test
   session.

2. Creates missing `ops.display_test_session` records for operational displays
   currently assigned to the container. Displays with lifecycle status
   `RECYCLED` are excluded because they no longer physically exist.

3. Removes obsolete `ops.display_test_session` records that no longer represent
   valid operational relationships, including:

   - displays identified as `WRONG_CONTAINER` that are no longer assigned to the
     container and have no dependent work orders; and

   - displays whose lifecycle status is `RECYCLED` when no historical work-order
     dependency requires the test record to be retained.

4. Updates refresh audit information, records synchronization statistics, and
   clears the refresh request flag.

5. Detects recycled stand-alone displays and automatically invokes
   `ops.p_cleanup_recycled_standalone_display()` to remove the synthetic
   container, associated active test session, and remaining operational testing
   relationships when cleanup can be performed safely.

The procedure is intentionally conservative. Existing testing results,
historical work orders, and audit records are preserved. Only operational
relationships that are no longer valid are removed.

This procedure is responsible for synchronizing active testing records. Removal
of synthetic stand-alone containers is delegated to
`ops.p_cleanup_recycled_standalone_display()`, allowing each procedure to
maintain a single, well-defined responsibility while working together to keep
the operational inventory consistent.

---

# Related Documentation

## Procedures

- [`P_Cleanup_Recycled_Standalone_Display.md`](P_Cleanup_Recycled_Standalone_Display.md)

  Performs lifecycle cleanup for recycled stand-alone displays by removing
  synthetic containers, associated active test sessions, and operational
  testing relationships after the display has been marked `RECYCLED`.

## Triggers

- [`T_After_Refresh_Test_Session.md`](T_After_Refresh_Test_Session.md)

  Documents the trigger that invokes
  `ops.p_refresh_test_session()` when the Directus
  **Refresh Displays to Test** action is requested.
