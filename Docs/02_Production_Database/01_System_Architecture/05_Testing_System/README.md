# Testing System

This subsystem documents the Production Database workflow for annual/container-based display testing, test-session state, repair outcomes, audit attribution, and integration with Work Orders.

## Current State

Testing is an active operational system. PostgreSQL stores test-session state and enforces important workflow rules; Directus currently provides operational views/bookmarks and selected workflow interaction.

The operator documentation is being reconciled to the current Operational SOP Standard. The 2026 annual test-season launch was performed manually during development, so the manager annual-start procedure remains a draft until the repeatable process is captured and verified.

## Design Intent

Testing validates more than whether a display lights. It also verifies container contents, display identity, placement, repair needs, and readiness for setup.

## Display Lifecycle Boundary

Testing must distinguish between displays that are **RETIRED** and displays that are **RECYCLED**.

- **RETIRED** means the display still physically exists but is no longer used in the current show. A retired display may remain assigned to a storage container, including a container used for retired displays. Retirement by itself is not a reason to remove the display from inventory or delete its container relationship.
- **RECYCLED** means the display physically no longer exists. Recycled displays are excluded from active testing and may be removed from active test-session relationships when the cleanup can be performed safely.
- When a RECYCLED display uses a synthetic **Standalone Display** container, the Testing cleanup process may also remove that synthetic container and its active testing relationships when no protected work-order or historical dependency prevents cleanup.

The refresh/cleanup process must preserve historical testing and work-order records when dependencies still exist.

## Dependencies

- [Database Foundation](../01_Database_Foundation/README.md)
- [People and Identity](../03_People_and_Identity/README.md)
- [Containers and Storage](../04_Containers_and_Storage/README.md)

## Current Responsibilities

- test-session creation and refresh behavior
- display test-session records
- test status and notes rules
- actor attribution for checked/updated state
- repair handoff to Work Orders
- completion feedback from Work Orders to testing
- annual test-season initialization contract and validation
- lifecycle-aware cleanup of RECYCLED displays and synthetic Standalone Display containers

## Current Engineering Documents

Testing depends on PostgreSQL procedures and triggers whose canonical engineering documentation is centralized under Database Foundation:

- [P_Refresh_Test_Session](../01_Database_Foundation/01_Functions_and_Procedures/P_Refresh_Test_Session.md)
- [P_Cleanup_Recycled_Standalone_Display](../01_Database_Foundation/01_Functions_and_Procedures/P_Cleanup_Recycled_Standalone_Display.md)
- [T_After_Refresh_Test_Session](../01_Database_Foundation/02_Triggers/T_After_Refresh_Test_Session.md)

Testing owns the business workflow and links to these database objects; it does not maintain duplicate authoritative copies of their engineering documentation.

## Authoritative Sources

Current PostgreSQL procedures/triggers and current Directus configuration are implementation truth. Existing operator procedures remain under the separate [Test Session Operational SOPs](../../02_Operational_SOPs/Test_Sessions/README.md) tree.

The current operator testing SOP predates the documentation standard and must be audited against production behavior before it is treated as fully reconciled authority.

## Related Systems

- [Containers and Storage](../04_Containers_and_Storage/README.md)
- [Work Orders](../06_Work_Orders/README.md)
- [Test Session Operational SOPs](../../02_Operational_SOPs/Test_Sessions/README.md)

## Known Open Work

- Audit the current Container Testing & Repair SOP against PostgreSQL and Directus behavior.
- Separate normal volunteer testing from manager-only annual season setup and correction procedures.
- Verify current test-status terminology and the Work Order completion feedback loop before publishing the rewritten operator SOP as CURRENT.
- Capture and test the repeatable annual test-season initialization process before marking the manager setup procedure CURRENT.
- Reconcile remaining Directus testing views/bookmarks and operational behavior into this handoff.

Archived testing documents are historical evidence, not current authority.
