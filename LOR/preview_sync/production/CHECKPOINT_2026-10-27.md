# #299 LOR Preview Sync Production Development Checkpoint

**Date:** 2026-10-27  
**Branch:** `release/299-lor-preview-sync-v1.0.0`  
**Base main:** `43077980051ab40005ce66ecfd38ef38c6fdad35`  
**Status:** DEVELOPMENT CHECKPOINT — NOT PRODUCTION ACCEPTED

## Why this checkpoint exists

The prior development process generated too many successive ZIPs and manual overwrites in the shared Google Drive deployment. From this checkpoint forward, the repository branch is the engineering source of truth.

## Production-folder state

The controlled production-layout migration has **PASSED** on:

```text
G:\Shared drives\MSB Database\UserPreviewStaging\LOR2DB_2PC_Sync
```

Programmers now see only:

```text
Update your PC Previews to LOR Master Files
READ ME - Update your PC Previews.txt
MSB Preview Sync Support\
```

The migration itself did not modify any PC's local LOR preview library.

## Current LOR2DB accepted source

A fresh production parser/ingest/reconciliation was completed on 2026-10-27.

Accepted evidence:

- reconciliation Run: **32**
- captured ingest: **74**
- final status: **COMPLETED**
- validation: **PASSED**
- source folder:
  `G:\Shared drives\MSB Database\Database Previews V6.6.12`
- previews: **34**
- scenes: **91**
- props: **1176**
- subprops: **1346**
- DMX: **514**
- scene/prop rows: **2268**
- `Show Background Stage 00 HWY42 MSB-Rotary-Trees.lorprev`: **Revision 57**

Run 32 requires zero operator decisions and zero Production changes.

## Defect exposed on new Show PC

The deployed updater still blocks on:

```text
Master identity/content differs from the controlled manifest:
Show Background Stage 00 HWY42 MSB-Rotary-Trees.lorprev
```

That block is caused by a **design flaw in the updater**:

- it treats the extraction-era `_MSB_CONTROLLED_PREVIEW_MANIFEST.csv` as permanent authority;
- normal authoring legitimately changes files inside the same approved LOR version folder;
- later completed LOR2DB runs accept those changes;
- therefore the static CSV can become stale even when LOR2DB has accepted newer source content.

This must not be bypassed or fixed by manually rewriting the CSV.

## Correct production authority model

The production updater must use:

```text
latest published COMPLETED LOR2DB reconciliation
        -> frozen source folder + frozen preview inventory for that run
        -> validate live source folder against that accepted run
        -> MASTER -> LOCAL sync
```

The updater must **not** use a copied historical report as a permanent pointer and must **not** use the static extraction CSV as permanent source authority.

### Long-term integrity contract

The parser already records `source_manifest_sha256`, defined as SHA-256 over the ordered list of:

```text
{ filename, sha256(file bytes) }
```

The preferred durable contract is:

1. LOR2DB exposes/publishes the accepted run's `source_manifest_sha256`;
2. the PC updater recomputes the same digest from the live versioned source folder;
3. exact digest match is required before sync;
4. later COMPLETED runs supersede earlier accepted runs automatically;
5. edits made after the latest completed run block until another completed reconciliation establishes them.

## Current v1.0.0 work in this branch

Current WIP source:

```text
LOR/preview_sync/production/Update_MSB_Previews.ps1
```

Direction already incorporated in the WIP source:

- production updater architecture rather than test ZIP workflow;
- keep safe local-library merge semantics;
- preserve unmanaged/personal previews;
- backup before install;
- explicit overwrite acknowledgement;
- single-instance protection;
- local/candidate hash rechecks before install;
- remove permanent static-manifest authority.

## Next development steps

1. Finish authoritative latest-COMPLETED report discovery from the published LOR2DB report archive.
2. Complete source-integrity verification against accepted Run evidence.
3. Add/publish `source_manifest_sha256` to immutable reconciliation report/current-source contract under #81.
4. Make updater consume that accepted hash when available.
5. Disposable-test:
   - later completed run supersedes earlier run;
   - post-run source edit blocks;
   - stale extraction CSV cannot veto a later completed run;
   - unmanaged previews preserved;
   - add/replace/revision-only semantics unchanged;
   - local file changed during review blocks;
   - candidate changed during review blocks.
6. Deploy exact committed candidate into `MSB Preview Sync Support\`.
7. New Show PC acceptance:
   - first run expected approximately ADD 34 / REPLACE 0;
   - apply;
   - reopen LOR and verify;
   - close LOR and rerun;
   - require ADD 0 / REPLACE 0.
8. Only then stamp the first production release.

## Do not do

- Do not manually regenerate the static controlled-manifest CSV as a workaround.
- Do not copy Run 32 manually into the support folder as the permanent fix.
- Do not bypass the source-integrity block.
- Do not let programmers select version folders.
- Do not resume ZIP-overwrite development outside the repo.

