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
## Tools for Making Display Drawings

To build a display, we need a plottable **vector drawing**.  
Scaling a bitmap image (such as *.jpg or *.png) will not work for a 4 ft × 8 ft panel because bitmap images lose quality when enlarged.

Several programs can be used to create vector drawings:

### AutoCAD
- Works well with DXF formats
- We have a limited number of licenses available
- Suitable for precise dimensional work

### Inkscape — Free Vector Graphics Editor
- [Inkscape](https://inkscape.org/)
- Free and open-source vector drawing program
- Can import bitmap images and trace them to create vector graphics
- Exports scalable vector formats such as *.svg
- Ideal for signage, outlines, and panel layouts

**File Naming Guidelines:**

- Inkscape saves files as `*.svg` using Inkscape-specific features
- For working files, include `-inkscape.svg` in the filename  
  *(Example: `SnowmanPanel-inkscape.svg`)*
- When the drawing is finalized and ready for production, save a clean export with `-working.svg`  
  *(Example: `SnowmanPanel-working.svg`)*

### GIMP — GNU Image Manipulation Program (Raster Editor)
- [GIMP](https://www.gimp.org/)
- Free image editor for bitmap graphics
- Useful for cleaning up photos or artwork before vector tracing
- Not suitable for final scalable drawings


## Prerequisites

Complete the following steps before beginning wiring or preview work:

1. Start with the **Display Approval Form**
2. Once approved, create the concept drawing of the display
3. Create a folder under the correct **Display Stage ID** using the display name
4. Create the background image (`.jpg`) of the display panel design
5. Save a copy of the finished display file to:


G:\Shared drives\Display Folders\StageID-StageName-Prefix\Wiring\Props-Displays


---

## Image Requirements

### Size Limits

- **Maximum:** 4000 × 3000 pixels  
- **Recommended (single panel):**
- Horizontal: **800 × 600 px**
- Vertical: **600 × 800 px**
- **Recommended (full stage):**
- **3840 × 2160 px**

### Format

- Save as **JPG**
- Optimize with approximately **20% compression**
- (Easy to do in PaintShop Pro or similar software)

### File Naming

Use the display name exactly:

DisplayName.jpg

---

## Creating a Single-Panel Preview for a New Display

1. **Open LOR Sequence Editor**

2. In the bottom-left panel, select  
   **Background → Set Image**

3. Browse to your background file located at:


G:\Shared drives\Display Folders<StageID-StageName-Prefix>\Wiring\Props-Displays


- Use the background image created during the design phase
- ⚠️ **Do NOT embed or save the image with the preview**

4. Draw the strings and assign controllers and channels

---

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

