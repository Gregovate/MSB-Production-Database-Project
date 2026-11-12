# Operator UI Message Contract

| Document control | Value |
|---|---|
| Status | **GOVERNING OPERATOR UI CONTRACT** |
| Applies to | FieldWiring, Procedures, Scan, Testing, Work Orders, LOR2DB operator pages, and future operator-facing applications |
| Audience | MSB volunteers and operators |
| Engineering audience | Application and database maintainers |

## Purpose

All MSB operator-facing applications must present errors, warnings, missing-content findings, and review conditions in one consistent human-readable style.

An operator must be able to report a problem accurately without knowing:

- PostgreSQL schema or table names;
- internal diagnostic codes;
- Python/JavaScript function names;
- Linux server mount paths;
- GitHub repository paths; or
- implementation-specific resolver terminology.

Internal engineering diagnostics remain valuable and may be retained in logs, tests, API engineering metadata, or a clearly separated engineering-details view. They must not be used as the primary operator message.

## Required Operator Message Content

When enough context is available, a visible operator message must identify:

1. **What function/content failed** — for example Wiring, Setup procedure, Takedown procedure, Inspection procedure, Testing, Work Order, or Scan action.
2. **What item/context is affected** — Display, Stage, Sub-stage, Scene, Container, Work Order, or other operator-recognizable identity.
3. **Where the operator should expect the item or content to exist** when a human-maintained location applies.
4. **What the operator can report or do next** without interpreting an engineering code.

For Google Drive-backed field documents, the message must show the exact expected task folder whenever it can be constructed from already-resolved context.

Examples:

```text
Wiring not found for 21-Sliding Penguins in folder
G:\Shared drives\Display Folders\21-Polar Bear Playground-PB\21-Sliding Penguins\Wiring\MusicalStage.
```

```text
Setup procedure not found for 13-Christmas Story in folder
G:\Shared drives\Display Folders\13-Winter Wonderland-WW\13-Christmas Story\Procedures\Setup.
```

```text
Takedown procedure not found for Stage 15 in folder
G:\Shared drives\Display Folders\15-Church-Bells-CH\Procedures\Takedown.
```

The operator can now report both the missing item and the exact place that should be checked.

## Engineering Code Separation

Internal codes such as:

```text
LOR_CONTEXT_NOT_DEFINED_FIELD_SCENE
FIELD_SCENE_MARKER_MISSING
DATABASE_STAGE_NOT_IN_FIELD_HIERARCHY
```

are engineering identifiers.

They may be retained separately, for example:

```json
{
  "code": "LOR_CONTEXT_NOT_DEFINED_FIELD_SCENE",
  "operator_warning": "Wiring not found for 21-Sliding Penguins in folder G:\\Shared drives\\Display Folders\\21-Polar Bear Playground-PB\\Wiring\\MusicalStage."
}
```

The browser/operator presentation must use `operator_warning`, not `code`, as the visible primary message.

An unmapped/new engineering code must fall back to a useful generic operator message. The raw internal code must not leak into normal operator presentation merely because a mapping is missing.

## Human-Facing Path Rule

When a Google Drive location is reported to an operator, use the canonical human-facing path:

```text
G:\Shared drives\Display Folders\...
```

Do not show the production server mount path as the normal operator location:

```text
/mnt/msb-display-folders/...
```

Server paths may remain in engineering logs when needed. Operator presentation translates the already-known server-relative path text to the canonical Shared Drive path without performing another filesystem lookup.

## Task-Specific Folder Rule

The shared context resolver identifies the owning Stage/Sub-stage/Scene scope.

The task adapter already knows its own relative content branch and must supply that branch to the operator-message formatter.

Examples:

```text
FieldWiring / Musical
    -> Wiring\MusicalStage

FieldWiring / Background
    -> Wiring\BackgroundStage

Setup
    -> Procedures\Setup

Takedown
    -> Procedures\Takedown

Inspection
    -> Procedures\Inspection
```

The shared message formatter must not choose the task branch itself.

This preserves the application boundary:

```text
shared context
    -> resolved physical scope
    -> task adapter chooses content branch
    -> operator formatter reports the already-known expected location
```

## Performance Requirement

Operator-message formatting must not materially increase application latency.

The formatter must use information already available from the completed request. It must not perform:

- additional PostgreSQL queries;
- SQLite queries;
- Google Drive enumeration;
- filesystem `exists`/directory scans;
- marker validation;
- HTTP/network requests; or
- a second context-resolution pass.

Formatting is a pure presentation operation over already-resolved values.

If constructing a useful operator message would require new I/O, that I/O belongs in the normal application/resolution workflow and must be justified independently. The message layer itself must remain formatting-only.

## Consistency Across Applications

This contract applies to every operator-facing MSB UI, even when the underlying subsystem is unrelated to Google Drive.

The exact fields vary by subsystem, but the presentation principle does not:

```text
technical condition
    -> internal diagnostic code/details
    -> operator translation
    -> plain-language affected item + expected location/action + next useful information
```

Examples outside field documents may use a record/action rather than a folder:

```text
Work Order 184 could not be opened for DISP:251. Report Work Order 184 and Display DISP:251.
```

```text
Testing is not available for DISP:251 because no current test session was found. Start or select a current test session first.
```

The operator should never need to translate a developer error code before reporting a problem.

## Acceptance Rule For New Operator UIs

A new or changed operator-facing UI is not accepted until its error/warning states demonstrate that:

- internal codes are not the primary visible message;
- the affected operator-recognizable item is named;
- the expected location/action is shown when known;
- Google Drive paths use the canonical operator path when applicable;
- an unmapped diagnostic still produces useful plain language; and
- message generation introduces no additional I/O or context-resolution work.

This requirement is part of UI acceptance, not optional cleanup after deployment.
