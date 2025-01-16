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

**Preview Definition**:
    <PreviewClass id="b847c70c-6134-4bb1-8dba-992405d014f5" BackgroundFile="" Brightness="5" Revision="65" Name="RGB Plus Prop Stage 07 Whoville "></PreviewClass>
   - Process previews:
     - Previews contain all the props grouped by a themed stage
   - Action:  
     - Get Stage number from Name
     - Get Stage type from Name
     - Save id to every prop and subprop record as a foreign Key
     - These records are stored in the Previews table


1. **Props Definition**:
  <PropClass id="971f5ddf-9918-4287-8e19-3743d2f91e56" BulbShape="Square" ChannelGrid="Aux I,B4,15,15,0,Green" Comment="Who House Grinch" CustomBulbColor="FFFFFF80" DeviceType="LOR" DimmingCurveName="None" IndividualChannels="True" LegacySequenceMethod="" MaxChannels="16" Opacity="255" MasterDimmable="True" PreviewBulbSize="2" RgbOrder="RGB order" MasterPropId="" SeparateIds="False" StartLocation="n/a" StringType="Traditional" TraditionalColors="Green" TraditionalType="Multicolor_string_1_ch" EffectBulbSize="1" Tag="FaceV2-Felix Tree Outline" Name="Who House Grinch" Parm1="43" Parm2="100"> </PropClass>
   - Process props with:
     - `devicetype == LOR`
     - Same `LORComment`
     - Single ChannelGrid
     - `MasterPropId` Does Not Exist
   - Action:  
     - Separate ChannelGrid fields: Network, UID, Channel, EndChannel, Unknown, Color
     - Parm1 containts segments INTEGER
     - Parm2 contains light count INTEGER
     - These props are subprops and should be placed in the `subprops` table, linked to the `id` prop.



2. **SubProps Definition**:
<PropClass id="0e3971ac-63dc-46c4-8c4b-325d8df57470" BulbShape="Square" ChannelGrid="Aux I,B4,15,15,0,Red" Comment="Who House Grinch" CustomBulbColor="FFFFFF80" DeviceType="LOR" DimmingCurveName="None" IndividualChannels="True" LegacySequenceMethod="" MaxChannels="16" Opacity="255" MasterDimmable="True" PreviewBulbSize="2" RgbOrder="RGB order" MasterPropId="971f5ddf-9918-4287-8e19-3743d2f91e56" SeparateIds="False" StartLocation="n/a" StringType="Traditional" TraditionalColors="Red" TraditionalType="Multicolor_string_1_ch" EffectBulbSize="1" Tag="" Name="Who House Grinch Hat" Parm1="31" Parm2="100"> </PropClass>
   - Process props with:
     - Same `LORComment`
     - `devicetype == LOR`
     - Single ChannelGrid
     - `MasterPropId` exists
   - Action:  
     - Separate ChannelGrid fields: Network, UID, Channel, EndChannel, Unknown, Color
     - These props are subprops and should be placed in the `subprops` table, linked to the `id` prop.

  <PropClass id="182b09f0-e5c8-48f8-89bb-577a38f2d3d4" BulbShape="Square" ChannelGrid="Aux I,BB,1,1,0,Green;Aux I,BB,2,2,0,Green;Aux I,BB,3,3,0,Green;Aux I,BB,4,4,0,Green;Aux I,BB,5,5,0,Green;Aux I,BB,6,6,0,Green;Aux I,BB,7,7,0,Green;Aux I,BB,8,8,0,Green" Comment="Spiral Tree Grn" CustomBulbColor="FFFFFF80" DeviceType="LOR" DimmingCurveName="None" IndividualChannels="True" LegacySequenceMethod="" MaxChannels="512" Opacity="255" MasterDimmable="True" PreviewBulbSize="2" RgbOrder="RGB order" MasterPropId="" SeparateIds="False" StartLocation="Bottom Left" StringType="Traditional" TraditionalColors="Green" TraditionalType="Channel_per_color" EffectBulbSize="1" Tag="03.01 AC Light Curtain (8 Strands) - Group A" Name="Who Tree Grn 01-08 Group A" Parm1="8" Parm2="100" Parm3="0" Parm4="0"> </PropClass>




2. **Grouped Props with Repeating `Comment`** (**Current Issue**):
<PropClass id="7d41589f-5fc4-4657-9cb1-c968384e7cb7" BulbShape="Hexagon" ChannelGrid="Aux I,B1,6,6,0,Blue" Comment="Who Panel 1" CustomBulbColor="FFFFFF80" DeviceType="LOR" DimmingCurveName="None" IndividualChannels="True" LegacySequenceMethod="" MaxChannels="512" Opacity="255" MasterDimmable="True" PreviewBulbSize="3" RgbOrder="RGB order" MasterPropId="" SeparateIds="False" StartLocation="n/a" StringType="Traditional" TraditionalColors="Blue" TraditionalType="Channel_per_color" EffectBulbSize="1" Tag="" Name="Who Hand 16 Inside Mid" Parm1="2" Parm2="100">
  </PropClass>
   - Process props with:
     - Repeating `Comment` in separate PropClass records
     - `DeviceType == LOR`
     - Single ChannelGrid
     - No `masterpropID`
   - Action:
     - Group props by `LORComment`.
     - Create a derived master prop using the lowest channel number in the group.
     - Place the master prop in the `props` table.
     - Move remaining props in the group to the `subprops` table, linking them to the master prop.

Same Display Single ChannelGrid
    Who House Grinch
    DeviceType="LOR"
    Name="Who House Grinch"
    Comment="Who House Grinch" 
    MasterPropId=""
        <PropClass id="971f5ddf-9918-4287-8e19-3743d2f91e56" BulbShape="Square" ChannelGrid="Aux I,B4,15,15,0,Green" Comment="Who House Grinch" CustomBulbColor="FFFFFF80" DeviceType="LOR" DimmingCurveName="None" IndividualChannels="True" LegacySequenceMethod="" MaxChannels="16" Opacity="255" MasterDimmable="True" PreviewBulbSize="2" RgbOrder="RGB order" MasterPropId="" SeparateIds="False" StartLocation="n/a" StringType="Traditional" TraditionalColors="Green" TraditionalType="Multicolor_string_1_ch" EffectBulbSize="1" Tag="FaceV2-Felix Tree Outline" Name="Who House Grinch" Parm1="43" Parm2="100">

    Who House Grinch subProp
    DeviceType="LOR"
    Name="Who House Grinch Hat"
    Comment="Who House Grinch"
    MasterPropId="971f5ddf-9918-4287-8e19-3743d2f91e56" 
        <PropClass id="0e3971ac-63dc-46c4-8c4b-325d8df57470" BulbShape="Square" ChannelGrid="Aux I,B4,15,15,0,Red" Comment="Who House Grinch" CustomBulbColor="FFFFFF80" DeviceType="LOR" DimmingCurveName="None" IndividualChannels="True" LegacySequenceMethod="" MaxChannels="16" Opacity="255" MasterDimmable="True" PreviewBulbSize="2" RgbOrder="RGB order" MasterPropId="971f5ddf-9918-4287-8e19-3743d2f91e56" SeparateIds="False" StartLocation="n/a" StringType="Traditional" TraditionalColors="Red" TraditionalType="Multicolor_string_1_ch" EffectBulbSize="1" Tag="" Name="Who House Grinch Hat" Parm1="31" Parm2="100"> </PropClass>

    Singing Tree Ralphie
    DeviceType="LOR"
    Name="GG24-Ralphie Tree Outline"
    Comment "GG24-Ralphie"
    MasterPropId=""
        <PropClass id="78871a1d-cae0-419a-8ccc-019d08b402b7" BulbShape="Octogon" ChannelGrid="Aux C,24,1,3,0," Comment="GG24-Ralphie" CustomBulbColor="FF80FFFF" DeviceType="LOR" DimmingCurveName="PixelCurve 30%" IndividualChannels="True" LegacySequenceMethod="" MaxChannels="512" Opacity="255" MasterDimmable="True" PreviewBulbSize="2" RgbOrder="RGB order" MasterPropId="" SeparateIds="False" StartLocation="n/a" StringType="DumbRGB" TraditionalColors="" TraditionalType="Multicolor_string_1_ch" EffectBulbSize="1" Tag="Face-Ralphie Tree Outline" Name="GG24-Ralphie Tree Outline" Parm1="76" Parm2="84"></PropClass>  

    Singing Tree Ralphie Eyes
    DeviceType="LOR"
    Name="GG24-Ralphie Eyes Open"
    Comment="GG24-Ralphie"
    MasterPropId=""
        <PropClass id="f81dcbbb-9524-43ee-9404-ee8b68b4dfad" BulbShape="Octogon" ChannelGrid="Aux C,24,10,12,0," Comment="GG24-Ralphie" CustomBulbColor="FF80FFFF" DeviceType="LOR" DimmingCurveName="PixelCurve 30%" IndividualChannels="True" LegacySequenceMethod="" MaxChannels="512" Opacity="255" MasterDimmable="True" PreviewBulbSize="2" RgbOrder="RGB order" MasterPropId="" SeparateIds="False" StartLocation="n/a" StringType="DumbRGB" TraditionalColors="" TraditionalType="Multicolor_string_1_ch" EffectBulbSize="1" Tag="Face-Ralphie Eyes Open" Name="GG24-Ralphie Eyes Open" Parm1="36" Parm2="38"> </PropClass>


Different Displays Single ChannelGrid with Subprop
    RGB candycane master prop
    DeviceType="LOR"
    Name="CL 21 RGB Candy Cane 01"
    Comment="CL RGB Candy Cane 01"
    MasterPropId=""
        <PropClass id="42b87e29-46da-4d42-8627-67b411e15890" BulbShape="Octogon" ChannelGrid="Aux A,21,1,144,0," Comment="CL RGB Candy Cane 01" CustomBulbColor="FFFFFF80" DeviceType="LOR" DimmingCurveName="PixelCurve 30%" IndividualChannels="False" LegacySequenceMethod="" MaxChannels="510" Opacity="255" MasterDimmable="True" PreviewBulbSize="7" RgbOrder="RGB order" MasterPropId="" SeparateIds="False" StartLocation="n/a" StringType="RGB" TraditionalColors="" TraditionalType="Multicolor_string_1_ch" EffectBulbSize="1" Tag="RGB Candy Cane 01" Name="CL 21 RGB Candy Cane 01" Parm1="0">

    RGB candycane subprop
    Name="CL RGB Candy Cane 05" 
    Comment="CL RGB Candy Cane 05"
    MasterPropId="42b87e29-46da-4d42-8627-67b411e15890" links MasterPropID to id of Name="CL 21 RGB Candy Cane 01"
        <PropClass id="348f503f-fbdd-4903-a85e-cfef9ee1821b" BulbShape="Octogon" ChannelGrid="Aux A,21,1,144,0," Comment="CL RGB Candy Cane 05" CustomBulbColor="FFFFFF80" DeviceType="LOR" DimmingCurveName="PixelCurve 30%" IndividualChannels="False" LegacySequenceMethod="" MaxChannels="510" Opacity="255" MasterDimmable="True" PreviewBulbSize="7" RgbOrder="RGB order" MasterPropId="42b87e29-46da-4d42-8627-67b411e15890" SeparateIds="False" StartLocation="n/a" StringType="RGB" TraditionalColors="" TraditionalType="Multicolor_string_1_ch" EffectBulbSize="1" Tag="RGB Candy Cane 01" Name="CL 21 RGB Candy Cane 05" Parm1="0">


Different Displays multiple ChannelGrids Single Prop

  <PropClass id="182b09f0-e5c8-48f8-89bb-577a38f2d3d4" BulbShape="Square" ChannelGrid="Aux I,BB,1,1,0,Green;Aux I,BB,2,2,0,Green;Aux I,BB,3,3,0,Green;Aux I,BB,4,4,0,Green;Aux I,BB,5,5,0,Green;Aux I,BB,6,6,0,Green;Aux I,BB,7,7,0,Green;Aux I,BB,8,8,0,Green" Comment="Spiral Tree Grn" CustomBulbColor="FFFFFF80" DeviceType="LOR" DimmingCurveName="None" IndividualChannels="True" LegacySequenceMethod="" MaxChannels="16" Opacity="255" MasterDimmable="True" PreviewBulbSize="2" RgbOrder="RGB order" MasterPropId="" SeparateIds="False" StartLocation="Bottom Left" StringType="Traditional" TraditionalColors="Green" TraditionalType="Channel_per_color" EffectBulbSize="1" Tag="03.01 AC Light Curtain (8 Strands) - Group A" Name="Who Tree Grn 01-08 Group A" Parm1="8" Parm2="100" Parm3="0" Parm4="0"></PropClass>

    <PropClass id="182b09f0-e5c8-48f8-89bb-577a38f2d3d4" BulbShape="Square" ChannelGrid="Aux I,BB,1,1,0,Green;Aux I,BB,2,2,0,Green;Aux I,BB,3,3,0,Green;Aux I,BB,4,4,0,Green;Aux I,BB,5,5,0,Green;Aux I,BB,6,6,0,Green;Aux I,BB,7,7,0,Green;Aux I,BB,8,8,0,Green;Aux I,BB,9,9,0,Green;Aux I,BB,10,10,0,Green;Aux I,BB,11,11,0,Green;Aux I,BB,12,12,0,Green;Aux I,BB,13,13,0,Green;Aux I,BB,14,14,0,Green;Aux I,BB,15,15,0,Green;Aux I,BB,16,16,0,Green" Comment="Spiral Tree Grn" CustomBulbColor="FFFFFF80" DeviceType="LOR" DimmingCurveName="None" IndividualChannels="True" LegacySequenceMethod="" MaxChannels="16" Opacity="255" MasterDimmable="True" PreviewBulbSize="2" RgbOrder="RGB order" MasterPropId="" SeparateIds="False" StartLocation="Bottom Back CCW" StringType="Traditional" TraditionalColors="Green" TraditionalType="Multicolor_string_1_ch" EffectBulbSize="1" Tag="03.09 AC Light Curtain (8 Strands) - Group B" Name="Who Tree Grp B Grn 01-16" Parm1="16" Parm2="100" Parm3="50" Parm4="0" Parm5="0">

DMX
<PropClass id="35caca41-289a-46f2-aa3d-17ebe849c6a4" BulbShape="Square" ChannelGrid="Regular,65,1,150,0,;Regular,66,1,150,0,;Regular,67,1,150,0,;Regular,68,1,150,0,;Regular,69,1,150,0,;Regular,70,1,150,0,;Regular,71,1,150,0,;Regular,72,1,150,0,;Regular,73,1,150,0,;Regular,74,1,150,0,;Regular,75,1,150,0,;Regular,76,1,150,0,;Regular,77,1,150,0,;Regular,78,1,150,0,;Regular,79,1,150,0,;Regular,80,1,150,0,;Regular,81,1,150,0,;Regular,82,1,150,0,;Regular,83,1,150,0,;Regular,84,1,150,0,;Regular,85,1,150,0,;Regular,86,1,150,0,;Regular,87,1,150,0,;Regular,88,1,150,0,;Regular,89,1,150,0,;Regular,90,1,150,0,;Regular,91,1,150,0,;Regular,92,1,150,0," Comment="Mega Cube Side" CustomBulbColor="FFFFFF80" DeviceType="DMX" DimmingCurveName="PixelCurve 30%" IndividualChannels="False" LegacySequenceMethod="" MaxChannels="512" Opacity="255" MasterDimmable="True" PreviewBulbSize="4" RgbOrder="RGB order" MasterPropId="" SeparateIds="True" StartLocation="Bottom Right" StringType="RGB" TraditionalColors="" TraditionalType="Multicolor_string_1_ch" EffectBulbSize="1" Tag="RGB Matrix 20x40" Name="Mega Cube Side" Parm1="28" Parm2="50" Parm3="0" Parm4="0">

  <PropClass id="e3bdb50f-733e-4c53-bbe2-b30e0eb9363b" BulbShape="Square" ChannelGrid="Regular,1,1,300,0,;Regular,2,1,300,0,;Regular,3,1,300,0,;Regular,4,1,300,0,;Regular,5,1,300,0,;Regular,6,1,300,0,;Regular,7,1,300,0,;Regular,8,1,300,0,;Regular,9,1,300,0,;Regular,10,1,300,0,;Regular,11,1,300,0,;Regular,12,1,300,0,;Regular,13,1,300,0,;Regular,14,1,300,0,;Regular,15,1,300,0,;Regular,16,1,300,0,;Regular,17,1,300,0,;Regular,18,1,300,0,;Regular,19,1,300,0,;Regular,20,1,300,0,;Regular,21,1,300,0,;Regular,22,1,300,0,;Regular,23,1,300,0,;Regular,24,1,300,0,;Regular,25,1,300,0,;Regular,26,1,300,0,;Regular,27,1,300,0,;Regular,28,1,300,0,;Regular,29,1,300,0,;Regular,30,1,300,0,;Regular,31,1,300,0,;Regular,32,1,300,0,;Regular,33,1,300,0,;Regular,34,1,300,0,;Regular,35,1,300,0,;Regular,36,1,300,0,;Regular,37,1,300,0,;Regular,38,1,300,0,;Regular,39,1,300,0,;Regular,40,1,300,0,;Regular,41,1,300,0,;Regular,42,1,300,0,;Regular,43,1,300,0,;Regular,44,1,300,0,;Regular,45,1,300,0,;Regular,46,1,300,0,;Regular,47,1,300,0,;Regular,48,1,300,0," Comment="Mega Tree RGB Tree 48 x 100-360" CustomBulbColor="FFFFFF80" DeviceType="DMX" DimmingCurveName="PixelCurve 30%" IndividualChannels="False" LegacySequenceMethod="" MaxChannels="512" Opacity="255" MasterDimmable="True" PreviewBulbSize="2" RgbOrder="RGB order" MasterPropId="" SeparateIds="True" StartLocation="Bottom Left CCW" StringType="RGB" TraditionalColors="" TraditionalType="Multicolor_string_1_ch" EffectBulbSize="1" Tag="RGB Tree 32x50-360" Name="Mega Tree RGB Tree 48 x 100-360" Parm1="48" Parm2="100" Parm3="0" Parm4="10" Parm5="4" Parm6="1" Parm7="4" Parm8="0">


<PropClass id="909a9ae3-1e1e-486c-8b6a-56331d012172" BulbShape="Square" ChannelGrid="" Comment="Bright 1" CustomBulbColor="FFFFFF80" DeviceType="None" DimmingCurveName="None" IndividualChannels="True" LegacySequenceMethod="" MaxChannels="4" Opacity="255" MasterDimmable="True" PreviewBulbSize="2" RgbOrder="RGB order" MasterPropId="" SeparateIds="False" StartLocation="n/a" StringType="Traditional" TraditionalColors="White" TraditionalType="Multicolor_string_1_ch" EffectBulbSize="1" Tag="" Name="QV Bright a-B" Parm1="29" Parm2="100">



  <PropClass id="158dd202-f80e-42ec-b473-916422a6e8c7" BulbShape="Square" ChannelGrid="" Comment="Bright 1" CustomBulbColor="FFFFFF80" DeviceType="None" DimmingCurveName="None" IndividualChannels="True" LegacySequenceMethod="" MaxChannels="4" Opacity="255" MasterDimmable="True" PreviewBulbSize="2" RgbOrder="RGB order" MasterPropId="909a9ae3-1e1e-486c-8b6a-56331d012172" SeparateIds="False" StartLocation="n/a" StringType="Traditional" TraditionalColors="White" TraditionalType="Multicolor_string_1_ch" EffectBulbSize="1" Tag="" Name="QV Bright b-R" Parm1="31" Parm2="100">
    <shape ShapeName="Lines-Connected">