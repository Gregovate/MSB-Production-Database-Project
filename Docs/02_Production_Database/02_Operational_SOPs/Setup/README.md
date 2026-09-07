# Setup Session Operator Procedures

This folder contains operator/Manager procedures for the Setup Session application.

## Current shared-review procedure

- [Setup Session Manager Review Guide](Setup_Session_Manager_Review_Guide.md) — plain-English guide for the Production-backed 2025 historical review/training workflow, including reusable Park Infrastructure/Stage/Scene organization, prerequisites, ordered backlog planning, rolling-horizon Crew A/B/C scheduling, Procedure PDFs, material/location context, Captain progress/completion, session-year date restrictions, and Administrator-only future-baseline promotion.

The 2025 shared review is **not disposable**. Authorized saves are real 2025/reusable Production Database changes.

## Session-year safety

The selected annual Setup Session controls the allowable operational year:

```text
2025 historical review -> 2025 operational dates only
2026 Setup Session      -> 2026 operational dates only
```

The browser constrains date controls, and the Production Database independently enforces the same rule. Audit/recording timestamps remain real current timestamps.

Only a Setup Administrator may:

- create/manage an annual Setup Session; or
- promote an annual planned order into the reusable future baseline.

See the engineering contract:

- [Setup Session Shared Review and Season-Year Guard — 2026-09-07](../../01_System_Architecture/12_Setup_and_Deployment/Setup_Session_Shared_Review_and_Season_Year_Guard_2026-09-07.md)

## Related Google Drive build procedure

Truly park-wide Setup work with no appropriate LOR Stage/Scene uses the controlled non-LOR root:

```text
G:\Shared drives\Display Folders\41 Park Infrastructure-PI
```

Build and maintain it from:

- [Create the Site Infrastructure Procedure Folder](../../../00_Project_Overview/Google_Drive/operatorSOP/Create_Site_Infrastructure_Procedure_Folder.md)

Do not create a fake LOR Stage, Scene, or Preview for Park Infrastructure merely to hold these Procedures.

`40-CommandCenter` is different: it has a real LOR Preview and remains legitimate Stage 40 even though its Preview currently has no wired inventory items. Command Center trailer/WiFi/gateway/hotspot Setup work belongs to Stage 40, not to Park Infrastructure.

## Current implementation boundary

The Setup V0.3.4 planning/review application is being promoted through a controlled Production-backed review gate. The shared candidate application is kept isolated from the current live shared checkout until accepted.

Still outside the current Production-ready boundary:

- Pick List generation; and
- Container/Display movement/scanning write commands.

Do not document those later layers as live Production behavior until their separate acceptance gates pass.
