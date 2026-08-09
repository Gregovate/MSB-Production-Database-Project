# Work Orders

This subsystem documents the Production Database work-order system, including intake, triage, assignment, notification, repair integration, completion, and the database relationships that make work orders part of the larger production system.

## Current State

Work Orders are implemented and actively evolving. PostgreSQL is the system of record. Google Forms currently participates in intake. Directus currently handles triage/completion interaction and several workflow automations. A dedicated task-focused Work Order application may eventually replace parts of the Directus user experience without changing the PostgreSQL ownership model.

## Dependencies

- [Database Foundation](../01_Database_Foundation/README.md)
- [People and Identity](../03_People_and_Identity/README.md)
- [Testing System](../05_Testing_System/README.md) for repair-generated and repair-completion integration

## Current Responsibilities

- work-order identity and lifecycle
- stage/work-area location model
- task type, urgency, and target year
- assignee relationships
- Google Form intake and triage
- assignment and notification behavior
- display/test-session linkage
- completion and repair feedback
- current work-order visibility/navigation limitations

## Directus Flow Ownership

Work-order-specific Directus flows belong in this subsystem. Current production flows observed during the documentation audit include:

- Create Repair Work Order
- WOI Request Triage Email
- Work Order Email Assignees
- Work Order completion/update integration

These flows must be documented from the current production configuration rather than reconstructed from legacy design notes.

## Current Engineering Source

- [G_Work_Order_Design_Plan.md](../G_Work_Order_Design_Plan.md) — current engineering foundation being reconciled against the implemented Work Order system before relocation into this subsystem.

The design source is not considered obsolete merely because it still has a legacy filename. Its still-valid contracts must be preserved while stale implementation assumptions are corrected.

## Authoritative Sources

- current PostgreSQL work-order tables, constraints, procedures, and triggers
- current production Directus flows
- current Google Form/intake workflow
- current operational Work Order SOPs

## Related Systems

- [People and Identity](../03_People_and_Identity/README.md)
- [Testing System](../05_Testing_System/README.md)
- [Operational SOPs](../../02_Operational_SOPs/README.md)

## Resume Development

Begin by inspecting the current PostgreSQL implementation and current Directus flows. Reconcile `G_Work_Order_Design_Plan.md` against that implementation, move the resulting engineering document into this subsystem, then update this README as the final handoff.
