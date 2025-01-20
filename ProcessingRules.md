# Processing Rule Document for LOR Props Parsing

# Objective
Outline actions needed to process *.lorprev files in a specified folder to extract xml keys found for PreviewClass and PropClass. Parse and data and format prop file to provide the structure necessay to create a one to one link to the between the props table and external displays table. This will be accpomplished by utilizing the comment field to assign the display name. we will create separate tables using the keys found in previewsClass and propClass records. All requisite data is in the preview file. 

# Goal
Create props table that contains one record per display. Use the subprops and dmx channel tables to store the information needed to setup the displays. This is needed to manage the physical displays we design, build, inventory, and setthe light show. 

# Background Information:
The propClass is designed to sequence a light show but is not friendly to manage the inventory and documentation to set it up. The propClass is very consistant and provides all the information needed by utilizing the comment field to set the key for displays. There could be one prop per display. There could be props with subprops in a display. there can be shared props on one display. there could be shared props that are on different displays. There can be multiple props on one display, there can be  prop file. since one display can contain multiple props

# Definitions:
  - Preview: A collection of props in a designated stage. This can be a collection of props sequenced to music or a background animation.
  - LOR: Abbreviation for Light O Rama
  - Stage: An area set to a theme containing displays that are either background animations or displays sequenced to music.
  - Prop: Light O Rama defines a prop as any device that responds to a command sent from the sequencer. This is a very confusing term since most people think a prop is a single physical objext.
  - Subprop: A prop that responds to the same commands as a prop. This must be expicitly assigned in the preview.
  - Display: A display as a single physical object that we design, build, setup, and inventory. A display can be a single prop or can be a combination of props and/or subprops.
  - UID: The hexadecimal number assigned to a controller
  - id: is the  UUID or "Universally Unique Identifier" assigned to the id of a prop, preview, or subprop by the LOR Software at the time of creation. This number will not change unless the prop is deleted or is imported into a preview where that UUID is shared with a duplicated prop. All duplicated props must be placed into the same preview and re-exported to ensure 

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

### Rule for `DeviceType == None`
- Parse props with `DeviceType == None`.
- Sum the `Lights` values (`Parm2`) for props sharing the same `LORComment`.
- Insert a single record into the `props` table for each unique `LORComment`.
- Include parsed grid parts (`Network`, `UID`, `StartChannel`, etc.) if available.

### Rule for `DeviceType == DMX`
1. **Identify Groups by `Comment`:**
    - Group props sharing the same `Comment`.
2. **Master Prop Selection:**
    - Choose the prop with the lowest `StartChannel` as the master prop.
3. **Insert Master Prop:**
    - Insert the master prop into the `props` table.
4. **Insert Remaining Props as DMX Channels:**
    - Insert remaining props with the same `Comment` into the `dmxChannels` table.
    - Assign the `MasterPropId` to the `PropID` of the master prop.

### Rule for `DeviceType == LOR` with Single `ChannelGrid`
1. **Single `ChannelGrid`:**
    - Parse the `ChannelGrid` into `Network`, `UID`, `StartChannel`, `EndChannel`, `Unknown`, and `Color`.

2. **Master Prop Identification:**
    - Identify the master prop as the prop with the lowest `StartChannel` among props sharing the same `LORComment`.
    - Insert the master prop into the `props` table.

3. **SubProps Handling:**
    - For remaining props sharing the same `LORComment`:
        - Assign the `MasterPropId` to the `PropID` of the master prop.
        - Insert these props into the `subProps` table.
        - Include all parsed grid parts.

4. **Special Case for Props with Name Containing 'Spare':**
    - Props with `Name` containing the substring "spare" (case-insensitive):
        - Insert directly into the `props` table.
        - Parse the `ChannelGrid` field to extract grid parts (`Network`, `UID`, `StartChannel`, etc.).
        - Save the parsed grid data in the `props` table.
        - Skip further processing for these props.

### Rule for `DeviceType == LOR` with `ChannelGrids` Groups (> 1) Separated by `;`
1. **Process Props with Multiple `ChannelGrid` Groups:**
    - Parse the `ChannelGrid` field into individual groups separated by `;`.
    - Each group is split into `Network`, `UID`, `StartChannel`, `EndChannel`, `Unknown`, and `Color`.

2. **Master Prop Retention:**
    - The original prop remains in the `props` table.

3. **SubProps Creation:**
    - For each parsed grid group:
        - Generate a subprop record with the grid data.
        - Assign the `MasterPropId` as the `PropID` of the original master prop.
        - Assign a unique `SubPropID` for each subprop.
        - Determine the `Name` for subprops based on the master prop’s name with an appropriate suffix.
        - Insert subprops into the `subProps` table.

### General Notes
- Ensure all missing attributes are handled gracefully with default values.
- Debugging logs are added to confirm master and subprop identification.
- Each `PropClass` is parsed, and results are committed to the database incrementally.

### Debugging and Validation
1. Verify data in the `props` table:
   ```sql
   SELECT * FROM props;
   ```
2. Verify data in the `subProps` table:
   ```sql
   SELECT * FROM subProps;
   ```
3. Verify all tables include the expected number of records and fields.

# Remaining Tasks
1. Determine method to deal with props that are members of multi-channel prop groups with specifiv tags used for programming.
  - Tag="03.01 AC Light Curtain (8 Strands) - Group A"
  - Tag="03.09 AC Light Curtain (8 Strands) - Group B

2. Determine methond to deal with prop components making up a larger display
  - Mega Star
  - Lollipop trailer

This document reflects the latest changes and ensures all processing rules and database updates are synchronized with the script logic.
