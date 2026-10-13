# Site Infrastructure / GIS — Engineering References

This is the technical entry point for the maintained GIS/source/icon subsystem. **Engineering documents set system contracts and acceptance gates; pull requests must implement those contracts.** A README is a handoff and navigation page, not a substitute for engineering authority.

## Current Engineering Authority

- [GIS Symbol Management — CURRENT icon source, publication, access and consumer contract](GIS_Symbol_Management.md) — definitive roles of `Masters`, `Plain`, canonical PNGs, web SVGs, ExpertGPS, current accepted release, security rules, map symbol sizing/fallback and open acceptance.
- [ExpertGPS Office Cropped Map Repair](ExpertGPS_Office_Cropped_Map_Repair.md) — targeted, backed-up correction and outstanding acceptance gates under #171.
- [Network Source Reconciliation](Network_Source_Reconciliation_2026-10-09.md) — source discovery and historical network reconciliation evidence; review against current #171/#230 controlled source requirements before applying old conclusions.

## Current Handoff — October 12, 2026

The approved Plain SVGs were administrator-published to Synology: **37 source entries SHA-256 verified** (12 new / 3 updated / 21 unchanged / 1 existing-case alias retained). The separate web PNG compatibility action remains blocked, and browser HTTPS/image and rugged Android offline map acceptance remain pending. The local ExpertGPS PNG files match the reviewed source hashes; Garmin is not implemented.

Ongoing #171/#230 work under #122 is integrated in **draft PR #319**. Its current GIS/GPX/FLW/PostGIS contracts belong in the existing controlled source synchronization engineering document on that work branch, not in this portal or in the PR body. The governing design is one maintained PostGIS reference authority with distinct Setup, Field Wiring and dedicated #230 editor surfaces; do not merge parallel map code without reconciling the engineering specification.

## Procedures and Development Entry Points

- [Task-based icon operator procedures](../operatorSOP/README.md) — install/update the manager, local ExpertGPS maintenance and authorized administrator-only web publication.
- [MSB Icon Library Manager engineering/tool portal](../../../../../Database/EngineeringTools/README-Icon-Library-Manager.md) — source code and GUI entry points.
- [Site Infrastructure / GIS subsystem handoff](../README.md) — system dependencies, reference-data status and related systems.
