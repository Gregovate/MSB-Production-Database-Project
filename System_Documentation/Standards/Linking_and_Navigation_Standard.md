# Linking and Navigation Standard

## Purpose

Keep repository navigation simple and reduce link maintenance as the project grows.

## Rules

- Portal pages should link primarily to immediate children.
- When a child folder has its own README portal, link directly to that `README.md` so GitHub opens the portal content rather than placing the folder listing above it.
- Use relative Markdown links for repository content whenever practical.
- Use descriptive link text that tells the reader what the destination is for.
- Do not duplicate the same deep technical links across multiple portals.
- Cross-system links are allowed when they are genuinely needed to understand a dependency, complete a task, or reach a responsible engineering reference.
- Do not move or rename files only to make links look cleaner without first discussing the change.
- Current internal and external application links must remain current in engineering documentation as well as user-facing documentation.

## Related Systems

Use a **Related Systems** section when a document has meaningful upstream, downstream, supporting, or consuming systems.

Examples include:

- Preview Authoring → Preview Merger → LOR Data Extraction;
- LOR Data Extraction → LOR2DB Ingest;
- LOR2DB Ingest → Reconciliation → Reporting;
- parser output → FormView or the future Wiring System.

When a related system has a current repository portal or engineering entry point, its name should be a navigable Markdown link.

Do not add a Related Systems section when it does not help the reader.

## Related Documents

Use a **Related Documents** section for companion procedures, architecture documents, specifications, runbooks, or other responsible references.

- Every listed document should be a real Markdown link when the target exists.
- Prefer relative paths.
- Link to the responsible document rather than copying its content.
- Do not leave plain document titles that appear to be navigation but cannot be clicked.
- Do not add a Related Documents section when there are no useful related documents.

## Navigation Model

Use progressive navigation:

```text
Repository portal
    -> subsystem portal
        -> task or technical area
            -> detailed document
```

Cross-system engineering navigation may supplement this model when a document needs to show an actual dependency chain. It should not replace the normal portal hierarchy.

Most readers should not need to understand the complete repository structure to find the document they need.

## Link Validation

Automation may scan Markdown files and report:

- broken relative links;
- missing README portals where a portal is expected;
- links to missing files or folders;
- deep links that may bypass an available child portal;
- non-clickable entries inside Related Systems or Related Documents sections;
- current application URLs that still use known superseded locations.

Automation should report problems before changing human-written navigation. Automatic rewriting should be limited to clearly defined generated sections when those are introduced and approved.
