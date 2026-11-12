# Script to regenerate tables in LOR.db using LOR preview files
# Created by: Greg Liebig 2025/01/04
# Revision 0.0.1

import xml.etree.ElementTree as ET
import os
import sqlite3

def initialize_database():
    # Connect to the database (do not delete the file)
    conn = sqlite3.connect("LOR.db")
    cursor = conn.cursor()

    # Drop existing tables
    # cursor.execute("DROP VIEW IF EXISTS LORProps")
    cursor.execute("DROP TABLE IF EXISTS dmxChannels")
    cursor.execute("DROP TABLE IF EXISTS fixtures")
    cursor.execute("DROP TABLE IF EXISTS props")
    cursor.execute("DROP TABLE IF EXISTS previews")

    # Create tables for previews, props, fixtures, and dmxChannels
    cursor.execute("""
        CREATE TABLE previews (
            id TEXT PRIMARY KEY,
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
            Comment TEXT,
            DeviceType TEXT,
            MaxChannels INTEGER,
            Tag TEXT,
            Network TEXT,
            UID TEXT,
            StartChannel INTEGER,
            EndChannel INTEGER,
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
        CREATE TABLE fixtures (
            FixtureID TEXT PRIMARY KEY,
            Name TEXT,
            Lights INTEGER,
            Comment TEXT,
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
            Start_Unv INTEGER,
            Start_Channel INTEGER,
            End_Channel INTEGER,
            Unknown TEXT,
            Color TEXT,
            FOREIGN KEY (PropId) REFERENCES props (PropID)
        )
    """)

    # Create a view to join props, fixtures, and dmxChannels
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

    # Extract structure for previews, props, fixtures, and DMX channels
    previews = []
    props = []
    fixtures = []
    dmx_channels = []
    for elem in root.iter():
        if elem.tag == "PreviewClass":
            previews.append({
                "id": elem.attrib.get('id'),
                "Name": elem.attrib.get('Name', None),
                "Revision": elem.attrib.get('Revision', None),
                "Brightness": float(elem.attrib.get('Brightness')) if elem.attrib.get('Brightness') else None,
                "BackgroundFile": elem.attrib.get('BackgroundFile', None)
            })

        if elem.tag == "PropClass":
            # Extract attributes
            attributes = elem.attrib

            # Initialize variables
            network = uid = start_channel = end_channel = unknown = color = None

            # Extract DeviceType
            device_type = attributes.get('DeviceType', None)

            # Parse 'ChannelGrid' based on DeviceType
            channel_grid = attributes.get('ChannelGrid', None)
            if channel_grid and device_type == "LOR":
                grid_parts = channel_grid.split(',')
                network = grid_parts[0] if len(grid_parts) > 0 else None
                uid = grid_parts[1] if len(grid_parts) > 1 else None
                start_channel = int(grid_parts[2]) if len(grid_parts) > 2 and grid_parts[2].isdigit() else None
                end_channel = int(grid_parts[3]) if len(grid_parts) > 3 and grid_parts[3].isdigit() else None
                unknown = grid_parts[4] if len(grid_parts) > 4 else None
                color = grid_parts[5] if len(grid_parts) > 5 else None
            elif channel_grid and device_type == "DMX":
                grids = channel_grid.split(';')
                for grid in grids:
                    grid_parts = grid.split(',')
                    dmx_channels.append({
                        "PropId": attributes.get('id'),
                        "Network": grid_parts[0] if len(grid_parts) > 0 else None,
                        "Start_Unv": int(grid_parts[1]) if len(grid_parts) > 1 and grid_parts[1].isdigit() else None,
                        "Start_Channel": int(grid_parts[2]) if len(grid_parts) > 2 and grid_parts[2].isdigit() else None,
                        "End_Channel": int(grid_parts[3]) if len(grid_parts) > 3 and grid_parts[3].isdigit() else None,
                        "Unknown": grid_parts[4] if len(grid_parts) > 4 else None,
                        "Color": grid_parts[5] if len(grid_parts) > 5 else None
                    })

            # Extract fields from attributes
            if attributes.get('MasterPropId'):
                fixtures.append({
                    "FixtureID": attributes.get('id'),
                    "Name": attributes.get('Name', None),
                    "Lights": int(attributes.get('Parm2')) if attributes.get('Parm2') else None,
                    "Comment": attributes.get('Comment', None),
                    "Attributes": str(attributes),
                    "MasterPropId": attributes.get('MasterPropId'),
                    "PreviewId": attributes.get('PreviewId', None)
                })
            else:
                props.append({
                "PropID": attributes.get('id'),
                "Name": attributes.get('Name'),
                "Comment": attributes.get('Comment'),
                "DeviceType": device_type,
                "MaxChannels": int(attributes.get('MaxChannels')) if attributes.get('MaxChannels') else None,
                "Tag": attributes.get('Tag'),
                "Network": network,
                "UID": uid,
                "StartChannel": start_channel,
                "EndChannel": end_channel,
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
        "INSERT OR IGNORE INTO previews (id, Name, Revision, Brightness, BackgroundFile) VALUES (?, ?, ?, ?, ?)",
        [(preview['id'], preview['Name'], preview['Revision'], preview['Brightness'], preview['BackgroundFile']) for preview in previews]
    )

    # Insert props
    cursor.executemany(
        "INSERT OR IGNORE INTO props (PropID, Name, Comment, DeviceType, MaxChannels, Tag, Network, UID, StartChannel, EndChannel, Unknown, Color, Lights, DimmingCurveName, Segments, Opacity, MasterDimmable, PreviewBulbSize, BulbShape, CustomBulbColor, StartLocation, StringType, TraditionalColors, TraditionalType, RgbOrder, SeparateIds, EffectBulbSize, IndividualChannels, LegacySequenceMethod, MasterPropId, Attributes) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
        [(prop['PropID'], prop['Name'], prop['Comment'], prop['DeviceType'], prop['MaxChannels'], prop['Tag'], prop['Network'], prop['UID'], prop['StartChannel'], prop['EndChannel'], prop['Unknown'], prop['Color'], prop['Lights'], prop['DimmingCurveName'], prop['Segments'], prop['Opacity'], prop['MasterDimmable'], prop['PreviewBulbSize'], prop['BulbShape'], prop['CustomBulbColor'], prop['StartLocation'], prop['StringType'], prop['TraditionalColors'], prop['TraditionalType'], prop['RgbOrder'], prop['SeparateIds'], prop['EffectBulbSize'], prop['IndividualChannels'], prop['LegacySequenceMethod'], prop['MasterPropId'], prop['Attributes']) for prop in props]
    )

    # Insert fixtures
    cursor.executemany(
        "INSERT OR IGNORE INTO fixtures (FixtureID, Name, Lights, Comment, Attributes, MasterPropId, PreviewId) VALUES (?, ?, ?, ?, ?, ?, ?)",
        [(fixture['FixtureID'], fixture['Name'], fixture['Lights'], fixture['Comment'], fixture['Attributes'], fixture['MasterPropId'], fixture['PreviewId']) for fixture in fixtures]
    )

    # Insert DMX channels
    cursor.executemany(
        "INSERT OR IGNORE INTO dmxChannels (PropId, Network, Start_Unv, Start_Channel, End_Channel, Unknown, Color) VALUES (?, ?, ?, ?, ?, ?, ?)",
        [(dmx['PropId'], dmx['Network'], dmx['Start_Unv'], dmx['Start_Channel'], dmx['End_Channel'], dmx['Unknown'], dmx['Color']) for dmx in dmx_channels]
    )

    conn.commit()

def process_folder(folder_path):
    # Initialize the database
    conn = initialize_database()

    # Process all .lorprev files in the specified folder
    for file_name in os.listdir(folder_path):
        if file_name.endswith(".lorprev"):
            file_path = os.path.join(folder_path, file_name)
            print(f"Processing file: {file_path}")
            process_file(file_path, conn)

    conn.close()
    print("Processing complete. Data saved to LOR.db.")

if __name__ == "__main__":
    folder_path = input("Enter the folder path containing .lorprev files: ")
    process_folder(folder_path)

