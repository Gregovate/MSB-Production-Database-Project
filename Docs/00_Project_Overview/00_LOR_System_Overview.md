# LOR System Overview

| Document control | Value |
|---|---|
| Status | ACTIVE — V7 scene-aware production workflow |
| Owner | MSB Database Administrator |
| Current revision | 2026-08-08 |

## Purpose

The MSB LOR system converts the authoritative Light-O-Rama preview set into a complete SQLite snapshot, loads that snapshot into PostgreSQL, reconciles it against permanent production identities, and publishes an auditable report.

The current workflow is V7. V6 parser and PostgreSQL ingest material is archived under `archive/v6/` and must not be used for production. The Preview Merger's multi-programmer integrity process remains active even though its recovered implementation contains V6-era dependencies that require review.

## Identity layers

- A **stage** is a permanent physical park area.
- A **display** is one permanent physical object tracked by `display_id`.
- An LOR **prop** or **subprop** is sequencing structure and is not itself the permanent production identity.
- A **scene** is a V7 presentation/workspace view associated with a stage.
- `raw_prop_id` is the current LOR association; it may change without creating a new physical display.

## Current production flow

```text
Isolated programmer previews
    -> controlled dry-run comparison and reviewed merge
    -> Office PC designated master during LOR 6.6.4/V7 development
    -> authoritative V7 preview exports
    -> LOR2DB/01_Ingest/parse_props_v7_scene_parser.py
    -> lor_output_v7_scene.db
    -> LOR2DB/01_Ingest/postgres_run_ingest_v7.ps1
    -> immutable lor_snap snapshot
    -> https://my.sheboyganlights.org/lor2db/
    -> persistent reconciliation and operator decisions
    -> controlled P1-P4 promotion
    -> validation and immutable HTML report
```

For the current release, the Office PC is the designated master during LOR 6.6.4/V7 development. The Show PC held the master historically and must not be treated as current authority until a deliberate handoff. The parser and PostgreSQL snapshot ingest are run manually from the approved master set. The LOR2DB page detects the latest committed snapshot and never asks the operator to enter an ingest ID.

## Current source and entry points

- Parser: [`LOR2DB/01_Ingest/parse_props_v7_scene_parser.py`](../../LOR2DB/01_Ingest/parse_props_v7_scene_parser.py).
- SQLite snapshot: `lor_output_v7_scene.db`.
- PostgreSQL ingest: [`LOR2DB/01_Ingest/postgres_run_ingest_v7.ps1`](../../LOR2DB/01_Ingest/postgres_run_ingest_v7.ps1).
- Preview ownership and merge control: [Preview Merger](../01_LOR_System/03_Preview_Merger/README.md).
- FormView executable application: [FormView](../../LOR/FormView/README.md).
- Controlled production procedure: [LOR Production Import and Reconciliation Procedure](../../LOR2DB/02_Reconciliation/00_LOR_Production_Import_and_Reconciliation_Procedure.md).
- Reconciliation landing page: [LOR2DB](https://my.sheboyganlights.org/lor2db/).
- Manual recovery runbook: [LOR Manual Reconciliation Runbook](../../LOR2DB/02_Reconciliation/02_LOR_Manual_Reconciliation_Runbook.md).

## Noncurrent material

Do not use `parse_props_v6.py`, `lor_output_v6.db`, or V6 workflow instructions for a production run. They are retained only under `archive/v6/` so earlier decisions and troubleshooting evidence remain available.

FormView's current `lor_output_v6.db` and `_v6` names are documented compatibility dependencies, not authorization to run the archived V6 parser. LOR 6.6.8 compatibility is unverified and must follow the [LOR Preview Version Compatibility Review](../01_LOR_System/02_Data_Extraction/LOR_Preview_Version_Compatibility_Review.md).
