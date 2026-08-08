# 06 — Edit and Preview a Document

[← Previous: Understanding Markdown](05_Understanding_Markdown.md) | [Back to Contributor Training](README.md) | [Next: Save and Review Your Changes →](07_Save_and_Review_Your_Changes.md)

---

## Before You Begin

Before starting this section, you should have completed:

* [01 — Install Visual Studio Code and Git](01_Install_VSCode_and_Git.md)
* [02 — Create a GitHub Account and Get Access](02_Create_GitHub_Account_and_Get_Access.md)
* [03 — Get the MSB Documentation on Your Computer](03_Get_MSB_Documentation_on_Your_Computer.md)
* [04 — Open and Find MSB Documents](04_Open_and_Find_MSB_Documents.md)
* [05 — Understanding Markdown](05_Understanding_Markdown.md)

You should have the MSB project open in Visual Studio Code.

---

# What You Will Learn

In this lesson you will learn how to:

* Open a document for editing.
* Make changes safely.
* Save your work.
* Preview the finished document.
* Check your work before submitting it.

The goal is to make your changes look like they have always been part of the document.

---

# Step 1 — Open the Document

Using the Explorer, browse to the document you want to edit.

Double-click the document.

The document will open in the editor.

The filename will appear on a tab near the top of the VS Code window.

Before making changes, verify that you opened the correct document.

---

# Step 2 — Read Before You Edit

Avoid making changes immediately.

Instead:

* Read the surrounding section.
* Understand what the document is explaining.
* Look at how headings, lists, and notes are formatted.

Most MSB documents already follow a consistent style.

Your goal is to continue using that style.

---

# Step 3 — Place the Cursor

Click where you want to make your change.

The flashing cursor shows where new text will be inserted.

If you need to replace existing text:

1. Select the text.
2. Type the replacement.

---

# Step 4 — Type Normally

Markdown files are plain text.

Simply begin typing.

For example:

```markdown
The display must be tested before installation.
```

You do not need to switch into a special editing mode.

---

# Step 5 — Save Your Work

Save frequently.

Choose one of the following:

* **File → Save**
* Press **Ctrl + S**

Saving only writes the changes to your copy of the project.

Nothing has been sent to GitHub yet.

Nothing has been reviewed yet.

Nothing has become official documentation yet.

---

# Understanding Save

Many new contributors worry that pressing **Save** will immediately update the official documentation.

It does not.

Saving only updates the copy on **your own computer**.

Later, you will decide whether to submit those changes for review.

---

# Step 6 — Open the Preview

The Preview window allows you to see how the finished document will look.

There are two common ways to open it.

### Option 1

Click the **Open Preview** button near the upper-right corner of the editor.

### Option 2

Press:

```text
Ctrl + Shift + V
```

The preview normally opens beside the editor.

---

# Editing and Previewing Together

Many contributors prefer to keep both windows visible.

For example:

```text
+----------------------+----------------------+
|                      |                      |
| Markdown             | Document Preview     |
|                      |                      |
| You edit here        | You review here      |
|                      |                      |
+----------------------+----------------------+
```

As you type, the preview automatically updates.

This allows you to immediately see the results of your changes.

---

# Check Your Formatting

Read the preview carefully.

Ask yourself:

* Do the headings look correct?
* Are the bullet lists aligned properly?
* Does the spacing look correct?
* Are bold words actually bold?
* Do links appear correctly?

Small formatting mistakes are often much easier to notice in the preview than in the Markdown text.

---

# Correct Any Problems

If something doesn't look right:

1. Return to the editor.
2. Correct the Markdown.
3. Save the file.
4. Check the preview again.

Repeat until you are satisfied with the result.

---

# Editing Existing Lists

If you are adding another item to a bulleted list, follow the style already being used.

Example:

```markdown
- First item
- Second item
- Third item
```

Avoid changing the formatting of existing list items unless there is a reason.

---

# Editing Procedures

Many MSB documents contain numbered procedures.

Example:

```markdown
1. Turn on the controller.
2. Verify power.
3. Continue to the next step.
```

If you insert a new step, simply continue the numbering.

Markdown automatically displays the list correctly.

---

# Editing Tables

Tables require a little more attention.

When editing a table:

* Do not remove the separator line.
* Keep information in the correct columns.
* Preview the document afterward.

If the table looks wrong in the preview, it usually means one row has too many or too few column separators.

---

# Editing Links

Links often look like this:

```markdown
[Contributor Guide](README.md)
```

Normally you only need to change the displayed text.

Avoid changing the filename unless the target document has also changed.

Broken links make navigation difficult.

---

# Adding New Sections

When adding a new section:

Use the same heading style already used in the document.

For example:

```markdown
## New Procedure
```

Do not invent a different heading style.

Consistency is important.

---

# Adding Images

Some documents contain screenshots.

If you need to add a new image:

* Place the image in the correct Images folder.
* Follow the naming style already used in the project.
* Update the document to reference the new image.

If you are unsure where images belong, ask before adding them.

---

# Avoid Large Unrelated Changes

Suppose you opened a document to correct one spelling mistake.

While reading, you notice five other things that could also be improved.

Instead of changing everything at once:

Complete one logical improvement.

Large unrelated edits make the review process much more difficult.

Small focused changes are easier to review and approve.

---

# Avoid Changing Document Style

If a document consistently uses:

* One heading style
* One note style
* One list style

Continue using that style.

Do not redesign the document simply because you prefer a different appearance.

The goal is consistency across the entire documentation library.

---

# If You Make a Mistake

Don't panic.

Mistakes are expected.

You have not damaged the official documentation.

At this point:

* Your changes exist only on your computer.
* Nothing has been submitted.
* Nothing has been reviewed.

Most mistakes can be corrected simply by editing the document again.

---

# Before Leaving the Document

Before moving to another task, make sure:

* The document has been saved.
* The preview looks correct.
* There are no obvious formatting problems.
* The document still reads naturally.

Taking one extra minute now often prevents review comments later.

---

# What You Have Learned

You now know how to:

* Open a document.
* Edit text.
* Save your work.
* Preview the finished document.
* Correct formatting problems.
* Work safely without affecting the official documentation.

These are the editing skills you will use every time you contribute to the MSB documentation.

---

# Next Step

Your changes are now saved on your computer.

The next lesson explains how to see exactly what changed before submitting your work for review.

Continue with:

[07 — Save and Review Your Changes](07_Save_and_Review_Your_Changes.md)

---

[← Previous: Understanding Markdown](05_Understanding_Markdown.md) | [Back to Contributor Training](README.md) | [Next: Save and Review Your Changes →](07_Save_and_Review_Your_Changes.md)
