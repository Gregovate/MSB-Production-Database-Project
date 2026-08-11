---
title: Building the Master Musical Preview (Operator How-To)
author: Greg Liebig / Engineering Innovations, LLC
status: ACTIVE
---

# Building the Master Musical Preview (Operator How-To)

## Purpose

Use this procedure when creating or maintaining the MSB **Master Musical Preview** in Light-O-Rama (LOR).

The Master Musical Preview is different from a normal Background Stage Preview:

- one Master Musical Preview contains musical programming material from many Stages;
- the Preview name identifies the annual/versioned master preview, not a Stage;
- each Scene provides the Stage context needed by the parser; and
- a Scene's background-image path can also identify the Google Drive documentation root that belongs to that Scene.

This relationship is important to the parser, Folder Alignment, FormView-style wiring documentation, and future field applications.

---

## Master Musical Preview Name

The Master Musical Preview uses a common annual/versioned name such as:

```text
2026 Master Musical Preview v...
```

All Scenes inside that Preview share the same Preview name.

**Do not use the Master Musical Preview name to determine Stage placement.**

The Preview name identifies the master musical working set. Stage membership is derived from the Scene information.

---

## Scene Names Carry Stage Context

Each musical Scene must retain enough Stage information in its Scene name for the parser to derive the correct `SceneStageID`.

Examples include Scene names such as:

```text
05-Festive Trees-FT
07-Whoville-WV
07-Who Characters-WV
07-Who Spiral Tree-WV
07a-Who Forest-WF
```

The parser uses the Scene name to determine the Stage because the Master Musical Preview name itself is not Stage-specific.

A Scene is primarily an LOR sequencing organization. It does **not** automatically mean that a matching Google Drive Scene folder must exist.

Some musical Scenes represent the whole Stage. Some represent a meaningful physical/documentation subdivision. Other Scenes may exist only to make musical sequencing easier to understand.

---

# Documentation Root — Important

A musical Scene can use its LOR `BackgroundFile` path to identify the correct Google Drive documentation root.

This is more than a visual-background setting. The stored path provides an explicit filesystem anchor that downstream tools can use to determine where Stage or Scene documentation belongs.

The **image itself may be temporary**. The important authoring decision is that the image is stored below the correct documentation root before it is assigned to the Scene.

## Stage-level musical Scene

When the Scene belongs to the Stage as a whole, place or select its background image somewhere below the Stage's musical wiring branch:

```text
G:\Shared drives\Display Folders\<Stage Folder>\Wiring\MusicalStage\...
```

Example:

```text
G:\Shared drives\Display Folders\07-Whoville-WV\
└── Wiring\
    └── MusicalStage\
        └── SourceDocs\
            └── WhoPeople.jpg
```

That path identifies this documentation root:

```text
07-Whoville-WV
```

The background image may later be replaced by a better wiring image without changing the intended Stage-level documentation scope.

## Scene or Substage with its own documentation root

When a musical Scene has a real one-to-one Google Drive folder that owns its own Wiring, Procedures, Photos, or other shared documentation, place or select the background image below that folder's musical wiring branch.

Example:

```text
G:\Shared drives\Display Folders\07-Whoville-WV\
└── 07a-Who Forest-WF\
    └── Wiring\
        └── MusicalStage\
            └── WhoForest-Tagged.jpg
```

That path identifies this documentation root:

```text
07-Whoville-WV\07a-Who Forest-WF
```

This is how the author can intentionally tell downstream tools that `07a-Who Forest-WF` has its own documentation scope inside Stage 07.

---

# Why the Path Matters

Downstream tooling can recognize the standardized helper portion of the path:

```text
\Wiring\MusicalStage\
```

and treat the folder immediately above `Wiring` as the resolved Stage/Scene documentation root.

Examples:

```text
07-Whoville-WV\Wiring\MusicalStage\SourceDocs\WhoPeople.jpg
```

resolves to:

```text
07-Whoville-WV
```

while:

```text
07-Whoville-WV\07a-Who Forest-WF\Wiring\MusicalStage\WhoForest-Tagged.jpg
```

resolves to:

```text
07-Whoville-WV\07a-Who Forest-WF
```

The file name is not the permanent identity. The folder relationship is the important part of this contract.

---

# Placeholder Background Images Are Allowed

When the final musical wiring image does not yet exist, a temporary background image may be used to establish the correct documentation-root path.

The placeholder should:

1. be stored below the correct Stage or Scene documentation root;
2. be assigned as the Scene background in LOR;
3. remain an external file reference rather than being embedded into the Preview; and
4. later be replaced with the proper field-wiring image without changing the intended documentation root unless the Scene's physical/documentation scope has intentionally changed.

A placeholder background is therefore a temporary visual file but a useful explicit path anchor.

---

# Choosing the Correct Documentation Root

Use the existing physical/documentation organization as the primary guide.

## If the musical Scene represents the entire Stage

Use the Stage root:

```text
<Stage Folder>\Wiring\MusicalStage\...
```

Do **not** create a duplicate child folder merely because the LOR Scene name matches the Stage name.

For example, this is wrong:

```text
05-Festive Trees-FT\
└── 05-Festive Trees-FT\
    └── Wiring\MusicalStage
```

The correct Stage-level location is:

```text
05-Festive Trees-FT\
└── Wiring\MusicalStage
```

## If there is an established one-to-one Scene folder

Use that existing Scene/Substage folder as the documentation root.

Example:

```text
07-Whoville-WV\07a-Who Forest-WF\Wiring\MusicalStage
```

## If the Scene exists only for sequencing clarity

Do not create a new Google Drive folder simply because the Scene exists in LOR.

If the Scene's documentation belongs to the whole Stage, anchor its background under the Stage's `Wiring\MusicalStage` branch.

If the intended documentation scope is unclear, stop and review it before creating a new folder.

---

# Current Whoville Example

Stage 07 demonstrates why this distinction matters.

The Master Musical Preview can contain Scenes including:

```text
07-Whoville-WV
07-Who Characters-WV
07-Who Spiral Tree-WV
07a-Who Forest-WF
```

All belong to Stage 07, but they do not all require separate Google Drive documentation folders.

Current intended behavior:

```text
07-Whoville-WV
    -> Stage 07 documentation root

07-Who Characters-WV
    -> Stage 07 documentation root when its BackgroundFile is under
       07-Whoville-WV\Wiring\MusicalStage\...

07-Who Spiral Tree-WV
    -> Stage 07 documentation root when its BackgroundFile is under
       07-Whoville-WV\Wiring\MusicalStage\...

07a-Who Forest-WF
    -> nested documentation root when its BackgroundFile is under
       07-Whoville-WV\07a-Who Forest-WF\Wiring\MusicalStage\...
```

This allows LOR Scenes to remain useful for musical sequencing without forcing the Google Drive hierarchy to duplicate every Scene.

---

# Setting the Scene Background in LOR

For each Scene that needs an explicit documentation-root anchor:

1. Determine whether its documentation belongs to the whole Stage or to an established Scene/Substage folder.
2. Place the current background image or temporary placeholder below that root's `Wiring\MusicalStage` branch.
3. In the LOR Preview editor, use:

```text
Background -> Set Image
```

4. Select the image from the intended shared-drive location.
5. Do **not** embed the image into the Preview.
6. Save the Preview.
7. Repeat for other Scenes where the filesystem/documentation scope needs to be explicit.

The image may later change. Preserve the correct documentation-root relationship when replacing it.

---

# Before Exporting the Master Musical Preview

Verify:

- [ ] The Preview name follows the current annual/versioned Master Musical Preview convention.
- [ ] Scene names retain the Stage information needed by the parser.
- [ ] Stage-level musical Scenes use a BackgroundFile below the correct Stage root when a filesystem anchor is needed.
- [ ] Scenes with an established one-to-one documentation folder use a BackgroundFile below that folder's `Wiring\MusicalStage` branch.
- [ ] Sequencing-only Scenes have not caused unnecessary Google Drive Scene folders to be created.
- [ ] Background images remain external references.
- [ ] Placeholder images are understood to be temporary and may be replaced later.
- [ ] The Preview is exported through the normal controlled Preview Authoring / Preview Merger workflow.

After the approved Preview set changes, rerun the current parser so Folder Alignment and other LOR-side tools see the current Scene and BackgroundFile relationships.

Parser output is a working snapshot of the current approved LOR structure. PostgreSQL ingest remains a separate later production step.

---

## Related Documents

- [Building a Preview](B_Building_Preview_Howto.md) — general LOR Preview authoring procedure.
- [Create Wiring Backgrounds for Stage Previews](D_Create_Wiring_Backgrounds..md) — wiring-image folder and publication procedure.
- [Naming Conventions](A_Naming_Conventions.md) — current Display and channel naming rules.
- [LOR Preview Authoring](README.md) — Preview Authoring navigation portal.
- [FormView](../04_FormView/README.md) — existing field-wiring application that demonstrates the background-path/document-location contract.
- [LOR Data Extraction](../02_Data_Extraction/README.md) — parser and Folder Alignment engineering documentation.
