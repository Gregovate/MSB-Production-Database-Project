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
6. ✅ Repaired stale paths and navigation in the main current portals, including `LOR2DB/README.md`, `LOR2DB/03_Reporting/README.md`, `LOR/README.md`, `Database/README.md`, the repository root portal, and the current Project Overview.
7. ✅ Refactored `Docs/README.md` to primarily link to immediate child portals rather than deep documents.
8. ✅ Completed `System_Documentation/README.md`, `System_Documentation/Standards/README.md`, and `System_Documentation/Automation/README.md` portals.
9. ✅ Added `Utilities/README.md` describing the purpose and ownership rule for cross-system utilities.
10. ✅ Reviewed `Docs/01_LOR_System/01_Preview_Authoring/preview_merger_reference.md`. Relevant engineering and operator content is preserved in the current Preview Merger architecture/procedure; the superseded reference was moved to `archive/docs/preview_merger_reference.md` and removed from active Preview Authoring.
11. ⏳ Document known Production Database engineering gaps, especially the Wiring System, and review whether Work Orders and Controller Inventory need stronger subsystem-level engineering documentation.
12. ⏳ Regenerate `RepositoryTree.txt` after the current documentation cleanup; the committed tree can become stale as soon as files are added or moved.
13. ✅ Repaired the repository root `readme.md` against the current folder layout. A broader root-portal redesign may still follow the Project Overview review.
14. ⏳ Review the two separately published production `index.html` navigation files. Do not redesign or automate them until their audience, ownership, and navigation model are agreed upon.

## Additional README Portals Completed During Review

The repository-wide README verification found two existing documentation destinations that were not listed in the first audit pass. These have also been completed without changing the folder structure:

- ✅ `Docs/00_Project_Overview/README.md` — 5,000-foot project overview portal.
- ✅ `Docs/01_LOR_System/01_Preview_Authoring/README.md` — volunteer-facing preview authoring portal.

`Docs/0_Contributing/README.md` was verified and already contained a complete contributor-training portal, so it was left unchanged.

## Link Cleanup Status

### Pass 1 — Known Moved Paths

Completed for the current navigation layer. The main current portals and Project Overview were repaired for the approved path changes, including:

- `LOR/ingest/` → `LOR2DB/01_Ingest/`;
- `LOR2DB/Reconciliation/` → `LOR2DB/02_Reconciliation/`;
- `LOR2DB/Reporting/` → `LOR2DB/03_Reporting/`;
- `Docs/01_LOR_System/00_Project_Overview/` → `Docs/00_Project_Overview/`;
- `https://lortodb.sheboyganlights.org/lor2db/` → `https://my.sheboyganlights.org/lor2db/` where the reference is current access guidance.

Historical/archive material may retain original paths as evidence when clearly noncurrent.

### Pass 2 — README Portal Verification

Completed for the current portal layer created or reviewed during this audit. Parent portals now link to child `README.md` files where those portals exist, and the primary LOR, LOR2DB, Database, Project Overview, Production Database, and System Documentation navigation chains were checked against the current repository layout.

The separately published production `index.html` files are intentionally excluded from Pass 1 and Pass 2. They require a separate design review before changes or automation rules are approved.

## Standards and Automation Alignment

The link-cleanup process is now documented in:

- `System_Documentation/Standards/Linking_and_Navigation_Standard.md`;
- `System_Documentation/Automation/README.md`.

The future `verify_links.py` implementation should reproduce these checks programmatically and report failures before attempting automatic changes.

## Review Rule

Do not change folder structure merely to satisfy this worklist. Review each current file and subsystem before moving or renaming anything. Preserve working technical documents and historical evidence; update portals and links around the authoritative material whenever practical.
