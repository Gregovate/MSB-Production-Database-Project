# README Portal Standard

## Purpose

README files are navigation portals. Their job is to help a reader quickly understand where they are and where to go next.

A portal should be short, plain-language, and useful to the least technical audience that needs that particular portal.

For an active engineering subsystem, the README also serves as the durable handoff point between development sessions. It must preserve enough current-state context that work can resume from repository documentation instead of reconstructing decisions from conversation history.

These are not conflicting goals because README portals must be written for their actual audience. A volunteer-facing portal and an engineering-subsystem portal have different responsibilities even though both use the same navigation standard.

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

All portal pages follow the same structural standard, but the language and handoff content must reflect the intended audience.

| Audience | Portal Style | Primary Goal |
|----------|--------------|--------------|
| Volunteers / Operators | Task-oriented | Find the correct procedure and perform the task |
| General Users | User-facing | Find information, reports, or the correct system entry point |
| Engineers / Developers | Engineering | Resume and navigate system development without rediscovering settled work |
| Documentation Maintainers | Standards | Find and apply documentation rules |

The structure of the portal remains consistent throughout the repository, but the navigation and terminology should match the people who use it.

- **Task-oriented portals** help readers complete an operational workflow.
- **User-facing portals** introduce a system and help readers find information or reports.
- **Engineering portals** may use technical terminology appropriate for developers and maintainers and must preserve the current engineering handoff.
- **Standards portals** describe how the documentation system is organized and maintained.

Choose the portal style based on the primary audience, not merely the types of documents contained within the folder.

### Operator portals must not become engineering handoffs

A volunteer/operator portal should not expose parser internals, database implementation, design rationale, unresolved development detail, or other engineering material merely because that information exists in the same subsystem.

The normal operator path should lead to plain-language procedures. Engineering references belong in a clearly separated related-information section when they are useful.

### Engineering portals must not be reduced to operator summaries

An engineering-subsystem README has a different job. It must remain concise, but it cannot omit current state, system boundaries, authoritative sources, unresolved work, or the correct development restart point when losing that information would force the next engineering session to investigate the same questions again.

Plain language is still preferred where possible, but necessary technical terminology is appropriate for the engineering audience.

## Engineering Subsystem Handoff

An active engineering or development subsystem README has an additional responsibility: it is the current handoff point for future work, including work resumed in a different conversation or development thread.

Use concise sections when applicable to identify:

- **Current State** — what is implemented, deployed, approved, legacy, partial, or planned now.
- **Design Intent** — the direction of the subsystem, while clearly separating approved architecture from future ideas.
- **Authoritative Sources** — the code, SQL, database objects, applications, drawings, spreadsheets, exports, equipment datasets, or other artifacts that must be reviewed before changing the subsystem.
- **System Boundaries and Dependencies** — what this subsystem owns and which related systems own adjacent information.
- **Known Limitations / Open Work** — material unresolved work and the point where development stopped.
- **Resume Development** — the subsystem-specific documents and evidence that must be reviewed before continuing engineering work.
- **Related Systems / Related Documents** — navigable links to the responsible neighboring systems and detailed documents rather than duplicated explanations.

These sections are not required on simple volunteer-facing portals when they would add unnecessary technical detail. They are required where omission would force future engineering work to rediscover the subsystem state.

The README is not a development diary. Preserve historical implementation detail in Git history, revision history, incident reports, engineering history, or archive material as appropriate. The README records the current handoff state.

## Conversation-to-Repository Handoff

A material engineering decision is not safely handed off merely because it was resolved in a conversation.

When work changes a subsystem's architecture, workflow, operating behavior, system boundary, authoritative source, known limitation, or next development step:

1. update the detailed document that owns the changed information;
2. review any affected operator procedure when the change affects how people use the system; and
3. update the responsible engineering README when the change affects what the next engineering session needs to know.

The repository, not conversation history, is the durable handoff mechanism.

The goal is that a future session can start from the responsible README and linked engineering documents, understand the current state, and continue work without reconstructing settled decisions from previous chats.

## Mandatory Closeout Rule

Material subsystem work is not complete until the responsible README has been reviewed and, when necessary, updated to reflect the resulting current state.

This applies to development, migrations, workflow changes, deployment changes, architecture decisions, significant documentation changes, and other work that changes how the subsystem operates or should be resumed.

Before closing the work:

1. Update the responsible detailed engineering, procedure, SOP, or reference documents when their owned information changed.
2. Review the subsystem README after those updates.
3. Update the README so its current state, authoritative sources, dependencies, known limitations, and next development starting point remain accurate.
4. Review affected operator documentation separately when the engineering change alters an operator task.
5. Verify navigation and related-system links.
6. Commit the README handoff update with the work rather than leaving it for a later cleanup pass.

The intended result is that the next work session can begin by reading the repository and continue from the documented state without rehashing or reinvestigating settled decisions.

## Technical Detail

Technical depth belongs one level deeper in procedures, design documents, runbooks, or subsystem documentation. A portal may briefly identify those destinations but should not reproduce their content.

For engineering portals, this rule means the README summarizes the handoff and links to the detailed engineering authority. It does not mean the README should omit the current engineering state.

## Maintenance

- Portal links should remain as local as practical. When a child folder has its own README portal, parent portals should link directly to that README rather than maintaining links to documents several levels below it.
- Screenshots should follow the repository screenshot standard and be stored in the designated documentation image location.
- When linking users to a portal from email or other external communication, link directly to the portal `README.md` so GitHub opens the portal content without the repository file listing above it.
- Current internal and external application links must be maintained in engineering documentation as well as user-facing documentation. Historical URLs may remain only when they are clearly identified as historical evidence rather than current access instructions.
