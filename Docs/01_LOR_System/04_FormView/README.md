# FormView

FormView is the LOR field-documentation application that turns parsed LOR Preview data and Stage wiring images into practical wiring, stage, and programming information.

FormView is a standalone subsystem within the LOR System. It consumes the SQLite output created by Data Extraction and combines that structured data with the Stage wiring-documentation filesystem. It does not depend on PostgreSQL.

## Start Here

| I want to... | Go to |
|---|---|
| Wire a Stage/Preview or print temporary field instructions | [FormView Operator Procedure](FormView_Operator_Procedure.md) |
| Understand the recovered FormView engineering design and compatibility contract | [FormView Engineering Architecture](FormView_Engineering_Architecture.md) |
| Understand how the production application is built/deployed | [FormView application README](../../../LOR/FormView/README.md) |
| Understand how wiring backgrounds and Stage wiring folders are prepared | [Create Wiring Backgrounds](../01_Preview_Authoring/D_Create_Wiring_Backgrounds..md) |
| Understand the SQLite data produced for downstream consumers | [Data Extraction](../02_Data_Extraction/README.md) |

## Production Status

FormView 0.3.1 is the proven field-wiring application used with the V6 SQLite compatibility database.

The V7 parser was designed to preserve the established wiring data contract, but FormView has **not yet been operationally validated against the V7 scene-aware SQLite database**. Production field use should remain on the approved V6 compatibility database until that validation is completed.

## System Boundary

At a high level:

```text
Approved LOR Previews
        |
        v
Data Extraction / Parser
        |
        +--> SQLite tables and views --------+
        |                                    |
        +--> Preview BackgroundFile ---------+--> FormView
                                                  |
Stage Wiring folders and published images --------+
                                                  |
                                                  v
                                      Field wiring documentation
```

The parser is responsible for interpreting LOR data and materializing the SQLite interface. FormView is responsible for interpreting that data together with the Stage wiring assets and presenting it for field use.

The current desktop application requires Windows and access to the MSB `G:` shared drive. The planned successor is intended to preserve FormView's proven wiring behavior through browser access at `my.sheboyganlights.org` with PostgreSQL behind the application, removing the field user's mapped-drive and direct-SQLite dependency.

## Documentation Boundary

- **Operator Procedure** explains how a technician uses FormView for field wiring.
- **Engineering Architecture** explains how the application, SQLite views, `BackgroundFile`, Stage wiring filesystem, filters, and exports work together.
- **Preview Authoring** owns preparation of the wiring-background files and LOR Preview reference.
- **Data Extraction** owns the parser-created SQLite structures consumed by FormView.
- **Application README** owns source/build/deployment details for `FormViewSA.exe`.

## Related Systems

- [Preview Authoring](../01_Preview_Authoring/README.md) — creates the LOR Preview, Stage/Preview identity, and external wiring-background reference used by FormView.
- [Data Extraction](../02_Data_Extraction/README.md) — creates the SQLite tables and views consumed by FormView.
- [Preview Merger](../03_Preview_Merger/README.md) — protects the approved official Preview set upstream of parser/database rebuilds.
