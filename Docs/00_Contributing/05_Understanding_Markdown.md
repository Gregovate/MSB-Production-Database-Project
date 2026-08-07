# 05 — Understanding Markdown

[← Previous: Open and Find MSB Documents](04_Open_and_Find_MSB_Documents.md) | [Back to Contributor Training](README.md) | [Next: Edit and Preview a Document →](06_Edit_and_Preview_a_Document.md)

---

## Before You Begin

Before starting this section, you should have completed:

* [01 — Install Visual Studio Code and Git](01_Install_VSCode_and_Git.md)
* [02 — Create a GitHub Account and Get Access](02_Create_GitHub_Account_and_Get_Access.md)
* [03 — Get the MSB Documentation on Your Computer](03_Get_MSB_Documentation_on_Your_Computer.md)
* [04 — Open and Find MSB Documents](04_Open_and_Find_MSB_Documents.md)

You should also have a Markdown document open in Visual Studio Code.

---

# What Is Markdown?

Markdown is a simple way to write documents using plain text.

Instead of clicking buttons to make text bold or create headings, you type a few simple symbols.

For example, instead of selecting text and clicking the **Bold** button, you type:

```markdown
**This text will appear bold**
```

When the document is viewed, it appears as:

**This text will appear bold**

---

# Why Does MSB Use Markdown?

Markdown has several advantages for documentation:

* Documents are easy to read.
* Documents are easy to edit.
* Changes are easy to compare.
* Git can clearly show what changed.
* The files are small and can be used on many different computers.

Markdown is one of the most common formats used for technical documentation.

---

# Don't Worry

The good news is that you only need to learn a small part of Markdown.

Most MSB documentation uses the same formatting over and over.

You do **not** need to memorize every Markdown feature.

---

# Headings

Headings organize a document into sections.

A single number sign creates a main heading.

```markdown
# Main Heading
```

Two number signs create a second-level heading.

```markdown
## Section Heading
```

Three number signs create a subsection.

```markdown
### Subsection
```

Example:

```markdown
# Wiring Procedure

## Before You Begin

### Required Tools
```

---

# Blank Lines Matter

Leave one blank line between paragraphs.

Example:

```markdown
This is the first paragraph.

This is the second paragraph.
```

Without the blank line, Markdown may combine the text into one paragraph.

---

# Bold Text

Use bold text for important information.

Type two asterisks before and after the text.

```markdown
**Important**
```

Result:

**Important**

---

# Italic Text

Use one asterisk before and after the text.

```markdown
*Example*
```

Result:

*Example*

Italic text is used less often in MSB documentation than bold text.

---

# Bullet Lists

Bulleted lists are very common.

Type a dash followed by a space.

Example:

```markdown
- First item
- Second item
- Third item
```

Result:

* First item
* Second item
* Third item

---

# Numbered Lists

Numbered lists are useful for procedures.

Example:

```markdown
1. Open VS Code.
2. Open the document.
3. Make your changes.
4. Save the file.
```

Result:

1. Open VS Code.
2. Open the document.
3. Save the file.

Markdown automatically adjusts the numbering if items are inserted or removed.

---

# Code Blocks

Sometimes we want text to appear exactly as typed.

For example:

* File names
* Folder names
* Commands
* Settings

Use three backticks before and after the text.

Example:

````markdown
```
Docs
    01_LOR_System
        01_Preview_Authoring
```
````

Result:

```
Docs
    01_LOR_System
        01_Preview_Authoring
```

---

# Inline Code

Short filenames and commands are often shown using backticks.

Example:

```markdown
README.md
```

Result:

`README.md`

Examples:

`README.md`

`Ctrl+S`

`Docs`

---

# Links to Other Documents

Markdown can create links between documents.

Example:

```markdown
[Open the Contributor Guide](README.md)
```

Result:

[Open the Contributor Guide](README.md)

Relative links like this continue to work even when the project is moved to another computer.

---

# Horizontal Lines

A horizontal line separates major sections.

Type three dashes.

```markdown
---
```

Result:

---

Many MSB documents use horizontal lines between major topics.

---

# Tables

Simple tables can also be created.

Example:

```markdown
| Document | Purpose |
|----------|---------|
| README.md | Folder introduction |
| 05_Understanding_Markdown.md | Markdown training |
```

Result:

| Document                     | Purpose             |
| ---------------------------- | ------------------- |
| README.md                    | Folder introduction |
| 05_Understanding_Markdown.md | Markdown training   |

You do not need to create tables manually very often.

Most existing tables can simply be edited.

---

# Comments

Unlike Microsoft Word comments, Markdown does not have built-in review comments.

Discussion normally happens during the GitHub review process.

Avoid adding notes such as:

```text
TODO
FIX THIS
COME BACK LATER
```

unless they are intended to remain part of the documentation.

---

# The Preview Window

One of the best features of VS Code is the Markdown Preview.

Instead of trying to imagine what the document will look like, VS Code can display the finished document.

To open the preview:

1. Open a Markdown document.
2. Click the **Open Preview** button near the upper-right corner of the editor.

You can also press:

```
Ctrl + Shift + V
```

The preview updates automatically as you edit the document.

---

# You Don't Need to Memorize Everything

Many contributors worry about remembering Markdown.

Don't.

Most of the time you will simply copy the formatting already used in nearby sections.

For example, if one heading looks like this:

```markdown
## Safety Information
```

and you need another heading, simply copy that line and change the words.

This is how most documentation authors work.

---

# A Good Editing Habit

Before changing formatting, look at the surrounding text.

If the rest of the document already uses a consistent style, continue using that same style.

Keeping documents consistent makes them easier to read.

---

# Common Beginner Mistakes

## Forgetting the Space After a Dash

Correct:

```markdown
- Item
```

Incorrect:

```markdown
-Item
```

---

## Forgetting a Blank Line

Markdown is easier to read when paragraphs are separated by blank lines.

---

## Changing Existing Formatting

If you are only correcting text, avoid changing the formatting unless it also needs improvement.

Keeping your edits focused makes them easier to review.

---

# Practice

Try the following in a new Markdown file.

```markdown
# My First Markdown Document

## Things I Learned

- VS Code edits Markdown files.
- Markdown is plain text.
- Git keeps track of changes.

**This is bold text.**

This is a normal paragraph.
```

Open the Preview window and compare the Markdown with the finished document.

---

# What You Have Learned

You now know the Markdown features used in most MSB documentation:

* Headings
* Bold text
* Italics
* Bullet lists
* Numbered lists
* Code blocks
* Inline code
* Links
* Tables
* Horizontal lines
* Preview

That is enough to edit nearly all MSB documentation.

You can always return to this guide later if you forget the syntax.

---

# Next Step

Now that you understand the basics of Markdown, you are ready to safely edit a document and preview the results before saving.

Continue with:

[06 — Edit and Preview a Document](06_Edit_and_Preview_a_Document.md)

---

[← Previous: Open and Find MSB Documents](04_Open_and_Find_MSB_Documents.md) | [Back to Contributor Training](README.md) | [Next: Edit and Preview a Document →](06_Edit_and_Preview_a_Document.md)
