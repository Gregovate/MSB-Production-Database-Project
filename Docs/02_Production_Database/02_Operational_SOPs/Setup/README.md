# Setup Session Operator Procedures

This folder contains operator/Manager procedures for the live Setup Session application.

## Current State

The protected Production application is operational at:

```text
https://my.sheboyganlights.org/setup/
```

The current shared working session is the real Production-backed:

```text
2025 — Historical Verification
```

The reusable catalog reconstruction was accepted in Production on 2026-09-09. The current PostgreSQL working baseline is:

```text
active reusable tasks    = 185
total reusable rows      = 187
reusable prerequisites   = 0
2026 Setup Sessions      = 0
```

Production deployment is accepted, but the **broader Setup UI/workflow remains in live evaluation**. Managers should continue real review/task-development work against current PostgreSQL data and report questions, suggestions, confusing behavior, and workflow problems before final subsystem acceptance.

The reconstruction workbook and historical schedules remain evidence. They are not a parallel ongoing master task list.

## Start Here

- [Setup Session Manager Review Guide](Setup_Session_Manager_Review_Guide.md) — plain-English guide for reviewing 2025 history, adding/correcting reusable tasks, resources and prerequisites, verification, planning/order concepts, procedures, and the annual-vs-reusable distinction.

The 2025 shared review is **not disposable**. Authorized saves are real 2025 or reusable Production Database changes.

## Session-Year Safety

The selected annual Setup Session controls the allowable operational year:

```text
2025 historical review -> 2025 operational dates only
2026 Setup Session      -> 2026 operational dates only
```

The browser constrains date controls, and the Production Database independently enforces the same rule. Audit/recording timestamps remain real current timestamps.

Only a Setup Administrator may:

- create/manage an annual Setup Session; or
- promote an annual planned order into the reusable future baseline.

There is currently no 2026 Setup Session. Do not create it until the current reusable catalog and the reviewed predecessor/readiness model are useful enough for planning.

See the engineering contract:

- [Setup Session Shared Review and Season-Year Guard — 2026-09-07](../../01_System_Architecture/12_Setup_and_Deployment/Setup_Session_Shared_Review_and_Season_Year_Guard_2026-09-07.md)

## Related Google Drive Procedure

Truly park-wide Setup work with no appropriate LOR Stage/Scene uses the controlled non-LOR root:

```text
G:\Shared drives\Display Folders\41 Park Infrastructure-PI
```

Build and maintain it from:

- [Create the Park Infrastructure Procedure Folder](../../../00_Project_Overview/Google_Drive/operatorSOP/Create_Site_Infrastructure_Procedure_Folder.md)

Do not create a fake LOR Stage, Scene, or Preview for Park Infrastructure merely to hold these Procedures.

`40-CommandCenter` is different: it has a real LOR Preview and remains legitimate Stage 40 even though its Preview currently has no wired inventory items. Command Center trailer/WiFi/gateway/hotspot Setup work belongs to Stage 40, not Park Infrastructure.

## Current Implementation Boundary

Live now:

- Production-backed 2025 historical review/training;
- the current 185-task reusable PostgreSQL catalog;
- Manager/reviewer task verification and correction;
- reusable task creation/copy and maintenance;
- scope/order/prerequisite/resource/effort maintenance through governed controls;
- annual planning/review controls supported by the current application;
- Procedure/document context; and
- protected authenticated browser access.

Still outside the current Production-ready boundary:

- reviewed predecessor/readiness completion across the reconstructed catalog;
- cross-Stage candidate planning / short-horizon scheduler workflow;
- Pick List generation; and
- Container/Display movement/scanning write commands and park-location execution evidence.

A current known catalog correction is missing physical `Set Up Frosty`; transport-only `Bring Frosty to park` remains logistics evidence. Frosty setup must be added to the current catalog and precede the applicable Stars work.

Do not document later layers as live Production behavior until their separate acceptance gates pass.
