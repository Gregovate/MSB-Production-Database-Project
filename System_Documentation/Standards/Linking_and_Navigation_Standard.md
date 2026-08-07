# Linking and Navigation Standard

## Purpose

Keep repository navigation simple and reduce link maintenance as the project grows.

## Rules

- Portal pages should link primarily to immediate children.
- When a child folder has its own README portal, link to that portal instead of linking directly to files several levels below it.
- Use relative Markdown links for repository content whenever practical.
- Use descriptive link text that tells the reader what the destination is for.
- Do not duplicate the same deep technical links across multiple portals.
- Cross-system links are allowed when they are genuinely needed to complete a task, but they should be the exception rather than the normal navigation model.
- Do not move or rename files only to make links look cleaner without first discussing the change.

## Navigation Model

Use progressive navigation:

```text
Repository portal
    -> subsystem portal
        -> task or technical area
            -> detailed document
```

Most readers should not need to understand the complete repository structure to find the document they need.

## Link Validation

Automation may scan Markdown files and report:

- broken relative links;
- missing README portals where a portal is expected;
- links to missing files or folders;
- deep links that may bypass an available child portal.

Automation should report problems before changing human-written navigation. Automatic rewriting should be limited to clearly defined generated sections when those are introduced and approved.
