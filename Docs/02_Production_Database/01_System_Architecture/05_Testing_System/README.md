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

## Authoritative Sources

Current PostgreSQL procedures/triggers and current Directus configuration are implementation truth. Existing operational procedures remain under the separate Operational SOP tree.

## Related Systems

- [Work Orders](../06_Work_Orders/README.md)
- [Operational SOPs](../../02_Operational_SOPs/README.md)

## Known Open Work

Reconcile the current testing procedures, triggers, views, and Directus behavior into this subsystem and document the current refresh/repair lifecycle without relying on archived testing documents as active authority.
