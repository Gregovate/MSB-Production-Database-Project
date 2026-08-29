# Repository Change Workflow

## Purpose

This project rule defines the minimum repository-synchronization steps that must occur before making changes in the MSB Production Database repository.

The project is worked on across multiple active branches, sub-projects, and conversation threads. A branch that was current when one task started may be stale by the time another task resumes.

## Step Zero — Refresh Before Editing

Before changing code, schema, configuration, or controlled documentation:

1. refresh the repository view from the current remote;
2. identify the current `main` head;
3. verify whether the intended working branch is current with `main`;
4. inspect the latest versions of the files that will be changed; and
5. if the existing working branch is materially behind current `main`, rebase/merge deliberately or start a fresh branch from current `main` before editing.

Do not assume that repository state remembered from an earlier conversation is still current.

For connector/API-based work where a local `git pull` is not available, creating the work branch directly from current remote `main` and reading the current remote files satisfies the refresh requirement.

## Production Schema Authority

The **live PostgreSQL database is runtime implementation truth**.

The canonical engineering record of that implementation is the newest dated schema-only export under:

```text
Database/Schema_Snapshots/
```

The newest canonical snapshot may be used as the current engineering authority when it is known to have been captured **after the most recent accepted production schema change**. This is especially important when direct database-query access is unavailable.

Checked-in historical DDL, old migration scripts, development query files, archived schema exports, documentation, and conversation history remain evidence only unless they have been reconciled to the current canonical snapshot or live database.

Before designing or applying a schema change to an existing production object:

1. inspect the newest canonical schema snapshot and confirm its capture date/revision is after the latest known production schema change;
2. inspect the object's current columns and data types;
3. inspect its primary key, unique constraints, foreign keys, check constraints, defaults, generated expressions, and sequences/identity behavior as applicable;
4. inspect current indexes;
5. inspect current triggers and referenced trigger functions;
6. inspect dependent views/functions/procedures where the proposed change can affect them;
7. inspect current ownership, grants, and application-role permissions when the change can affect access;
8. inspect relevant Directus metadata, relationships, forms, bookmarks, or other application configuration when the object is exposed through Directus;
9. use live PostgreSQL inspection as an additional verification whenever direct access is available; and
10. derive the additive migration/change from the verified current production definition, not from an unverified historical CREATE TABLE file.

A repository DDL file that contains `DROP TABLE`, recreates an object from scratch, uses an obsolete key, omits current columns/constraints, or otherwise differs from the canonical current snapshot must be treated as historical/development evidence until reconciled.

If neither direct live-schema access nor a known-current canonical schema snapshot is available, stop before approving or applying DDL to the existing production object. Capture/obtain current schema evidence rather than guessing.

### Mandatory Post-Schema-Change Snapshot

Every accepted production schema change must include a fresh schema-only PostgreSQL snapshot as part of deployment closeout.

The schema change is not considered fully documented until:

1. the production DDL has been applied and verified;
2. any required Directus restart/reload and relationship/form/bookmark review has been completed;
3. a new schema-only snapshot has been captured from the resulting production database;
4. the new snapshot has been saved directly under `Database/Schema_Snapshots/` using the required dated filename;
5. the previous current snapshot has been moved to `Database/Schema_Snapshots/archive/` rather than deleted;
6. the new snapshot has been reviewed sufficiently to confirm the intended object/change is present; and
7. the snapshot and related controlled documentation have been committed with the implementation work before the issue/PR is treated as complete.

This requirement exists so future engineering can reconstruct current production schema from the repository even when direct PostgreSQL access is unavailable.

### Simple schema rule

> **Use the newest post-change canonical schema snapshot as the durable engineering authority; verify live PostgreSQL too whenever access is available. After every production schema change, capture a new snapshot before closeout.**

## Concurrent Project Work

When another sub-project has changed the same area since the current branch was created:

- review the newer work before applying older planned changes;
- preserve accepted newer architecture and operator behavior;
- do not overwrite newer documentation merely because an older branch already contains a draft rewrite;
- reconcile conflicts against the current repository authority, not conversation memory; and
- record any newly discovered cross-system conflict in the responsible engineering documentation.

## Documentation Work

Documentation changes are subject to the same synchronization rule as code.

Before rewriting an operator procedure or engineering document:

1. read the current repository version;
2. read the current engineering authority and related subsystem README when the subject crosses system boundaries;
3. preserve newer accepted decisions from parallel work;
4. update the operator document only after the underlying current behavior is understood; and
5. perform the normal README/documentation closeout after the change.

## Why This Rule Exists

The repository is the durable project record. Parallel development is expected.

Refreshing first and maintaining a current schema snapshot prevents:

- overwriting newer work;
- documenting obsolete behavior;
- rebuilding decisions already settled in another thread;
- creating conflicting operator and engineering instructions;
- deriving production schema changes from stale development DDL;
- becoming blocked merely because direct database-query access is unavailable; and
- wasting time reconciling changes after they have already been written against a stale base.

## Simple Rule

> **Before changing the repository, refresh current `main` and read the latest affected files. Do not edit from remembered repository state.**

## Related Standards

- [Documentation Standards](../Standards/Documentation_Standards.md)
- [README Portal Standard](../Standards/README_Portal_Standard.md)
- [Document Control Standard](../Standards/Document_Control_Standard.md)
