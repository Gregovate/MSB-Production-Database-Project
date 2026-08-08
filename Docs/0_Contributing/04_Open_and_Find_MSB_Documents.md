# 04 — Open and Find MSB Documents

[← Previous: Get the MSB Documentation on Your Computer](03_Get_MSB_Documentation_on_Your_Computer.md) | [Back to Contributor Training](README.md) | [Next: Understanding Markdown →](05_Understanding_Markdown.md)

---

## Before You Begin

Before starting this section, you should have completed:

* [01 — Install Visual Studio Code and Git](01_Install_VSCode_and_Git.md)
* [02 — Create a GitHub Account and Get Access](02_Create_GitHub_Account_and_Get_Access.md)
* [03 — Get the MSB Documentation on Your Computer](03_Get_MSB_Documentation_on_Your_Computer.md)

You should also have the MSB project open in Visual Studio Code.

---

# What You Will Learn

In this section you will learn how to:

* Open the MSB project.
* Understand the folder layout.
* Find the document you want to edit.
* Open a document.
* Navigate between documents.
* Avoid making changes in the wrong location.

---

# The Explorer Window

Most of your time will be spent using the **Explorer** on the left side of the VS Code window.

If you have used Windows File Explorer, the Explorer in VS Code will feel very familiar.

It displays folders and files in a tree structure.

Folders can be expanded to show additional folders or files.

Files can be opened by clicking on them.

---

# Open the Explorer

If the Explorer is not already visible:

1. Click **View** on the top menu.
2. Select **Explorer**.

Or click the **Explorer** icon near the upper left side of the VS Code window.

The Explorer icon normally looks like two sheets of paper.

---

# Understanding the Folder Tree

When you open the MSB project, you should see the project name at the top of the Explorer.

Under the project name you will see folders.

One of the first folders is:

```text
Docs
```

Click the small arrow next to **Docs** to expand it.

---

# The Documentation Folder Structure

The MSB documentation is organized into folders by subject.

You may see folders similar to:

```text
Docs

├── 00_Contributing
├── 01_LOR_System
├── 02_Server_Management
├── 03_Directus
├── 04_PostgreSQL
└── ...
```

Additional folders may be added as the project grows.

Each folder contains documents related to that topic.

---

# Folder Numbering

Folders begin with numbers.

For example:

```text
00_Contributing
01_LOR_System
```

The numbers keep folders in a logical order.

Do not rename folders simply to change their order.

---

# Finding the LOR Preview Authoring Documents

Expand the folders in this order:

```text
Docs

↓

01_LOR_System

↓

01_Preview_Authoring
```

The complete folder path is:

```text
Docs/01_LOR_System/01_Preview_Authoring
```

This folder contains the procedures used to create and maintain LOR preview documentation.

---

# Opening a Document

To open a document:

1. Find the file in the Explorer.
2. Double-click the file.

The document opens in the main editing area.

You may have several documents open at the same time.

Each document appears as a tab across the top of the editing window.

---

# Switching Between Documents

Click a document tab to make it active.

You can switch between documents at any time.

Only the active document can be edited.

---

# Closing a Document

To close a document:

Click the **X** on its tab.

Closing a document does **not** delete it.

It simply closes that tab.

---

# Opening Another Document

You can open another document at any time by clicking it in the Explorer.

There is no need to close the first document before opening another one.

---

# Understanding File Names

Most documentation files end with:

```text
.md
```

The **.md** extension means the file is a Markdown document.

You will learn about Markdown in the next lesson.

---

# README.md Files

Many folders contain a file named:

```text
README.md
```

A README is usually the starting point for that folder.

It often explains:

* What the folder contains.
* How the documents are organized.
* Which document should be read first.

When entering a new documentation area, it is usually a good idea to read the README first.

---

# Expanding and Collapsing Folders

You do not need every folder expanded all the time.

Click the small arrow next to a folder to:

* Expand it.
* Collapse it again.

Keeping unrelated folders collapsed makes the Explorer easier to navigate.

---

# Searching for a Document

As the documentation grows, finding a document by browsing folders may take longer.

VS Code provides a quick search.

Press:

```text
Ctrl + P
```

Begin typing part of the document name.

VS Code will display matching files.

Select the correct document to open it.

This is often the fastest way to locate a document.

---

# Finding Text Inside a Document

To search inside the document you currently have open:

Press:

```text
Ctrl + F
```

Type the word or phrase you want to find.

VS Code highlights each matching location.

---

# Finding Text Across All Documents

Sometimes you know a word or phrase but do not know which document contains it.

Press:

```text
Ctrl + Shift + F
```

Enter the search text.

VS Code searches every document in the project and lists the results.

This is very useful when working with a large documentation library.

---

# Avoid Renaming Files

Unless you have been specifically instructed to do so:

Do **not** rename documentation files.

Changing a filename may break links from other documents.

If you believe a document should be renamed, discuss it with the project administrator first.

---

# Avoid Moving Files

Likewise, avoid dragging files into different folders unless instructed.

Moving a document changes its location and may break links from other documentation.

---

# The Most Common Mistake

New contributors sometimes open the wrong document because two files have similar names.

Before making changes, always check:

* The folder location.
* The document title.
* The filename shown on the tab.

Taking a few seconds to verify the correct document can prevent accidental edits.

---

# What You Have Learned

You should now know how to:

* Navigate the MSB documentation folders.
* Expand and collapse folders.
* Open documents.
* Close documents.
* Switch between documents.
* Search for documents.
* Search inside documents.
* Search across the project.

These are the basic navigation skills you will use every time you work with the MSB documentation.

---

# Next Step

You are now ready to learn the small amount of Markdown needed to edit MSB documentation.

Continue with:

[05 — Understanding Markdown](05_Understanding_Markdown.md)

---

[← Previous: Get the MSB Documentation on Your Computer](03_Get_MSB_Documentation_on_Your_Computer.md) | [Back to Contributor Training](README.md) | [Next: Understanding Markdown →](05_Understanding_Markdown.md)
