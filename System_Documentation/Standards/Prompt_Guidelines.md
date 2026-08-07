# Prompt Guidelines

## Purpose

This document defines how Greg and ChatGPT work together when creating or revising MSB documentation.

These guidelines support the standards in this folder. They do not replace the technical content of the documents being edited.

## Working Rules

- Review the actual repository structure and the current files before proposing changes.
- Follow `Documentation_Standards.md` and the other standards in this folder.
- Work one step at a time when the requested task is staged.
- Do not change direction in the middle of an agreed documentation task unless a real problem is found and discussed.
- Do not move, rename, or reorganize files unless Greg approves it first.
- Do not rewrite working technical documentation merely to make it fit a portal format.
- Preserve technical meaning, established terminology, safety boundaries, and operational controls.
- Keep operational SOPs separate from technical design documentation.
- Keep portal pages short and navigation-focused.
- Link primarily to immediate children rather than duplicating deep links throughout the repository.
- Do not duplicate technical content when a responsible document already exists; link to it instead.
- Write for the least technical audience that needs the specific document.
- Do not make volunteer-facing documentation more technical than the task requires.
- When a document contains version or revision control, preserve it and follow the applicable standards before editing.
- Revision history must remain reverse chronological when used.
- Use repository evidence instead of assumptions whenever the current state can be inspected.

## Before Editing Documentation

For repository documentation work, first determine:

1. What document type is being changed: portal, procedure, SOP, design, runbook, report, or other technical reference.
2. Who needs to read it.
3. What existing document is responsible for the information.
4. Whether the requested change affects links, document control, or revision history.

Do not add complexity that does not help the intended reader complete the task or find the next document.

## Repository Changes

When making repository changes through GitHub:

- inspect the current file before replacing it;
- make only the changes required for the current step;
- use clear commit messages;
- report exactly what was changed;
- identify any issue discovered but intentionally left unchanged.

The repository, not conversation history, is the durable source for these documentation conventions.
