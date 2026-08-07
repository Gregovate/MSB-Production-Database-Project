# 13 — Working with Screenshots

[← Previous: Common Problems and How to Fix Them](12_Common_Problems_and_How_to_Fix_Them.md) | [Back to Contributor Training](README.md)

---

# Introduction

Many MSB procedures include screenshots to help explain each step.

A good screenshot is often easier to understand than several paragraphs of text.

This guide explains how screenshots are used throughout the MSB Documentation Project.

---

# Where Screenshots Are Stored

All screenshots and graphics used by the documentation are stored in one shared folder.

```text
Docs/
└── images/
```

There is only one **images** folder for the entire documentation project.

Do **not** create additional Images folders inside other documentation folders unless instructed by the project administrator.

---

# Why We Use One Images Folder

Using one shared image folder provides several advantages.

* Images are easier to locate.
* Duplicate copies are avoided.
* Updating an image automatically updates every document that uses it.
* The project stays organized.

---

# Supported Image Formats

For most documentation, use:

* PNG (.png)

PNG provides excellent quality for screenshots and diagrams.

Avoid using screenshots saved as:

* BMP
* TIFF

JPEG (.jpg) may be used for photographs if necessary.

---

# Taking a Screenshot

Windows provides several ways to capture a screenshot.

One simple method is:

1. Press **Windows + Shift + S**
2. Select the area you want to capture.
3. Save the image.

Crop the image so that only the important information is shown.

Large screenshots containing unnecessary information make documents harder to read.

---

# What Makes a Good Screenshot?

A good screenshot should:

* Show only the important part of the screen.
* Be easy to read.
* Have a reasonable size.
* Avoid unnecessary desktop background.
* Avoid personal information.

Before saving a screenshot, check for:

* Email addresses
* Passwords
* Personal information
* Private project information
* Browser tabs unrelated to the procedure

Remove or hide anything that should not become part of the documentation.

---

# Naming Images

Use descriptive filenames.

Good examples:

```text
github-sign-in-page.png

vscode-open-folder.png

vscode-source-control.png

vscode-markdown-preview.png

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

Someone should be able to understand what an image contains simply by reading its filename.

---

# File Naming Guidelines

Use:

* lowercase letters
* numbers when appropriate
* hyphens between words

Avoid:

* spaces
* special characters
* long filenames

---

# Saving the Image

Save every documentation screenshot into:

```text
Docs/images/
```

Do not store screenshots on your Desktop or inside unrelated folders.

---

# Referencing an Image

Markdown uses the following format:

```markdown
![Image Description](../images/example-image.png)
```

The text inside the square brackets is called **alternative text**.

It briefly describes the image.

Example:

```markdown
![Visual Studio Code Welcome Screen](../images/vscode-welcome-screen.png)
```

---

# Understanding Relative Paths

Markdown links images relative to the document's location.

Example:

If your document is located here:

```text
Docs/
└── 00_Contributing/
    └── 13_Working_with_Screenshots.md
```

and the image is located here:

```text
Docs/
└── images/
    └── vscode-source-control.png
```

the correct image reference is:

```markdown
![Source Control](../images/vscode-source-control.png)
```

The `..` means:

"Go up one folder."

---

# Documents in Other Folders

Some documents are located deeper in the project.

For example:

```text
Docs/
└── 01_LOR_System/
    └── 01_Preview_Authoring/
        └── procedure.md
```

To reach the shared images folder, the document must go up two folders.

The correct reference would be:

```markdown
![Preview Window](../../images/preview-window.png)
```

Always verify the relative path based on the location of the document.

---

# Testing the Image

After adding an image:

1. Save the document.
2. Open the Markdown Preview.
3. Verify the image appears correctly.

If you see only the alternative text, the image path is probably incorrect.

---

# Replacing an Existing Image

Sometimes software changes and an older screenshot becomes outdated.

If the new screenshot represents the same feature:

Replace the existing image rather than creating a second file with a different name.

This automatically updates every document that references that image.

Only replace an image if it represents the same screen or feature.

---

# Creating a New Image

If the screenshot represents a new feature or a completely different screen:

Create a new image with a descriptive filename.

Update only the documents that need the new image.

---

# Image Size

Avoid extremely large screenshots.

Crop unnecessary borders.

Focus attention on the controls being discussed.

Smaller, focused images are easier to read.

---

# Annotating Images

Sometimes it helps to draw attention to a button or menu.

Simple annotations such as:

* arrows
* circles
* rectangles

may be added.

Avoid excessive colors or large blocks of text on the image.

The document should explain the procedure.

The image should support the explanation.

---

# Before Submitting

Before submitting documentation containing new screenshots, verify:

* The image is stored in `Docs/images`.
* The filename is descriptive.
* The image displays correctly.
* The Markdown Preview shows the image.
* No personal information appears in the screenshot.
* The image clearly supports the procedure.

---

# What You Have Learned

You now know how to:

* Capture screenshots.
* Name screenshots.
* Store screenshots.
* Reference screenshots in Markdown.
* Verify that screenshots display correctly.
* Replace outdated screenshots.

Following these guidelines helps keep the MSB Documentation Project consistent and easy to maintain.

---

[← Previous: Common Problems and How to Fix Them](12_Common_Problems_and_How_to_Fix_Them.md) | [Back to Contributor Training](README.md)
