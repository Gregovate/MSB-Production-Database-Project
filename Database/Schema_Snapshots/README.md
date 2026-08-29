# PostgreSQL Schema Snapshots

This folder is the canonical repository location for point-in-time **schema-only PostgreSQL exports** of the MSB Production Database.

These exports are an engineering reference used to verify current table names, column names, keys, foreign keys, constraints, functions, procedures, triggers, views, permissions, and schema relationships without guessing from old documentation.

## Current Snapshot

The newest schema export belongs directly in this folder and must use a dated filename:

`msb_production_schema-YYYY-MM-DD.sql`

For example:

`msb_production_schema-2026-08-08.sql`

When a newer snapshot is captured, move the previous snapshot into [`archive/`](archive/) rather than deleting it.

## Authority and Freshness

The live PostgreSQL database remains runtime implementation truth.

The newest schema snapshot in this folder is the durable engineering authority when it is known to have been captured **after the most recent accepted production schema change**. It may be used for schema engineering and field-name verification when direct PostgreSQL access is unavailable.

Do not assume an older dump under `Database/schema/`, an archived snapshot, a migration file, or historical DDL is current merely because it contains the object being reviewed.

If the newest snapshot predates a known production schema change, it is stale and must not be treated as current authority. Capture a replacement before approving further DDL that depends on the missing current definition.

## Required Export Scope

The production schema snapshot should be a plain UTF-8, schema-only `pg_dump` covering the production schemas needed for engineering review, currently including:

- `lor_snap`
- `ops`
- `public`
- `ref`
- `stage`

The export must preserve enough PostgreSQL definition detail to reconstruct current engineering reality, including identities/sequences, constraints, indexes, triggers/functions, views, ownership, and grants.

## Mandatory Capture After Production Schema Changes

A fresh schema snapshot is required after **every accepted production schema change**.

The post-change sequence is:

1. apply and verify the production DDL;
2. complete any required Directus restart/reload and affected relationship/form/bookmark review;
3. capture a new schema-only export from the resulting production database;
4. save it directly in this folder using `msb_production_schema-YYYY-MM-DD.sql`;
5. move the prior current snapshot into `archive/`;
6. verify the new snapshot contains the intended schema change; and
7. commit the new snapshot with the implementation/documentation closeout.

A production schema change is not fully documented until this snapshot closeout is complete.

If more than one accepted schema change occurs on the same date before the repository snapshot is committed, the final snapshot for that date must reflect all accepted production changes. Do not overwrite a newer same-day snapshot with an earlier database state.

## Maintenance Rule

The current schema snapshot is a required engineering artifact. Repository cleanup or documentation reorganization must not remove or archive the only current schema snapshot without first establishing its replacement in this folder.

When documentation describes a table, column, relationship, function, procedure, trigger, permission, or view, verify the implementation against the newest known-current schema snapshot or the live database before changing the documentation.

The purpose of keeping this artifact current is operational as well as historical: engineering must still be able to determine current production schema when direct database connectivity or a development tunnel is unavailable.

## Related Documentation

- [Repository Change Workflow](../../System_Documentation/Project_Rules/Repository_Change_Workflow.md)
- [Database Foundation](../../Docs/02_Production_Database/01_System_Architecture/01_Database_Foundation/README.md)
- [Production Database Architecture](../../Docs/02_Production_Database/01_System_Architecture/README.md)
- [Database folder](../README.md)
