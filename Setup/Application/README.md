# Setup Session Application

Status: **PRODUCTION RUNTIME OPERATIONAL — 2025 HISTORICAL REVIEW / TRAINING; UI/WORKFLOW IN LIVE EVALUATION**

This folder contains the browser-native Setup Session application used for the Production-backed 2025 Historical Verification workflow.

The application is live at:

```text
https://my.sheboyganlights.org/setup/
```

The current Production entry point is:

```text
Setup/Application/production_backend.py
```

Current reported version:

```text
V0.3.4-shared-season-guard-review
```

## Current Production Meaning

The 2025 Setup Session is real Production data, not disposable test data.

Managers/reviewers use it to:

- reconstruct and correct 2025 annual Setup information;
- verify records where evidence exists;
- add/correct reusable Setup tasks;
- add/correct reusable resources and prerequisites;
- improve task scope, order, crew/time/readiness information;
- review current Setup Procedure context; and
- identify UI/workflow/data-model problems before the 2026 Setup Session is created.

Production deployment is accepted, but the Setup/UI subsystem is intentionally **not final**. PRs #123, #124, and #125 remain open while real-use findings are collected and resolved.

## Application Architecture

The Production application follows the MSB browser-native pattern:

```text
browser
  -> Cloudflare Access
  -> Synology /setup/ reverse proxy
  -> msb-setup.service on 192.168.5.9:8794
  -> production_backend.py
  -> Setup APIs/repositories
  -> PostgreSQL msb through fieldwiring_app
  -> shared Field Context / Procedure resolver
  -> read-only Display Folders / Google-native link view
```

Key boundaries:

- PostgreSQL remains authoritative;
- Cloudflare Access provides authenticated identity at the perimeter;
- Setup capabilities are resolved server-side;
- writes use narrow governed PostgreSQL command functions;
- the browser does not receive broad table DML authority;
- Stage/Sub-stage/Scene path resolution reuses the accepted shared resolver; and
- Google Drive Procedure publishing remains separately controlled.

## Annual vs Reusable Data

The application deliberately separates:

```text
Annual 2025 information
    = what happened or was planned in 2025

Reusable Setup knowledge
    = normal task/resource/prerequisite/scope/order information
      that may carry forward to later seasons
```

A one-off 2025 condition must not be written into reusable knowledge merely to make the historical record fit.

## Session-Year Guard

The selected Setup Session owns the allowed operational year.

```text
2025 session -> 2025 operational dates/timestamps only
2026 session -> 2026 operational dates/timestamps only
```

The browser constrains date controls and the database independently enforces the same rule. Audit timestamps remain real current timestamps.

## Current Manager / Reviewer Capabilities

The live review workflow supports the current governed application behavior for:

- reading the 2025 annual task list;
- reviewing verification state;
- correcting supported annual information;
- creating/copying reusable tasks;
- maintaining task scope and order;
- maintaining prerequisites;
- maintaining structured equipment/resources;
- reviewing supported planning information; and
- opening current Setup Procedure/document context.

Only Administrators may create annual Setup Sessions or promote an annual planned order into the reusable future baseline.

## Procedure / Google Drive Contract

Stage- and Scene-scoped tasks use the established Procedure layout:

```text
<Stage / Sub-stage / Scene>\Procedures\Setup\
    <current field PDF>.pdf
    Archive\
    images\
    SourceDocs\
```

Park-wide work with no appropriate LOR Stage/Scene uses:

```text
G:\Shared drives\Display Folders\41 Park Infrastructure-PI\Procedures\Setup
```

The application may expose both the current published PDF and an editable Google-native source to authorized Managers. If the editable procedure is corrected, the current published PDF must also be updated before the instruction is treated as current.

The runtime uses `/mnt/msb-setup-google-links` to expose link-form representations of native Google documents without converting normal Word documents.

## Production Runtime

Permanent source checkout:

```text
/opt/msb-setup
```

Current deployed source SHA:

```text
c0639c5b04de667176a8d8eef14fce0409f03ec6
```

Service/runtime facts are owned by `Gregovate/MSB-Server-Management`.

Current accepted service state:

```text
msb-setup.service              = active / enabled
msb-setup-google-links.service = active / enabled
listener                       = 192.168.5.9:8794
public route                   = https://my.sheboyganlights.org/setup/
```

## Prototype Lineage

Earlier files in this folder include prototype-era UI and local validation support. They remain useful lineage and test evidence, but they are not the Production entry point.

Do not infer current Production behavior from old prototype comments or local-storage-only code paths. Current authority is the Production entry point, current tests, current database migrations, and the Setup engineering handoff.

## Current Boundaries

Still outside the accepted Production-ready workflow:

- Pick List generation; and
- Container/Display movement/scanning write commands.

Do not infer movement history merely because identifiers are scanned or because a review action occurs.

The application also does not automatically publish revised PDFs back into Google Drive.

## Testing / Live Evaluation

Automated contract tests remain useful for application changes, but final UI/workflow acceptance depends on real 2025 review use by Managers.

During live evaluation, collect:

- bugs;
- confusing labels or fields;
- missing information;
- difficult task/resource/prerequisite workflows;
- navigation/search/filter issues;
- operational suggestions; and
- places where the UI does not match how Setup work is actually planned or performed.

Do not create fake Production work days, movement events, or throwaway records merely to exercise controls.

## Engineering Resume

Before changing the application:

1. read `System_Documentation/Project_Rules/README.md`;
2. read `Docs/02_Production_Database/01_System_Architecture/12_Setup_and_Deployment/engineering/README.md`;
3. read the current Production engineering handoff;
4. review PRs #123, #124, and #125 together;
5. review current manager/reviewer findings; and
6. use `Gregovate/MSB-Server-Management` for live runtime facts and deployment runbooks.

## Related Documentation

- `Docs/02_Production_Database/01_System_Architecture/12_Setup_and_Deployment/README.md`
- `Docs/02_Production_Database/01_System_Architecture/12_Setup_and_Deployment/operatorSOP/Review_2025_Setup_History.md`
- `Docs/02_Production_Database/02_Operational_SOPs/Setup/Setup_Session_Manager_Review_Guide.md`
- `Docs/02_Production_Database/01_System_Architecture/12_Setup_and_Deployment/engineering/Setup_Session_Production_Engineering_Handoff_2026-09-07.md`
