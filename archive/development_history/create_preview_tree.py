# Script to create database from scratch using LOR preview files
# Created by: Greg Liebig 2025/01/04
# Revision 0.1.0

import xml.etree.ElementTree as ET
import os
import sqlite3

def initialize_database():
    #Delete existing database file to ensure a clean start
    if os.path.exists("LOR.db"):
        os.remove("LOR.db")

    #Connect to the database (do not delete the file)
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
            Attributes TEXT
        )
    """)

    cursor.execute("""
        CREATE TABLE subProps (
            SubPropID TEXT PRIMARY KEY,
            Name TEXT,
            Lights INTEGER,
            DisplayName TEXT,
            Attributes TEXT,
            MasterPropId TEXT,
            PreviewId TEXT,
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
            p.UID AS PropUID,
            p.StartChannel AS PropStartChannel
        FROM props p
        WHERE p.DeviceType = 'LOR';
    """)

    conn.commit()
    return conn

def process_file(file_path, conn):
    # Parse the XML file
    tree = ET.parse(file_path)
    root = tree.getroot()

    # Extract structure for previews, props, subProps, and DMX channels
    previews = []
    props = []
    sub_props = []
    dmx_channels = []
    for elem in root.iter():
        if elem.tag == "PreviewClass":
            import re
            stage_match = re.search(r"Stage (\d{2})", os.path.basename(file_path))
            stage_id = stage_match.group(1) if stage_match else None
            
            preview_type = os.path.basename(file_path).split()[0]

            previews.append({
                "id": elem.attrib.get('id'),
                "StageID": stage_id,
                "PreviewType": preview_type,
                "Name": elem.attrib.get('Name', None),
                "Revision": elem.attrib.get('Revision', None),
                "Brightness": float(elem.attrib.get('Brightness')) if elem.attrib.get('Brightness') else None,
                "BackgroundFile": elem.attrib.get('BackgroundFile', None),
                
            })

        if elem.tag == "PropClass":
            # Extract attributes
            attributes = elem.attrib

            # Initialize variables
            network = uid = StartChannel = EndChannel = unknown = color = None

            # Extract DeviceType
            device_type = attributes.get('DeviceType', None)

            # Parse 'ChannelGrid' based on DeviceType
            channel_grid = attributes.get('ChannelGrid', None)
            if channel_grid and device_type == "LOR":
                grid_parts = channel_grid.split(',')
                network = grid_parts[0] if len(grid_parts) > 0 else None
                uid = grid_parts[1] if len(grid_parts) > 1 else None
                StartChannel = ("0" + grid_parts[2])[-2:] if len(grid_parts) > 2 and grid_parts[2].isdigit() else None
                EndChannel = ("0" + grid_parts[3])[-2:] if len(grid_parts) > 3 and grid_parts[3].isdigit() else None
                unknown = grid_parts[4] if len(grid_parts) > 4 else None
                color = grid_parts[5] if len(grid_parts) > 5 else None
            elif channel_grid and device_type == "DMX":
                grids = channel_grid.split(';')
                for grid in grids:
                    grid_parts = grid.split(',')
                    dmx_channels.append({
                        "PropId": attributes.get('id'),
                        "Network": grid_parts[0] if len(grid_parts) > 0 else None,
                        "StartUniverse": int(grid_parts[1]) if len(grid_parts) > 1 and grid_parts[1].isdigit() else None,
                        "StartChannel": int(grid_parts[2]) if len(grid_parts) > 2 and grid_parts[2].isdigit() else None,
                        "EndChannel": int(grid_parts[3]) if len(grid_parts) > 3 and grid_parts[3].isdigit() else None,
                        "Unknown": grid_parts[4] if len(grid_parts) > 4 else None,
                        "Color": grid_parts[5] if len(grid_parts) > 5 else None
                    })

            # Extract fields from attributes
            if attributes.get('MasterPropId'):
                sub_props.append({
                    "SubPropID": attributes.get('id'),
                    "Name": attributes.get('Name', None),
                    "Lights": int(attributes.get('Parm2')) if attributes.get('Parm2') else None,
                    "DisplayName": attributes.get('Comment', None),
                    "Attributes": str(attributes),
                    "MasterPropId": attributes.get('MasterPropId'),
                    "PreviewId": attributes.get('PreviewId', None)
                })
            else:
                props.append({
                    "PropID": attributes.get('id'),
                    "Name": attributes.get('Name'),
                    "DisplayName": attributes.get('Comment'),
                    "DeviceType": device_type,
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

    # Insert data into the database
    cursor = conn.cursor()

    # Insert previews
    cursor.executemany(
        "INSERT OR IGNORE INTO previews (id, StageID, PreviewType, Name, Revision, Brightness, BackgroundFile) VALUES (?, ?, ?, ?, ?, ?, ?)",
        [(preview['id'], preview['StageID'], preview['PreviewType'], preview['Name'], preview['Revision'], preview['Brightness'], preview['BackgroundFile']) for preview in previews]
    )

    # Insert props
    cursor.executemany(
        "INSERT OR IGNORE INTO props (PropID, Name, DisplayName, DeviceType, MaxChannels, Tag, Network, UID, StartChannel, EndChannel, Unknown, Color, Lights, DimmingCurveName, Segments, Opacity, MasterDimmable, PreviewBulbSize, BulbShape, CustomBulbColor, StartLocation, StringType, TraditionalColors, TraditionalType, RgbOrder, SeparateIds, EffectBulbSize, IndividualChannels, LegacySequenceMethod, MasterPropId, Attributes) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
        [(prop['PropID'], prop['Name'], prop['DisplayName'], prop['DeviceType'], prop['MaxChannels'], prop['Tag'], prop['Network'], prop['UID'], prop['StartChannel'], prop['EndChannel'], prop['Unknown'], prop['Color'], prop['Lights'], prop['DimmingCurveName'], prop['Segments'], prop['Opacity'], prop['MasterDimmable'], prop['PreviewBulbSize'], prop['BulbShape'], prop['CustomBulbColor'], prop['StartLocation'], prop['StringType'], prop['TraditionalColors'], prop['TraditionalType'], prop['RgbOrder'], prop['SeparateIds'], prop['EffectBulbSize'], prop['IndividualChannels'], prop['LegacySequenceMethod'], prop['MasterPropId'], prop['Attributes']) for prop in props]
    )

    # Insert sub-props
    cursor.executemany(
        "INSERT OR IGNORE INTO subProps (SubPropID, Name, Lights, DisplayName, Attributes, MasterPropId, PreviewId) VALUES (?, ?, ?, ?, ?, ?, ?)",
        [(sub_prop['SubPropID'], sub_prop['Name'], sub_prop['Lights'], sub_prop['DisplayName'], sub_prop['Attributes'], sub_prop['MasterPropId'], sub_prop['PreviewId']) for sub_prop in sub_props]
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

