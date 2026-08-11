# FormView

FormView is the LOR field-documentation application that turns parsed LOR Preview data and Stage wiring images into practical wiring, stage, and programming information.

FormView is a standalone subsystem within the LOR System. It consumes the SQLite output created by Data Extraction and combines that structured data with the Stage wiring-documentation filesystem. It does not depend on PostgreSQL.

## Start Here

| I want to... | Go to |
|---|---|
| Understand what FormView is and how the production application is built/deployed | [FormView application README](../../../LOR/FormView/README.md) |
| Understand how wiring backgrounds and Stage wiring folders are prepared | [Create Wiring Backgrounds](../01_Preview_Authoring/D_Create_Wiring_Backgrounds..md) |
| Understand the SQLite data produced for downstream consumers | [Data Extraction](../02_Data_Extraction/README.md) |

## Current Engineering Recovery

The detailed FormView engineering contract is being reconstructed from the current source, parser-generated SQLite views, Git history, and production artifacts before any replacement or Setup/Procedure linking architecture is designed.

The engineering document will define the proven behavior of:

- the Stage / Preview Picker;
- Preview and Stage identity;
- `previews.BackgroundFile` and the Stage wiring-folder relationship;
- wiring-image discovery and navigation;
- the SQLite wiring and Stage views consumed by FormView;
- Field Wiring reduction;
- Open Folder behavior;
- printable HTML generation;
- V6/V7 compatibility; and
- requirements that any future replacement must preserve.

The engineering document is intentionally not being committed until the recovered contract is reviewed and accepted.

## System Boundary

At a high level:

```text
LOR Preview Authoring
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

## Related Systems

- [Preview Authoring](../01_Preview_Authoring/README.md) — creates the LOR Preview, Stage/Preview identity, and external wiring-background reference used by FormView.
- [Data Extraction](../02_Data_Extraction/README.md) — creates the SQLite tables and views consumed by FormView.
- [Preview Merger](../03_Preview_Merger/README.md) — manages controlled Preview changes upstream of later parser/database rebuilds.
