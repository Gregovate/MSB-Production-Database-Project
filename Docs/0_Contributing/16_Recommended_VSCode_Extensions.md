# 16 — Recommended VS Code Extensions

[← Previous: Glossary](15_Glossary.md) | [Back to Contributor Training](README.md)

---

# Purpose

This page lists Visual Studio Code extensions that have been tested or are commonly used when creating and maintaining MSB documentation.

These extensions are optional unless a procedure specifically says otherwise. They are intended to reduce repetitive manual work and make Markdown authoring easier for contributors.

Only settings that have been tested with the MSB documentation structure should be treated as the current recommended configuration.

---

# Paste Image

## What It Does

**Paste Image** lets you capture a screenshot to the Windows clipboard and paste it directly into a Markdown document from Visual Studio Code.

Instead of manually:

1. saving the screenshot;
2. moving it into the correct documentation folder;
3. renaming it;
4. typing the image path; and
5. adding display sizing;

Paste Image can perform those steps as part of one paste operation.

The normal keyboard shortcut is:

```text
Ctrl+Alt+V
```

The command can also be started from the Command Palette by searching for:

```text
Paste Image
```

---

## Current MSB Image Layout

Converted documentation subsystems should keep their own repository documentation images inside an `images` folder owned by that subsystem.

Example:

```text
Scanning/
├── images/
│   ├── README.md
│   └── Scan_Home_Page.png
├── README.md
├── QR_Code_Types_and_Meanings.md
├── Set_Up_Phone_or_Tablet_for_Scanning.md
├── Use_Scan_Manually.md
└── What_To_Do_After_You_Scan.md
```

Do not assume the older shared `Docs/images/` folder is the correct destination for new documentation images. Use the image location owned by the subsystem you are editing.

---

## Recommended Paste Image Settings

The settings below are proven for a Markdown file located directly in a subsystem folder with a sibling `images` folder, as shown in the Scanning example above.

Open Visual Studio Code Settings and search for **Paste Image**.

Set the fields as follows.

### Base Path

```text
${currentFileDir}
```

### Default Name

```text
${currentFileNameWithoutExt}_Y-MM-DD-HH-mm-ss
```

This creates a useful fallback filename based on the Markdown document being edited.

### Encode Path

```text
none
```

Use filenames without spaces instead of relying on URL encoding.

### File Path Confirm Input Box Mode

```text
onlyName
```

This makes the paste dialog show only the filename so it is easy to replace the generated name with a descriptive name.

### Force Unix Style Separator

```text
ON
```

Markdown paths should use `/` separators even when editing on Windows.

### Insert Pattern

```text
<img src="${imageFilePath}" alt="${imageFileNameWithoutExt}" width="600">
```

This automatically inserts:

- the correct relative image path;
- starter alternative text based on the filename; and
- a default display width of 600 pixels.

The alternative text should still be improved manually when the filename is not a good description of what the image shows.

### Name Prefix

Leave blank.

### Name Suffix

Leave blank.

### Path

```text
${currentFileDir}/images
```

This saves the screenshot into the subsystem's sibling `images` folder.

### Prefix

Leave blank.

### Show File Path Confirm Input Box

```text
ON
```

This is important because it gives the contributor a chance to replace the generated filename before the image is saved.

### Suffix

Leave blank.

---

## Normal Paste Image Workflow

1. Capture the part of the screen you need using **Windows + Shift + S** or another screenshot tool.
2. Open the Markdown file in Visual Studio Code.
3. Put the cursor on the line where the image belongs.
4. Make sure no unrelated text is selected.
5. Press **Ctrl+Alt+V**.
6. Replace the generated filename with a descriptive filename such as:

```text
Scan_Home_Page.png
```

7. Press **Enter**.
8. Save the Markdown document.
9. Open Markdown Preview and verify the image displays correctly.

A successful paste in the Scanning subsystem should create:

```text
Scanning/images/Scan_Home_Page.png
```

and insert markup similar to:

```html
<img src="images/Scan_Home_Page.png" alt="Scan_Home_Page" width="600">
```

---

## Important Paste Image Behaviors

### Selected text can become the filename

Paste Image can use currently selected editor text as the image filename or path.

Before pressing **Ctrl+Alt+V**, make sure you have not accidentally selected Markdown syntax or unrelated text.

If selected text contains characters such as `![](`, path fragments, or other Markdown syntax, the generated image link can become malformed.

### Confirm the resolved save path when troubleshooting

If an image is not being saved where expected, temporarily change:

```text
File Path Confirm Input Box Mode
```

to:

```text
fullPath
```

The paste dialog will then show the full physical destination before saving.

For the Scanning example, the destination should end with something like:

```text
...\Scanning\images\Image_Name.png
```

After confirming the path is correct, change the mode back to:

```text
onlyName
```

### Markdown Preview may cache an replaced image

If an existing image file is replaced using the same filename, Visual Studio Code Markdown Preview may continue displaying the previous image for a short time.

If the source file is correct but Preview still shows the old image:

1. use the Preview refresh button;
2. close and reopen the Preview tab; or
3. run **Developer: Reload Window** from the Command Palette.

Do not assume the image file itself is wrong until the Preview cache has been refreshed.

---

# Markdown Preview Shortcuts

Visual Studio Code includes Markdown Preview without installing another extension.

Use:

```text
Ctrl+Shift+V
```

to open the rendered Markdown preview.

Use:

```text
Ctrl+K, V
```

to open the preview beside the Markdown editor.

Preview the document before submitting changes, especially after adding or replacing images.

---

# Markdown PDF

**Markdown PDF** is also used by some MSB contributors to create PDF copies from Markdown documents.

The MSB-specific recommended configuration and publishing rules for Markdown PDF have **not yet been standardized in this contributor guide**.

Do not treat a locally generated PDF as the authoritative editable document. The Markdown source remains the controlled source unless the responsible subsystem explicitly defines a published PDF workflow.

Once the current Markdown PDF settings and intended document classes are reviewed, they should be added to this page as a second tested extension configuration.

---

# Adding More Extensions to This Guide

Do not add an extension here only because it looks useful in the Visual Studio Code Marketplace.

Before recommending it to MSB contributors:

1. test it against the current MSB repository structure;
2. record the exact settings that contributors should use;
3. verify that its output works in GitHub and Visual Studio Code Preview;
4. verify that it does not create duplicate source documents or place files in obsolete folders; and
5. document any behavior that could surprise a contributor.

This keeps contributor setup repeatable and prevents every volunteer from having to rediscover the same configuration.

---

[← Previous: Glossary](15_Glossary.md) | [Back to Contributor Training](README.md)
