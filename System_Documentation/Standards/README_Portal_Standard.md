# README Portal Standard

## Purpose

README files are navigation portals. Their job is to help a reader quickly understand where they are and where to go next.

A portal should be short, plain-language, and useful to the least technical audience that needs it.

## Required Structure

Use only the sections that help the reader navigate.

```markdown
# <System or Folder Name>

<One or two plain-language sentences explaining what this area is for.>

## Start Here

<The best first document or action for most readers.>

## What Do You Need To Do?

- [Task or destination](relative-link)
- [Task or destination](relative-link)

## Folder Guide

| Folder | What it contains |
|---|---|
| `Child/` | Plain-language description |
```

`Start Here`, `What Do You Need To Do?`, and `Folder Guide` are optional when they do not add value. Do not add empty sections simply to satisfy a template.

## Portal Rules

- Keep the portal focused on navigation, not technical explanation.
- Link primarily to immediate child folders or documents.
- When an immediate child has its own README portal, link directly to that `README.md` so GitHub opens the portal content instead of placing the directory file listing above it.
- Use plain-language link labels that describe what the reader will find or accomplish.
- Do not duplicate procedures, design explanations, or technical reference material in a portal.
- Prefer relative Markdown links for repository content.
- Do not list every file when a child folder has its own README portal.
- Do not require volunteers to understand implementation terms before they can choose where to go.
- A reader should normally know where to go next within about ten seconds.
- When a subsystem is primarily accessed through a user interface, include a current screenshot near the beginning of the portal when it helps readers confirm they are in the correct location.

## Match the Portal to Its Audience

All portal pages follow the same structural standard, but the language should reflect the intended audience.

| Audience | Portal Style | Examples |
|----------|--------------|----------|
| Volunteers / Operators | Task-oriented | Reconciliation |
| General Users | User-facing | Repository Root, LOR2DB, Reporting |
| Engineers / Developers | Engineering | Application |
| Documentation Maintainers | Standards | System_Documentation |

The structure of the portal remains consistent throughout the repository, but the navigation and terminology should match the people who use it.

- **Task-oriented portals** help readers complete an operational workflow.
- **User-facing portals** introduce a system and help readers find information or reports.
- **Engineering portals** may use technical terminology appropriate for developers and maintainers.
- **Standards portals** describe how the documentation system is organized and maintained.

Choose the portal style based on the primary audience, not the types of documents contained within the folder.

## Technical Detail

Technical depth belongs one level deeper in procedures, design documents, runbooks, or subsystem documentation. A portal may briefly identify those destinations but should not reproduce their content.

## Maintenance

- Portal links should remain as local as practical. When a child folder has its own README portal, parent portals should link directly to that README rather than maintaining links to documents several levels below it.
- Screenshots should follow the repository screenshot standard and be stored in the designated documentation image location.
- When linking users to a portal from email or other external communication, link directly to the portal `README.md` so GitHub opens the portal content without the repository file listing above it.
- Current internal and external application links must be maintained in engineering documentation as well as user-facing documentation. Historical URLs may remain only when they are clearly identified as historical evidence rather than current access instructions.
