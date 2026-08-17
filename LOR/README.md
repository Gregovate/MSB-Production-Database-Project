# LOR input system

LOR is the critical input-side system for the MSB production database. It includes preview ownership and controlled merging, authoring rules, system definitions, FormView, and the handoff to the LOR2DB V7 ingest pipeline.

## End-to-end production chain

```text
programmer preview islands
    -> individual UserPreviewStaging folders
    -> controlled comparison and merge
    -> Office PC designated master
    -> approved master preview set
    -> LOR2DB V7 parser and SQLite snapshot
    -> FormView (standalone SQLite application)
    -> LOR2DB PostgreSQL append-only snapshot ingest
    -> LOR2DB reconciliation, promotion, validation, and reporting
```

The Show PC historically held the master. It is not the current authority while the Office PC holds that role during development. Master authority must be transferred deliberately; no programmer's local preview may overwrite it.

## Production entry points

1. Follow the [Preview Merger process](preview_merger/README.md) to establish the reviewed master input set. The process remains required, although the recovered implementation is blocked from production apply pending review.
2. Continue to the [LOR2DB operator workflow](../Docs/02_Production_Database/02_Operational_SOPs/LOR2DB/Run_an_LOR_Production_Update.md) for the current V7 parser, review, and PostgreSQL snapshot ingest.
3. Continue in LOR2DB. Ingest does not directly promote snapshot data into permanent production identities.

## FormView

`FormView/` is Python compiled with PyInstaller and distributed as `FormViewSA.exe`. It remains a production application based on the SQLite snapshot. It still consumes the established `lor_output_v6.db` and `_v6` wiring-view contract even though V7 is the supported ingest pipeline. Those compatibility names are active dependencies, not authorization to use the archived V6 parser or V6 ingest workflow. FormView is transitional and must remain available until database-generated field and wiring reports replace its required functions. That replacement is not complete.

See [FormView](FormView/README.md) for its build, deployment, launcher, data contract, views, exports, and required replacement validation.

## Version compatibility

The current V7 workflow and approved XML manifest are validated for LOR 6.6.10.
Every later LOR software version requires a separate compatibility review before
it can replace that known-good input baseline. Use the website's **Check new
version** workflow and the controlled [LOR Preview Version Compatibility
Review](../Docs/01_LOR_System/02_Data_Extraction/LOR_Preview_Version_Compatibility_Review.md).
Do not infer compatibility merely because the parser starts.

## Authoritative documentation

- [Project overview](../Docs/00_Project_Overview/README.md)
- [LOR system documentation](../Docs/01_LOR_System/README.md)
- [Preview authoring](../Docs/01_LOR_System/01_Preview_Authoring/README.md)
- [Data extraction engineering](../Docs/01_LOR_System/02_Data_Extraction/README.md)
- [Preview Merger documentation](../Docs/01_LOR_System/03_Preview_Merger/README.md)
- [LOR2DB Ingest](../LOR2DB/01_Ingest/README.md)
- [Office PC runner operations and disaster recovery](../LOR2DB/Application/Office_PC_Runner_Operations_and_Disaster_Recovery.md)

V6 and spreadsheet-era parser/ingest/report workflows are historical only and are stored under `archive/`. The Preview Merger's multi-programmer integrity process is active; it was not made obsolete by V7.
