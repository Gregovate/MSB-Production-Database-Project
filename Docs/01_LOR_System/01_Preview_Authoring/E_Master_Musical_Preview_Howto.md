---
title: Building the Master Musical Preview (Operator How-To)
author: Greg Liebig / Engineering Innovations, LLC
status: CURRENT
revision: 2026-08-17
---

# Building the Master Musical Preview (Operator How-To)

## Purpose

Use this procedure when creating or maintaining the MSB **Master Musical Preview** in Light-O-Rama (LOR).

The Master Musical Preview is different from a normal Stage-specific Preview:

- one annual/versioned Master Musical Preview contains musical programming material from many Stages;
- the Preview name identifies the shared musical working set, not one Stage;
- each preview-level LOR Scene provides sequencing context;
- deterministic Scene naming provides Stage/Sub-stage/Scene/Display-group scope evidence; and
- a Scene's external `BackgroundFile` can provide explicit Google Drive path evidence for the scope that owns that Scene/background.

A Scene is still an LOR sequencing/presentation workspace. It is **not** a physical Display identity and it does not automatically require a matching Google Drive folder.

---

# Master Musical Preview Name

Use the current annual/versioned Master Musical Preview convention, for example:

```text
2026 Master Musical Preview v...
```

All Scenes inside the Preview share that Preview identity.

Do **not** use the Master Musical Preview name to determine per-Scene Stage placement.

The former current-workflow model of separate `RGB Plus Stage xx` musical previews has been replaced by the Master Musical Preview.

---

# Current Scene Naming and Scope Classification

The current Folder Alignment contract classifies raw LOR Scene names deterministically.

These rules are used for documentation lookup and path resolution. They do not change parser extraction or physical Display identity.

## Stage root

Format:

```text
NN-Name-XY
```

Example:

```text
07-Whoville-WV
```

Meaning:

```text
STAGE_ROOT
```

The Scene identifies the Stage root itself.

## Sub-stage root

Format:

```text
NNa-Name-XY
```

Example:

```text
07a-Who Forest-WF
```

Meaning:

```text
SUB_STAGE_ROOT
```

The Sub-stage is physically nested beneath its owning Stage but uses the same standardized root/helper structure as a Stage.

## True Scene / documentation group

Formats:

```text
NN-Name
NNa-Name
```

with **no trailing two-letter Stage/Sub-stage suffix**.

Examples:

```text
13-Christmas Story
13-Christmas Vacation
07-Who Characters
```

Meaning:

```text
SCENE
```

The Stage/Sub-stage token identifies the owning root, while the raw Scene name identifies the expected child Scene/documentation folder when that folder actually exists or is intentionally established.

## Unprefixed Scene name

An unprefixed non-`Root` Scene name is treated as Display/shared-group evidence rather than as a new Stage/Scene root.

Examples may include a Display name or a shared Display-group name used for sequencing clarity.

Meaning:

```text
DISPLAY_OR_GROUP
```

Do not create a Stage/Scene helper tree merely because an unprefixed LOR Scene exists.

## Reserved `Root`

Bare `Root` is a Background Preview scope marker when the owning Preview already supplies definitive Stage context.

It is **not** a valid way to assign a Stage inside the multi-Stage Master Musical Preview.

Do not use bare `Root` as a Master Musical Scene name when Stage ownership must be resolved.

---

# Why Scene Naming Matters

The V7 parser preserves the raw Scene `Name` and derives Stage-token evidence from it.

Folder Alignment then combines:

- raw Scene name;
- Preview context;
- parser Stage evidence; and
- explicit `Scene.BackgroundFile` path evidence

to resolve the intended Google Drive documentation scope without guessing.

If the name and path disagree, the condition should be reviewed rather than silently choosing one.

---

# Current Google Drive Background Path Contract

The stable helper folder for an image intentionally used as a Preview/Scene authoring background is:

```text
PreviewBackground
```

It can exist at any scope that may independently own a Preview/Scene background:

```text
<Stage>\PreviewBackground\
<Sub-stage>\PreviewBackground\
<Scene>\PreviewBackground\
<Display or shared group>\PreviewBackground\
```

For Master Musical Preview Scenes, use the `PreviewBackground` folder beneath the scope that actually owns the Scene/background.

The image file may change later. The important relationship is the resolved scope represented by the path.

## Stage-level Master Musical Scene

If the Scene belongs to the Stage as a whole, use:

```text
G:\Shared drives\Display Folders\<Stage Folder>\PreviewBackground\<image>.jpg
```

Example:

```text
G:\Shared drives\Display Folders\07-Whoville-WV\PreviewBackground\WhoPeople.jpg
```

This provides explicit filesystem evidence for:

```text
07-Whoville-WV
```

## Sub-stage or true Scene with its own documentation root

If an established Sub-stage or true Scene owns its own documentation, use its own `PreviewBackground` helper.

Examples:

```text
G:\Shared drives\Display Folders\07-Whoville-WV\07a-Who Forest-WF\PreviewBackground\WhoForest.jpg
```

or:

```text
G:\Shared drives\Display Folders\13-Winter Wonderland-WW\13-Christmas Vacation\PreviewBackground\ChristmasVacation.jpg
```

## Display or shared-group scope

If an unprefixed LOR Scene intentionally corresponds to an **existing** Display or shared documentation folder, that existing scope may own the background:

```text
<existing Display or shared group>\PreviewBackground\<image>.jpg
```

Do not create a new Display folder merely because an unprefixed LOR Scene exists. The current Drive contract explicitly allows Displays to share documentation or to have no dedicated folder.

---

# Do Not Use Wiring Folders as the General Master Musical Background Location

The `Wiring` tree is a separate field-documentation publication contract.

Current published wiring branches are:

```text
<Stage / Sub-stage / Scene>\Wiring\BackgroundStage\
<Stage / Sub-stage / Scene>\Wiring\MusicalStage\
```

Those directories are used for current field-wiring diagrams and the proven FormView workflow.

For Master Musical Scene authoring/scope anchors, use the applicable `PreviewBackground` helper rather than placing a placeholder in `Wiring\MusicalStage` merely to create a filesystem pointer.

This separation is intentional:

```text
PreviewBackground
    = stable Preview/Scene authoring background and scope evidence

Wiring\MusicalStage
    = published musical field-wiring images
```

The separate FieldWiring/FormView conversion project owns how the future browser-based wiring system maps these relationships. Do not redesign that implementation from this operator procedure.

---

# Placeholder Background Images Are Allowed

A final visual background does not need to exist before the correct filesystem scope can be established.

A temporary placeholder may be used when:

1. it is stored in the correct scope's `PreviewBackground` folder;
2. it is assigned to the Scene as an external file reference;
3. the path correctly identifies the intended Stage/Sub-stage/Scene/Display-group scope; and
4. it will later be replaced by a more useful image without changing the intended scope unless the engineering ownership itself changes.

The placeholder is temporary visual content. The scope/path relationship is the important authoring decision.

---

# Choosing the Correct Scope

Use the existing physical/documentation organization as the primary guide.

## If the Scene represents the entire Stage

Use the Stage root's `PreviewBackground` folder.

Do not create a duplicate child folder that repeats the Stage name.

Wrong:

```text
05-Festive Trees-FT\
└── 05-Festive Trees-FT\
    └── PreviewBackground\
```

Correct:

```text
05-Festive Trees-FT\
└── PreviewBackground\
```

## If the Scene is a formal Sub-stage

Use the existing Sub-stage root, for example:

```text
07-Whoville-WV\07a-Who Forest-WF\PreviewBackground\
```

## If the Scene is a true Scene/documentation group

Use the Scene root only when that Scene folder is established as a real documentation scope.

Example:

```text
13-Winter Wonderland-WW\13-Christmas Vacation\PreviewBackground\
```

Do not infer that every `NN-Name` LOR Scene must immediately create a Google Drive folder when the physical/documentation ownership is still uncertain. Folder creation and migration remain human-reviewed decisions.

## If the Scene is only sequencing organization

Do not create a new Google Drive Scene folder merely to mirror the LOR Scene list.

Use the existing scope that actually owns the background/documentation, or leave the path unresolved for review if ownership is not yet established.

---

# Example — Whoville

The Master Musical Preview may include Scenes such as:

```text
07-Whoville-WV
07-Who Characters
07-Who Spiral Tree
07a-Who Forest-WF
```

Current classification:

```text
07-Whoville-WV
    -> STAGE_ROOT
    -> 07-Whoville-WV\PreviewBackground\...

07-Who Characters
    -> SCENE
    -> Stage 07 child Scene only if that Scene is an established documentation scope
       otherwise resolve/review against the existing owning scope

07-Who Spiral Tree
    -> SCENE
    -> same rule

07a-Who Forest-WF
    -> SUB_STAGE_ROOT
    -> 07-Whoville-WV\07a-Who Forest-WF\PreviewBackground\...
```

This keeps LOR sequencing organization useful without forcing the Google Drive hierarchy to duplicate every sequencing choice.

---

# Setting a Scene Background in LOR

For each Scene that needs an explicit background/path anchor:

1. classify the Scene name using the rules above;
2. identify the existing scope that owns the Scene/background;
3. place the current image or placeholder in that scope's `PreviewBackground` folder;
4. in the LOR Preview editor use:

```text
Background -> Set Image
```

5. select the shared-drive image;
6. do **not** embed the image into the Preview;
7. save the Preview; and
8. repeat for other Scenes where explicit filesystem evidence is required.

If the path and Scene naming point to different scopes, stop and review the mismatch.

---

# Before Exporting the Master Musical Preview

Verify:

- [ ] The Preview name follows the current annual/versioned Master Musical Preview convention.
- [ ] `NN-Name-XY` is used only for Stage-root classification.
- [ ] `NNa-Name-XY` is used only for Sub-stage-root classification.
- [ ] `NN-Name` / `NNa-Name` is used for true Scene/documentation-group classification.
- [ ] Unprefixed non-`Root` names are treated as Display/shared-group evidence, not automatically as Scene roots.
- [ ] Bare `Root` is not being used to assign Stage scope inside the Master Musical Preview.
- [ ] Scene background images use the correct scope-local `PreviewBackground` helper.
- [ ] Background images remain external references.
- [ ] Sequencing-only Scenes have not caused unnecessary Google Drive folders to be created.
- [ ] `Wiring\MusicalStage` has not been repurposed as the general Master Musical Preview background folder.
- [ ] The candidate is exported to `UserPreviewStaging\<username>` through the normal Preview Authoring workflow.
- [ ] The controlled master is not overwritten directly.

After an approved controlled Preview-set update, rerun the current V7 parser so Folder Alignment and downstream LOR-side tools see the current Scene and `BackgroundFile` relationships.

PostgreSQL ingest remains a separate later production step.

---

## Related Documents

- [Building a Preview](B_Building_Preview_Howto.md) — general current Preview authoring workflow.
- [Create Wiring Backgrounds for Stage Previews](D_Create_Wiring_Backgrounds..md) — published field-wiring image workflow.
- [Naming Conventions](A_Naming_Conventions.md) — current Display and channel naming rules.
- [Preview Import Workflow](Preview_Import_Workflow.md) — obtain the current approved working source.
- [Folder Alignment Engineering Design](../02_Data_Extraction/Folder_Alignment/Folder_Alignment_Engineering_Design.md) — authoritative deterministic Scene classification and Google Drive resolution behavior.
- [LOR Preview Parser Architecture](../02_Data_Extraction/LOR_Preview_Parser_Architecture.md) — parser Scene and Stage-token contract.
- [Google Drive Folder Structure](../../00_Project_Overview/00-Google_Drive.md) — current engineering-repository helper-folder contract.
- [FormView](../04_FormView/README.md) — current field-wiring subsystem, maintained separately.

## Revision History

- 2026-08-17 — Reconciled Master Musical Preview authoring with the deterministic Scene naming contract, current `PreviewBackground` path-resolution model, current Drive hierarchy, and separate Wiring/FormView publication boundary.
