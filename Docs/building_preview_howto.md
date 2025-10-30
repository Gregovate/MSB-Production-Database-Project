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
│ └── SourceImages **Location to build the background images for Field Wiring Instructions**
│ ├── polar_bears_map.drawio
│ ├── polar_bears_wiring.pspimage
│ └── sliding_penguins_layout.jpg
│
├── MusicalStage -> **Only store images here needed for the Field Wiring Instructions here for Musical Previews**
│ ├── Show Musical Stage 21 PolarBears-Tagged.jpg
│ ├── Show Musical Stage 21 Sliding Penguins-Wired.jpg
│ └── SourceImages **Location to build the background images for Field Wiring Instructions**
│ ├── polar_bears_musical_map.drawio
│ ├── penguins_musical_layers.pspimage
│ └── penguins_overview_layout.jpg
│
└── Props-Displays -> **Only store images here to build the Display/Prop for LOR**
│ ├── polar_bears_musical_map.drawio
│ ├── penguins_musical_layers.pspimage
│ └── penguins_overview_layout.jpg
```

## Prerequisites
- Start with the Prop Approval Form.
- Once approved, draw the concept display.
- Create a folder under the corect Display Stage ID with the Display name
- Create the Background image (`.jpg`) of the display panel design
- Save a copy of the finished display file to:  
  `G:\Shared drives\Display Folders\StageID-StageName-Prefix\Wiring\Props-Displays`
- Size limits:
  - Max **4000 × 3000 px**
  - Recommended: **800 × 600 px** for a horizontal panel or **600 x 800** for a vertical panel.
  - Recommended: **3840 x 2160 px** for a full stage.
  - Save as JPG optimized with a 20% compression factor (Easy to do in PaintShop Pro) 
- File naming: `DisplayName.jpg`

---

## Creating Single Panel Preview for a New Display 

1. **Open LOR Sequence Editor.**
2. In the bottom-left panel, select **Background → Set Image**.
3. Browse to your background file you saved in   G:\Shared drives\Display Folders\<StageID-StageName-Prefix>\Wiring\Props-Displays
   1. Start with the background image created 
   2. ⚠️ **Do not save the image with the preview.**
   
5. Draw the strings and assign controllers and channels.

> 📘 See [Prop and Display Naming Conventions](./01_Naming_Conventions.md)  
> for full rules on channel grouping, display IDs, and comment field requirements.

6. **Channel Naming Conventions:**
   [LL UID-Channel Name]
    - LL:  is the character abbreviation of the display or stage
    - UID:  assigned to the controller used
    - Channel:   is the channel or port of the controller
    - Name:  A brief description of the channel name. The list sorts alphabetically

7. When finished:
   - Select all channels → **Create Group**.
   - Save the group with the **Display Name**.
8. Export the group as a **.leprop** file:
  - When exporting props, they land, by default, in the Author's ImportExport folder on their local PC
  - Copy the prop file to `G:\Shared drives\MSB Database\Database Previews\PreviewsForProps`
    -  Use the **Preview Name** for the file.
10. Save the preview as:  **Display Prop <Display Name> UID StartChannel-EndChannel**
11. Export the preview (`.lorprev`) to the same `PreviewsForProps` folder.
- Display Prop Example with Channel Grid

[<img src="/Docs/images/ChristmasHippo.jpg" width="600" alt="Display Prop ChristmasHippo TC 7B 01-07 (scaled)">](/Docs/images/ChristmasHippo.jpg)

---

## Creating Previews for Stages
The `.leprop` file creates a **PropID** that can be reused inside larger previews, such as:
- `RGB Plus Prop Stage xx` `MusicalStage`
- `Show Background Stage xx` `BackgroundStage`
- `Show Animation xx` (Not Implemented)

## Background
-  When exporting props, they land, by default, in the Author's ImportExport folder on their local PC
-  Copy the prop file to 'G:\Shared drives\MSB Database\Database Previews\PreviewsForProps'
-  These props can then be added to a Stage Preview and will be available to everyone
-  You can import all the props you need.
-  Be sure to double check the Channel Names to comply with our naming conventions and channel/Controller assignments are correct.
-  If there are SPARE channels, be sure to include them and use SPARE as the Display Name (Comment) field. I color them Orange and they are used as place-holders for future development.

## Duplicated Displays

If there are duplicate displays like Arrow signs, Speed Limit signs, Making Spirit Bright signs, they must be created in one preview to ensure each display has it's unique PropID. The database will error if more than one display shares the same PropID

## Editing an Existing Preview

1. Import the preview from the canonical folder: `G:\Shared drives\MSB Database\Database Previews` (ensures you have the latest version).
2. If the preview Does Not contain a background image we need to add it
   - If the show is running, take a picture of the stage being careful to collect all elements possible
   - Try to have enough light so the displays are visible. Needed for the Field Wiring documentation
   - The location for image storage depends on the type of background image being taken `Musical Stage` or `Background Stage`
     - `Musical` Save the image to G:\Shared drives\Display Folders\Stage Folder\Wiring\MusicalStage\SourceImages
       - RGB Plus Stage xx Name Background.jpg
     - `Background` Save the image to G:\Shared drives\Display Folders\Stage Folder\Wiring\BackgroundStage\SourceImages
       - Show Background Stage xx Name Background.jpg
   - Edit Open up the image in an editor. Corel Paint Shop Pro is Avaiable on the Show PC
   - Ensure the Canvas/Image size it to 3840 x 2160 and use a 20% Compression
   - Begin importing the prop files created for the stage
   - To add a prop: choose **Add → LOR Prop file**, then select from: `G:\Shared drives\MSB Database\Database Previews\PreviewsForProps`
3. After editing:
   - Save the preview.
   - Export the updated `.lorprev` file to your **G:\Shared drives\MSB Database\UserPreviewStaging\Author**:
- Stage Preview Example:

[<img src="/Docs/images/Show_Background_Stage_15_Preview_Background.jpg" width="600" alt="Show Background Stage 15 (scaled)">](/Docs/images/Show_Background_Stage_15_Preview_Background.jpg)
---
## Create a Wiring Backgrounds for Stage Previews
We now have the ability to include an image in the Field Wiring paperwork. Creating this image involves a few more steps. This only applies to the `Musical` or `Background` stage previews:

### Field Wiring Images
-  This is the fastest method to create a wiring view but not very useful
-  Only `.jpg` files directly inside `BackgroundStage` or `MusicalStage` folders are used by FormView and exported to HTML.
-  Every image in these folders will be used in the Field Wiring documentation **Remove every file not needed!**

**File naming pattern:**
Show <Category> <StageType> <Stage#> <DisplayName>-<Tag>.jpg
Examples:  
- `Show Background Stage 21 PolarBears-Tagged.jpg`  
- `Show Backround Stage 21 Sliding Penguins-Wired.jpg`
- `RGB Plus Prop Stage 15 Wired.jpg`

### How-To
1. Open the complete Preview in the Preview Editor:
2. Snip the **entire preview image** you created using the Windows Snip App Full Screen:
3. Save the snipped image. Location depends on the preview `stage type` you are working ie: `MusicalStage` or `BackgroundStage`
-  It's important to save this image in the SourceImages Folder
- `Musical Stage` G:\Shared drives\Display Folders\<StageID-StageName-Prefix>\Wiring\MusicalStage\SourceImages'
  - RGB Plus Prop Stage xx LOR Preview-Wired.jpg
- `Background Stage` G:\Shared drives\Display Folders\<StageID-StageName-Prefix>\Wiring\BackgroundStage\SourceImages'
  - File naming: Show Background Stage xx LOR Preview-Wired.jpg
4. If you are stopping here then just copy the image you just saved to G:\Shared drives\Display Folders\<StageID-StageName-Prefix>\Wiring\`Stage Type`\
5. Re-open the preview and then select the file you just saved G:\Shared drives\Display Folders\<StageID-StageName-Prefix>\Wiring\`Stage Type`\ and set as background.
6. Replace the initial background with the wired version you just created. Depending on how accurate you were  making the snip, you may have to adjust your wired props slightly to get everything to line up. This tells FormView where to look for the image.
7. Save the preview. The basic wiring diagram is done
- Stage Wiring Example:

[<img src="/Docs/images/Show_Background_Stage_15_Preview_Background_Wired.jpg" width="600" alt="Show Background Stage 15 Wired (scaled)">](/Docs/images/Show_Background_Stage_15_Preview_Background_Wired.jpg)


### Tagged Wiring Images
This is the last step to create a useful wiring diagram that tags the channels in the preview. Unfortunately, there is no way to create this image in LOR but we can build this image using drawio.
1. Open the DrawIO app
2. Select a Blank Diagram the Create
3. Go to Page Properties
  - Drag your wired image into the background or just drag the original background image without the wiring
  - Landscape
  - Page Size Custom
    - Set the page size to fit the background image. Hint: Should be **3840 x 2160**
4. Then using the Arrows or other geometry from the tool bar on left select the shape you want and drag it onto the image.
5. Double Click the shape and add each **DisplayName** to the shape. Format it so it fits the shape. You may need to open the sequencer and copy the Comment field to keep things accurate.
  - Font: Helvetica. Minimum Font Size 18pt BOLD 24pt Bold is better
  - Do not use **Channel Names!**, these will appear in the Field Wiring Chart
  - If you add **Channel Names** and the channels change over time, the wiring diagram will need to be updated!
  - As long as the preview background path does not change, the background is updateable as long as the path and file name remains the same. No need to edit the preview.
6. Repeat until you have all the displays defined.
7. Save the *.drawio file. Examples:
- MusicalStage
  -  `G:\Shared drives\Display Folders\Stage Folder\Wiring\MusicalStage\SourceImages\
    -  `RGB Plus Prop Stage 15 Church-Tagged.drawio`
- BackgroudStage
  -  `G:\Shared drives\Display Folders\Stage Folder\Wiring\BackgroundStage\SourceImages\
    -  `Show Backround Stage 21 Sliding Penguins-Tagged.drawio`
8. Export your tagged file as *.jpg and save it to:
- MusicalStage
  - G:\Shared drives\Display Folders\Stage Folder\Wiring\MusicalStage\
    - RGB Plus Prop Stage 15 Church-Tagged.jpg
- BackgroundStage
  - Show Background Stage 21 PolarBears-Tagged.jpg
  - Show Background Stage 21 Sliding Penguins-Tagged.jpg
9. Lastly, you will need to Re-open the preview and assign the new image as the background file in the sequencer.

**IMPORTANT**
For large displays, it may not be possible to create a single preview image to capture the detail needed for wiring the displays. A preview can only have one background image assigned. The FormView app understands this and will scan `MusicalStage` and `BackgroundStage` folders for all the images needed for setting up the display. That's why there are two images G:\Shared drives\Display Folders\21-Polar Bear Playground-PB\Wiring\BackgroundStage folder. **Only keep the images NEEDED for the Field Wiring documentation in thier repective folders!** The Formview app will print **EVERY** image in these folders and it will become useless if these folders get polluted with garbage image files!

[<img src="/Docs/images/Show_Background_Stage_15_Preview_Background_Tagged.jpg" width="600" alt="Show Background Stage 15 Tagged (scaled)">](/Docs/images/Show_Background_Stage_15_Preview_Background_Tagged.jpg)

---

## Reminder
After **any changes** to previews, Export the preview to your G:\Shared drives\MSB Database\UserPreviewStaging\`Author Folder`
- Run the full **Workflow v6** pipeline:
  1. Merger
  2. Parser
  3. Sheet Export
  4. DB Compare

This ensures the system stays consistent for all users.

