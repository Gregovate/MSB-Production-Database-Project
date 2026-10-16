# Controller Capacity and UID Planning Contract — 2026-09-02

| Item | Value |
|---|---|
| Status | CURRENT ACCEPTED PLANNING CONTRACT |
| Issue | #110 |
| Scope | Pre-build Display planning / Controller Inventory / LOR-V7 integration |
| Permanent physical identity | `ref.controller.controller_id` |
| Show wiring/address authority | Current approved LOR/V7 snapshot |
| Physical current-programming authority | `ref.controller` |

## Purpose

Eliminate tribal knowledge required to decide how a new Display should be controlled **before the Display is added to an LOR Preview**.

MSB has grown to the point where finding usable controller capacity, spare A/C channels, and an available LOR Unit ID or contiguous Unit-ID range can require significant manual investigation by the few people who know where to look. That knowledge must become a repeatable browser workflow rather than remain dependent on one operator.

The Controller application therefore needs a planning/probing workflow that answers, in order:

1. Does the intended Stage already have usable spare channel capacity on an existing physical controller?
2. If not, which LOR Network is appropriate for that Stage/current wiring context?
3. Which Unit IDs or contiguous Unit-ID ranges are unused by the current approved LOR/V7 show configuration on that Network?
4. Are any available physical controllers already programmed compatibly with a candidate address/range?
5. What Controller model/capacity is required before the new Display is authored in LOR?

This planning workflow occurs **before** the eventual Controller-to-Display assignment workflow.

## Two Different Meanings of Spare

Do not conflate these concepts:

### Spare physical Controller

A permanent Controller Inventory asset with no current Display assignment, normally status `AVAILABLE`.

Example:

```text
CTRL 1201
Model: CTB32
Status: AVAILABLE
Display assignments: none
Current programmed Network/UID: may be blank or may retain old programming
```

### Spare channel capacity

An output/channel represented by the current approved LOR/V7 show configuration as available/SPARE within an existing controller/address context.

A deployed physical controller may therefore serve existing Displays **and** still have spare channels that could support a small additional Display.

The Controller application must present both kinds of spare capacity but label them distinctly.

## Planning Order

The normal new-Display planning sequence is:

```text
new Display idea
    -> choose intended Stage / Sub-stage
    -> inspect Stage controller/channel capacity
    -> reuse suitable explicit spare channels when practical
    -> otherwise inspect the intended LOR Network
    -> find an unused Unit ID or sufficiently large contiguous Unit-ID range
    -> choose/add the physical Controller
    -> determine Network + UID/range + channel/output plan
    -> author the new Display in LOR Preview
    -> parse / ingest / reconcile through the normal LOR/V7 workflow
    -> assign the permanent controller_id to the new permanent display_id
    -> compare physical current programming with current LOR-required programming
    -> program/verify the physical Controller explicitly
```

Controller assignment must not be used to invent the LOR design before this planning work is complete.

## Stage Capacity View

The first planning view is Stage-centered.

For the selected Stage/Sub-stage, show physical Controller contexts that can be resolved through current Controller-to-Display relationships together with current LOR wiring/channel use.

Conceptually:

```text
Stage 17 — Candyland

CTRL   Model   Network   UID/range   Displays served       Used channels   Explicit spare
1102   CTB32   Aux E     80          Display A, Display B  12              4
1103   CTB32   Aux E     81          Display C             15              1
1134   Pixie4  Aux N     30-33       Candy Canes 1-4       pixel outputs    n/a
```

Where channel-level attribution is supportable, the operator must be able to expand one Controller context and see the actual available channels.

Example:

```text
CTRL 1102 — Aux E / UID 80

Used
  Ch 01  Display A
  ...
  Ch 12  Display B

Explicit SPARE
  Ch 13
  Ch 14
  Ch 15
  Ch 16
```

This allows the operator to decide that a small new Display can use existing controller capacity without consuming another Unit ID.

## Spare-Channel Authority

Current approved LOR/V7 is the authority for current wiring, Network, UID, channels/outputs, and SPARE state.

`ref.spare_channel` is not the current planning authority merely because it exists historically. Current reconciliation design deliberately does not maintain that table as part of normal P2 Display reconciliation. The planning view must therefore derive current channel/SPARE facts from the approved current LOR/V7 materialization unless/until a separately governed spare-channel synchronization design is accepted.

Do not silently classify every numerical gap as an explicit spare.

Use distinct states when possible:

```text
EXPLICIT_SPARE
    current LOR/V7 evidence identifies the channel/output as SPARE

UNUSED_GAP
    no current LOR/V7 use is resolved for the address/channel, but it is not explicitly marked SPARE

USED
    current LOR/V7 wiring consumes it

REVIEW_REQUIRED
    physical-controller attribution or wiring context is not supportable without review
```

An `UNUSED_GAP` may be useful planning evidence but must not be presented as equivalent to an explicitly maintained SPARE channel unless the governing LOR semantics support that conclusion.

## Network Unit-ID Usage View

When the intended Stage does not have sufficient reusable capacity, the operator must be able to inspect a selected LOR Network across the current approved show.

Conceptually:

```text
AUX E — CURRENT UNIT-ID USAGE

UID/range   LOR use                  Physical Controller(s)
01          USED                     CTRL 1010
02          USED                     CTRL 1011
03          UNUSED_BY_LOR            —
04          UNUSED_BY_LOR            —
22          USED / SHARED            CTRL 1041, 1042, 1043 ...
80          USED                     CTRL 1102
81          USED                     CTRL 1103
82          UNUSED_BY_LOR            CTRL 1190 AVAILABLE, currently programmed Aux E / 82
```

The LOR usage and physical-programming columns answer different questions and must remain separate.

### LOR/V7 usage

Answers:

> Does the current approved show configuration already consume this Unit ID/range on this Network?

### Controller Inventory programming

Answers:

> Which permanent physical Controllers are currently recorded as programmed to this Network/UID/range?

A Unit ID can therefore be unused by the current show while an AVAILABLE shelf Controller still retains that programming from prior use.

## Intentional Shared Addresses

Repeated Network/UID values are valid and must never become a uniqueness error.

Known accepted cases include Highway 42 traffic signs and the Church/Candyland Candy Cane controller groups.

The planning view should identify shared current use, for example:

```text
Regular / UID 22
LOR state: USED / SHARED
Physical Controllers:
    CTRL ...
    CTRL ...
    CTRL ...
```

Do not collapse these permanent physical assets or reject them merely because the address is repeated.

## Contiguous Unit-ID Planning

Some Controller families consume more than one sequential LOR Unit ID. Finding an individual unused UID is therefore insufficient.

The planner must support a **contiguous Unit-ID block search** driven by the selected Controller model's governed addressing/capacity rule.

The current permanent model already contains machine-readable LOR capacity metadata, including:

```text
ref.controller_model.lor_uid_capacity
ref.controller_model.lor_uid_requires_full_capacity
```

For a model requiring its full capacity, the planner must find a contiguous unused block of exactly that width in the selected Network.

Examples of accepted fixed-range behavior include:

```text
CCB100   -> 2 contiguous UIDs
Pixie4D  -> 4 contiguous UIDs
Pixie8D  -> 8 contiguous UIDs
Pixie16D -> 16 contiguous UIDs
```

The planner must not simply list free individual IDs when the selected model requires a block.

Conceptually:

```text
Network: Aux N
Controller model: Pixie8D
Required contiguous Unit IDs: 8

Candidate blocks:
    40-47   AVAILABLE_BY_CURRENT_LOR
    58-5F   AVAILABLE_BY_CURRENT_LOR

Rejected gaps:
    20-26   only 7 consecutive IDs
    70-78   interrupted by current use at 74
```

Unit IDs are stored/compared numerically and rendered to the operator in uppercase hexadecimal.

The current permitted LOR Unit-ID range remains the governed database range `01` through `F0`.

## Candidate-Block Safety Rules

A candidate contiguous block means only:

> the current approved LOR/V7 show does not consume any Unit ID in the proposed block on the selected Network.

It does **not** mean:

- no physical Controller is currently programmed there;
- the physical Network has unlimited bandwidth/capacity;
- the selected Stage is automatically the correct network destination;
- the block should be written into LOR automatically.

The planner should therefore show physical Controller programming conflicts/overlaps alongside the LOR availability result.

Example:

```text
Candidate Aux E / 82
LOR current use: UNUSED
Physical Controller programming:
    CTRL 1190 AVAILABLE — currently Aux E / 82

Planning implication:
    candidate address remains available to the show and may already have a compatible spare physical Controller
```

## Controller Assignment Consequence

The eventual Controller-to-Display assignment screen must consume the planning/current-LOR information rather than merely insert a relationship.

For an assignment candidate, show:

```text
physical Controller current programming
current LOR/V7 required programming for the selected Display
MATCH / MISMATCH / UNPROGRAMMED / REVIEW_REQUIRED
other physical Controllers recorded on the same Network/UID/range
```

Assignment itself must not silently rewrite Controller programming and must not rewrite LOR/V7.

A newly purchased Controller may legitimately be created with no Network or UID. Its permanent `controller_id` exists before programming.

## Tribal-Knowledge Elimination Goal

The planning workflow is accepted only when another qualified MSB operator can determine, without relying on private knowledge of the show design:

- which controllers serve a Stage;
- which of those have reusable spare channel capacity;
- the exact spare channels when supportable;
- which Network the current Stage wiring uses;
- which Unit IDs/ranges are currently consumed on that Network;
- which addresses are intentionally shared;
- which contiguous UID blocks can support a selected multi-UID Controller model;
- whether compatible AVAILABLE physical Controller stock exists; and
- the Network/UID/channel plan that should be used when the new Display is subsequently authored in LOR.

The application should make the reasoning visible rather than return only a single recommended number.

## Implementation Priority

This planning/probing layer is a prerequisite to declaring the Controller assignment workflow setup-ready.

Current priority becomes:

1. Stage Controller/channel capacity view;
2. current LOR/V7 explicit-SPARE and channel-use resolution;
3. Network UID/range utilization view;
4. model-aware contiguous UID-block finder;
5. AVAILABLE physical Controller overlay;
6. Controller-vs-LOR MATCH/MISMATCH/UNPROGRAMMED presentation;
7. then final acceptance of Add/Edit/Assign/Reassign/Unassign workflows.

Do not proceed to production acceptance of the simplified assignment UI until this planning context is available or the remaining gaps are explicitly accepted.

## 2026-10-16 — Network-first UID explorer correction (draft candidate)

Operator-accepted correction under #110/#111, governed by #122. This is a proposed
application change, **not** Production acceptance or deployment.

- Select a Network and inspect the complete hexadecimal 01–F0 UID inventory,
  regardless of Controller model. Search a UID or filter the inventory without
  changing the underlying Network-wide occupancy calculation.
- Show current LOR/V7 usage and Display names separately from recorded physical
  Controller programming and status. "Unused by LOR" is not proof an address
  has no physical programming conflict.
- The optional Controller model only determines contiguous-block width through
  governed `lor_uid_capacity`; it must not filter the base UID inventory.
  List all conflict-free candidate ranges instead of silently truncating at 24.
- Normalize Network **identity** case-insensitively throughout the planner:
  `Regular` and `regular` refer to one address space, displayed as `Regular`.
  Preserve raw source spelling and do not silently rewrite LOR/V7 or database
  rows. A separate read-only source audit is still needed to determine whether
  reference data contains inconsistent spellings.
- The Stage panel remains separate. The earlier limits on physical spare
  attribution, reachability, and LOR/physical authority remain unchanged.

Implementation checkpoint: isolated draft branch
`fix/controller-network-uid-explorer-20261016` from
`main` `b2d5f8c2f202b228a180bd950187718937c41019`.
No Production mutation, schema change or deployment. Executable regression,
disposable-browser acceptance, concurrent-main reconciliation and Greg's
operator review are still required.

## 2026-10-16 — E1.31/DMX boundary correction in draft PR #406

The operator reproduced a false Regular/39 entry for `TR-MegaTreeRGBTree`
alongside `WW-ClarkGriswold`, while permanent CTRL 1177 legitimately
records only `WW-ClarkGriswold` assigned at Regular/39. The accepted
FieldWiring dense RGB contract states that `device_type=DMX` may represent
E1.31 universes in the legacy compatibility wiring view; that `controller`
value is **not** an LOR UID.

The read-only Controller planner's network-wide UID and explicit Stage SPARE
queries must exclude `device_type=DMX` compatibility rows from LOR UID
occupancy, regardless of whether the controller value resembles a hex UID.
Do not modify the FieldWiring viewer, LOR/V7 snapshots, Controller assignment,
or E1.31/DMX physical wiring presentation. Mixed/unknown device semantics
remain a review concern, not grounds for guessing a free UID.

This correction is committed to draft PR #406 but has not passed actual
current-production-clone/browser acceptance. Previously running disposable
browser sessions remain pinned to their earlier SHA and will **not**
automatically reflect these changes.

## 2026-10-16 — Pixie contiguous-range visibility in draft #406

Operator browser finding: selecting Pixie4D did not visibly expose candidate
four-UID ranges because the planner rendered the full 240-UID inventory first.
The draft now renders the optional model-aware contiguous block results **above**
the inventory, includes the number of candidate starting addresses and bounds
its block list with independent scrolling. The Network inventory remains
model-independent. Requires fresh exact-candidate browser acceptance; do not
interpret source correction as deployed or accepted behavior.

## 2026-10-16 — Individual vs contiguous UID presentation

Operator screenshots of the Controller planner showed that PixCon16 was listed as
one UID in the governed model metadata, while Pixie2D/4D/8D use multi-UID
blocks. Physical output/channel count must not be confused with LOR UID width.
The draft #406 browser now labels one-UID choices as **Available individual UIDs**
in a compact grid; models with width greater than one retain contiguous block
ranges. The UID availability rules and model metadata were not changed.
Exact-candidate regression/browser acceptance of this presentation is pending.

## Post-2026 Season — PixCon16 Dual Addressing / E1.31 Capacity (DEFERRED)

Operator-confirmed engineering requirement (2026-10-16): a PixCon16 may legitimately
operate on a traditional **LOR Network** or by **IP address on E1.31**. Neither
mode should be globally inferred from the model name alone. The observed
`lor_uid_capacity=1` entry is not a universal definition of the model's
E1.31 addressing or its 16 physical outputs.

For post-season planning, investigate a separate E1.31/IP capacity view that
shows each actual physical Controller, IP address, recorded addressing mode,
and the DMX universes/ranges it consumes. Identify overlaps and free universe
capacity without translating universes into traditional LOR Unit IDs. Anticipate
potential addition of **three more E1.31 addresses/controllers**, but do not
allocate IP addresses or universe ranges without current network design evidence.
Reconcile physical inventory/programmed facts with the authoritative LOR/V7
DMX/universe topology and the existing FieldWiring dense-RGB interpretation.

This is **deferred work, not an unfinished gate for the 2026 Network UID
planner correction**. Keep the current FieldWiring Viewer behavior, existing
Controller identities, physical assignments and LOR/V7 source data unchanged.
Revisit after the 2026 season under the existing Controller Inventory issue
authority, with a separate accepted design and testing gate before implementation.
