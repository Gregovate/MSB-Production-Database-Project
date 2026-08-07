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
- Use plain-language link labels that describe what the reader will find or accomplish.
- Do not duplicate procedures, design explanations, or technical reference material in a portal.
- Prefer relative Markdown links for repository content.
- Do not list every file when a child folder has its own README portal.
- Do not require volunteers to understand implementation terms before they can choose where to go.
- A reader should normally know where to go next within about ten seconds.

## Technical Detail

Technical depth belongs one level deeper in procedures, design documents, runbooks, or subsystem documentation. A portal may briefly identify those destinations but should not reproduce their content.

## Maintenance

Portal links should remain as local as practical. When a child folder has its own README, parent portals should link to that folder or README rather than maintaining links to documents several levels below it.
