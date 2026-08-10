# PostgreSQL Schema Snapshots

This folder is the canonical repository location for point-in-time **schema-only PostgreSQL exports** of the MSB Production Database.

These exports are an engineering reference used to verify current table names, column names, keys, foreign keys, constraints, functions, procedures, triggers, views, and schema relationships without guessing from old documentation.

## Current Snapshot

The newest schema export belongs directly in this folder and must use a dated filename:

`msb_production_schema-YYYY-MM-DD.sql`

For example:

`msb_production_schema-2026-08-08.sql`

When a newer snapshot is captured, move the previous snapshot into [`archive/`](archive/) rather than deleting it.

## Required Export Scope

The production schema snapshot should be a plain UTF-8, schema-only `pg_dump` covering the production schemas that are needed for engineering review, currently including:

- `lor_snap`
- `ops`
- `public`
- `ref`
- `stage`

The live PostgreSQL database remains runtime implementation truth. This repository snapshot is the durable point-in-time reference used for architecture review, documentation, field-name verification, and comparison between database revisions.

## Maintenance Rule

The current schema snapshot is a required engineering artifact. Repository cleanup or documentation reorganization must not remove or archive the only current schema snapshot without first establishing its replacement in this folder.

When documentation describes a table, column, relationship, function, procedure, trigger, or view, verify the implementation against the newest schema snapshot or the live database before changing the documentation.

## Related Documentation

- [Database Foundation](../../Docs/02_Production_Database/01_System_Architecture/01_Database_Foundation/README.md)
- [Production Database Architecture](../../Docs/02_Production_Database/01_System_Architecture/README.md)
- [Database folder](../README.md)
