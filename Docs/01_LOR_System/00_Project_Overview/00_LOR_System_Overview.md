# LOR System Overview

| Document control | Value |
|---|---|
| Status | ACTIVE — V7 scene-aware production workflow |
| Owner | MSB Database Administrator |
| Current revision | 2026-08-06 |

## Purpose

The MSB LOR system converts the authoritative Light-O-Rama preview set into a
complete SQLite snapshot, loads that snapshot into PostgreSQL, reconciles it
against permanent production identities, and publishes an auditable report.

The current workflow is V7. V6 parser and database material is archived under
`archive/v6/` and must not be used for production.

## Identity layers

- A **stage** is a permanent physical park area.
- A **display** is one permanent physical object tracked by `display_id`.
- An LOR **prop** or **subprop** is sequencing structure and is not itself the
  permanent production identity.
- A **scene** is a V7 presentation/workspace view associated with a stage.
- `raw_prop_id` is the current LOR association; it may change without creating
  a new physical display.

## Current production flow

```text
Authoritative V7 preview exports
    -> parse_props_v7_scene_parser.py
    -> lor_output_v7_scene.db
    -> LOR/ingest/postgres_run_ingest_v7.ps1
    -> immutable lor_snap snapshot
    -> https://lortodb.sheboyganlights.org/lor2db/
    -> persistent reconciliation and operator decisions
    -> controlled P1-P4 promotion
    -> validation and immutable HTML report
```

For the current release, the parser and PostgreSQL snapshot ingest are run
manually on the approved Master PC. The `lor2db` page detects the latest
committed snapshot and never asks the operator to enter an ingest ID.

## Current source and entry points

- Parser: `LOR/ingest/parse_props_v7_scene_parser.py` (production
  exercised through V7.0.7; the path name is retained until a separate,
  controlled source-layout change).
- SQLite snapshot: `lor_output_v7_scene.db`.
- PostgreSQL ingest: `LOR/ingest/postgres_run_ingest_v7.ps1`.
- Controlled production procedure:
  `LOR2DB/Reconciliation/00_LOR_Production_Import_and_Reconciliation_Procedure.md`.
- Reconciliation landing page:
  `https://lortodb.sheboyganlights.org/lor2db/`.
- Manual recovery runbook:
  `LOR2DB/Reconciliation/02_LOR_Manual_Reconciliation_Runbook.md`.

## Noncurrent material

Do not use `parse_props_v6.py`, `lor_output_v6.db`, or V6 workflow instructions
for a production run. They are retained only under `archive/v6/` so earlier
decisions and troubleshooting evidence remain available.
