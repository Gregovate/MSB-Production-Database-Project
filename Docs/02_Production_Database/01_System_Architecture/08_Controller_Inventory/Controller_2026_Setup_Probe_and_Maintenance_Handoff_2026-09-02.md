# Controller 2026 Setup Probe and Maintenance Handoff — 2026-09-02

| Item | Value |
|---|---|
| Status | CURRENT IMPLEMENTATION / ACCEPTANCE HANDOFF |
| Issue | #110 |
| Draft PR | #111 |
| Branch | `agent/controller-inventory-ref-sandbox` |
| Exact application candidate | `1eea0ba437f7e4337e075b769c137ffe032dc27b` |
| Production application baseline | `e9ab029a17067b38b34f9306069f54899925f73f` |
| Production maintenance migrations | 021/022 only; 023/024 are candidate-only |
| Setup priority | Controller planning/probing plus browser maintenance |

## Purpose

Preserve the exact setup-season implementation boundary and acceptance resume point for Controller Inventory. The immediate operational goal is to let a qualified MSB operator determine usable Controller capacity before building a new Display in LOR, then maintain the resulting physical Controller inventory and Controller-to-Display relationships without raw SQL or tribal knowledge.

This handoff supplements the current [Controller Capacity and UID Planning Contract](Controller_Capacity_and_UID_Planning_Contract_2026-09-02.md). That contract remains the design authority for Stage capacity, Network-scoped UID usage, repeated-address behavior, contiguous UID planning, and Controller-vs-LOR comparison.

## 2026 Setup Boundary — Do Not Block on GPS / Full Network Topology

A complete machine-readable park/network reachability model is **not required for 2026 setup**.

Current physical Network topology still exists in the established engineering maps and other Network Infrastructure source material. The Controller planner therefore must not claim that current database/LOR evidence proves which Networks are physically reachable at every Stage.

For this season the accepted operator boundary is:

```text
Stage selection
    -> application shows Networks currently used by that Stage
    -> application shows current Controller/channel/UID evidence
    -> operator may select another Network to probe
    -> if that Network is not currently used by the Stage,
       operator confirms physical reach using the existing park/network map
```

The UI wording must say **Networks currently used by this Stage**, not **Networks available at this Stage**.

GPS/site/network topology may replace or enrich this manual map check in a later system phase. GPS work for 2026 is expected, if implemented, to focus first on Stage/location tracking rather than becoming a prerequisite for Controller planning.

## `Regular` Network Rule

`Regular` is the known park-wide exception in the current operating model:

- it is split/distributed throughout the park;
- it is slow speed;
- it is used primarily for background sequences.

The planner may therefore identify `Regular` as park-wide, but it must not automatically recommend it as a generic fallback Network for a new Display merely because it is physically reachable.

The operator still decides whether `Regular` is appropriate for the intended Display/show behavior.

## Pre-Build Planning Workflow

The required 2026 workflow is:

```text
new Display idea
    -> select intended Stage / Sub-stage
    -> inspect existing physical Controllers assigned into that Stage
    -> inspect current LOR Network / UID / channel use
    -> inspect directly supportable explicit SPARE channel capacity

if sufficient spare channels exist:
    -> plan the new Display on those channels

otherwise:
    -> select the Network to investigate
    -> confirm physical reach from existing map when needed
    -> select intended Controller model
    -> find unused single UID or contiguous UID block on THAT Network
    -> overlay AVAILABLE physical Controller stock / retained programming
    -> choose Network + UID/range + channel plan

then:
    -> author the Display in LOR Preview
    -> parse / ingest / reconcile through normal V7 workflow
    -> assign permanent controller_id to permanent display_id
    -> compare physical current programming vs current LOR requirement
    -> physically program / verify Controller explicitly
```

Network + UID is one address context. A UID used on one Network does not consume the same UID on another Network.

## Current Candidate — Probe

The exact candidate `1eea0ba437f7e4337e075b769c137ffe032dc27b` adds a Manager/Admin-only **Plan Capacity** workflow to the Controller browser.

### Stage capacity

For a selected permanent Stage/Sub-stage it:

- resolves the Stage's valid current FieldWiring Preview/Scene contexts through the existing `/api/stages` resolver contract;
- unions/deduplicates current wiring evidence across those contexts;
- shows Networks currently used by the Stage;
- shows permanent physical Controllers currently assigned through Displays in that Stage;
- shows each Controller's recorded current Network/UID range and assigned Displays;
- shows current LOR wiring-row coverage for those physical relationships;
- shows directly attributable explicit SPARE rows and exact UID/channel where the evidence is supportable;
- refuses to guess which physical Controller owns a SPARE when multiple physical Controllers intentionally share the same Network/UID address.

### Network / UID probe

For an explicitly selected Network and Controller model it:

- evaluates numeric LOR UID usage only inside that selected Network;
- overlays current physical Controller programming separately;
- treats intentional repeated Network/UID programming as valid;
- uses model `lor_uid_capacity` to search sequential UID blocks;
- searches the governed `01` through `F0` address range;
- excludes blocks already consumed by current approved LOR/V7;
- excludes blocks overlapping non-AVAILABLE physical Controller programming;
- surfaces AVAILABLE physical Controller overlaps as useful stock/planning evidence rather than silently rejecting them;
- highlights compatible AVAILABLE same-model stock where supportable;
- warns when the selected Network is not currently used by the selected Stage and instructs the operator to confirm physical reach on the existing map;
- applies the special `Regular` park-wide/slow/background guidance.

The probe is read-only. It does not issue Controller write commands and does not write LOR/V7.

## Current Candidate — Maintenance

The same exact candidate provides browser-native Manager/Admin maintenance:

- Add Controller with PostgreSQL-generated permanent `controller_id`;
- zero Display assignments valid;
- new Controller may have no Network/UID/IP programming recorded;
- Edit Controller model/status/location/hardware/serial/year/notes/verification;
- maintain current Network/First UID/UID Count/IP programming;
- maintain installed firmware and verification state/history;
- assign one Controller to one or many Displays;
- assign one Display to one or many Controllers;
- edit relationship notes / placement note;
- reviewed `wiring_source_display_id` support;
- atomic Display replacement/reassignment;
- unassign without deleting the Controller asset;
- optional final `DEPLOYED -> AVAILABLE` transition;
- REPAIR/RETIRED assignment guard;
- Display-assignment-capability guard for managed devices that do not drive Displays.

The browser maintenance writes use narrow PostgreSQL `SECURITY DEFINER` commands. `fieldwiring_app` remains without broad Controller table DML.

## Assignment Planning Context

The assignment editor is no longer intended to be a blind relationship insert.

For a selected Controller/Display it shows read-only comparison states:

```text
MATCH
MISMATCH
UNPROGRAMMED
REVIEW_REQUIRED
```

It displays:

- physical Controller recorded current Network/UID range;
- selected Display's current numeric LOR Network/UID evidence where resolvable;
- other physical Controllers recorded on the same Network/UID range.

Assignment does **not** automatically rewrite physical Controller programming and does **not** rewrite LOR/V7. Repeated addresses remain valid and visible.

## SPARE Authority / Known Limitation

`ref.spare_channel` is historical and is not maintained by the current approved P2 reconciliation design. It is therefore not the live setup-planning authority.

The current probe derives SPARE evidence from current approved LOR/V7 materialization.

For the first 2026 implementation, automatic Stage attribution of an explicit SPARE is accepted only when the current Preview itself resolves directly to that Stage. Shared/master Preview SPARE attribution is deliberately left review-required instead of guessed.

This limitation is acceptable for initial probing provided the UI does not overstate the result.

## Database Candidate

Candidate migrations not yet installed in production:

```text
Controllers/Database/023_create_controller_management_commands.sql
Controllers/Database/024_harden_controller_assignment_capability.sql
```

023 provides the narrow Add/Edit/assignment command family and Manager reference lookup.

024 hardens assignment/reassignment so a model with `display_assignment_capable = false` cannot receive a new Display relationship. Unassign remains available for cleanup.

## Acceptance Gate

No production mutation is authorized merely because the candidate exists.

The current acceptance entry point is:

```text
Controllers/Acceptance/run_controller_setup_probe_disposable_acceptance.ps1
```

It performs one bounded workflow:

1. pins the exact application candidate `1eea0ba437f7e4337e075b769c137ffe032dc27b`;
2. creates a detached candidate worktree on `msb-prod-db`;
3. runs the shared FieldWiring + Procedures pytest suite against that exact candidate;
4. performs a read-only planner-data/permission probe against current production;
5. verifies current LOR numeric UID data, Controller programming, Stages, `Regular` evidence, and multi-UID model capacity are available;
6. executes the direct-stage SPARE attribution query without requiring a nonzero count;
7. restores a current production dump into an isolated disposable PostgreSQL container;
8. applies candidate migrations 023 followed by 024 in that disposable clone only;
9. exercises Add/Edit/programming/duplicate-address/fixed-count/M:N/reassign/unassign/REPAIR lifecycle behavior;
10. verifies production Controller fingerprint is unchanged.

Production Controller data is not mutated by this acceptance gate.

## Exact Resume Point

Before production deployment:

1. run the one-command setup probe / disposable acceptance wrapper;
2. review any planner/SPARE/permission findings rather than weakening the contract to force a pass;
3. if it passes, prepare a new production deployment package governed by the current MSB-Server-Management Production Database deployment runbook;
4. deploy migrations 023/024 plus the exact accepted application candidate only after explicit approval;
5. perform live browser acceptance for Plan Capacity, Add Controller, Edit Controller, and assignment comparison;
6. use deliberate real Controller/Display changes for production acceptance rather than arbitrary destructive test mutations;
7. complete operator procedures against the accepted live screens;
8. only then prepare PR #111 for final merge to `main`.

Do not use the older Controller Print Label production deployment runner for migrations 023/024; it is a historical deployment artifact pinned to the earlier 021/022 target.
