# FieldWiring / Controller Inventory Handoff — 2026-08-20

| Item | Value |
|---|---|
| Status | ENGINEERING HANDOFF — durable cross-workstream contract |
| FieldWiring branch | `agent/fieldwiring-engineering-recovery` |
| FieldWiring ownership | Browser wiring presentation and consumption of controller relationships |
| Controller Inventory ownership | Permanent physical controller identity and current assignment for the current approved LOR/V7 snapshot |
| Schema status | FieldWiring does not own or authorize Controller Inventory schema changes |

## Purpose

This note is the durable handoff between the FieldWiring engineering-recovery workstream and the separate Controller Inventory workstream. It exists so controller requirements discovered during FieldWiring browser acceptance are available from the repository rather than depending on conversation memory.

The Controller Inventory workstream should inspect its own source artifacts and design its eventual PostgreSQL model from evidence. FieldWiring findings below are consumer requirements and confirmed physical/topology observations; they are not a substitute for Controller Inventory source inspection.

## Authority Boundary

- LOR is authoritative for show topology, addressing, and current wiring relationships.
- PostgreSQL owns permanent Production Database identities and operational relationships.
- `ref.display.display_id` is permanent Display identity; LOR Prop UUID / `lor_prop_id` is an external binding.
- Google Shared Drive `Display Folders` remains the engineering document/image authority used by FieldWiring.
- FieldWiring does **not** own the Controller Inventory schema.
- Controller Inventory must eventually provide permanent physical controller identity plus the **current assignment relationship that applies to the current approved LOR/V7 snapshot**.
- FieldWiring does **not** require historical controller deployment relationships.

Permanent physical controller identity must **not** be based on:

- LOR Unit ID or Unit-ID range;
- E1.31 universe;
- IP address;
- Display name;
- physical location alone.

Pixie controllers may deliberately reuse Unit-ID ranges. One E1.31 controller may span many universes, and one Display may use multiple physical controllers.

## Current-State Assignment Scope

FieldWiring needs to answer a current operational question:

> Which permanent physical controller is assigned to the wiring relationships in the current approved LOR/V7 snapshot?

The controller itself has permanent identity. Its deployment/address assignment is current-state data.

There is no FieldWiring requirement to preserve each prior controller deployment as historical relationship rows. Controller assignments change infrequently. When they do change, the Controller Inventory current assignment can be reconciled to the newly approved current snapshot.

Older LOR snapshots and preserved source artifacts may remain available as engineering evidence, but Controller Inventory does not need to duplicate that evidence as deployment-history relationships merely for FieldWiring.

No schema design is implied here. The Controller Inventory workstream still owns the eventual PostgreSQL model and must derive it from inspected source evidence.

## Controller Inventory Return Handoff — Current Plan

Controller Inventory source review has now established a current engineering direction that FieldWiring can design toward while the physical data is still being corrected.

The controlling plan is:

- [Controller Inventory Current-State / FieldWiring Integration Plan — 2026-08-20](../08_Controller_Inventory/Controller_Inventory_Current_State_FieldWiring_Integration_Plan_2026-08-20.md)

Confirmed direction from that workstream:

- permanent physical controller identity remains independent of LOR addressing;
- controller assignment is current-state only and is reconciled to the current approved LOR/V7 snapshot;
- no historical controller deployment relationship is required;
- firmware update history belongs to Controller Inventory;
- repairs/maintenance belong to Work Orders linked to the permanent controller asset;
- Controller Inventory should not manually duplicate every Display/output relationship already available from the current LOR snapshot;
- a unique current Network + Unit ID/range can normally associate one physical controller to the LOR wiring rows using that address;
- intentional duplicate addresses require one additional distinguishing physical group, for example `Candy Canes 1-4`, `Candy Canes 5-8`, and `Candy Canes 9-12`;
- exact hardware models remain distinct (`PixCon16` and `Pixie-16` are different devices); and
- Stage/Scene or another simple physical context is sufficient during ordinary data cleanup unless a duplicate-address/ambiguous case needs a more specific Display group.

### FieldWiring implementation consequence

FieldWiring development does **not** need to stop while the controller data is being reviewed.

However, temporary named/hard-coded physical mappings must remain an isolated bridge rather than becoming the permanent architecture.

FieldWiring should converge on a replaceable controller-resolution boundary/provider that can eventually consume a PostgreSQL Controller Inventory read interface supplying, conceptually:

```text
permanent controller identity
exact controller model/family + physical capability
current controller address/context
optional duplicate-address distinguishing group
current approved LOR/V7 snapshot provenance
```

The LOR/V7 snapshot continues to supply the detailed current Display/output wiring rows. Controller Inventory supplies the physical-controller identity/context that LOR cannot encode.

Do not spread new Display/Scene-specific controller assumptions through rendering code merely because the authoritative Controller Inventory data is not ready yet. If a temporary accepted physical mapping is still required for recovery/acceptance, keep it centralized and replaceable by the future controller resolver.

## Temporary FieldWiring Recovery Rules

The current FieldWiring recovery classifier contains some named, operator-confirmed runtime rules for known Displays/Scenes. This is acceptable as a temporary bridge while Controller Inventory is not yet authoritative.

Those rules are **presentation recovery logic**, not permanent controller identities. They must not be interpreted as the Controller Inventory data model.

Named examples in FieldWiring tests/runtime currently include Church, Candyland, Who Forest, and Santa's Workshop controller patterns. Tests may freely use exact Display/Scene names as acceptance fixtures. Runtime named rules should remain limited to explicitly reviewed physical patterns and should be replaced by authoritative Controller Inventory current-assignment relationships when that subsystem is ready.

## Confirmed Consumer Requirements

### Reused Pixie Unit IDs

Repeated RGB Unit IDs across separate operator-confirmed physical Displays can be positive evidence of multiple physical Pixie controller instances. Reused addresses must not be treated as permanent physical identity and must not be "fixed" merely because they repeat.

### Physical Grouping vs Current Snapshot Output Mapping

A known physical controller grouping and the current snapshot output relationships inside that controller are separate concerns.

FieldWiring may preserve an operator-confirmed physical controller group while still displaying the exact current snapshot wiring relationships inside that group. FieldWiring must not silently rewrite stale LOR topology outside the normal controlled parser/import cycle.

This also means a physical output may legitimately show more than one Display/connection relationship when the current source topology says so.

### Unknown Physical Detail

When the controller context is known but the exact physical model/output mapping is not established, FieldWiring should preserve the known controller context without inventing the missing physical fact. Unknown output may be shown as `—`; this is different from an unresolved grouping that genuinely requires review.

## Confirmed Examples

### Church RGB Tree Star

`CH-RGBTree-Star` is a controller context separate from `CH-RGBTree-16x100-180`.

Confirmed from operator inspection of the LOR Prop Definition:

- Network: `Aux N`;
- LOR Unit-ID span: `40-41`;
- not part of the Tree Pixie 16 at `30-3F`;
- exact physical Pixie model/output count is not yet established from authoritative physical evidence.

FieldWiring therefore presents a separate known controller context and does not attach the Star to Tree Output 16.

See `FieldWiring_Church_RGB_Tree_Star_Controller_Context_2026-08-20.md`.

### Church RGB Candy Canes

Eight Candy Canes use two physical Pixie 4 controllers. Each controller intentionally uses Unit IDs `21-24` and Outputs 1-4.

### Candyland RGB Candy Canes

Twelve Candy Canes use three physical Pixie 4 controllers, each intended to use Unit IDs `21-24` and Outputs 1-4.

The current development snapshot predates an LOR correction and still contains:

```text
Candy Cane 09 -> 21
Candy Cane 10 -> 22
Candy Cane 11 -> 23
Candy Cane 12 -> 22
```

The live Preview was corrected so Candy Cane 12 now uses `24`, but no new controlled snapshot has been imported yet.

For the stale snapshot, FieldWiring must still present the known third Pixie 4 controller while preserving the current snapshot hookup relationships:

```text
Pixie group 3
  Output 1 -> CL-RGBCandyCane-09
  Output 2 -> CL-RGBCandyCane-10
              CL-RGBCandyCane-12
  Output 3 -> CL-RGBCandyCane-11
  Output 4 -> no current snapshot relationship
```

After a refreshed snapshot contains the corrected `24`, the same controller naturally becomes Outputs 1-4 with Cane 12 on Output 4.

See `FieldWiring_Candyland_Stale_Snapshot_Output_Mapping_2026-08-20.md`.

### Candyland RGB Lollipops

The reviewed current topology is one Pixie 16 presentation spanning Unit IDs `50-5B` with twelve physical outputs across the eight Lollipop Displays. This is a FieldWiring accepted pattern, not a permanent controller identity record.

### Who Forest

Eight reviewed Pixie 8 groups use the ranges `50-57`, `58-5F`, `60-67`, `68-6F`, `70-77`, `78-7F`, `80-87`, and `88-8F`. Corresponding RGB Stars are accepted shared-controller relationships in the current FieldWiring presentation. A known source conflict remains for Tree 4 network assignment (historical inventory vs current V7); it must not be silently reconciled.

### E1.31 / Dense RGB

E1.31 universes are addressing, not physical controller identity. A single physical controller may span many universes. FieldWiring must not infer controller count merely from compatibility/universe rows.

## Current Branch Implementation Status

At the time this handoff was written, the branch contains the Candyland stale-snapshot presentation change, but the full automated gate is **not yet green**.

Observed laptop test result:

```text
1 failed, 22 passed
```

Failing test:

```text
FieldWiring/Application/test_wiring.py::test_inconsistent_repeated_block_preserves_good_groups_and_flags_bad_block
```

Cause identified during review:

- the temporary stale-Candyland exception currently keys on the `CL-RGBCandyCane` series/shape without also requiring the actual Candyland Scene;
- the older safety test intentionally places a similar inconsistent series in a synthetic non-Candyland Scene and expects the bad block to fail safe;
- therefore the Candyland stale-source exception must be scoped to the actual `17-Candyland-CL` context while generic inconsistent repeated blocks must continue to require review.

This is an **implementation defect**, not a change to the consumer contract above. Do not treat the current branch head as acceptance-ready until the test gate is green again.

## Controller Inventory Integration Direction

When Controller Inventory becomes authoritative, FieldWiring should consume permanent controller identity plus the controller's **current assignment for the current approved snapshot**, rather than relying on temporary group labels such as `Pixie group 1/2/3` or named recovery rules.

Controller Inventory should be able to represent, without violating identity rules:

- multiple physical Pixie controllers carrying the same programmed Unit-ID range in the current snapshot;
- one physical controller spanning multiple addressing rows/ranges;
- one Display connected through more than one physical controller where applicable;
- the current assignment of each controller to the current approved snapshot topology; and
- known controller identity even when addressing or deployment is later changed and the current assignment is updated.

A historical deployment-relationship model is **not required** for FieldWiring.

FieldWiring will remain a consumer of that model; it should not redefine Controller Inventory ownership in order to satisfy browser presentation needs.

## Related Documents

- [Controller Inventory Current-State / FieldWiring Integration Plan — 2026-08-20](../08_Controller_Inventory/Controller_Inventory_Current_State_FieldWiring_Integration_Plan_2026-08-20.md)
- [Controller Inventory](../08_Controller_Inventory/README.md)
- `FieldWiring_Physical_Controller_Output_Presentation_Contract.md`
- `FieldWiring_RGB_Controller_Pattern_Findings_2026-08-19.md`
- `FieldWiring_Church_RGB_Tree_Star_Controller_Context_2026-08-20.md`
- `FieldWiring_Candyland_Stale_Snapshot_Output_Mapping_2026-08-20.md`
- `FieldWiring_Accepted_Baseline_Recovery_2026-08-20.md`
