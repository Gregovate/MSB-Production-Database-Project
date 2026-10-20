# Setup Mixed-Stage Container Unload Contract — 2026-09-09

| Document Control | Value |
|---|---|
| Document Type | Engineering Workflow Contract |
| System | Production Database — Setup Session / Pick List |
| Status | CURRENT DESIGN DIRECTION — operator-confirmed; not yet implemented |
| Owner | MSB Production Database engineering |
| Related Work | Issue #122; Setup Pick List Tablet Workflow; PR #125 |

## Purpose

Preserve the operator-confirmed execution model for shared/mixed-Stage Containers and trailers so the future Setup Pick List does not require volunteers to scan every Display/piece and does not incorrectly treat Container arrival at the park as proof that all contents were unloaded.

This contract applies generally to any Container whose current authoritative contents span more than one Setup Stage/scope. Known examples include Container 34 / Arch Trailer and the Antenna Trailer.

## October 19 — some unloaded Containers remain physical show structures

### Confirmed C009 mixed Display-Pallet acceptance case — October 19

C009 **Ginger Bread House** is a real multi-Display pallet with **13 permanently assigned Displays**, of which **Display 909 / CL-GingerbreadHouse is an integral part of the C009 physical show base**, while the other 12 assigned Displays are removable cargo. 2026 event #551 (`CONTAINER_MOVE`) with `contents_decision=EMPTY` created **13 inferred `TASK_UNLOAD` events #538–550** using **prior Container event #250** as the location source; DBeaver current-state readback shows **all 13 DETACHED**, including incorrectly detached **909 event #544**. The shared timestamp and GPS are not thirteen individual installation scans.

The future correct contents model must **exclude physical integral Display 909 from removable-cargo "Empty" decisions and counts** without removing its permanent Container assignment or requiring a second physical item to be scanned. It must still unload each of the other 12 when physically removed, retain C009 in the park as a show structure, and allow a truthful cargo-empty + show-base-present state (not `PARTIAL` simply because an integral Display remains). The current single-assigned-Display Pallet guard does not cover mixed pallets. Reference-data role of the integral Display must be explicitly governed under #230; guessing based on `Display Pallet` type or the Container's `display_pallet` boolean alone is insufficient.

C034 Arch Trailer distributes components along an approximately one-mile loop, intentionally stopping at many Stage locations hundreds of feet apart. Distances between successive unloads are **expected**, not grounds for a blanket movement rejection. Apply original HERE/PRIOR provenance and actual selected Stage only.

See [#88 governing current-state evidence](Setup_88_Pick_Mode_Movement_Design_2026-09-29.md#october-19-follow-up--c009-current-state-readback-resolves-prior-inference-and-exposes-mixed-show-base-problem). The historic #544 must remain auditable through an authorized targeted correction; never rewrite the original GPS/effect or mass reattach all assigned Displays.



**Operator-confirmed physical exception:** Certain Display Containers/Pallets carry several separable Displays that are unloaded at Setup, but the **pallet/base/container itself stays in the park at that Stage and becomes part of the installed display/show**. Such a Container can be `cargo empty` while still **present, in use and at its show location**. Do not mislabel it `Returned Home` or automatically route it to Workshop when all child Displays detach. Preserve its permanent Home rack for later takedown only, and retain its actual current park position as a Container observation. The carried Displays have separate installed-position evidence, linked to their applicable Setup installation tasks.

This differs from (a) transport-only pallets eligible for return only after an actual empty/receipt decision, (b) synthetic Standalone Display testing wrappers representing **one** physical unit under linked Display/Container IDs, and (c) single integral Display-Pallets whose Display can never detach. The governed current-type/flag matrix (`container_type_name`, `display_pallet`, active content count and source relationships) must be audited before an automated return recommendation or type-specific status rule; multi-Display count by itself does not establish whether the remaining base is part of the show. More details, label variance and scan reasonableness are owned by [#88 movement engineering contract](Setup_88_Pick_Mode_Movement_Design_2026-09-29.md#october-19-follow-up--verified-2026-recovery-scans-and-physical-container-role-boundaries).

**Required Stage unload UI acceptance:** Unload physically removed cargo with Stage group confirmation, leave other cargo attached and the show-base Container anchored in the park; independently verify each installed Display at actual position during its Setup task (2026 voluntarily, 2027 required by the [Crew Work Reporting contract](Setup_Crew_Work_Reporting_Contract_2026-09-08.md)). A zero-onboard-Displays total is **not** an automatic trigger to return Home. Takedown can repack that same physical base using fast scan-each confirmation under #423. This is design/acceptance scope; no present production records were changed.

## Core Rule

A mixed-Stage Container is handled at **Container + unload-scope** level, not Display-by-Display.

The normal operator flow is:

```text
open Setup -> Pick List
    -> scan CONT:<container_id> once
    -> system resolves current contents grouped by Stage
    -> operator chooses unload scope
         - one Stage
         - multiple selected Stages
         - all remaining contents
    -> confirm unload
    -> Setup records annual unload state for the selected Stage scope(s)
```

Do **not** require scanning every Display/piece carried on a shared trailer/container. High-count Containers make that operationally unreasonable.

## Why Stage-Scoped Unload Is Required

A shared trailer may be brought to the park because one Stage needs material first, while material for several later Stages remains on the trailer.

Therefore these facts are distinct:

```text
Container is at the park
Stage 17 material has been unloaded
Stage 25 material is still loaded
```

The system must not collapse those into one `container_mobilized = all contents available` assumption.

A later scheduled task for another Stage on that same Container must **not** request that the Container be pulled from the workshop again. Instead, the Pick List should surface the still-loaded Stage scope as the work that now needs unloading.

## October 19, 2026 — active 2026 field regression: Stage unload must be immediately accessible

**Operator report:** During C134 Container unloading on October 19, the "Unload by Stage" action was buried at the **bottom** of the Container's controls on Tom's tablet. Inspection of current `Setup/Application/setup_record_location.js::renderContentsDecision()` confirms the action `Displays were physically removed HERE — select Stage groups` is appended after the Empty / Not Empty / Not Sure questions, remaining-content selections and longer lists. Its Stage-ordering/access regression is source-proven; no device screenshot is required to reproduce the specific DOM ordering. Actual C134 scan/event outcome, tablet layout dimensions and operator screenshots have **not** been independently inspected.

**Controlled interaction correction:** On scanning an ordinary multi-Stage Container with at least one still-attached bulk-selectable Stage group, put the **Unload by Stage** entry **before** the physical-contents question and its potentially long submenus. Keep physical confirmation, one/multiple/all remaining Stage choices, HERE location evidence, explicit operator review, selection-preserving compact rows and all protected-Container/offline/reconciliation guards intact. **This is navigation order only, not permission to unload contents automatically.** Empty / Not Empty / Not Sure stays directly available without scrolling; don't remove the existing required stop/evidence rule. If the Container has no selectable Stage group, omit the shortcut. The initial list/recording state must still be source-driven.

**Separate LIVE location integrity incident:** Several Containers were previously unloaded incorrectly. Displays can be marked detached at the Container drop GPS instead of their actual installation positions. The user requires the **latest valid, independently captured or authorized corrected location for each physical Display** to win over older, wrong inferred/detach positions, with historical events retained. Last capture precedence must respect the event's actual capture time, reliable idempotency, offline queue chronology, and existing last-movement guard; never substitute the most recent Container scan for an already-detached Display. A mass Stage correction may capture **Stage-level confirmed placement**, but without verified per-Display coordinates it must **not manufacture exact Display GPS pins**. Preserve later genuine individual Display scans and the possibility that a Display is not yet physically installed. A scoped, Manager-audited correction of erroneous unload/attachment and affected Display locations belongs to the existing #88 Container Exceptions and Manager contents review in PR #418, **not** a direct SQL rewrite or another map GIS authority.

**Acceptance:** C134 mixed-Stage and C034/C131 trailer behavior; Stage action top-of-controls on 600px tablet; actual previously erroneous detach, later independent Display scan, offline replay, stale last-event guard, protected Standalone/Pallet and grouped HERE/PRIOR provenance. Confirm correct current records using read-only latest Production event trail before any correction. Operator screenshots in "Field Issues / Tablet 2" are not available in the current repository/chat evidence; obtain actual files before asserting full UI regression or proposing physical corrections. No Production mutation or scan-history rewrite authorized here.

## Required Tablet Interaction

After a mixed-Stage Container scan, the Pick List should present a compact touch-friendly scope picker, conceptually:

```text
Arch Trailer / Container 34
At park: YES

Remaining loaded Stage groups:
[ ] 04 Food Collection
[ ] 10 Stars
[ ] 14 Icicle Tunnel
[ ] 17 Candyland
[ ] 21 Polar Bear Playground
[ ] 25 Racing Arches

[Confirm Selected Unload]   [Unload All Remaining]
```

The exact UI is subject to browser/tablet acceptance, but the business meaning is fixed:

- one Container scan;
- Stage-group confirmation;
- optional multi-select;
- one action for all remaining contents;
- no piece-by-piece scan requirement.

For a normal single-Stage Container, the UI may collapse to a simple Container-level unload confirmation.

## Annual Execution State

Exact schema/table names are not yet accepted, but annual Setup state must be able to distinguish at least:

```text
Container not yet moved
Container moved / at park
Stage scope still loaded
Stage scope unloaded
all remaining contents unloaded
```

The state should be derived from real Setup execution events and should be correctable by an operator without DBA cleanup.

Do not change permanent `ref.display.container_id` merely because a Display has been unloaded for Setup. Permanent storage assignment and annual deployment/unload state are different concepts.

## Pick List Resolution Behavior

The resolver remains:

```text
scheduled / selected Setup work
    -> required Displays/assets
    -> current Container assignments
    -> deduplicate shared Containers
    -> show why the Container is required
```

Then annual Container/Stage unload state determines the next logistics action:

```text
Container still at workshop
    -> mobilize / move Container

Container already at park
+ required Stage scope still loaded
    -> unload that Stage scope

required Stage scope already unloaded
    -> no duplicate unload action
```

## Arch Trailer / Container 34

Container 34 is the primary proven edge case. It carries Displays for multiple Stages, including Food Collection, Stars, Icicle Tunnel, Candyland, Polar Bear Playground, and Racing Arches.

Operator-confirmed reusable planning guidance for the Arch Trailer unload operation:

```text
normal crew: 2 people
normal elapsed time: approximately 60-90 minutes
```

Historical 2025 evidence may show a different crew on a specific date. Preserve that as annual historical evidence; do not overwrite the reusable planning guidance with one historical crew count.

The Arch Trailer also has a later operational role: after its cargo is unloaded, the trailer becomes the Who House base. The Who House itself is stored elsewhere and must not be falsely assigned to Container 34 merely to express that dependency.

## Antenna Trailer and Other Mixed Containers

The same Container + Stage-scope execution model applies to the Antenna Trailer and any other Container whose contents span multiple Stages.

Do not hard-code `Arch Trailer` as a special-case algorithm. Detect mixed-Stage contents from authoritative current relationships, then apply the same unload-scope workflow.

Container-specific special roles may still need explicit relationships or rules, but mixed-Stage detection itself should be data-driven.

## Acceptance Direction

A future Pick List implementation should not be accepted until it proves:

1. a mixed-Stage Container is detected from current contents;
2. the operator scans the Container once rather than every Display;
3. the UI can confirm one Stage, several selected Stages, or all remaining contents;
4. partial unload leaves other Stage scopes visibly still loaded;
5. later scheduled work for another carried Stage generates an unload request without re-requesting workshop transport;
6. single-Stage Containers remain simple;
7. operator correction is possible without DBA intervention; and
8. the Arch Trailer normal planning guidance of 2 people / 60-90 minutes is preserved separately from historical actual crew evidence.

## Related Durable Sources

- [Setup Pick List Tablet Workflow](Setup_Pick_List_Tablet_Workflow_2026-09-09.md)
- [Setup Planning Operating Model](Setup_Planning_Operating_Model_2026-09-08.md)
- GitHub issue #122 — Setup Session planning / Pick List / movement umbrella
