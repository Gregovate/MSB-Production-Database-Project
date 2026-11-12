# 11 — Markdown Quick Reference

[← Previous: Respond to Review Comments](10_Respond_to_Review_Comments.md) | [Back to Contributor Training](README.md) | [Next: Common Problems and How to Fix Them →](12_Common_Problems_and_How_to_Fix_Them.md)

---

# Introduction

This document is a quick reference for the Markdown formatting used throughout the MSB Documentation Project.

You do **not** need to memorize Markdown.

Most contributors simply copy the formatting already being used in the document they are editing.

Keep this page open whenever you need a reminder.

---

# Headings

Headings organize a document into sections.

| Markdown       | Result          |
| -------------- | --------------- |
| `# Heading`    | Main Heading    |
| `## Heading`   | Section Heading |
| `### Heading`  | Subsection      |
| `#### Heading` | Minor Heading   |

Example:

```markdown
# Main Heading

## Section Heading

### Subsection

#### Minor Heading
```

---

# Paragraphs

Leave one blank line between paragraphs.

Correct:

```markdown
This is the first paragraph.

This is the second paragraph.
```

Incorrect:

```markdown
This is the first paragraph.
This is the second paragraph.
```

---

# Bold Text

Use bold text to emphasize important information.

Markdown

```markdown
**Important**
```

Result

**Important**

---

# Italic Text

Markdown

```markdown
*Example*
```

Result

*Example*

---

# Bullet Lists

Use a dash followed by a space.

Markdown

```markdown
- First item
- Second item
- Third item
```

Result

* First item
* Second item
* Third item

---

# Numbered Lists

Markdown

```markdown
1. First Step
2. Second Step
3. Third Step
```

Result

1. First Step
2. Second Step
3. Third Step

---

# Checklists

Markdown

```markdown
- [ ] Not completed
- [x] Completed
```

Result

* [ ] Not completed
* [x] Completed

---

# Inline Code

Use backticks around filenames, commands, keyboard shortcuts, or folder names.

Markdown

```markdown
`README.md`

`Ctrl+S`

`Docs`
```

Result

`README.md`

`Ctrl+S`

`Docs`

---

# Code Blocks

Use three backticks before and after the text.

Markdown

````markdown
```
Docs
    01_LOR_System
        01_Preview_Authoring
```
````

Result

```
Docs
    01_LOR_System
        01_Preview_Authoring
```

---

# Links to Another Document

Markdown

```markdown
[Contributor Training](README.md)
```

Result

[Contributor Training](README.md)

---

# Links to a Website

Markdown

```markdown
[Visual Studio Code](https://code.visualstudio.com/)
```

Result

[Visual Studio Code](https://code.visualstudio.com/)

---

# Images

Images are inserted using this format.

Markdown

```markdown
![Image Description](Images/example.png)
```

Example

```markdown
![VS Code Welcome Screen](Images/vscode_welcome.png)
```

Always place images in the project's **Images** folder unless instructed otherwise.

---

# Horizontal Line

Use three dashes.

Markdown

```markdown
---
```

Result

---

Horizontal lines are commonly used to separate major sections.

---

# Tables

Example

```markdown
| File | Purpose |
|------|---------|
| README.md | Folder introduction |
| 11_Markdown_Quick_Reference.md | Markdown reference |
```

Result

| File                           | Purpose             |
| ------------------------------ | ------------------- |
| README.md                      | Folder introduction |
| 11_Markdown_Quick_Reference.md | Markdown reference  |

---

# Notes

Many MSB documents use bold text to call attention to important information.

Example

```markdown
**Important**

Always update your project before editing documentation.
```

Result

**Important**

Always update your project before editing documentation.

---

# Keyboard Shortcuts

| Shortcut           | Purpose                      |
| ------------------ | ---------------------------- |
| `Ctrl + S`         | Save document                |
| `Ctrl + F`         | Find within current document |
| `Ctrl + Shift + F` | Search all project files     |
| `Ctrl + P`         | Open a file by name          |
| `Ctrl + Shift + V` | Open Markdown Preview        |

---

# Folder Paths

Use a code block for longer folder paths.

Example

```
Docs
    01_LOR_System
        01_Preview_Authoring
```

For a short path within a sentence, use inline code.

Example

`Docs/01_LOR_System/01_Preview_Authoring`

---

# Filenames

Always surround filenames with backticks.

Correct

`README.md`

`01_Install_VSCode_and_Git.md`

Incorrect

README.md

01_Install_VSCode_and_Git.md

---

# Common Formatting Mistakes

## Missing Space After a Dash

Correct

```markdown
- Item
```

Incorrect

```markdown
-Item
```

---

## Missing Blank Line

Correct

```markdown
Paragraph One.

Paragraph Two.
```

Incorrect

```markdown
Paragraph One.
Paragraph Two.
```

---

## Forgetting to Close Bold Text

Correct

```markdown
**Important**
```

Incorrect

```markdown
**Important
```

---

## Forgetting the Closing Backtick

Correct

```markdown
`README.md`
```

Incorrect

```markdown
`README.md
```

---

# Copy Existing Formatting

The easiest way to keep documents consistent is to copy formatting that already exists.

For example, if you need another heading, copy an existing heading and change only the text.

If you need another list item, copy an existing list item.

This approach helps keep the entire documentation library consistent.

---

# Remember

You do **not** need to become a Markdown expert.

Nearly every MSB document uses only the formatting shown on this page.

If you forget something, simply return to this reference.

---

# Next Step

The final lesson explains several common problems that new contributors encounter and how to solve them.

Continue with:

[12 — Common Problems and How to Fix Them](12_Common_Problems_and_How_to_Fix_Them.md)

---

[← Previous: Respond to Review Comments](10_Respond_to_Review_Comments.md) | [Back to Contributor Training](README.md) | [Next: Common Problems and How to Fix Them →](12_Common_Problems_and_How_to_Fix_Them.md)
