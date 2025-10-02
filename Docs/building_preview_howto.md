# Building a Preview (Operator How-To)

_Last updated: 2025-10-01_

This guide explains how to build, edit, and export a preview in **Light‑O‑Rama (LOR)** for integration with the MSB Database.

---

## Prerequisites
- A background image (`.jpg` or `.png`) of the display panel design.
- Save the file to:  
  `G:\Shared drives\Display Folders`
- Size limits:
  - Max **4000 × 3000 px**
  - Recommended: **800 × 600 px** for a single panel.
- File naming:
  ```
  Preview Background <Display Name>
  ```

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

