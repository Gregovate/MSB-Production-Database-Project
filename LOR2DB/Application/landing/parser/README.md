# LOR2DB Parser Page Reconciliation Handoff

| Document control | Value |
|---|---|
| Status | CURRENT |
| System | LOR2DB parser / ingest page |
| Owner | MSB Database Administrator |
| Last reviewed | 2026-08-30 |
| Issue | #106 |

## Purpose

This document owns the parser page's handoff from a completed PostgreSQL ingest to the persistent LOR reconciliation workflow.

The parser page does not own reconciliation state. PostgreSQL and the LOR2DB backend remain authoritative for whether the current snapshot can start a reconciliation, already belongs to an unfinished reconciliation, or has been consumed by a terminal run.

## Backend Workflow Contract

The parser page reads the same authenticated dashboard endpoint used by the LOR2DB landing page:

```text
../preflight/api/dashboard
```

The returned `workflow` object controls the valid next action.

### New snapshot ready to start

```text
workflow.state     = READY_TO_START
workflow.can_start = true
workflow.action.kind = start
```

The parser page may show **Start reconciliation**. The actual Start request remains guarded by the backend/database one-run-per-snapshot contract.

### Existing reconciliation is open

```text
workflow.state       = IN_PROGRESS
workflow.can_start   = false
workflow.action.kind = review
workflow.action.url  = preflight/?run=<run_id>
```

The parser page must show a direct **Continue previous reconciliation** / **Continue reconciliation** action to that persisted run.

A browser refresh must not strand the operator at the ingest page, create another reconciliation, rerun the parser, or rerun ingest.

### Snapshot has no valid action

If `workflow.can_start` is false and there is no valid `review` action, the parser page must not manufacture a Start or Continue action. The dashboard remains the authoritative place to inspect the current state.

## Refresh / Recovery Rule

Browser storage is not reconciliation authority.

After a refresh, tab close/reopen, frontend error, or corrected backend/database permission problem:

```text
reload parser page
    -> read authenticated dashboard state
    -> if a persisted review action exists, route to that exact run
    -> otherwise expose only the action authorized by current backend state
```

The parser-page resume bridge accepts only the fixed relative review URL form:

```text
preflight/?run=<numeric run_id>
```

It performs read-only dashboard access and cannot call `runs/start` or any reconciliation write endpoint.

## Production Regression — Run 18 / Import 60

On 2026-08-30 import 60 successfully created reconciliation Run 18. A separate missing least-privilege database grant (#104) initially prevented the browser from reading Stage review. After migration 0041 repaired that permission, refreshing `/lor2db/parser/` still rendered only **Refresh reconciliation status** because the existing parser JavaScript ignored the backend `workflow.action` review URL.

Issue #106 corrects that frontend recovery gap. Run 18 / import 60 is the production acceptance case: refreshing the parser page must provide a direct route back to existing Run 18 without creating new parser, ingest, or reconciliation state.

## Implementation

- `parser.js` — primary parser/ingest workflow rendering and Start action.
- `parser-reconciliation-resume.js` — read-only recovery bridge that converts the legacy refresh-status control into the backend-authorized persisted review action when one exists.
- `index.html` — loads the resume bridge after `parser.js`.
- `test_parser_reconciliation_resume.py` — regression contract for script ordering, review action handling, URL restriction, and no-write behavior.

The resume bridge is deliberately narrow. It does not alter parser evidence, ingest evidence, reconciliation database logic, or the one-reconciliation-per-snapshot contract.
