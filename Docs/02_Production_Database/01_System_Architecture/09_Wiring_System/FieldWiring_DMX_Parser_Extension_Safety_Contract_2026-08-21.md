# FieldWiring DMX Parser Extension Safety Contract — 2026-08-21

| Item | Value |
|---|---|
| Status | OPERATOR-CONFIRMED DESIGN CONSTRAINT |
| Sub-project | FieldWiring |
| Scope | V7 parser `dmxChannels` extension for dense-RGB recovery |
| Change strategy | Additive / surgical only |

## Purpose

Dense-RGB FieldWiring needs source component detail that the current V7 `dmxChannels` materialization loses during grouped-DMX consolidation. The safest recovery path is to extend the existing DMX table rather than redesign parser identity, Display identity, or the existing ingest chain.

## Identity Boundary

The V7 parser uses preview-scoped composite identifiers internally:

```text
PropID = PreviewId:RawPropID
```

That composite identity is a parser/SQLite relational key.

By the time Display identity reaches PostgreSQL, `ref.display` uses the raw LOR `PropClass` UUID (`lor_prop_id`) rather than the preview-scoped composite parser key.

Therefore these two concepts must remain distinct:

```text
SQLite/parser scoped PropID
    -> PreviewId:RawPropID
    -> protects parser-local uniqueness and joins

PostgreSQL ref.display.lor_prop_id
    -> raw PropClass UUID
    -> external LOR binding for the permanent Display record
```

No dense-RGB recovery change may blur or replace this boundary.

## Surgical Change Rule

The existing `dmxChannels` table and its current row relationships are the compatibility baseline.

The recovery change must:

- keep existing `dmxChannels.PropId` semantics unchanged;
- keep the current DMX row grain unless a separately reviewed compact-grid expansion requires additive materialization;
- keep `props` / `subProps` scoped-ID behavior unchanged;
- keep the PostgreSQL `ref.display` raw-UUID mapping unchanged;
- keep existing parser consumers and wiring/report views working unless an explicit downstream change is separately reviewed;
- add source provenance fields only where needed to preserve information currently discarded by grouped-DMX consolidation.

The change must **not** repurpose `dmxChannels.PropId` to mean source component identity.

## Why Extension Is Safer Than Redesign

Current grouped-DMX behavior still provides useful compatibility:

```text
dmxChannels.PropId
    -> canonical/materialized Display master relationship
```

FieldWiring additionally needs to know which original LOR PropClass authored each DMX row. That is a second provenance relationship, not a replacement for the existing one.

Conceptually the extended table needs to preserve both:

```text
PropId
    -> existing parser-scoped canonical/master relationship

source component provenance
    -> originating PropClass identity
    -> originating PropClass.Name
    -> component-local ChannelGrid/controller-port row ordinal
```

Exact new column names are intentionally not authorized by this document. They must be chosen only after inspecting the current V7.0.10 DMX insertion/grouping code and tests.

## Raw UUID Handling

Because PostgreSQL ultimately uses the raw PropClass UUID for `ref.display.lor_prop_id`, any source-component provenance design must preserve a reliable path back to that raw UUID.

That may be accomplished by storing the raw source UUID explicitly, the source scoped composite plus an explicit raw field, or another reviewed additive representation. The implementation must not assume that the existing canonical `dmxChannels.PropId` identifies the original source component after grouped-DMX consolidation.

## Required Acceptance Before Parser Change

Before editing the parser:

1. inspect the exact V7.0.10 `dmxChannels` schema creation;
2. inspect every DMX insert/materialization path;
3. inspect grouped-DMX master selection and reassignment behavior;
4. inspect all views/tests that consume `dmxChannels.PropId`;
5. document the minimum additive fields needed for source provenance;
6. verify the proposal does not alter the existing SQLite-to-PostgreSQL Display identity mapping;
7. add regression tests proving all existing DMX rows/joins remain compatible while the new source provenance survives.

## Governing Principle

```text
Do not redesign what already works.
Extend dmxChannels only enough to retain the LOR source facts FieldWiring currently loses.
```

This is the safety boundary for the upcoming dense-RGB parser work.

## Related Documents

- [FieldWiring Dense RGB LOR Controller-Port Recovery — 2026-08-21](FieldWiring_Dense_RGB_LOR_Controller_Port_Recovery_2026-08-21.md)
- [FieldWiring E1.31 LOR Controller Definitions — 2026-08-21](FieldWiring_E131_LOR_Controller_Definitions_2026-08-21.md)
- [FieldWiring DMX Table Purpose and Field Assembly Boundary — 2026-08-21](FieldWiring_DMX_Table_Purpose_and_Field_Assembly_Boundary_2026-08-21.md)
