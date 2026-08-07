# 07 — Save and Review Your Changes

[← Previous: Edit and Preview a Document](06_Edit_and_Preview_a_Document.md) | [Back to Contributor Training](README.md) | [Next: Submit Changes for Review →](08_Submit_Changes_for_Review.md)

---

## Before You Begin

Before starting this section, you should have completed:

* [01 — Install Visual Studio Code and Git](01_Install_VSCode_and_Git.md)
* [02 — Create a GitHub Account and Get Access](02_Create_GitHub_Account_and_Get_Access.md)
* [03 — Get the MSB Documentation on Your Computer](03_Get_MSB_Documentation_on_Your_Computer.md)
* [04 — Open and Find MSB Documents](04_Open_and_Find_MSB_Documents.md)
* [05 — Understanding Markdown](05_Understanding_Markdown.md)
* [06 — Edit and Preview a Document](06_Edit_and_Preview_a_Document.md)

You should have made at least one small change to a document and saved it.

---

# What You Will Learn

In this lesson you will learn how to:

* Verify your document has been saved.
* See exactly what you changed.
* Review your work before sending it for approval.
* Correct mistakes before anyone else sees them.

One of the greatest advantages of Git is that it clearly shows your changes before they are submitted.

---

# Saving Is Not the Same as Submitting

Remember:

When you press **Ctrl + S**, you are only saving the file on **your own computer**.

You are **not**:

* Updating GitHub.
* Changing the official documentation.
* Sending anything to another person.

Think of Save exactly like saving a Microsoft Word document.

---

# How VS Code Shows Unsaved Changes

If you change a document but have **not** saved it yet, VS Code usually displays a small white dot on the document tab.

Example:

```text
README.md ●
```

This indicates there are unsaved changes.

---

# Save the Document

Save your document before reviewing it.

You can:

* Press **Ctrl + S**

or

* Choose **File → Save**

The white dot should disappear.

This confirms the file has been saved.

---

# Opening Source Control

Now you are ready to review your work.

Look at the left side of VS Code.

Click the **Source Control** icon.

It usually looks like three connected circles.

The Source Control window will open.

---

# What You Will See

If you changed one document, you may see something similar to:

```text
Changes

README.md
```

If you changed several documents, each document will appear in the list.

Only the documents you changed will be listed.

---

# This Is Normal

Many first-time users become concerned when they see a list of changed files.

Don't worry.

VS Code is simply telling you:

> "These are the files that are different from the official version."

Nothing has been sent to GitHub yet.

---

# View Your Changes

Click one of the changed files.

VS Code opens a comparison view.

You will see:

* The original version.
* Your edited version.

The changed lines are highlighted.

This allows you to quickly verify exactly what changed.

---

# Understanding the Comparison View

The comparison window may look something like this:

```text
Original                      Your Version

Replace "Display"        →     "Display Name"

Old sentence             →     New sentence

(blank)                  →     New paragraph
```

You are looking at a comparison between:

The original document

and

Your edited document.

---

# Why Review Your Changes?

Before asking someone else to review your work, review it yourself.

Ask questions such as:

* Did I edit the correct document?
* Did I accidentally delete anything?
* Are there spelling mistakes?
* Does the wording make sense?
* Is the formatting still correct?

Many simple mistakes are caught during this step.

---

# Small Changes Are Easier to Review

A reviewer can usually approve:

* One spelling correction.
* One paragraph improvement.
* One procedure update.

much more quickly than:

* Twenty unrelated edits across multiple documents.

Whenever practical, keep each submission focused on one topic.

---

# If You Find a Mistake

If you notice something that needs correction:

1. Close the comparison view.
2. Return to the document.
3. Make the correction.
4. Save the document.
5. Return to Source Control.

The comparison automatically updates.

---

# If You Decide You Don't Want a Change

Sometimes you make a change and later decide it was not an improvement.

That is perfectly normal.

Do not try to fix it by making several more edits.

Instead, restore the document to the official version.

The exact process for restoring a file may vary slightly between versions of VS Code.

If you are unsure, ask before discarding changes.

---

# A Good Habit

Before submitting any document:

Read the document from beginning to end.

Reading continuously often reveals problems that are easy to miss while editing individual sentences.

---

# Watch for Accidental Formatting Changes

Sometimes a single extra character can change formatting.

Examples include:

* Missing blank lines.
* Missing heading symbols (#).
* Missing list markers (-).
* Missing closing ** symbols.

Always compare the Preview with the original document if something looks unusual.

---

# Check Your Links

If you added or changed links:

Click them in the Preview window.

Make sure they open the correct document.

Broken links make documentation difficult to navigate.

---

# Check Lists

Look carefully at:

* Numbered procedures.
* Bullet lists.
* Tables.

These areas are where formatting mistakes most commonly occur.

---

# Ask Yourself Three Questions

Before submitting your work, ask:

## 1. Is the information correct?

Have I verified that what I wrote is accurate?

---

## 2. Is the formatting consistent?

Does my new section match the rest of the document?

---

## 3. Is this ready for another person to review?

If the answer is "No," continue improving the document before submitting it.

---

# Don't Worry About Perfection

The review process exists because nobody catches every mistake.

The goal is to submit your best work.

Another reviewer may still suggest improvements.

That is a normal part of the documentation process.

---

# What You Have Learned

You now know how to:

* Save your work.
* Open Source Control.
* See exactly what changed.
* Compare your work with the original document.
* Correct mistakes before submission.
* Prepare your work for review.

This review step is one of the most valuable parts of using Git and GitHub.

---

# Next Step

Your work has been saved and reviewed.

The next lesson explains how to submit your changes so they can be reviewed and approved before becoming part of the official MSB documentation.

Continue with:

[08 — Submit Changes for Review](08_Submit_Changes_for_Review.md)

---

[← Previous: Edit and Preview a Document](06_Edit_and_Preview_a_Document.md) | [Back to Contributor Training](README.md) | [Next: Submit Changes for Review →](08_Submit_Changes_for_Review.md)
