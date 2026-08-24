# Documentation Subsystem Conversion Tracker

| Document Control | Value |
|---|---|
| Document Type | Project Migration Tracker |
| Repository | MSB Production Database Project |
| Status | CURRENT |
| Owner | Production documentation owner / administrator |
| Last Reviewed | 2026-08-24 |

## Purpose

Track the repository-wide migration from mixed/legacy documentation layouts to subsystem-owned operator, engineering, image, and Internal Web Backbone integration structure.

This tracker is the durable record of where the migration stands. Do not rely on conversation history to remember which subsystem has been converted.

## Status Values

- `LEGACY` — current documentation has not been converted to the subsystem pattern.
- `IN PROGRESS` — conversion has started but one or more closeout requirements remain.
- `CONVERTED` — source-repository documentation layout, authorities, links, and images are reconciled.
- `BACKBONE PENDING` — source conversion is complete but intranet work remains.
- `VERIFIED` — source conversion and deployed intranet integration are both verified.

## Conversion Closeout Requirements

A subsystem is not `CONVERTED` until all applicable items are complete:

- [ ] root `README.md` is the operator/user portal when the subsystem has an operator audience;
- [ ] `operatorSOP/README.md` indexes current operator procedures owned by the subsystem;
- [ ] operator procedures are task-oriented and current;
- [ ] `engineering/README.md` is the engineering handoff/current-state portal;
- [ ] current engineering authorities are under `engineering/` or deliberately referenced with a documented migration reason;
- [ ] old current-authority paths are converted to compatibility pointers when needed;
- [ ] current inbound links have been repaired or deliberately protected by compatibility pointers;
- [ ] every image reference in converted docs has been inventoried;
- [ ] subsystem-owned images are under `<Subsystem>/images/` and current document links are updated;
- [ ] no shared image is deleted before all current consumers are identified;
- [ ] `engineering/Internal_Web_Backbone_Handoff.md` exists when intranet discovery is affected;
- [ ] Backbone integration issue/work item exists;
- [ ] Backbone state is recorded as `PENDING`, `IMPLEMENTED`, or `VERIFIED`;
- [ ] current portals and Related Documents point to the canonical locations;
- [ ] no engineering/history documents appear in normal operator task-selection navigation.

## Current Migration

| Subsystem / Area | Source Status | Images Audit | Backbone Handoff | Backbone State | Notes |
|---|---|---|---|---|---|
| Google Drive / Display Folder Operations | IN PROGRESS | COMPLETE — no embedded Markdown images found in the current engineering overview, path contract, or converted operator procedures; subsystem `images/` established | EXISTS | PENDING — Backbone issue #2 | Operator portal/SOP split complete. Engineering overview and path contract physically relocated under `engineering/`; old paths are compatibility pointers. Major current portal links repaired. Final validation of relative links inside relocated engineering authorities remains. |
| Folder Alignment | IN PROGRESS | COMPLETE — no embedded Markdown images found in the current engineering design or converted operator procedures; subsystem `images/` established | EXISTS | PENDING — Backbone issue #2 | Operator portal, run/review SOPs, engineering portal complete. Engineering design physically relocated under `engineering/`; old path is compatibility pointer. Final validation of relative links inside relocated engineering authority remains. |

## Active Backbone Work

- `Gregovate/MSB-Internal-Web-Backbone` issue **#2** — `Integrate converted Google Drive and Folder Alignment operator portals`

Source conversion and live intranet deployment are separate milestones. Do not mark these subsystems `VERIFIED` until the deployed Backbone result is checked.

## Planned After Proof Is Accepted

The sequence below is not a commitment to convert everything at once. Convert one subsystem at a time and update this tracker after each reviewed migration.

| Subsystem / Area | Status | Notes |
|---|---|---|
| Preview Authoring | LEGACY | Contains current operator procedures including wiring-diagram creation; image ownership must be inventoried before moving docs. |
| Field Wiring | LEGACY | Current engineering documentation under Production Database architecture; operator experience is primarily the production application. |
| Setup / Takedown / Procedure | LEGACY | Current engineering/handoff history is mixed under Setup/Deployment architecture; field Stage instructions are a separate document class. |
| Labeling and Scanning | LEGACY | Cross-system operator and engineering ownership requires review before conversion. |
| Testing / Repairs | LEGACY | Existing central Operational SOP structure remains valid until this subsystem is deliberately reviewed. |
| Containers | LEGACY | Existing operator SOPs remain in current location until subsystem ownership/navigation review. |
| Displays | LEGACY | Existing operator SOPs remain in current location until subsystem ownership/navigation review. |
| Work Orders | LEGACY | Existing operator SOPs remain in current location until subsystem ownership/navigation review. |
| LOR2DB / Reconciliation | LEGACY | Separate application/repository-root structure; conversion requires careful current portal and reporting review. |
| FormView | LEGACY | Maintained fallback/reference; do not reorganize casually while still operationally relevant. |
| Parser / Data Extraction | LEGACY | Folder Alignment is being separated first; parser documentation requires its own later review. |
| Project Overview | STANDALONE | Remains a project overview/navigation area. Do not force operator/engineering split unless it later owns tasks/engineering work that justify the structure. |
| Contributing | STANDALONE | Contributor guidance area; review separately rather than mechanically applying subsystem layout. |

## Image-Migration Principle

The existing global `Docs/images/` folder contains assets from multiple systems. It must not become the default destination for future documentation images.

When each subsystem is converted:

1. identify which current documents reference images;
2. determine the owning subsystem for each referenced asset;
3. move the asset into that subsystem's `images/` folder;
4. update current links;
5. verify rendered references; and
6. leave unrelated global images untouched until their owning subsystem is converted.

This prevents a risky bulk image move before ownership is understood.

## Internal Web Backbone Principle

Every converted operator-facing subsystem must tell `Gregovate/MSB-Internal-Web-Backbone` what changed.

The handoff is owned by the source subsystem and must describe:

- canonical operator portal;
- task-oriented navigation/search terms;
- live application entry points;
- engineering exclusions;
- compatibility paths that should not become new intranet dependencies;
- image-path implications where relevant; and
- deployment acceptance criteria.

The conversion is only `VERIFIED` after the corresponding live `my.sheboyganlights.org` navigation/search behavior is checked.

## Related Rule

- [Production Operational Documentation Rule](Operational_Documentation_Rule.md)
