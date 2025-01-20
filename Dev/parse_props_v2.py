# Script to create database from scratch using LOR preview files
# Created by: Greg Liebig 2025/01/04
# Revision 0.1.0
# Revision 0.1.1 - Added logic to create sub-props from displays with multiple props on a single panel
# using the lowest channel on the display as the master prop 1/14/25
# source from create_preview_tree_building_subprops.py
# working on 1/14/25
# this script works to move all assigned props with masterpropID to subprops
# and to expand all props with multiple grids into subprops



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
            PreviewId TEXT,
            FOREIGN KEY (PreviewId) REFERENCES previews(id)  -- Define foreign key
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
            display_name = attributes.get('Comment')

            # 1. Explicit subprops
            if device_type == "LOR" and channel_grid and attributes.get('MasterPropId') and len(channel_grid.split(';')) == 1:
                sub_props.append({
                    "SubPropID": attributes.get('id'),
                    "Name": attributes.get('Name'),
                    "DisplayName": display_name,
                    "MasterPropId": attributes.get('MasterPropId'),
                    "PreviewId": prop_preview_id,
                    "UID": attributes.get('UID'),
                    "Channel": attributes.get('StartChannel'),
                    "Color": attributes.get('Color'),
                })

            # 2. Shared DisplayName, Single Grid, No MasterPropId
            elif device_type == "LOR" and channel_grid and not attributes.get('MasterPropId') and len(channel_grid.split(';')) == 1:
                grouped_props = defaultdict(list)
                grouped_props[display_name].append(attributes)

                # Process grouped props
                for display_name, group in grouped_props.items():
                    master_prop = min(
                        group,
                        key=lambda x: int(x.get('StartChannel', 0)) if x.get('StartChannel') and x['StartChannel'].isdigit() else float('inf')
                    )
                    master_prop_id = master_prop["id"]

                    # Add master prop to the props table
                    props.append({
                        "PropID": master_prop_id,
                        "Name": master_prop["Name"],
                        "DisplayName": display_name,
                        "DeviceType": device_type,
                        "PreviewId": prop_preview_id,
                        "StartChannel": master_prop.get("StartChannel"),
                    })

                    # Create subprops for the remaining props
                    for prop in group:
                        if prop["id"] != master_prop_id:
                            sub_props.append({
                                "SubPropID": prop["id"],
                                "Name": prop["Name"],
                                "DisplayName": prop["DisplayName"],
                                "MasterPropId": master_prop_id,
                                "PreviewId": prop_preview_id,
                                "UID": prop.get("UID"),
                                "Channel": prop.get("StartChannel"),
                                "Color": prop.get("Color"),
                            })
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
                            "DisplayName": display_name,
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
                            "DisplayName": f"{attributes.get('Comment')}-{start_channel.zfill(2)}",
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
                    "DisplayName": display_name,
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
                    "DisplayName": display_name,
                    "DeviceType": device_type,
                    "PreviewId": prop_preview_id,
                })

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
        INSERT OR IGNORE INTO props (PropID, Name, DisplayName, DeviceType, PreviewId)
        VALUES (?, ?, ?, ?, ?)
        """,
        [(p['PropID'], p['Name'], p['DisplayName'], p['DeviceType'], p['PreviewId']) for p in props]
    )

    # Insert subprops
    cursor.executemany(
        """
        INSERT OR IGNORE INTO subProps (SubPropID, Name, DisplayName, MasterPropId, PreviewId, UID, Channel, Color)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        """,
        [(s['SubPropID'], s['Name'], s['DisplayName'], s['MasterPropId'], s['PreviewId'], s['UID'], s['Channel'], s['Color']) for s in sub_props]
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


