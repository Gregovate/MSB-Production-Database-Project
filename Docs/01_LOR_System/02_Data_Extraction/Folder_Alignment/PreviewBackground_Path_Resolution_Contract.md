# PreviewBackground Path Resolution Contract

| Document control | Value |
|---|---|
| Status | DRAFT — documented current design intent |
| Current revision | 2026-08-17 |
| Owner | MSB Database Administrator |
| Scope | Folder Alignment / field-document path resolution |
| Code/schema status | Documentation only; no code or schema change authorized |

## Purpose

This document makes explicit the path-resolution rule that the standardized `PreviewBackground` folder was designed to support.

The current Google Drive structure deliberately places `PreviewBackground` at every level that may own an LOR Preview/Scene background:

```text
Stage\PreviewBackground\
Sub-stage\PreviewBackground\
Scene\PreviewBackground\
Display\PreviewBackground\
```

The LOR `BackgroundFile` path is therefore more than an image locator. When it points into the standardized `PreviewBackground` structure, it also provides filesystem evidence showing how deep in the physical Stage/Scene/Display hierarchy the current LOR context belongs.

The intended downstream application model is:

```text
LOR Preview / Scene BackgroundFile
        |
        v
...\<owner>\PreviewBackground\<background image>
        |
        v
identify the folder immediately above PreviewBackground
        |
        v
classify that owner as Stage / Sub-stage / Scene / Display
        |
        v
resolve the applicable documentation root
        |
        +--> Wiring\BackgroundStage
        +--> Wiring\MusicalStage
        +--> Procedures\Setup
        +--> Procedures\Takedown
        +--> Procedures\Inspection
        +--> other standardized task branches
```

This contract formalizes the filesystem relationship. It does not make a mounted Windows path the permanent Production Database identity and does not authorize storing engineering documents as database blobs.

## Why `PreviewBackground` Exists at Multiple Depths

The LOR background may legitimately belong to different physical/documentation depths.

Examples:

### Stage / Preview-level background

```text
<Stage>\PreviewBackground\stage-background.jpg
```

The immediate owner is the Stage root.

Applicable shared task roots are resolved at that Stage:

```text
<Stage>\Wiring\...
<Stage>\Procedures\...
```

### Sub-stage-level background

```text
<Stage>\<Sub-stage>\PreviewBackground\substage-background.jpg
```

The immediate owner is the Sub-stage root.

Applicable shared task roots are resolved at that Sub-stage:

```text
<Sub-stage>\Wiring\...
<Sub-stage>\Procedures\...
```

### Scene-level background

```text
<Stage>\<Scene>\PreviewBackground\scene-background.jpg
```

The immediate owner is the Scene root.

Applicable shared task roots are resolved at that Scene:

```text
<Scene>\Wiring\...
<Scene>\Procedures\...
```

### Display-level background

```text
<Stage>\<Scene>\<Display>\PreviewBackground\display-background.jpg
```

or:

```text
<Stage>\<Display>\PreviewBackground\display-background.jpg
```

The immediate owner is the Display folder.

A Display folder intentionally uses the smaller Display structure and does not automatically own standardized `Wiring` or `Procedures` trees.

Therefore a Display-level `PreviewBackground` establishes the Display's exact place in the filesystem hierarchy, after which shared task resolution climbs upward to the nearest established Stage/Sub-stage/Scene documentation root.

Examples:

```text
Stage\Scene\Display\PreviewBackground\image
                    |
                    v
               Display owner
                    |
                    v
            parent Scene root
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

The Display background path must not cause the application to invent `Wiring` or `Procedures` under the Display merely to satisfy lookup.

## Deterministic Resolution Algorithm

For a current standardized background path, the intended algorithm is:

1. obtain the applicable LOR `BackgroundFile` from the current Preview/Scene evidence;
2. locate the `PreviewBackground` path component;
3. treat its parent folder as the **background owner**;
4. classify that owner using the accepted Folder Alignment hierarchy rules;
5. if the owner is a Stage, Sub-stage, or Scene, use that same folder as the shared documentation root;
6. if the owner is a Display/shared Display-group folder, walk upward through the established hierarchy until the nearest valid Scene, Sub-stage, or Stage documentation root is reached;
7. append only the standardized relative branch owned by the selected task;
8. if the hierarchy is missing, contradictory, or ambiguous, report the condition rather than guessing.

Conceptually:

```text
BackgroundFile
    -> PreviewBackground
    -> background owner
    -> documentation owner
    -> selected task branch
```

The depth of the `PreviewBackground` path supplies filesystem evidence; the task determines which relative branch to present.

## Relationship to Database Identity

The Production Database remains responsible for permanent identity and current relationships.

For normal scan/manual lookup, the preferred application path is still:

```text
permanent Display identity
    -> current Stage/Scene/Preview relationships
    -> applicable current BackgroundFile/path evidence
    -> standardized documentation root
    -> task content
```

A QR code must not embed the Google Drive path.

The full `G:\...` path is filesystem evidence and traceability, not permanent asset identity.

Where a browser/service cannot consume a mapped-drive path directly, the service may resolve the same standardized hierarchy through a controlled Drive/file-serving mechanism. That implementation must preserve the scope and branch rules in this contract.

## Relationship to FormView

Historical FormView used `Preview.BackgroundFile` more directly.

In the proven FormView workflow, the background itself was commonly placed in or pointed at the active Wiring directory so FormView could use the image's containing directory as the published wiring-image directory.

The standardized `PreviewBackground` model separates those concerns:

```text
BackgroundFile
    = hierarchy/location anchor and LOR visual background

Wiring\...
    = published wiring documentation

Procedures\...
    = published procedure documentation
```

This is why the current V7 database can remain wiring-compatible with FormView's table views while the old FormView image lookup can fail against the new folder model.

The new field applications should resolve the hierarchy and then select the appropriate standardized task branch rather than forcing the LOR background path itself to point directly into `Wiring`.

## Legacy Compatibility

Historical LOR backgrounds may still point directly into folders such as:

```text
Wiring\BackgroundStage
Wiring\MusicalStage
```

Folder Alignment may continue recognizing those paths as legacy filesystem evidence while migration is incomplete.

However, the target current contract is the fixed scope-local `PreviewBackground` anchor.

Do not move or rewrite a functioning LOR `BackgroundFile` path automatically merely to satisfy this contract. Folder/path changes remain controlled human decisions because moving the referenced image can break LOR Preview Editor.

## Task Resolution Examples

Once the documentation root is resolved, the task adapter selects only its owned relative branch.

### Field Wiring

```text
<documentation root>\Wiring\BackgroundStage
```

or:

```text
<documentation root>\Wiring\MusicalStage
```

The application still must preserve the applicable LOR Preview/context distinction.

### Setup

```text
<documentation root>\Procedures\Setup
```

### Takedown

```text
<documentation root>\Procedures\Takedown
```

### Inspection

```text
<documentation root>\Procedures\Inspection
```

The standardized branch is appended after scope resolution; the application must not maintain a separate hard-coded full path for each individual document.

## Safety Rules

Path resolution must:

- preserve the existing Stage/Sub-stage/Scene/Display hierarchy;
- treat `PreviewBackground` as an infrastructure/helper folder, never as the scope itself;
- distinguish a Display background owner from a Stage/Sub-stage/Scene documentation root;
- climb only through actual established parent folders, not fuzzy name guesses;
- not create missing `Wiring` or `Procedures` branches as a side effect of lookup;
- not move or rename LOR background images during lookup;
- expose ambiguity instead of silently choosing a neighboring Scene or Stage;
- keep archive/source folders out of normal field publication; and
- keep Google Drive documents/images editable in the filesystem rather than copying them into a non-editable database blob.

## Regression Cases

Future resolver testing should include at minimum:

1. Stage-level `PreviewBackground` -> Stage Wiring/Procedures;
2. Sub-stage-level `PreviewBackground` -> Sub-stage Wiring/Procedures;
3. Scene-level `PreviewBackground` -> Scene Wiring/Procedures;
4. Display under Scene -> Display background owner, then parent Scene Wiring/Procedures;
5. Display directly under Stage -> Display background owner, then Stage Wiring/Procedures;
6. Display under Sub-stage -> Display background owner, then Sub-stage Wiring/Procedures;
7. legacy background located directly under `Wiring\BackgroundStage` -> recognized as legacy evidence but not treated as the target folder contract;
8. missing `PreviewBackground` component in a new/current path -> explicit review condition;
9. ambiguous or nonexistent parent hierarchy -> fail visibly rather than guess.

## Related Documents

- [Folder Alignment Engineering Design](Folder_Alignment_Engineering_Design.md)
- [Google Drive Folder Structure](../../../00_Project_Overview/00-Google_Drive.md)
- [Google Drive Document Organization Procedure](../../../00_Project_Overview/01-Google_Drive_Document_Organization_Procedure.md)
- [LOR Preview Parser Architecture](../LOR_Preview_Parser_Architecture.md)
- [Shared Field Context Resolution Contract](../../../02_Production_Database/01_System_Architecture/07_Labeling_and_Scanning/Field_Context_Resolution_Contract.md)
- [FieldWiring Engineering Recovery and Compatibility Contract](../../../02_Production_Database/01_System_Architecture/09_Wiring_System/FieldWiring_Engineering_Recovery_and_Compatibility_Contract.md)
