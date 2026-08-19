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

This relationship is important to the parser, Folder Alignment, FieldWiring, and future field applications.

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

Examples include:

```text
05-Festive Trees-FT
07-Whoville-WV
07-Who People
07a-Who Forest-WF
```

The parser uses the Scene name to determine the Stage because the Master Musical Preview name itself is not Stage-specific.

A Scene is primarily an LOR sequencing organization. It does **not** automatically mean that a matching Google Drive Scene folder must exist.

Some musical Scenes represent the whole Stage. Some represent a meaningful physical/documentation subdivision. Other Scenes may exist only to make musical sequencing easier to understand.

---

# Documentation Root — Important

A musical Scene can use its LOR `BackgroundFile` path to identify the correct Google Drive documentation root.

This is more than a visual-background setting. The stored path provides filesystem evidence that downstream tools can use together with current Stage/Scene identity.

For **new authoring**, the Scene background should be selected from an approved marked database/application source location below the intended documentation root. Do not create new Scene pointers into loose legacy files or `SourceDocs`.

Approved new-authoring anchors are normally:

```text
<documentation root>\PreviewBackground\<image>
```

or, when the published musical wiring drawing is itself the appropriate background:

```text
<documentation root>\Wiring\MusicalStage\<published image>
```

The `PreviewBackground` or `Wiring` root must carry the standard MSB database-source marker.

Existing legacy Scene pointers may temporarily use older locations while Folder Alignment cleanup continues. That does not make those old locations valid for new authoring.

## Stage-level musical Scene

When the Scene belongs to the Stage as a whole, use a marked Stage-level source location.

Example using `PreviewBackground`:

```text
G:\Shared drives\Display Folders\07-Whoville-WV\
└── PreviewBackground\
    ├── _MSB-DB-Source-Folder_READ-ME-FIRST-AND-DO-NOT-DELETE.txt
    └── WhoPeople.jpg
```

Example using a published wiring drawing:

```text
G:\Shared drives\Display Folders\07-Whoville-WV\
└── Wiring\
    ├── _MSB-DB-Source-Folder_READ-ME-FIRST-AND-DO-NOT-DELETE.txt
    └── MusicalStage\
        └── Stage-07-Musical-Tagged.jpg
```

Both identify Stage 07 as the documentation root.

**Do not use `Wiring\MusicalStage\SourceDocs` as a new Scene background endpoint.** `SourceDocs` is working/source material and is excluded from normal FieldWiring presentation.

## Scene or Sub-stage with its own documentation root

When a musical Scene has a real one-to-one Google Drive folder that owns its own Wiring, Procedures, PreviewBackground, or other shared documentation, use that folder as the documentation root.

Example:

```text
G:\Shared drives\Display Folders\07-Whoville-WV\
└── 07a-Who Forest-WF\
    ├── _MSB-DB-Source-Folder_READ-ME-FIRST-AND-DO-NOT-DELETE.txt
    └── Wiring\
        ├── _MSB-DB-Source-Folder_READ-ME-FIRST-AND-DO-NOT-DELETE.txt
        └── MusicalStage\
            └── WhoForest-Tagged.jpg
```

That path identifies this documentation root:

```text
07-Whoville-WV\07a-Who Forest-WF
```

---

# If a New Scene Documentation Folder Is Needed

Do not create an empty or one-off Scene folder and add helper folders later.

If review determines that a Scene genuinely needs its own Google Drive documentation root, create the **complete controlled Stage/Sub-stage/Scene scaffold immediately**.

Use:

[Stage / Sub-stage / Scene Folder Scaffold](../../00_Project_Overview/04-Stage_Substage_Scene_Folder_Scaffold.md)

The new Scene root includes:

- the structural root marker;
- marked `PreviewBackground`;
- marked `Procedures`;
- marked `Wiring`;
- the standard procedure and wiring branches; and
- the standard `Photos` structure, which is not currently a database/application source folder.

This requirement is especially important for Scenes because new Scene documentation scopes are more likely to be created than entirely new Stages.

A new Scene folder should begin clean. The legacy-tolerance rules that allow loose files to remain in old Stage/Scene roots do not justify putting new loose files into a newly created Scene root.

---

# Why the Path Matters

For current controlled authoring, downstream tooling can recognize marked source folders and the standardized path structure.

Example:

```text
07-Whoville-WV\PreviewBackground\WhoPeople.jpg
```

identifies Stage 07 as the background/documentation context.

A direct published wiring path:

```text
07-Whoville-WV\07a-Who Forest-WF\Wiring\MusicalStage\WhoForest-Tagged.jpg
```

identifies the nested `07a-Who Forest-WF` documentation root and the Musical wiring context.

The file name is not permanent identity. Current database/LOR relationships plus the controlled folder relationship establish context.

Legacy path text outside the marked structure may still be useful as navigation evidence during cleanup, but applications return to the marked source structure before selecting published field content.

---

# Placeholder Background Images Are Allowed

When the final musical wiring image does not yet exist, a temporary background image may be used to establish the correct documentation-root path.

For new authoring, put the placeholder in the marked `PreviewBackground` folder for the intended Stage/Sub-stage/Scene root.

The placeholder should:

1. be stored in the correct marked `PreviewBackground` folder;
2. be assigned as the Scene background in LOR;
3. remain an external file reference rather than being embedded into the Preview; and
4. later be replaced deliberately while preserving the intended documentation root unless the Scene's physical/documentation scope has changed.

Do not use `SourceDocs` for placeholder Scene backgrounds.

---

# Choosing the Correct Documentation Root

Use the existing physical/documentation organization as the primary guide.

## If the musical Scene represents the entire Stage

Use the existing Stage root and one of its marked source folders.

Do **not** create a duplicate child folder merely because the LOR Scene name matches the Stage name.

Wrong:

```text
05-Festive Trees-FT\
└── 05-Festive Trees-FT\
    └── Wiring\MusicalStage
```

Correct Stage-level context:

```text
05-Festive Trees-FT\PreviewBackground\...
```

or:

```text
05-Festive Trees-FT\Wiring\MusicalStage\...
```

## If there is an established one-to-one Scene/Sub-stage folder

Use that existing structured root and its marked source folders.

## If a new Scene documentation root is genuinely required

Create it using the complete controlled scaffold before assigning new LOR background references to it.

## If the Scene exists only for sequencing clarity

Do not create a new Google Drive folder simply because the Scene exists in LOR.

Use the applicable Stage or Sub-stage documentation root.

If the intended documentation scope is unclear, stop and review it before creating a folder or changing the Scene background.

---

# Current Whoville Example

Stage 07 demonstrates why this distinction matters.

The Master Musical Preview can contain Stage-level, Sub-stage, and sequencing Scenes such as:

```text
07-Whoville-WV
07-Who People
07a-Who Forest-WF
```

They do not all require separate Google Drive documentation folders.

Conceptually:

```text
07-Whoville-WV
    -> Stage 07 documentation root

07-Who People
    -> Stage 07 documentation root when its current controlled background
       is under Stage 07 PreviewBackground or published MusicalStage Wiring

07a-Who Forest-WF
    -> nested documentation root when its current controlled background
       is under 07a-Who Forest-WF PreviewBackground or published Wiring
```

This allows LOR Scenes to remain useful for musical sequencing without forcing the Google Drive hierarchy to duplicate every Scene.

---

# Setting the Scene Background in LOR

For each Scene that needs an explicit documentation-root anchor:

1. Determine whether its documentation belongs to the whole Stage, a formal Sub-stage, or an established Scene documentation folder.
2. If a new Scene documentation folder is required, create the complete controlled scaffold first.
3. Choose the current background image from that root's **marked `PreviewBackground`** folder or directly from the published `Wiring\MusicalStage` branch when that drawing is the intended background.
4. Do not select a new background from `SourceDocs` or from loose legacy material.
5. In the LOR Preview editor, use:

```text
Background -> Set Image
```

6. Select the image from the intended shared-drive location.
7. Do **not** embed the image into the Preview.
8. Save the Preview.
9. Repeat for other Scenes where filesystem/documentation scope needs to be explicit.

The image may later change. Preserve the correct documentation-root relationship when replacing it.

---

# Before Exporting the Master Musical Preview

Verify:

- [ ] The Preview name follows the current annual/versioned Master Musical Preview convention.
- [ ] Scene names retain the Stage information needed by the parser.
- [ ] A new Google Drive Scene folder was created only when the Scene represents a real documentation scope.
- [ ] Any newly created Stage/Sub-stage/Scene folder uses the complete controlled scaffold.
- [ ] The structural root marker is present.
- [ ] `PreviewBackground`, `Procedures`, and `Wiring` carry their required markers.
- [ ] Stage-level musical Scenes use a current BackgroundFile below the correct marked Stage source folder when a filesystem anchor is needed.
- [ ] Scenes with their own documentation folder use a current BackgroundFile below that folder's marked source structure.
- [ ] New Scene background pointers do not enter `SourceDocs` or loose legacy material.
- [ ] Sequencing-only Scenes have not caused unnecessary Google Drive Scene folders to be created.
- [ ] Background images remain external references.
- [ ] The Preview is exported through the normal controlled Preview Authoring / Preview Merger workflow.

After the approved Preview set changes, rerun the current parser when appropriate so Folder Alignment and other LOR-side tools see the current Scene and `BackgroundFile` relationships.

Parser output is a working snapshot of the current approved LOR structure. PostgreSQL ingest remains a separate later production step.

---

## Related Documents

- [Building a Preview](B_Building_Preview_Howto.md) — general LOR Preview authoring procedure.
- [Create Wiring Backgrounds for Stage Previews](D_Create_Wiring_Backgrounds..md) — wiring-image folder and publication procedure.
- [Naming Conventions](A_Naming_Conventions.md) — current Display and channel naming rules.
- [Stage / Sub-stage / Scene Folder Scaffold](../../00_Project_Overview/04-Stage_Substage_Scene_Folder_Scaffold.md) — required scaffold when creating a new structured documentation root.
- [MSB Database Source Folder Marker](../../00_Project_Overview/03-MSB_DB_Source_Folder_Marker_Operator_Procedure.md) — root/source marker rules and local notes.
- [LOR Preview Authoring](README.md) — Preview Authoring navigation portal.
- [LOR Data Extraction](../02_Data_Extraction/README.md) — parser and Folder Alignment engineering documentation.
