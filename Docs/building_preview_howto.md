# Building a Preview (Operator How-To)

_Last updated: 2025-10-26

This guide explains how to build, edit, and export a preview in **Light‑O‑Rama (LOR)** for integration with the MSB Database.

---

## Prerequisites
- A background image (`.jpg`) of the display panel design or entire stage.
- Save the file to:  
  `G:\Shared drives\Display Folders\Stage Folder'
- Size limits:
  - Max **4000 × 3000 px**
  - Recommended: **800 × 600 px** for a single panel.
  - Recommended: **3840 x 2160 px** for a full stage.
  - Save as JPG optimized with a 20% compression factor (Easy to do in PaintShop Pro) 
- File naming:
  ```
  - Show Background Stage xx LOR Preview.jpg
  - RGB Plus Prop Stage xx LOR Preview.jpg
  ```
- Example:
[<img src="/Docs/images/Show_Background_Stage_15_Preview_Background.jpg" width="600" alt="Show Background Stage 15 (scaled)">](/Docs/images/Show_Background_Stage_15_Preview_Background.jpg)

---

## Creating a New Preview

1. **Open LOR Sequence Editor.**
2. In the bottom-left panel, select **Background → Set Image**.
3. Browse to your background file.  
   ⚠️ **Do not save the image with the preview.**
4. Draw the strings and assign controllers and channels.
5. **Naming Conventions:**
   - **Channel Names:** follow channel naming conventions.
   - **Comment field:** must be filled with the **Display Name** (required for every channel).
6. When finished:
   - Select all channels → **Create Group**.
   - Save the group with the **Prop Naming Convention**.
7. Export the group as a **.leprop** file:
   ```
   G:\Shared drives\MSB Database\Database Previews\PreviewsForProps
   ```
   Use the **Preview Name** for the file.
8. Save the preview as:
   ```
   1st Panel Preview <Display Name>
   ```
9. Export the preview (`.lorprev`) to the same `PreviewsForProps` folder.

---

## Personal Props
For individual use (not yet centrally managed):
```
G:\Shared drives\MSB Database\UserPreviewStaging\<username>\PreviewsForProps
```

---

## Reusing Props
The `.leprop` file creates a **prop key** that can be reused inside larger previews, such as:
- `RGB Plus Prop Stage xx`
- `Show Background Stage xx`
- `Show Animation xx`

---

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

---
## Create a Wiring Background
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
Example:
[<img src="/Docs/images/Show_Background_Stage_15_Preview_Background_Wired.jpg" width="600" alt="Show Background Stage 15 Wired (scaled)">](/Docs/images/Show_Background_Stage_15_Preview_Background_Wired.jpg)


## Create a Tagged Wiring Background
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
  - Do not use **Channel Names!**, these will appear in the Field Wiring Chart
  - If you add **Channel Names** and the channels change over time, the wiring diagram will need to be updated!
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
Example:
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

---

## Suggested commit message
```
docs: add operator guide for building and editing previews

- New doc: Docs/building_preview_howto.md
- Covers prerequisites, creating a preview, personal props, editing existing previews
- Reminder to follow Workflow v6 after any preview changes
```

