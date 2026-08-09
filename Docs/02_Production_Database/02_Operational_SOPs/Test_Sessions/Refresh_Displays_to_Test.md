# Refresh Displays to Test

[← Previous: Handle a Wrong or Missing Display](Handle_a_Wrong_or_Missing_Display.md) | [↑ Test Sessions Home](README.md) | [Next: Defer Testing →](Defer_Testing.md)

| Document Control | Value |
|---|---|
| Document Type | Operational SOP |
| System | Production Database — Testing |
| Task | Refresh the displays included in a test session |
| Audience | Testing volunteers / managers |
| Status | DRAFT |
| Owner | Production Database Manager |
| Last Reviewed | 2026-08-09 |
| Keywords | refresh displays, testing, wrong container, recycled display, standalone display |

## Purpose

Use **Refresh Displays to Test** when the displays shown in a test session no longer match the current container assignment or display inventory.

This may happen when:

- a display was assigned to the wrong container;
- a display was moved to a different container;
- a display was added to the container after the test session was created; or
- a **RECYCLED** display no longer physically exists and should no longer be part of active testing.

## Important Lifecycle Rule

**RETIRED** and **RECYCLED** do not mean the same thing.

- **RETIRED** means the display still physically exists but is no longer used in the current show. It may remain stored on a container for retired displays. A retired display is not removed simply because it is retired.
- **RECYCLED** means the display physically no longer exists. Recycled displays are removed from active testing when it is safe to do so.

## Before You Start

If a display is assigned to the wrong container, correct the Display record first so the Production Database matches the physical container.

## Procedure

1. Open the affected container test session.
2. Verify that the Production Database container assignments are correct.
3. Select **Refresh Displays to Test**.
4. Save the test-session record.
5. Review **Display Checks** after the refresh completes.

## What the Refresh Does

The system synchronizes Display Checks with the current operational inventory.

It can:

- add displays that now belong on the container;
- remove obsolete wrong-container testing rows when they can be removed safely;
- remove RECYCLED displays from active testing when they can be removed safely; and
- clean up a synthetic **Standalone Display** container for a RECYCLED display when no protected history or other dependency prevents cleanup.

Existing testing and Work Order history is preserved when a dependency requires it.

## Expected Result

Display Checks match the current operational displays that should be tested for the container.

## If Something Is Wrong

If an old display remains after refresh because it has protected history or a linked Work Order, do not delete it manually. Ask a manager for help.

## Related Documents

- [Handle a Wrong or Missing Display](Handle_a_Wrong_or_Missing_Display.md)
- [Test the Displays on a Container](Test_the_Displays_on_a_Container.md)

---

[← Previous: Handle a Wrong or Missing Display](Handle_a_Wrong_or_Missing_Display.md) | [↑ Test Sessions Home](README.md) | [Next: Defer Testing →](Defer_Testing.md)
