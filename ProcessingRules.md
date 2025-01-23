# Processing Rule Document for LOR Props Parsing

## Objective
Outline actions needed to process *.lorprev files in a specified folder to extract XML keys found for `PreviewClass` and `PropClass`. Parse and format the data to provide the structure necessary to create a one-to-one link between the `props` table and the external displays table. This will be accomplished by utilizing the `Comment` field to assign the display name. We will create separate tables using the keys found in `PreviewClass` and `PropClass` records. All requisite data is in the preview file.

## Goal
Create a `props` table that contains one record per display. Use the `subProps` and `dmxChannels` tables to store the information needed to set up the displays. This is required to manage the physical displays we design, build, inventory, and configure for the light show.

## Background Information
The `PropClass` is designed to sequence a light show but is not ideal for managing inventory and documentation. The `PropClass` provides all necessary information by utilizing the `Comment` field to set the key for displays. Displays may consist of one or more props, and props may include subprops. These relationships must be parsed and stored appropriately.

## Definitions
- **Preview**: A collection of props in a designated stage. This can be props sequenced to music or a background animation.
- **LOR**: Abbreviation for Light O Rama.
- **Stage**: An area set to a theme containing displays that are either background animations or sequenced to music.
- **Prop**: Any device that responds to commands sent by the sequencer.
- **Subprop**: A prop assigned explicitly as subordinate to another prop in the preview.
- **Display**: A physical object designed, built, setup, and inventoried. Displays may consist of one or more props and/or subprops.
- **UID**: A hexadecimal number assigned to a controller.
- **id**: A UUID (Universally Unique Identifier) assigned by LOR software to a prop, preview, or subprop upon creation.

## Database Schema

### Previews Table
Stores metadata about each preview, ensuring the relationship between the stage and its associated props.
```sql
CREATE TABLE previews (
    id TEXT PRIMARY KEY,
    StageID TEXT,
    Name TEXT,
    Revision TEXT,
    Brightness REAL,
    BackgroundFile TEXT
);
```

### Props Table
Contains master props, storing parsed data from `ChannelGrid` fields to support display-specific requirements.
```sql
CREATE TABLE props (
    PropID TEXT PRIMARY KEY,
    Name TEXT,
    LORComment TEXT,
    DeviceType TEXT,
    BulbShape TEXT,
    Network TEXT,
    UID TEXT,
    StartChannel INTEGER,
    EndChannel INTEGER,
    Unknown TEXT,
    Color TEXT,
    CustomBulbColor TEXT,
    DimmingCurveName TEXT,
    IndividualChannels BOOLEAN,
    LegacySequenceMethod TEXT,
    MaxChannels INTEGER,
    Opacity REAL,
    MasterDimmable BOOLEAN,
    PreviewBulbSize REAL,
    MasterPropId TEXT,
    SeparateIds BOOLEAN,
    StartLocation TEXT,
    StringType TEXT,
    TraditionalColors TEXT,
    TraditionalType TEXT,
    EffectBulbSize REAL,
    Tag TEXT,
    Parm1 TEXT,
    Parm2 TEXT,
    Parm3 TEXT,
    Parm4 TEXT,
    Parm5 TEXT,
    Parm6 TEXT,
    Parm7 TEXT,
    Parm8 TEXT,
    Lights INTEGER,
    PreviewId TEXT,
    FOREIGN KEY (PreviewId) REFERENCES previews (id)
);
```

### SubProps Table
Stores subprops linked to master props, capturing subordinate elements of displays.
```sql
CREATE TABLE subProps (
    SubPropID TEXT PRIMARY KEY,
    Name TEXT,
    LORComment TEXT,
    DeviceType TEXT,
    BulbShape TEXT,
    Network TEXT,
    UID TEXT,
    StartChannel INTEGER,
    EndChannel INTEGER,
    Unknown TEXT,
    Color TEXT,
    CustomBulbColor TEXT,
    DimmingCurveName TEXT,
    IndividualChannels BOOLEAN,
    LegacySequenceMethod TEXT,
    MaxChannels INTEGER,
    Opacity REAL,
    MasterDimmable BOOLEAN,
    PreviewBulbSize REAL,
    RgbOrder TEXT,
    MasterPropId TEXT,
    SeparateIds BOOLEAN,
    StartLocation TEXT,
    StringType TEXT,
    TraditionalColors TEXT,
    TraditionalType TEXT,
    EffectBulbSize REAL,
    Tag TEXT,
    Parm1 TEXT,
    Parm2 TEXT,
    Parm3 TEXT,
    Parm4 TEXT,
    Parm5 TEXT,
    Parm6 TEXT,
    Parm7 TEXT,
    Parm8 TEXT,
    Lights INTEGER,
    PreviewId TEXT,
    FOREIGN KEY (MasterPropId) REFERENCES props (PropID),
    FOREIGN KEY (PreviewId) REFERENCES previews (id)
);
```

## Processing Rules

### Rule 1: DeviceType == None
- Parse props with `DeviceType == None`.
- Sum the `Lights` values (`Parm2`) for props sharing the same `LORComment`.
- Insert a single record into the `props` table for each unique `LORComment`.
- Include parsed grid parts (`Network`, `UID`, `StartChannel`, etc.) if available.

### Rule 2: DeviceType == DMX
1. **Identify Groups by `Comment`**:
    - Group props sharing the same `Comment`.
2. **Master Prop Selection**:
    - Choose the prop with the lowest `StartChannel` as the master prop.
3. **Insert Master Prop**:
    - Insert the master prop into the `props` table.
4. **Insert Remaining Props as DMX Channels**:
    - Insert remaining props with the same `Comment` into the `dmxChannels` table.
    - Assign the `MasterPropId` to the `PropID` of the master prop.

### Rule 3: DeviceType == LOR
#### Single `ChannelGrid`
1. Parse the `ChannelGrid` into `Network`, `UID`, `StartChannel`, `EndChannel`, `Unknown`, and `Color`.
2. Identify the prop with the lowest `StartChannel` as the master prop.
3. Insert the master prop into the `props` table.
4. Insert remaining props into the `subProps` table, linking them to the master prop and including their grid parts.

#### Multiple `ChannelGrid` Groups (> 1) Separated by `;`
1. **Group Props by `LORComment`**:
    - All props sharing the same `LORComment` are grouped.
2. **Master Prop Selection**:
    - Identify the prop with the lowest `StartChannel` as the master prop.
    - Insert this prop into the `props` table.
3. **SubProps Creation**:
    - Process all remaining props and their `ChannelGrid` groups.
    - Insert each grid group as a subprop into the `subProps` table.
4. **Special Case**:
    - If the `Name` contains "spare", the prop is directly placed in the `props` table.

### General Notes
- Ensure all missing attributes are handled gracefully with default values.
- Debugging logs confirm master and subprop identification.
- Each `PropClass` is parsed, and results are committed to the database incrementally.

## Debugging and Validation
1. Verify data in the `props` table:
   ```sql
   SELECT * FROM props;
   ```
2. Verify data in the `subProps` table:
   ```sql
   SELECT * FROM subProps;
   ```
3. Verify all tables include the expected number of records and fields.

This document reflects the latest changes, including grouping by `LORComment` and handling special cases like "spare" props, ensuring all processing rules and database updates are synchronized with the script logic.
