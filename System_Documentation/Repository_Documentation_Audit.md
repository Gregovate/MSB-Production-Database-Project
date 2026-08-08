# Repository Documentation Audit

| Document Control | Value |
|---|---|
| Status | ACTIVE — Documentation Review Worklist |
| Scope | Repository-wide documentation structure and navigation |
| Review baseline | 2026-08-08 |
| Owner | MSB Database Administrator |

## Purpose

This document preserves the current repository documentation audit so the remaining cleanup work is not lost between editing sessions.

The audit is based on the MSB documentation standards under `System_Documentation/Standards/`. It is a worklist, not a replacement for subsystem documentation.

## Current Findings

1. ✅ Created `Docs/01_LOR_System/README.md` as the LOR documentation portal.
2. ✅ Created `Docs/02_Production_Database/README.md` as the Production Database documentation portal.
3. ✅ Created `Docs/02_Production_Database/01_System_Architecture/README.md` as the engineering architecture portal.
4. ✅ Created `Docs/02_Production_Database/02_Operational_SOPs/README.md` as the operator-procedure portal.
5. ✅ Created `LOR2DB/01_Ingest/README.md` as the ingest implementation/operation portal.
6. ⏳ Update stale paths and navigation in `LOR2DB/README.md`, `LOR2DB/03_Reporting/README.md`, `LOR/README.md`, and `Database/README.md`.
7. ⏳ Refactor `Docs/README.md` to primarily link to immediate child portals rather than deep documents.
8. ✅ Completed `System_Documentation/README.md`, `System_Documentation/Standards/README.md`, and `System_Documentation/Automation/README.md` portals.
9. ✅ Added `Utilities/README.md` describing the purpose and ownership rule for cross-system utilities.
10. ⏳ Review the remaining `Docs/01_LOR_System/01_Preview_Authoring/preview_merger_reference.md` now that Preview Merger has its own `03_Preview_Merger` documentation area.
11. ⏳ Document known Production Database engineering gaps, especially the Wiring System, and review whether Work Orders and Controller Inventory need stronger subsystem-level engineering documentation.
12. ⏳ Regenerate `RepositoryTree.txt` after the current documentation cleanup; the committed tree can become stale as soon as files are added or moved.
13. ⏳ Rebuild the repository root `readme.md` only after the middle-layer portals and stale links are corrected.

## Additional README Portals Completed During Review

The repository-wide README verification found two existing documentation destinations that were not listed in the first audit pass. These have also been completed without changing the folder structure:

- ✅ `Docs/00_Project_Overview/README.md` — 5,000-foot project overview portal.
- ✅ `Docs/01_LOR_System/01_Preview_Authoring/README.md` — volunteer-facing preview authoring portal.

`Docs/0_Contributing/README.md` was verified and already contained a complete contributor-training portal, so it was left unchanged.

## Additional Stale Navigation Found

The current root and subsystem documentation still contain paths from the previous repository layout, including references to:

- `LOR/ingest/` instead of `LOR2DB/01_Ingest/`;
- `LOR2DB/Reconciliation/` instead of `LOR2DB/02_Reconciliation/`;
- `LOR2DB/Reporting/` instead of `LOR2DB/03_Reporting/`;
- the former `Docs/01_LOR_System/00_Project_Overview/` location after `00_Project_Overview` moved to the top level under `Docs/`.

These should be corrected as part of the repository-wide link cleanup rather than repaired ad hoc.

## Review Rule

Do not change folder structure merely to satisfy this worklist. Review each current file and subsystem before moving or renaming anything. Preserve working technical documents and historical evidence; update portals and links around the authoritative material whenever practical.
