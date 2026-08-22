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
| System | LOR Preview Authoring / Field Wiring |
| Task | Create and publish field wiring images |
| Audience | Preview authors and wiring-documentation maintainers |
| Status | CURRENT |
| Owner | MSB Production Crew |
| Last Reviewed | 2026-08-22 |

## Purpose

Use this procedure when creating or updating the images used for field wiring instructions.

These images help the field crew see where Displays and controller connections are located. They do not replace the controller/channel assignments stored in LOR.

---

# 1. Use the Correct Wiring Folder

Use the wiring folder that matches the type of field wiring.

## Background / Static wiring

```text
<Stage / Sub-stage / Scene>\Wiring\BackgroundStage\
```

## Musical wiring

```text
<Stage / Sub-stage / Scene>\Wiring\MusicalStage\
```

## Working files

Keep editable and temporary work in the matching `SourceDocs` folder:

```text
Wiring\BackgroundStage\SourceDocs\
Wiring\MusicalStage\SourceDocs\
```

Do not use `SourceDocs` as the published field-image location.

---

# 2. Check the Marker Files

Folders used by FieldWiring must have the required marker:

```text
_MSB-DB-Source-Folder_READ-ME-FIRST-AND-DO-NOT-DELETE.txt
```

For a published wiring path, verify the marker is present in:

- the Stage/Sub-stage/Scene root;
- `Wiring`; and
- the `BackgroundStage` or `MusicalStage` folder being used.

Do not rename or delete marker files.

See [MSB Source Folder Marker](../../00_Project_Overview/03-MSB_DB_Source_Folder_Marker_Operator_Procedure.md).

---

# 3. Keep the Published Wiring Folder Clean

Only current field-use images belong directly in `BackgroundStage` or `MusicalStage`.

Do not leave:

- draft images;
- obsolete images;
- source files;
- screenshots that are not part of the current field instructions; or
- unrelated photographs

in the published folder.

Move working material into `SourceDocs`.

This matters because the field system may show the images stored directly in the selected published wiring folder.

---

# 4. Create a Basic Wiring Image

A basic wiring image can be made from the LOR Preview.

1. Open the complete Stage/Scene Preview in LOR.
2. Arrange the view so the physical layout is easy to understand.
3. Capture the complete Preview with Windows Snip Tool or another screen-capture tool.
4. Save the working capture in the correct `SourceDocs` folder.
5. Crop, resize, or clean up the image as needed.
6. Save the finished field-use image directly in the marked `BackgroundStage` or `MusicalStage` folder.

A typical full-Stage image size is about:

```text
3840 x 2160
```

The important requirement is that the image remains readable on screen and when printed.

---

# 5. Create a Tagged Wiring Image When More Detail Is Needed

A tagged image is recommended when the plain Preview does not clearly show where physical Displays are located.

A common method is to use draw.io.

1. Open draw.io and create a new diagram.
2. Set the page size to match the base image when practical.
3. Insert the base Stage/Scene image.
4. Add arrows, boxes, or callouts to identify Displays and connection areas.
5. Label physical Displays using their **Display Names**.
6. Save the editable `.drawio` file in `SourceDocs`.
7. Export the finished JPG or PNG directly into the marked published wiring folder.

Example:

```text
<Stage>\Wiring\BackgroundStage\SourceDocs\Show Background Stage 21 PolarBears-Tagged.drawio
<Stage>\Wiring\BackgroundStage\Show Background Stage 21 PolarBears-Tagged.jpg
```

Use a readable font size. The goal is a drawing the setup crew can understand quickly.

---

# 6. More Than One Wiring Image Is Allowed

Large or complicated Stages/Scenes may need more than one wiring image.

Store each final field-use image directly in the same marked published folder.

Example:

```text
Wiring\BackgroundStage\
    Show Background Stage 21 PolarBears-Tagged.jpg
    Show Background Stage 21 Sliding Penguins-Tagged.jpg
```

Only keep images there that belong in the current field packet.

---

# 7. When the Wiring Image Is Also the LOR Background

A published wiring image may also be selected as the LOR Preview/Scene background when that is the best image for authoring.

In LOR:

1. Open the Preview Editor.
2. Choose **Background -> Set Image**.
3. Select the current published image directly from the marked `BackgroundStage` or `MusicalStage` folder.
4. Do **not** embed the image.
5. Save the Preview.

This direct Wiring path is allowed. You do not need to copy the same image into `PreviewBackground` just to use it in LOR.

---

# 8. Master Musical Preview — Important Difference

A Master Musical Scene does not have to use a Wiring image as its background.

Normally, use a marked `PreviewBackground` image for the Scene.

A directly published `Wiring\MusicalStage` image is also allowed when that wiring drawing is intentionally the best Scene background.

Do not use `SourceDocs` for a new Scene background.

See [Building the Master Musical Preview](E_Master_Musical_Preview_Howto.md).

---

# 9. Check the Wiring Information

The picture does not override LOR.

Before relying on the wiring image, verify the LOR Preview still has the correct:

- controller IDs;
- channels;
- networks; and
- DMX/E1.31 information where applicable.

If the picture and LOR disagree, stop and correct/review the source information.

---

# 10. Check the Field Output

The browser-based **FieldWiring** system is the current replacement being prepared for field use. **FormView remains available as the fallback/reference until FieldWiring completes deployment and field-device acceptance.**

Before relying on the image set:

1. use the current field-wiring tool available for the test/field situation;
2. select the correct Stage/Scene and wiring type;
3. make sure the expected wiring image(s) appear;
4. verify there are no old or unrelated images; and
5. confirm the wiring table matches the area you are working on.

If an unwanted image appears, remove or move it from the published wiring folder and check again.

---

# Printed Wiring Instructions Are Temporary

Printed or generated wiring instructions are temporary field working documents.

- Generate a current copy when needed.
- Use it for the current setup work.
- Do not laminate or treat it as permanent wiring authority.
- Discard old copies after the work is complete or after Preview/wiring information changes.

This prevents crews from using stale hookup information.

---

# Before You Finish

- [ ] I used the correct `BackgroundStage` or `MusicalStage` folder.
- [ ] The Stage/Sub-stage/Scene root is marked.
- [ ] `Wiring` is marked.
- [ ] The published `BackgroundStage` / `MusicalStage` folder is marked.
- [ ] Working files are in `SourceDocs`.
- [ ] Only current field-use images are in the published wiring folder.
- [ ] Any LOR background points to an approved marked image and not `SourceDocs`.
- [ ] LOR controller/channel/network information is correct.
- [ ] I checked the final image set in the current field-wiring tool.

## Expected Result

The correct current wiring images are available for the same Stage/Sub-stage/Scene as the wiring data, with no draft or unrelated images mixed into the field output.

## Related Operator Documents

- [Preview Authoring Home](README.md)
- [Building a Preview](B_Building_Preview_Howto.md)
- [Building the Master Musical Preview](E_Master_Musical_Preview_Howto.md)
- [MSB Source Folder Marker](../../00_Project_Overview/03-MSB_DB_Source_Folder_Marker_Operator_Procedure.md)

## Related Engineering

- [FieldWiring Engineering](../../02_Production_Database/01_System_Architecture/09_Wiring_System/README.md)
- [FormView](../04_FormView/README.md)

## Revision History

- 2026-08-22 — Rewritten for operators in plain language and aligned with current FieldWiring, FormView fallback, direct Wiring background paths, and full marker requirements.
