---
title: Building a Preview
status: CURRENT
revision: 2026-08-22
author: Greg Liebig / Engineering Innovations, LLC
---

# Building a Preview

| Document Control | Value |
|---|---|
| Document Type | Operator Procedure |
| System | LOR Preview Authoring |
| Task | Build or update an LOR Preview |
| Audience | Preview authors and programmers |
| Status | CURRENT |
| Owner | MSB Production Crew |
| Last Reviewed | 2026-08-22 |

## Purpose

Use this procedure when creating a new LOR Preview or changing an existing one.

You do not need to understand the parser or database systems to complete this task.

## Before You Start

Have the following ready:

- the approved Display Design Worksheet or other approved design information;
- the correct Stage and controller/channel assignments;
- the current approved Preview if you are editing an existing one; and
- any artwork or background image needed to build the Preview.

The existing Display Design Worksheet is the design starting point. This procedure does not replace it.

---

# 1. Get the Current Preview Before Editing

If you are changing an existing Preview, first follow:

[Preview Import Workflow](Preview_Import_Workflow.md)

Do not edit the approved master files directly.

Make all changes in your own LOR working copy.

---

# 2. Use the Existing Google Drive Folder Structure

The engineering files are stored under:

```text
G:\Shared drives\Display Folders\
```

Use the Stage, Scene, shared group, or Display folder that already owns the material you are working on.

Do not create a new folder just because a Display or Scene exists in LOR.

Not every LOR Display has its own Google Drive folder.

## Normal Preview background images

For a normal Display or Scene background, use the `PreviewBackground` folder under the location that owns that background.

Examples:

```text
<Stage>\PreviewBackground\
<Scene>\PreviewBackground\
<Display>\PreviewBackground\
```

Do not put normal Display/Scene background images in the Wiring folders.

## Field wiring images

Field wiring images are different. They belong in:

```text
Wiring\BackgroundStage\
```

or:

```text
Wiring\MusicalStage\
```

Use [Create Wiring Backgrounds](D_Create_Wiring_Backgrounds..md) for those images.

---

# 3. Prepare the Display Artwork

Use scalable vector artwork when the drawing will be used for fabrication, plotting, CNC work, or full-size printing.

Bitmap images such as JPG or PNG are useful for Preview backgrounds and documentation.

If using Inkscape, keep both files when appropriate:

```text
DisplayName-inkscape.svg
DisplayName-plain.svg
```

The `-inkscape.svg` file is the editable master. The `-plain.svg` file is the simpler copy used by other programs.

Do not store general artwork or fabrication files in the published Wiring image folders.

---

# 4. Create the Preview Background

Typical image sizes:

- horizontal single panel: about `800 x 600`;
- vertical single panel: about `600 x 800`;
- full Stage image: about `3840 x 2160`.

JPG is normally used for Preview backgrounds.

Save the image in the correct `PreviewBackground` folder.

In LOR:

1. Open the Preview Editor.
2. Choose **Background -> Set Image**.
3. Select the image from the shared drive.
4. Do **not** embed the image into the Preview.

The Preview should keep a link to the shared-drive image.

---

# 5. Draw the Display and Assign Channels

In the LOR Preview Editor:

1. Draw the strings or elements needed to represent the Display.
2. Assign the correct controller, network, and channels from the approved design.
3. Check the drawing scale and placement.
4. Name the channels and Display using [Prop and Display Naming Conventions](A_Naming_Conventions.md).
5. Add unused controller channels as SPARE channels.
6. If a Display was moved from old channels, delete the old Display object and create new SPARE channels in its place.

Do not simply hide an old Display channel or rename it to SPARE.

---

# 6. Create a Reusable LOR Prop When Needed

If the Display will be reused in another Preview, export it as a `.leprop` file.

The shared Prop location is:

```text
G:\Shared drives\MSB Database\Database Previews\PreviewsForProps
```

Use reusable Props carefully. Separate physical Displays must have separate LOR identities.

Do not blindly copy one Display object into several places when those objects represent different physical Displays.

---

# 7. Choose the Correct Preview Type

## Master Musical Preview

Use the **Master Musical Preview** for current musical programming.

Do not create separate `RGB Plus Stage xx` musical Previews as part of the current workflow.

For Scene names and Scene backgrounds, follow:

[Building the Master Musical Preview](E_Master_Musical_Preview_Howto.md)

## Show Background Stage Preview

These Previews are still used for background/static operation and field wiring.

For the wiring image, follow:

[Create Wiring Backgrounds](D_Create_Wiring_Backgrounds..md)

## Show Animation Preview

Use the existing Show Animation Preview where the current show workflow requires it.

## Special Previews

Some Previews are intentional exceptions, such as specialized show equipment or displays. Do not rename or combine them just to make the Preview names look consistent.

---

# 8. Save and Check Your Work

Before exporting:

- verify the Display Name and channel names;
- verify controller and channel assignments;
- verify SPARE channels;
- verify the background image still opens from the shared drive;
- verify you did not create unnecessary Google Drive folders; and
- verify you are working in your own copy, not the approved master.

---

# 9. Export Your Candidate Preview

When the Preview is ready, export the `.lorprev` file to your own staging folder:

```text
G:\Shared drives\MSB Database\UserPreviewStaging\<username>
```

Allow Google Drive to finish synchronizing the file.

## Stop Here

`UserPreviewStaging` is the handoff point for your finished candidate.

Do **not**:

- overwrite the approved master Preview;
- save directly into the approved source folder; or
- run the production parser on your personal staging folder.

The master-update/review process is controlled separately.

---

# Before You Finish

- [ ] I started from the approved design information.
- [ ] If editing an existing Preview, I used the current approved Preview.
- [ ] My background image is in the correct folder.
- [ ] My Display and channel names follow the naming rules.
- [ ] Controller and channel assignments are correct.
- [ ] Unused channels are shown as SPARE.
- [ ] Old channels from moved Displays were deleted and replaced with new SPARE channels.
- [ ] I did not create unnecessary Google Drive folders.
- [ ] I saved and exported my work to `UserPreviewStaging\<username>`.
- [ ] I did not overwrite the approved master.

## Expected Result

A complete candidate Preview is saved in your `UserPreviewStaging` folder and is ready for the controlled review/master-update process.

## If Something Is Wrong

If you are unsure about the correct Stage, folder, Scene name, Display Name, or master Preview, stop before exporting and ask for review. Do not guess by creating new folders or new Preview identities.

## Related Operator Documents

- [Preview Authoring Home](README.md)
- [Prop and Display Naming Conventions](A_Naming_Conventions.md)
- [Building the Master Musical Preview](E_Master_Musical_Preview_Howto.md)
- [Create Wiring Backgrounds](D_Create_Wiring_Backgrounds..md)
- [Preview Import Workflow](Preview_Import_Workflow.md)

## Related Engineering

- [Preview Merger](../03_Preview_Merger/README.md)
- [LOR Data Extraction](../02_Data_Extraction/README.md)
- [FormView](../04_FormView/README.md)

# Changelog

- 2026-08-22 — Rewritten as a plain-language operator procedure. Engineering details were removed from the normal workflow while preserving current folder, Master Musical Preview, wiring, and staging rules.
- 2026-08-17 — Reconciled with the current Preview/folder workflow.
- 2026-08-11 — Added Master Musical Preview handoff.
- 2025-10-05 — Initial release.
