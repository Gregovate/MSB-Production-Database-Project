# FieldWiring Dense RGB DMX Parser Extension Checkpoint — 2026-08-21

| Item | Value |
|---|---|
| Status | IMPLEMENTATION CHECKPOINT — NO PARSER CODE CHANGE YET |
| Sub-project | FieldWiring / Engineering Recovery |
| Branch | `agent/fieldwiring-engineering-recovery` |
| Parser baseline | V7.0.10 |
| Purpose | Freeze the accepted additive-only DMX extension boundary before implementation continues in a fresh engineering conversation |

## Why This Checkpoint Exists

Dense-RGB recovery has reached the point where a parser schema extension is likely required. The implementation must not begin from conversational memory alone because the existing V7 parser, PostgreSQL ingest, identity model, FormView compatibility, and FieldWiring read model are tightly coupled.

This document is the durable handoff for the next implementation conversation.

## Accepted Identity Chain — Must Not Change

The current V7 parser deliberately uses preview-scoped composite IDs because raw LOR PropClass UUIDs can be reused across previews.

```text
V7 SQLite parser
    props.PropID / subProps keys
        = PreviewId:RawPropID
        = parser-local preview-scoped composite identity

PostgreSQL ingest
    ref.display.display_id
        = permanent MSB Display identity

    ref.display.lor_prop_id
        = raw LOR PropClass UUID binding
        = NOT the V7 composite parser key
```

Do not redesign this chain as part of dense-RGB recovery.

## Existing `dmxChannels` Contract — Preserve It

Current table fields:

```text
IntDMXChannelID
PropId
Network
StartUniverse
StartChannel
EndChannel
Unknown
PreviewId
```

`dmxChannels.PropId` currently participates in established parser/downstream relationships. For grouped DMX Displays it points to the canonical/materialized Display master composite `PropID`.

That behavior must remain unchanged unless a separate architecture review proves a defect.

The safest implementation is **additive only**: extend `dmxChannels` with source-component provenance while leaving every existing column, value, join, key behavior, and downstream relationship intact.

## Problem Being Fixed

LOR dense-RGB authoring contains more wiring detail than current V7 DMX materialization preserves.

Operator-confirmed authoring contract:

```text
PropClass.Comment -> Display identity
PropClass.Name    -> operator-authored component/channel-configuration identity
```

Current grouped-DMX processing preserves the Display/master relationship but can discard which original PropClass component authored each DMX row.

This is especially damaging for Displays such as Mega Star and Mega Cube, where multiple channel-bearing PropClasses share the same Display Comment but have distinct Names and component-local controller-port/string rows.

## Minimum Information the Extension Must Preserve

The implementation must preserve enough source provenance to answer:

```text
Which materialized Display/master does this DMX relationship belong to?
Which original LOR PropClass authored it?
What was that PropClass.Name?
What component-local controller-port/string row did it represent?
What universe/channel addressing did LOR assign?
```

Candidate additive concepts include:

```text
SourcePropId
    -> preview-scoped composite ID of the originating PropClass

SourceName
    -> originating PropClass.Name

SourceGridOrdinal
    -> component-local ChannelGrid/controller-port/string row ordinal
```

Exact column names are NOT final until current V7.0.10 DMX creation/insertion code and tests are inspected.

A separate `SourceRawPropID` column should not be added automatically. The raw UUID is already represented inside a preview-scoped source composite if `SourcePropId` follows the existing `scoped_id()` contract. Add duplication only if a proven downstream need justifies it.

## Critical Ordinal Rule

Controller-port/string row ordinal is local to each source PropClass and can restart at `1` for the next component.

Example:

```text
MS Long Spire 1 4x150
    local row 1 -> U113
    local row 2 -> U114
    local row 3 -> U115
    local row 4 -> U116

MS Short Spire 1 2x150
    local row 1 -> U129
    local row 2 -> U130
```

Do not flatten Mega Star into one synthetic 1-N output sequence at parser source-provenance level.

A later resolved physical-controller output number is a separate derived concept and must not overwrite the source component-local ordinal.

## Compact / Auto-Numbered ChannelGrid Constraint

Some current dense-RGB custom props serialize compact ChannelGrid entries rather than one explicit semicolon-delimited record for every visible LOR controller-port/string row.

Observed examples include the `2100` fifth-field pattern on Mega Cube and Whoville Matrix.

The arithmetic and LOR UI strongly support an expansion route for these specific cases, but the current parser field remains named `Unknown` because the repository does not have an authoritative universal file-format definition for that fifth value.

Therefore:

- keep the existing `Unknown` column and semantics unchanged;
- do not globally rename/redefine it during the additive provenance change;
- validate any compact-row expansion rule against representative current LOR UI/source evidence and tests before applying it parser-wide.

## LOR Network Configuration Is a Separate Source

Direct Show-PC inspection on 2026-08-21 established that LOR Network Preferences are stored in the current Windows user's registry, under a branch such as:

```text
HKEY_CURRENT_USER\SOFTWARE\Light-O-Rama\Shared\NetworkF420399CE04C4EC08C7ED0A2C62A1051
```

with per-universe `DMX<n>` subkeys containing values including:

```text
Uses E131
Protocol
E131 IP Address
E131 IP Address Type
E131 Send To Port
Comment
```

This is a separate source adapter from `.lorprev` parsing.

Do not couple registry extraction into the XML parser simply because FieldWiring ultimately consumes both layers.

The registry evidence also directly established that Universes `109-112` are currently inactive/unconfigured (`Uses E131 = 0`, blank target data), resolving that previous gap.

## Dense-RGB Current Physical/Authoring Context

Operator-confirmed physical controller map includes:

```text
Mega Tree       -> one HolidayCoro AlphaPix Flex 48-output system
Mega Ball       -> one physical PixCon16
Mega Cube       -> one HolidayCoro AlphaPix Flex 48-output system
Whoville Matrix -> one physical PixCon16
Mega Star       -> two physical PixCon16
```

Current LOR routing context includes:

```text
Mega Tree       U1-48    -> 10.10.5.10
Mega Ball       U49-64   -> 10.10.5.11
Mega Cube       U65-108  -> 10.10.5.12
U109-112                   inactive/unconfigured
Mega Star 1     U113-128 -> 10.10.5.15
Mega Star 2     U129-144 -> 10.10.5.16
Northern Lights U145-146 -> 10.10.5.30
Whoville Matrix U147-162 -> 10.10.5.17
Gift Conveyor   U163-167 -> 10.10.5.18
Open/Close Sign U168-169 -> 10.10.5.19
```

These routing facts are LOR configuration evidence, not permanent physical-controller identity.

## Controller Inventory Boundary

Controller Inventory remains responsible for permanent physical controller identity/current reviewed physical assignment facts, including future `ctrl_id` resolution.

Do not use any of the following as permanent controller identity:

```text
IP address
universe number/range
LOR Unit ID
network name
Display name
location
controller comment/name
```

## Wiring-System Operational Metadata Boundary

MSB-owned operational wiring metadata such as:

```text
assembly_required_at_setup BOOLEAN NOT NULL DEFAULT FALSE
```

must remain separate from LOR source data and must not be embedded into `.lorprev` parsing.

It belongs at wiring-relationship/connection grain, should carry forward through controlled reconciliation when the same relationship remains, and should be frozen into approved wiring snapshots so later changes do not rewrite history.

Exact persistent table/schema and stable wiring-relationship key remain a separate design step.

## Implementation Safety Rules

Before making any parser change:

1. Inspect the exact V7.0.10 `dmxChannels` table creation statement.
2. Inspect every DMX insertion/materialization path.
3. Inspect where grouped DMX reassigns/uses the canonical master `PropId`.
4. Inspect every parser view/query/test that references `dmxChannels` or assumes its column set/order.
5. Inspect PostgreSQL ingest code/views that consume `dmxChannels`.
6. Confirm additive columns do not alter existing row counts, existing field values, existing joins, or raw-UUID handoff to `ref.display.lor_prop_id`.
7. Add regression tests before changing production parser behavior.
8. Preserve V7.0.10 as the pre-change baseline and bump parser version only with the controlled change.

## Required Regression Principle

For the same input Preview set, excluding intentionally new additive columns/materialized rows explicitly authorized for compact dense-RGB recovery:

```text
existing parser identity behavior must remain unchanged
existing non-DMX behavior must remain unchanged
existing Display master selection must remain unchanged
existing PostgreSQL raw PropClass UUID mapping must remain unchanged
existing FormView/FieldWiring-compatible relationships must remain unchanged
```

If an additive extension unexpectedly changes an existing relationship, stop and review rather than compensating downstream.

## Next Conversation / Next Engineering Step

Start a fresh implementation conversation from this checkpoint and the current feature branch.

The first task is **inspection only**:

```text
A. locate dmxChannels CREATE TABLE
B. locate all INSERT/UPDATE uses of dmxChannels
C. locate grouped-DMX canonical-master logic
D. locate tests and ingest dependencies
E. produce an exact proposed additive schema/change map
```

Do not edit parser code until that dependency map has been reviewed.

After approval:

```text
implement additive source provenance
-> run parser regression tests
-> produce a new parser SQLite snapshot
-> inspect dense-RGB rows directly
-> update PostgreSQL ingest only if additive columns need propagation
-> build a new FieldWiring dev snapshot
-> browser-test Mega Tree, Mega Cube, Mega Star, Whoville Matrix, etc.
```

Broad FieldWiring UX work remains out of scope until dense-RGB acceptance is complete.

## Related Durable Decisions

- `FieldWiring_Dense_RGB_LOR_Controller_Port_Recovery_2026-08-21.md`
- `FieldWiring_E131_LOR_Controller_Definitions_2026-08-21.md`
- `FieldWiring_DMX_Table_Purpose_and_Field_Assembly_Boundary_2026-08-21.md`
- `FieldWiring_Wiring_Snapshot_Assembly_Required_Contract_2026-08-21.md`
- `FieldWiring_Dense_RGB_Physical_Controller_Map_2026-08-20.md`
- `FieldWiring_Controller_Inventory_Handoff_2026-08-20.md`

## Stop Point

At this checkpoint, **no V7 parser code/schema change has been made for the dense-RGB provenance extension**.

That is intentional. The next conversation should begin from the dependency inspection above, not from an assumed implementation.