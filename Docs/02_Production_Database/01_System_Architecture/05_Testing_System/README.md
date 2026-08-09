# Testing System

This subsystem documents the Production Database workflow for annual/container-based display testing, test-session state, repair outcomes, audit attribution, and integration with Work Orders.

## Current State

Testing is an active operational system. PostgreSQL stores test-session state and enforces important workflow rules; Directus currently provides operational views/bookmarks and selected workflow interaction.

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

## Current Engineering Documents

The following current production documents still live in the former procedure/trigger folders and are being migrated into this subsystem as part of the architecture cleanup:

- [P_Refresh_Test_Session](../01_Stored_Proceedures/P_Refresh_Test_Session.md)
- [P_Cleanup_Recycled_Standalone_Display](../01_Stored_Proceedures/P_Cleanup_Recycled_Standalone_Display.md)
- [T_After_Refresh_Test_Session](../02_Triggers/T_After_Refresh_Test_Session.md)

These are Testing-system implementation documents, not generic database-foundation documentation.

## Authoritative Sources

Current PostgreSQL procedures/triggers and current Directus configuration are implementation truth. Existing operator procedures remain under the separate Operational SOP tree.

## Related Systems

- [Work Orders](../06_Work_Orders/README.md)
- [Operational SOPs](../../02_Operational_SOPs/README.md)

## Known Open Work

Move the current Testing-specific procedure/trigger documents into this subsystem, repair their cross-links, then reconcile the remaining testing views and Directus behavior into the handoff. Archived testing documents are historical evidence, not current authority.
