# 08 — Submit Changes for Review

[← Previous: Save and Review Your Changes](07_Save_and_Review_Your_Changes.md) | [Back to Contributor Training](README.md) | [Next: Update Your Copy Before Editing →](09_Update_Your_Copy_Before_Editing.md)

---

## Before You Begin

Before starting this section, you should have completed:

* [01 — Install Visual Studio Code and Git](01_Install_VSCode_and_Git.md)
* [02 — Create a GitHub Account and Get Access](02_Create_GitHub_Account_and_Get_Access.md)
* [03 — Get the MSB Documentation on Your Computer](03_Get_MSB_Documentation_on_Your_Computer.md)
* [04 — Open and Find MSB Documents](04_Open_and_Find_MSB_Documentation.md)
* [05 — Understanding Markdown](05_Understanding_Markdown.md)
* [06 — Edit and Preview a Document](06_Edit_and_Preview_a_Document.md)
* [07 — Save and Review Your Changes](07_Save_and_Review_Your_Changes.md)

You should have reviewed your changes and be satisfied that they are ready for another person to review.

---

# What You Will Learn

In this lesson you will learn how to:

* Prepare your changes for submission.
* Write a useful description of your changes.
* Submit your work for review.
* Understand what happens after submission.

Submitting your work **does not immediately change the official MSB documentation**.

Every submission is reviewed before it becomes part of the project.

---

# The Review Process

The MSB documentation follows a review process.

Your changes follow this path:

```text
Edit Document

↓

Review Your Changes

↓

Submit for Review

↓

Reviewer Examines Changes

↓

Changes Approved
      or
Changes Returned for Correction

↓

Official Documentation Updated
```

The review process helps ensure that documentation remains accurate and consistent.

---

# What Is a Pull Request?

GitHub calls a submitted set of changes a **Pull Request**.

A Pull Request is simply a request asking:

> "Please review these changes and consider adding them to the official documentation."

Think of it as handing your edited document to another person for approval before it is published.

---

# Preparing to Submit

Before submitting your work:

* Save every document.
* Review every change.
* Verify the Preview looks correct.
* Make sure only the intended documents were modified.

If you accidentally changed an unrelated file, correct that before continuing.

---

# Open Source Control

In VS Code:

Click the **Source Control** icon.

You should see the list of changed files.

Review the list one more time.

If you see a file that you did not intend to change, investigate it before submitting your work.

---

# Stage Your Changes

Depending on the version of VS Code you are using, you may need to stage your changes.

If you see a **+** symbol next to a file:

Click the **+**.

This tells Git that you want to include that file in your submission.

Some versions of VS Code may automatically stage files.

If your screen looks different from the examples in this guide, that is normal.

---

# Write a Commit Message

Git requires a short description explaining what you changed.

This is called a **commit message**.

A good commit message is short and specific.

Examples:

```text
Correct wiring procedure spelling

Update Preview Authoring screenshots

Clarify stage numbering procedure

Fix broken document links
```

Avoid messages such as:

```text
Changes

Update

Fixed stuff

Miscellaneous
```

Someone reading the project history months from now should understand what was changed.

---

# Commit Your Changes

After entering the commit message:

Click **Commit**.

VS Code records the changes on your computer.

The commit becomes part of your local project history.

At this point, the changes are **still not part of the official MSB documentation**.

---

# Publish Your Changes

After committing, VS Code will normally display an option such as:

* Publish Branch
* Sync Changes
* Push
* Publish Changes

The wording may vary slightly depending on your version of VS Code.

Click the appropriate button.

VS Code uploads your committed changes to GitHub.

---

# Create the Pull Request

After publishing your branch, VS Code may offer to create a Pull Request.

If it does:

Click:

**Create Pull Request**

VS Code may open your web browser.

GitHub will display the Pull Request page.

---

# Complete the Pull Request

GitHub will ask for:

## Title

Use a short summary.

Example:

```text
Update Preview Authoring wiring documentation
```

---

## Description

Briefly explain:

* What was changed.
* Why it was changed.
* Anything the reviewer should pay special attention to.

Example:

```text
Updated the Preview Authoring procedure to clarify how stage numbers are assigned.

Corrected two screenshots that no longer matched the current version of LOR.

No procedure changes were made.
```

A few sentences are usually enough.

---

# Submit the Pull Request

Review the information.

When satisfied:

Click:

**Create Pull Request**

Your work is now waiting for review.

---

# Congratulations

At this point:

* Your work has been submitted.
* The reviewer has been notified.
* The official documentation has **not** changed yet.

Nothing more is required until the review is complete.

---

# What Happens Next?

The reviewer may:

* Approve your changes.
* Ask questions.
* Request corrections.
* Suggest improvements.

This is normal.

Nearly every contributor receives review comments from time to time.

The goal is to improve the documentation, not criticize the author.

---

# If Your Changes Are Approved

Once approved:

The reviewer will merge your Pull Request.

Your work becomes part of the official MSB documentation.

Congratulations!

---

# If Changes Are Requested

If the reviewer requests corrections:

Do not create a new Pull Request.

Instead:

* Make the requested changes.
* Save the document.
* Commit the new changes.
* Push them again.

GitHub automatically updates the existing Pull Request.

The reviewer will receive the updated version.

The next lesson explains this process in more detail.

---

# Good Commit Message Examples

| Good                             | Poor    |
| -------------------------------- | ------- |
| Correct Preview Authoring links  | Update  |
| Fix wiring table formatting      | Changes |
| Clarify display naming procedure | Stuff   |
| Add screenshots for installation | Misc    |

---

# A Few Best Practices

Before submitting:

* Keep each Pull Request focused on one subject.
* Make related changes together.
* Avoid mixing unrelated corrections.
* Double-check your spelling.
* Verify all links work.
* Preview the document one final time.

These small habits make reviews much faster.

---

# What You Have Learned

You now know how to:

* Prepare a submission.
* Write a useful commit message.
* Commit your work.
* Publish your changes.
* Create a Pull Request.
* Understand what happens during review.

You have completed the normal workflow used to contribute documentation to the MSB project.

---

# Next Step

Now that you know how to submit changes, the next lesson explains how to keep your copy of the documentation up to date before beginning new work.

Continue with:

[09 — Update Your Copy Before Editing](09_Update_Your_Copy_Before_Editing.md)

---

[← Previous: Save and Review Your Changes](07_Save_and_Review_Your_Changes.md) | [Back to Contributor Training](README.md) | [Next: Update Your Copy Before Editing →](09_Update_Your_Copy_Before_Editing.md)
