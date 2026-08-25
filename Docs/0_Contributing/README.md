# MSB Documentation Contributor Training

Welcome to the MSB documentation contributor training.

This guide explains how to review and make changes to MSB procedure and training documents.

It is written for volunteers and other contributors who are comfortable using a Windows computer but have **no previous experience with GitHub, Git, Visual Studio Code, or Markdown**.

You do not need to be a programmer.

---

## What You Should Already Know

Before starting this training, you should be comfortable with basic computer tasks such as:

* Opening and browsing folders in Windows.
* Creating and finding files.
* Using email.
* Using Microsoft Word or Google Docs.
* Using Microsoft Excel, Google Sheets, or another spreadsheet program.

If you can do those things, you have the computer skills needed to follow this guide.

---

# What You Will Learn

The MSB documentation system works differently from editing a Word document stored on your computer.

Instead of creating separate copies of documents and emailing them to other people, we keep the official documents together in one controlled location.

You will learn how to:

1. Install the required software.
2. Create a GitHub account.
3. Get permission to access the MSB documentation.
4. Place a working copy of the MSB documentation on your computer.
5. Find the document you need.
6. Read and edit Markdown documents.
7. Preview a document before submitting it.
8. See exactly what you changed.
9. Submit your changes for review.
10. Respond if changes are requested.
11. Update your computer with newer documentation changes.

---

Complete the following lessons in order.

| Lesson | Description |
|---------|-------------|
| [01 — Install Visual Studio Code and Git](01_Install_Visual_Studio_Code_and_Git.md) | Install the required software used throughout the MSB Documentation Project. |
| [02 — Create a GitHub Account and Get Access](02_GitHub_Account.md) | Create a GitHub account and obtain permission to access the MSB documentation project. |
| [03 — Get the MSB Documentation on Your Computer](03_Get_MSB_Documentation_on_Your_Computer.md) | Download the MSB project to your computer and open it in Visual Studio Code. |
| [04 — Open and Find MSB Documents](04_Open_and_Find_MSB_Documents.md) | Learn how the documentation is organized and how to locate the document you want to edit. |
| [05 — Understanding Markdown](05_Understanding_Markdown.md) | Learn the basic Markdown formatting used throughout the MSB documentation. |
| [06 — Edit and Preview a Document](06_Edit_and_Preview_a_Document.md) | Edit documentation, preview your changes, and verify formatting before saving. |
| [07 — Save and Review Your Changes](07_Save_and_Review_Your_Changes.md) | Learn how to review your changes before submitting them for approval. |
| [08 — Submit Changes for Review](08_Submit_Changes_for_Review.md) | Submit your documentation changes using GitHub and the review process. |
| [09 — Update Your Copy Before Editing](09_Update_Your_Copy_Before_Editing.md) | Keep your local copy synchronized with the official MSB documentation. |
| [10 — Respond to Review Comments](10_Respond_to_Review_Comments.md) | Learn how to respond to review comments and update an existing Pull Request. |
| [11 — Markdown Quick Reference](11_Markdown_Quick_Reference.md) | A handy reference for the Markdown formatting used throughout the project. |
| [12 — Common Problems and How to Fix Them](12_Common_Problems_and_How_to_Fix_Them.md) | Solutions to the most common questions and problems encountered by new contributors. |
| [13 — Working with Screenshots](13_Working_with_Screenshots.md) | Learn how to capture, name, store, size, replace, and preview screenshots using subsystem-owned image folders. |
| [14 — Visual Reference Guide](14_Visual_Reference_Guide.md) | Screenshots and visual examples of the Visual Studio Code and GitHub interface used throughout this training. |
| [15 — Glossary](15_Glossary.md) | Definitions of common Git, GitHub, Visual Studio Code, and Markdown terms used in the MSB Documentation Project. |
| [16 — Recommended VS Code Extensions](16_Recommended_VSCode_Extensions.md) | Tested or commonly used VS Code extensions and their MSB-specific settings, starting with Paste Image. |

---

# Why We Use This System

A Word or Google Docs workflow works well when only a few people are editing a small number of documents.

The MSB documentation contains procedures that may be updated by several people over time.

We need to know:

* Which document is the current version.
* Who changed something.
* What was changed.
* Why it was changed.
* Whether a proposed change was reviewed.
* What the document looked like before the change.

The tools used in this guide provide that history automatically.

---

# The Four Parts of the System

You will hear four names throughout this training.

## Visual Studio Code

Usually called **VS Code**.

VS Code is the program you will use to open and edit the MSB documents.

For our purposes, think of it as the document editor.

---

## Markdown

Markdown is the format used for most MSB documentation.

Markdown files normally end with:

`.md`

A Markdown document contains normal text with a few simple symbols used for headings, lists, bold text, links, and similar formatting.

You will learn the small amount of Markdown needed for MSB documents later in this training.

---

## Git

Git keeps track of changes made to the files.

You will normally use Git through buttons and menus inside VS Code.

You are **not expected to learn Git command-line programming** to edit MSB documentation.

A useful comparison is the revision history or Track Changes feature you may have used in Word or Google Docs.

---

## GitHub

GitHub is the online location where the controlled copy of the MSB documentation is stored.

GitHub also provides the review process.

You can prepare a change without immediately changing the official document.

The change can be reviewed first.

Only approved changes are added to the official documentation.

---

# The Basic MSB Documentation Workflow

The normal process is:

**Get the latest documents**

↓

**Find the document you need**

↓

**Make your changes**

↓

**Preview the document**

↓

**Review what you changed**

↓

**Submit the changes**

↓

**The changes are reviewed**

↓

**Approved changes become part of the official documentation**

This may sound complicated the first time you read it.

Each part will be covered separately in this training.

---

# An Important Rule

## Do not maintain separate offline copies of MSB procedures.

Do not download a document, edit a separate copy somewhere else, and later try to determine which version is newest.

Work from the MSB documentation copy created using this training.

This helps prevent:

* Changes being made to an old document.
* Two people editing different copies.
* Changes being accidentally lost.
* Someone having to manually combine several versions of the same document.

---

# Documents You Will Be Editing

For LOR Preview Authoring documentation, the documents are located under:

`Docs/01_LOR_System/01_Preview_Authoring`

You do not need to memorize this location.

Later sections will show you exactly how to reach it from VS Code.

Other MSB documentation may be opened and edited using the same process after you have been given permission.

---

# Follow the Training in Order

The files in this folder are numbered so they appear in the order you should use them.

Start with:

[01 — Install Visual Studio Code and Git](01_Install_Visual_Studio_Code_and_Git.md)

Do not skip directly to the editing instructions during your first setup.

The first few sections prepare your computer and connect it to the MSB documentation system.

After the initial setup is complete, you will not need to repeat those installation steps each time you edit a document.

---

# If Something Does Not Match This Guide

Software screens occasionally change.

If a screen, button, or message is significantly different from what this guide shows, do not guess if you are unsure what to select.

Ask for assistance.

Especially avoid choosing options that mention:

* Force
* Delete
* Discard
* Reset
* Overwrite

until you understand what will happen.

The documentation system keeps a very good history, but it is still better to stop before accidentally removing work.
