---
title: Create and Publish a Field Wiring Diagram
author: Greg Liebig / Engineering Innovations, LLC
status: CURRENT
revision: 2026-08-24
---

# Create and Publish a Field Wiring Diagram

| Document Control | Value |
|---|---|
| Document Type | Operational SOP |
| System | LOR Preview Authoring / Field Wiring |
| Task | Create, update, and publish field wiring images |
| Audience | Preview authors and wiring-documentation maintainers |
| Status | CURRENT |
| Owner | MSB Production Crew |
| Last Reviewed | 2026-08-24 |
| Keywords | wiring diagram, Field Wiring, draw.io, Stage wiring, BackgroundStage, MusicalStage, LOR Preview |

## Purpose

Use this procedure when creating or updating a wiring image that the setup crew will use in **Field Wiring**.

The image helps the crew recognize the physical layout and connection areas. The wiring image does **not** replace the controller/channel/network information maintained in LOR and presented by Field Wiring.

## Before You Start

- Confirm the correct Stage, Sub-stage, or Scene.
- Decide whether you are documenting **Background / Static** wiring or **Musical** wiring.
- Do not place a current published image in `SourceDocs`.
- Keep editable source files separate from the field-use image.

## Choose the Correct Wiring Folder

### Background / Static wiring

Publish the final image directly in:

```text
<Stage / Sub-stage / Scene>\Wiring\BackgroundStage\
```

Keep editable/working files in:

```text
<Stage / Sub-stage / Scene>\Wiring\BackgroundStage\SourceDocs\
```

### Musical wiring

Publish the final image directly in:

```text
<Stage / Sub-stage / Scene>\Wiring\MusicalStage\
```

Keep editable/working files in:

```text
<Stage / Sub-stage / Scene>\Wiring\MusicalStage\SourceDocs\
```

Putting the current field image only in `SourceDocs` can prevent Field Wiring from presenting it as the published wiring image.

## Check the Marker Files

Before publishing, verify:

```text
<Stage / Sub-stage / Scene root>     marker required
Wiring                               marker required
BackgroundStage                      no separate marker
MusicalStage                         no separate marker
SourceDocs                           no marker for field presentation
```

The marker filename is:

```text
_MSB-DB-Source-Folder_READ-ME-FIRST-AND-DO-NOT-DELETE.txt
```

For the full marker procedure, see [Add and Verify MSB Display Folder Marker Files](../../00_Project_Overview/Google_Drive/operatorSOP/Add_Verify_Marker_Files.md).

## Create a Basic Wiring Image

A basic wiring image can be made from the LOR Preview.

1. Open the complete Stage/Scene Preview in LOR.
2. Arrange the Preview so the physical layout is easy to understand.
3. Capture the full useful view with Windows Snipping Tool or another screen-capture tool.
4. Save the working capture in the correct `SourceDocs` folder.
5. Crop, resize, or clean up the image as needed.
6. Save/export the finished JPG or PNG directly into the correct published Wiring folder.

A typical full-Stage image may be around:

```text
3840 x 2160
```

Exact dimensions are less important than readability on a screen and on a printed temporary field copy.

## Create a Tagged Wiring Image

Use a tagged image when the plain Preview does not clearly show where Displays or connection areas are located.

A common method is draw.io.

1. Open draw.io and create a new diagram.
2. Set the page size to match the base image when practical.
3. Insert the base Stage/Scene image.
4. Add arrows, boxes, or callouts to identify Displays and connection areas.
5. Label Displays using their current **Display Names**.
6. Keep labels large enough to read on a phone/tablet and on a printed field copy.
7. Save the editable `.drawio` file in `SourceDocs`.
8. Export the finished JPG or PNG directly into the applicable published Wiring folder.

Example:

```text
21-Polar Bear Playground-PB\
└── Wiring\
    └── BackgroundStage\
        ├── SourceDocs\
        │   └── Show Background Stage 21 PolarBears-Tagged.drawio
        └── Show Background Stage 21 PolarBears-Tagged.jpg
```

The `.drawio` source is for editing. The JPG/PNG beside `SourceDocs` is the current field image.

## More Than One Wiring Image Is Allowed

A large or complicated Stage/Scene may need more than one current wiring image.

Example:

```text
Wiring\BackgroundStage\
├── Show Background Stage 21 PolarBears-Tagged.jpg
└── Show Background Stage 21 Sliding Penguins-Tagged.jpg
```

Keep only images that belong in the current field packet directly in the published folder.

Move drafts, obsolete images, editable source files, and unrelated screenshots into `SourceDocs` or the appropriate historical location.

## If the Wiring Image Is Also the LOR Background

A published wiring image may also be used as the LOR Preview/Scene background when it is the best image for authoring.

In LOR:

1. Open the Preview Editor.
2. Choose **Background → Set Image**.
3. Select the current published image from the applicable `Wiring\BackgroundStage` or `Wiring\MusicalStage` folder.
4. Do **not** embed the image.
5. Save the Preview.

Do not make a duplicate copy in `PreviewBackground` merely to satisfy the folder layout when the published Wiring image is intentionally the LOR background.

Do not point a new LOR background into `SourceDocs`.

## Master Musical Preview

A Master Musical Scene does not have to use its wiring image as the LOR background.

Normally use the approved Scene `PreviewBackground` image when that is the best authoring background.

A published `Wiring\MusicalStage` image may be used when the wiring drawing itself is intentionally the best Scene background.

See [Building the Master Musical Preview](E_Master_Musical_Preview_Howto.md) for the Preview-authoring workflow.

## Verify the Wiring Data

The picture does not override LOR wiring information.

Before publishing or relying on a diagram, verify the current LOR Preview still has the correct applicable:

- controller IDs;
- channels/outputs;
- networks;
- DMX information; and
- E1.31 information.

If the picture and Field Wiring/LOR information disagree, stop and review the source information rather than editing the picture to hide the disagreement.

## Verify the Published Diagram in Field Wiring

Field Wiring is production-operational at:

```text
https://my.sheboyganlights.org/fieldwiring/
```

After publishing the image:

1. Open **Field Wiring**.
2. Find the intended Display, Stage, or Scene.
3. Select the applicable Background/Static or Musical wiring context.
4. Confirm the expected current image appears.
5. Confirm no draft, source, obsolete, or unrelated image appears.
6. Confirm the hookup information shown with the image matches the intended physical area.

If the new image does not appear, first verify it is directly in the correct published Wiring branch and that the Stage/Scene root and `Wiring` marker files are present.

## Printed Wiring Instructions Are Temporary

Printed or generated wiring instructions are temporary field working documents.

- Generate/print a current copy when needed.
- Use it for the current setup work.
- Do not laminate or treat it as permanent wiring authority.
- Discard stale printed copies after wiring/Preview information changes or when the work is complete.

This prevents crews from using old hookup information after the system changes.

## Before You Finish

- [ ] I used the correct `BackgroundStage` or `MusicalStage` folder.
- [ ] The Stage/Sub-stage/Scene root marker is present.
- [ ] The `Wiring` marker is present.
- [ ] I did not add a separate marker to `BackgroundStage` or `MusicalStage`.
- [ ] Editable/working files are in `SourceDocs`.
- [ ] Current field-use JPG/PNG files are directly in the published Wiring folder.
- [ ] Any LOR background points to an approved current image and not `SourceDocs`.
- [ ] Current LOR controller/channel/network information has been checked.
- [ ] I verified the final image in production Field Wiring.

## Expected Result

The intended Stage/Sub-stage/Scene has a readable current wiring image in the correct published Wiring branch, and that image appears with the correct hookup information in Field Wiring.

## If Something Is Wrong

- **Image does not appear in Field Wiring:** verify the published location and required markers first.
- **Old image also appears:** remove it from the current published folder or move it to the correct source/history location after confirming it is no longer current.
- **Image and hookup table disagree:** stop and review the LOR/source wiring information.
- **Unsure whether the wiring belongs at Stage or Scene level:** review Folder Alignment/current Scene ownership before moving files by guesswork.

## Related Operator Documents

- [Google Drive / Display Folder Operations](../../00_Project_Overview/Google_Drive/README.md)
- [Add and Verify MSB Display Folder Marker Files](../../00_Project_Overview/Google_Drive/operatorSOP/Add_Verify_Marker_Files.md)
- [Preview Authoring Home](README.md)
- [Building a Preview](B_Building_Preview_Howto.md)
- [Building the Master Musical Preview](E_Master_Musical_Preview_Howto.md)

## Related Engineering

- [FieldWiring Engineering](../../02_Production_Database/01_System_Architecture/09_Wiring_System/README.md)
- [Google Drive Engineering](../../00_Project_Overview/Google_Drive/engineering/README.md)
- [FormView](../04_FormView/README.md)

## Revision History

- 2026-08-24 — Repaired navigation to the final direct Google Drive subsystem layout.
- 2026-08-23 — Updated for production FieldWiring and separated operator publishing steps from resolver/application engineering detail.
- 2026-08-22 — Corrected current FieldWiring marker placement and rewrote the procedure for field-document maintainers.
