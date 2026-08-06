# LOR input system

LOR is the critical input-side system for the MSB production database. It includes preview authoring rules, system definitions, the V7 scene-aware SQLite snapshot, PostgreSQL snapshot ingest, and FormView.

## Production entry points

1. Run `ingest/parse_props_v7_scene_parser.py` to rebuild `lor_output_v7_scene.db` from the approved preview set.
2. Run `ingest/postgres_run_ingest_v7.ps1`; it calls `ingest/postgres_ingest_from_lor_sqlite_v7.py` and creates one atomic, append-only PostgreSQL snapshot.
3. Continue in LOR2DB. Ingest does not directly promote snapshot data into permanent production identities.

## FormView

`FormView/` remains a production application based on the SQLite snapshot. It
still consumes the established `lor_output_v6.db` and `_v6` wiring-view
contract even though V7 is the supported ingest pipeline. Those compatibility
names are active dependencies, not authorization to use the archived V6 parser
or V6 ingest workflow. FormView is transitional and must remain available until
database-generated field and wiring reports replace its required functions.
That replacement is not complete.

## Authoritative documentation

- [LOR system overview](../Docs/01_LOR_System/00_Project_Overview/00_LOR_System_Overview.md)
- [Preview authoring](../Docs/01_LOR_System/01_Preview_Authoring/)
- [V7 extraction workflow](../Docs/01_LOR_System/02_Data_Extraction/README.md)

V6 and spreadsheet-era LOR workflows are historical only and are stored under `archive/`.
