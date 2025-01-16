# Script to create database from scratch using LOR preview files
# Created by: Greg Liebig 2025/01/04
# Revision 0.1.0
# Revision 0.1.1 - Added logic to create sub-props from displays with multiple props on a single panel
# using the lowest channel on the display as the master prop 1/14/25
# source from create_preview_tree_building_subprops.py
# working on 1/14/25
# this script works to move all assigned props with masterpropID to subprops
# and to expand all props with multiple grids into subprops
# 0.1.4 


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

    """)

    #Revised SubProps table to include UID and StartChannel 1/14/25
    cursor.execute("""
        CREATE TABLE subProps (
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
    """)

    cursor.execute("""
        CREATE TABLE dmxChannels (
            PropId TEXT,
            Network TEXT,
            StartUniverse INTEGER,
            StartChannel INTEGER,
            EndChannel INTEGER,
            Unknown TEXT,
            PreviewId TEXT,
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
            p.LORComment AS PropLORComment,
            sp.LORComment AS SubPropLORComment
        FROM previews pr
        LEFT JOIN props p ON pr.id = p.PreviewId
        LEFT JOIN subProps sp ON p.PropID = sp.MasterPropId
        WHERE sp.Channel IS NOT NULL
        ORDER BY p.LORComment, sp.Channel;
    """)


    conn.commit()
    return conn

# Revised process file code 1/15/25
# Revised process file code 1/15/25
def process_file(file_path, conn):
    # Parse the XML file
    tree = ET.parse(file_path)
    root = tree.getroot()
    preview_id = None  # Initialize PreviewId globally

    previews = {}  # Initialize as a dictionary
    props = []
    sub_props = []
    dmx_channels = []

    for elem in root.iter():
        if elem.tag == "PreviewClass":
            # Extract StageID and PreviewId
            import re
            stage_match = re.search(r"Stage (\d{2})", os.path.basename(file_path))
            stage_id = stage_match.group(1) if stage_match else None
            preview_type = os.path.basename(file_path).split()[0]
            preview_id = elem.attrib.get('id')
            #print(f"Assigned PreviewId: {preview_id}")            
            previews[preview_id] = {
                "id": preview_id,
                "StageID": stage_id,
                "PreviewType": preview_type,
                "Name": elem.attrib.get('Name', None),
                "Revision": elem.attrib.get('Revision', None),
                "Brightness": float(elem.attrib.get('Brightness')) if elem.attrib.get('Brightness') else None,
                "BackgroundFile": elem.attrib.get('BackgroundFile', None),
            }

        if elem.tag == "PropClass":
            attributes = elem.attrib
            prop_preview_id = preview_id
            channel_grid = attributes.get('ChannelGrid', None)
            device_type = attributes.get('DeviceType', None)
            LORComment = attributes.get('Comment')

            # 1. Explicit subprops
            if device_type == "LOR" and channel_grid and attributes.get('MasterPropId') and len(channel_grid.split(';')) == 1:
                sub_props.append({
                    "SubPropID": attributes.get('id'),
                    "Name": attributes.get('Name'),
                    "LORComment": LORComment,
                    "MasterPropId": attributes.get('MasterPropId'),
                    "PreviewId": prop_preview_id,
                    "UID": attributes.get('UID'),
                    "Channel": attributes.get('StartChannel'),
                    "Color": attributes.get('Color'),
                })

            # 2. Shared DisplayName (LORComment), Single Grid, No MasterPropId
            # 2. Shared LORComment, Single Grid, No MasterPropId
            elif device_type == "LOR" and channel_grid and not attributes.get('MasterPropId') and len(channel_grid.split(';')) == 1:
                grouped_props = defaultdict(list)

                # Group props by their LORComment
                for prop in props:
                    grouped_props[prop['LORComment']].append(prop)

                # Debugging: Verify grouping
                for comment, group in grouped_props.items():
                    print(f"Grouped LORComment '{comment}': {len(group)} props")

                # Process each group
                for comment, group in grouped_props.items():
                    if not group:
                        continue

                    # Sort group by StartChannel
                    group_sorted = sorted(
                        group,
                        key=lambda x: int(x.get('StartChannel', 0)) if x.get('StartChannel') and x['StartChannel'].isdigit() else float('inf')
                    )

                    # Identify the master prop (first in the sorted list)
                    master_prop = group_sorted[0]
                    master_prop_id = master_prop['PropID']

                    # Debugging: Verify master prop
                    print(f"Master prop for LORComment '{comment}': {master_prop['Name']} (StartChannel={master_prop.get('StartChannel')})")

                    # Parse grid parts for the master prop
                    grid_parts = master_prop.get('ChannelGrid', '').split(',')
                    network = grid_parts[0] if len(grid_parts) > 0 else None
                    uid = grid_parts[1] if len(grid_parts) > 1 else None
                    start_channel = grid_parts[2] if len(grid_parts) > 2 else None
                    end_channel = grid_parts[3] if len(grid_parts) > 3 else None
                    color = grid_parts[5] if len(grid_parts) > 5 else None

                    # Add the master prop to the props table
                    props.append({
                        "PropID": master_prop_id,
                        "Name": master_prop['Name'],
                        "LORComment": comment,
                        "DeviceType": device_type,
                        "PreviewId": master_prop.get('PreviewId', None),
                        "Network": network,
                        "UID": uid,
                        "StartChannel": start_channel,
                        "EndChannel": end_channel,
                        "Color": color,
                        "MaxChannels": int(master_prop.get('MaxChannels', 0)),
                        "Tag": master_prop.get('Tag', None),
                        "Lights": int(master_prop.get('Parm2', 0)),
                        "DimmingCurveName": master_prop.get('DimmingCurveName', None),
                        "Segments": int(master_prop.get('Parm1', 0)),
                        "Opacity": float(master_prop.get('Opacity', 0.0)),
                        "MasterDimmable": master_prop.get('MasterDimmable', 'false') == 'true',
                        "PreviewBulbSize": float(master_prop.get('PreviewBulbSize', 0.0)),
                        "BulbShape": master_prop.get('BulbShape', None),
                        "CustomBulbColor": master_prop.get('CustomBulbColor', None),
                        "StartLocation": master_prop.get('StartLocation', None),
                        "StringType": master_prop.get('StringType', None),
                        "TraditionalColors": master_prop.get('TraditionalColors', None),
                        "TraditionalType": master_prop.get('TraditionalType', None),
                        "RgbOrder": master_prop.get('RgbOrder', None),
                        "SeparateIds": master_prop.get('SeparateIds', None),
                        "EffectBulbSize": float(master_prop.get('EffectBulbSize', 0.0)),
                        "IndividualChannels": master_prop.get('IndividualChannels', '').strip().lower() == 'true',
                        "LegacySequenceMethod": master_prop.get('LegacySequenceMethod', None),
                    })

                    # Add remaining props in the group to the subProps table
                    for prop in group_sorted[1:]:
                        # Parse grid parts for the subprop
                        grid_parts = prop.get('ChannelGrid', '').split(',')
                        start_channel = grid_parts[2] if len(grid_parts) > 2 else None
                        color = grid_parts[5] if len(grid_parts) > 5 else None

                        sub_props.append({
                            "SubPropID": prop['PropID'],
                            "Name": prop['Name'],
                            "LORComment": comment,
                            "MasterPropId": master_prop_id,
                            "PreviewId": prop.get('PreviewId', None),
                            "UID": prop.get('UID'),
                            "Channel": start_channel,
                            "Color": color,
                        })

                        # Debugging: Verify subprop
                        print(f"Subprop for LORComment '{comment}': {prop['Name']} (StartChannel={start_channel})")



            # 3. LOR Props with Multiple Grids
            elif device_type == "LOR" and channel_grid and len(channel_grid.split(';')) > 1:
                grids = channel_grid.split(';')
                is_master_set = False

                for grid in grids:
                    grid_parts = grid.split(',')
                    network = grid_parts[0] if len(grid_parts) > 0 else None
                    uid = grid_parts[1] if len(grid_parts) > 1 else None
                    start_channel = grid_parts[2] if len(grid_parts) > 2 else None
                    end_channel = grid_parts[3] if len(grid_parts) > 3 else None
                    color = grid_parts[5] if len(grid_parts) > 5 else None

                    if not is_master_set:
                        # Add the first grid as the master prop
                        props.append({
                            "PropID": attributes.get('id'),
                            "Name": attributes.get('Name'),
                            "LORComment": LORComment,
                            "DeviceType": device_type,
                            "PreviewId": prop_preview_id,
                            "Network": network,
                            "UID": uid,
                            "StartChannel": start_channel,
                            "EndChannel": end_channel,
                            "Color": color,
                        })
                        is_master_set = True
                    else:
                        # Add subsequent grids as subprops
                        sub_props.append({
                            "SubPropID": f"{attributes.get('id')}-{start_channel}",
                            "Name": f"{attributes.get('Name')}",
                            "LORComment": f"{attributes.get('Comment')}-{start_channel.zfill(2)}",
                            "MasterPropId": attributes.get('id'),
                            "PreviewId": prop_preview_id,
                            "Network": network,
                            "UID": uid,
                            "Channel": start_channel,
                            "Color": color,
                        })


            # 4. DMX Props with Multiple Grids, No MasterPropId
            elif device_type == "DMX" and channel_grid and not attributes.get('MasterPropId') and len(channel_grid.split(';')) > 1:
                grids = channel_grid.split(';')
                master_prop = min(
                    grids,
                    key=lambda g: int(g.split(',')[2]) if len(g.split(',')) > 2 and g.split(',')[2].isdigit() else float('inf')
                )
                master_channel = master_prop.split(',')[2]

                # Add master prop
                props.append({
                    "PropID": attributes.get('id'),
                    "Name": attributes.get('Name'),
                    "LORComment": LORComment,
                    "DeviceType": device_type,
                    "PreviewId": prop_preview_id,
                    "StartChannel": master_channel,
                })

                # Add grids to DMX channels
                for grid in grids:
                    grid_parts = grid.split(',')
                    dmx_channels.append({
                        "PropId": attributes.get('id'),
                        "Network": grid_parts[0] if len(grid_parts) > 0 else None,
                        "StartUniverse": int(grid_parts[1]) if len(grid_parts) > 1 and grid_parts[1].isdigit() else None,
                        "StartChannel": int(grid_parts[2]) if len(grid_parts) > 2 and grid_parts[2].isdigit() else None,
                        "EndUniverse": int(grid_parts[3]) if len(grid_parts) > 3 and grid_parts[3].isdigit() else None,
                        "EndChannel": int(grid_parts[4]) if len(grid_parts) > 4 and grid_parts[4].isdigit() else None,
                        "PreviewId": prop_preview_id,
                    })

            # 5. Props with DeviceType == None
            elif device_type is None:
                props.append({
                    "PropID": attributes.get('id'),
                    "Name": attributes.get('Name'),
                    "LORComment": LORComment,
                    "DeviceType": device_type,
                    "PreviewId": prop_preview_id,
                })

    # for prop in props:
    #     if len(prop) != 32:
    #         print(f"Incomplete prop: {prop}")


    # Insert data into the database
    cursor = conn.cursor()

    # Insert previews
    cursor.executemany(
        """
        INSERT OR IGNORE INTO previews (id, StageID, PreviewType, Name, Revision, Brightness, BackgroundFile)
        VALUES (?, ?, ?, ?, ?, ?, ?)
        """,
        [(p['id'], p['StageID'], p['PreviewType'], p['Name'], p['Revision'], p['Brightness'], p['BackgroundFile']) for p in previews.values()]
    )

    # Insert props
    cursor.executemany(
        """
        INSERT OR IGNORE INTO props (
            PropID, Name, LORComment, DeviceType, MaxChannels, Tag, Network, UID,
            StartChannel, EndChannel, Unknown, Color, Lights, DimmingCurveName, Segments,
            Opacity, MasterDimmable, PreviewBulbSize, BulbShape, CustomBulbColor,
            StartLocation, StringType, TraditionalColors, TraditionalType, RgbOrder,
            SeparateIds, EffectBulbSize, IndividualChannels, LegacySequenceMethod,
            MasterPropId, PreviewId
        )
        VALUES (
            ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?
        )
        """,
        [
            (
                prop.get('PropID'),
                prop.get('Name'),
                prop.get('LORComment'),
                prop.get('DeviceType'),
                prop.get('MaxChannels', 0),  # Default to 0
                prop.get('Tag'),
                prop.get('Network'),
                prop.get('UID'),
                prop.get('StartChannel'),
                prop.get('EndChannel'),
                prop.get('Unknown'),
                prop.get('Color'),
                prop.get('Lights', 0),  # Default to 0
                prop.get('DimmingCurveName'),
                prop.get('Segments', 0),  # Default to 0
                prop.get('Opacity', 0.0),  # Default to 0.0
                prop.get('MasterDimmable', False),
                prop.get('PreviewBulbSize', 0.0),  # Default to 0.0
                prop.get('BulbShape'),
                prop.get('CustomBulbColor'),
                prop.get('StartLocation'),
                prop.get('StringType'),
                prop.get('TraditionalColors'),
                prop.get('TraditionalType'),
                prop.get('RgbOrder'),
                prop.get('SeparateIds'),
                prop.get('EffectBulbSize', 0.0),  # Default to 0.0
                prop.get('IndividualChannels', False),
                prop.get('LegacySequenceMethod'),
                prop.get('MasterPropId'),
                prop.get('PreviewId')
            )
            for prop in props
        ]
    )



    # Insert subprops
    cursor.executemany(
        """
        INSERT OR IGNORE INTO subProps (SubPropID, Name, LORComment, MasterPropId, PreviewId, UID, Channel, Color)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        """,
        [(s['SubPropID'], s['Name'], s['LORComment'], s['MasterPropId'], s['PreviewId'], s['UID'], s['Channel'], s['Color']) for s in sub_props]
    )

    # Insert DMX channels
    cursor.executemany(
        """
        INSERT OR IGNORE INTO dmxChannels (PropId, Network, StartUniverse, StartChannel, EndChannel, Unknown, PreviewId)
        VALUES (?, ?, ?, ?, ?, ?, ?)
        """,
        [(d['PropId'], d['Network'], d['StartUniverse'], d['StartChannel'], d['EndChannel'], d.get('Unknown'), d['PreviewId']) for d in dmx_channels]
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


