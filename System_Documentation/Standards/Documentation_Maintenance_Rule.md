# Documentation Maintenance Rule

| Document control | Value |
|---|---|
| Status | CURRENT — reusable documentation standard |
| Scope | Version-controlled engineering projects using the MSB documentation framework |
| Initial revision | 2026-08-21 |
| Current revision | 2026-08-23 |
| Owner | Project documentation owner / administrator |

## Purpose

Reverse-engineering discoveries and other durable engineering knowledge developed during project work are part of the system knowledge. They must be preserved in the repository rather than left only in conversation history.

This rule applies to engineering projects using this documentation framework and to every controlled document touched during an engineering conversation.

## Core Rule

When engineering work reveals new information that improves, corrects, or materially clarifies the understanding of a system, data source, field meaning, relationship, workflow, boundary, naming translation, implementation behavior, or operating constraint, that discovery must be captured in the appropriate repository documentation before the work is considered complete.

Conversation is a working and discovery environment. The repository is the durable project record.

## No Chat-Only Project Memory

Durable project knowledge must not remain only in ChatGPT conversation history, email, temporary notes, or another working communication channel.

This includes, when material to future work:

- verified current-state facts;
- reverse-engineering discoveries;
- accepted design or architecture decisions;
- corrected assumptions;
- identity, naming, path, schema, runtime, and ownership rules;
- production constraints and failure boundaries;
- validation results that establish a new accepted baseline;
- known limitations and unresolved questions; and
- the exact stop point or next engineering starting point.

A chat summary is not a substitute for repository documentation.

Do not defer a material discovery merely by planning to document it at the end of the project. When later engineering work will rely on a discovery, correction, or accepted decision, promote it into the responsible controlled repository document before proceeding past the point where that later work depends on it.

If the correct documentation owner is not immediately obvious, identify the existing current authority first. Do not create an ad hoc document, duplicate a rule into multiple active documents, or invent a new structure simply to record the discovery.

If work stops before implementation is complete, the repository must still contain the durable reconnaissance findings, known constraints, unresolved items, and resume point established during that work.

For cross-repository systems, each repository must preserve the information it owns. Update or synchronize the responsible documents according to the documented ownership boundary rather than leaving the cross-repository state only in conversation history.

## Operational and Runbook Knowledge

Operational discovery is durable engineering knowledge and must be treated the same way as architecture or schema discovery.

When work establishes or corrects how a production system is deployed, restarted, backed up, restored, verified, routed, upgraded, or safely modified, update the existing responsible runbook or runtime document as part of that work.

Examples include:

- the actual nginx configuration file and safe edit/reload procedure;
- the correct reverse-proxy path and trailing-slash behavior;
- the Directus extension deployment path, source/runtime ownership boundary, syntax check, restart sequence, and verification steps;
- accepted production artifact hashes and rollback locations;
- systemd service names, ports, environment files, mount dependencies, firewall rules, and health checks;
- database backup/restore or migration safety gates; and
- any production-specific failure or rollback condition discovered while troubleshooting.

Once this information has been established and documented, future work must read the responsible runbook first and must not repeat broad reconnaissance merely because a new conversation does not remember the prior discovery.

If an existing runbook is wrong or incomplete, correct that runbook before subsequent work depends on the corrected procedure. Do not leave the corrected sequence only in chat and do not create a competing second runbook for the same operation unless the documented ownership model requires a distinct artifact.

## Applies to Every Document Touched

If a controlled document is edited during a conversation, review that document for discoveries made during the same work that affect information the document owns.

Do not update only the immediate sentence or section that triggered the edit while knowingly leaving newly established system knowledge absent, misleading, or inconsistent elsewhere in that same document.

This does not mean rewriting the document. Preserve valid existing content, history, terminology, structure, and ownership. Make focused additive corrections or clarifications where practical.

## Reverse-Engineering Discoveries

Reverse-engineered knowledge must be documented at the level actually established by evidence.

Examples include:

- source-schema field meanings and project terminology translations;
- type-dependent interpretation of serialized fields;
- undocumented relationships between source objects;
- identity and grouping behavior discovered from source files or running systems;
- path-resolution behavior;
- database or application dependencies;
- compatibility assumptions;
- operational constraints revealed during testing;
- limitations where the meaning of a source field is still unknown.

Do not promote an inference into a documented fact unless the evidence supports it. When a meaning remains uncertain, preserve the observed behavior and the uncertainty.

## Documentation Placement

Record discoveries in the document that owns the subject whenever possible.

Use the document-control ownership hierarchy defined by the repository:

- reusable cross-project standards belong in the repository's standards area;
- project-specific governance belongs in the repository's project-rules or equivalent governance area;
- subsystem engineering discoveries belong in the responsible subsystem architecture/reference documentation;
- operator workflow discoveries that change how work is performed belong in the responsible procedure or SOP.

Do not create a new document merely to avoid maintaining the current responsible document. Create a new controlled reference only when the information has a distinct durable purpose, then link it through the responsible navigation.

## Naming and Terminology

When reverse engineering establishes a translation between source-system terminology and project terminology, preserve that translation explicitly in the repository.

Prefer exact source-system names when discussing the source schema and established human-readable project names when discussing project meaning. Avoid introducing conversation-specific aliases when an established source name or controlled project term already exists.

## Closeout Requirement

Before closing material engineering work:

1. Confirm that no durable discovery, accepted decision, corrected assumption, production fact, known limitation, or resume point remains only in conversation history.
2. Confirm that operational or recovery procedures discovered during the work are recorded in the responsible current runbook/runtime document.
3. Review the controlled documents edited during the conversation.
4. Identify durable discoveries made during the work that affect what those documents own.
5. Add focused corrections or clarifications without unnecessarily rewriting valid documentation.
6. Update the responsible subsystem documentation for discoveries that belong outside the files already being edited.
7. Review navigation when a new controlled reference was created or moved.
8. Commit the documentation with the engineering work or as a clearly related documentation commit.

Work is not fully documented if a future maintainer or future engineering session would have to reconstruct an established discovery from conversation history instead of finding it in the repository.

## Relationship to Existing Standards

This rule strengthens the existing requirements in:

- [`Document_Control_Standard.md`](Document_Control_Standard.md), which requires accepted material decisions to be promoted from conversation into controlled repository documentation; and
- [`Prompt_Guidelines.md`](Prompt_Guidelines.md), which treats the repository and authoritative artifacts as the durable source of truth.

This rule does not replace those standards. It establishes the explicit maintenance obligation for discoveries made during engineering conversations.