# FieldWiring Wiring-Snapshot Assembly-Required Contract — 2026-08-21

| Item | Value |
|---|---|
| Status | OPERATOR-CONFIRMED DESIGN DECISION |
| Sub-project | FieldWiring |
| Scope | MSB-owned wiring relationship enrichment preserved with wiring snapshots |
| Schema status | Concept/field contract accepted; exact table, relationship key, migration, and UI workflow still require design/review |

## Purpose

This contract defines the MSB-owned operational wiring attribute that distinguishes a connection which must be assembled during normal park setup from a connection which is already assembled/prewired.

Light-O-Rama does not provide a controlled place for this MSB operational fact. The value must therefore remain independent of the LOR XML/parser contract so a future LOR XML change or parser redesign cannot erase or redefine the MSB setup decision.

The wiring topology itself remains LOR-authoritative where LOR supplies it. This contract adds an operational annotation to the resolved wiring relationship; it does not create a second independent topology-authoring system.

## Accepted Boolean

The accepted conceptual field is:

```text
assembly_required_at_setup BOOLEAN NOT NULL DEFAULT FALSE
```

Meaning:

```text
FALSE
    -> the wiring relationship exists and remains part of FieldWiring
    -> the connection is normally already assembled/prewired at park setup
    -> normal setup does not require making that connection

TRUE
    -> the wiring relationship exists and remains part of FieldWiring
    -> the connection must normally be assembled/connected during park setup
```

`FALSE` must never mean that the wiring is hidden, discarded, or technically unimportant.

## Grain — Wiring Relationship, Not Display

The boolean belongs at the wiring-relationship/connection level.

It must **not** be a single flag on `ref.display`, because one Display can contain different connection types with different setup requirements.

Examples include Lollipop-related wiring where RGB Lollipop heads and Lollipop sticks can have different physical setup behavior while remaining related to the same broader installation context.

Likewise, dense-RGB Displays can contain internal prewired connections and externally assembled connections without requiring additional `ref.display` identities.

Conceptually:

```text
Display
    -> wiring relationship A
         assembly_required_at_setup = false
    -> wiring relationship B
         assembly_required_at_setup = true
```

The exact persisted relationship key is not yet authorized by this document.

## Source-Family Independent

This attribute is not DMX-specific.

It may apply to wiring relationships derived from or associated with:

```text
Traditional LOR / A/C
LOR RGB / Pixie
DMX / DumbRGB
DMX / E1.31 dense RGB
```

The wiring family determines how the topology is interpreted and presented. The assembly flag determines whether that particular physical connection normally has to be made during setup.

## Ownership Boundary

### LOR / parser owns

- current show topology represented by LOR;
- controller/address/channel/universe relationships represented by LOR;
- Prop/SubProp/DMX source structure;
- Preview/Scene provenance; and
- parser-derived snapshot topology.

### Wiring system owns

- `assembly_required_at_setup`;
- operator maintenance of that value against the resolved wiring relationship;
- reconciliation/carry-forward of the value when a new LOR wiring snapshot is prepared; and
- presentation/edit workflows for the MSB-owned wiring enrichment.

### Approved wiring snapshot owns

- an immutable copy of the resolved wiring topology for that snapshot; and
- the `assembly_required_at_setup` value that was effective for each applicable wiring relationship when that snapshot was approved.

This keeps operational assembly history aligned with the wiring state that was actually approved at the time.

## Snapshot Preservation Rule

`assembly_required_at_setup` must be preserved with each approved wiring snapshot.

If the flag changes later, that change applies to the later/current wiring state. It must not rewrite the value stored with an older approved snapshot.

Conceptually:

```text
Wiring Snapshot A
    Relationship X
    assembly_required_at_setup = false

later operational change

Wiring Snapshot B
    Relationship X
    assembly_required_at_setup = true
```

Snapshot A remains evidence that the relationship was considered prewired when Snapshot A was approved.

## Carry-Forward / Reconciliation Requirement

Because this value does not originate in LOR, a new parser/import snapshot cannot simply regenerate it from XML.

When a new wiring snapshot is prepared, the wiring system must reconcile the new LOR-derived relationships against the prior/current MSB wiring annotations and carry forward the boolean when the relationship still represents the same physical connection.

The reconciliation key must be deliberately designed to survive reasonable LOR/parser changes.

Do **not** base long-term carry-forward solely on mutable human text such as Display Name or Channel Name.

Potential inputs to the future stable matching contract may include permanent `display_id`, source identities where reliable, physical controller/output context, Preview/Scene context, and other reviewed wiring relationship identifiers. Exact keys are intentionally left open until the current wiring model and Controller Inventory integration are completed.

Ambiguous carry-forward must be reviewable rather than guessed.

## Parser Isolation Requirement

Do not add `assembly_required_at_setup` to the LOR `.lorprev` parsing contract or make parser correctness depend on this field.

The parser should remain responsible for extracting LOR topology.

This isolation is intentional because LOR may change its XML schema, serialization rules, Prop models, or ChannelGrid representation in a future release. A major parser redesign must not force MSB to reconstruct operational assembly decisions from scratch.

The safe architecture is:

```text
LOR XML
    -> replaceable parser/materialization
    -> LOR-derived wiring topology

MSB Wiring System
    -> separately managed operational annotation
    -> assembly_required_at_setup

snapshot publication
    -> resolved topology + resolved MSB annotation
```

## Relationship to Parser DMX Work

The current dense-RGB recovery separately requires richer DMX source preservation in the parser, including source `PropClass.Name`, source identity, and component-local controller-port/string rows.

That work improves the **topology relationship that the wiring system annotates**.

It must not absorb `assembly_required_at_setup` into `dmxChannels` as though the value came from LOR.

The same assembly annotation model must also work for non-DMX relationships.

## Current Examples

The current reviewed setup distinctions include:

```text
Mega Tree ribbon/controller-output relationships
    -> assembly_required_at_setup = true

Mega Star internal controller-to-Hub/Spire relationships
    -> assembly_required_at_setup = false

Mega Cube park-assembly relationships
    -> assembly_required_at_setup = true

Mt. Crumpit / Whoville Matrix internal controller-to-matrix relationships
    -> assembly_required_at_setup = false

Open/Close Sign — new 2026
    -> likely true, but remains provisional until the physical installation method is confirmed
```

These examples do not authorize blanket Display-level defaults where a Display has mixed relationships. The stored value is relationship-level.

Other unreviewed wiring relationships must retain the default `false` until intentionally classified rather than being inferred from name, controller family, or LOR device type.

## FieldWiring Presentation

FieldWiring must always retain access to the complete physical wiring map.

The assembly flag changes the setup emphasis, not the existence of the wiring.

A practical presentation can distinguish:

```text
assembly_required_at_setup = true
    -> ASSEMBLY REQUIRED AT SETUP / CONNECT IN PARK

assembly_required_at_setup = false
    -> PREWIRED / NO SETUP ASSEMBLY REQUIRED
```

Exact display wording can be refined during UX acceptance.

Engineering/troubleshooting views and hard reports must still be able to show the underlying wiring for both values.

## Narrow Supersession of the Earlier No-New-Wiring-Table Decision

`FieldWiring_View_Inventory_and_Read_Model_Decision.md` previously stated:

```text
DO NOT create ref.wiring
DO NOT create ops.wiring
DO NOT manually copy wiring into a second persistent table
```

That decision remains valid for **LOR-authoritative wiring topology**. FieldWiring must not create a manually maintained duplicate topology system.

This contract narrows that rule for facts LOR cannot represent.

MSB-owned wiring annotations/enrichment are allowed and, for `assembly_required_at_setup`, required because:

- the fact does not exist in LOR;
- the fact must be operator-manageable in the wiring system;
- the fact must survive LOR XML/parser redesign; and
- the historical value must be preserved with each approved wiring snapshot.

Therefore a persistent annotation/relationship mechanism is justified. The exact table/schema is still to be designed; this document does not authorize a `ref.wiring` or `ops.wiring` table by name.

## Next Design Gate

Before implementation, define:

1. the exact wiring relationship grain/key to which the boolean attaches;
2. where the current editable value is stored;
3. how the value is copied into each approved immutable wiring snapshot;
4. how carry-forward/reconciliation works when LOR topology changes;
5. how ambiguous or removed relationships are reviewed;
6. how FieldWiring exposes and edits the current value without altering LOR topology; and
7. how the same mechanism supports A/C, Pixie, DMX, and E1.31 wiring relationships.

No parser dependence on the boolean is permitted.

## Related Documents

- [FieldWiring View Inventory and Read-Model Decision](FieldWiring_View_Inventory_and_Read_Model_Decision.md)
- [FieldWiring DMX Table Purpose and Field Assembly Boundary — 2026-08-21](FieldWiring_DMX_Table_Purpose_and_Field_Assembly_Boundary_2026-08-21.md)
- [FieldWiring Dense RGB LOR Controller-Port Recovery — 2026-08-21](FieldWiring_Dense_RGB_LOR_Controller_Port_Recovery_2026-08-21.md)
- [FieldWiring Engineering Recovery and Compatibility Contract](FieldWiring_Engineering_Recovery_and_Compatibility_Contract.md)
- [Wiring System](README.md)
