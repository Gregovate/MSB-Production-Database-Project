# Google Drive Path Resolution Contract

| Document control | Value |
|---|---|
| Status | DRAFT — governing filesystem/path contract |
| Current revision | 2026-08-22 |
| Owner | MSB Database Administrator |
| Applies to | Folder Alignment, Field Context Resolution, FieldWiring, Setup, Takedown, Inspection, future field-document applications |
| Code/schema status | Documentation contract; current FieldWiring release candidate does not yet enforce every required child-branch marker |

## Purpose

This document owns the Google Shared Drive filesystem rules used to resolve editable engineering documentation from LOR and Production Database context.

The Google Shared Drive **Display Folders** repository remains the authoritative editable engineering-document repository. PostgreSQL owns durable Production Database identity and relationships; it does not replace the Drive repository with non-editable document or image blobs.

Folder Alignment, FieldWiring, Setup/Takedown presentation, and future applications must consume this filesystem contract rather than inventing separate path rules.

The general architecture is:

```text
permanent Production Database identity
        +
current LOR Preview / Scene evidence
        |
        v
resolve current Stage / Sub-stage / Scene / Display context
        |
        v
interpret applicable BackgroundFile/path evidence
        |
        v
resolve Google Drive documentation root
        |
        +--> Wiring
        +--> Procedures
        +--> Photos
        +--> other standardized helper branches
```

The full mounted-drive path is evidence and a runtime filesystem locator. It is not permanent asset identity and must not be encoded into the physical QR payload.

## Authority Boundary

This document owns:

- the standard Stage/Sub-stage/Scene/Display folder hierarchy;
- the filesystem meaning of `PreviewBackground`;
- accepted path evidence from LOR `BackgroundFile` values;
- Stage/Sub-stage/Scene/Display path-depth interpretation;
- the rule for locating shared `Wiring` and `Procedures` branches;
- Stage/Sub-stage/Scene naming rules used for documentation resolution; and
- the rule that ambiguity must be reported rather than guessed.

Folder Alignment implements and validates these rules. It does not own a separate competing filesystem contract.

Field applications consume the resolved scope. They do not redefine the Drive hierarchy.

## Standard Structured Roots

Stage, Sub-stage, and Scene roots use the same standardized helper structure:

```text
<Stage / Sub-stage / Scene>\
├── PreviewBackground\
├── Photos\
│   ├── Current\
│   └── Historical\
├── Procedures\
│   ├── Inspection\
│   ├── Setup\
│   │   ├── Archive\
│   │   ├── images\
│   │   └── SourceDocs\
│   └── Takedown\
│       ├── Archive\
│       ├── images\
│       └── SourceDocs\
└── Wiring\
    ├── BackgroundStage\
    │   └── SourceDocs\
    └── MusicalStage\
        └── SourceDocs\
```

Display folders intentionally use a smaller standard structure:

```text
<Display>\
├── PreviewBackground\
└── Photos\
    ├── Current\
    └── Historical\
```

A Display does not automatically receive standardized `Wiring` or `Procedures` branches.

Not every Display requires its own `PreviewBackground` image.

## Controlled Marker Path

The standard marker is:

```text
_MSB-DB-Source-Folder_READ-ME-FIRST-AND-DO-NOT-DELETE.txt
```

The governing rule is:

> **Every folder that FieldWiring or the future Procedure system uses as part of its controlled application path must contain the marker.**

The marker therefore applies to both the structured scope and the application-facing branches below it.

For current Stage/Sub-stage/Scene field-document paths, required marker locations include:

```text
<Stage / Sub-stage / Scene>\
├── _MSB-DB-Source-Folder_READ-ME-FIRST-AND-DO-NOT-DELETE.txt
│
├── PreviewBackground\
│   └── _MSB-DB-Source-Folder_READ-ME-FIRST-AND-DO-NOT-DELETE.txt
│
├── Procedures\
│   ├── _MSB-DB-Source-Folder_READ-ME-FIRST-AND-DO-NOT-DELETE.txt
│   ├── Inspection\
│   │   └── _MSB-DB-Source-Folder_READ-ME-FIRST-AND-DO-NOT-DELETE.txt
│   ├── Setup\
│   │   ├── _MSB-DB-Source-Folder_READ-ME-FIRST-AND-DO-NOT-DELETE.txt
│   │   └── images\
│   │       └── _MSB-DB-Source-Folder_READ-ME-FIRST-AND-DO-NOT-DELETE.txt
│   └── Takedown\
│       ├── _MSB-DB-Source-Folder_READ-ME-FIRST-AND-DO-NOT-DELETE.txt
│       └── images\
│           └── _MSB-DB-Source-Folder_READ-ME-FIRST-AND-DO-NOT-DELETE.txt
│
└── Wiring\
    ├── _MSB-DB-Source-Folder_READ-ME-FIRST-AND-DO-NOT-DELETE.txt
    ├── BackgroundStage\
    │   └── _MSB-DB-Source-Folder_READ-ME-FIRST-AND-DO-NOT-DELETE.txt
    └── MusicalStage\
        └── _MSB-DB-Source-Folder_READ-ME-FIRST-AND-DO-NOT-DELETE.txt
```

A current Display/shared-folder `PreviewBackground` that is used as LOR/application path evidence must also be marked.

`SourceDocs` and `Archive` are excluded working/history boundaries and are not part of normal field traversal or presentation. They are not field-application marker targets unless an approved future design changes that role.

`Setup\images` and `Takedown\images` are part of the future Procedure content path and must be marked.

`Photos` is not currently part of the FieldWiring or Procedure application path.

### Current FieldWiring implementation gap

The FieldWiring release-candidate image resolver currently validates the structured Stage/Scene root and checks markers on `Wiring` and `PreviewBackground`, but it does not yet require a marker on the selected `BackgroundStage` / `MusicalStage` child branch.

That is an implementation gap against this current contract. Do not weaken the folder/marker documentation to match the incomplete enforcement. The FieldWiring engineering work must be updated separately before final deployment acceptance.

## Naming Rules for Documentation Scope

The current deterministic filesystem classification rules are:

```text
NN-Name-XY      = Stage root
NNa-Name-XY     = Sub-stage root
NN-Name         = Scene under the owning Stage
NNa-Name        = Scene under the owning Sub-stage
unprefixed name = Display or shared Display/group folder
Root            = owning Preview Stage root in a Background Preview
```

Examples:

```text
07-Whoville-WV       -> Stage
07a-Who Forest-WF    -> Sub-stage
13-Christmas Story   -> Scene
PB-MommaBear         -> Display/group folder
```

A path passing through an unprefixed Display/group folder must not promote that folder into a Scene merely because LOR uses a Scene marker with a related name.

The naming rules are used together with actual folder hierarchy and explicit path evidence. Conflicting evidence is a review condition.

## `PreviewBackground` Is a Stable Helper, Not a Mandatory Display Asset

`PreviewBackground` is the standard stable location for an image intentionally used as an LOR Preview or Scene background.

It may exist at any scope that independently owns such a background:

```text
<Stage>\PreviewBackground\
<Sub-stage>\PreviewBackground\
<Scene>\PreviewBackground\
<Display>\PreviewBackground\
```

A Display is **not required** to have its own `PreviewBackground` image.

A Display may instead use context resolved from:

- its owning Scene;
- its owning Sub-stage;
- its owning Stage / Background Preview; or
- another current valid LOR path relationship governed by this contract.

This is expected behavior, not a missing-document error.

## Accepted `BackgroundFile` Path Evidence

The LOR `BackgroundFile` value is current filesystem evidence. It can legitimately serve more than one purpose.

Two important accepted forms are:

### `PreviewBackground` anchor

Example:

```text
<Stage>\<Scene>\PreviewBackground\scene-background.jpg
```

The folder immediately above `PreviewBackground` is the background owner.

The application uses the owner depth and naming rules to determine the applicable structured documentation scope.

### Direct Wiring path

A background may deliberately point directly into the applicable Wiring branch when that was the practical authoring choice.

Examples:

```text
<Stage>\Wiring\BackgroundStage\tagged-image.jpg
<Stage>\<Scene>\Wiring\BackgroundStage\tagged-image.jpg
<Stage>\<Scene>\Wiring\MusicalStage\tagged-image.jpg
```

This is valid explicit path evidence.

The path identifies:

- the owning Stage/Sub-stage/Scene from the folders above `Wiring`; and
- the applicable Wiring context from `BackgroundStage` or `MusicalStage`.

Applications must not require the image to be moved into `PreviewBackground` merely to satisfy a resolver.

Moving or renaming an LOR-referenced file can break LOR Preview Editor and remains a controlled human decision.

# Worked Path-Resolution Examples

The following examples are part of the governing contract because they show how path depth, naming, and the standard helper folders work together.

## Example 1 — Stage-level `PreviewBackground`

```text
21-Polar Bear Playground-PB\
    PreviewBackground\
        Polar-Bear-Stage.jpg
```

Resolution:

```text
BackgroundFile
    -> 21-Polar Bear Playground-PB\PreviewBackground\Polar-Bear-Stage.jpg
    -> PreviewBackground owner = 21-Polar Bear Playground-PB
    -> name matches NN-Name-XY
    -> documentation root = Stage 21
```

Task resolution:

```text
Field Wiring / Background
    -> 21-Polar Bear Playground-PB\Wiring\BackgroundStage

Field Wiring / Musical
    -> 21-Polar Bear Playground-PB\Wiring\MusicalStage

Setup
    -> 21-Polar Bear Playground-PB\Procedures\Setup

Takedown
    -> 21-Polar Bear Playground-PB\Procedures\Takedown
```

This is appropriate when the whole Stage shares the background/documentation context.

## Example 2 — Scene-level `PreviewBackground`

```text
21-Polar Bear Playground-PB\
    21-Sliding Penguins\
        PreviewBackground\
            Sliding-Penguins.jpg
```

Resolution:

```text
BackgroundFile
    -> ...\21-Sliding Penguins\PreviewBackground\Sliding-Penguins.jpg
    -> PreviewBackground owner = 21-Sliding Penguins
    -> name matches NN-Name
    -> documentation root = Scene 21-Sliding Penguins
```

Task resolution:

```text
Field Wiring
    -> 21-Sliding Penguins\Wiring\...

Setup
    -> 21-Sliding Penguins\Procedures\Setup

Takedown
    -> 21-Sliding Penguins\Procedures\Takedown
```

Every Display whose applicable task scope is this Scene can reach the same shared package without requiring a separate background or duplicate procedure under each Display.

## Example 3 — Display-level `PreviewBackground` under a Scene

```text
21-Polar Bear Playground-PB\
    21-Sliding Penguins\
        PB-SlidingPenguins-07\
            PreviewBackground\
                Penguin-07.jpg
```

Resolution:

```text
BackgroundFile
    -> ...\PB-SlidingPenguins-07\PreviewBackground\Penguin-07.jpg
    -> PreviewBackground owner = PB-SlidingPenguins-07
    -> unprefixed folder = Display/group
    -> Display does not automatically own Wiring/Procedures
    -> climb to parent structured scope
    -> parent 21-Sliding Penguins matches NN-Name
    -> shared documentation root = Scene 21-Sliding Penguins
```

Relationship:

```text
PB-SlidingPenguins-07
        |
        | owns its own LOR background/photo context
        v
PreviewBackground

PB-SlidingPenguins-07
        |
        | inherits shared field documentation
        v
21-Sliding Penguins
        +--> Wiring
        +--> Procedures
```

This is the key distinction between **background ownership** and **shared documentation ownership**.

## Example 4 — Display-level `PreviewBackground` directly under a Stage

```text
21-Polar Bear Playground-PB\
    PB-MommaBear\
        PreviewBackground\
            MommaBear.jpg
```

Resolution:

```text
BackgroundFile
    -> ...\PB-MommaBear\PreviewBackground\MommaBear.jpg
    -> background owner = PB-MommaBear Display
    -> no structured Scene/Sub-stage between Display and Stage
    -> climb to 21-Polar Bear Playground-PB
    -> documentation root = Stage 21
```

Task resolution:

```text
PB-MommaBear background
    = Display-specific LOR visual context

PB-MommaBear Field Wiring / Procedures
    = inherited from Stage 21 unless another authoritative relationship defines a more specific shared scope
```

## Example 5 — Direct Stage Wiring path

```text
21-Polar Bear Playground-PB\
    Wiring\
        BackgroundStage\
            Background-Stage-21-Tagged.jpg
```

Resolution:

```text
BackgroundFile
    -> ...\21-Polar Bear Playground-PB\Wiring\BackgroundStage\Background-Stage-21-Tagged.jpg
    -> path enters Wiring\BackgroundStage directly
    -> folder above Wiring = Stage 21
    -> wiring context = Background / Static
    -> documentation root = Stage 21
```

No `PreviewBackground` hop is required because the explicit path already identifies both the owner and the Wiring branch.

This preserves the practical FormView-era technique when pointing directly at the wiring folder is simpler.

## Example 6 — Direct Scene Wiring path

```text
21-Polar Bear Playground-PB\
    21-Sliding Penguins\
        Wiring\
            BackgroundStage\
                Sliding-Penguins-Tagged.jpg
```

Resolution:

```text
BackgroundFile
    -> ...\21-Sliding Penguins\Wiring\BackgroundStage\Sliding-Penguins-Tagged.jpg
    -> path enters Wiring\BackgroundStage directly
    -> folder above Wiring = 21-Sliding Penguins
    -> name matches NN-Name
    -> documentation root = Scene 21-Sliding Penguins
    -> wiring context = Background / Static
```

This is particularly useful when the Scene wiring drawing itself is also the best LOR visual background.

## Example 7 — Scene owns the background; individual Displays do not

```text
21-Polar Bear Playground-PB\
    21-Sliding Penguins\
        PreviewBackground\
            Sliding-Penguins.jpg
        Wiring\
            BackgroundStage\
                Sliding-Penguins-Wiring.jpg
        PB-SlidingPenguins-06\
        PB-SlidingPenguins-07\
        PB-SlidingPenguins-08\
```

None of the three Displays needs a Display-level `PreviewBackground`.

Resolution for any of those Displays:

```text
selected/scanned Display
    -> current Scene membership = 21-Sliding Penguins
    -> Scene owns the applicable background/context
    -> documentation root = 21-Sliding Penguins
    -> all three Displays resolve to the same base Scene Wiring / Procedure package
```

This is the expected idempotent field behavior.

## Example 8 — Sub-stage-level ownership

```text
07-Whoville-WV\
    07a-Who Forest-WF\
        PreviewBackground\
            Who-Forest.jpg
        Wiring\
            BackgroundStage\
        Procedures\
            Setup\
```

Resolution:

```text
BackgroundFile
    -> ...\07a-Who Forest-WF\PreviewBackground\Who-Forest.jpg
    -> owner matches NNa-Name-XY
    -> documentation root = Sub-stage 07a
```

A Display under that Sub-stage without a more specific Scene inherits the Sub-stage Wiring/Procedure package.

## Example 9 — Naming and path evidence conflict

Suppose the LOR Scene name is:

```text
21-Sliding Penguins
```

but its current `BackgroundFile` points into:

```text
21-Polar Bear Playground-PB\
    PB-MommaBear\
        PreviewBackground\
            Wrong-Image.jpg
```

The path says Display `PB-MommaBear`; the deterministic Scene name says Scene `21-Sliding Penguins`.

This is a **review condition**.

The resolver must not silently choose one because it produces a usable folder. Folder Alignment should surface the contradiction for correction.

## Example 10 — `Root` in a Background Preview

For a Background Preview whose Preview Stage is already definitively Stage 21:

```text
Scene Name = Root
```

means:

```text
use Stage 21 root
```

It does **not** mean:

```text
21-Polar Bear Playground-PB\Root\
```

`Root` is a scope marker, not a child folder.

## Resolver Order

A downstream resolver should apply this contract conservatively:

1. resolve permanent Display/Stage relationships from the Production Database when entry starts from a Display;
2. resolve applicable current Scene and Preview context from authoritative relationships;
3. obtain the applicable current LOR path evidence; a Scene-level background may be more specific than a Preview-level background when that Scene is the selected context;
4. if the path enters `Wiring\BackgroundStage` or `Wiring\MusicalStage`, use the folders above `Wiring` as explicit ownership evidence and retain the branch as Wiring-context evidence;
5. otherwise, if the path enters `PreviewBackground`, treat its parent as the background owner;
6. classify the owner and parent hierarchy using the Stage/Sub-stage/Scene/Display naming rules;
7. if the immediate owner is a Display/group, climb through the actual parent hierarchy to the nearest valid Scene/Sub-stage/Stage root for shared Wiring/Procedure discovery;
8. if no usable explicit path evidence exists, use the current database hierarchy and deterministic naming rules to resolve the applicable structured scope;
9. verify the required markers along the controlled application path;
10. append only the standardized relative branch owned by the selected task;
11. if path evidence, naming, markers, and current relationships conflict or remain ambiguous, report the condition instead of guessing.

The resolver must not require a Display-level background merely because the entry point was a Display.

## Task Branches After Scope Resolution

After resolving the documentation root, the task determines the relative branch.

Every directory used in the selected application path must satisfy the marker rule above.

### Field Wiring

```text
<documentation root>\Wiring\BackgroundStage
```

or:

```text
<documentation root>\Wiring\MusicalStage
```

A direct Wiring `BackgroundFile` path may already identify the applicable branch.

### Setup

```text
<documentation root>\Procedures\Setup
```

Published Setup images use the marked:

```text
<documentation root>\Procedures\Setup\images
```

### Takedown

```text
<documentation root>\Procedures\Takedown
```

Published Takedown images use the marked:

```text
<documentation root>\Procedures\Takedown\images
```

### Inspection

```text
<documentation root>\Procedures\Inspection
```

The application must not maintain a separate hard-coded full path for each individual field document when the standardized hierarchy can resolve it.

## Relationship to Production Database Identity

The Production Database remains responsible for permanent identity and current relationships.

The normal application path is:

```text
permanent Display identity
    -> current Stage/Scene/Preview relationships
    -> applicable current LOR path evidence
    -> Google Drive documentation root
    -> selected task branch
```

A QR code must not embed the Google Drive path.

Where a browser/service cannot consume a mounted-drive path directly, the service may resolve the same hierarchy through a controlled Google Drive/file-serving mechanism. That mechanism must preserve the scope, branch, and marker rules in this contract.

## Relationship to Folder Alignment

Folder Alignment is the implementation/validation tool for these filesystem rules.

Folder Alignment should:

- read current V7 parser evidence;
- inspect the actual Google Drive hierarchy;
- classify Stage/Sub-stage/Scene/Display scopes using this contract;
- recognize both `PreviewBackground` and deliberate direct Wiring path evidence;
- report path/name/hierarchy conflicts;
- validate required markers and standardized helper folders where applicable; and
- remain read-only except for separately controlled additive helper-folder/marker updaters.

When this document and Folder Alignment implementation disagree, the discrepancy must be reviewed explicitly. Do not silently treat Folder Alignment implementation behavior as a new filesystem standard.

## Safety Rules

Path resolution must:

- preserve the existing Stage/Sub-stage/Scene/Display hierarchy;
- require the marker on every directory used as part of the current field-application path;
- treat `PreviewBackground` as an infrastructure/helper folder, never as the scope itself;
- not require every Display to have `PreviewBackground`;
- accept deliberate direct Wiring paths as valid current evidence;
- distinguish Display background ownership from shared Stage/Sub-stage/Scene documentation ownership;
- climb only through actual established parent folders, not fuzzy guesses;
- not create missing `Wiring` or `Procedures` branches as a side effect of lookup;
- not move or rename LOR background images during lookup;
- expose ambiguity instead of silently choosing a neighboring Scene or Stage;
- keep archive/source folders out of normal field publication; and
- keep Google Drive documents/images editable in the filesystem rather than copying them into a non-editable database blob.

## Related Documents

- [Google Drive Folder Structure](00-Google_Drive.md)
- [Google Drive Document Organization Procedure](01-Google_Drive_Document_Organization_Procedure.md)
- [MSB Database Source Folder Marker — Operator Procedure](03-MSB_DB_Source_Folder_Marker_Operator_Procedure.md)
- [Stage / Sub-stage / Scene Folder Scaffold](04-Stage_Substage_Scene_Folder_Scaffold.md)
- [Folder Alignment Engineering Design](../01_LOR_System/02_Data_Extraction/Folder_Alignment/Folder_Alignment_Engineering_Design.md)
- [LOR Preview Parser Architecture](../01_LOR_System/02_Data_Extraction/LOR_Preview_Parser_Architecture.md)
- [Shared Field Context Resolution Contract](../02_Production_Database/01_System_Architecture/07_Labeling_and_Scanning/Field_Context_Resolution_Contract.md)
- [FieldWiring Engineering Recovery and Compatibility Contract](../02_Production_Database/01_System_Architecture/09_Wiring_System/FieldWiring_Engineering_Recovery_and_Compatibility_Contract.md)
