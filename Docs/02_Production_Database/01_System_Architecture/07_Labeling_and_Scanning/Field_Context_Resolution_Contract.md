# Field Context Resolution Contract

| Document control | Value |
|---|---|
| Status | DRAFT — shared field-navigation architecture |
| Current revision | 2026-08-17 |
| Owner | MSB Database Administrator |
| Primary consumers | Work Orders, FieldWiring, Setup, Takedown, Testing, future field applications |
| Schema/code status | Documentation only; no schema or application change authorized |

## Purpose

This document defines the shared field-context engine that turns either a scan of a physical MSB asset or a manual browser lookup into a durable Production Database identity plus the current field context needed by task-specific applications.

The resolver is deliberately separate from Wiring, Setup, Takedown, Testing, Work Orders, and other task content.

The core operating model is:

```text
scan physical asset
        OR
manual browser lookup
        |
        v
resolve durable Production Database identity
        |
        v
resolve current related field context
        |
        v
show task choices for that asset/context
        |
        +--> Work Order
        +--> Field Wiring
        +--> Setup Instructions
        +--> Takedown Instructions
        +--> Testing Procedures
        +--> future task-specific functions
```

The QR identifies the asset. It does not encode which task the operator intends to perform.

Manual lookup identifies the same asset/context without requiring physical access to the QR label.

## Design Decision

A Display QR scan or a manual Display lookup opens the same Display **field home/context page**.

The operator then chooses what they want to do.

The context engine must therefore be application-neutral and entry-method-neutral.

Work Order, FieldWiring, Setup, Takedown, Testing, and future field functions should consume the same resolved Display identity and hierarchy rather than independently re-resolving the QR or maintaining separate asset-to-Stage/Scene logic.

## Two Equal Entry Paths

Physical scanning is important in the field, but it cannot be the only way to reach field information.

Displays may be physically inaccessible when documentation is needed. A Display may be buried on a rack, located high on a storage shelf, packed in a Container, already loaded for transport, or otherwise inconvenient to reach merely to scan its label.

Office/PC users also need to prepare and print current Wiring and procedures before going to the park.

The application must therefore support two equal entry paths:

```text
[ Scan Display ]
        |
        +------------------+
                           v
                 FIELD CONTEXT RESOLVER
                           ^
        +------------------+
        |
[ Find / Browse ]
```

Both paths must resolve to the same authoritative context object and the same task menu.

### Scan entry

The operator scans the canonical asset identifier, such as:

```text
DISP:251
```

The resolver identifies the permanent Display and current hierarchy.

### Manual browser entry

The PC/browser interface must allow an operator to find the same permanent Display without scanning the physical label.

Useful lookup methods include:

- Display Name;
- permanent Display ID;
- canonical scan value such as `DISP:251` typed or pasted manually;
- Stage/Sub-stage;
- Scene; and
- controlled browse/navigation through the current Stage/Scene hierarchy.

The exact search UI is application work, but the result must resolve to a permanent Production Database identity rather than treating a text name or folder path as identity.

If a text search returns more than one plausible result, the user must select the intended current record. The application must not guess from a partial/fuzzy name when the result is ambiguous.

## Manual Browse for Group Preparation

PC users may also know the Stage or Scene they are preparing without starting from a particular Display.

The browser should therefore support controlled Stage/Scene browsing for group-oriented tasks such as:

- printing a complete Scene Wiring package;
- printing Stage-level Wiring when no Scene scope applies;
- printing current Setup Instructions;
- printing current Takedown Instructions; and
- reviewing the current documents before setup work begins.

Direct Stage/Scene navigation is another front end to the same controlled hierarchy. It must not create a second set of folder-resolution rules.

When a task normally derives its scope from a Display, manually selecting that same resolved Stage/Scene must produce the same base task package that would be reached by scanning any Display in that scope.

## Pre-Print / Office Workflow

A supported workflow is:

```text
PC browser in office/workshop
        |
        v
Find Display OR browse Stage/Scene
        |
        v
shared Field Context resolver
        |
        v
choose Field Wiring / Setup / Takedown / other task
        |
        v
review current package
        |
        v
generate / print current controlled PDF
        |
        v
carry offline field copy to park
```

This is not a separate reporting system. It is the same current content resolution used by QR scanning, reached before the physical asset is accessible.

The generated field copy remains subject to the shared publication/currentness and expiration rules.

## Canonical Scan Identity

The existing Asset Identity and Scan Payload Standard defines durable machine-readable asset identities such as:

```text
DISP:251
```

The scan resolver must use the permanent Production Database identity carried by that payload.

It must not depend on:

- a Directus admin URL;
- a Google Drive URL;
- a Stage folder path embedded in the QR;
- an LOR Prop UUID as the permanent asset identity;
- a FieldWiring-specific URL;
- a Setup-specific URL; or
- a Work-Order-specific URL.

This allows the destination applications, document locations, and browser routes to evolve without replacing physical labels.

## Scan and Lookup Are Read-Only Navigation

Scanning or manually finding a Display must **not** change the Display's Stage, Scene, Preview, container, documentation ownership, or any other Production Database relationship.

Either entry method establishes the operator's current **view/navigation context** only.

Conceptually:

```text
DISP:<display_id>
        OR
manual selection of <display_id>
        |
        v
lookup current Production Database relationships
        |
        v
field home/context
```

If stored relationships are wrong, incomplete, or ambiguous, the resolver must expose that condition for correction through the responsible engineering/database workflow. It must not silently rewrite relationships to make navigation appear successful.

## Context Returned by the Resolver

The resolver should not collapse the lookup immediately into a single Scene or Stage.

It should return enough current identity to let each task choose its correct scope.

Conceptually the resolved context includes:

```text
entry method / trigger type
trigger display_id when applicable
Display identity/name/status
current permanent Stage/Sub-stage relationship
applicable current Scene membership(s), where defined
applicable Preview identity/context, where required
current source/provenance needed for task routing
```

This separation is important because different tasks can legitimately operate at different scopes.

Examples:

- a Work Order may be specific to the selected Display;
- Field Wiring may be common to the owning Scene or Stage/Preview context;
- Setup Instructions may be common to the owning Scene or Stage;
- Takedown Instructions may be common to the owning Scene or Stage;
- Testing Procedures may be Display-specific or may use another controlled scope.

The shared resolver provides the facts. The task adapter applies the task's scope rules.

## Current Relationship Evidence

The current Production Database already contains major identities needed for this resolver:

- `ref.display.display_id` — permanent Display identity;
- `ref.display.stage_id` — current permanent Stage relationship;
- `ref.lor_scene_display.display_id` — permanent Display membership in a current LOR Scene, scoped by Preview;
- `ref.lor_scene_display.lor_scene_id` / `preview_uuid` — current Scene/Preview relationship;
- `ref.lor_scene.stage_id` — permanent Stage owning the promoted Scene;
- `ref.lor_scene.scene_name` — current Scene identity/name;
- `ref.lor_scene.background_file` — current Scene background reference where applicable.

These relationships show that the scan/manual-lookup-to-context model is feasible. They do not by themselves define the final application query/view or authorize a new schema object.

## Base Display Resolution

For a Display scan or manual Display lookup, the shared resolver should conceptually perform these steps:

```text
1. Resolve permanent Display identity
       scanned: DISP:<display_id>
       manual:  selected ref.display.display_id

2. Resolve permanent Display
       ref.display.display_id

3. Resolve current permanent Stage/Sub-stage relationship
       ref.display.stage_id -> ref.stage

4. Resolve current Scene membership when applicable
       ref.lor_scene_display -> ref.lor_scene

5. Resolve any Preview context needed by downstream functions
       without guessing among valid distinct Preview purposes

6. Return the identity/context object to the field home page
```

The resolver returns identity/context. It does not return a hard-coded Wiring or Setup file path as the asset identity.

## Field Home / Task Menu

After a successful Display scan or manual Display lookup, the normal operator experience should present the Display and the actions available for that asset/context.

Conceptually:

```text
Display: <Display Name>
Stage:   <Stage>
Scene:   <Scene when applicable>

What do you need to do?

[ Work Order ]
[ Field Wiring ]
[ Setup Instructions ]
[ Takedown Instructions ]
[ Testing Procedures ]
[ ...future functions... ]
```

The exact visual design is application work and is not defined by this document.

The architectural requirement is that one resolved context establishes the same task choices regardless of whether it came from a physical scan or manual browser lookup.

## Task Adapter Rule

Each task-specific function receives the same resolved context and applies only the scope/content rules it owns.

### Work Order

Work Orders already use permanent Production Database Display identity when a Work Order concerns a Display.

The shared architecture must preserve that existing capability rather than rebuilding Work Order authority inside FieldWiring or another presentation application.

A Work Order action may remain centered on the selected `display_id` even when other actions promote to a Scene/Stage context.

### Field Wiring

FieldWiring receives the selected Display plus its current Stage/Scene/Preview relationships and resolves the applicable wiring context.

The proven FormView rules must remain intact, including:

- distinct Show Background versus Musical/RGB Preview contexts;
- LOR-authoritative controller/channel/network data;
- `BackgroundFile` or its controlled successor relationship;
- field-lead reduction; and
- multiple supporting wiring images.

If multiple Displays resolve to the same requisite wiring context, scanning or manually selecting any of them must produce the same wiring content set.

### Setup Instructions

Setup uses the same Display/Stage/Scene hierarchy but selects current Setup content from the applicable documentation scope.

Conceptually the content branch is:

```text
<resolved Stage/Sub-stage/Scene root>\Procedures\Setup
```

Normal field presentation must exclude archive and working/source material and present only current approved Setup instruction content.

### Takedown Instructions

Takedown uses the same resolved field hierarchy and applies the Takedown content rules owned by Setup and Deployment.

Conceptually the content branch is:

```text
<resolved Stage/Sub-stage/Scene root>\Procedures\Takedown
```

The context resolver does not need a separate Takedown identity model.

### Testing Procedures

Testing consumes the same selected permanent Display identity and any relevant hierarchy, but Testing owns the rules for whether the presented procedure/state is Display-specific, container/session-specific, or shared at another scope.

The context resolver must not invent Testing scope rules.

## Same Engine, Different Task Scope

The intended architecture is:

```text
               Display QR       Manual Browser Lookup
                    \                 /
                     \               /
                      v             v
                    permanent identity
                           |
                           v
                 FIELD CONTEXT RESOLVER
                           |
                 Display + hierarchy facts
                           |
                           v
                    FIELD HOME / MENU
                           |
        +-----------+-------+--------+---------+
        |           |                |         |
        v           v                v         v
   Work Order   FieldWiring        Setup    Takedown   ...
   display      scene/stage       scene/     scene/
   context      + preview         stage      stage
```

The resolver is shared.

The task scope and content ownership remain separate.

This prevents multiple applications or entry paths from drifting into different answers about the same Display's identity or physical organization.

## Context Idempotence

The resolver and each task adapter must be deterministic for the same current database state.

For group-oriented functions, the task result is **context-idempotent**.

If Display A and Display B belong to the same current field-documentation scope for a task, scanning either one, manually selecting either one, or deliberately browsing to that resolved Scene/Stage and choosing that task must produce the same base task result.

Example:

```text
Display A QR --------\
Display B search -----+--> same Scene --> Field Wiring --> same wiring view
Scene X browse -------/

Display A QR --------\
Display B search -----+--> same Scene --> Setup --> same current Setup instructions
Scene X browse -------/
```

The application may retain `trigger_display_id` to highlight or orient the operator to the item they selected, but that highlighting must not change the underlying shared content set.

## Stage / Scene Documentation Scope

The established Google Drive documentation rules use this hierarchy:

```text
Display
    -> owning Scene, when applicable
    -> owning Sub-stage, when applicable
    -> owning Stage
```

A Scene is meaningful when a group of Displays is installed/wired as one physical unit or shares common field documentation.

Therefore group-oriented task adapters should normally prefer the established Scene scope when the task belongs to that group, and fall back to the applicable Stage/Sub-stage when no Scene scope exists.

The resolver or task adapter must not create a Scene merely because a path, filename, or LOR background happens to pass through a similarly named folder.

## Wiring and Setup Share Resolution, Not Content Rules

Wiring and Setup use the same physical Stage/Scene organization but remain distinct content systems.

For Wiring, current published content is associated with branches such as:

```text
Wiring\BackgroundStage
Wiring\MusicalStage
```

and the Preview/Scene `BackgroundFile` relationship is part of choosing the correct wiring context.

For Setup, current field content is presented from the applicable Setup branch, currently under:

```text
Procedures\Setup
```

The exact organization beneath a task branch is owned by that task's subsystem and may evolve without changing the QR payload, manual lookup behavior, or base context resolver.

## Preview Ambiguity

The current LOR production model is Preview-scoped. A permanent Display can legitimately participate in more than one Preview context.

The shared resolver must therefore distinguish between:

- the Display's permanent physical identity and Stage/Scene organization; and
- purpose-specific Preview context required by a task such as Wiring.

The base resolver must not guess among valid distinct Preview contexts.

FieldWiring must apply its controlled Preview rules, including the difference between Show Background and Musical/RGB contexts.

Setup/Takedown should not create duplicate document identity merely because more than one LOR Preview contains the same physical Display when the same physical Stage/Scene instruction applies.

## Error / Ambiguity Behavior

A scan or manual lookup must fail visibly rather than guess when any required identity is ambiguous or invalid.

Examples include:

- unknown `display_id`;
- ambiguous manual Display-name search;
- retired/recycled asset when the selected task should not apply;
- conflicting current Stage relationships;
- ambiguous Scene membership relevant to the selected task;
- required Wiring Preview context cannot be determined;
- current task content is missing or not approved.

The operator should be told what could not be resolved and the responsible subsystem should correct the underlying data/documentation.

The field application must not repair authority data as a side effect of viewing it.

## Relationship to Current Work Order Function

Work Orders are already an operational Production Database subsystem and already use `display_id` when work concerns a Display.

The field-home architecture should integrate the existing Work Order function as one task destination rather than replace its database lifecycle or duplicate Work Order records.

Any existing working Work Order route should be preserved unless separately changed through the Work Order subsystem.

## Browser Presentation Boundary

`my.sheboyganlights.org` is the intended normal field and office-browser presentation layer for this information.

A normal volunteer or office operator should not need to know:

- PostgreSQL schema;
- Directus collection paths;
- GitHub repository paths;
- Google Drive folder hierarchy;
- LOR Preview UUIDs; or
- document source/publishing mechanics.

The browser experience should expose simple **Scan**, **Find**, and controlled **Browse** entry methods followed by the physical asset/context and the task choices that make sense for it.

## No Schema Decision Yet

This document defines behavior and responsibility boundaries only.

Before creating a new database view, function, table, endpoint, or service:

1. inspect the current production relationships and grants;
2. determine whether the resolver can be expressed from existing authoritative objects;
3. define the minimum read-only context contract needed by both scan and manual browser entry;
4. verify the current Work Order scan/task integration so it can be reused rather than duplicated; and
5. propose schema only when a demonstrated gap cannot be satisfied safely by existing objects.

## Related Documents

- [Asset Identity and Scan Payload Standard](Asset_Identity_and_Scan_Payload_Standard.md)
- [Labeling and Scanning](README.md)
- [Field Document Publication and Currentness Contract](Field_Document_Publication_and_Currentness_Contract.md)
- [FieldWiring Engineering Recovery and Compatibility Contract](../09_Wiring_System/FieldWiring_Engineering_Recovery_and_Compatibility_Contract.md)
- [Wiring System](../09_Wiring_System/README.md)
- [Setup and Deployment](../12_Setup_and_Deployment/README.md)
- [Work Orders](../06_Work_Orders/README.md)
- [Work Order System Design](../06_Work_Orders/Work_Order_System_Design.md)
- [Testing System](../05_Testing_System/README.md)
- [Google Drive Document Organization Procedure](../../../00_Project_Overview/01-Google_Drive_Document_Organization_Procedure.md)
