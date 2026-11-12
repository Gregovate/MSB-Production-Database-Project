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
17. ✅ Audited the legacy lettered architecture series (`A`, `B`, `D`, `E`, `F`, `G`, `H`) and established dispositions below before any moves or archival changes.

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

LOR remains authoritative for show topology and wiring configuration. Controller assignments, channel numbers, DMX/network assignments, and LOR topology are defined and controlled in LOR and must not be independently defined or changed in PostgreSQL, FormView, or a future wiring application.

The existing operational/display workflow includes FormView, PostgreSQL wiring data derived from LOR snapshots, generated HTML/field documentation, and Draw.io wiring diagrams. FormView and any future PostgreSQL-backed wiring application are presentation and operational layers over the LOR-authoritative topology, with Production Database enrichment where appropriate.

Audit action: create or strengthen the subsystem engineering README/design placeholder without prematurely designing the replacement application. Preserve existing FormView and Draw.io source relationships, identify the authoritative implementation/data artifacts, and explicitly preserve the LOR ownership boundary.

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

## Current Directus Role

Directus remains an active production component, but its role is narrower than the original architecture envisioned.

Current design boundary:

- **PostgreSQL** owns authoritative production data, constraints, procedures, triggers, permanent identities, and database-enforced business rules.
- **Directus** provides a graphical presentation/editor for PostgreSQL collections, user/role administration, bookmarks/presets, selected operator interaction, and selected workflow automation through Directus Flows.
- **Dedicated applications** are appropriate for repetitive or task-focused workflows where Directus does not provide acceptable operator UX.

Known active Directus use includes Test Session records, testing records, container operations, Work Order triage/completion, Work Order assignment presentation, user onboarding, and workflow automation. Current active Flows observed during this audit include `Create Repair Work Order`, `User Onboarding`, `WOI Request Triage Email`, `Work Order Complete-Update ...`, and `Work Order Email Assignees`.

These Flows are production implementation components and require engineering documentation. They must not remain undocumented application configuration.

The old assumption that Directus would serve as the universal task-focused browser application is superseded by operational experience. This does not make Directus obsolete; it changes its documented system boundary.

## Legacy Lettered Architecture Series Audit

The loose lettered documents at the root of `Docs/02_Production_Database/01_System_Architecture/` predate the current subsystem-oriented documentation structure. They contain valuable engineering history but should not remain a parallel active organization system indefinitely.

No active `C_*` document was identified during this audit. The active series reviewed is `A`, `B`, `D`, `E`, `F`, `G`, and `H`.

### `A_System_Blueprint.md` — reconcile, then supersede as a loose root document

**Preserve:**

- Production Database purpose as the operational system of record for physical assets and operations;
- the boundary that **LOR remains authoritative for show topology and wiring**;
- permanent Production identities must not depend on LOR UUIDs;
- snapshot-based ingestion and separation between LOR source data and Production enrichment;
- high-level storage, testing, controller inventory, infrastructure, and operational goals;
- historical explanation of why the Production Database exists.

**Correct/reconcile:**

- the architecture flow that presents `Directus Application Layer` as the general application layer;
- stale implementation/status claims;
- old identity terminology such as `DisplayKey` where current `display_id`, reconciliation, and current naming contracts supersede it;
- obsolete phase/status descriptions and old V6/V7 transition assumptions;
- future subsystem descriptions now clarified by this audit.

**Destination:** useful 5,000-foot content should feed `Docs/00_Project_Overview/` and the current Production Database architecture portals. Once current owners contain the surviving contracts, archive the original blueprint as engineering history rather than leaving it as the active Start Here architecture.

### `B_Infrastructure.md` — reconcile with current server-management authority, then archive or narrow

**Preserve:**

- PostgreSQL must not be exposed directly to the public Internet;
- secure administrative/network boundaries;
- backup, restore-test, monitoring, and logging requirements;
- infrastructure requirements that remain true independent of a specific deployment snapshot.

**Reconcile:**

- ZeroTier/network assumptions;
- Docker/service-hosting assumptions;
- Cloudflare/DNS details;
- backup status and retention;
- old future `db.sheboyganlights.org` application assumptions;
- ingestion/storage terminology that predates the current LOR2DB architecture.

**Destination:** current server/deployment details belong with the authoritative server-management documentation rather than being duplicated here. Retain only Production Database infrastructure boundaries needed to understand this repository; archive the old deployment snapshot after reconciliation.

### `D_Database_Structure.md` — high-value source requiring controlled decomposition

This is the most important legacy architecture source and must not be archived until its current contracts have responsible homes.

**Preserve/reconcile carefully:**

- schema ownership boundaries (`lor_snap`, `ref`, `ops`, staging/development concepts);
- permanent `display_id` boundary and the rule that operational tables should not depend on LOR UUID identity;
- audit/actor attribution design that remains current;
- history-table principles;
- reference-versus-operational data ownership rules;
- testing, storage, Work Order, and other subsystem relationships that remain implemented.

**Known stale/mixed content:**

- historical implementation notes mixed with current design;
- older display identity terminology and transitional keying states;
- Directus-hook assumptions that require verification against current triggers/Flows;
- V6-era ingestion and old wiring representations;
- multiple subsystem designs accumulated into one monolithic document.

**Destination:** decompose current contracts into responsible subsystem engineering documents and database-wide standards. Preserve the original as historical architecture only after every surviving rule has an authoritative current owner.

### `E_Directus_DB_Dev.md` — obsolete Directus architecture model; mine before archival

**Preserve as evidence:**

- descriptions of the intended Container Testing, Display Testing, Work Order, and stage/container workflows;
- useful names/relationships for PostgreSQL tables and views that still exist;
- evidence of the original Directus implementation intent.

**Superseded:**

- Directus-specific `ops.v_*` views as the assumed universal UI architecture;
- the statement `No DB triggers. Directus Flow handles update.`;
- the assumption that Directus owns all repair completion behavior;
- old field/status names where current production differs.

**Destination:** verify any surviving database objects against PostgreSQL and document them with their responsible subsystems. Current Directus integration/Flow behavior should be documented separately. Archive this MVP architecture once current ownership is established.

### `F_Directus_UI_md` — historical UI vision; superseded

This document describes the intended task-focused Directus application experience rather than the UI that proved practical in production.

**Preserve as engineering history:**

- the original goals for Container Testing, Display Testing, Stage Browse, and Work Orders;
- evidence explaining why Directus was evaluated as a task-focused application layer.

**Superseded:**

- the proposed Container Focus screen model;
- assumed editable view/grid behavior;
- assumed Work Order navigation behavior;
- the general statement that the Directus UI is task-focused and minimizes clutter;
- the old MVP permissions/UI plan where it differs from current production.

**Destination:** archive after a current Directus engineering document records Directus's actual role, current collections/bookmarks, current Flows, and known UX limitations.

### `G_Work_Order_Design_Plan.md` — active engineering foundation; update and relocate after review

This is not merely historical. It contains foundational Work Order decisions that remain useful, including PostgreSQL as system of record, normalized assignees, stage/work-area location rules, urgency versus target-year separation, permanent `display_id` linkage, and testing/repair integration.

**Requires current-state review:**

- Google Form/Google Sheets intake status;
- triage workflow;
- assignment workflow and current assignee presentation;
- Directus Flow responsibilities;
- database trigger/procedure responsibilities;
- completion workflow and current failure points;
- notification behavior;
- current operator procedure and navigation limitations.

**Destination:** use as the engineering seed for the planned `07_Work_Orders/` subsystem. Update against actual implementation before moving/renaming it. Do not archive it as obsolete.

### `H_Asset_ID_Labeling_and_Scanning_Plan.md` — reconcile against implemented labeling/scanning systems

This planning document contains valuable standards such as stable asset identities, machine-readable payload concepts, barcode/QR distinctions, label quantities, print tracking, reprint concepts, scanner requirements, and future controller identification.

It also contains planning assumptions overtaken by implementation, including Directus Flow as the expected label-print orchestrator and old `db.sheboyganlights.org/scan/...` routing assumptions.

**Destination:** compare against the current LabelPrintService, current labeling/scanning standards, scanner/tablet integration, and forklift workflow documents. Move surviving standards to their responsible current documents and archive the superseded planning document once coverage is verified.

## Lettered-Series Migration Rule

Do not delete, move, or archive a lettered document merely because it is old.

For each document:

1. Identify every still-valid engineering contract.
2. Verify the contract against current implementation or the current authoritative source.
3. Place or confirm that contract in the responsible current subsystem/design document.
4. Update the responsible subsystem README handoff.
5. Only then move the superseded lettered source to the archive.
6. Repair parent portals and links as part of the same closeout.

The desired end state is a subsystem-oriented active architecture tree without a competing loose A–H series, while retaining useful engineering history in the archive.

## Planned Active Architecture Homes

Subject to the controlled migration rule above, the currently identified subsystem homes are:

- `01_Stored_Proceedures/` — shared/cross-system PostgreSQL procedures;
- `02_Triggers/` — shared/cross-system PostgreSQL trigger documentation;
- `03_Labeling_and_Scanning_Standards/`;
- `04_Controller_Inventory_and_Labeling/` — existing folder; review current scope/name before any rename;
- `05_Scanner_Hardware_and_Tablet_Integration/`;
- `06_Scan_Workflows_and_Forklift_Operations/`;
- `07_Work_Orders/` — planned current subsystem home;
- `08_Wiring_System/` — planned engineering handoff;
- `09_Network_Infrastructure/` — planned engineering handoff;
- `10_Site_Infrastructure_GIS/` — planned engineering handoff;
- `90_Project Hour Log/` — development history rather than subsystem architecture.

Existing `03` through `06` should receive README handoffs where missing before they are treated as completed subsystem portals.

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
