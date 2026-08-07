# Database Triggers

## Purpose

Triggers provide the event-driven entry points into the production business logic.

Triggers should remain lightweight.

Their responsibility is to detect database events and invoke the appropriate stored procedure.

Business rules belong in stored procedures rather than inside trigger code whenever practical.

Each trigger document describes:

• Trigger event
• Calling conditions
• Invoked procedure
• Business purpose
• Dependencies