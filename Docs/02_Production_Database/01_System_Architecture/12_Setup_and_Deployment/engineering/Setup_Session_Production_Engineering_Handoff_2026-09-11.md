# Setup Session Production Engineering Handoff — 2026-09-11

| Document Control | Value |
|---|---|
| Document Type | Engineering Handoff |
| System | Production Database — Setup Session |
| Status | CURRENT HANDOFF — V0.3.10 accepted in Production; broader Setup development remains active |
| Owner | MSB Production Database engineering |
| Last Reviewed | 2026-09-11 |

## Purpose

Preserve the current accepted Setup Session Production state, recent runtime lineage, data/authorization boundaries, exact deployed source, fingerprint evidence, prerequisite behavior, resource-catalog behavior, procedure-source behavior, open work, and engineering resume point so future work starts from repository evidence rather than reconstructing recent acceptance from chat or issue comments.

This handoff supersedes the 2026-09-07 handoff as the **current** runtime/resume summary. The 2026-09-07 document remains historical foundation evidence for the original V0.3.4 Production promotion.

## Current Production Runtime

Protected application:

```text
https://my.sheboyganlights.org/setup/
```

Current accepted application version:

```text
V0.3.10-resource-catalog
```

Exact deployed application source:

```text
/opt/msb-setup
SHA = c2a1820627f1a036d634241cc6aecd1a926a1479
```

Implementation lineage:

```text
Issue #152
PR #168
merge commit = cc4b5767605373504fd993698ce735514bec0d37
```

The runtime intentionally remains pinned to the exact browser-accepted application candidate rather than silently moving to later test/documentation commits.

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

## Current Database / Migration Baseline

Current accepted Setup database additions include migration 025 for Stage/Scene material resolution, migration 026 for persistent prerequisite review/display order, and migration 027 for reusable resource-catalog management.

Migration 026 remains accepted:

```text
Setup/Database/026_add_setup_dependency_order.sql
blob = 759774d80eb51b706a0e7b71c5e834636b64a451
```

Migration 027:

```text
Setup/Database/027_add_setup_resource_catalog_management.sql
blob = 8d65593a3c083ea74b4a35a95bfd6aa8fd617252
```

Accepted migration 027 state includes:

```text
ref.setup_resource.display_order = integer NOT NULL DEFAULT 100
non-negative display_order constraint = installed
catalog-order index = installed
ref.update_setup_resource(text,integer,text,text,text,boolean,integer) = installed
normalized exact-name duplicate protection = installed
fieldwiring_app narrow resource-command EXECUTE = YES
fieldwiring_app broad setup_resource UPDATE/DELETE = NO
fieldwiring_app broad setup_task_resource UPDATE = NO
```

Production had 12 resource rows, 32 task-resource relationships, and zero normalized duplicate groups at deployment. Migration 027 did not silently merge or rewrite existing catalog rows.

The stable governed Setup fingerprint before and after migration/deployment, before the legitimate protected-route operator acceptance write, was:

```text
7c21041caecac6eb77660238ba3c8cf9
```

Validated rollback archive retained on the Production host:

```text
/home/msbadmin/backups/setup-152/msb-pre-setup-152-20260911T170411.dump
SHA256 = b60857bf12eae68922cc309b795e920b3b2aaccd5a928b775527057450a7aa15
```

The earlier V0.3.9 dependency migration evidence remains historically valid, including the 17-row legacy dependency fingerprint:

```text
26b170fba3500ea2647967e87aa02a1c
```

## Current Annual / Catalog Boundary

The current annual context remains:

```text
2025 Setup Session  = HISTORICAL_VERIFICATION
2026 Setup Sessions = 0
```

Do not use older fixed reusable-task counts such as 57 or 185 as current authority. The reusable Catalog has legitimately changed during reconstruction and live review.

The active reusable Catalog is the future-work baseline. A reusable task may legitimately exist without a 2025 annual row. New annual Session creation seeds every active reusable task, so Issue #145 remains the hard cleanup gate before creating 2026.

Do not force newer reusable tasks into the 2025 historical Session merely to make the historical Plan appear complete.

## Current V0.3.9 Prerequisite Behavior

The accepted fast-entry interaction remains:

```text
hold Shift before left-button-down on dependent task A
    -> drag A onto prerequisite task B
    -> release
    -> A depends on B
    -> neither task moves
```

Accepted behavior includes:

- multiple prerequisites on one task;
- idempotent repeated dependency entry;
- database-authoritative circular-dependency rejection;
- Shift-release over empty Stage/Scene space cancels without moving the task;
- ordinary drag without Shift keeps reusable reorder and Stage/real-Scene movement behavior; and
- explicit success/failure feedback with the intended dependency direction.

Task detail uses one canonical prerequisite list. Each prerequisite appears once with position plus **Up**, **Down**, and **Remove**. A separate manual **Add prerequisite** form remains available, and already-assigned prerequisites are excluded from its choices.

Add/remove/reorder reload authoritative dependency state so task detail and the Catalog `Requires` line remain synchronized.

Prerequisite Up/Down changes review/display order only. It does not create dependency relationships among prerequisite tasks.

Keep the domain distinction:

```text
HARD PREDECESSOR != PREFERRED ORDER != READINESS CONDITION
```

Structured outside/site readiness remains future work.

See [`Setup_Predecessor_and_Readiness_Contract_2026-09-09.md`](Setup_Predecessor_and_Readiness_Contract_2026-09-09.md).

## Current Task-Detail Presentation

V0.3.10 preserves the accepted V0.3.8 laptop/desktop layout:

```text
LEFT                               RIGHT
Reusable Task Definition            Annual Historical Actual
Material / Logistics                Captains / Knowledge Owners
```

The reusable definition itself uses a compact two-column desktop grid. Material / Logistics retains the four essential counts plus the existing full detail dialog. Prerequisites and Equipment / Resources remain below the rail block and are reachable with materially less scrolling.

Physical mobile-device acceptance was not performed for V0.3.8. Responsive stacking is contract-covered and was checked using a narrowed desktop browser only.

Issue #159 separately owns cross-application palette and dark-mode white-logo consistency. Issue #169 separately owns keeping the active task name visible while scrolling long task detail.

## Current V0.3.10 Resource Catalog Behavior

The accepted ordinary task-resource workflow is deliberately compact and name-oriented:

```text
search existing resource
    -> choose resource
    -> set task quantity / Required-vs-Preferred / task notes
    -> add or update relationship
```

The ordinary picker sorts primarily by `resource_name`, then type/ID. This is an accepted refinement from the original #152 wording: numeric `display_order` remains modeled/editable, but meaningful names drive normal selection and the full Manager catalog defaults to Name sort.

Use **Manage Resource Catalog** only for reusable catalog maintenance. It:

- searches active and inactive catalog rows;
- supports alternate sorts including optional display order;
- renames/corrects an existing catalog row in place;
- edits resource type, reusable catalog notes, active state, and display order;
- preserves stable `setup_resource_id` identity and existing task relationships; and
- returns to the compact task flow through **Close Resource Catalog**.

Normalized exact duplicate names are blocked after case/trim/repeated-whitespace normalization. Likely existing matches are surfaced while entering a new name so near-duplicates can be reviewed before creation.

Task-specific quantity, Required-vs-Preferred, and task notes remain separate from catalog-level resource identity and notes.

Inactive resources remain discoverable in the Manager catalog and on existing relationships. New inactive assignments are blocked; existing inactive relationships can still be removed.

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
- visible client-build badge;
- governed-write client/server build-match validation;
- `no-store` protection for Setup page/assets/health so a stale client bundle cannot quietly continue writing; and
- independent Effort / Material / Resource / Captain save surfaces remain separately governed.

### V0.3.8 — accepted compact task-detail layout

Accepted exact candidate:

```text
SHA     = 2eee967b6c5359c0e2e2d876a2fe44af8359315c
version = V0.3.8-task-detail-compact
```

Production source-only deployment evidence:

```text
exact detached preflight regression = 53 passed
live focused regression              = 53 passed
fingerprint before deployment        = 9510360aa7de2da59d1ed8a9ad9d69f7
fingerprint after deployment         = 9510360aa7de2da59d1ed8a9ad9d69f7
protected health                     = V0.3.8-task-detail-compact
final protected browser acceptance   = PASS
```

### V0.3.9 — accepted prerequisite workflow

Accepted exact candidate:

```text
SHA     = 55478f98f760473b65b5d700a84c868285022ab7
version = V0.3.9-predecessor-drag
```

Production evidence:

```text
migration 026                         = PASS
focused exact-candidate regression    = 63 passed
live focused regression               = 63 passed
pre/post governed fingerprint         = 9510360aa7de2da59d1ed8a9ad9d69f7
pre/post legacy dependency fingerprint= 26b170fba3500ea2647967e87aa02a1c
protected direct negative path        = HTTP 401 PASS
protected health                      = V0.3.9-predecessor-drag
final protected browser acceptance    = PASS
```

The broad `Setup/Application` suite reported 191 passed / 2 failed on the exact V0.3.9 candidate. The same two failing literal-string contracts were reproduced on the already accepted V0.3.8 checkout, proving they were inherited stale test debt rather than V0.3.9 regressions.

See [`Setup_Predecessor_V039_Production_Acceptance_2026-09-11.md`](../../../../../Setup/Acceptance/Setup_Predecessor_V039_Production_Acceptance_2026-09-11.md).

### V0.3.10 — current accepted reusable resource catalog

Accepted exact application candidate:

```text
SHA     = c2a1820627f1a036d634241cc6aecd1a926a1479
version = V0.3.10-resource-catalog
```

Implementation merge:

```text
PR #168
merge commit = cc4b5767605373504fd993698ce735514bec0d37
```

Regression evidence:

```text
exact runtime candidate        = 207 passed / 1 stale literal assertion
corrected test-only derivative = 209 passed
live focused regression        = 29 passed / 1 deselected stale assertion
```

The exact-runtime failure was only an outdated CSS cache-token assertion. The immediately following commit `be19b4f0e013b16f40673d14364113219d081f01` changed only the test file and passed 209 tests in the Production Python environment.

Production evidence:

```text
migration 027                     = PASS
stable pre/post fingerprint       = 7c21041caecac6eb77660238ba3c8cf9
protected direct negative path    = HTTP 401 PASS
protected health                  = V0.3.10-resource-catalog
protected browser acceptance      = PASS
legitimate catalog edit           = PASS
existing task relationship intact = PASS
```

See [`Setup_Resource_Catalog_V0310_Production_Acceptance_2026-09-11.md`](../../../../../Setup/Acceptance/Setup_Resource_Catalog_V0310_Production_Acceptance_2026-09-11.md).

## Browser Preview Lifecycle Finding

The #151 disposable review exposed a browser-preview lifecycle failure that remains durable operational knowledge.

A lost workstation SSH tunnel can leave the remote source-only preview wrapper blocked on its browser-review prompt while the Flask child survives in its own session/process group. In that state the browser reports `Failed to fetch`, but the application may still be healthy on the server.

Diagnosis must distinguish:

```text
application crash
vs.
SSH/tunnel loss with surviving preview
```

Acceptance tooling was hardened to clean only recognized preview-owned resources, reject Production ports, preserve reports/logs, use SSH keepalives, include HUP handling, and use `timeout --foreground` for an interactive bounded remote review.

Issue #166 separately tracks the remaining duplicate-sudo-prompt problem: the current #152-style launcher opens separate SSH/PTTY sessions for cleanup and preview, which can require two sudo authentications. Do not weaken sudo policy to hide that issue.

Server-side browser-review operational authority is `Gregovate/MSB-Server-Management/docs/server/Pre_Production_Browser_Review_Runbook.md`.

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

Migration 027 preserves the same boundary: `fieldwiring_app` receives narrow EXECUTE on resource-management commands and no broad resource/task-resource DML.

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

Issue #167 now owns the separate reusable Extra Materials / KIT assignments / material-source foundation. Do not collapse Extra Material requirements into LOR Display membership or assume every Extra Material lives in a KIT.

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
#151 Shift+left-drag predecessor entry  = CLOSED / ACCEPTED V0.3.9
#152 reusable resource catalog workflow = ACCEPTED V0.3.10 / close after documentation merge
#161 SourceDocs migration documentation = CLOSED / COMPLETED
```

Real independent work remains, including:

```text
#145 reusable Catalog cleanup before 2026 Session creation
#167 Extra Materials / KIT assignments / material-source tracking
#169 persistent active-task name/context while scrolling long task detail
#166 one-sudo browser-preview harness hardening
#159 cross-app light/dark palette and dark-mode white-logo standardization
#141 task-specific staged material / Pick List release timing
#132 Captain work-report duration / multi-day effort capture
#113 shared Scan readiness / identity capture integration
```

Structured readiness remains open design/implementation work under the broader Setup planning stream and must remain separate from hard task prerequisites.

Do not create the 2026 Setup Session until #145 is complete and the cleaned active Catalog has passed the disposable 2026 seeding check.

## Engineering Resume Sequence

Before the next Setup change:

1. refresh current remote `main` and read the Project Rules;
2. read this handoff and [`README.md`](README.md);
3. read the responsible contract for the work item being changed;
4. preserve V0.3.7 dirty-edit/client-server build protections;
5. preserve V0.3.8 compact task-detail layout;
6. preserve V0.3.9 Shift-drag prerequisite direction, canonical prerequisite editor, and display-order-only semantics;
7. preserve V0.3.10 name-oriented resource assignment, stable in-place resource editing, duplicate protection, inactive-resource rules, and narrow authorization boundary;
8. preserve current 2025 historical state and do not create 2026 without #145 acceptance;
9. use `Gregovate/MSB-Server-Management` for runtime/deployment/browser-review authority;
10. perform disposable/current-Production-clone browser acceptance before Production deployment when browser behavior changes;
11. perform real protected-route operator validation for behavior that depends on actual client/runtime interaction; and
12. complete controlled engineering/operator documentation and issue closeout before leaving the work item.

## Related Documents

- [Setup engineering portal](README.md)
- [V0.3.10 resource-catalog Production acceptance](../../../../../Setup/Acceptance/Setup_Resource_Catalog_V0310_Production_Acceptance_2026-09-11.md)
- [V0.3.9 prerequisite Production acceptance](../../../../../Setup/Acceptance/Setup_Predecessor_V039_Production_Acceptance_2026-09-11.md)
- [V0.3.8 task-detail Production acceptance](../../../../../Setup/Acceptance/Setup_Task_Detail_Production_Acceptance_2026-09-11.md)
- [Stage / Scene material resolution contract](Setup_Stage_Scene_Material_Resolution_Contract_2026-09-10.md)
- [Data consumption and authorization contract](Setup_Data_Consumption_and_Authorization_Contract_2026-09-10.md)
- [Predecessor and readiness contract](Setup_Predecessor_and_Readiness_Contract_2026-09-09.md)
- [Original V0.3.4 foundation handoff — historical](Setup_Session_Production_Engineering_Handoff_2026-09-07.md)
- [Manager Review Guide](../../../02_Operational_SOPs/Setup/Setup_Session_Manager_Review_Guide.md)
