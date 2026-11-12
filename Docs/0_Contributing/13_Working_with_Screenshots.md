# 13 — Working with Screenshots

[← Previous: Common Problems and How to Fix Them](12_Common_Problems_and_How_to_Fix_Them.md) | [Back to Contributor Training](README.md)

---

# Introduction

Many MSB procedures include screenshots to help explain each step.

A good screenshot is often easier to understand than several paragraphs of text.

This guide explains how screenshots are stored, named, referenced, previewed, and replaced in the current MSB documentation structure.

For the tested Visual Studio Code extension that can automate screenshot saving and insertion, see:

[16 — Recommended VS Code Extensions](16_Recommended_VSCode_Extensions.md)

---

# Where Screenshots Are Stored

The MSB documentation no longer assumes one global image folder for every subsystem.

Converted documentation subsystems own their repository documentation images in a local `images` folder.

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

Use the image folder owned by the subsystem you are editing.

Do **not** place new images into the older shared `Docs/images/` folder merely because older documentation still references it. Some legacy documentation has not yet been converted, and its existing image references should remain intact until that subsystem is deliberately reviewed.

---

# Why Images Are Owned by the Subsystem

Keeping documentation images with the subsystem that uses them makes ownership clear and keeps future documentation moves safer.

This helps contributors understand:

* which documentation owns the image;
* which images should move if a subsystem is reorganized;
* which images are current versus legacy; and
* which image paths must be preserved when documentation is published through another presentation system.

Do not duplicate the same image into several subsystem folders unless there is a documented reason for each subsystem to own its own copy.

---

# Supported Image Formats

For most documentation screenshots, use:

* PNG (`.png`)

PNG provides excellent quality for user-interface screenshots and diagrams.

JPEG (`.jpg`) may be used for photographs when appropriate.

Avoid using screenshots saved as:

* BMP
* TIFF

---

# Taking a Screenshot

A simple Windows method is:

1. Press **Windows + Shift + S**.
2. Select only the area needed for the procedure.
3. Copy the captured image to the clipboard.
4. Save or paste the image into the subsystem-owned `images` folder.

Crop the screenshot so it shows the information the contributor or operator needs without unnecessary browser chrome, desktop background, or unrelated application content.

---

# What Makes a Good Screenshot?

A good screenshot should:

* show only the important part of the screen;
* be easy to read;
* have a reasonable display size;
* avoid unnecessary desktop background or unrelated browser tabs; and
* avoid personal or confidential information.

Before adding a screenshot, check for:

* passwords;
* private account information;
* personal email or contact information that is not intended for documentation;
* unrelated browser tabs;
* confidential project information; and
* other material that should not become part of the repository.

---

# Naming Images

Use descriptive filenames.

Good examples:

```text
Scan_Home_Page.png
vscode-open-folder.png
vscode-source-control.png
preview-authoring-folder.png
directus-login-screen.png
```

Poor examples:

```text
image1.png
picture.png
new.png
screenshot.png
copy.png
```

Someone should be able to understand approximately what an image contains by reading its filename.

Avoid spaces and special characters in image filenames.

---

# Referencing an Image

If the Markdown file and the `images` folder are in the same subsystem folder, a standard Markdown image reference is:

```markdown
![MSB Scan home page](images/Scan_Home_Page.png)
```

The text inside the square brackets is **alternative text**. It should briefly describe what the image shows.

Alternative text is useful for accessibility and remains useful if the image cannot be displayed.

---

# Controlling Display Size

Plain Markdown does not provide a consistent standard for image width across all renderers.

When a screenshot needs a controlled display width, MSB documentation may use an HTML image element inside the Markdown document.

Example:

```html
<img src="images/Scan_Home_Page.png" alt="MSB Scan home page" width="600">
```

This keeps the original PNG at full quality while controlling how large it appears in the rendered document.

The tested Paste Image configuration in [16 — Recommended VS Code Extensions](16_Recommended_VSCode_Extensions.md) can insert this pattern automatically so contributors do not have to type it manually for every screenshot.

---

# Understanding Relative Paths

Image references are relative to the Markdown file that contains them.

For this structure:

```text
Scanning/
├── images/
│   └── Scan_Home_Page.png
└── Use_Scan_Manually.md
```

the image path is:

```text
images/Scan_Home_Page.png
```

If a Markdown file is in a nested folder, the correct relative path may be different.

Do not guess. Preview the document and verify the image displays correctly.

---

# Previewing the Document

Visual Studio Code includes Markdown Preview.

With the Markdown file open, use:

```text
Ctrl+Shift+V
```

to open the preview.

Use:

```text
Ctrl+K, V
```

to open the preview beside the editor.

After adding or replacing an image:

1. save the Markdown document;
2. open or refresh Markdown Preview; and
3. verify the image displays at the expected size.

---

# Replacing an Existing Image

If a screenshot is being updated for the same screen or feature, it is often appropriate to replace the existing image using the same filename.

That allows every current document referencing that image to continue using the same path.

Only replace an image when the new image represents the same documented screen or purpose.

If the screenshot represents a different feature, create a new descriptive filename instead.

---

# Important: Markdown Preview Can Show a Cached Image

When an image file is replaced using the same filename, Visual Studio Code Markdown Preview may continue displaying the previous image temporarily.

If the image file itself is correct but Preview still shows an older version:

1. click the Preview refresh button;
2. close and reopen the Preview tab; or
3. open the Command Palette and run:

```text
Developer: Reload Window
```

Do not create another image file or rename a correct image merely because Preview has not refreshed yet.

---

# Using Paste Image

MSB has tested the Visual Studio Code **Paste Image** extension as a way to automate screenshot placement and markup.

With the recommended settings, the contributor can:

1. capture a screenshot to the clipboard;
2. place the cursor in the Markdown document;
3. press **Ctrl+Alt+V**;
4. enter a descriptive filename; and
5. let the extension save the image and insert the image markup automatically.

The current tested settings are documented in:

[16 — Recommended VS Code Extensions](16_Recommended_VSCode_Extensions.md)

One important behavior: Paste Image can use selected editor text as part of the image filename or path. Make sure unrelated text is not selected before pasting an image.

---

# Annotating Images

Sometimes it helps to draw attention to a button or menu.

Simple annotations such as:

* arrows;
* circles; and
* rectangles

may be added when they improve clarity.

Avoid excessive colors or large blocks of text inside the screenshot.

The written procedure should explain the task. The screenshot should support that explanation.

---

# Before Submitting

Before submitting documentation containing new or changed screenshots, verify:

* the image is stored in the image folder owned by the subsystem;
* the filename is descriptive;
* the image displays correctly in Markdown Preview;
* the displayed image is not unnecessarily large;
* the alternative text describes the image;
* no personal or confidential information appears in the screenshot; and
* the image clearly supports the procedure.

---

# What You Have Learned

You now know how to:

* capture screenshots;
* determine the correct subsystem-owned image location;
* name screenshots;
* reference screenshots in Markdown;
* control screenshot display size when needed;
* preview images in Visual Studio Code;
* replace outdated screenshots; and
* recognize and clear a stale Markdown Preview image cache.

Following these guidelines helps keep MSB documentation consistent, portable, and easier to maintain.

---

[← Previous: Common Problems and How to Fix Them](12_Common_Problems_and_How_to_Fix_Them.md) | [Back to Contributor Training](README.md)
