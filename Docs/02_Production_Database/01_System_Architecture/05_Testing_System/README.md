# Testing System

This subsystem documents the Production Database workflow for annual/container-based display testing, test-session state, repair outcomes, audit attribution, and integration with Work Orders.

## Current State

Testing is an active operational system. PostgreSQL stores test-session state and enforces important workflow rules; Directus currently provides operational views/bookmarks and selected workflow interaction.

The operator documentation is being reconciled to the current Operational SOP Standard. The 2026 annual test-season launch was performed manually during development, so the manager annual-start procedure remains a draft until the repeatable process is captured and verified.

## Design Intent

Testing validates more than whether a display lights. It also verifies container contents, display identity, placement, repair needs, and readiness for setup.

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

## Current Engineering Documents

The Testing-specific procedure and trigger documentation now lives in this subsystem:

- [P_Refresh_Test_Session](P_Refresh_Test_Session.md)
- [P_Cleanup_Recycled_Standalone_Display](P_Cleanup_Recycled_Standalone_Display.md)
- [T_After_Refresh_Test_Session](T_After_Refresh_Test_Session.md)

These are Testing-system implementation documents, not generic database-foundation documentation.

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
