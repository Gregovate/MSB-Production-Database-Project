---
title: Create Wiring Backgrounds for Stage Previews
author: Greg Liebig / Engineering Innovations, LLC
status: CURRENT
revision: 2026-08-17
---

# Create Wiring Backgrounds for Stage Previews

## Purpose

This procedure explains how to create, publish, and maintain the Stage wiring images used by the current MSB field-wiring workflow.

This is a **wiring-publication** procedure. It is not the general location for every LOR Preview or Scene background image.

The current Google Drive contract separates:

```text
PreviewBackground
    = normal Preview/Scene authoring background and scope evidence

Wiring\BackgroundStage
Wiring\MusicalStage
    = published field-wiring images
```

The existing FormView application depends on the published Wiring-folder behavior described here. Detailed FormView engineering and the browser-based FieldWiring conversion remain separate projects.

---

# Current Field-Wiring Flow

For the proven FormView workflow:

```text
approved Stage Preview
        |
        v
PreviewClass.BackgroundFile
        |
        v
published Wiring image directory
        |
        +--> primary wiring image
        +--> additional published images in same directory
        |
        v
FormView + parser-created wiring rows
        |
        v
on-screen field wiring / CSV / disposable printable HTML
```

For current FormView 0.3.1, the Preview `BackgroundFile` is not merely a visual setting. Its parent directory becomes the active published wiring-image directory.

---

# Standard Stage / Scene Wiring Structure

Stage, Sub-stage, and true Scene documentation roots may own Wiring branches:

```text
<Stage / Sub-stage / Scene>\
└── Wiring\
    ├── BackgroundStage\
    │   ├── published field images
    │   └── SourceDocs\
    └── MusicalStage\
        ├── published field images
        └── SourceDocs\
```

A normal individual Display folder does **not** automatically receive a `Wiring` tree. Display folders use the smaller `PreviewBackground` / `Photos` helper structure unless an existing legacy engineering structure is being intentionally preserved.

Do not create a Display `Wiring` folder merely because an LOR Display exists.

---

# Published Images vs Source Material

## Published field images

Only current field-use images belong directly in:

```text
Wiring\BackgroundStage\
```

or:

```text
Wiring\MusicalStage\
```

These directories are application-facing publication boundaries.

Current FormView searches the same directory as the selected Preview's `BackgroundFile` for additional JPG/JPEG/PNG images.

Therefore extra or obsolete images can appear in the field output.

## Source material

Working/source files belong under:

```text
Wiring\BackgroundStage\SourceDocs\
```

or:

```text
Wiring\MusicalStage\SourceDocs\
```

Examples:

- `.drawio` source;
- PaintShop Pro source;
- editable vector/raster source;
- screenshots used to build the final diagram;
- temporary markups; and
- intermediate exports.

FormView does not recursively treat `SourceDocs` as the published field-image set.

---

# Background / Static Wiring

Use the `BackgroundStage` branch for the field-wiring images associated with a **Show Background Stage** Preview.

Example:

```text
G:\Shared drives\Display Folders\21-Polar Bear Playground-PB\
└── Wiring\
    └── BackgroundStage\
        ├── Show Background Stage 21 PolarBears-Tagged.jpg
        ├── Show Background Stage 21 Sliding Penguins-Tagged.jpg
        └── SourceDocs\
            ├── polar_bears_map.drawio
            └── sliding_penguins_layout.jpg
```

For the current FormView contract, the approved Stage Preview's external `BackgroundFile` should reference the intended primary image directly in the published `BackgroundStage` directory.

The primary image becomes Page 1 and the directory is used to discover additional published images.

---

# Musical Wiring Publication

Use the `MusicalStage` branch for published musical field-wiring diagrams:

```text
<Stage / Sub-stage / Scene>\Wiring\MusicalStage\
```

Keep current field-use images directly in that directory and working source material under `SourceDocs`.

## Important Master Musical Preview boundary

Do **not** use `Wiring\MusicalStage` as the general location for Master Musical Preview Scene authoring backgrounds merely to create a filesystem pointer.

The current Master Musical Preview operator contract uses the appropriate scope's:

```text
PreviewBackground\
```

for Scene authoring backgrounds / path-resolution evidence.

The published `Wiring\MusicalStage` branch remains the field-wiring diagram location.

Current FormView 0.3.1 has not yet been operationally validated against the V7 scene-aware database / Master Musical Scene model. The separate FieldWiring/FormView conversion project owns that integration work.

See [Building the Master Musical Preview](E_Master_Musical_Preview_Howto.md).

---

# Creating a Basic Wiring Image

A basic wiring image may be created directly from the LOR Preview when a more detailed diagram is not yet necessary.

Typical workflow:

1. open the complete Stage Preview in LOR;
2. display the Stage layout clearly;
3. capture the complete Preview using Windows Snip Tool or another screen-capture method;
4. save the working capture under the applicable `SourceDocs` folder;
5. crop/resize/clean the image as required;
6. publish the final JPG directly in the applicable Wiring branch; and
7. for a current FormView Stage Preview, assign that published image as the Preview's external background.

Typical full-Stage image guidance remains approximately:

```text
3840 x 2160 px
```

The exact size is less important than keeping the field image readable on screen and in printed output.

---

# Tagged Wiring Images

Tagged diagrams are recommended when the plain Preview image does not clearly identify physical Display locations.

A common workflow uses draw.io:

1. create a new diagram;
2. set the page/canvas to match the background image;
3. insert the base Stage image;
4. add arrows, boxes, or callouts to identify physical Displays/connection areas;
5. label using the stable physical **Display Name** rather than relying only on a channel name that may later change;
6. save the editable `.drawio` source in `SourceDocs`; and
7. export the final field-use image as JPG/PNG directly into the published Wiring branch.

Example:

```text
<Stage>\Wiring\BackgroundStage\SourceDocs\Show Background Stage 21 PolarBears-Tagged.drawio
<Stage>\Wiring\BackgroundStage\Show Background Stage 21 PolarBears-Tagged.jpg
```

For a complex Stage, more than one published image is allowed.

---

# Additional Images for Large or Complex Stages

Current FormView supports multiple wiring images for one selected Preview.

The primary `BackgroundFile` is first. FormView then discovers additional supported image files from the **same published directory**.

Supported current extensions include:

- `.jpg`;
- `.jpeg`; and
- `.png`.

Consequences:

- keep only current field-use images in the published directory;
- do not leave obsolete or draft exports beside the primary image;
- move working material into `SourceDocs`;
- do not use the published Wiring directory as a general photo library; and
- verify the image order/content in FormView before relying on the output.

---

# Set the Current FormView BackgroundFile

For a Stage Preview that is intentionally part of the current FormView workflow:

1. publish the intended primary image directly in the correct Wiring branch;
2. in the LOR Preview editor use:

```text
Background -> Set Image
```

3. select that published image from the shared drive;
4. do **not** embed the image;
5. save the Preview; and
6. export the candidate Preview through the normal Preview Authoring / `UserPreviewStaging` workflow.

Example Background/Static path:

```text
G:\Shared drives\Display Folders\21-Polar Bear Playground-PB\Wiring\BackgroundStage\Show Background Stage 21 PolarBears-Tagged.jpg
```

The current FormView engineering contract uses the containing directory as the active published wiring-image directory.

---

# Keep the Published Wiring Directory Clean

Before field use, verify:

- the correct primary image is present;
- every additional JPG/JPEG/PNG belongs in the current field packet;
- no draft or obsolete diagrams remain;
- source files are under `SourceDocs`;
- the external `BackgroundFile` opens from the shared drive; and
- the selected Preview produces the expected image set and wiring rows in FormView.

If the folder contains unnecessary images, FormView may display or print them.

---

# Wiring Data Authority

LOR remains authoritative for:

- controller assignments;
- controller Unit IDs;
- channel numbers;
- networks;
- DMX universes/channels; and
- show topology.

The Wiring images are the visual field-documentation layer.

FormView combines parser-derived wiring rows with these published images. A diagram does not override conflicting LOR wiring data.

If the diagram and LOR assignments disagree, fix/review the engineering source rather than treating the picture as the wiring authority.

---

# Temporary Printed/HTML Output

FormView printable HTML and hard-copy wiring output are temporary field working documents, not permanent engineering records.

Current output carries a generation timestamp and a prominent stale-copy warning. The operational rule is:

- generate a current copy when needed;
- use it for the immediate field task;
- do not laminate or archive it as permanent wiring authority;
- discard it when the setup work is complete; and
- treat it as expired after a newer Preview merge/database build changes the underlying data.

This expiration behavior belongs to the proven FormView workflow and must be preserved by the separate FieldWiring conversion unless that project explicitly approves a different controlled-document lifecycle.

---

# Before Exporting the Preview

Verify:

- [ ] The Preview uses the correct current Preview class/context.
- [ ] The published field-wiring image is directly in the correct `Wiring\BackgroundStage` or `Wiring\MusicalStage` directory.
- [ ] Working/source files are under the corresponding `SourceDocs` folder.
- [ ] The current FormView Stage Preview references the intended published primary image externally.
- [ ] The published directory contains only current field-use images.
- [ ] LOR controller/channel/network assignments are correct.
- [ ] Master Musical Scene authoring backgrounds have not been incorrectly moved into Wiring merely for path resolution.
- [ ] The candidate Preview will be exported to `UserPreviewStaging\<username>`, not directly over the controlled master.

---

## Important System Boundary

This procedure owns the **operator-facing publication of wiring images**.

It does not own:

- FormView source-code behavior;
- V7 compatibility validation;
- PostgreSQL schema;
- the browser-based FieldWiring replacement;
- Google Drive folder redesign; or
- the Master Musical Preview's Scene classification rules.

Those responsibilities remain in their own controlled subsystem documents/projects.

---

## Related Documents

- [Building a Preview](B_Building_Preview_Howto.md)
- [Building the Master Musical Preview](E_Master_Musical_Preview_Howto.md)
- [Naming Conventions](A_Naming_Conventions.md)
- [Google Drive Folder Structure](../../00_Project_Overview/00-Google_Drive.md)
- [Folder Alignment Engineering Design](../02_Data_Extraction/Folder_Alignment/Folder_Alignment_Engineering_Design.md)
- [FormView](../04_FormView/README.md)
- [FormView Engineering Architecture](../04_FormView/FormView_Engineering_Architecture.md)

## Revision History

- 2026-08-17 — Reconciled the wiring-image procedure with the current Google Drive helper-folder contract, separated `PreviewBackground` from published Wiring directories, preserved the proven FormView `BackgroundFile`/same-directory behavior, and kept Master Musical / FieldWiring conversion work outside this procedure.
