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
- Include navigable `Related Systems` and `Related Documents` sections when they help the reader understand dependencies or find the next responsible document.
- Do not leave plain-text document or system names in navigation sections when a valid Markdown link can be provided.
- When implementation code, SQL, or configuration is authoritative, document the engineering contract without duplicating the implementation unnecessarily.
- When repository paths change, review affected internal links, source-code documentation references, and externally published navigation such as the production `index.html`.

## Before Editing Documentation

For repository documentation work, first determine:

1. What document type is being changed: portal, procedure, SOP, design, runbook, report, or other technical reference.
2. Who needs to read it.
3. What existing document is responsible for the information.
4. Whether the requested change affects links, document control, revision history, screenshots, related systems, or related documents.
5. Whether the document is describing implementation or an engineering contract whose executable source of truth lives elsewhere.

Do not add complexity that does not help the intended reader complete the task or find the next document.

## Repository Changes

When making repository changes through GitHub:

- inspect the current file before replacing it;
- inspect the current repository tree when paths or navigation are involved;
- make only the changes required for the current step;
- use clear commit messages;
- report exactly what was changed;
- identify any issue discovered but intentionally left unchanged;
- do not claim links are current without checking the present repository paths when those paths can be inspected.

The repository, not conversation history, is the durable source for these documentation conventions.

## Reusable MSB Documentation Prompt

Use the following prompt when asking ChatGPT to create, revise, review, or reorganize MSB project documentation. It is intentionally broad so the same standards are applied consistently without having to restate them for every task.

```text
Work on the MSB Production Database Project documentation using the current repository as the source of truth.

Before editing:
1. Review the actual current repository tree and the files directly involved in the task.
2. Read and follow the standards under System_Documentation/Standards/, especially:
   - Documentation_Standards.md
   - README_Portal_Standard.md when working on a README or portal
   - Linking_and_Navigation_Standard.md when links or navigation are involved
   - Prompt_Guidelines.md
3. Determine the document type and intended audience before changing its structure or tone.
4. Identify which existing document, source file, SQL file, application, or configuration is authoritative for the information being documented.

Documentation rules:
- Write for the least technical audience that needs the specific document.
- README files are navigation portals, not technical manuals.
- Procedures and SOPs explain how to perform tasks.
- Engineering/design documents explain how systems work and why engineering decisions were made.
- Keep operational SOPs separate from engineering design.
- Do not rewrite working technical documentation simply to force it into a portal format.
- Do not duplicate information already owned by another responsible document; link to it instead.
- When executable code, SQL, or configuration is the authoritative implementation, document the engineering intent and contract without copying implementation that would have to be maintained twice.
- Preserve established terminology, version information, revision control, safety boundaries, and operational controls.
- Revision histories, when present, must remain reverse chronological.

Navigation rules:
- Use real Markdown links for repository documents and systems whenever targets exist.
- Prefer relative repository links.
- For portal navigation, link directly to the target README.md when this gives the cleaner GitHub portal view.
- Link primarily to immediate children from portal pages.
- Include a Related Systems section when upstream, downstream, supporting, or consuming systems are relevant.
- Include a Related Documents section when companion procedures, specifications, design documents, or responsible references are relevant.
- Do not add either section when it has no useful entries.
- Do not leave non-clickable titles in navigation sections when valid links exist.
- Keep current internal and external application URLs current in engineering documentation as well as user-facing documentation.

Repository-change rules:
- Do not move or rename files unless explicitly approved.
- If files or folders have already moved, identify and repair stale links rather than preserving obsolete paths.
- When path changes affect a published production navigation page, include that page in the link review.
- Check screenshots and image links when the document uses them.
- Make focused changes and do not change direction in the middle of the agreed task without discussing a real problem first.

Before considering the task complete:
1. Verify all links added or changed.
2. Verify Related Systems and Related Documents are included when applicable and are navigable.
3. Verify no current path or URL in the edited material points to a superseded location.
4. Verify the document still serves its intended audience.
5. Report what was changed and identify anything intentionally left for a later step.
```

## Using the Reusable Prompt

The reusable prompt is a starting instruction, not permission to make broad repository changes.

The current task still controls scope. If the task is to review one README, review one README. If the task is a repository-wide link cleanup, inspect the entire affected scope before changing links.

The purpose of the prompt is consistency: the same documentation principles, navigation rules, source-of-truth rules, and completion checks should be applied every time.
