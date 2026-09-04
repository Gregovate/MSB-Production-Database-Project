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

Preserve the 2026-09-03 reconnaissance finding that current Containers, including KIT Containers, have useful permanent identity and broad delivery-endpoint information but do not always provide a machine-readable way for Setup planning to determine every Stage/Setup scope that the physical Container supports.

The absence of one universal Container-to-Stage foreign key was **not necessarily a modeling mistake**. Some Containers legitimately contain or support material for multiple Stages, so a single `stage_id` on every Container could encode a false relationship.

This distinction is important to the first Setup Session pick-list resolver.

This document records the observed business-model gap and the original design rationale now established during reconnaissance. It does **not** approve a PostgreSQL migration, Directus relation, field rename, replacement of the existing `goes_to` field, or a universal Container `stage_id`.

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

The descriptions make the intended Stage/Setup support relationship understandable to a knowledgeable human, but that meaning is embedded in free text when it cannot be derived from linked Displays.

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

## Production Kit Box Query — 2026-09-03

A production DBeaver query was run for all Containers where `container_type_id = 2` (`Kit Box`), including current Home Location, `goes_to`, `display_pallet`, `testing_after_takedown`, and count of linked `ref.display` rows.

The result returned **52 Kit Box Containers**.

Observed totals:

- 52 Kit Box Containers total;
- 16 Kit Box Containers currently have one or more linked Display rows;
- 36 Kit Box Containers currently have zero linked Display rows;
- the 16 linked Kit Boxes account for 108 linked Display rows in total;
- every returned Kit Box had `goes_to = 2`;
- no returned Kit Box was marked `display_pallet` in the query result;
- `testing_after_takedown` varies by Kit and therefore does not identify the Stage relationship by itself.

Kit Boxes with one or more linked Displays were:

- 35 — Magic Igloo kit (Includes skins);
- 55 — Magic Igloo & PB Igloo Flood Light Kit;
- 56 — Icicle Tunnel Kit;
- 57 — Icicle Tunnel Kit;
- 58 — Candy Land Kit;
- 59 — Front Entrance Kit;
- 61 — Polar Bears & Sliding Penguins Kit;
- 62 — Polar Bear Playground Kit;
- 63 — Fred Stars;
- 65 — Santa's Workshop Kit;
- 66 — Post Office Kit;
- 67 — Potter's Pole Kit includes the signs;
- 68 — FC Kit possibly including UTVLight & FC-FoodTruckLight;
- 70 — Sledders Kit including spacers;
- 72 — Volunteer Path Lights & Cords; and
- 79 — Winter Wonderland Kit.

The remaining 36 Kit Boxes currently have zero linked Displays. Those include several clearly Stage/work-oriented descriptions such as `Elf Choir Kit includes spacers`, `Racing Arches Kit`, `Church Tree kit`, `Hwy 42 Kit including spacers`, `Star Cords`, `Traditional Christmas Kit`, and the multiple `Kits for inside Santa's Station` Containers.

### Engineering significance

This result gives the Setup resolver two evidence classes:

```text
Kit Box with linked Displays
    -> attempt to derive supported Stage/work scope from those Displays first

Kit Box with no linked Displays
    -> Stage/work support cannot be derived from Display assignment
    -> candidate for supplemental Setup-support relationship
```

Do not assign Stage relationships to zero-linked Kits by parsing Description text automatically. The names are useful human reconciliation evidence, but the authoritative relationship should be reviewed and stored explicitly if the 2026 Setup planner needs it.

## Linked Kit Box Stage Distribution — 2026-09-03

A second production query grouped each Kit Box by the distinct `ref.stage` values of its linked Displays.

Of the 16 Kit Boxes with linked Displays:

- **15 resolve to exactly one linked Stage**;
- **1 resolves to two linked Stages**;
- none of the linked Kit Boxes in this sample resolved to more than two Stages.

The single multi-Stage Kit is:

- Container 55 — `Magic Igloo & PB Igloo Flood Light Kit`
  - Stage 21 — Polar Bear Playground;
  - Stage 26 — Magic Igloo.

Representative single-Stage derivations include:

- Container 58 — Candy Land Kit -> Stage 17 / Candyland;
- Container 68 — FC Kit -> Stage 04 / Food Collection;
- Containers 56 and 57 — Icicle Tunnel Kits -> Stage 14 / Icicle Tunnel;
- Container 35 — Magic Igloo kit -> Stage 26 / Magic Igloo;
- Container 62 — Polar Bear Playground Kit -> Stage 21 / Polar Bear Playground;
- Container 66 — Post Office Kit -> Stage 06 / Post Office;
- Container 65 — Santa's Workshop Kit -> Stage 19 / Santa's Workshop;
- Container 70 — Sledders Kit -> Stage 11 / Sledders;
- Container 79 — Winter Wonderland Kit -> Stage 13 / Winter Wonderland.

This is strong production evidence that linked Displays already provide useful Setup-support context for most currently linked Kit Boxes, while also proving that the relationship cannot be universally modeled as one exclusive Stage.

### Physical adjacency / practical Setup grouping

Two linked Kit descriptions initially looked surprising because both resolve through their Displays to Stage 02 / Triangle:

- Container 63 — `Fred Stars`;
- Container 72 — `Volunteer Path Lights & Cords`.

Field-process clarification established that these physical features are **right next to each other in the park**. Their Stage 02 linkage is therefore not being treated as suspicious or incorrect merely because the Container descriptions do not say `Triangle`.

This establishes an important semantic rule for Setup Session engineering:

> A linked Stage can represent the practical Setup area/work context that uses or services a Container, not necessarily strict inventory ownership implied by the Container's human-readable name.

Do not automatically "correct" a linked Stage merely because Description text suggests a different label. Physical adjacency, crew workflow, and existing Display relationships are relevant evidence.

## Original No-Single-Stage-FK Rationale

The project intentionally avoided establishing one Stage FK on every Container because a Container does not always belong to exactly one Stage.

That concern is now validated by real production examples.

Container 34 / Arch Trailer currently holds 121 `ref.display` records across six Stages:

- Stage 04 — Food Collection;
- Stage 10 — Stars;
- Stage 14 — Icicle Tunnel;
- Stage 17 — Candyland;
- Stage 21 — Polar Bear Playground; and
- Stage 25 — Racing Arches.

A scalar relationship such as:

```text
ref.container.stage_id = <one Stage>
```

would require choosing one Stage and would therefore misrepresent Container 34.

The Antenna Trailer is another operational example of a shared Container/trailer used to store and transport pieces for multiple Displays/Stages.

Therefore the current reconnaissance must **not** characterize the missing universal Stage FK as a simple defect. The real requirement is to let Setup resolve every work scope supported by a Container without falsely requiring one exclusive Stage owner.

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

For many Display-bearing Containers, Stage relevance can already be derived through the Displays assigned to the Container:

```text
Container
    -> linked Displays
        -> each Display's Stage/Setup context
```

But that does not solve Containers whose operational Stage support is represented only in human knowledge or free-text Description.

Examples include KIT Containers such as:

```text
Icicle Tunnel Kit
    -> Park                         [current broad endpoint]
    -> supports Stage 14            [needed Setup planning knowledge]

Elf Choir Kit
    -> Park
    -> supports Old Elf Choir scope

Polar Bear Playground Kit
    -> Park
    -> supports Stage 21
```

For Setup Session planning, `Park` is too broad, while forcing every Container to one Stage is too narrow.

## Resolver Principle — Derive First, Supplement Only Where Needed

The first Setup Session resolver should avoid maintaining duplicate relationship data when Production Database relationships already provide the answer.

Preferred direction:

```text
selected Setup work
    |
    +-- required Displays
    |       -> current Display.container_id
    |           -> required Containers
    |
    +-- supplemental Container support relationships
            -> only where the physical Container requirement
               cannot be derived from existing Display relationships

then
    -> deduplicate physical Containers/trailers
    -> explain every reason each Container is required
```

### Example — Arch Trailer

Selecting Star Stage can already reach Container 34 through its 24 Star Display records. A manually maintained `Container 34 -> Stage 10` relationship is not necessarily needed just to rediscover information already present in `ref.display`.

If Candyland, Icicle Tunnel, Polar Bear Playground, Food Collection, or Racing Arches are selected, their existing Display assignments likewise contribute Container 34 to the physical dependency set.

### Example — KIT Container

Selecting Icicle Tunnel can already reach Containers 56 and 57 through their linked Stage-14 Displays. That Stage-support information should be derived rather than separately re-entered merely because the Containers are Kits.

By contrast, selecting Elf Choir cannot currently reach Container 60 through linked Displays because that Kit has zero Display assignments. A supplemental relationship can make that physical dependency resolvable without inventorying every Kit item:

```text
Container 60
    -> supports Old Elf Choir setup scope
```

The supplemental relationship is therefore a **planning dependency**, not a statement that all Containers have one exclusive Stage owner.

## `goes_to` and Setup Scope Must Remain Separate Concepts

Do **not** repurpose `goes_to` to mean Stage merely because Setup needs richer planning relationships.

The concepts answer different questions:

```text
goes_to
    -> broad endpoint / delivery class
    -> example: Park

Setup support relationship
    -> which Stage / Sub-stage / Scene / work scope requires this Container
    -> example: Stage 14 — Icicle Tunnel
```

A Container may validly have `goes_to = Park` while supporting one Stage, several Stages, or another Setup-specific scope.

## Relationship Cardinality Is Non-Exclusive Until Proven Otherwise

Do not assume every Container maps to exactly one Stage.

The KIT examples often appear Stage-oriented, but the broader Container population already demonstrates cross-Stage behavior:

- Container 34 / Arch Trailer stores Displays from six Stages;
- Container 55 Kit Box derives two linked Stages;
- Antenna Trailer stores/transports parts for multiple Displays;
- some Containers may be shared by several Setup jobs;
- some Display-pallet Containers may themselves become part of a Display;
- some Containers may legitimately have no Stage-specific support relationship.

If an explicit permanent Container-to-Stage/Setup-support relationship is required, the data model must be capable of representing **zero, one, or multiple supported scopes** unless production evidence proves a narrower rule for a particular Container type.

A many-to-many/support association may therefore be more faithful than a scalar `ref.container.stage_id`, but exact schema remains unapproved until live production objects and the real exception cases are inventoried.

A type-specific rule is also possible. For example, most KIT Containers currently derive one Stage while some shared Kits/trailers derive many. Do not encode a universal one-Stage assumption.

## Why This Matters for Pick Lists

The first Setup Session MVP must be able to start from selected work and generate the physical assets that need to move.

Existing Display-to-Container relationships can resolve many Display-bearing Containers:

```text
selected Stage/work
    -> required Displays
        -> current display.container_id
            -> required Containers
```

KIT Containers are different only where their physical Setup dependency cannot already be derived from linked Displays. Their detailed contents are deliberately deferred from the 2026 MVP, but the **KIT Container itself already exists and is a meaningful physical dependency**.

Therefore the 2026 MVP does not need detailed KIT contents to benefit from a supplemental Setup-support relationship at the Container level for the unresolved cases.

Conceptually:

```text
selected Stage/work
    -> required Displays -> Display-bearing Containers
    +
    -> supplemental Container support relationships
        -> zero-linked KIT Containers / other non-derived physical dependencies
            -> deduplicate physical pick list
```

This lets a planner include an `Elf Choir Kit` when Old Elf Choir is selected without inventorying every spacer, tie, piece of garland, fastener, or other small component inside the Kit.

## 2026 MVP Direction

Detailed KIT contents remain deferred.

However, a **Container-level supplemental Setup-support relationship is now in scope for reconnaissance** because it can materially improve the pick-list resolver without creating component inventory.

For 2026, the preferred boundary is:

```text
IN SCOPE
    -> existing Container identity
    -> existing Home Location
    -> existing broad goes_to endpoint
    -> derive Container dependencies from linked Displays where possible
    -> determine supplemental Stage/Setup support only where derivation is insufficient
    -> allow non-exclusive/shared support where required
    -> use the combined result in pick-list generation

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
4. whether any Stage-related or support relationship already exists but is not exposed in the current Directus layout;
5. all current Container foreign keys;
6. whether Directus has any hidden/manual relationship metadata relevant to Stage/Setup support;
7. Container types/rows that demonstrate zero/one/many Stage support;
8. how KIT Containers are identified in current production data;
9. which Containers already yield Stage support completely from their linked Displays; and
10. which Containers need supplemental relationship data because their physical dependency cannot be derived.

## Recommended Acceptance Cases

Any proposed Container support solution should correctly handle at least:

- Containers 56 and 57 — Icicle Tunnel Kits -> derive Stage 14 through linked Displays without redundant manual support data;
- Container 60 — Elf Choir Kit -> supplemental Old Elf Choir supporting scope because it currently has zero linked Displays;
- Container 62 — Polar Bear Playground Kit -> derive Stage 21 through linked Displays;
- Container 76 — Racing Arches Kit -> supplemental Stage 25 / Racing Arches support because it currently has zero linked Displays;
- Container 55 — preserve derived support for both Stage 21 / Polar Bear Playground and Stage 26 / Magic Igloo;
- Containers 63 and 72 — preserve the currently derived Stage 02 practical Setup-area relationship unless contrary field evidence establishes a defect;
- Container 34 — Arch Trailer -> derive multiple Stage dependencies from its linked Displays and do **not** force it to one Stage;
- shared Containers that genuinely support multiple Stages;
- Containers with no Stage/Setup support where that is legitimate.

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
