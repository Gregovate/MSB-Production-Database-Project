# LOR SQLite Output Database Structure

| Document Control | Value |
|---|---|
| Status | CURRENT — Engineering Design |
| System | LOR Preview Parser |
| Database | `lor_output_v7_scene.db` |
| Current Parser Baseline | V7.0.9 |
| Owner | MSB Database Administrator |
| Initial Release | 2026-08-08 |

---

# Purpose

This document describes the engineering design of the SQLite database produced by the MSB LOR Preview Parser.

The SQLite database is the intermediate engineering data model between the Light-O-Rama Preview file (`*.lorprev`) and the LOR2DB PostgreSQL ingest process.

It is a disposable database that is rebuilt from scratch during every parser execution.

This document explains:

- why each table exists;
- how the tables relate;
- the engineering contract provided by each table;
- the published SQLite views;
- the downstream systems that consume the parser output.

This document intentionally does **not** duplicate the SQL implementation contained within the parser source code.

---

# System Position

The SQLite output database forms the engineering boundary between Light-O-Rama preview files and the production database.

```text
Approved .lorprev files
          │
          ▼
LOR Preview Parser
          │
          ▼
lor_output_v7_scene.db
          │
          ▼
PostgreSQL Ingest
          │
          ▼
lor_snap Snapshot
          │
          ▼
LOR2DB Reconciliation
          │
          ▼
Production Database
```

Every downstream component depends on the engineering contract described here.

---

# Engineering Philosophy

The SQLite database is designed as a complete snapshot of the currently approved Light-O-Rama previews.

Every parser execution creates an entirely new database.

Nothing inside the SQLite database is considered permanent.

The parser is intentionally deterministic.

Running the parser twice against identical preview files should produce equivalent SQLite content.

The SQLite database exists only to normalize Light-O-Rama preview information into a consistent engineering model suitable for production ingest.

---

# Schema Ownership

The SQLite schema is implemented exclusively within:

`Docs/01_LOR_System/02_Data_Extraction/Parser/parse_props_v7_scene_parser.py`

The parser source code is the authoritative implementation of:

- CREATE TABLE statements
- CREATE VIEW statements
- indexes
- constraints
- implementation SQL

This document intentionally avoids duplicating those implementation details.

Instead, it documents the engineering intent behind the schema.

---

# Database Tables

The parser materializes several engineering tables.

## previews

Purpose

Stores one record for every imported LOR preview.

Responsibilities

- preview identity
- stage assignment
- revision
- background image
- parser source file

Consumers

- PostgreSQL ingest
- reporting
- parser provenance

---

## parser_run

Purpose

Records provenance for the current parser execution.

Responsibilities

- parser version
- execution timestamps
- operator
- workstation
- source preview folder
- database location
- parser status
- parser run mode and declared LOR version
- parser source SHA-256 and complete preview-manifest SHA-256
- approved complete XML compatibility-manifest SHA-256
- output validation status and detail

This table documents the engineering provenance of the generated snapshot.

`Status=COMPLETE` is legal only with `ValidationStatus=PASSED`. The final file
is published atomically after the parser reopens and validates this row.

---

## props

Purpose

Stores every materialized physical display.

This table represents the permanent engineering identity of each display extracted from the preview files.

Responsibilities

- materialized display identity
- raw LOR identity
- display naming
- controller information
- wiring information
- channel assignments

This table is the primary engineering source for downstream production ingest.

---

## subProps

Purpose

Stores materialized sub-components associated with a parent display.

Responsibilities

- subprop identity
- canonical master display
- inherited wiring information
- parser-generated materialization

Subprops are normalized independently because many downstream engineering processes require direct access to them.

---

## scenes

Purpose

Stores LOR scene metadata.

Important Engineering Rule

Scenes are organizational workspace objects.

Scenes are **not** permanent display identities.

The table stores every preview-level LOR `<Scene>` row. A table count must be
reported as **raw LOR Scene rows**, not as the number of operational Scenes.
Stage roots, Sub-stage roots, `Root` markers, true Scenes, and unprefixed
Display/group locators are classified downstream by Folder Alignment without
changing parser extraction.

---

## scene_lor_props

Purpose

Stores positional membership of displays within scenes.

Responsibilities

- scene membership
- positional ordering
- stage relationships
- scene provenance

This table is rebuilt completely during every parser execution.

---

## dmxChannels

Purpose

Stores DMX-specific channel information.

Responsibilities

- universes
- channel ranges
- parser materialization of DMX controllers

---

# Table Relationships

Conceptually the database is organized as:

```text
previews
    │
    ├──────────────┐
    ▼              ▼
 props         scenes
    │              │
    ▼              ▼
subProps   scene_lor_props

DMXChannels
```

The parser maintains these relationships as a normalized engineering model.

---

# SQLite Views

In addition to the physical SQLite tables, the parser creates a collection of SQL views.

These views are considered part of the parser's published engineering interface and are intended to simplify downstream applications, reporting, validation, and future system integration.

The parser source code is the authoritative implementation of every view. This document intentionally describes the engineering purpose of each view rather than duplicating the SQL definitions.

## Engineering Philosophy

The parser exposes two public interfaces:

- SQLite tables
- SQLite views

The tables represent the parser's internal normalized data model.

The views represent stable logical interfaces that downstream software should use whenever practical.

Applications should avoid depending on undocumented implementation details of the underlying tables when an equivalent published view exists.

---

## Current Snapshot Views

Purpose

Provide simplified access to the current parser snapshot.

Typical consumers

- PostgreSQL ingest
- validation
- engineering queries

---

## Wiring Views

Purpose

Expose physical wiring relationships extracted from the preview.

Typical consumers

- FormView
- Wiring System
- wiring reports
- controller inventory
- setup documentation

---

## Display Views

Purpose

Provide engineering summaries of materialized displays.

Typical consumers

- inventory validation
- engineering reports
- reconciliation support

---

## Scene Views

Purpose

Provide normalized scene relationships.

Typical consumers

- LOR2DB reconciliation
- engineering validation
- reporting

---

## Preview Views

Purpose

Provide preview-level metadata.

Typical consumers

- production reporting
- parser validation
- ingest verification

---

# Compatibility Views

Some parser views exist specifically to support compatibility with legacy applications.

The current example is FormView.

FormView historically consumed the V6 SQLite database.

Equivalent compatibility views are generated from the V7 scene-aware database to allow FormView to continue operating while migration to the native V7 schema is completed.

Compatibility views should remain stable until all dependent software has migrated.

---

# Engineering Contract

Downstream systems should rely upon the published engineering interfaces provided by the parser whenever practical.

Examples include:

- PostgreSQL ingest
- LOR2DB reconciliation
- FormView
- future Wiring System
- engineering utilities
- validation procedures
- reporting

The parser implementation may evolve internally provided that the documented engineering contract remains valid.

---

# Maintenance

Any parser revision that changes:

- table purpose;
- logical relationships;
- published SQLite views;
- engineering contracts;
- downstream interfaces;

shall also update this document.

Changes to SQL implementation alone do **not** require modification unless they alter the documented engineering behavior.

---

# Related Systems

The SQLite output database forms the engineering interface between the LOR Preview Parser and the LOR2DB production ingest process.

| System | Purpose |
|---|---|

| [LOR Preview Authoring](../01_Preview_Authoring/README.md) | Defines how approved Light-O-Rama previews are created, named, and managed before parsing. |
| [LOR Data Extraction](README.md) | Engineering documentation for the parser, `.lorprev` format, SQLite output database, and compatibility review process. |
| [LOR2DB Ingest](../../../LOR2DB/01_Ingest/README.md) | Imports the parser-generated SQLite snapshot into PostgreSQL and creates the production snapshot used by reconciliation. |
| [LOR2DB Reconciliation](../../../LOR2DB/02_Reconciliation/README.md) | Reviews the imported snapshot, applies controlled production changes, and validates the results. |
| [LOR2DB Reporting](../../../LOR2DB/03_Reporting/README.md) | Publishes the immutable reconciliation reports and production evidence. |
| [FormView](../../../LOR/FormView/README.md) | Stand-alone engineering application that consumes parser output for display and wiring visualization. |
| Preview Merger | Engineering subsystem that protects the approved preview set before parser execution. *(Add README link when the subsystem portal is completed.)* |

---

# Related Documents

- [LOR Preview File Structure Specification](LOR_Preview_File_Structure_Specification.md)
- [LOR Preview Parser Architecture](LOR_Preview_Parser_Architecture.md)
- [LOR Preview Version Compatibility Review](LOR_Preview_Version_Compatibility_Review.md)
- [LOR2DB Ingest](../../../LOR2DB/01_Ingest/README.md)
