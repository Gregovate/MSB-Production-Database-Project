# Controller Management Application Boundary — 2026-08-31

| Item | Value |
|---|---|
| Status | ACTIVE ARCHITECTURE DECISION |
| Issue | #110 |
| Primary Controller UX | Purpose-built Controller application |
| Directus role | Simple table/reference maintenance only |
| Controller delete policy | No normal Controller delete |

## Decision

Directus remains useful in the MSB Production Database for relatively simple maintenance tasks where the operator is editing one table at a time, optionally with a small number of lookups or boolean controls.

Accepted examples include:

- maintaining lookup/reference tables;
- maintaining ordinary Display metadata;
- selecting simple related values such as status, frame, theme, designer, or container;
- toggling boolean request/state fields such as `label_required` and `print_label`;
- basic record notes and audit-aware metadata maintenance.

The existing Display edit form is an acceptable example of this boundary. Its formatting and layout are limited and somewhat clunky, but it is operationally adequate for one-record metadata maintenance.

Directus is **not** the target operational UX once a task becomes a multi-table workflow.

## Custom-application threshold

A purpose-built application should own the UX when the operator must coordinate several related facts/actions in one workflow, including any combination of:

- multiple related tables;
- relationship assignment/unassignment;
- workflow state transitions;
- derived context from other records;
- conditional validation;
- task-specific search/navigation;
- printing/label request workflow;
- history or reconciliation views;
- cross-links to operational tools;
- application-specific permissions and commands.

Controller Management is already beyond the Directus threshold.

Work Orders are expected to cross the same threshold and should eventually become a purpose-built application rather than remain dependent on Directus as the primary UX.

## Controller Management responsibility

The Controller application owns the normal operational experience for:

- browse/search;
- Add Controller;
- Edit Controller;
- current model/status/location/firmware maintenance;
- current programmed Network/UID/IP maintenance;
- Controller-to-Display assignment and unassignment;
- reviewed `wiring_source_display_id` maintenance;
- label request state including `print_label`;
- firmware/history context;
- FieldWiring cross-links;
- shelf-stock/unassigned Controller workflows;
- Manager-only commands and validation.

The application may visually reuse successful Directus concepts such as grouped sections, readable lookups, booleans, and read-only audit fields, but it is not constrained by Directus layout or relation-model limitations.

## Directus responsibility for Controller subsystem

Directus may remain available for simple Controller/reference-table maintenance where it behaves well, for example:

- `ref.controller_model`;
- `ref.controller_status`;
- `ref.controller_firmware_version`;
- simple individual `ref.controller` metadata fields if operationally useful;
- simple boolean fields such as `print_label`.

Do not require Directus to provide the Controller-to-Display assignment workspace or other complex Controller workflows.

## Database-model rule

Do not distort a sound PostgreSQL data model solely to satisfy a Directus UI limitation when Directus is not the intended operational application.

In particular, `ref.controller_display` currently uses the legitimate composite business key:

```text
PRIMARY KEY (controller_id, display_id)
```

A rollback-only investigation proved that adding a surrogate `controller_display_id` would make the table easier for Directus to treat as an O2M collection, but the architecture decision is **not to apply that schema change merely for Directus compatibility**.

The Controller application can work directly with the governed composite relationship semantics.

## Security boundary

The existing Controller/FieldWiring browser remains read-only until authenticated Manager write handling is implemented.

Do not grant broad write privileges to `fieldwiring_app` simply to enable browser editing.

Browser-native Controller editing must include a server-side authenticated Manager authorization check before any write operation. Client-side button visibility is not the security boundary.

The implementation should preserve:

- read-only behavior for ordinary users;
- Manager-only create/update/assignment commands;
- no normal Controller DELETE;
- controlled relationship unassignment without deleting the Controller asset;
- PostgreSQL validation and audit triggers as final data-integrity authority.

## Directus formatting lesson

Directus provides limited form formatting. Existing MSB forms can group fields and provide reasonable lookup/boolean controls, but layout flexibility is insufficient for complex operational workflows.

This limitation is accepted for simple metadata maintenance and lookup tables. It is not a reason to force complex workflows into Directus.

## Acceptance direction

Controller Management is complete when a Manager can use the purpose-built Controller application to perform the full operational workflow without raw SQL and without relying on Directus for multi-table coordination.

Directus remains a supporting administration/reference tool, not the Controller Management application.
