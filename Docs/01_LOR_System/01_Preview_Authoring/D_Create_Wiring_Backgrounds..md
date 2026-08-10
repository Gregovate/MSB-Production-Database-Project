---
title: Create Wiring Backgrounds for Stage Previews
author: Greg Liebig / Engineering Innovations, LLC
status: ACTIVE
---

# Create Wiring Backgrounds for Stage Previews

## Purpose

This procedure explains how to create and organize the background images and supporting files used by Light-O-Rama Stage Previews and the MSB field-wiring documentation workflow.

The wiring background is more than a picture used while authoring a preview. Its stored path and the files placed in the designated Wiring folders are part of the field-documentation pipeline used by FormView.

At a high level:

```text
Stage folder
    -> Wiring folder
        -> designated Preview background folder
            -> Preview background image
            -> supporting field-reference images
        -> LOR Preview references the background image path
        -> FormView uses that path/folder relationship
        -> FormView collects the designated field images
        -> FormView builds printable HTML field-wiring instructions
```

The generated HTML is used by setup crews while plugging displays into controllers and connecting the Stage in the field.

## Standard Stage Folder Location

Each Stage has one unique folder under:

```text
G:\Shared drives\Display Folders\StageID-StageName-Prefix\
```

Example:

```text
G:\Shared drives\Display Folders\21-Polar Bear Playground-PB\
```

The existing Stage-oriented folder structure is shared operational infrastructure. Do not create a second unrelated folder structure for wiring documentation.

## Wiring Folder Purpose

The `Wiring\` folder is reserved for field installation documentation and the images needed by the LOR Stage Preview / FormView wiring workflow.

It is intended to support:

- Stage Preview background images;
- field wiring reference images;
- controller connection diagrams;
- Draw.io wiring documents and source material;
- FormView-generated field wiring instructions; and
- visual setup references used while connecting the Stage.

Do not use the Wiring folders as general-purpose storage for unrelated artwork, temporary exports, or fabrication files.

## Wiring Folder Layout

A typical Stage wiring structure is:

```text
G:\Shared drives\Display Folders\21-Polar Bear Playground-PB\
└── Wiring\
    ├── BackgroundStage\
    │   ├── Show Background Stage 21 PolarBears-Tagged.jpg
    │   ├── Show Background Stage 21 Sliding Penguins-Tagged.jpg
    │   └── SourceDocs\
    │       ├── polar_bears_map.drawio
    │       ├── polar_bears_wiring.pspimage
    │       └── sliding_penguins_layout.jpg
    │
    ├── MusicalStage\
    │   ├── Show Musical Stage 21 PolarBears-Tagged.jpg
    │   ├── Show Musical Stage 21 Sliding Penguins-Wired.jpg
    │   └── SourceDocs\
    │       ├── polar_bears_musical_map.drawio
    │       ├── penguins_musical_layers.pspimage
    │       └── penguins_overview_layout.jpg
    │
    └── Props-Displays\
        ├── polar_bears_musical_map.drawio
        ├── penguins_musical_layers.pspimage
        └── penguins_overview_layout.jpg
```

### `BackgroundStage`

Store the images used for **Show Background Stage** Preview field-wiring instructions here.

The `SourceDocs\` subfolder is the working location for source material used to build those field-wiring background images.

### `MusicalStage`

Store the images used for **Musical Stage** Preview field-wiring instructions here.

The `SourceDocs\` subfolder is the working location for source material used to build those field-wiring background images.

### `Props-Displays`

Use this area for images needed to build individual Display/Prop previews in LOR. These are distinct from the Stage-level field-wiring instruction images.

## Creating the Wiring Background

The Stage wiring background should provide a useful visual map for field installation. Depending on the Stage, it may be created from Draw.io, PaintShop Pro, Inkscape, GIMP, photographs, layout drawings, or other source material.

The working/source files belong in the appropriate `SourceDocs\` folder. The final image used by the LOR Preview belongs directly in the designated `BackgroundStage\` or `MusicalStage\` folder.

The final background should show enough information to make the generated field-wiring instructions useful to the setup crew. The exact drawing content varies by Stage.

## Set the Background Image in LOR

In the LOR Preview editor:

```text
Background -> Set Image
```

Browse to the final background image in the correct Stage Wiring folder.

Example:

```text
G:\Shared drives\Display Folders\21-Polar Bear Playground-PB\Wiring\BackgroundStage\Show Background Stage 21 PolarBears-Tagged.jpg
```

or, for a Musical Stage Preview:

```text
G:\Shared drives\Display Folders\21-Polar Bear Playground-PB\Wiring\MusicalStage\...
```

### Do not embed the image

The Preview should reference the background image externally rather than embedding it into the Preview.

The stored background path is important because the existing wiring-documentation workflow uses that filesystem relationship to locate the Stage wiring material.

## FormView Relationship

FormView uses the LOR/parsed Preview background path as the starting point for the wiring-documentation workflow.

The current operational behavior is:

1. The Stage Preview references its background image by path.
2. That path places the Preview within the established Stage `Wiring\` folder structure.
3. FormView uses the path/folder relationship to locate the designated wiring images associated with that Preview.
4. Images stored in the applicable field-wiring folder are incorporated into the output.
5. FormView combines those images with the wiring information derived from the LOR Preview data.
6. FormView generates a printable HTML document used in the field for plugging displays and controller connections.

This folder/path relationship is therefore an operational contract, not merely a file-organizing preference.

## Keep the Designated Wiring Folders Clean

FormView uses the contents of the designated wiring folders when producing field documentation.

Because of this:

- only place images needed for the field-wiring instructions in those folders;
- do not leave unrelated pictures in the active wiring-image folder;
- do not leave obsolete exports behind after the Stage documentation changes;
- keep working/source material inside `SourceDocs\` rather than mixed with final field images; and
- verify the correct final background image is referenced by the LOR Preview.

Extra or obsolete images can become part of the generated field documentation and confuse the setup crew.

## Background Image Guidance

For Stage backgrounds, use a JPG image sized appropriately for the Preview and field documentation.

Existing guidance for full Stage images is approximately:

```text
3840 x 2160 px
```

The image should remain readable when viewed on screen and when incorporated into printed/HTML field instructions.

## Before Exporting the Preview

Verify:

1. The Preview references the final image from the correct Stage `Wiring\` folder.
2. The background image opens correctly from the shared-drive location.
3. The designated wiring-image folder contains only current field-use images.
4. Source/working files are kept in `SourceDocs\` where applicable.
5. The Stage/Preview naming follows the current Preview Authoring naming rules.
6. Controller and channel assignments in LOR are correct before relying on the resulting field instructions.

Then export the Preview using the normal controlled Preview Authoring workflow.

## Important System Boundary

LOR remains authoritative for controller assignments, channel numbers, network/DMX assignments, and show topology.

The Wiring folder and its images provide the visual field-documentation layer. FormView combines those visual assets with the LOR-derived wiring data to create a practical installation document; it does not redefine the LOR wiring assignments.

## Related Documents

- [Building a Preview](B_Building_Preview_Howto.md)
- [Naming Conventions](A_Naming_Conventions.md)
- [LOR Preview Authoring](README.md)
- [Wiring System Engineering](../../02_Production_Database/01_System_Architecture/09_Wiring_System/README.md)

## Engineering Note

This document records the operator-facing folder/path contract. The detailed FormView engineering design — including how it resolves the background path, which folders/files it reads, how it combines images with wiring rows, and how the printable HTML is assembled — must be documented separately from the application source and linked back here.
