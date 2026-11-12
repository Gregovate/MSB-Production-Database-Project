# LOR System Overview

| Document control | Value |
|---|---|
| Status | ACTIVE — V7 scene-aware production workflow |
| Owner | MSB Database Administrator |
| Current revision | 2026-08-17 |

## Purpose

The MSB LOR system converts the authoritative Light-O-Rama preview set into a complete SQLite snapshot, loads that snapshot into PostgreSQL, reconciles it against permanent production identities, and publishes an auditable report.

The current workflow is V7. V6 parser and PostgreSQL ingest material is archived under `archive/v6/` and must not be used for production. The Preview Merger's multi-programmer integrity process remains active even though its recovered implementation contains V6-era dependencies that require review.

## Identity layers

- A **stage** is a permanent physical park area.
- A **display** is one permanent physical object tracked by `display_id`.
- An LOR **prop** or **subprop** is sequencing structure and is not itself the permanent production identity.
- A raw LOR **Scene** is a presentation/workspace row. Folder Alignment
  separately classifies Stage roots, Sub-stage roots, true Scenes, `Root`
  markers, and Display/group locators from the Scene name.
- `raw_prop_id` is the current LOR association; it may change without creating a new physical display.

## Current production flow

```text
Isolated programmer previews
    -> controlled dry-run comparison and reviewed merge
    -> Office PC designated master
    -> authoritative V7 preview exports
    -> Run and review the parser in the LOR2DB website
    -> Docs/01_LOR_System/02_Data_Extraction/Parser/parse_props_v7_scene_parser.py
    -> lor_output_v7_scene.db
    -> approve the exact SQLite digest in the LOR2DB website
    -> digest-locked PostgreSQL ingest from the same page
    -> immutable lor_snap snapshot
    -> Start reconciliation in the LOR2DB website
    -> persistent operator decisions and final review
    -> controlled P1-P4 promotion
    -> validation and immutable HTML report
```

For the current release, the Office PC is the designated master for the
approved LOR 6.6.10 preview set. The Show PC held the master historically and must not be
treated as current authority until a deliberate handoff. The LOR2DB page runs
the parser and the fixed PostgreSQL ingest through the restricted Office PC
runner. They remain separate operator approvals: the parser may be repeated
until the output looks correct, ingest is locked to the exact approved SQLite
SHA-256, and reconciliation starts only after another explicit operator action.
The page never asks the operator for an ingest ID.

## Current source and entry points

- Parser: [`Docs/01_LOR_System/02_Data_Extraction/Parser/parse_props_v7_scene_parser.py`](../01_LOR_System/02_Data_Extraction/Parser/parse_props_v7_scene_parser.py).
- XML version checker and runner: [`LOR Data Extraction`](../01_LOR_System/02_Data_Extraction/README.md).
- SQLite snapshot: `lor_output_v7_scene.db`.
- Normal production workflow: [LOR2DB](https://my.sheboyganlights.org/lor2db/).
- PostgreSQL ingest implementation and recovery entry point: [`LOR2DB/01_Ingest/postgres_run_ingest_v7.ps1`](../../LOR2DB/01_Ingest/postgres_run_ingest_v7.ps1).
- Preview ownership and merge control: [Preview Merger](../01_LOR_System/03_Preview_Merger/README.md).
- FormView executable application: [FormView](../../LOR/FormView/README.md).
- Controlled production procedure: [LOR Production Import and Reconciliation Procedure](../../LOR2DB/02_Reconciliation/00_LOR_Production_Import_and_Reconciliation_Procedure.md).
- Reconciliation landing page: [LOR2DB](https://my.sheboyganlights.org/lor2db/).
- Manual recovery runbook: [LOR Manual Reconciliation Runbook](../../LOR2DB/02_Reconciliation/02_LOR_Manual_Reconciliation_Runbook.md).
- Office PC service dependency and recovery: [Office PC Runner Operations and Disaster Recovery](../../LOR2DB/Application/Office_PC_Runner_Operations_and_Disaster_Recovery.md).

## Noncurrent material

Do not use `parse_props_v6.py`, `lor_output_v6.db`, or V6 workflow instructions for a production run. They are retained only under `archive/v6/` so earlier decisions and troubleshooting evidence remain available.

FormView's current `lor_output_v6.db` and `_v6` names are documented
compatibility dependencies, not authorization to run the archived V6 parser.
LOR 6.6.10 is the current approved version of record. Every later version must
follow the [LOR Preview Version Compatibility Review](../01_LOR_System/02_Data_Extraction/LOR_Preview_Version_Compatibility_Review.md).
