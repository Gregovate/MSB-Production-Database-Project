---
title: Create Wiring Backgrounds for Stage Previews
author: Greg Liebig / Engineering Innovations, LLC
status: CURRENT
revision: 2026-08-22
---

# Create Wiring Backgrounds for Stage Previews

| Document Control | Value |
|---|---|
| Document Type | Operator Procedure |
| System | LOR Preview Authoring / FormView |
| Task | Create and publish field wiring images |
| Audience | Preview authors and wiring-documentation maintainers |
| Status | CURRENT |
| Owner | MSB Production Crew |
| Last Reviewed | 2026-08-22 |

## Purpose

Use this procedure when creating or updating the images used for field wiring instructions.

These images are different from normal LOR Preview or Scene background images.

## Where the Files Go

Use the correct wiring folder for the type of field wiring you are documenting.

### Background / Static wiring

```text
<Stage or Scene>\Wiring\BackgroundStage\
```

### Musical wiring

```text
<Stage or Scene>\Wiring\MusicalStage\
```

### Working files

Put editable source files and temporary work in the matching `SourceDocs` folder:

```text
Wiring\BackgroundStage\SourceDocs\
Wiring\MusicalStage\SourceDocs\
```

Do not put drafts and source files in the main wiring-image folder.

---

# Important: Keep the Main Wiring Folder Clean

FormView can include the other image files stored in the same wiring folder as the selected main image.

That means every JPG, JPEG, or PNG in the main wiring folder may appear in the field documentation.

Before field use:

- keep only current field-use images in the main wiring folder;
- move editable and temporary files into `SourceDocs`;
- remove obsolete images; and
- check the final image set in FormView.

Do not use the main wiring folder as a general photo or artwork folder.

---

# 1. Choose the Correct Wiring Folder

Use `BackgroundStage` for a **Show Background Stage** Preview.

Example:

```text
G:\Shared drives\Display Folders\21-Polar Bear Playground-PB\Wiring\BackgroundStage\
```

Use `MusicalStage` for musical field-wiring images.

Example:

```text
G:\Shared drives\Display Folders\21-Polar Bear Playground-PB\Wiring\MusicalStage\
```

A normal individual Display folder does not automatically need a Wiring folder.

---

# 2. Create a Basic Wiring Image

A basic image can be made directly from the LOR Preview.

1. Open the complete Stage Preview in LOR.
2. Arrange the view so the Stage is easy to understand.
3. Capture the complete Preview with Windows Snip Tool or another screen-capture tool.
4. Save the working capture in the correct `SourceDocs` folder.
5. Crop, resize, or clean up the image as needed.
6. Save the final field-use image directly in the main `BackgroundStage` or `MusicalStage` folder.

A typical full-Stage image size is about:

```text
3840 x 2160
```

The important requirement is that the image remains readable on screen and in the printed field instructions.

---

# 3. Create a Tagged Wiring Image When More Detail Is Needed

A tagged image is recommended when the plain Preview does not clearly show where the physical Displays are located.

A common method is to use draw.io.

1. Open draw.io and create a new diagram.
2. Set the page size to match the base image when practical.
3. Insert the base Stage image.
4. Add arrows, boxes, or callouts to identify Displays and connection areas.
5. Label the physical Displays using their **Display Names**.
6. Save the editable `.drawio` file in `SourceDocs`.
7. Export the finished field-use image as JPG or PNG into the main wiring folder.

Example:

```text
<Stage>\Wiring\BackgroundStage\SourceDocs\Show Background Stage 21 PolarBears-Tagged.drawio
<Stage>\Wiring\BackgroundStage\Show Background Stage 21 PolarBears-Tagged.jpg
```

Use a readable font size. The exact style is less important than making the field drawing clear.

---

# 4. Use More Than One Image When Necessary

Large or complicated Stages may need more than one wiring image.

That is allowed.

Store each final field-use image in the same main wiring folder.

Example:

```text
Wiring\BackgroundStage\
    Show Background Stage 21 PolarBears-Tagged.jpg
    Show Background Stage 21 Sliding Penguins-Tagged.jpg
```

FormView can show the main image plus the additional images from that folder.

Again, only keep images there that belong in the current field packet.

---

# 5. Set the Main Wiring Image in LOR

For a Stage Preview that is used with the current FormView workflow:

1. Make sure the final main wiring image is directly in the correct main wiring folder.
2. Open the LOR Preview Editor.
3. Choose **Background -> Set Image**.
4. Select the final published wiring image.
5. Do **not** embed the image.
6. Save the Preview.

Example:

```text
G:\Shared drives\Display Folders\21-Polar Bear Playground-PB\Wiring\BackgroundStage\Show Background Stage 21 PolarBears-Tagged.jpg
```

FormView uses that location to find the field wiring images for the selected Preview.

---

# 6. Master Musical Preview — Important Difference

Do not use `Wiring\MusicalStage` as the normal location for Master Musical Preview Scene background images.

Master Musical Scene backgrounds belong in the correct `PreviewBackground` folder.

Use:

[Building the Master Musical Preview](E_Master_Musical_Preview_Howto.md)

The `Wiring\MusicalStage` folder is for the field wiring images themselves.

---

# 7. Check the Wiring Information

The picture does not replace the LOR wiring assignments.

Before relying on a wiring image, verify the LOR Preview still has the correct:

- controller IDs;
- channels;
- networks; and
- DMX information where applicable.

If the picture and the LOR assignments disagree, stop and correct the source information. Do not assume the picture is right.

---

# 8. Check FormView Before Field Use

Before printing or using the field wiring instructions:

1. Open the correct Preview in FormView.
2. Make sure the expected main image appears.
3. Page through any additional images.
4. Confirm there are no old or unrelated images.
5. Confirm the wiring table matches the Stage you are working on.

If an unwanted image appears, remove or move it from the main wiring folder and check again.

---

# Printed Wiring Instructions Are Temporary

FormView wiring printouts are temporary working documents.

- Generate a current copy when needed.
- Use it for the current setup work.
- Do not laminate or treat it as permanent wiring documentation.
- Discard old copies after the work is complete or after the Preview/wiring information changes.

This prevents crews from using an old wiring sheet after the system has changed.

---

# Before You Finish

- [ ] I used the correct `BackgroundStage` or `MusicalStage` folder.
- [ ] Working files are in `SourceDocs`.
- [ ] Only current field-use images are in the main wiring folder.
- [ ] The main image is selected in the correct LOR Stage Preview when required for FormView.
- [ ] The image is linked, not embedded.
- [ ] LOR controller/channel/network information is correct.
- [ ] I checked the final image set in FormView.
- [ ] Master Musical Scene backgrounds were not incorrectly stored in the Wiring folder.

## Expected Result

The correct Stage wiring images appear in FormView with the current wiring information, and the main wiring folder contains only images that should be shown to the field crew.

## Related Operator Documents

- [Preview Authoring Home](README.md)
- [Building a Preview](B_Building_Preview_Howto.md)
- [Building the Master Musical Preview](E_Master_Musical_Preview_Howto.md)
- [Prop and Display Naming Conventions](A_Naming_Conventions.md)

## Related Engineering

- [FormView](../04_FormView/README.md)
- [FormView Engineering Architecture](../04_FormView/FormView_Engineering_Architecture.md)
- [Folder Alignment Engineering Design](../02_Data_Extraction/Folder_Alignment/Folder_Alignment_Engineering_Design.md)

## Revision History

- 2026-08-22 — Rewritten for operators in plain language. Internal filesystem/application explanations were removed from the task instructions while preserving the current FormView folder and image behavior.
- 2026-08-17 — Reconciled the wiring-image workflow with the current Google Drive structure and FormView behavior.
