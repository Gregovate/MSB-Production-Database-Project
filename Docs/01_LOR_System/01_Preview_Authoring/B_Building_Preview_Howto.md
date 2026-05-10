---
title: Building a Preview (Operator How-To)
version: 2025-10-30
author: Greg Liebig / Engineering Innovations, LLC
---

# Building a Preview (Operator How-To)

This guide explains how to build, edit, and export a preview in **Light‑O‑Rama (LOR)** for integration with the MSB Database.

---

## Folder Layout — Wiring Images and Examples
```
G:
└── Shared drives
└── Display Folders
└── 21-Polar Bear Playground-PB -> **Each Stage has single unique folder**
└── Wiring -> **Folder used to store all images needed for LOR Previews**
├── BackgroundStage -> **Only store images here needed for the Field Wiring Instructions here for Background Previews**
│ ├── Show Background Stage 21 PolarBears-Tagged.jpg
│ ├── Show Background Stage 21 Sliding Penguins-Tagged.jpg
│ └── SourceDocs **Location to build the background images for Field Wiring Instructions**
│ ├── polar_bears_map.drawio
│ ├── polar_bears_wiring.pspimage
│ └── sliding_penguins_layout.jpg
│
├── MusicalStage -> **Only store images here needed for the Field Wiring Instructions here for Musical Previews**
│ ├── Show Musical Stage 21 PolarBears-Tagged.jpg
│ ├── Show Musical Stage 21 Sliding Penguins-Wired.jpg
│ └── SourceDocs **Location to build the background images for Field Wiring Instructions**
│ ├── polar_bears_musical_map.drawio
│ ├── penguins_musical_layers.pspimage
│ └── penguins_overview_layout.jpg
│
└── Props-Displays -> **Only store images here to build the Display/Prop for LOR**
│ ├── polar_bears_musical_map.drawio
│ ├── penguins_musical_layers.pspimage
│ └── penguins_overview_layout.jpg
```
# Display Drawing and Preview Creation

## Overview

To build a display, we need a plottable **vector drawing**.

Scaling a bitmap image (such as *.jpg or *.png) will NOT work for fabrication because bitmap images lose quality when enlarged. A 4 ft × 8 ft panel requires a full-scale vector drawing that can be accurately resized without distortion.

Vector drawings are used for:

- CNC cutting
- Plotting
- Wiring overlays
- Panel layout verification
- Full-scale printing
- Documentation
- Preview background generation

Bitmap images are still important for:

- Documentation
- Preview images
- Tracing source artwork
- Wiring references

Both vector and bitmap workflows are required for building displays.

---

# Recommended Software Tools

## AutoCAD

https://www.autodesk.com/products/autocad/

- Works well with DXF formats
- Suitable for precise dimensional work
- Best suited for fabrication and dimensional accuracy
- We have a limited number of licenses available

---

## Inkscape — Free Vector Graphics Editor

https://inkscape.org/

- Free and open-source vector drawing program
- Can import bitmap images and trace them into vector graphics
- Exports scalable vector formats such as *.svg
- Ideal for signage, outlines, overlays, and panel layouts
- Works well for organizing display wiring layers

### IMPORTANT — Full Scale Document Setup

When creating a new display drawing in Inkscape:

- The document size MUST match the actual panel size being built
- Always start the drawing at full scale

Examples:

- 4 ft × 8 ft panel
- 8 ft × 4 ft panel
- 3 ft × 6 ft coro panel

This ensures:

- Artwork fits correctly on stock frames
- Layout dimensions remain accurate
- Wiring overlays align correctly
- Exported files remain usable for fabrication

---

## GIMP — GNU Image Manipulation Program (Raster Editor)

https://www.gimp.org/

- Free bitmap image editor
- Useful for cleaning up photos or artwork before vector tracing
- Helpful for removing backgrounds or increasing contrast
- Commonly used before importing artwork into Inkscape
- NOT suitable for final scalable fabrication drawings

Typical workflow:

1. Clean up artwork in GIMP
2. Import image into Inkscape
3. Trace bitmap into vector artwork
4. Organize drawing into layers
5. Export production SVG files

---

# Layer Requirements

Layers are extremely important for display construction.

Each layer should represent a logical wiring or construction group.

Examples:

- Outline
- Cut Lines
- Channel 1
- Channel 2
- Roofline
- Eyes
- Mouth
- Floods
- Mounting Holes
- Wiring Overlay

Proper layer organization allows:

- Easier troubleshooting
- Cleaner fabrication files
- Wiring overlays to be generated
- Cleaner exported documentation
- Selective printing and exporting

Poor layer organization makes future maintenance extremely difficult.

---

# File Naming Standards

Inkscape uses special SVG features that are NOT fully compatible with many other programs.

Because of this, TWO SVG versions must be preserved.

---

## 1. Inkscape MASTER File

This file preserves:

- Layers
- Guides
- Inkscape effects
- Editable objects
- Internal metadata

### Naming Format

`DisplayName-inkscape.svg`

### Example

`SnowmanPanel-inkscape.svg`

This is the MASTER working file and should always be preserved.

---

## 2. Production / Working Export

Once the drawing is finalized for production, export a simplified SVG version for compatibility with other programs.

### Naming Format

`DisplayName-plain.svg`

### Example

`SnowmanPanel-plain.svg`

This version is typically used for:

- CNC software
- Plotters
- Sharing with other programs
- Production workflows

---

# JPG / PNG Export Rules

Bitmap images such as *.jpg and *.png are ONLY used for:

- Documentation
- Wiring previews
- Web pages
- Printed instructions
- Preview backgrounds
- Quick reference images

Bitmap formats are:

- NOT scalable
- NOT suitable for fabrication
- NOT suitable for plotting or CNC work

Because bitmap images are resolution-dependent:

- Export sizes matter
- Low-resolution exports become blurry when enlarged
- Large images consume excessive storage space

---

# Folder Structure Requirements

Each approved display must have its files stored under the proper stage folder structure.

## Standard Stage Folder Location

```text
G:\Shared drives\Display Folders\StageID-StageName-Prefix\
```

Example:

```text
G:\Shared drives\Display Folders\21-Polar Bear Playground-PB\
```

---

# Display Folder Organization

Under each stage folder, there should be a dedicated folder for each display.

This folder should contain:

- Inkscape drawings
- AutoCAD drawings
- Working SVG files
- Source artwork
- Preview images
- Documentation images
- Related fabrication files

Example:

```text
G:\Shared drives\Display Folders\21-Polar Bear Playground-PB\Snowman\
```

---

# Display Groups for Large Projects

For larger multi-part displays, a display group folder may be created to organize related displays together.

This is commonly used when multiple props belong to a larger themed scene.

Example:

```text
G:\Shared drives\Display Folders\13-Winter Wonderland-WW\Christmas Vacation\
```

Inside the display group folder, individual display folders may then be created:

```text
13-Winter Wonderland-WW\
└── Christmas Vacation\
    ├── RV\
    ├── Cousin Eddie\
    ├── Clark\
    ├── Garbage Can\
    └── Uncle Louis\
```

This helps keep:

- Related artwork together
- Wiring documentation organized
- Preview assets grouped logically
- Fabrication files easier to manage
- Multi-display scenes easier to maintain

---

# IMPORTANT — Avoid Loose Files

Do NOT store unrelated drawing files directly under the stage root folder.

Every display should have its own dedicated folder structure.

This prevents:

- Lost artwork
- Duplicate files
- Broken preview references
- Wiring documentation confusion
- Difficulty locating fabrication assets later

# Wiring Documentation Folder

⚠️ IMPORTANT:

The `Wiring\` folder is a RESERVED folder structure used for **field installation documentation**.

This folder is NOT intended for storing:

- Raw artwork
- Working SVG files
- Fabrication files
- General preview assets
- Temporary exports

The Wiring folder exists specifically to support:

- Field setup documentation
- Controller connection diagrams
- DrawIO wiring documents
- FormView-generated wiring PDFs
- Visual field reference images

---

# FormView Integration

The FormView application automatically scans the Wiring folder structure and generates printable field setup documentation.

This documentation is used by setup crews to identify:

- Which controller plugs into which display
- Wiring paths
- Display locations
- Port assignments
- Visual setup references

---

# IMPORTANT — Preview Name Controls Folder Linking

The Preview Name is extremely important because it controls how the FormView application locates the correct Wiring folders.

The Preview Name acts as the pointer between:

- LOR Preview files
- Wiring documentation folders
- Background images
- FormView-generated PDFs

If the Preview Name does NOT match the expected folder structure:

- FormView may fail to locate images
- Wiring PDFs may generate incorrectly
- Field setup documentation may be incomplete
- Wrong displays may appear in generated packets

Because of this, Preview Names must remain standardized and consistent.

---

# IMPORTANT — Keep Wiring Folders Clean

The FormView application scans these folders automatically.

⚠️ Any extra images or unrelated files may appear in generated wiring PDFs.

Because of this:

- ONLY place files needed for field setup into these folders
- Do NOT use the Wiring folders for general artwork storage
- Do NOT leave old exports or temporary images in these folders
- Remove obsolete images when displays are updated

If these folders become cluttered, the generated field documentation becomes difficult to use.

---

# Typical Wiring Folder Structure

```text
Wiring\
Wiring\BackgroundStage\
Wiring\MusicalStage\
Wiring\DrawIO\
```

Additional folders may be added later as the workflow evolves.

---

# Future Direction

The current FormView workflow is considered temporary.

Future plans are to migrate the wiring and setup documentation system into the new MSB Database workflow. That system is not yet implemented.

Until then, the existing Wiring folder structure remains critical for field setup operations.

# Prerequisites Before Wiring or Preview Work

Complete the following steps before beginning wiring or preview creation:

1. Start with the approved Display Approval Form
2. Create the concept drawing of the display
3. Create the display folder under the correct Stage ID
4. Create the vector artwork
5. Create the preview background image (*.jpg)
6. Save all files into the proper Wiring folders

---

# Image Requirements

## Size Limits

### Maximum

- 4000 × 3000 pixels

### Recommended — Single Panel

- Horizontal: 800 × 600 px
- Vertical: 600 × 800 px

### Recommended — Full Stage

- 3840 × 2160 px

---

# Image Format Requirements

- Save preview images as JPG
- Optimize with approximately 20% compression
- PaintShop Pro, GIMP, or similar software may be used

---

# Background Image File Naming

Use the display name exactly.

Example:

```text
SnowmanPanel.jpg
```

---

# Creating a Single-Panel Preview for a New Display

## 1. Open LOR Sequence Editor

---

## 2. Set the Background Image

In the lower-left panel:

```text
Background → Set Image
```

Browse to the background image located under the display stage folder.

Example:

```text
G:\Shared drives\Display Folders\21-Polar Bear Playground-PB\Wiring\Props-Displays
```

Use the JPG background image created during the design phase.

⚠️ IMPORTANT:

- Do NOT embed the image into the preview
- The preview should reference the image externally
- This keeps preview files smaller and easier to maintain

---

## 3. Draw Strings and Assign Channels

- Draw the display strings
- Assign controllers
- Assign channels
- Verify scaling and placement
- Save the preview file into the correct stage folder

### Naming Guidance

📘 See  
[Prop and Display Naming Conventions](../01_Preview_Authoring/A_Naming_Conventions.md)  
for full rules on channel grouping, display IDs, and comment field requirements.

---

### Channel Naming Convention

Use the following format:


SC UID-Channel Name


Where:

- **SC** — Character abbreviation of the display or stage  
- **UID** — Controller ID assigned to the display  
- **Channel** — Controller port or channel number  
- **Name** — Brief description of the channel  
  - Channel lists sort alphabetically

---

5. When channel setup is complete:

   - Select all channels → **Create Group**
   - Save the group using the **Display Name**

6. Export the group as a `.leprop` file

   - Exported props are saved by default to the author’s local `ImportExport` folder
   - Copy the `.leprop` file to:


G:\Shared drives\MSB Database\Database Previews\PreviewsForProps


- Use the **Preview Name** as the file name

7. Save the preview as:


Display Prop <Display Name> UID StartChannel-EndChannel


8. Export the preview (`.lorprev`) to the same  
   `PreviewsForProps` folder

---

## Example — Display Prop with Channel Grid

[<img src="/Docs/images/ChristmasHippo.jpg" width="600" alt="Display Prop ChristmasHippo TC 7B 01-07 (scaled)">](/Docs/images/ChristmasHippo.jpg)

---

## Creating Previews for Stages

The `.leprop` file creates a **PropID** that can be reused inside larger previews, such as:

- `RGB Plus Prop Stage xx` (`MusicalStage`)
- `Show Background Stage xx` (`BackgroundStage`)
- `Show Animation xx` *(Not implemented)*

---

## Background

- When exporting props, they are saved by default to the author’s local **ImportExport** folder
- Copy the prop file to:

G:\Shared drives\MSB Database\Database Previews\PreviewsForProps

- These props can then be added to a Stage Preview and will be available to everyone
- Import all required props into the stage preview
- Verify channel names comply with naming conventions and controller assignments
- If there are **spare channels**:
- Include them in the preview
- Use **SPARE** as the Display Name (Comment field)
- Color them **orange** as placeholders for future development

## Duplicated Displays

If there are multiple identical displays (such as arrow signs, speed limit signs, or Making Spirits Bright signs), they **MUST** be created together in a single preview so that each display receives a unique **PropID**.

The database will generate errors if more than one display shares the same PropID.

- ❌ Never copy a `.leprop` file from one preview into another preview

---

### Example

[<img src="/Docs/images/combined_duplicated_displays.png" width="600" alt="Combined Duplicate Displays">](/Docs/images/combined_duplicated_displays.png)

---

### Export Procedure

- Each display group is exported to its own `.leprop` file:

  - `MSB-01.leprop`
  - `MSB-02.leprop`
  - `MSB-03.leprop`
  - `MSB-04.leprop`

- These props can then be safely imported into other previews

---

## Editing an Existing Preview

1. Import the preview from the canonical folder:

```
G:\Shared drives\MSB Database\Database Previews
```

   This ensures you have the latest version.

---

### If the preview does NOT contain a background image

We need to create and add one.

#### Capture the image

- If the show is running, take a photo of the stage.
- Ensure lighting is sufficient so displays are clearly visible.
- Capture ALL elements if possible (needed for Field Wiring documentation).

#### Save location depends on stage type

**Musical Stage**

Save to:

```
G:\Shared drives\Display Folders\Stage Folder\Wiring\MusicalStage\SourceDocs
```

File name:


RGB Plus Stage <Stage#> <Name> Background.jpg


---

**Background Stage**

Save to:

```
G:\Shared drives\Display Folders\Stage Folder\Wiring\BackgroundStage\SourceDocs
```

File name:


Show Background Stage <Stage#> <Name> Background.jpg


---

### Edit the Image

1. Open the image in an editor  
   - Corel PaintShop Pro is available on the Show PC
2. Set canvas size to:
    - 3840 × 2160 pixels
3. Save as JPG with approximately 20% compression

---

### Import Props into the Preview

1. Begin importing the prop files created for the stage.
2. To add a prop:
    - **Add → LOR Prop file**
3. Select props from:

```
G:\Shared drives\MSB Database\Database Previews\PreviewsForProps
```

---

### After Editing

1. Save the preview.
2. Export the updated `.lorprev` file to your staging folder:

```
G:\Shared drives\MSB Database\UserPreviewStaging<Author>
```

---

## Create Wiring Backgrounds for Stage Previews

This allows Field Wiring documentation to include images.

Applies only to:

- Musical Stage previews
- Background Stage previews

---

## Field Wiring Images (Basic)

Fastest method, but limited detail.

- Only `.jpg` files directly inside the stage folders are used by FormView.
- ALL images in these folders will be included in Field Wiring documentation.

⚠️ Remove any files that should not appear.

### File Naming Pattern

>Show <Category> <StageType> <Stage#> <DisplayName>-<Tag>.jpg

Examples:

- Show Background Stage 21 PolarBears-Tagged.jpg
- Show Background Stage 21 Sliding Penguins-Wired.jpg
- RGB Plus Prop Stage 15 Wired.jpg

---

## How to Create a Basic Wiring Image

1. Open the complete preview in the Preview Editor.
2. Capture the entire preview using the Windows Snip Tool (Full Screen).
3. Save the image to the SourceDocs folder for the stage type.

---

### Save Locations

**Musical Stage**


G:\Shared drives\Display Folders<StageID-StageName-Prefix>\Wiring\MusicalStage\SourceDocs


File example:
- RGB Plus Prop Stage <Stage#> LOR Preview-Wired.jpg

---

**Background Stage**

```
G:\Shared drives\Display Folders<StageID-StageName-Prefix>\Wiring\BackgroundStage\SourceDocs
```

File example:

- Show Background Stage <Stage#> LOR Preview-Wired.jpg

---

4. If stopping here, copy the image to the main stage folder:

```
G:\Shared drives\Display Folders<StageID-StageName-Prefix>\Wiring<StageType>
```

5. Re-open the preview and set this image as the background.
6. Adjust props if needed to align correctly.
7. Save the preview.

The basic wiring diagram is now complete.

---

## Tagged Wiring Images (Recommended)

Creates a detailed diagram showing Display Names.

This cannot be generated inside LOR — use draw.io.

---

### Create Tagged Diagram in draw.io

1. Open draw.io and create a Blank Diagram.
2. Open Page Properties:
   - Orientation: Landscape
   - Page Size: Custom
   - Set to match the background image (typically 3840 × 2160)
3. Insert the wired image as the background.
4. Add shapes (arrows, boxes, etc.) to label each display.
5. Double-click shapes and enter the **Display Name**.
   ⚠️ Do NOT use Channel Names  
   Channel assignments may change over time.
6. Formatting guidelines:
   - Font: Helvetica
   - Minimum size: 18 pt bold
   - Recommended: 24 pt bold
7. Repeat until all displays are labeled.

---

### Save the draw.io File

**Musical Stage**

```
G:\Shared drives\Display Folders\Stage Folder\Wiring\MusicalStage\SourceDocs
```

Example:
- RGB Plus Prop Stage <Stage#> <Name>-Tagged.drawio

---

**Background Stage**

```
G:\Shared drives\Display Folders\Stage Folder\Wiring\BackgroundStage\SourceDocs
```

Example:

- Show Background Stage <Stage#> <Name>-Tagged.drawio

---

### Export Tagged Image

Export as JPG and save to the stage folder:

**Musical Stage**

```
G:\Shared drives\Display Folders\Stage Folder\Wiring\MusicalStage
```

Example:

- RGB Plus Prop Stage <Stage#> <Name>-Tagged.jpg

---

**Background Stage**

```
G:\Shared drives\Display Folders\Stage Folder\Wiring\BackgroundStage
```

Examples:
- Show Background Stage <Stage#> PolarBears-Tagged.jpg
- Show Background Stage <Stage#> Sliding Penguins-Tagged.jpg

---

### Final Step

Re-open the preview and assign the tagged image as the background file.

Save the preview.

Field Wiring documentation will now use the tagged diagram.

## ⚠️ IMPORTANT — Large Displays and Field Wiring Images

For large displays, a single preview image may not provide enough detail for wiring documentation.

A preview in LOR can only have **one background image**, but the FormView application supports multiple images for a stage.

FormView will automatically scan the following folders and include **all images found** when generating Field Wiring documentation:

- `MusicalStage`
- `BackgroundStage`

Example:

```
G:\Shared drives\Display Folders\21-Polar Bear Playground-PB\Wiring\BackgroundStage
```

Multiple images may be required to fully document complex stages.

### 🚨 Critical Requirement

**Only keep the images that are REQUIRED for Field Wiring documentation in these folders.**

FormView will print **EVERY image** found.

If unnecessary files are present, the wiring documentation will become cluttered and difficult to use.

Remove any temporary, draft, or unrelated images before finalizing.

---

### Example — Tagged Wiring Image

![Show Background Stage 15 Tagged](/Docs/images/Show_Background_Stage_15_Preview_Background_Tagged.jpg)

---

## Reminder
After **any changes** to previews, Export the preview to your G:\Shared drives\MSB Database\UserPreviewStaging\`Author Folder`
- Run the full **Workflow v6** pipeline:
  1. Merger
  2. Parser
  3. Sheet Export
  4. DB Compare

This ensures the system stays consistent for all users.

