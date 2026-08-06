# LOR input system

LOR is the critical input-side system for the MSB production database. It
includes preview ownership and controlled merging, authoring rules, system
definitions, the V7 scene-aware SQLite snapshot, FormView, PostgreSQL snapshot
ingest, and the handoff to LOR2DB reconciliation.

## End-to-end production chain

```text
programmer preview islands
    -> individual UserPreviewStaging folders
    -> controlled comparison and merge
    -> Office PC designated master during 6.6.4/V7 development
    -> approved master preview set
    -> V7 parser and SQLite snapshot
    -> FormView (standalone SQLite application)
    -> PostgreSQL append-only snapshot ingest
    -> LOR2DB reconciliation, promotion, validation, and reporting
```

The Show PC historically held the master. It is not the current authority while
the Office PC holds that role during development. Master authority must be
transferred deliberately; no programmer's local preview may overwrite it.

## Production entry points

1. Follow the [Preview Merger process](preview_merger/README.md) to establish the
   reviewed master input set. The process remains required, although the
   recovered implementation is blocked from production apply pending review.
2. Run `ingest/parse_props_v7_scene_parser.py` to rebuild
   `lor_output_v7_scene.db` from the approved preview set.
3. Run `ingest/postgres_run_ingest_v7.ps1`; it calls
   `ingest/postgres_ingest_from_lor_sqlite_v7.py` and creates one atomic,
   append-only PostgreSQL snapshot.
4. Continue in LOR2DB. Ingest does not directly promote snapshot data into
   permanent production identities.

## FormView

`FormView/` is Python compiled with PyInstaller and distributed as
`FormViewSA.exe`. It remains a production application based on the SQLite snapshot. It
still consumes the established `lor_output_v6.db` and `_v6` wiring-view
contract even though V7 is the supported ingest pipeline. Those compatibility
names are active dependencies, not authorization to use the archived V6 parser
or V6 ingest workflow. FormView is transitional and must remain available until
database-generated field and wiring reports replace its required functions.
That replacement is not complete.

See [FormView](FormView/README.md) for its build, deployment, launcher, data
contract, views, exports, and required replacement validation.

## Version compatibility

The current V7 workflow was validated against LOR 6.6.4. LOR 6.6.8 requires a
separate compatibility review before it can replace the known-good input
baseline. The controlled checklist is maintained in
[LOR Preview Merger](preview_merger/README.md). Do not assume parser, merger, or
snapshot compatibility and do not modify production ingest or reconciliation
until the review is complete.

## Authoritative documentation

- [LOR system overview](../Docs/01_LOR_System/00_Project_Overview/00_LOR_System_Overview.md)
- [Preview authoring](../Docs/01_LOR_System/01_Preview_Authoring/)
- [V7 extraction workflow](../Docs/01_LOR_System/02_Data_Extraction/README.md)

V6 and spreadsheet-era parser/ingest/report workflows are historical only and
are stored under `archive/`. The Preview Merger's multi-programmer integrity
process is active; it was not made obsolete by V7.
