# Repository Documentation Audit

| Document Control | Value |
|---|---|
| Status | ACTIVE — Documentation Review Worklist |
| Scope | Repository-wide documentation structure, engineering continuity, and navigation |
| Review baseline | 2026-08-08 |
| Owner | MSB Database Administrator |

## Purpose

This document preserves the current repository documentation audit so the remaining cleanup and engineering-documentation work is not lost between editing sessions.

The audit is based on the MSB documentation standards under `System_Documentation/Standards/`. It is a worklist, not a replacement for subsystem documentation.

The audit also preserves the 5,000-foot design intent of the Production Database project: PostgreSQL is becoming the durable identity, relationship, history, and operational integration layer across production information that has historically lived in separate applications, drawings, spreadsheets, files, specialized test equipment, and field datasets. The database should integrate those systems around permanent MSB identities without unnecessarily replacing specialized tools that remain useful for authoring, testing, surveying, or visualization.

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
11. ⏳ Complete Production Database subsystem engineering coverage and handoff documentation as described below.
12. ⏳ Regenerate `RepositoryTree.txt` after the current documentation cleanup; the committed tree can become stale as soon as files are added or moved.
13. ✅ Repaired the repository root `readme.md` against the current folder layout. A broader root-portal redesign may still follow the Project Overview review.
14. ↗ Pass 3 moved to the separate `MSB-Internal-Web-Backbone` investigation. The separately published production `index.html` files, live-server source/deployment relationship, backup coverage, and cross-repository web navigation should be resolved there rather than mixed into this repository audit.
15. ✅ Expanded `System_Documentation/Standards/README_Portal_Standard.md` and `Prompt_Guidelines.md` so active subsystem READMEs are mandatory engineering handoffs and material work includes a README closeout review.
16. ⏳ Expand the 5,000-foot Project Overview after the subsystem audit has preserved the current source systems and design intent below.

## Production Database Subsystem Coverage

The following systems belong conceptually under the PostgreSQL Production Database architecture. They are at different maturity levels and should not be documented as though they are equally implemented.

### Work Orders — implemented and actively evolving

Existing engineering and operator documentation must be reviewed against the current implementation rather than replaced from memory.

Known current scope includes:

- Google Form intake;
- triage workflows;
- assignment and notification workflows;
- assignee visibility improvements;
- generated Work Order link data and the current Directus limitation using that link to navigate back to the Work Order;
- operator completion workflow;
- relationships to display testing/repair and future relationships to other physical infrastructure.

Audit action: bring the existing engineering design and operator SOP through the current documentation standards, then leave the responsible README as the current development handoff.

### Wiring System — legacy/current engineering system awaiting stronger PostgreSQL integration

The existing workflow includes FormView, database wiring fields, generated HTML/field documentation, and Draw.io wiring diagrams. FormView remains useful but is tied to legacy assumptions and is likely to be replaced by a dedicated task-focused application using PostgreSQL as the authoritative data source.

Audit action: create or strengthen the subsystem engineering README/design placeholder without prematurely designing the replacement application. Preserve existing FormView and Draw.io source relationships and identify the authoritative implementation/data artifacts.

### Network Infrastructure — existing engineering system distributed across specialized tools

This is not merely a future idea. Existing engineering information is distributed across:

- Draw.io network schematics containing structured cable/topology attributes;
- CableIQ qualification/testing data and exports;
- GPS waypoint identities shared with the physical site model;
- historical network layout information.

Cable test history must be treated as history rather than overwritten by the latest result. Draw.io may remain an engineering visualization tool while PostgreSQL becomes the durable identity/relationship/history layer.

Audit action: create an engineering README/design placeholder that preserves these source artifacts, their relationships, and the future integration intent before database schema development begins.

### Controller Inventory — current spreadsheet source, PostgreSQL subsystem not yet built

Controller inventory currently exists outside PostgreSQL and tracks multiple controller types, network relationships, and other controller information. LOR snapshots identify controllers used by previews, but that is not a complete controller inventory system.

Audit action: create an engineering README/design placeholder identifying the current spreadsheet as an authoritative source artifact, the need for permanent controller identity, relationships to Wiring and Network Infrastructure, deployment/location requirements, and unresolved schema work.

### Site Infrastructure / GIS — planned database integration with substantial historical source data

Existing field/site data includes historical GPX data going back to at least 2015, GPS waypoints and tracks, receptacles, network tracks, power tracks, display/location information, utility meters, distribution panels, circuits, and seasonal energization requirements.

Field collection uses a Garmin GPSMAP 66sr. ExpertGPS and county 3-inch aerial imagery are used for validation/refinement. The working coordinate reference is `NAD83 HARN WISCRS Sheboygan County Feet (USft)`.

Existing display information in the GIS/GPS material does not consistently use the Production Database permanent `display_id`; future integration must correct that identity boundary rather than create another competing display identity.

Audit action: create an engineering README/design placeholder preserving the source systems, coordinate-system contract, historical-data importance, permanent-identity requirement, and relationships to receptacles, power distribution, Network Infrastructure, Controller Inventory, Wiring, and Work Orders. Do not design the GIS database schema during this documentation audit.

## Engineering Continuity Requirement

The subsystem READMEs above are intended to become durable development handoffs. Each should identify current state, design intent, authoritative artifacts, ownership boundaries, related systems, known limitations/open work, and a subsystem-specific resume-development prompt or link when needed.

The subsystem prompt supplements the generic project working contract in `System_Documentation/Standards/Prompt_Guidelines.md`; it must not duplicate that generic contract.

At the end of material subsystem work, update the responsible detailed documents first and then review/update the subsystem README as the final handoff step. The next work session should be able to resume from repository documentation without reconstructing settled architecture from conversation history.

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

### Pass 3 — MSB Internal Web Backbone

Moved to the separate MSB Internal Web Backbone investigation because the published `my.sheboyganlights.org` pages live on a different server and are owned by a separate repository. That review must establish source control, deployment, backup coverage, and cross-repository link validation before web navigation automation is designed.

## Standards and Automation Alignment

The link-cleanup process is documented in:

- `System_Documentation/Standards/Linking_and_Navigation_Standard.md`;
- `System_Documentation/Automation/README.md`.

Engineering continuity and reusable project/subsystem prompts are documented in:

- `System_Documentation/Standards/README_Portal_Standard.md`;
- `System_Documentation/Standards/Prompt_Guidelines.md`.

The future `verify_links.py` implementation should reproduce the documented link checks programmatically and report failures before attempting automatic changes. It should also detect malformed GitHub file/folder URL patterns where practical, including missing branch/ref segments after `/blob/` or `/tree/`.

## Review Rule

Do not change folder structure merely to satisfy this worklist. Review each current file and subsystem before moving or renaming anything. Preserve working technical documents and historical evidence; update portals and links around the authoritative material whenever practical.
