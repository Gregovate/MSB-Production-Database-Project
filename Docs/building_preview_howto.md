---
title: Building a Preview (Operator How-To)
version: 2025-10-29
author: Greg Liebig / Engineering Innovations, LLC
---

# Building a Preview (Operator How-To)

_Last updated: 2025-10-26

This guide explains how to build, edit, and export a preview in **Light‑O‑Rama (LOR)** for integration with the MSB Database.

---

## Prerequisites
- Start with the Prop Approval Form.
- Once approved, draw the concept display.
- Create a folder under the corect Display Stage ID with the Display name
- Create the Background image (`.jpg`) of the display panel design
- Save a copy of the finished display file to:  
  'G:\Shared drives\Display Folders\<StageID-StageName-Prefix>\Wiring\'
- Size limits:
  - Max **4000 × 3000 px**
  - Recommended: **800 × 600 px** for a horizontal panel or **600 x 800** for a vertical panel.
  - Recommended: **3840 x 2160 px** for a full stage.
  - Save as JPG optimized with a 20% compression factor (Easy to do in PaintShop Pro) 
- File naming:
  ```
  - DisplayName.jpg
  ```

---

## Creating Single Panel Preview for a New Display 

1. **Open LOR Sequence Editor.**
2. In the bottom-left panel, select **Background → Set Image**.
3. Browse to your background file you saved in   G:\Shared drives\Display Folders\<StageID-StageName-Prefix>\wiring
   1. Start with the background image created 
   2. ⚠️ **Do not save the image with the preview.**
   3. 
   
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
   ```
   G:\Shared drives\MSB Database\Database Previews\PreviewsForProps
   ```
   Use the **Preview Name** for the file.
9. Save the preview as:
   ```
   **Display Prop <Display Name> UID StartChannel-EndChannel**
   ```
10. Export the preview (`.lorprev`) to the same `PreviewsForProps` folder.
- Display Prop Example with Channel Grid

[<img src="/Docs/images/ChristmasHippo.jpg" width="600" alt="Display Prop ChristmasHippo TC 7B 01-07 (scaled)">](/Docs/images/ChristmasHippo.jpg)

  
---

## Personal Props
For individual use (not yet centrally managed):
```
G:\Shared drives\MSB Database\UserPreviewStaging\<username>\PreviewsForProps
```

---

## Creating Previews for Stages
The `.leprop` file creates a **PropID** that can be reused inside larger previews, such as:
- `RGB Plus Prop Stage xx`
- `Show Background Stage xx`
- `Show Animation xx`
If there are duplicate displays like Arrow signs, Speed Limit signs, Making Spirit Bright signs, they must be created in one preview to ensure each display has it's unique PropID. The database will error if more than one display shares the same PropID
---
1. When exporting props, they land, by default, in the Author's ImportExport folder
2. These props can then be added to a Stage Preview.
3. You can import all the props you need
4. In Progess...
 
## Editing an Existing Preview

1. Import the preview from the canonical folder:
   ```
   G:\Shared drives\MSB Database\Database Previews
   ```
   (ensures you have the latest version).
2. To add a prop: choose **Add → LOR Prop file**, then select from:
   ```
   G:\Shared drives\MSB Database\Database Previews\PreviewsForProps
   ```
3. After editing:
   - Save the preview.
   - Export the updated `.lorprev` file to your **user staging folder**:
     ```
     G:\Shared drives\MSB Database\UserPreviewStaging
     ```
- Stage Preview Example:

[<img src="/Docs/images/Show_Background_Stage_15_Preview_Background.jpg" width="600" alt="Show Background Stage 15 (scaled)">](/Docs/images/Show_Background_Stage_15_Preview_Background.jpg)
---
## Create a Wiring Background for Stage Previews
We now have the ability to include an image in the field wiring paperwork. Creating this image involves a few more steps. This only applies to the stage previews:
  ```
  - Show Background Stage xx preview name.jpg
  - RGB Plus Prop Stage xx preview name.jpg
  ```
1. Open the complete Preview in the Preview Editor:
2. Snip the **entire preview image** you created using the Windows Snip App Full Screen:
3. Save the snipped image
- Save the file to:  
  `G:\Shared drives\Display Folders\Stage Folder\Show Background Stage xx Preview Background Wired.jpg'
- File naming:
  ```
  - Show Background Stage xx LOR Preview Wired.jpg
  - RGB Plus Prop Stage xx LOR Preview Wired.jpg
  ```
4. Replace the initial background with the wired version you just created. Depending on how accurate you were  making the snip, you may have to adjust your wired props slightly to get everything to line up.
5. Save the preview. The basic wiring diagram is done
- Stage Wiring Example:

[<img src="/Docs/images/Show_Background_Stage_15_Preview_Background_Wired.jpg" width="600" alt="Show Background Stage 15 Wired (scaled)">](/Docs/images/Show_Background_Stage_15_Preview_Background_Wired.jpg)


## Create a Tagged Wiring Background For Stage Previews
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
7. Save the file as `G:\Shared drives\Display Folders\Stage Folder\

  ```
  - Show Background Stage xx LOR Preview Tagged.drawio
  - RGB Plus Prop Stage xx LOR Preview Tagged.drawio
  ```
8. Eport the file to `G:\Shared drives\Display Folders\Stage Folder\
  ```
  - Show Background Stage xx LOR Preview Tagged.jpg
  - RGB Plus Prop Stage xx LOR Preview Tagged.jpg
  ```
9. Lastly, you will need to assign the new image as the background file in the sequencer.
- Tagged Stage Example:

[<img src="/Docs/images/Show_Background_Stage_15_Preview_Background_Tagged.jpg" width="600" alt="Show Background Stage 15 Tagged (scaled)">](/Docs/images/Show_Background_Stage_15_Preview_Background_Tagged.jpg)

---

## Reminder
After **any changes** to previews:
- Run the full **Workflow v6** pipeline:
  1. Merger
  2. Parser
  3. Sheet Export
  4. DB Compare

This ensures the system stays consistent for all users.

