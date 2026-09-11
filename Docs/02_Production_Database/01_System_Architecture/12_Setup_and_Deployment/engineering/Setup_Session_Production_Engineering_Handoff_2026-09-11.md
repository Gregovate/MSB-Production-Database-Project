# Setup Session Production Engineering Handoff — 2026-09-11

| Document Control | Value |
|---|---|
| Document Type | Engineering Handoff |
| System | Production Database — Setup Session |
| Status | CURRENT HANDOFF — V0.3.8 accepted in Production; broader Setup development remains active |
| Owner | MSB Production Database engineering |
| Last Reviewed | 2026-09-11 |

## Purpose

Preserve the current accepted Setup Session Production state, recent runtime lineage, data/authorization boundaries, exact deployed source, fingerprint evidence, procedure-source behavior, open work, and engineering resume point so future work starts from repository evidence rather than reconstructing recent acceptance from chat or issue comments.

This handoff supersedes the 2026-09-07 handoff as the **current** runtime/resume summary. The 2026-09-07 document remains historical foundation evidence for the original V0.3.4 Production promotion.

## Current Production Runtime

Protected application:

```text
https://my.sheboyganlights.org/setup/
```

Current accepted application version:

```text
V0.3.8-task-detail-compact
```

Exact deployed application source:

```text
/opt/msb-setup
SHA = 2eee967b6c5359c0e2e2d876a2fe44af8359315c
```

Implementation lineage:

```text
Issue #153
PR #160
merge commit = d882bb33785321de9a6a880347521adf9518502e
```

The runtime intentionally remains pinned to the exact browser-accepted candidate rather than silently moving to the later repository merge/documentation commit.

Current accepted service/runtime facts remain:

```text
msb-setup.service                   = active / enabled
listener                            = 192.168.5.9:8794
msb-setup-google-links.service      = active / enabled
Display Folders mount               = /mnt/msb-display-folders (read-only)
Google native link view             = /mnt/msb-setup-google-links
protected route                     = https://my.sheboyganlights.org/setup/
```

Server/runtime authority remains `Gregovate/MSB-Server-Management`.

## Current Annual / Catalog Boundary

The current annual context remains:

```text
2025 Setup Session  = HISTORICAL_VERIFICATION
2026 Setup Sessions = 0
```

Do not use older fixed reusable-task counts such as 57 or 185 as current authority. The reusable Catalog has legitimately changed during reconstruction and live review.

The active reusable Catalog is the future-work baseline. A reusable task may legitimately exist without a 2025 annual row. New annual Session creation seeds every active reusable task, so Issue #145 remains the hard cleanup gate before creating 2026.

Do not force newer reusable tasks into the 2025 historical Session merely to make the historical Plan appear complete.

## Current V0.3.8 Task-Detail Presentation

Accepted laptop/desktop task-detail layout:

```text
LEFT                               RIGHT
Reusable Task Definition            Annual Historical Actual
Material / Logistics                Captains / Knowledge Owners
```

The reusable definition itself uses a compact two-column desktop grid. Material / Logistics retains the four essential counts plus the existing full detail dialog. Prerequisites and Equipment / Resources remain below the rail block and are reachable with materially less scrolling.

No schema, API, authorization, or Plan / Schedule behavior changed solely for V0.3.8.

Physical mobile-device acceptance was not performed. Responsive stacking is contract-covered and was checked using a narrowed desktop browser only.

Issue #159 separately owns cross-application palette and dark-mode white-logo consistency. The blue Setup logo in dark mode is a known current presentation inconsistency and is not an accepted V0.3.8 theme standard.

## Recent Runtime / Safety Lineage

### V0.3.5 — accepted Stage/Scene material baseline

```text
SHA     = 9791a6b5a9739c1107746ecbe3cf3ebb558f38bd
version = V0.3.5-stage-scene-material-review
```

This release established the current Stage/real-Scene material-resolution and Stage-oriented presentation baseline and applied migration 025.

### V0.3.6 — failed protected Production acceptance and rollback

The first dirty-edit safety implementation reached Production as:

```text
SHA     = 89012d5e40a26323db78dce50d9e58dd27580169
version = V0.3.6-catalog-dirty-edit-safety
```

Real protected-route validation reproduced the unsafe behavior: `Mark Verified` committed annual VERIFIED state while unsaved reusable crew/completion edits disappeared after reload.

The source-only deployment was rolled back to the prior accepted V0.3.5 application. No database dump restore was used because the operator acceptance itself legitimately wrote annual-review state.

This failure is durable evidence that disposable browser acceptance alone is not sufficient for this class of client/runtime interaction; real protected-route acceptance remains mandatory.

### V0.3.7 — accepted dirty-edit / version safety

Accepted exact candidate:

```text
SHA     = 9d0c31421ce7cbd1b1cbcf733b06198ace418e9d
version = V0.3.7-catalog-dirty-edit-followup
```

Accepted protections include:

- live-form vs selected-task dirty comparison;
- reusable save before annual verification, with verification blocked if save fails;
- Save / Discard / Stay protection for dirty navigation;
- visible `Client V0.3.7` client-build badge;
- governed-write client/server build-match validation;
- `no-store` protection for Setup page/assets/health so a stale client bundle cannot quietly continue writing; and
- independent Effort / Material / Resource / Captain save surfaces remain separately governed.

V0.3.7 Production deployment evidence:

```text
focused live regression = 45 passed
pre/post source-deployment fingerprint = 0298e2b1c3531e13b1a0a86d4e55509d
protected health = V0.3.7-catalog-dirty-edit-followup
```

Real operator validation on reusable task 200 / annual task 81 confirmed crew min/max 4/6 and completion point survived `Mark Verified` without a separate manual reusable save, and annual state became VERIFIED.

### V0.3.8 — current accepted runtime

Accepted exact candidate:

```text
SHA     = 2eee967b6c5359c0e2e2d876a2fe44af8359315c
version = V0.3.8-task-detail-compact
```

V0.3.8 preserves the V0.3.7 dirty-edit/build-match protections and changes the task-detail presentation only.

Production source-only deployment evidence:

```text
exact detached preflight regression = 53 passed
live focused regression              = 53 passed
fingerprint before deployment        = 9510360aa7de2da59d1ed8a9ad9d69f7
fingerprint after deployment         = 9510360aa7de2da59d1ed8a9ad9d69f7
protected health                     = V0.3.8-task-detail-compact
final protected browser acceptance   = PASS
```

Final browser acceptance required no special Production data write.

See [`Setup_Task_Detail_Production_Acceptance_2026-09-11.md`](../../../../../Setup/Acceptance/Setup_Task_Detail_Production_Acceptance_2026-09-11.md).

## Data / Authorization Boundary

Cloudflare authentication, Setup capability, Person identity mapping, and PostgreSQL grants remain separate layers:

```text
Cloudflare Access authenticated email
  -> Setup backend capability lookup
  -> Directus / ref.person identity
  -> narrow PostgreSQL SECURITY DEFINER command
```

Do not grant broad direct Setup table DML to solve operator identity or capability problems.

The characteristic error:

```text
Authenticated Setup operator is not mapped to an MSB person
```

is an identity-link / Person mapping problem, not evidence that the browser needs broader database permissions.

## Procedure / Editable Source Boundary

Current published field instruction:

```text
<Stage/Sub-stage/Scene>\Procedures\Setup\<current>.pdf
```

Authoritative editable Google-native source after migration:

```text
<Stage/Sub-stage/Scene>\Procedures\Setup\SourceDocs\
```

Historical original / fallback source:

```text
<Stage/Sub-stage/Scene>\Procedures\Setup\Archive\
```

Manager editable-source resolution is:

```text
SourceDocs first
-> Archive only when no editable SourceDocs .gdoc exists
```

The 2026 migration workflow is controlled in the Google Drive operator SOPs: open the archived `.gdoc` in Google Docs, use **File -> Make a copy**, save the new Google-native copy into `SourceDocs`, then edit only the SourceDocs copy. Copying the Windows `.gdoc` shortcut file is not the migration method.

Issue #161 / PR #162 completed that documentation closeout.

## Current Material / Planning Boundaries

The accepted Stage/Scene material resolver remains context, not a complete task-specific release/pick model.

```text
material enabled + real Scene
    -> exact current Scene Displays

material enabled + Stage
    -> current Stage-level Displays
    -> true child Scenes excluded

resolved Displays
    -> current ref.display.container_id
    -> deduplicated Containers
```

Issue #141 remains responsible for task-specific staged material subdivision and release timing.

Setup planning remains a rolling operational model rather than a rigid season-long fixed calendar:

```text
preferred order / hard predecessors
    + readiness
    + volunteers/equipment
    + weather/site conditions
    + prior progress
    -> candidate work
    -> operator selects practical work
    -> short-horizon schedule
```

## Current Open Work / Resume Point

Completed and accepted in this recent line:

```text
#154 dirty-edit / Mark Verified safety  = CLOSED / ACCEPTED V0.3.7
#153 compact task-detail layout         = CLOSED / ACCEPTED V0.3.8
#161 SourceDocs migration documentation = CLOSED / COMPLETED
```

Real independent work remains, including:

```text
#145 reusable Catalog cleanup before 2026 Session creation
#151 Shift+left-drag predecessor creation
#152 resource catalog sort order / existing-resource editing
#159 cross-app light/dark palette and dark-mode white-logo standardization
#141 task-specific staged material / Pick List release timing
#132 Captain work-report duration / multi-day effort capture
#113 shared Scan readiness / identity capture integration
```

Do not create the 2026 Setup Session until #145 is complete and the cleaned active Catalog has passed the disposable 2026 seeding check.

## Engineering Resume Sequence

Before the next Setup change:

1. refresh current remote `main` and read the Project Rules;
2. read this handoff and [`README.md`](README.md);
3. read the responsible contract for the work item being changed;
4. preserve the V0.3.7 dirty-edit/client-server build protections;
5. preserve the V0.3.8 visible client version marker;
6. preserve current 2025 historical state and do not create 2026 without #145 acceptance;
7. use `Gregovate/MSB-Server-Management` for runtime/deployment authority;
8. perform disposable/current-Production-clone browser acceptance before Production deployment when browser behavior changes;
9. perform real protected-route operator validation for behavior that depends on actual client/runtime interaction; and
10. complete controlled engineering/operator documentation and issue closeout before leaving the work item.

## Related Documents

- [Setup engineering portal](README.md)
- [V0.3.8 Production acceptance](../../../../../Setup/Acceptance/Setup_Task_Detail_Production_Acceptance_2026-09-11.md)
- [Stage / Scene material resolution contract](Setup_Stage_Scene_Material_Resolution_Contract_2026-09-10.md)
- [Data consumption and authorization contract](Setup_Data_Consumption_and_Authorization_Contract_2026-09-10.md)
- [Predecessor and readiness contract](Setup_Predecessor_and_Readiness_Contract_2026-09-09.md)
- [Original V0.3.4 foundation handoff — historical](Setup_Session_Production_Engineering_Handoff_2026-09-07.md)
- [Manager Review Guide](../../../02_Operational_SOPs/Setup/Setup_Session_Manager_Review_Guide.md)
