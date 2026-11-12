---
title: Building the Master Musical Preview
author: Greg Liebig / Engineering Innovations, LLC
status: CURRENT
revision: 2026-08-22
---

# Building the Master Musical Preview

| Document Control | Value |
|---|---|
| Document Type | Operator Procedure |
| System | LOR Preview Authoring |
| Task | Build or update the Master Musical Preview |
| Audience | Musical Preview authors and programmers |
| Status | CURRENT |
| Owner | MSB Production Crew |
| Last Reviewed | 2026-08-22 |

## Purpose

Use this procedure when creating or changing Scenes in the MSB **Master Musical Preview**.

The Master Musical Preview contains musical programming for many Stages, so Scene names and background locations must clearly show where the Scene belongs.

You do not need to understand the parser or database to use these rules.

---

# 1. Use the Master Musical Preview

The current musical workflow uses one annual/versioned Master Musical Preview, for example:

```text
2026 Master Musical Preview v...
```

Do not create separate `RGB Plus Stage xx` musical Previews as part of the current workflow.

The Master Musical Preview name identifies the overall musical Preview. The **Scene name** identifies the Stage/Sub-stage/Scene context inside it.

---

# 2. Name Each Scene Correctly

Use these naming patterns.

| What the Scene represents | Naming pattern | Example |
|---|---|---|
| Entire Stage | `NN-Name-XY` | `07-Whoville-WV` |
| Formal Sub-stage | `NNa-Name-XY` | `07a-Who Forest-WF` |
| Scene within a Stage | `NN-Name` | `13-Christmas Vacation` |
| Scene within a Sub-stage | `NNa-Name` | `07a-Some Scene` |
| Display/shared group used only for organizing LOR | Normal Display/group name | `Who Characters` |

Where:

- `NN` is the two-digit Stage number;
- `NNa` is the Stage number plus the Sub-stage letter; and
- `XY` is the two-letter Stage/Sub-stage code.

## Important

A Scene in LOR does **not** automatically mean a matching Google Drive Scene folder must be created.

Some Scenes exist only to make programming easier to organize.

Use the existing folder structure unless the Scene really needs its own shared documentation folder.

---

# 3. Do Not Use `Root` to Identify a Stage in the Master Musical Preview

The name `Root` is used in some Background Stage Previews.

Do **not** use bare `Root` as the Scene name when the Master Musical Preview needs to identify which Stage the Scene belongs to.

Use the proper Stage, Sub-stage, Scene, or Display/group name instead.

---

# 4. Decide Where the Scene Background Belongs

For new authoring, use an approved marked folder.

There are two normal choices.

## Choice A — `PreviewBackground`

Use the marked `PreviewBackground` folder when the Scene uses a normal LOR background image.

Examples:

### Whole Stage

```text
G:\Shared drives\Display Folders\07-Whoville-WV\PreviewBackground\WhoPeople.jpg
```

### Sub-stage

```text
G:\Shared drives\Display Folders\07-Whoville-WV\07a-Who Forest-WF\PreviewBackground\WhoForest.jpg
```

### Scene with its own established folder

```text
G:\Shared drives\Display Folders\13-Winter Wonderland-WW\13-Christmas Vacation\PreviewBackground\ChristmasVacation.jpg
```

## Choice B — Published `Wiring\MusicalStage` image

If the published musical wiring drawing is also the best LOR Scene background, you may point directly to that image.

Example:

```text
<Stage / Sub-stage / Scene>\Wiring\MusicalStage\<published image>.jpg
```

The Stage/Sub-stage/Scene root, `Wiring`, and `MusicalStage` folders must have their required marker files.

You do **not** need to copy the same published wiring image into `PreviewBackground` just to use it in LOR.

---

# 5. Never Use `SourceDocs` for a New Scene Background

Do not create a new Scene background link into:

```text
SourceDocs\
```

`SourceDocs` contains working files. It is not a normal field or LOR background location.

Existing old references may still be found during cleanup, but do not create new ones there.

---

# 6. If a New Scene Documentation Folder Is Needed

Do not create an empty Scene folder and add pieces later.

If the Scene really needs its own Google Drive documentation folder, use the complete controlled scaffold:

[Stage / Sub-stage / Scene Folder Scaffold](../../00_Project_Overview/04-Stage_Substage_Scene_Folder_Scaffold.md)

Use a separate Scene folder only when the Scene represents a real shared documentation area, such as a group that:

- is installed together;
- shares wiring;
- shares Setup/Takedown instructions; or
- needs its own common background/documentation.

If the Scene exists only for sequencing clarity, keep its documentation with the appropriate Stage or Sub-stage.

---

# 7. Check the Required Marker Files

Any folder used by the new FieldWiring system or future Procedure system must have the required marker:

```text
_MSB-DB-Source-Folder_READ-ME-FIRST-AND-DO-NOT-DELETE.txt
```

Do not rename or delete marker files.

For a new Stage/Sub-stage/Scene folder, the scaffold shows exactly where the markers belong.

See [MSB Source Folder Marker](../../00_Project_Overview/03-MSB_DB_Source_Folder_Marker_Operator_Procedure.md).

---

# 8. A Temporary Background Image Is Allowed

The final image does not have to be finished before the Scene can be set up.

You may use a temporary image if:

1. it is saved in the correct marked `PreviewBackground` folder;
2. it is linked to the Scene in LOR;
3. it is not embedded in the Preview; and
4. it is later replaced deliberately without moving the Scene to the wrong documentation location.

Do not use `SourceDocs` for the temporary image.

---

# 9. Set the Scene Background in LOR

For each Scene that needs a background:

1. Decide what the Scene represents: Stage, Sub-stage, Scene, Display, or shared group.
2. Use the correct Scene name.
3. Decide whether the background belongs in `PreviewBackground` or is intentionally the current published `Wiring\MusicalStage` image.
4. Verify the selected location has the required marker files.
5. In the LOR Preview Editor, choose **Background -> Set Image**.
6. Select the image from the shared drive.
7. Do **not** embed the image.
8. Save the Preview.

If the Scene name and folder location do not make sense together, stop and ask for review rather than guessing.

---

# Example — Whoville

The Master Musical Preview may contain Scenes such as:

```text
07-Whoville-WV
07-Who People
07a-Who Forest-WF
```

How to treat them:

- `07-Whoville-WV` represents the whole Stage 07.
- `07-Who People` is a Scene within Stage 07.
- `07a-Who Forest-WF` represents the Who Forest Sub-stage.

`07-Who People` does not automatically need its own Google Drive folder. If its documentation belongs to Stage 07, use the Stage 07 controlled folders. Create a separate Scene folder only if it genuinely owns its own shared documentation.

---

# 10. Check the Master Musical Preview Before Exporting

- [ ] The Preview uses the current Master Musical Preview name.
- [ ] Each Scene name follows the correct naming pattern.
- [ ] `Root` is not being used to identify a Stage in the Master Musical Preview.
- [ ] I did not create a Google Drive Scene folder only because a Scene exists in LOR.
- [ ] Any new Scene folder uses the complete controlled scaffold.
- [ ] The background is in an approved marked `PreviewBackground` folder or directly in an approved marked published `Wiring\MusicalStage` folder.
- [ ] The background does not point into `SourceDocs`.
- [ ] Background images are linked, not embedded.

---

# 11. Export the Candidate

When the Master Musical Preview changes are complete, export the candidate `.lorprev` file to:

```text
G:\Shared drives\MSB Database\UserPreviewStaging\<username>
```

Allow Google Drive to finish synchronizing.

Do not overwrite the approved master directly.

---

## Expected Result

The Master Musical Preview has clearly named Scenes, each background points to the correct controlled shared-drive location, and the finished candidate is ready in `UserPreviewStaging` for the controlled review process.

## If Something Is Wrong

If you are unsure whether a Scene should have its own Google Drive folder, where its background belongs, or whether the required marker is present, stop and ask for review. Do not create a new folder or background path simply to make the LOR Scene list match the Drive folder list.

## Related Operator Documents

- [Preview Authoring Home](README.md)
- [Building a Preview](B_Building_Preview_Howto.md)
- [Prop and Display Naming Conventions](A_Naming_Conventions.md)
- [Create Wiring Backgrounds](D_Create_Wiring_Backgrounds..md)
- [Preview Import Workflow](Preview_Import_Workflow.md)
- [Stage / Sub-stage / Scene Folder Scaffold](../../00_Project_Overview/04-Stage_Substage_Scene_Folder_Scaffold.md)
- [MSB Source Folder Marker](../../00_Project_Overview/03-MSB_DB_Source_Folder_Marker_Operator_Procedure.md)

## Related Engineering

- [Google Drive Path Resolution Contract](../../00_Project_Overview/02-Google_Drive_Path_Resolution_Contract.md)
- [LOR Parser Architecture](../02_Data_Extraction/LOR_Preview_Parser_Architecture.md)
- [FieldWiring Engineering](../../02_Production_Database/01_System_Architecture/09_Wiring_System/README.md)

## Revision History

- 2026-08-22 — Rewritten for Preview authors in plain language while preserving the current Scene naming, complete scaffold, marker, `PreviewBackground`, direct published Wiring background, and `SourceDocs` exclusion rules.
