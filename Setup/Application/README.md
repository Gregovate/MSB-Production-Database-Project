# Setup Session Application

Status: **PRODUCTION RUNTIME OPERATIONAL — V0.3.9 ACCEPTED; 2025 HISTORICAL REVIEW / REUSABLE CATALOG WORK CONTINUES**

This folder contains the browser-native Setup Session application used for the Production-backed 2025 Historical Verification workflow and ongoing reusable Setup development.

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
V0.3.9-predecessor-drag
```

Current exact deployed source:

```text
55478f98f760473b65b5d700a84c868285022ab7
```

## Current Production Meaning

The 2025 Setup Session is real Production data, not disposable test data.

Managers/reviewers use it to:

- reconstruct and correct 2025 annual Setup information;
- verify records where evidence exists;
- add/correct reusable Setup tasks;
- delete reconstruction-safe Catalog mistakes where the governed command permits it;
- add/correct reusable resources and prerequisites;
- use Shift-drag for fast hard-predecessor entry;
- maintain prerequisite review/display order in the canonical task-detail list;
- improve task scope, order, crew/time/readiness information;
- review current Setup Procedure context; and
- identify UI/workflow/data-model problems before the 2026 Setup Session is created.

The reusable Catalog and the 2025 annual Session are intentionally separate. A valid reusable task may exist without a 2025 annual row. Do not force newer reusable definitions into 2025 merely to make the historical Plan appear complete.

The 2026 Setup Session must not be created until the active reusable Catalog cleanup gate in Issue #145 is complete and the intended seeded task set has been proven in disposable validation.

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
- Stage/Sub-stage/Scene path resolution reuses the accepted shared resolver;
- Google Drive Procedure publishing remains separately controlled; and
- server/runtime deployment authority lives in `Gregovate/MSB-Server-Management`.

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

## Dirty-Edit / Client Build Safety

The accepted V0.3.7 safety behavior remains part of V0.3.9.

The Setup header visibly shows the loaded client build, currently:

```text
Client V0.3.9
```

Governed writes verify that the client build matches `/api/health`. A stale/mismatched client fails closed instead of quietly writing against a different server build.

Reusable edits are compared against the current selected server-backed task. State-changing actions such as `Mark Verified` cannot silently discard pending reusable edits. The application either safely saves the reusable changes before the annual action or stops the action when the reusable save cannot complete.

Dirty navigation uses explicit save/discard/stay behavior. Independent save surfaces such as Physical Effort, Display/Container Material, Resources, Captains, and prerequisite maintenance remain separately governed.

## Current Task-Detail Layout

V0.3.9 preserves the accepted V0.3.8 laptop/desktop layout:

```text
LEFT                               RIGHT
Reusable Task Definition            Annual Historical Actual
Material / Logistics                Captains / Knowledge Owners
```

The reusable editor itself uses a compact two-column desktop grid. Material / Logistics keeps its four resolved counts and full `View Material Details` dialog. Prerequisites and Equipment / Resources remain below the rail block.

Physical mobile-device acceptance was not performed for V0.3.8. Responsive stacking is contract-covered and was checked with a narrowed desktop browser only.

Cross-application theme and dark-mode white-logo consistency are tracked separately in Issue #159.

## Current Prerequisite Interaction

Issue #151 established the Production hard-predecessor workflow.

Fast entry:

```text
hold Shift before left-button-down on dependent task A
    -> drag A onto prerequisite task B
    -> release
    -> A depends on B
    -> neither task moves
```

Ordinary drag without Shift keeps normal reusable task reorder/scope movement behavior. Shift-release over empty Stage/Scene space cancels the prerequisite gesture without moving the task.

Task detail shows one canonical prerequisite list with position, **Up**, **Down**, and **Remove**, plus a separate manual **Add prerequisite** control. Already-assigned prerequisites are excluded from the Add choices.

Prerequisite Up/Down is presentation/review order only. It does not create dependency relationships among prerequisite tasks.

Creation/removal remains governed by:

```text
ref.set_setup_task_dependency(text,bigint,bigint,text,boolean)
```

Reordering uses:

```text
ref.reorder_setup_task_dependencies(text,bigint,bigint[])
```

Circular-dependency protection remains database-authoritative.

Structured external/site readiness remains separate future work. Do not represent mowing, access, outside construction, or similar conditions as fake Setup tasks merely to create blockers.

## Current Manager / Reviewer Capabilities

The live review workflow supports current governed behavior for:

- reading the 2025 annual task list;
- reviewing verification state;
- correcting supported annual information;
- creating/copying reusable tasks;
- reconstruction-safe deletion/deactivation where governed rules allow;
- maintaining task scope and order;
- maintaining prerequisites through Shift-drag or the canonical prerequisite editor;
- maintaining structured equipment/resources;
- maintaining supported reusable material applicability;
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

For authorized Managers, editable Google-native source resolution is:

```text
SourceDocs first
-> Archive only when no editable SourceDocs .gdoc exists
```

During the 2026 migration, the archived `.gdoc` remains the historical original. To establish the current editable source, open the archived document in Google Docs, use **File -> Make a copy**, and save the new Google-native document in `Procedures\Setup\SourceDocs`. All later edits occur in the SourceDocs copy. Copying the Windows `.gdoc` shortcut file is not the migration method.

The current published field PDF remains directly in `Procedures\Setup` and must be updated when the approved editable procedure changes.

The runtime uses `/mnt/msb-setup-google-links` to expose link-form representations of native Google documents without converting normal Word documents.

## Production Runtime

Permanent source checkout:

```text
/opt/msb-setup
```

Current deployed source SHA:

```text
55478f98f760473b65b5d700a84c868285022ab7
```

Current health:

```json
{"data_mode":"postgres","status":"ok","version":"V0.3.9-predecessor-drag"}
```

Service/runtime facts are owned by `Gregovate/MSB-Server-Management`.

Current accepted service state:

```text
msb-setup.service              = active / enabled
msb-setup-google-links.service = active / enabled
listener                       = 192.168.5.9:8794
public route                   = https://my.sheboyganlights.org/setup/
```

V0.3.9 applied database migration 026 and then advanced only the dedicated Setup application checkout. Live focused regression passed 63 tests. The Production governed fingerprint remained unchanged across migration/deployment:

```text
9510360aa7de2da59d1ed8a9ad9d69f7
```

Existing dependency note/audit evidence also remained unchanged across migration:

```text
26b170fba3500ea2647967e87aa02a1c
```

See `Setup/Acceptance/Setup_Predecessor_V039_Production_Acceptance_2026-09-11.md` for the full Production evidence and rollback archive.

## Prototype / Historical Lineage

Earlier files in this folder include prototype-era UI and local validation support. They remain useful lineage and test evidence, but they are not the Production entry point.

Do not infer current Production behavior from old prototype comments or local-storage-only code paths. Current authority is the Production entry point, current tests, current database migrations, current acceptance records, and the current Setup engineering handoff.

Historical runtime milestones include:

```text
V0.3.5  Stage/Scene material + presentation baseline
V0.3.6  dirty-edit candidate; failed real Production acceptance and rolled back
V0.3.7  accepted dirty-edit / client-build safety
V0.3.8  accepted compact task-detail layout
V0.3.9  current accepted Shift-drag prerequisite + canonical prerequisite editor
```

## Current Boundaries

Still outside the accepted Production-ready workflow:

- structured external/site readiness;
- Pick List generation;
- task-specific staged material release timing;
- resource catalog sort/existing-resource editing;
- Container/Display movement/scanning write commands; and
- park-location execution evidence.

The application also does not automatically publish revised PDFs back into Google Drive.

## Testing / Live Evaluation

Automated contract tests remain useful for application changes, but browser behavior that depends on real client/runtime interaction must also pass protected-route operator validation before being treated as accepted Production behavior.

Do not create fake Production work days, movement events, dependencies, or throwaway records merely to exercise controls.

During the V0.3.9 deployment gate, the broad Setup suite exposed two inherited stale literal-string tests that also failed on the already accepted V0.3.8 checkout. The V0.3.9 focused current deployment suite passed 63 tests. Closeout corrects those stale assertions; do not describe the pre-deployment broad suite as fully green.

## Engineering Resume

Before changing the application:

1. read `System_Documentation/Project_Rules/README.md`;
2. read `Docs/02_Production_Database/01_System_Architecture/12_Setup_and_Deployment/engineering/README.md`;
3. read the current `Setup_Session_Production_Engineering_Handoff_2026-09-11.md`;
4. preserve V0.3.7 dirty-edit/client-server build protection;
5. preserve the V0.3.8 compact task-detail layout;
6. preserve the V0.3.9 Shift-drag direction, canonical prerequisite editor, and presentation-order semantics;
7. preserve the 2025 annual vs reusable Catalog boundary;
8. review Issue #145 before any 2026 Session creation;
9. review the active issue/contract for the feature being changed; and
10. use `Gregovate/MSB-Server-Management` for live runtime facts, browser-review procedure, and deployment runbooks.

## Related Documentation

- `Docs/02_Production_Database/01_System_Architecture/12_Setup_and_Deployment/README.md`
- `Docs/02_Production_Database/01_System_Architecture/12_Setup_and_Deployment/engineering/README.md`
- `Docs/02_Production_Database/01_System_Architecture/12_Setup_and_Deployment/engineering/Setup_Session_Production_Engineering_Handoff_2026-09-11.md`
- `Docs/02_Production_Database/01_System_Architecture/12_Setup_and_Deployment/engineering/Setup_Predecessor_and_Readiness_Contract_2026-09-09.md`
- `Docs/02_Production_Database/01_System_Architecture/12_Setup_and_Deployment/operatorSOP/Review_2025_Setup_History.md`
- `Docs/02_Production_Database/02_Operational_SOPs/Setup/Setup_Session_Manager_Review_Guide.md`
- `Setup/Acceptance/Setup_Predecessor_V039_Production_Acceptance_2026-09-11.md`
