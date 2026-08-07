# Stored Procedures

## Purpose

This section documents the production PostgreSQL stored procedures that implement MSB business logic.

These procedures are part of the production application architecture and should be treated as production software rather than ad-hoc SQL scripts.

Each procedure document describes:

• Purpose
• Calling workflow
• Inputs
• Outputs
• Business rules
• Safety protections
• Dependencies
• Related triggers
• Revision history

Whenever production business logic changes, the corresponding procedure documentation shall be updated as part of the same change.

---

# Stored Procedures

This folder contains the production documentation for operational stored procedures used by the MSB Database.

Each document describes the procedure's business purpose, architecture, business rules, dependencies, validation steps, and revision history.

## Current Procedures

| Procedure | Purpose |
|-----------|---------|
| `P_Refresh_Test_Session.md` | Synchronizes active display testing records with the current operational container inventory, removes invalid testing relationships, and coordinates cleanup of recycled stand-alone displays. |
| `P_Cleanup_Recycled_Standalone_Display.md` | Removes synthetic stand-alone containers and associated operational testing records after a display has been marked `RECYCLED`, while preserving the permanent historical display record. |

## Design Philosophy

Procedures are documented individually and cross-referenced where they cooperate to implement a larger workflow.

For example:

```
Directus
    ↓
Refresh Displays to Test
    ↓
T_After_Refresh_Test_Session
    ↓
P_Refresh_Test_Session
    ↓
P_Cleanup_Recycled_Standalone_Display
```

This organization allows each procedure to maintain a single responsibility while documenting how the complete operational workflow is executed.