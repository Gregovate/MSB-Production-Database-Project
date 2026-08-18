# BackgroundFile and Documentation Scope Resolution Contract

| Document control | Value |
|---|---|
| Status | DRAFT — documented current design intent |
| Current revision | 2026-08-17 |
| Owner | MSB Database Administrator |
| Scope | Folder Alignment / field-document path resolution |
| Code/schema status | Documentation only; no code or schema change authorized |

## Purpose

This document makes explicit how an LOR `BackgroundFile` path, the standardized Google Drive folder structure, and the established Stage/Scene naming rules work together to locate Wiring and Procedure documentation.

There is **not** a requirement that every Display have its own `PreviewBackground` image or even its own Google Drive Display folder.

A current LOR background may legitimately be owned at:

```text
Stage / Preview level
Sub-stage level
Scene level
Display level
```

and, when useful, an LOR background may also deliberately point directly into an applicable Wiring folder.

The resolver therefore uses the path as **explicit filesystem evidence**, determines how deep in the established hierarchy that evidence points, and then resolves the applicable task/documentation scope.

The path is evidence and navigation context. It is not permanent Production Database identity.

## Accepted Path Patterns

### Standard `PreviewBackground` anchor

The current Drive structure supports:

```text
<Stage>\PreviewBackground\...
<Stage>\<Sub-stage>\PreviewBackground\...
<Stage>\<Scene>\PreviewBackground\...
<Stage>\<Scene>\<Display>\PreviewBackground\...
<Stage>\<Display>\PreviewBackground\...
```

`PreviewBackground` is a fixed helper-folder name that makes path depth deterministic.

When the path uses this form, the folder immediately above `PreviewBackground` is the **background owner**.

### Direct Wiring path

A valid LOR `BackgroundFile` may also point directly into a standardized Wiring branch when that is the easiest and most useful authoring relationship:

```text
<Stage>\Wiring\BackgroundStage\...
<Stage>\Wiring\MusicalStage\...

<Sub-stage>\Wiring\BackgroundStage\...
<Sub-stage>\Wiring\MusicalStage\...

<Scene>\Wiring\BackgroundStage\...
<Scene>\Wiring\MusicalStage\...
```

This is valid explicit filesystem evidence.

For Field Wiring, such a path may identify both:

- the owning Stage/Sub-stage/Scene; and
- the exact applicable Wiring branch.

It must not be treated as an obsolete path merely because a `PreviewBackground` folder also exists.

### Other explicit infrastructure paths

Folder Alignment already recognizes infrastructure components such as:

```text
PreviewBackground
Photos
Procedures
Wiring
```

as belonging to an enclosing Stage/Sub-stage/Scene/Display scope rather than becoming scopes themselves.

The same principle applies to future field-document resolution: strip the recognized infrastructure branch to determine its owning physical/documentation folder.

## Background Ownership Is Not Always Display Ownership

A Display does not need its own background.

Examples:

```text
Display A -----\
Display B ------+--> Scene 21-Polar Bears
Display C -----/         |
                         v
             Scene\PreviewBackground\image.jpg
```

All three Displays may legitimately use the Scene-level background/path evidence.

Likewise, a Stage-level background can provide the applicable scope for Displays that do not have a subordinate Scene or more specific background.

Therefore the resolver must not interpret the absence of:

```text
<Display>\PreviewBackground
```

as missing documentation.

The applicable Scene/Sub-stage/Stage context may intentionally own the background and the shared field documentation.

## Path Depth and Documentation Scope

The important rule is **how deep the valid path resolves in the established physical hierarchy**.

### Stage / Preview-level path

Example:

```text
<Stage>\PreviewBackground\image.jpg
```

or:

```text
<Stage>\Wiring\BackgroundStage\image.jpg
```

Resolved documentation owner:

```text
<Stage>
```

Applicable task branches can then include:

```text
<Stage>\Wiring\...
<Stage>\Procedures\...
```

### Sub-stage-level path

Example:

```text
<Stage>\<Sub-stage>\PreviewBackground\image.jpg
```

or:

```text
<Stage>\<Sub-stage>\Wiring\BackgroundStage\image.jpg
```

Resolved documentation owner:

```text
<Sub-stage>
```

### Scene-level path

Example:

```text
<Stage>\<Scene>\PreviewBackground\image.jpg
```

or:

```text
<Stage>\<Scene>\Wiring\BackgroundStage\image.jpg
```

Resolved documentation owner:

```text
<Scene>
```

This is the normal shared scope for all member Displays when the Scene represents one physical installation/wiring group.

### Display-level `PreviewBackground`

Example:

```text
<Stage>\<Scene>\<Display>\PreviewBackground\image.jpg
```

or:

```text
<Stage>\<Display>\PreviewBackground\image.jpg
```

The immediate background owner is the Display folder.

However, the standardized Display root intentionally does **not** automatically contain `Wiring` or `Procedures`.

For shared Wiring/Procedure lookup, resolution therefore walks upward through the actual folder hierarchy to the nearest valid Scene, Sub-stage, or Stage documentation root.

Examples:

```text
Stage\Scene\Display\PreviewBackground\image
                    |
                    v
               Display owner
                    |
                    v
            enclosing Scene root
                    |
                    +--> Scene\Wiring\...
                    +--> Scene\Procedures\...
```

and:

```text
Stage\Display\PreviewBackground\image
              |
              v
         Display owner
              |
              v
          Stage root
              |
              +--> Stage\Wiring\...
              +--> Stage\Procedures\...
```

The application must not invent `Wiring` or `Procedures` under a Display merely because that Display owns an LOR background.

## Stage and Scene Naming Rules Remain Part of Resolution

Filesystem path evidence is strong when it is valid, but it is not the only resolution evidence.

The current Folder Alignment naming rules remain contractual:

```text
NN-Name-XY       = Stage root
NNa-Name-XY      = Sub-stage root
NN-Name          = Scene
NNa-Name         = Scene under Sub-stage
unprefixed name  = Display/shared group evidence
Root             = owning Stage root for a Background Preview with definitive Preview StageID
```

These rules are used to:

- classify the folder/path owner;
- resolve a scope when no usable explicit background path exists;
- validate that an explicit path is consistent with the LOR Scene/Preview identity; and
- detect conflicts that require review.

An explicit path and the naming classification should agree.

If they conflict materially, the resolver must surface the disagreement rather than choosing whichever answer is more convenient.

## Resolution Evidence Order

For field-document discovery, the evidence should be applied conservatively.

Conceptually:

1. start from the permanent Display and current Production Database relationships when the request comes from Scan/Find;
2. identify the applicable current LOR Preview/Scene context for the selected task;
3. use a valid `BackgroundFile` as explicit filesystem evidence when one exists;
4. determine the deepest valid Stage/Sub-stage/Scene/Display owner represented by that path;
5. use the established Stage/Scene naming rules to classify and validate that owner;
6. if the path is absent or unusable, use the current hierarchy/naming relationships rather than requiring a Display-level background;
7. resolve the nearest valid Stage/Sub-stage/Scene documentation root for shared task content;
8. select the task-specific relative branch;
9. fail visibly when the evidence is contradictory or ambiguous.

The path is therefore a **location pointer and scope clue**, not the only source of truth.

## Field Wiring Resolution

Field Wiring has one additional useful behavior: a direct Wiring `BackgroundFile` can already identify the applicable Wiring branch.

Examples:

```text
Scene\Wiring\BackgroundStage\image.jpg
```

resolves directly to:

```text
Scene
+ Background/Static Wiring context
```

while:

```text
Scene\PreviewBackground\image.jpg
```

resolves to:

```text
Scene
```

and FieldWiring then selects the required standardized branch:

```text
Scene\Wiring\BackgroundStage
```

or:

```text
Scene\Wiring\MusicalStage
```

based on the applicable LOR/field context.

Both patterns are valid.

## Procedure Resolution

Procedures use the resolved Stage/Sub-stage/Scene owner but do not depend on the background file itself being a procedure document.

After scope resolution:

```text
Setup      -> <documentation root>\Procedures\Setup
Takedown   -> <documentation root>\Procedures\Takedown
Inspection -> <documentation root>\Procedures\Inspection
```

A direct Wiring background path may still provide useful evidence that the owner is a particular Scene; the Procedure adapter then uses that same Scene root and chooses its own Procedure branch.

This is the reusable benefit of the folder structure: **resolve scope once, then choose the task branch.**

## Relationship to FormView

Historical FormView had a simpler requirement: the selected Preview's `BackgroundFile` needed to lead to the image directory FormView should display and paginate.

Pointing the LOR background directly into a Wiring directory was therefore often the easiest solution and remains valid filesystem evidence.

The new Scene-aware model is broader:

```text
BackgroundFile
    -> explicit path/scope evidence

Production Database + Scene/Stage naming
    -> durable identity and current hierarchy

standardized helper folders
    -> task content discovery
```

The future browser resolver should not require every LOR background to be moved into `PreviewBackground` merely to make the application work.

## Relationship to Database Identity

The QR/manual lookup starts from permanent Production Database identity, not a path.

Conceptually:

```text
Display identity
    -> current Stage/Scene relationships
    -> applicable Preview/Scene
    -> BackgroundFile/path evidence when available
    -> resolved documentation root
    -> selected task branch
```

A mapped `G:\...` path must not become permanent asset identity.

Where a browser/service cannot consume the mapped-drive path directly, it must reproduce the same scope-resolution rules through the controlled Google Drive/file-serving integration.

## Safety Rules

Path resolution must:

- preserve the current Stage/Sub-stage/Scene/Display hierarchy;
- accept both standardized `PreviewBackground` paths and deliberate direct Wiring paths as valid evidence;
- never require every Display to own a `PreviewBackground` image;
- allow a Scene/Sub-stage/Stage background to serve its member Displays;
- treat infrastructure folders such as `PreviewBackground`, `Wiring`, `Procedures`, and `Photos` as branches, not physical scopes;
- use the accepted Stage/Scene naming rules to classify and validate path ownership;
- distinguish Display background ownership from shared documentation ownership;
- climb only through actual established parent folders, not fuzzy guesses;
- not create missing folders as a side effect of lookup;
- not move or rename LOR background images during lookup;
- expose path/naming/hierarchy conflicts instead of silently choosing one;
- keep archive/source folders out of normal field publication; and
- keep Google Drive documents/images editable in the filesystem instead of copying them into a non-editable database blob.

## Regression Cases

Future resolver testing should include at minimum:

1. Stage-level `PreviewBackground` -> Stage Wiring/Procedures;
2. Scene-level `PreviewBackground` -> Scene Wiring/Procedures for every member Display;
3. Sub-stage-level `PreviewBackground` -> Sub-stage Wiring/Procedures;
4. Display under Scene with Display-level `PreviewBackground` -> Display background owner, then parent Scene shared Wiring/Procedures;
5. Display directly under Stage with Display-level `PreviewBackground` -> Stage shared Wiring/Procedures;
6. Display with no `PreviewBackground` but current Scene-level background -> Scene Wiring/Procedures;
7. Display with no background and no Scene -> controlled Stage/Sub-stage hierarchy fallback;
8. direct `Scene\Wiring\BackgroundStage\image` -> Scene + Background Wiring branch;
9. direct `Stage\Wiring\MusicalStage\image` -> Stage + Musical Wiring branch;
10. valid path whose owner conflicts with deterministic Scene naming -> explicit review condition;
11. missing/unusable BackgroundFile but deterministic Scene relationship -> resolve from current hierarchy without inventing a Display background;
12. ambiguous or nonexistent parent hierarchy -> fail visibly rather than guess.

## Related Documents

- [Folder Alignment Engineering Design](Folder_Alignment_Engineering_Design.md)
- [Google Drive Folder Structure](../../../00_Project_Overview/00-Google_Drive.md)
- [Google Drive Document Organization Procedure](../../../00_Project_Overview/01-Google_Drive_Document_Organization_Procedure.md)
- [LOR Preview Parser Architecture](../LOR_Preview_Parser_Architecture.md)
- [Shared Field Context Resolution Contract](../../../02_Production_Database/01_System_Architecture/07_Labeling_and_Scanning/Field_Context_Resolution_Contract.md)
- [FieldWiring Engineering Recovery and Compatibility Contract](../../../02_Production_Database/01_System_Architecture/09_Wiring_System/FieldWiring_Engineering_Recovery_and_Compatibility_Contract.md)
