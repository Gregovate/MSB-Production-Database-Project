# People and Identity — Engineering

This is the engineering starting point for Production Database work involving person identity, authentication linkage, actor attribution, contact data, reusable capabilities, formal qualifications, and duplicate-safe person management.

## Current Authority

- [`../README.md`](../README.md) — subsystem overview and current responsibilities
- [`People_Capability_Qualification_Catalog_Design_2026-09-08.md`](People_Capability_Qualification_Catalog_Design_2026-09-08.md) — current People/Skills/Qualifications design candidate exposed by the 2025 Setup reconstruction
- Issue #130 — implementation/reconnaissance tracker for the global People capability/qualification catalog and duplicate-safe People Manager

## Current Production Boundary

`ref.person` remains the durable person/contact identity authority.

The proposed global capability/qualification tables and People Manager are **not** installed in Production yet.

The current Setup Captain candidate has a separate narrow migration, `Setup/Database/022_require_active_setup_captain_people.sql`, which restricts new Captain selection/assignment to active `ref.person` records. It does not implement the global People catalog.

## Resume Work

Before schema or application changes:

1. refresh current `main` and the intended work branch;
2. inventory the live/current `ref.person` schema, indexes, unique constraints, and foreign-key dependents;
3. recover legacy spreadsheet / To-Do talent data if available;
4. read the current People capability/qualification design;
5. preserve `ref.person` as the one durable person identity authority;
6. prove duplicate detection and merge behavior against a current Production clone; and
7. integrate Setup, Work Orders, and other consumers without creating subsystem-owned competing person identities.
