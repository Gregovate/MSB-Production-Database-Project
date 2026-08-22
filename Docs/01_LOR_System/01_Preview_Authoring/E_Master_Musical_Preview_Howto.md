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

The Master Musical Preview contains musical programming for many Stages. Because of that, the Scene names must clearly show where each Scene belongs.

You do not need to understand the parser or database to use these rules.

---

# 1. Use the Master Musical Preview

The current musical workflow uses one annual/versioned Master Musical Preview, for example:

```text
2026 Master Musical Preview v...
```

Do not create separate `RGB Plus Stage xx` musical Previews as part of the current workflow.

The Master Musical Preview name identifies the overall musical Preview. The **Scene name** identifies where each Scene belongs.

---

# 2. Name Each Scene Correctly

Use these naming patterns.

| What the Scene represents | Naming pattern | Example |
|---|---|---|
| Entire Stage | `NN-Name-XY` | `07-Whoville-WV` |
| Substage | `NNa-Name-XY` | `07a-Who Forest-WF` |
| Scene within a Stage | `NN-Name` | `13-Christmas Vacation` |
| Scene within a Substage | `NNa-Name` | `07a-Some Scene` |
| Display or shared group used for organizing LOR | Normal Display/group name | `Who Characters` |

Where:

- `NN` is the two-digit Stage number;
- `NNa` is the Stage number plus the substage letter; and
- `XY` is the two-letter Stage/Substage code.

## Important

A Scene in LOR does **not** automatically mean a matching Google Drive Scene folder must be created.

Some Scenes are only used to make programming easier to organize.

Use the existing folder structure. Do not create a new folder just because you created a Scene in LOR.

---

# 3. Do Not Use `Root` to Identify a Stage in the Master Musical Preview

The name `Root` is used in some Background Stage Previews.

Do **not** use bare `Root` as the Scene name when the Master Musical Preview needs to identify which Stage the Scene belongs to.

Use the proper Stage, Substage, Scene, or Display/group name instead.

---

# 4. Put the Scene Background in the Correct `PreviewBackground` Folder

Master Musical Scene background images belong in the `PreviewBackground` folder for the location that owns the Scene or background.

Examples:

### Scene belongs to the whole Stage

```text
G:\Shared drives\Display Folders\07-Whoville-WV\PreviewBackground\WhoPeople.jpg
```

### Scene belongs to a Substage

```text
G:\Shared drives\Display Folders\07-Whoville-WV\07a-Who Forest-WF\PreviewBackground\WhoForest.jpg
```

### Scene has its own established Scene folder

```text
G:\Shared drives\Display Folders\13-Winter Wonderland-WW\13-Christmas Vacation\PreviewBackground\ChristmasVacation.jpg
```

### Scene uses an existing Display or shared-group folder

Use that existing folder's `PreviewBackground` folder when that is where the background really belongs.

Do not create a new Display or shared-group folder only because an LOR Scene exists.

---

# 5. A Temporary Background Image Is Allowed

The final image does not have to be finished before the Scene can be set up.

You may use a temporary image if:

1. it is saved in the correct `PreviewBackground` folder;
2. it is linked to the Scene in LOR;
3. it is not embedded in the Preview; and
4. you later replace it with the final image without moving it to the wrong folder.

The important part is using the correct folder from the beginning.

---

# 6. Set the Scene Background in LOR

For each Scene that needs a background:

1. Decide what the Scene represents: Stage, Substage, Scene, Display, or shared group.
2. Use the correct Scene name.
3. Save the background image in the correct `PreviewBackground` folder.
4. In the LOR Preview Editor, choose **Background -> Set Image**.
5. Select the image from the shared drive.
6. Do **not** embed the image.
7. Save the Preview.

If the Scene name and the folder location do not make sense together, stop and ask for review rather than guessing.

---

# 7. Do Not Use the Wiring Folder for Normal Master Musical Scene Backgrounds

The following folder is for **field wiring images**:

```text
Wiring\MusicalStage\
```

Do not use it as the normal place for Master Musical Scene background images.

For Master Musical Scene backgrounds, use:

```text
PreviewBackground\
```

For field wiring images, use:

[Create Wiring Backgrounds](D_Create_Wiring_Backgrounds..md)

---

# Example — Whoville

The Master Musical Preview may contain Scenes such as:

```text
07-Whoville-WV
07-Who Characters
07-Who Spiral Tree
07a-Who Forest-WF
```

How to think about them:

- `07-Whoville-WV` represents the whole Stage 07.
- `07-Who Characters` is a Scene within Stage 07.
- `07-Who Spiral Tree` is a Scene within Stage 07.
- `07a-Who Forest-WF` represents the Who Forest Substage.

The two Stage 07 Scenes do not automatically need their own Google Drive folders. Use separate Scene folders only when those Scenes really have their own shared documentation location.

---

# 8. Check the Master Musical Preview Before Exporting

- [ ] The Preview uses the current Master Musical Preview name.
- [ ] Each Scene name follows the correct naming pattern.
- [ ] `Root` is not being used to identify a Stage in the Master Musical Preview.
- [ ] Each Scene background is in the correct `PreviewBackground` folder.
- [ ] Background images are linked, not embedded.
- [ ] I did not create unnecessary Google Drive folders just to match LOR Scenes.
- [ ] I did not use `Wiring\MusicalStage` as the normal Scene-background folder.

---

# 9. Export the Candidate

When the Master Musical Preview changes are complete, export the candidate `.lorprev` file to:

```text
G:\Shared drives\MSB Database\UserPreviewStaging\<username>
```

Allow Google Drive to finish synchronizing.

Do not overwrite the approved master directly.

---

## Expected Result

The Master Musical Preview has clearly named Scenes, each background points to the correct shared-drive location, and the finished candidate is ready in `UserPreviewStaging` for the controlled review process.

## If Something Is Wrong

If you are unsure whether a Scene should have its own Google Drive folder, or where its background belongs, stop and ask for review. Do not create a new folder simply to make the LOR Scene list match the Drive folder list.

## Related Operator Documents

- [Preview Authoring Home](README.md)
- [Building a Preview](B_Building_Preview_Howto.md)
- [Prop and Display Naming Conventions](A_Naming_Conventions.md)
- [Create Wiring Backgrounds](D_Create_Wiring_Backgrounds..md)
- [Preview Import Workflow](Preview_Import_Workflow.md)

## Related Engineering

- [Folder Alignment Engineering Design](../02_Data_Extraction/Folder_Alignment/Folder_Alignment_Engineering_Design.md)
- [LOR Parser Architecture](../02_Data_Extraction/LOR_Preview_Parser_Architecture.md)

## Revision History

- 2026-08-22 — Rewritten for Preview authors in plain language. Internal Scene classifications, parser terminology, and filesystem-evidence terminology were removed from the operator procedure while preserving the current naming and folder rules.
- 2026-08-17 — Reconciled with the current Scene naming and `PreviewBackground` structure.
