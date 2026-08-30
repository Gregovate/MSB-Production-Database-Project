# Stage Root Authority and Path Synchronization

| Document Control | Value |
|---|---|
| Document Type | Database engineering contract |
| System | LOR2DB Reconciliation / Google Drive Stage context |
| Status | CURRENT — migrations 0039 through 0041 production deployed and validated |
| Owner | MSB Database Administrator |
| Last Reviewed | 2026-08-30 |
| Issues | #96, #101, #104 |
| Migrations | `0039_repair_stage_folder_authority.sql`, `0040_sync_existing_stage_folder_path.sql`, `0041_grant_lor_preflight_governed_root.sql` |

## Purpose

This document is the current authority for how LOR2DB stores and maintains permanent Stage/Sub-stage naming and the current Google Drive `folder_path` locator in `ref.stage`.

It records the production behavior established by migrations 0039, 0040, and the least-privilege application grant repaired by migration 0041. Where older reconciliation design documents describe earlier P1 Stage naming, path behavior, or application access, this contract controls for Stage root naming and `folder_path` synchronization.

## Existing Google Drive Naming Contract — Unchanged

The established Display Folders grammar remains:

```text
NN-Name-XY      = Stage root
NNa-Name-XY     = Sub-stage root
NN-Name         = Scene under the owning Stage
NNa-Name        = Scene under the owning Sub-stage
unprefixed name = Display/shared Display group
Root            = owning Preview Stage root in a Background Preview
```

Examples:

```text
07-Whoville-WV       = Stage 07 root
07a-Who Forest-WF    = Sub-stage 07a root
07-Who People        = Scene under Stage 07
07-Who Spiral Tree   = Scene under Stage 07
```

The terminal short code on a Stage/Sub-stage root is structural. It is part of the governed root name and is not stripped from permanent Stage metadata.

## Permanent Stage Identity and Current Locator

For a governed Stage/Sub-stage:

```text
stage_id    = permanent database surrogate identity
stage_key   = canonical Stage/Sub-stage key
stage_name  = exact governed Google Drive root basename
folder_name = exact governed Google Drive root basename
folder_path = current Google Drive locator for that governed root
```

Example:

```text
stage_key   = 15
stage_name  = 15-Church-Bells-CH
folder_name = 15-Church-Bells-CH
folder_path = G:\Shared drives\Display Folders\15-Church-Bells-CH
```

`folder_path` is a locator, not permanent physical identity. Moving or renaming a governed Stage/Sub-stage folder can legitimately require `folder_path` to change while preserving the same `stage_id`.

## Frozen LOR Path Evidence

The parser and PostgreSQL ingest already preserve LOR `BackgroundFile` path strings in the frozen `lor_snap` snapshot. LOR2DB does not need to enumerate or search the Google Drive to rediscover a governed Stage/Sub-stage root.

The database resolver is:

```text
ops.f_lor_governed_stage_roots(import_run_id, stage_key)
```

It reads frozen Preview/Scene path evidence for one import, accepts paths under:

```text
G:\Shared drives\Display Folders
```

and identifies governed Stage/Sub-stage root segments using the established root-name grammar.

### Performance rule

**Do not add Google Drive enumeration/search to Stage naming or `folder_path` synchronization.**

The normal authority chain is:

```text
Google Drive folder corrected
    -> LOR Preview/Scene BackgroundFile reference corrected
    -> parser captures that path
    -> reviewed SQLite is ingested
    -> reconciliation freezes that import
    -> P1 uses the frozen governed-root evidence
    -> ref.stage metadata/path is synchronized when safely proven
```

Until a corrected LOR path has been parsed and ingested, the Production Database may still contain the previous locator. Field applications must not compensate by recursively searching Display Folders.

## Migration 0039 — Governed Stage Naming Authority

Migration 0039 corrected the prior P1 naming-source defect.

For existing accepted Stage/Sub-stage rows it repaired `stage_name` and `folder_name` to the exact governed root basename. It deliberately did not modify existing `folder_path` values during that migration.

For future `ADD_NEW_STAGE` decisions:

- exactly one governed root must exist in the reconciliation run's frozen import;
- the exact governed root name and path are frozen into the append-only Stage authority action;
- P1 rechecks the frozen governed root before insertion;
- the exact root basename is stored as both `stage_name` and `folder_name`;
- the exact governed path is stored as `folder_path`;
- LOR Preview/Scene descriptive names are not a fallback for permanent Stage naming.

Production migration 0039 was validated on 2026-08-30.

## Migration 0040 — Existing Stage/Sub-stage Path Synchronization

Migration 0040 extends the production-accepted P1 without changing Stage identity.

For an existing governed Stage/Sub-stage, P1 may synchronize `ref.stage.folder_path` only when all of the following are true:

1. the Stage is part of an approved or auto-approved existing-Stage P1 context;
2. the reconciliation run's frozen `import_run_id` yields exactly one governed root for the permanent `stage_key`;
3. the governed root `stage_name` exactly matches the permanent `ref.stage.stage_name`;
4. the governed root `folder_name` exactly matches the permanent `ref.stage.folder_name`;
5. the Stage is not one of the explicitly held/special identities;
6. the governed path differs from the stored `folder_path`.

When those conditions are satisfied:

- `stage_id` is preserved;
- only `folder_path` and normal audit fields are changed by this path-sync step;
- a reconciliation result is recorded with reason code `P1_STAGE_FOLDER_PATH`;
- no Google Drive scan occurs.

If governed root evidence is absent, multiple, or inconsistent with the permanent Stage identity, P1 does not synthesize or guess a path.

## Migration 0041 — LOR2DB Least-Privilege Resolver Access

Migration 0039 correctly revoked `PUBLIC` execute on `ops.f_lor_governed_stage_roots(bigint,text)`, but the first production installation omitted the explicit grant required by the least-privilege LOR2DB login `lor_preflight_app`.

That omission blocked browser Stage review on reconciliation Run 18 / import 60 with:

```text
permission denied for function f_lor_governed_stage_roots
```

Migration 0041 repairs only that privilege boundary:

```text
GRANT EXECUTE ON FUNCTION
    ops.f_lor_governed_stage_roots(bigint,text)
TO lor_preflight_app;
```

`PUBLIC` remains revoked. No production Stage data, snapshot data, reconciliation actions, parser data, Google Drive content, or application code is changed by 0041.

### Required application-role acceptance rule

A database change used by the LOR2DB browser is not production-accepted merely because it works as `msbadmin`.

When a new function, view, or procedure enters a browser-facing query path, acceptance must exercise that exact path under the real least-privilege application role. For the governed-root resolver this means validating with:

```text
SET LOCAL ROLE lor_preflight_app
    -> SELECT from ops.v_lor_reconciliation_operator_stage_review
```

This application-role check is required in addition to object-definition and administrator-role validation.

## Held / Special Stage Identities

The current held set remains outside automatic root-name/path repair:

```text
12, 39, 40, 90, 91, 92, 93, 94
```

These rows require separate evidence/scope and must not be silently folded into the normal governed-root rules.

## Production Acceptance — 2026-08-30

### Migration 0039

Production acceptance repaired the accepted Stage/Sub-stage names while leaving existing paths and held rows unchanged.

Rollback artifact:

```text
/home/msbadmin/backups/postgres/msb-pre-0039-stage96-20260830T161515Z.dump
```

### Migration 0040

Before migration 0040, import 59 proved exactly three normal governed path differences and no multiple-root cases:

```text
05a  blank
     -> G:\Shared drives\Display Folders\05-Festive Trees-FT\05a-Mega Star-MS

07a  G:\Shared drives\Display Folders\07-Whoville-WV/07a-Who Forest
     -> G:\Shared drives\Display Folders\07-Whoville-WV\07a-Who Forest-WF

17   G:\Shared drives\Display Folders\17-Candy Land-CL
     -> G:\Shared drives\Display Folders\17-Candyland-CL
```

Migration 0040 updated exactly those three rows. Validation 35 then reported zero normal governed path mismatches. Non-target Stage rows, held rows, Stage identity fields, import 59, and reconciliation run 17 remained unchanged. PostgreSQL remained healthy.

Rollback artifact:

```text
/home/msbadmin/backups/postgres/msb-pre-0040-stage101-20260830T172117Z.dump
```

SHA-256:

```text
4b243a01583c18571349727cfeaa0e9b213536fcd8bf158580542c3099d9eaa0
```

### Migration 0041 / Run 18 recovery

Production evidence identified `lor_preflight_app` as the only LOR2DB login missing resolver execute permission. Before repair:

```text
can_record_stage_authority = true
can_read_governed_root     = false
Run 18 / import 60         = AWAITING_DECISIONS
Run 18 actions             = 0
```

The production repair first tested the exact Stage-review query inside a temporary transaction after granting execute and using `SET LOCAL ROLE lor_preflight_app`; the query returned the unresolved `03a-Mega Cube-MC` Stage candidate. That proof transaction was rolled back and the privilege returned to false, proving no hidden state change.

Migration 0041 then granted execute permanently to `lor_preflight_app`. Validation 36 proved:

- `lor_preflight_app` can execute the governed-root resolver;
- `PUBLIC` remains revoked;
- the actual browser-facing Stage review succeeds under `SET LOCAL ROLE lor_preflight_app`;
- Run 18 remained open and unchanged with zero actions;
- PostgreSQL remained healthy.

Run 18 therefore resumes in place. No new parser, ingest, or reconciliation run is required.

## Operator Consequence During Folder Cleanup

When a governed Stage/Sub-stage folder is renamed or moved during Display Folders cleanup:

1. make the intended Google Drive folder correction;
2. update every current LOR Preview/Scene `BackgroundFile` reference that points into the old location;
3. verify LOR is using the corrected path;
4. run the normal parser and review the resulting SQLite/path evidence;
5. ingest the approved SQLite;
6. run normal reconciliation;
7. P1 will synchronize the existing Stage/Sub-stage `folder_path` when the frozen evidence resolves one matching governed root.

Do not expect the Production Database, FieldWiring, or Procedures to recursively search Google Drive for a folder that moved without corresponding current LOR/database path evidence.

## Application Boundary

Migrations 0039 and 0040 did not modify:

- FieldWiring code;
- Procedures code;
- the shared filesystem resolver;
- the parser;
- Google Drive folders;
- Scene classification; or
- the established Stage/Sub-stage/Scene/Display naming grammar.

Migration 0041 changes only the explicit database privilege needed by the existing LOR2DB Stage-review path.

FieldWiring and Procedures continue to consume current Production Database/LOR path context under their existing resolver contracts. Keeping `ref.stage.folder_path` synchronized reduces stale-anchor recovery and gives those applications a current persisted Stage/Sub-stage locator.

## Authoritative Implementation

- [`current_procedures/P1_stage_promotion.sql`](current_procedures/P1_stage_promotion.sql) — current P1 definition
- [`migrations/0039_repair_stage_folder_authority.sql`](migrations/0039_repair_stage_folder_authority.sql) — Stage root naming authority installation/repair
- [`validation/34_stage_folder_authority_validation.sql`](validation/34_stage_folder_authority_validation.sql) — migration 0039 validation
- [`migrations/0040_sync_existing_stage_folder_path.sql`](migrations/0040_sync_existing_stage_folder_path.sql) — existing Stage/Sub-stage path synchronization
- [`validation/35_stage_folder_path_sync_validation.sql`](validation/35_stage_folder_path_sync_validation.sql) — migration 0040 validation
- [`migrations/0041_grant_lor_preflight_governed_root.sql`](migrations/0041_grant_lor_preflight_governed_root.sql) — least-privilege LOR2DB resolver grant
- [`validation/36_lor_preflight_governed_root_grant_validation.sql`](validation/36_lor_preflight_governed_root_grant_validation.sql) — application-role grant validation

## Related Documents

- [LOR Reconciliation SQL](README.md)
- [Production Promotion Pipeline Design](../01_LOR_Production_Promotion_Pipeline_Design.md)
- [Google Drive Path Resolution Contract](../../../Docs/00_Project_Overview/Google_Drive/engineering/Google_Drive_Path_Resolution_Contract.md)
- [Repair or Organize an Existing Stage / Scene](../../../Docs/00_Project_Overview/Google_Drive/operatorSOP/Repair_Existing_Stage_Scene.md)
