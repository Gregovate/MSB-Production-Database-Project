Outline actions needed to process *.lorprev files in a specified folder to extract xml keys found for PreviewClass and PropClass. Parse and data and format prop file to provide the structure necessay to create a one to one link to the between the props table and external displays table. This will be accpomplished by utilizing the comment field to assign the display name. we will create separate tables using the keys found in previewsClass and propClass records. All requisite data is in the preview file. 

Goal:
Create props table that contains one record per display. Use the subprops and dmx channel tables to store the information needed to setup the displays. This is needed to manage the physical displays we design, build, inventory, and setthe light show. 

Background Information:
The propClass is designed to sequence a light show but is not friendly to manage the inventory and documentation to set it up. The propClass is very consistant and provides all the information needed by utilizing the comment field to set the key for displays. There could be one prop per display. There could be props with subprops in a display. there can be shared props on one display. there could be shared props that are on different displays. There can be multiple props on one display, there can be  prop file. since one display can contain multiple props

Definitions:
  - Preview: A collection of props in a designated stage. This can be a collection of props sequenced to music or a background animation.
  - LOR: Abbreviation for Light O Rama
  - Stage: An area set to a theme containing displays that are either background animations or displays sequenced to music.
  - Prop: Light O Rama defines a prop as any device that responds to a command sent from the sequencer. This is a very confusing term since most people think a prop is a single physical objext.
  - Subprop: A prop that responds to the same commands as a prop. This must be expicitly assigned in the preview.
  - Display: A display as a single physical object that we design, build, setup, and inventory. A display can be a single prop or can be a combination of props and/or subprops.
  - UID: The hexadecimal number assigned to a controller
  - id: is the  UUID or "Universally Unique Identifier" assigned to the id of a prop, preview, or subprop by the LOR Software at the time of creation. This number will not change unless the prop is deleted or is imported into a preview where that UUID is shared with a duplicated prop. All duplicated props must be placed into the same preview and re-exported to ensure 


1. Create previews table
    - previews
      - CREATE TABLE previews (
        id TEXT PRIMARY KEY,
        StageID TEXT,
        PreviewType TEXT,
        Name TEXT,
        Revision TEXT,
        Brightness REAL,
        BackgroundFile TEXT
        )
2. Create props table
    - props
      - CREATE TABLE props (  
        PropID TEXT PRIMARY KEY,
        Name TEXT,
        LORComment TEXT,
        DeviceType TEXT,
        MaxChannels INTEGER,
        Tag TEXT,
        Network TEXT,
        UID TEXT,
        StartChannel TEXT,
        EndChannel TEXT,
        Unknown TEXT,
        Color TEXT,
        Lights INTEGER,
        DimmingCurveName TEXT,
        Segments INTEGER,
        Opacity REAL,
        MasterDimmable BOOLEAN,
        PreviewBulbSize REAL,
        BulbShape TEXT,
        CustomBulbColor TEXT,
        StartLocation TEXT,
        StringType TEXT,
        TraditionalColors TEXT,
        TraditionalType TEXT,
        RgbOrder TEXT,
        SeparateIds TEXT,
        EffectBulbSize REAL,
        IndividualChannels BOOLEAN,
        LegacySequenceMethod TEXT,
        MasterPropId TEXT,
        PreviewId TEXT
        )
3. Create subProps table
    - subProps
      - CREATE TABLE subProps (
        SubPropID TEXT PRIMARY KEY,
        Name TEXT,
        Lights INTEGER,
        LORComment TEXT,
        MasterPropId TEXT,
        PreviewId TEXT,
        UID TEXT,  -- Include UID
        Channel TEXT,  -- Include StartChannel as Channel
        Color TEXT,
        FOREIGN KEY (MasterPropId) REFERENCES props (PropID),
        FOREIGN KEY (PreviewId) REFERENCES previews (id)
        )
4. Create dmxChannels table
    - dmxChannels
      - CREATE TABLE dmxChannels (
        PropId TEXT,
        Network TEXT,
        StartUniverse INTEGER,
        StartChannel INTEGER,
        EndChannel INTEGER,
        Unknown TEXT,
        PreviewId TEXT,
        FOREIGN KEY (PropId) REFERENCES props (PropID)
        FOREIGN KEY (PreviewId) REFERENCES previews (id)
        )


5. Extract PreviewClass record
  -Create table previews
    1. Parse keys and put into previews table
    2. Apply id to all generated recods and split data into separate tables based on rules.

6. Process propClass records based on following rules:

3. tablesplit data into separate tables based on rules.



We also need to retain UID and channel information in the xml file for instructions for display setup. There could be one prop per display. There could be props with subprops in a display. there can be shared props on one display. there could be shared props that are on different displays. There can be multiple props on one display, there can be  prop file. since one display can contain multiple props

**Previews Table**
        CREATE TABLE previews 
            id TEXT PRIMARY KEY,
            StageID TEXT,
            PreviewType TEXT,
            Name TEXT,
            Revision TEXT,
            Brightness REAL,
            BackgroundFile TEXT

**Props Table**
        CREATE TABLE props 
            PropID TEXT PRIMARY KEY,
            Name TEXT,
            LORComment TEXT,
            DeviceType TEXT,
            MaxChannels INTEGER,
            Tag TEXT,
            Network TEXT,
            UID TEXT,
            StartChannel TEXT,
            EndChannel TEXT,
            Unknown TEXT,
            Color TEXT,
            Lights INTEGER,
            DimmingCurveName TEXT,
            Segments INTEGER,
            Opacity REAL,
            MasterDimmable BOOLEAN,
            PreviewBulbSize REAL,
            BulbShape TEXT,
            CustomBulbColor TEXT,
            StartLocation TEXT,
            StringType TEXT,
            TraditionalColors TEXT,
            TraditionalType TEXT,
            RgbOrder TEXT,
            SeparateIds TEXT,
            EffectBulbSize REAL,
            IndividualChannels BOOLEAN,
            LegacySequenceMethod TEXT,
            MasterPropId TEXT,
            PreviewId TEXT

**A. Preview Definition**:
    <PreviewClass id="b847c70c-6134-4bb1-8dba-992405d014f5" BackgroundFile="" Brightness="5" Revision="65" Name="RGB Plus Prop Stage 07 Whoville "></PreviewClass>
   - Process previews:
     - Previews contain all the props grouped by a themed stage
   - Action:  
     - Get Stage number from Name
     - Get Stage type from Name
     - Save id to every prop and subprop record as a foreign Key
     - These records are stored in the Previews table


**B. Single LOR Display Single ChannelGrid Master Prop**
  If MasterPropID is Null, this is a Master prop and stored in props table if no other master props share the same comment. 
    - Process props with:
      - `DeviceType`== "LOR"
      - `ChannelGrid` Single Group
      - `Comment`!= `Comment` in props table
      - `MasterPropId`== "" If null this is a master prop
      - Keys <PropClass>
          <PropClass id="971f5ddf-9918-4287-8e19-3743d2f91e56" BulbShape="Square" ChannelGrid="Aux I,B4,15,15,0,Green" Comment="Who House Grinch" CustomBulbColor="FFFFFF80" DeviceType="LOR" DimmingCurveName="None" IndividualChannels="True" LegacySequenceMethod="" MaxChannels="16" Opacity="255" MasterDimmable="True" PreviewBulbSize="2" RgbOrder="RGB order" MasterPropId="" SeparateIds="False" StartLocation="n/a" StringType="Traditional" TraditionalColors="Green" TraditionalType="Multicolor_string_1_ch" EffectBulbSize="1" Tag="FaceV2-Felix Tree Outline" Name="Who House Grinch" Parm1="43" Parm2="100"></PropClass>
    - Action:  
      - `propID` = id
      - Separate ChannelGrid fields: Network, UID, Channel, EndChannel, Unknown, Color
      - Lights = `Parm2` 
      - Assign previewID to prop
      - Record put in props table

**C. Single LOR Display Single ChannelGrid Multiple Props Group By Repeating Comment (Same Display)**
  If MasterPropID is Null, this is a Master prop. If there are existing records with the same `Comment` in the props table then this prop is part of the same display. We now convert this prop to a subprop by assigning the id of the master prop with lowest `StartChannel` to all remaining props and storing these records in the subprops table.
     - Process props with:
      - `DeviceType`== "LOR"
      - `ChannelGrid` Single Group
      - `Comment` == `Comment` has matching records in props table
      - `MasterPropId` == ""
      - Keys <PropClass>
        <PropClass id="78871a1d-cae0-419a-8ccc-019d08b402b7" BulbShape="Octogon" ChannelGrid="Aux C,24,1,3,0," Comment="GG24-Ralphie" CustomBulbColor="FF80FFFF" DeviceType="LOR" DimmingCurveName="PixelCurve 30%" IndividualChannels="True" LegacySequenceMethod="" MaxChannels="512" Opacity="255" MasterDimmable="True" PreviewBulbSize="2" RgbOrder="RGB order" MasterPropId="" SeparateIds="False" StartLocation="n/a" StringType="DumbRGB" TraditionalColors="" TraditionalType="Multicolor_string_1_ch" EffectBulbSize="1" Tag="Face-Ralphie Tree Outline" Name="GG24-Ralphie Tree Outline" Parm1="76" Parm2="84"></PropClass>  
    - Action:  
      - `propID` = id
      - Separate ChannelGrid fields: Network, UID, Channel, EndChannel, Unknown, Color
      - Lights = `Parm2` 
      - Assign previewID to prop      
      - Group all props sharing the same `Comment` 
        - Put single prop with lowest channel number in props table and get `id` this will become the master prop
        - Assign `id` of the master prop to all remaining props with the same comment and put these records into subProps Table

**D. subProp MasterpropId is not null Comment SubProp = Comment prop**
  Lookup record in props table. check comment field of master prop. If matching master prop has same comment field value, this is a subprop of the same Display
    - Process props with
      - `DeviceType`== "LOR"
      - `ChannelGrid` Single Group      
      - `MasterPropId` != "" this is a subProp and links to the propID in the props table
      - `Comment` == `Comment` in the props table
      - Keys <PropClass>
       <PropClass id="0e3971ac-63dc-46c4-8c4b-325d8df57470" BulbShape="Square" ChannelGrid="Aux I,B4,15,15,0,Red" Comment="Who House Grinch" CustomBulbColor="FFFFFF80" DeviceType="LOR" DimmingCurveName="None" IndividualChannels="True" LegacySequenceMethod="" MaxChannels="16" Opacity="255" MasterDimmable="True" PreviewBulbSize="2" RgbOrder="RGB order" MasterPropId="971f5ddf-9918-4287-8e19-3743d2f91e56" SeparateIds="False" StartLocation="n/a" StringType="Traditional" TraditionalColors="Red" TraditionalType="Multicolor_string_1_ch" EffectBulbSize="1" Tag="" Name="Who House Grinch Hat" Parm1="31" Parm2="100"> </PropClass>
    - Action:  
      - `subpropID` = id
      - Separate ChannelGrid fields: Network, UID, Channel, EndChannel, Unknown, Color
      - Lights = `Parm2` 
      - Assign previewID to subProp
      - This is a subProp of the same display and is stored in the subProps table

**E. Subprop MasterpropId is not Null SubProp != Comment prop**
  check comment field of master prop. If matching master prop has a different comment field value, We now convert this to a prop by saving the record to the props table.
  Example: RGB candycane subProp (Comment of subprop different than master prop)
     - Process props with:
      - `DeviceType` == "LOR"
      - `ChannelGrid` Single Group      
      - `MasterPropId` != ""  null this is a subProp and links to the propID in the props table
      - `Comment` != `Comment` in the props table
      - Keys <PropClass>
        <PropClass id="348f503f-fbdd-4903-a85e-cfef9ee1821b" BulbShape="Octogon" ChannelGrid="Aux A,21,1,144,0," Comment="CL RGB Candy Cane 05" CustomBulbColor="FFFFFF80" DeviceType="LOR" DimmingCurveName="PixelCurve 30%" IndividualChannels="False" LegacySequenceMethod="" MaxChannels="510" Opacity="255" MasterDimmable="True" PreviewBulbSize="7" RgbOrder="RGB order" MasterPropId="42b87e29-46da-4d42-8627-67b411e15890" SeparateIds="False" StartLocation="n/a" StringType="RGB" TraditionalColors="" TraditionalType="Multicolor_string_1_ch" EffectBulbSize="1" Tag="RGB Candy Cane 01" Name="CL 21 RGB Candy Cane 05" Parm1="0">
    - Action:  
      - `propID` = id
      - Separate ChannelGrid fields: Network, UID, Channel, EndChannel, Unknown, Color
      - Lights = `Parm2` 
      - Assign previewID to prop
      - This is a new display and save record to props table     

**F. Multiple LOR Displays Single ChannelGrid Comment field different derive new displays**
  Example: RGB Candy Cane Master Prop
     - Process props with:
      - `DeviceType` == "LOR"
      - `Name` = "CL 21 RGB Candy Cane 01"
      - `Comment` = "CL RGB Candy Cane 01"
      - `MasterPropId` == ""
      - Keys <PropClass>
        <PropClass id="42b87e29-46da-4d42-8627-67b411e15890" BulbShape="Octogon" ChannelGrid="Aux A,21,1,144,0," Comment="CL RGB Candy Cane 01" CustomBulbColor="FFFFFF80" DeviceType="LOR" DimmingCurveName="PixelCurve 30%" IndividualChannels="False" LegacySequenceMethod="" MaxChannels="510" Opacity="255" MasterDimmable="True" PreviewBulbSize="7" RgbOrder="RGB order" MasterPropId="" SeparateIds="False" StartLocation="n/a" StringType="RGB" TraditionalColors="" TraditionalType="Multicolor_string_1_ch" EffectBulbSize="1" Tag="RGB Candy Cane 01" Name="CL 21 RGB Candy Cane 01" Parm1="0">
    - Action:  
      - `propID` = id
      - Separate ChannelGrid fields: Network, UID, Channel, EndChannel, Unknown, Color
      - Lights = `Parm2` 
      - Assign previewID to prop      
      - Group all props sharing the same `Comment` 

**G. Single LOR Display multiple ChannelGrids Derive Additional subprops**
     - Process props with:
      - `DeviceType` == "LOR"
      - `ChannelGrid` multiple groups separated by `;` 
      - `Name` = "Who Tree Grp A Red 01-16"
      - `Comment` 
      - `MasterPropId` == ""
      - Keys <PropClass>
          <PropClass id="a6537f37-ab62-4b1e-9d43-c417705deb93" BulbShape="Square" ChannelGrid="Aux I,BA,1,1,0,Red;Aux I,BA,2,2,0,Red;Aux I,BA,3,3,0,Red;Aux I,BA,4,4,0,Red;Aux I,BA,5,5,0,Red;Aux I,BA,6,6,0,Red;Aux I,BA,7,7,0,Red;Aux I,BA,8,8,0,Red;Aux I,BA,9,9,0,Red;Aux I,BA,10,10,0,Red;Aux I,BA,11,11,0,Red;Aux I,BA,12,12,0,Red;Aux I,BA,13,13,0,Red;Aux I,BA,14,14,0,Red;Aux I,BA,15,15,0,Red;Aux I,BA,16,16,0,Red" Comment="Spiral Tree Red" CustomBulbColor="FFFFFF80" DeviceType="LOR" DimmingCurveName="None" IndividualChannels="True" LegacySequenceMethod="" MaxChannels="16" Opacity="255" MasterDimmable="True" PreviewBulbSize="2" RgbOrder="RGB order" MasterPropId="" SeparateIds="False" StartLocation="Bottom Back CCW" StringType="Traditional" TraditionalColors="Red" TraditionalType="Channel_per_color" EffectBulbSize="1" Tag="03.01 AC Light Curtain (8 Strands) - Group A" Name="Who Tree Grp A Red 01-16" Parm1="16" Parm2="100" Parm3="50" Parm4="0" Parm5="0">,<PropClass>
    - Action:  
      - `propID` = id
      - First ChannelGrid Network, UID, Channel, EndChannel, Unknown, Color assigned to master prop
      - Lights = `Parm2` 
      - Assign previewID to prop      
      - Loop through remaining ChannelGrids and create subProps store in subProp table
        - generate UUID for subPropId (Only used to generate unique keys for subprop table)
        - ChannelGrid Network, UID, Channel, EndChannel, Unknown, Color
        - MasterPropId` = id of first prop (master prop)
        -  same comment and place these records into subProps Table
        - `Name` = 'Name' append with 2-digit Channel
        - `Comment` = Comment

**H. Single DMX Display Multiple ChannnelGrids**
  - Process props with:
    - `DeviceType` == "DMX" 
    - `Comment`="Mega Tree RGB Tree 48 x 100-360"
    - `Name`="Mega Tree RGB Tree 48 x 100-360"
    - id="e3bdb50f-733e-4c53-bbe2-b30e0eb9363b"
    - `MasterPropId` == ""
    - Keys <PropClass>
      <PropClass id="e3bdb50f-733e-4c53-bbe2-b30e0eb9363b" BulbShape="Square" ChannelGrid="Regular,1,1,300,0,;Regular,2,1,300,0,;Regular,3,1,300,0,;Regular,4,1,300,0,;Regular,5,1,300,0,;Regular,6,1,300,0,;Regular,7,1,300,0,;Regular,8,1,300,0,;Regular,9,1,300,0,;Regular,10,1,300,0,;Regular,11,1,300,0,;Regular,12,1,300,0,;Regular,13,1,300,0,;Regular,14,1,300,0,;Regular,15,1,300,0,;Regular,16,1,300,0,;Regular,17,1,300,0,;Regular,18,1,300,0,;Regular,19,1,300,0,;Regular,20,1,300,0,;Regular,21,1,300,0,;Regular,22,1,300,0,;Regular,23,1,300,0,;Regular,24,1,300,0,;Regular,25,1,300,0,;Regular,26,1,300,0,;Regular,27,1,300,0,;Regular,28,1,300,0,;Regular,29,1,300,0,;Regular,30,1,300,0,;Regular,31,1,300,0,;Regular,32,1,300,0,;Regular,33,1,300,0,;Regular,34,1,300,0,;Regular,35,1,300,0,;Regular,36,1,300,0,;Regular,37,1,300,0,;Regular,38,1,300,0,;Regular,39,1,300,0,;Regular,40,1,300,0,;Regular,41,1,300,0,;Regular,42,1,300,0,;Regular,43,1,300,0,;Regular,44,1,300,0,;Regular,45,1,300,0,;Regular,46,1,300,0,;Regular,47,1,300,0,;Regular,48,1,300,0," Comment="Mega Tree RGB Tree 48 x 100-360" CustomBulbColor="FFFFFF80" DeviceType="DMX" DimmingCurveName="PixelCurve 30%" IndividualChannels="False" LegacySequenceMethod="" MaxChannels="512" Opacity="255" MasterDimmable="True" PreviewBulbSize="2" RgbOrder="RGB order" MasterPropId="" SeparateIds="True" StartLocation="Bottom Left CCW" StringType="RGB" TraditionalColors="" TraditionalType="Multicolor_string_1_ch" EffectBulbSize="1" Tag="RGB Tree 32x50-360" Name="Mega Tree RGB Tree 48 x 100-360" Parm1="48" Parm2="100" Parm3="0" Parm4="10" Parm5="4" Parm6="1" Parm7="4" Parm8="0">
    - Action:  
      - `propID` = id
      - First ChannelGrid Network, UID, Channel, EndChannel, Unknown, Color assigned to master prop
      - Lights = `Parm2` 
      - Assign previewID to prop      
      - Loop through remaining ChannelGrids and create subProps store in subProp table
        - generate UUID for subPropId (Only used to generate unique keys for subprop table)
        - ChannelGrid Network, UID, Channel, EndChannel, Unknown, Color
        - MasterPropId` = id of first prop (master prop)
        -  same comment and place these records into subProps Table
        - `Name` = 'Name' append with 2-digit Channel
        - `Comment` = Comment

**I. Single LOR Display Single ChannelGrid Master Prop**
  If MasterPropID is Null, this is a Master prop and stored in props table if no other master props share the same comment. 
    - Process props with:
      - `DeviceType`== "None"
      - `ChannelGrid` Single Group
      - `Comment`!= `Comment` in props table
      - `MasterPropId`== "" If null this is a master prop
      - Keys <PropClass>
        <PropClass id="34c08039-1307-429c-a86a-8b6a2721b3f5" BulbShape="Square" ChannelGrid="" Comment="Car Counter Arch Red" CustomBulbColor="FFFFFF80" DeviceType="None" DimmingCurveName="None" IndividualChannels="True" LegacySequenceMethod="" MaxChannels="1" Opacity="255" MasterDimmable="True" PreviewBulbSize="2" RgbOrder="RGB order" MasterPropId="" SeparateIds="False" StartLocation="n/a" StringType="Traditional" TraditionalColors="Red" TraditionalType="Multicolor_string_1_ch" EffectBulbSize="1" Tag="" Name="Car Counter Arch Red" Parm1="2" Parm2="1000"></PropClass>
    - Action:  
      - `propID` = id
      - Separate ChannelGrid fields: Network, UID, Channel, EndChannel, Unknown, Color
      - Lights = `Parm2` 
      - Assign previewID to prop
      - Record put in props table