# Script to create database from scratch using LOR preview files
# Created by: Greg Liebig 2025/01/04
# Revision 0.1.0
# Revision 0.1.1 - Added logic to create sub-props from displays with multiple props on a single panel
# using the lowest channel on the display as the master prop 1/14/25

import xml.etree.ElementTree as ET
import os
import sqlite3
from collections import defaultdict

def initialize_database():
    # Connect to the database (do not delete the file)
    conn = sqlite3.connect("LOR.db")
    cursor = conn.cursor()

    # Drop existing tables and views
    cursor.execute("DROP VIEW IF EXISTS LORProps")
    cursor.execute("DROP TABLE IF EXISTS dmxChannels")
    cursor.execute("DROP TABLE IF EXISTS subProps")
    cursor.execute("DROP TABLE IF EXISTS props")
    cursor.execute("DROP TABLE IF EXISTS previews")


    # Create tables for previews, props, subProps, and dmxChannels
    cursor.execute("""
        CREATE TABLE previews (
            id TEXT PRIMARY KEY,
            StageID TEXT,
            PreviewType TEXT,
            Name TEXT,
            Revision TEXT,
            Brightness REAL,
            BackgroundFile TEXT
        )
    """)

    cursor.execute("""
        CREATE TABLE props (
            PropID TEXT PRIMARY KEY,
            Name TEXT,
            DisplayName TEXT,
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
            Attributes TEXT,
            PreviewId TEXT
        )
    """)

    #Revised SubProps table to include UID and StartChannel 1/14/25
    cursor.execute("""
        CREATE TABLE subProps (
            SubPropID TEXT PRIMARY KEY,
            Name TEXT,
            Lights INTEGER,
            DisplayName TEXT,
            Attributes TEXT,
            MasterPropId TEXT,
            PreviewId TEXT,
            UID TEXT,  -- Include UID
            Channel TEXT,  -- Include StartChannel as Channel
            FOREIGN KEY (MasterPropId) REFERENCES props (PropID),
            FOREIGN KEY (PreviewId) REFERENCES previews (id)
        )
    """)

    cursor.execute("""
        CREATE TABLE dmxChannels (
            PropId TEXT,
            Network TEXT,
            StartUniverse INTEGER,
            StartChannel INTEGER,
            EndChannel INTEGER,
            Unknown TEXT,
            Color TEXT,
            FOREIGN KEY (PropId) REFERENCES props (PropID)
        )
    """)

    # Create a view to join props, subProps, and dmxChannels
    cursor.execute("""
        CREATE VIEW LORProps AS
        SELECT 
            p.Name AS PropName,
            p.Network AS PropNetwork,
            p.UID AS Controller,
            p.Channel AS PropStartChannel
        FROM props p
        WHERE p.DeviceType = 'LOR';
    """)

    # Separate the DROP VIEW and CREATE VIEW statements
    # Drop and recreate the view
    cursor.execute("DROP VIEW IF EXISTS PreviewDisplays")
    cursor.execute("""
        CREATE VIEW PreviewDisplays AS
        SELECT 
            pr.Name AS PreviewName,
            p.UID AS PropUID,
            p.StartChannel AS PropStartChannel,
            sp.UID AS SubPropUID,
            sp.Channel AS SubPropChannel,
            p.DisplayName AS PropDisplayName,
            sp.DisplayName AS SubPropDisplayName
        FROM previews pr
        LEFT JOIN props p ON pr.id = p.PreviewId
        LEFT JOIN subProps sp ON p.PropID = sp.MasterPropId
        WHERE sp.Channel IS NOT NULL
        ORDER BY p.DisplayName, sp.Channel;
    """)


    conn.commit()
    return conn

def process_file(file_path, conn):
    # Parse the XML file
    tree = ET.parse(file_path)
    root = tree.getroot()
    preview_id = None  # Initialize PreviewId globally
    
    # Extract structure for previews, props, subProps, and DMX channels
    #previews = {}
    previews = {}  # Initialize as a dictionary
    props = []
    sub_props = []
    dmx_channels = []

    for elem in root.iter():
        if elem.tag == "PreviewClass":
            import re
            # Extract StageID from file name
            stage_match = re.search(r"Stage (\d{2})", os.path.basename(file_path))
            stage_id = stage_match.group(1) if stage_match else None
            
            # Determine preview type from file name
            preview_type = os.path.basename(file_path).split()[0]
            
            # Extract PreviewId and other attributes
            preview_id = elem.attrib.get('id')
            previews[preview_id] = {
                "id": preview_id,
                "StageID": stage_id,
                "PreviewType": preview_type,
                "Name": elem.attrib.get('Name', None),
                "Revision": elem.attrib.get('Revision', None),
                "Brightness": float(elem.attrib.get('Brightness')) if elem.attrib.get('Brightness') else None,
                "BackgroundFile": elem.attrib.get('BackgroundFile', None),
            }

        # Process PropClass elements
        if elem.tag == "PropClass":
            # Extract attributes
            attributes = elem.attrib
            prop_preview_id = attributes.get('PreviewId')
            channel_grid = attributes.get('ChannelGrid', None)
            device_type = attributes.get('DeviceType', None)

            # Initialize variables
            network = uid = StartChannel = EndChannel = unknown = color = None

            # Process ChannelGrid based on DeviceType
            if channel_grid and device_type == "LOR":
                grids = channel_grid.split(';')  # Split multiple grids by ';'
                is_master_set = False  # Track whether the master prop has been added
                processed_display_names = set()  # Track processed DisplayNames to avoid duplicates in props

                for grid_index, grid in enumerate(grids):
                    grid_parts = grid.split(',')
                    network = grid_parts[0] if len(grid_parts) > 0 else None
                    uid = grid_parts[1] if len(grid_parts) > 1 else None
                    StartChannel = ("0" + grid_parts[2])[-2:] if len(grid_parts) > 2 and grid_parts[2].isdigit() else None
                    EndChannel = ("0" + grid_parts[3])[-2:] if len(grid_parts) > 3 and grid_parts[3].isdigit() else None
                    unknown = grid_parts[4] if len(grid_parts) > 4 else None
                    color = grid_parts[5] if len(grid_parts) > 5 else None

                    # Add the first grid as the master prop to the props table
                    if not is_master_set and attributes.get('id') not in processed_display_names:
                        props.append({
                            "PropID": attributes.get('id'),
                            "Name": attributes.get('Name'),
                            "DisplayName": attributes.get('Comment'),
                            "DeviceType": device_type,
                            "PreviewId": prop_preview_id,
                            "MaxChannels": int(attributes.get('MaxChannels')) if attributes.get('MaxChannels') else None,
                            "Tag": attributes.get('Tag'),
                            "Network": network,
                            "UID": uid,
                            "StartChannel": StartChannel,
                            "EndChannel": EndChannel,
                            "Unknown": unknown,
                            "Color": color,
                            "Lights": int(attributes.get('Parm2')) if attributes.get('Parm2') else None,
                            "DimmingCurveName": attributes.get('DimmingCurveName'),
                            "Segments": int(attributes.get('Parm1')) if attributes.get('Parm1') else None,
                            "Opacity": float(attributes.get('Opacity')) if attributes.get('Opacity') else None,
                            "MasterDimmable": attributes.get('MasterDimmable') == 'true',
                            "PreviewBulbSize": float(attributes.get('PreviewBulbSize')) if attributes.get('PreviewBulbSize') else None,
                            "BulbShape": attributes.get('BulbShape'),
                            "CustomBulbColor": attributes.get('CustomBulbColor'),
                            "StartLocation": attributes.get('StartLocation'),
                            "StringType": attributes.get('StringType'),
                            "TraditionalColors": attributes.get('TraditionalColors'),
                            "TraditionalType": attributes.get('TraditionalType'),
                            "RgbOrder": attributes.get('RgbOrder'),
                            "SeparateIds": attributes.get('SeparateIds'),
                            "EffectBulbSize": float(attributes.get('EffectBulbSize')) if attributes.get('EffectBulbSize') else None,
                            "IndividualChannels": attributes.get('IndividualChannels', '').strip().lower() == 'true',
                            "LegacySequenceMethod": attributes.get('LegacySequenceMethod'),
                            "MasterPropId": attributes.get('MasterPropId'),
                            "Attributes": str(attributes)
                        })
                        is_master_set = True  # Mark the master prop as added
                        processed_display_names.add(attributes.get('Comment'))  # Track the DisplayName
                    else:
                        # Add subsequent grids as subprops
                        sub_props.append({
                            "SubPropID": f"{attributes.get('id')}-{StartChannel}",
                            "Name": f"{attributes.get('Name')} - {StartChannel}",
                            "DisplayName": f"{attributes.get('Comment')} - {StartChannel}",
                            "Attributes": str(attributes),
                            "MasterPropId": attributes.get('id'),
                            "PreviewId": prop_preview_id,
                            "UID": uid,
                            "Channel": StartChannel,
                            "Color": color,
                        })

            # Group props by DisplayName for props without MasterPropId
            grouped_props = defaultdict(list)
            for prop in props:
                if prop.get("DisplayName") and not prop.get("MasterPropId"):
                    grouped_props[prop["DisplayName"]].append(prop)

            # Process each group to determine master props and create subprops
            for display_name, group in grouped_props.items():
                if len(group) > 1:
                    # Find the master prop (lowest StartChannel)
                    master_prop = min(group, key=lambda x: int(x["StartChannel"]) if x["StartChannel"] else float('inf'))
                    master_prop_id = master_prop["PropID"]

                    # Ensure the master prop remains in the props table
                    props = [p for p in props if p["PropID"] != master_prop_id or p["DisplayName"] != display_name]

                    # Create subprops for the remaining props in the group
                    for prop in group:
                        if prop["PropID"] != master_prop_id:
                            sub_props.append({
                                "SubPropID": f"{prop['PropID']}-{prop['StartChannel']}",
                                "Name": prop["Name"],
                                "DisplayName": prop["DisplayName"],
                                "Attributes": prop["Attributes"],
                                "MasterPropId": master_prop_id,
                                "PreviewId": prop["PreviewId"],
                                "UID": prop.get("UID"),
                                "Channel": prop["StartChannel"],
                                "Color": prop.get("Color"),
                            })



                        # After extracting props and before inserting into the database
                        # Group props by DisplayName for props without a MasterPropId
                        # Separate props with and without MasterPropId
                        props_with_master = []
                        props_without_master = []

                        for prop in props:
                            if prop.get("MasterPropId"):
                                # Add props with MasterPropId directly to subProps
                                props_with_master.append(prop)
                            else:
                                # Group props without MasterPropId by DisplayName
                                props_without_master.append(prop)

                        # Process props with MasterPropId
                        for prop in props_with_master:
                            grids = prop.get("ChannelGrid", "").split(';')
                            for grid in grids:
                                grid_parts = grid.split(',')
                                sub_props.append({
                                    "SubPropID": f"{prop['PropID']}-{grid_parts[2] if len(grid_parts) > 2 else '00'}",
                                    "Name": f"{prop['Name']} - {grid_parts[2] if len(grid_parts) > 2 else '00'}",
                                    "DisplayName": f"{prop['DisplayName']} - {grid_parts[2] if len(grid_parts) > 2 else '00'}",
                                    "Attributes": prop["Attributes"],
                                    "MasterPropId": prop["MasterPropId"],
                                    "PreviewId": prop["PreviewId"],
                                    "UID": grid_parts[1] if len(grid_parts) > 1 else None,
                                    "Channel": grid_parts[2] if len(grid_parts) > 2 else None,
                                    "Color": grid_parts[5] if len(grid_parts) > 5 else None,
                                })

                        # Group props without MasterPropId by DisplayName
                        grouped_props = defaultdict(list)
                        for prop in props_without_master:
                            if prop.get("DisplayName"):
                                grouped_props[prop["DisplayName"]].append(prop)

                        # Process each group to determine master props and create subprops
                        for display_name, group in grouped_props.items():
                            # Find the master prop (lowest StartChannel)
                            master_prop = min(group, key=lambda x: int(x["StartChannel"]) if x["StartChannel"] else float('inf'))
                            master_prop_id = master_prop["PropID"]

                            # Create subprops for the remaining props in the group
                            for prop in group:
                                if prop["PropID"] != master_prop_id:
                                    sub_props.append({
                                        "SubPropID": f"{prop['PropID']}-{prop['StartChannel']}",
                                        "Name": prop["Name"],
                                        "DisplayName": prop["DisplayName"],
                                        "Attributes": prop["Attributes"],
                                        "MasterPropId": master_prop_id,
                                        "PreviewId": prop["PreviewId"],
                                        "UID": prop.get("UID"),
                                        "Channel": prop["StartChannel"],
                                        "Color": prop.get("Color"),
                                    })


            # Master props remain in the `props` table, subprops are added to the `sub_props` list



    # Insert data into the database
    cursor = conn.cursor()

    # Insert previews
    cursor.executemany(
        """
        INSERT OR IGNORE INTO previews (id, StageID, PreviewType, Name, Revision, Brightness, BackgroundFile)
        VALUES (?, ?, ?, ?, ?, ?, ?)
        """,
        [
            (
                preview['id'], preview['StageID'], preview['PreviewType'], preview['Name'], 
                preview['Revision'], preview['Brightness'], preview['BackgroundFile']
            )
            for preview in previews.values()
        ]
    )

    # Insert props
    cursor.executemany(
        """
        INSERT OR IGNORE INTO props 
        (PropID, Name, DisplayName, DeviceType, MaxChannels, Tag, Network, UID, StartChannel, EndChannel, Unknown, Color, Lights, DimmingCurveName, Segments, Opacity, MasterDimmable, PreviewBulbSize, BulbShape, CustomBulbColor, StartLocation, StringType, TraditionalColors, TraditionalType, RgbOrder, SeparateIds, EffectBulbSize, IndividualChannels, LegacySequenceMethod, MasterPropId, Attributes, PreviewId) 
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        [
            (
                prop['PropID'], prop['Name'], prop['DisplayName'], prop['DeviceType'], prop['MaxChannels'], prop['Tag'],
                prop['Network'], prop['UID'], prop['StartChannel'], prop['EndChannel'], prop['Unknown'], prop['Color'],
                prop['Lights'], prop['DimmingCurveName'], prop['Segments'], prop['Opacity'], prop['MasterDimmable'],
                prop['PreviewBulbSize'], prop['BulbShape'], prop['CustomBulbColor'], prop['StartLocation'], prop['StringType'],
                prop['TraditionalColors'], prop['TraditionalType'], prop['RgbOrder'], prop['SeparateIds'],
                prop['EffectBulbSize'], prop['IndividualChannels'], prop['LegacySequenceMethod'], prop['MasterPropId'],
                prop['Attributes'], prop['PreviewId']  # Include PreviewId
            )
            for prop in props
        ]
    )

    # Insert subprops with UID and Channel
    cursor.executemany(
        """
        INSERT OR IGNORE INTO subProps 
        (SubPropID, Name, Lights, DisplayName, Attributes, MasterPropId, PreviewId, UID, Channel) 
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        [
            (
                sub_prop['SubPropID'], sub_prop['Name'], sub_prop.get('Lights'), sub_prop.get('DisplayName'),
                sub_prop.get('Attributes'), sub_prop['MasterPropId'], sub_prop.get('PreviewId'), sub_prop.get('UID'),
                sub_prop.get('Channel')
            )
            for sub_prop in sub_props
        ]
    )


    # Insert DMX channels
    cursor.executemany(
        "INSERT OR IGNORE INTO dmxChannels (PropId, Network, StartUniverse, StartChannel, EndChannel, Unknown, Color) VALUES (?, ?, ?, ?, ?, ?, ?)",
        [(dmx['PropId'], dmx['Network'], dmx['StartUniverse'], dmx['StartChannel'], dmx['EndChannel'], dmx['Unknown'], dmx['Color']) for dmx in dmx_channels]
    )

    conn.commit()

def process_folder(folder_path):
    # Initialize the database
    conn = initialize_database()

    # Process all .lorprev files in the specified folder
    for file_name in os.listdir(folder_path):
        if file_name.lower().endswith(".lorprev"):
            file_path = os.path.join(folder_path, file_name)
            print(f"Processing file: {file_path}")
            process_file(file_path, conn)

    conn.close()
    print(f"Processing complete. Data saved to {os.path.abspath('LOR.db')}")

if __name__ == "__main__":
    folder_path = input("Enter the folder path containing .lorprev files: ")
    process_folder(folder_path)


