# Site Infrastructure / GIS — Engineering References

This is the technical entry point for the maintained GIS/source/icon subsystem. **Engineering documents set system contracts and acceptance gates; pull requests must implement those contracts.** A README is a handoff and navigation page, not a substitute for engineering authority.

**Immediate October 19 field priority:** [#428 — capture visible park paint marks before they disappear](https://github.com/Gregovate/MSB-Production-Database-Project/issues/428), governed by the [GIS Manager Desktop Application Design](MSB_GIS_Manager_Desktop_Application_Design.md#october-19-field-first-priority--capture-current-ground-paint-before-it-disappears-171). Capture named/photo/landmark-offset evidence now; full #319 PostGIS migration and #378 Windows installer are not prerequisites to evidence preservation. No field capture or Production map deployment is claimed by this documentation-only handoff.

## Current Engineering Authority

- [GIS Symbol Management — CURRENT icon source, publication, access and consumer contract](GIS_Symbol_Management.md) — definitive roles of `Masters`, `Plain`, canonical PNGs, web SVGs, ExpertGPS, current accepted release, security rules, map symbol sizing/fallback and open acceptance.
- [MSB GIS Manager — Windows Desktop Application Design (DRAFT)](MSB_GIS_Manager_Desktop_Application_Design.md) — dedicated engineering specification for ordinary-user installer, G: source cutover, Show PC profile safety, current repair-track recording work queue, duplicate prevention and governed GIS review.
- [Network Source Reconciliation](Network_Source_Reconciliation_2026-10-09.md) — source discovery and historical network reconciliation evidence; review against current #171/#230 controlled source requirements before applying old conclusions.

## Current Handoff — October 19, 2026

**Priority and documentation recovery:** The approved October 14 physical G: Symbol Library rename preserved 823/823 files, but not all runtime consumers or Show PC installations have been accepted. #171's October 15 field recordings and master GPX are only partially reconciled, with manually applied edits that must not be duplicated. See the **draft dedicated desktop design above** for current fast-lane track correction, installer and Show PC acceptance gates. The existing #378 and #319 implementations remain unaccepted and must be reconciled with current main before further code changes. The permanent PostGIS reference editor and repeated GPX/FLW ingestion remain governed separately.

### Prior accepted publication checkpoint — October 12, 2026

The approved Plain SVGs were administrator-published to Synology: **37 source entries SHA-256 verified** (12 new / 3 updated / 21 unchanged / 1 existing-case alias retained). The separate web PNG compatibility action remains blocked, and browser HTTPS/image and rugged Android offline map acceptance remain pending. The local ExpertGPS PNG files match the reviewed source hashes; Garmin is not implemented.

Ongoing #171/#230 work under #122 is integrated in **draft PR #319**. Its current GIS/GPX/FLW/PostGIS contracts belong in the existing controlled source synchronization engineering document on that work branch, not in this portal or in the PR body. The governing design is one maintained PostGIS reference authority with distinct Setup, Field Wiring and dedicated #230 editor surfaces; do not merge parallel map code without reconciling the engineering specification.

## Procedures and Development Entry Points

- [Task-based icon operator procedures](../operatorSOP/README.md) — install/update the manager, local ExpertGPS maintenance and authorized administrator-only web publication.
- [MSB Icon Library Manager engineering/tool portal](../../../../../Database/EngineeringTools/README-Icon-Library-Manager.md) — source code and GUI entry points.
- [Site Infrastructure / GIS subsystem handoff](../README.md) — system dependencies, reference-data status and related systems.
