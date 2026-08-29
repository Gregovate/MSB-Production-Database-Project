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

## Production Schema Authority — Verify Live PostgreSQL Before DDL

For any table, view, function, trigger, constraint, sequence, permission path, or other database object that currently exists in production, the **live PostgreSQL definition is the implementation authority for current state**.

Checked-in DDL, old migration scripts, development query files, schema exports, archived SQL, documentation, and conversation history may be useful evidence, but they must not be assumed to represent the current production definition without verification against the live database.

Before designing or applying a schema change to an existing production object:

1. inspect the live PostgreSQL object's current columns and data types;
2. inspect its primary key, unique constraints, foreign keys, check constraints, defaults, generated expressions, and sequences/identity behavior as applicable;
3. inspect current indexes;
4. inspect current triggers and referenced trigger functions;
5. inspect dependent views/functions/procedures where the proposed change can affect them;
6. inspect current ownership, grants, and application-role permissions when the change can affect access;
7. inspect relevant Directus metadata, relationships, forms, bookmarks, or other application configuration when the object is exposed through Directus;
8. compare the live definition with repository SQL/documentation and explicitly identify stale or incomplete repository artifacts before using them as implementation input; and
9. derive the additive migration/change from the verified live production definition, not from an unverified historical CREATE TABLE file.

A repository DDL file that contains `DROP TABLE`, recreates an object from scratch, uses an obsolete key, omits current columns/constraints, or otherwise differs from production must be treated as historical/development evidence until reconciled. It must not be used as the basis for a production migration merely because its filename appears authoritative.

If live-schema access is not available, stop before approving or applying DDL to the existing production object. Record the missing verification as a blocker rather than guessing from repository files.

After an accepted production schema change, update the responsible repository schema/reference documentation so future work does not repeatedly rediscover the same divergence. Where Directus is affected, include the required Directus reload/restart and form/bookmark/relationship review in the deployment and acceptance sequence.

### Simple schema rule

> **Existing production object: inspect live PostgreSQL first. Repository DDL is evidence until verified.**

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

Refreshing first prevents:

- overwriting newer work;
- documenting obsolete behavior;
- rebuilding decisions already settled in another thread;
- creating conflicting operator and engineering instructions;
- deriving production schema changes from stale development DDL; and
- wasting time reconciling changes after they have already been written against a stale base.

## Simple Rule

> **Before changing the repository, refresh current `main` and read the latest affected files. Do not edit from remembered repository state.**

## Related Standards

- [Documentation Standards](../Standards/Documentation_Standards.md)
- [README Portal Standard](../Standards/README_Portal_Standard.md)
- [Document Control Standard](../Standards/Document_Control_Standard.md)
