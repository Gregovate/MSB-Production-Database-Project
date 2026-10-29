# Checkpoint — LOR2DB 2-PC Preview Sync

| Field | Value |
|---|---|
| Date | 2026-10-27 |
| Issue | #299 |
| Draft PR | #300 |
| Branch | `agent/issue-299-lor2db-2pc-sync-phase1` |
| Branch head at checkpoint start | `8d367eaf4c33ca641ca5fcee7c37d3d6644dba84` |
| Production release status | **BLOCKED — updater authority model requires correction** |
| Shared deployment root | `G:\Shared drives\MSB Database\UserPreviewStaging\LOR2DB_2PC_Sync` |

## What is working

- Shared programmer-facing root was successfully migrated to the simplified production layout.
- Normal programmers now see only:
  - `Update your PC Previews to LOR Master Files`
  - `READ ME - Update your PC Previews.txt`
  - `MSB Preview Sync Support\`
- The updater resolves the source folder from the accepted LOR2DB reconciliation report rather than hard-coding `Database Previews V6.6.12`.
- The updater blocks rather than silently overwriting when source-integrity evidence disagrees.
- Existing MASTER -> LOCAL behavior has already proven:
  - unmanaged/personal previews can be preserved;
  - missing controlled PreviewIDs can be added;
  - substantive controlled differences can be replaced;
  - revision-only differences can remain NOOP;
  - post-sync comparison can be idempotent.
- New Show PC is a clean acceptance target: it has no controlled MSB preview set yet.

## Current blocking defect

The updater currently treats the historical file:

`_MSB_CONTROLLED_PREVIEW_MANIFEST.csv`

inside the versioned master folder as permanent content authority.

That is wrong for normal ongoing authoring.

The manifest was created from the accepted V6.6.12 source around Run 29. Later legitimate authoring changed the same controlled master folder. In particular:

- `Show Background Stage 00 HWY42 MSB-Rotary-Trees.lorprev` was intentionally changed after Run 29;
- the 8 HW-Flood lights/identities were part of later accepted LOR work;
- Run 31 already contained the newer lights according to operator history;
- fresh ingest 74 / reconciliation Run 32 completed on 2026-10-27;
- Run 32 final status: `COMPLETED`;
- Run 32 validation: `PASSED`;
- Run 32 source folder: `G:\Shared drives\MSB Database\Database Previews V6.6.12`;
- Run 32 lists Rotary-Trees at Revision 57.

Despite that accepted newer reconciliation, the updater still blocks with:

```text
Master identity/content differs from the controlled manifest:
Show Background Stage 00 HWY42 MSB-Rotary-Trees.lorprev
```

Therefore the stale folder manifest is incorrectly overriding newer accepted LOR2DB evidence.

## Required authority model

The production updater must use the **latest accepted COMPLETED LOR2DB source state** as authority.

Required chain:

```text
latest accepted COMPLETED LOR2DB source evidence
        -> exact accepted versioned source folder
        -> accepted per-preview identity/content evidence for that run/state
        -> validate current folder against that accepted evidence
        -> MASTER -> LOCAL sync
```

A historical manifest created during an earlier run must never permanently freeze the contents of a versioned master folder.

### The controlled manifest may be used only if

- it is versioned/identified as belonging to the same currently accepted source state; and
- its content fingerprint is tied to that accepted run/current-source identity.

Otherwise it is historical evidence only.

## Long-term dependency on #81

#81 owns the LOR2DB accepted/current-source contract.

The desired durable resource remains a stable machine-readable current-source publication that advances only after successful reconciliation completion and includes enough evidence for #299 to validate the source, including:

- accepted reconciliation/import identity;
- LOR version;
- exact source preview folder;
- preview count;
- immutable report reference;
- per-preview filename;
- PreviewID;
- Revision as evidence only;
- source/content hash or substantive fingerprint.

The programmer updater must consume that moving accepted-source authority instead of a manually copied historical report or stale folder manifest.

## Immediate development requirement

Fix the updater before any Show-PC apply.

Do **not**:
- bypass the content-integrity block;
- delete the manifest merely to make the update run;
- regenerate the manifest ad hoc from whatever happens to be in the folder;
- hard-code Run 32;
- hard-code V6.6.12;
- update Adam's Show PC until the authority fix is accepted.

Implement the updater so a newly COMPLETED reconciliation such as Run 32 automatically supersedes older accepted source evidence and does not require hand-maintaining a stale manifest.

## Show-PC release gate after the fix

Once the source-authority correction is committed/deployed:

1. Close LOR on the new Show PC.
2. Run the single root shortcut.
3. Verify it resolves the latest accepted LOR2DB source.
4. Expected first-run shape for the clean Show PC:
   - controlled previews: 34;
   - ADD: approximately 34;
   - REPLACE: 0;
   - unrelated/default/imported/store previews preserved.
5. Apply only after review.
6. Reopen LOR and confirm the controlled set is usable.
7. Close LOR and rerun.
8. Require idempotent result: ADD 0 / REPLACE 0.
9. Record backup, logs, accepted-source identity and final release commit.
10. Only then mark the first production release accepted.

## Resume point

Start by changing the updater's source-integrity logic so the **latest accepted LOR2DB source state supersedes older folder-manifest authority** while preserving fail-closed behavior.

Do not spend more time on shortcut/folder UX until this source-authority defect is corrected.
