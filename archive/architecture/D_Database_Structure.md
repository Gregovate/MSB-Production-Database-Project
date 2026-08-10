# Archived — D Database Structure

**Archive Status:** Historical engineering evidence  
**Original active path:** `Docs/02_Production_Database/01_System_Architecture/D_Database_Structure.md`  
**Original blob SHA before archival:** `fa8eaf106619eb3b1b24089958c5e2b6a6e92738`  
**Reconciled:** 2026-08-09

The former `D_Database_Structure.md` was a working architecture/design document created during the February–March 2026 database build. It mixed implemented contracts, transitional implementation notes, planned tables, old Work Order design, V6-era LOR snapshot details, and later audit notes.

The complete original remains preserved in Git history under the blob SHA above. It was removed from the active architecture tree only after a section-by-section review reconciled its still-valid responsibilities into the current numbered subsystem documentation.

## Current Owners Established During Reconciliation

- Shared PostgreSQL schema boundaries, audit rules, history/lifecycle rules, canonical functions/procedures/triggers, and schema-snapshot verification belong to `01_Database_Foundation`.
- Current LOR parser, snapshot, ingest, scene, reconciliation, promotion, validation, and reporting detail belongs to LOR2DB/V7 documentation. The old Section 5 table-by-table model is superseded.
- `ref.person`, authentication linkage, Directus onboarding, and actor resolution belong to `03_People_and_Identity`.
- Containers, storage locations, current display/container relationships, KIT container identity, and storage limitations belong to `04_Containers_and_Storage`.
- Current annual/container testing and RECYCLED cleanup behavior belongs to `05_Testing_System` with canonical PostgreSQL object documentation under Database Foundation.
- Current Work Order implementation belongs to `06_Work_Orders`; the old `ref.work_priority`, `ref.work_task_type`, skill-based assignment, notification-outbox, and old Work Order table model are superseded by the current schema/workflow.
- QR-linked asset lookup and label/scan behavior belong to `07_Labeling_and_Scanning`; a generic database document registry is not a standalone goal.
- Physical controller inventory belongs to `08_Controller_Inventory`; LOR remains authoritative for controller/channel/network/DMX assignments and show topology.
- LOR-derived wiring presentation and the shared Stage-folder path convention belong to `09_Wiring_System`.
- Setup/Takedown instructions and future setup/deployment workflow engineering belong to `12_Setup_and_Deployment`.

## Important Decisions Preserved

### Display identity and lifecycle

`ref.display.display_id` is the durable PostgreSQL identity used by operational relationships. LOR identifiers are source/matching context and are not the PostgreSQL operational primary identity.

Current display lifecycle meanings are:

- **ACTIVE** — currently in service and deployable.
- **RETIRED** — the physical display still exists but is no longer part of the current show/use.
- **RECYCLED** — the original display no longer exists as a display; reusable components such as frames, lights, or hardware may have been reused elsewhere.

`ARCHIVED` is not a current display lifecycle status.

The current implementation conservatively retains `ref.display` after RECYCLED because existing foreign-key relationships make deletion unsafe. A future historical-display model could allow recycled current-inventory rows to be removed, but no such engineering change was made during this documentation audit.

### History rule

History tables are purposeful, not automatic. Current state stays on the owning record unless a workflow genuinely needs a reconstructable event/history trail. Standard audit fields provide normal accountability.

Generic container movement history and full display-to-container assignment history are not requirements. Operational history should be added only when the real workflow requires it.

### Containers and KITs

A KIT is an existing container type. It is a physical container holding loose setup materials rather than Displays, such as cords, plugs, string lights, bull line, stakes, hardware, or other setup supplies. Detailed kit-contents inventory is a useful future need but was not engineered during this audit.

### Season

`ref.season` remains a current annual operational reference. The working annual cycle is approximately January testing, late-September setup/show preparation, January 1 takedown, then the next testing cycle.

### Stage folders, Wiring, Setup, and QR lookup

The Stage-oriented folder structure already exists. Wiring and Setup/Takedown documentation use the same Stage `folder_path` convention. Setup instructions are being organized in that existing structure.

Display-linked documents/information are intended to be reached through QR-based field lookup. The database is not intended to become a generic document-management repository; each subsystem remains authoritative for its own content.

## Obsolete / Unimplemented Design Material

The following concepts in the original D document were confirmed as obsolete, unimplemented, or superseded and should not be treated as current schema authority:

- `ref.maintenance_result`
- `ref.light_technology` as the old proposed lookup-table design
- `ref.inventory_category` as the old proposed lookup-table design
- `ref.work_priority`
- `ref.work_task_type`
- `ref.skill`
- `ref.skill_level`
- old `ref.user` / `ref.role` / `ref.user_role` / `ref.user_skill` identity design
- old V6/V7-transition snapshot table descriptions in Section 5
- `ops.display_reconciliation` / `ops.display_alias` old reconciliation model
- old pallet-assignment and generic container-location-history model
- `ops.maintenance_record`
- standalone `ops.kit` / `ops.inventory_item` / `ops.kit_item` design as written
- generic `ops.document` / `ops.display_document_link` document-registry concept
- old `ops.controller` design as a replacement for LOR topology authority
- old Work Order module schema in Section 6A
- old seasonal testing/status tables in Section 8
- old label-print-job design
- old March 2026 automation state descriptions where current Testing/Work Order implementation now provides the authority

## Historical Value

The original D document remains important evidence of how the Production Database evolved from the early LOR/V6, pallet, maintenance, and Directus concepts into the current subsystem architecture. Use it for project-history reconstruction only. For current engineering, use the numbered subsystem READMEs, current implementation documentation, the newest schema snapshot, and the live system where applicable.
