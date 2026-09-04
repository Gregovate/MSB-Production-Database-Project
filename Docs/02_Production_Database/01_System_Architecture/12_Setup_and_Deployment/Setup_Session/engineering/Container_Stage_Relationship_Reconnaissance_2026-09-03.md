# Container-to-Stage Relationship Reconnaissance — 2026-09-03

| Document control | Value |
|---|---|
| Status | CURRENT ENGINEERING RECONNAISSANCE — schema change not yet approved |
| System | Setup Session |
| Parent system | Setup and Deployment |
| Owner | MSB Technical Team |
| Related issue | [#122 — Engineer annual Setup Session planning, pick-list, movement, and park-location subsystem](https://github.com/Gregovate/MSB-Production-Database-Project/issues/122) |
| Repository baseline reviewed | `main` at `0540d3b702de68d10d78ff8e17e8bca317a9a51f` |

## Purpose

Preserve the 2026-09-03 reconnaissance finding that current Containers, including KIT Containers, have useful permanent identity and broad delivery-endpoint information but do not provide a reliable machine-enforced relationship to the Stage/Setup scope they support.

This distinction is important to the first Setup Session pick-list resolver.

This document records the observed business-model gap. It does **not** approve a PostgreSQL migration, Directus relation, field rename, or replacement of the existing `goes_to` field.

## Current Directus Evidence

The current Container collection shows KIT Containers with permanent Container IDs, descriptions, Container types, Home Locations, Linked Displays, and Print Label state.

Representative visible KIT Containers include:

- Container 35 — `Magic Igloo kit (Includes skins)`;
- Container 56 — `Icicle Tunnel Kit`;
- Container 57 — `Icicle Tunnel Kit`;
- Container 58 — `Candy Land Kit`;
- Container 60 — `Elf Choir Kit includes spacers`;
- Container 61 — `Polar Bears & Sliding Penguins Kit`;
- Container 62 — `Polar Bear Playground Kit`;
- Container 65 — `Santa's Workshop Kit`;
- Container 66 — `Post Office Kit`;
- Container 67 — `Potter's Pole Kit includes the signs`;
- Container 68 — `FC Kit possibly including UTVLight & FC-FoodTruckLight`;
- Container 70 — `Sledders Kit including spacers`;
- Container 71 — `Hwy 42 Kit including spacers`;
- Container 76 — `Racing Arches Kit`;
- Container 79 — `Winter Wonderland Kit`; and
- several Containers identified as Kits for inside Santa's Station.

The descriptions make the intended Stage/Setup ownership understandable to a knowledgeable human, but that meaning is embedded in free text rather than represented as a durable Stage relationship.

## Container 56 Detail Evidence

The current Directus detail view for Container 56 shows:

- Description: `Icicle Tunnel Kit`;
- Home Location: `RC06-B-01`;
- Container Type: `Kit Box`;
- `Display Pallet Flag`: not enabled;
- `Goes To?`: `Park`;
- `Test Annually?`: enabled;
- label-required and label-print fields.

The visible help text for `Goes To?` describes it as the location where the Container is delivered.

Therefore, the current operator-visible meaning of `Goes To? = Park` is a **broad delivery endpoint**, not a relationship to Stage 14 / Icicle Tunnel.

Archived repository architecture also describes `ref.container.goes_to` as an endpoint rather than a Stage relationship. That archived documentation is supporting historical evidence only; exact current production FK/constraint behavior still must be verified from the live schema before schema changes.

## Business-Model Gap

The current model answers useful permanent questions:

```text
Which Container is this?
    -> container_id

Where does it live in the warehouse?
    -> Home Location

What kind of Container is it?
    -> Container Type

What broad destination does it go to?
    -> goes_to / Park
```

But it does not reliably answer:

```text
Which Stage / Sub-stage / Setup scope requires this Container?
```

For Setup Session planning, `Park` is far too broad.

Examples:

```text
Icicle Tunnel Kit
    -> Park          [current broad endpoint]
    -> Stage 14      [needed planning relationship]

Elf Choir Kit
    -> Park
    -> Old Elf Choir / owning Setup scope

Polar Bear Playground Kit
    -> Park
    -> Stage 21
```

The Stage meaning currently survives mainly in the human-readable Description.

## Why This Matters for Pick Lists

The first Setup Session MVP must be able to start from selected work and generate the physical assets that need to move.

Existing Display-to-Container relationships can resolve many Display-bearing Containers:

```text
selected Stage/work
    -> required Displays
        -> current display.container_id
            -> required Containers
```

KIT Containers are different. Their detailed contents are deliberately deferred from the 2026 MVP, but the **KIT Container itself already exists and is a meaningful physical dependency**.

Therefore the 2026 MVP does not need detailed KIT contents to benefit from a durable Stage relationship.

Conceptually:

```text
selected Stage/work
    -> required Displays -> Display-bearing Containers
    +
    -> Containers explicitly associated with that Stage/Setup scope
        -> KIT Containers and other Stage-support Containers
            -> deduplicate physical pick list
```

This lets a planner include an `Icicle Tunnel Kit` when Stage 14 is selected without inventorying every tie, piece of garland, fastener, spacer, or small lighting component inside the Kit.

## `goes_to` and Stage Must Remain Separate Concepts

Do **not** repurpose `goes_to` to mean Stage merely because Setup needs a Stage relationship.

The two concepts answer different questions:

```text
goes_to
    -> broad endpoint / delivery class
    -> example: Park

Stage / Setup scope relationship
    -> which show area or Setup work requires the Container
    -> example: Stage 14 — Icicle Tunnel
```

A Container may still validly have `goes_to = Park` while also being associated with a specific Stage.

The exact Stage relationship could eventually be a foreign key or another controlled relationship, but no schema form is approved until the live production schema and real exception cases are inventoried.

## Relationship Cardinality Must Be Proven

Do not assume every Container maps to exactly one Stage.

The KIT examples appear to be organized by Stage, but other Containers/trailers already demonstrate cross-Stage behavior:

- Container 34 / Arch Trailer stores 121 Displays across six Stages;
- Antenna Trailer stores/transports parts for multiple Displays;
- some Containers may be shared by several Setup jobs;
- some Display-pallet Containers may themselves become part of a Display.

Before adding a simple `stage_id` foreign key to every Container, prove whether the relationship is:

- one Container -> zero or one Stage;
- one Container -> one primary Stage plus exceptions;
- one Container -> many Stages; or
- type/role dependent.

A simple FK may be correct for KIT Containers while being wrong as a universal Container rule.

## 2026 MVP Direction

Detailed KIT contents remain deferred.

However, a **Container-level Stage/Setup relationship is now in scope for reconnaissance** because it can materially improve the pick-list resolver without creating component inventory.

For 2026, the preferred boundary is:

```text
IN SCOPE
    -> existing KIT Container identity
    -> existing Home Location
    -> existing broad goes_to endpoint
    -> determine durable Stage/Setup relationship for the Container itself
    -> use that relationship in pick-list generation

DEFERRED
    -> item-by-item KIT contents
    -> small hardware/material inventory
    -> BOM/component accounting
    -> forcing non-LOR Kit contents into ref.display
```

## Required Live-Schema Verification

Before proposing DDL, inspect production `ref.container` and all relevant FK constraints.

At minimum verify:

1. exact column name/type for `goes_to`;
2. whether `goes_to` has a foreign key and its referenced table/column;
3. current endpoint rows/values;
4. whether any Stage-related column or relationship already exists but is not exposed in the current Directus layout;
5. all current Container foreign keys;
6. whether Directus has any hidden/manual relationship metadata relevant to Stage;
7. Container types/rows that would make one-to-one Stage assignment invalid;
8. how KIT Containers are identified in current production data.

## Recommended Acceptance Cases

Any proposed Container-to-Stage solution should correctly handle at least:

- Container 56 — Icicle Tunnel Kit -> Stage 14 / Icicle Tunnel;
- Container 57 — second Icicle Tunnel Kit -> same owning Stage without conflict;
- Container 60 — Elf Choir Kit -> correct Elf Choir owning scope;
- Container 62 — Polar Bear Playground Kit -> Stage 21;
- Container 76 — Racing Arches Kit -> Stage 25;
- Container 34 — Arch Trailer -> must **not** be incorrectly forced to one Stage merely because it stores many Stage-specific Displays;
- Containers with no Stage ownership where that is legitimate.

## Documentation / Ownership Boundary

- Containers and Storage owns permanent Container identity, type, home storage, and existing Container relationships.
- Setup Session owns the requirement that physical planning can resolve the Containers needed for selected Setup work.
- Detailed KIT contents remain future inventory work.
- LOR must not be expanded to hold non-LOR small component inventory merely to solve this relationship.

When live schema verification establishes the exact current Container FK behavior, update the responsible Containers and Storage engineering authority as well as this Setup Session handoff if the finding changes the permanent Container model.

## Related Documents

- [Setup Session subsystem](../README.md)
- [Setup Session Engineering Reconnaissance — 2026-09-03](Setup_Session_Engineering_Reconnaissance_2026-09-03.md)
- [Containers and Storage](../../../04_Containers_and_Storage/README.md)
- [Setup and Deployment](../../README.md)
- [#122 — Setup Session engineering issue](https://github.com/Gregovate/MSB-Production-Database-Project/issues/122)
