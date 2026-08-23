# Utilities

This folder contains active tools that support more than one MSB subsystem or do not belong to a single application or database component.

## Ownership Rule

A utility should live here only when it is genuinely cross-system.

If a tool primarily serves one subsystem, keep it with that subsystem instead. This prevents `Utilities/` from becoming a miscellaneous storage area and keeps implementation close to the documentation and system that own it.

## Current Utilities

- [MSB PostgreSQL Read-Only MCP](MSB_Postgres_MCP/README.md) — draft cross-system engineering connector for safe read-only access to current Production Database state. It is not deployed and does not authorize database writes or schema changes.
- [FieldWiring Drive Resolver Test Harness](FieldWiring_Drive_Resolver_Test/README.md) — read-only engineering harness that tests the shared V7+ Stage/Scene Google Drive context-resolution rules against `fieldwiring_snapshot.db` and the mapped `Display Folders` hierarchy before FieldWiring browser implementation.
- [`populate_msb_db_source_folder_markers.ps1`](populate_msb_db_source_folder_markers.ps1) — **INCOMPLETE FOR THE CURRENT APPLICATION-SPECIFIC MARKER RULES.** This utility was written for an older narrow target set (`PreviewBackground`, `Procedures`, and `Wiring`) and does not add the required structural Stage/Sub-stage/Scene root marker or the future Procedure task/image markers. For FieldWiring, `Wiring` is the marked source root; `Wiring\BackgroundStage` and `Wiring\MusicalStage` do **not** require separate markers. Do not treat a successful run of this utility as proof of full marker compliance, and do not modify production marker files merely to match the utility. See the [marker operator procedure](../Docs/00_Project_Overview/03-MSB_DB_Source_Folder_Marker_Operator_Procedure.md).

## Retired / Do Not Run

- [`remove_misplaced_msb_db_scope_root_markers.ps1`](remove_misplaced_msb_db_scope_root_markers.ps1) — **DO NOT RUN under the current architecture.** This remediation utility was created during an intermediate design that incorrectly treated Stage/Sub-stage/Scene root markers as misplaced. Current FieldWiring/path-resolution rules require the structural marker on those roots. The utility is retained only as historical/recovery evidence until it is moved to the appropriate archive.

## Maintenance

When adding a current utility:

- document what system or systems use it;
- identify its normal entry point;
- link to the related subsystem documentation when useful;
- move superseded utilities to the appropriate archive rather than leaving obsolete tools mixed with current ones.

For repository documentation-maintenance tools, use [System Documentation Automation](../System_Documentation/Automation/README.md) instead of this folder.
