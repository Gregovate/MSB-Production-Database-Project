# Initial Release: 2022-01-20 V0.1.0
# Written by: Greg Liebig, Engineering Innovations, LLC.
# Description: This script parses LOR .lorprev files and extracts prop data into a SQLite database.
# Modified Schema as a test to create a new primary Key as an integer
# Modified to add INTEGER keys for MS Access compatibility 1/22/25

import os
import xml.etree.ElementTree as ET
import sqlite3
from collections import defaultdict
import uuid

DEBUG = False  # Global debug flag
DB_FILE = "G:\Shared drives\MSB Database\database\lor_output_v7.db"

def setup_database():
    """Initialize the database schema with all required fields."""
    conn = sqlite3.connect(DB_FILE)
    cursor = conn.cursor()

    # Drop tables if they exist
    cursor.execute("DROP TABLE IF EXISTS previews")
    cursor.execute("DROP TABLE IF EXISTS props")
    cursor.execute("DROP TABLE IF EXISTS subProps")
    cursor.execute("DROP TABLE IF EXISTS dmxChannels")

    # Create Previews Table
    cursor.execute("""
    CREATE TABLE previews (
        IntPreviewID INTEGER PRIMARY KEY AUTOINCREMENT,
        id TEXT UNIQUE,
        StageID TEXT,
        Name TEXT,
        Revision TEXT,
        Brightness REAL,
        BackgroundFile TEXT
    )
    """)

    # Create Props Table
    cursor.execute("""
    CREATE TABLE props (
        IntPropID INTEGER PRIMARY KEY AUTOINCREMENT,
        PropID TEXT UNIQUE NOT NULL,
        PreviewID TEXT NOT NULL,
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
        FOREIGN KEY (PreviewID) REFERENCES previews(id)
    )
    """)

    # Create SubProps Table
    cursor.execute("""
    CREATE TABLE subProps (
        IntSubPropID INTEGER PRIMARY KEY AUTOINCREMENT,
        SubPropID TEXT NOT NULL,
        MasterPropID TEXT NOT NULL,
        PreviewID TEXT NOT NULL,
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
        UNIQUE (IntSubPropID, PreviewID),
        FOREIGN KEY (MasterPropID) REFERENCES props(PropID),
        FOREIGN KEY (PreviewID) REFERENCES previews(id)
    )
    """)

    # Create DMX Channels Table
    cursor.execute("""
    CREATE TABLE dmxChannels (
        IntDMXChannelID INTEGER PRIMARY KEY AUTOINCREMENT,
        PropID TEXT NOT NULL,
        Network TEXT,
        StartUniverse INTEGER,
        StartChannel INTEGER,
        EndChannel INTEGER,
        Unknown TEXT,
        UNIQUE (PropID, Network, StartUniverse, StartChannel),
        FOREIGN KEY (PropID) REFERENCES props(PropID)
    )
    """)

    # Create DMX Channels Table
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS duplicateProps (
        PropID TEXT PRIMARY KEY,
        Name TEXT,
        LORComment TEXT,
        DeviceType TEXT,
        PreviewId TEXT,
        Reason TEXT
    )
    """)



    conn.commit()
    conn.close()
    print("[DEBUG] Database setup complete, all tables created.")

# Utility insert_* Functions for database

def insert_previews(preview_data):
    """Insert preview data into the previews table."""
    conn = sqlite3.connect(DB_FILE)
    cursor = conn.cursor()

    cursor.execute("""
    INSERT OR REPLACE INTO previews (id, StageID, Name, Revision, Brightness, BackgroundFile)
    VALUES (?, ?, ?, ?, ?, ?);
    """, (preview_data['id'], preview_data['StageID'], preview_data['Name'],
          preview_data['Revision'], preview_data['Brightness'], preview_data['BackgroundFile']))

    conn.commit()
    conn.close()

def insert_props(preview_id, props):
    """Insert props data into the props table."""
    conn = sqlite3.connect(DB_FILE)
    cursor = conn.cursor()

    for prop in props:
        cursor.execute("""
        INSERT OR REPLACE INTO props (
            PropID, PreviewID, Name, LORComment, DeviceType, BulbShape, Network, UID,
            StartChannel, EndChannel, Unknown, Color, CustomBulbColor, DimmingCurveName,
            IndividualChannels, LegacySequenceMethod, MaxChannels, Opacity, MasterDimmable,
            PreviewBulbSize, MasterPropId, SeparateIds, StartLocation, StringType,
            TraditionalColors, TraditionalType, EffectBulbSize, Tag, Parm1, Parm2, Parm3, Parm4,
            Parm5, Parm6, Parm7, Parm8, Lights
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """, (
            prop['PropID'], preview_id, prop['Name'], prop['LORComment'], prop['DeviceType'],
            prop['BulbShape'], prop['Network'], prop['UID'], prop['StartChannel'], prop['EndChannel'],
            prop['Unknown'], prop['Color'], prop['CustomBulbColor'], prop['DimmingCurveName'],
            prop['IndividualChannels'], prop['LegacySequenceMethod'], prop['MaxChannels'], prop['Opacity'],
            prop['MasterDimmable'], prop['PreviewBulbSize'], prop['MasterPropId'], prop['SeparateIds'],
            prop['StartLocation'], prop['StringType'], prop['TraditionalColors'], prop['TraditionalType'],
            prop['EffectBulbSize'], prop['Tag'], prop['Parm1'], prop['Parm2'], prop['Parm3'], prop['Parm4'],
            prop['Parm5'], prop['Parm6'], prop['Parm7'], prop['Parm8'], prop['Lights']
        ))

    conn.commit()
    conn.close()

def insert_sub_props(preview_id, sub_props):
    """Insert sub-props data into the subProps table."""
    with sqlite3.connect(DB_FILE) as conn:
        cursor = conn.cursor()

        for sub_prop in sub_props:
            # Dynamically construct columns and values based on available keys
            columns = []
            values = []

            # Include common fields
            for field in [
                'SubPropID', 'MasterPropID', 'PreviewID', 'Name', 'LORComment', 'DeviceType', 'BulbShape', 
                'Network', 'UID', 'StartChannel', 'EndChannel', 'Unknown', 'Color', 'CustomBulbColor', 
                'DimmingCurveName', 'IndividualChannels', 'LegacySequenceMethod', 'MaxChannels', 'Opacity', 
                'MasterDimmable', 'PreviewBulbSize', 'SeparateIds', 'StartLocation', 'StringType', 
                'TraditionalColors', 'TraditionalType', 'EffectBulbSize', 'Tag', 'Lights'
            ]:
                if field in sub_prop:
                    columns.append(field)
                    values.append(sub_prop[field])

            # Dynamically add Parm fields (Parm1 to Parm8) if they exist
            for i in range(1, 9):  # Parm1 to Parm8
                field_name = f'Parm{i}'
                if field_name in sub_prop:
                    columns.append(field_name)
                    values.append(sub_prop[field_name])

            # Construct the SQL statement dynamically
            sql = f"""
            INSERT OR REPLACE INTO subProps ({', '.join(columns)})
            VALUES ({', '.join(['?' for _ in values])})
            """
            cursor.execute(sql, values)

        conn.commit()

def insert_dmx_channels(dmx_channels):
    """Insert DMX channels data into the dmxChannels table."""
    conn = sqlite3.connect(DB_FILE)
    cursor = conn.cursor()

    for channel in dmx_channels:
        cursor.execute("""
        INSERT OR REPLACE INTO dmxChannels (
            PropID, Network, StartUniverse, StartChannel, EndChannel, Unknown
        ) VALUES (?, ?, ?, ?, ?, ?);
        """, (
            channel['PropID'], channel['Network'], channel['StartUniverse'],
            channel['StartChannel'], channel['EndChannel'], channel['Unknown']
        ))

    conn.commit()
    conn.close()

# Function to check for duplicate PropID and log it to the duplicateProps table if found
def handle_duplicate_prop(cursor, prop_id, name, lor_comment, device_type, preview_id, reason):
    """
    Check for duplicate PropID and log it to the duplicateProps table if found.

    Args:
        cursor (sqlite3.Cursor): Database cursor.
        prop_id (str): The PropID being checked.
        name (str): The Name of the prop.
        lor_comment (str): The LORComment of the prop.
        device_type (str): The DeviceType of the prop.
        preview_id (str): The PreviewId of the prop.
        reason (str): The reason for logging as duplicate.

    Returns:
        bool: True if duplicate, False otherwise.
    """
    # Check if PropID already exists in the props table
    cursor.execute("SELECT COUNT(*) FROM props WHERE PropID = ?", (prop_id,))
    count = cursor.fetchone()[0]

    if count > 0:
        # Log the duplicate in duplicateProps table
        cursor.execute("""
        INSERT OR REPLACE INTO duplicateProps (PropID, Name, LORComment, DeviceType, PreviewId, Reason)
        VALUES (?, ?, ?, ?, ?, ?)
        """, (prop_id, name, lor_comment, device_type, preview_id, reason))
        print(f"[INFO] Logged duplicate PropID: {prop_id} (Reason: {reason})")
        return True  # Duplicate detected
    return False  # No duplicate




def locate_preview_class_deep(file_path):
    """Locate the PreviewClass element at any depth in the XML tree."""
    try:
        tree = ET.parse(file_path)
        root = tree.getroot()

        # Deep search for PreviewClass
        for element in root.iter():
            if element.tag.endswith("PreviewClass"):  # Handle namespaces or simple tag names
                return element
        return None
    except ET.ParseError as e:
        print(f"[ERROR] Failed to parse {file_path}: {e}")
        return None

def process_preview(preview):
    """Extract and return data from the <PreviewClass> element."""
    preview_data = {
        "id": preview.get("id"),
        "StageID": extract_stage_id(preview.get("Name")),
        "Name": preview.get("Name"),
        "Revision": preview.get("Revision"),
        "Brightness": preview.get("Brightness"),
        "BackgroundFile": preview.get("BackgroundFile")
    }
    print(f"[DEBUG] Processed Preview: {preview_data}")
    return preview_data

def extract_stage_id(name):
    """Extract StageID from the Name field."""
    return ''.join(filter(str.isdigit, name)) if name else None

def process_none_props(preview_id, root):
    """
    Process props with DeviceType == None:
    - Aggregate lights (Parm2) by LORComment.
    - Ensure one entry per LORComment in the props table.
    """
    # Prepare to summarize props
    props_summary = defaultdict(lambda: {
        "Lights": 0, "Name": None, "PropID": None, "DeviceType": None
    })

    # Collect and aggregate data for props with DeviceType == "None"
    for prop in root.findall(".//PropClass"):
        if prop.get("DeviceType") == "None":
            lor_comment = prop.get("Comment", "NO_COMMENT")
            parm2 = prop.get("Parm2")
            lights = int(parm2) if parm2 and parm2.isdigit() else 0

            # Aggregate lights by LORComment
            props_summary[lor_comment]["Lights"] += lights
            props_summary[lor_comment]["Name"] = prop.get("Name", "")
            props_summary[lor_comment]["PropID"] = prop.get("id", "")
            props_summary[lor_comment]["DeviceType"] = prop.get("DeviceType", "None")

    # Prepare processed props
    processed_props = []
    for lor_comment, prop_data in props_summary.items():
        processed_props.append({
            'PropID': prop_data["PropID"],
            'Name': prop_data["Name"],
            'LORComment': lor_comment,
            'DeviceType': prop_data["DeviceType"],
            'BulbShape': "",  # Default for missing fields
            'Network': "",
            'UID': "",
            'StartChannel': 0,
            'EndChannel': 0,
            'Unknown': "",
            'Color': "",
            'CustomBulbColor': "",
            'DimmingCurveName': "",
            'IndividualChannels': False,
            'LegacySequenceMethod': "",
            'MaxChannels': 0,
            'Opacity': 1.0,
            'MasterDimmable': False,
            'PreviewBulbSize': 1.0,
            'MasterPropId': None,
            'SeparateIds': False,
            'StartLocation': "",
            'StringType': "",
            'TraditionalColors': "",
            'TraditionalType': "",
            'EffectBulbSize': 1.0,
            'Tag': "",
            'Parm1': "",
            'Parm2': "",
            'Parm3': "",
            'Parm4': "",
            'Parm5': "",
            'Parm6': "",
            'Parm7': "",
            'Parm8': "",
            'Lights': prop_data["Lights"],
            'PreviewID': preview_id
        })

    # Insert aggregated props into the database
    insert_props(preview_id, processed_props)

    if DEBUG:
        print(f"[DEBUG] Processed and inserted {len(processed_props)} 'None' props for PreviewID: {preview_id}")


def process_dmx_props(preview_id, root):
    """
    Process props with DeviceType == DMX:
    - Extract data from <PropClass> elements where DeviceType is "DMX".
    - Insert processed data into the props table using the insert_props utility function.
    - Extract and insert DMX channel data into the dmxChannels table.
    """
    # Prepare lists for props and DMX channels
    dmx_props = []
    dmx_channels = []

    # Iterate over all PropClass elements
    for prop in root.findall(".//PropClass"):
        if prop.get("DeviceType") == "DMX":
            # Add to props data
            dmx_props.append({
                'PropID': prop.get("id"),
                'Name': prop.get("Name", ""),
                'LORComment': prop.get("Comment", ""),
                'DeviceType': prop.get("DeviceType", ""),
                'BulbShape': prop.get("BulbShape", ""),
                'Network': prop.get("Network", ""),  # Default to ""
                'UID': prop.get("UID", ""),  # Default to ""
                'StartChannel': int(prop.get("StartChannel", 0)),
                'EndChannel': int(prop.get("EndChannel", 0)),
                'Unknown': prop.get("Unknown", ""),  # Default to ""
                'Color': prop.get("Color", ""),  # Default to ""
                'DimmingCurveName': prop.get("DimmingCurveName", ""),
                'MaxChannels': int(prop.get("MaxChannels", 0)),
                'CustomBulbColor': prop.get("CustomBulbColor", ""),
                'IndividualChannels': prop.get("IndividualChannels") == "true",
                'LegacySequenceMethod': prop.get("LegacySequenceMethod", ""),
                'Opacity': float(prop.get("Opacity", 1.0)),
                'MasterDimmable': prop.get("MasterDimmable") == "true",
                'PreviewBulbSize': float(prop.get("PreviewBulbSize", 1.0)),
                'MasterPropId': prop.get("MasterPropId", ""),
                'SeparateIds': prop.get("SeparateIds") == "true",
                'StartLocation': prop.get("StartLocation", ""),
                'StringType': prop.get("StringType", ""),
                'TraditionalColors': prop.get("TraditionalColors", ""),
                'TraditionalType': prop.get("TraditionalType", ""),
                'EffectBulbSize': float(prop.get("EffectBulbSize", 1.0)),
                'Tag': prop.get("Tag", ""),
                'Parm1': prop.get("Parm1", ""),
                'Parm2': prop.get("Parm2", ""),
                'Parm3': prop.get("Parm3", ""),
                'Parm4': prop.get("Parm4", ""),
                'Parm5': prop.get("Parm5", ""),
                'Parm6': prop.get("Parm6", ""),
                'Parm7': prop.get("Parm7", ""),
                'Parm8': prop.get("Parm8", ""),
                'Lights': int(prop.get("Parm2", 0)),
                'PreviewID': preview_id
            })

            # Extract DMX channel data from ChannelGrid (if available)
            channel_grid = prop.get("ChannelGrid")
            if channel_grid:
                for grid in channel_grid.split(";"):
                    parts = grid.split(",")
                    if len(parts) >= 5:  # Ensure sufficient data
                        dmx_channels.append({
                            'PropID': prop.get("id"),
                            'Network': parts[0],
                            'StartUniverse': int(parts[1]) if parts[1].isdigit() else 0,
                            'StartChannel': int(parts[2]) if parts[2].isdigit() else 0,
                            'EndChannel': int(parts[3]) if parts[3].isdigit() else 0,
                            'Unknown': parts[4]
                        })

    # Insert into the database using utility functions
    insert_props(preview_id, dmx_props)
    insert_dmx_channels(dmx_channels)

    if DEBUG:
        print(f"[DEBUG] Processed and inserted {len(dmx_props)} DMX props and {len(dmx_channels)} DMX channels for PreviewID: {preview_id}")

def process_lor_props(preview_id, root):
    """
    Process props with DeviceType == LOR:
    - Single ChannelGrid.
    - Identify the master prop as the prop with the lowest StartChannel among props with the same Comment.
    - Insert the master prop into the props table, including its grid parts.
    - Insert remaining props into the subProps table, linking them to the master prop and including their grid parts.
    - If the Name contains 'spare', place the prop directly into the props table and save grid parts.
    """
    # Lists to hold master props and subprops
    lor_props = []
    sub_props = []

    # Group props by Comment
    props_grouped_by_comment = defaultdict(list)
    for prop in root.findall(".//PropClass"):
        if prop.get("DeviceType") == "LOR":
            props_grouped_by_comment[prop.get("Comment", "NO_COMMENT")].append(prop)

    # Process each group
    for comment, props in props_grouped_by_comment.items():
        # Identify the master prop with the lowest StartChannel
        master_prop = min(
            props, key=lambda x: int(x.get("StartChannel", 0)) if x.get("StartChannel") and x.get("StartChannel").isdigit() else float('inf')
        )
        master_prop_id = master_prop.get("id")

        # Parse ChannelGrid for the master prop
        channel_grid = master_prop.get("ChannelGrid", "")
        master_channels = []
        for grid in channel_grid.split(";"):
            parts = grid.split(",")
            if len(parts) >= 5:
                master_channels.append({
                    'Network': parts[0],
                    'UID': parts[1],
                    'StartChannel': int(parts[2]),
                    'EndChannel': int(parts[3]),
                    'Unknown': parts[4],
                    'Color': parts[5] if len(parts) > 5 else None
                })

        # If the Name contains "spare", treat it as a standalone prop
        if "spare" in master_prop.get("Name", "").lower():
            lor_props.append({
                'PropID': master_prop_id,
                'Name': master_prop.get("Name", ""),
                'LORComment': comment,
                'DeviceType': master_prop.get("DeviceType", ""),
                'BulbShape': master_prop.get("BulbShape", ""),
                'Network': master_prop.get("Network", ""),  # Default to ""
                'UID': master_prop.get("UID", ""),  # Default to ""
                'StartChannel': int(master_prop.get("StartChannel", 0)),
                'EndChannel': int(master_prop.get("EndChannel", 0)),
                'Unknown': master_prop.get("Unknown", ""),  # Default to ""
                'Color': master_prop.get("Color", ""),  # Default to ""
                'DimmingCurveName': master_prop.get("DimmingCurveName", ""),
                'MaxChannels': int(master_prop.get("MaxChannels", 0)),
                'CustomBulbColor': master_prop.get("CustomBulbColor", ""),
                'IndividualChannels': master_prop.get("IndividualChannels") == "true",
                'LegacySequenceMethod': master_prop.get("LegacySequenceMethod", ""),
                'Opacity': float(master_prop.get("Opacity", 1.0)),
                'MasterDimmable': master_prop.get("MasterDimmable") == "true",
                'PreviewBulbSize': float(master_prop.get("PreviewBulbSize", 1.0)),
                'MasterPropId': None,  # Master props have no master
                'SeparateIds': master_prop.get("SeparateIds") == "true",
                'StartLocation': master_prop.get("StartLocation", ""),
                'StringType': master_prop.get("StringType", ""),
                'TraditionalColors': master_prop.get("TraditionalColors", ""),
                'TraditionalType': master_prop.get("TraditionalType", ""),
                'EffectBulbSize': float(master_prop.get("EffectBulbSize", 1.0)),
                'Tag': master_prop.get("Tag", ""),
                'Parm1': master_prop.get("Parm1", ""),
                'Parm2': master_prop.get("Parm2", ""),
                'Parm3': master_prop.get("Parm3", ""),
                'Parm4': master_prop.get("Parm4", ""),
                'Parm5': master_prop.get("Parm5", ""),
                'Parm6': master_prop.get("Parm6", ""),
                'Parm7': master_prop.get("Parm7", ""),
                'Parm8': master_prop.get("Parm8", ""),
                'Lights': int(master_prop.get("Parm2", 0)),
                'PreviewID': preview_id
            })
        else:
            # Insert the master prop into the props table
            lor_props.append({
                'PropID': master_prop_id,
                'Name': master_prop.get("Name", ""),
                'LORComment': comment,
                'DeviceType': master_prop.get("DeviceType", ""),
                'BulbShape': master_prop.get("BulbShape", ""),
                'Network': master_prop.get("Network", ""),
                'UID': master_prop.get("UID", ""),
                'StartChannel': int(master_prop.get("StartChannel", 0)),
                'EndChannel': int(master_prop.get("EndChannel", 0)),
                'Unknown': master_prop.get("Unknown", ""),
                'Color': master_prop.get("Color", ""),
                'DimmingCurveName': master_prop.get("DimmingCurveName", ""),
                'MaxChannels': int(master_prop.get("MaxChannels", 0)),
                'CustomBulbColor': master_prop.get("CustomBulbColor", ""),
                'IndividualChannels': master_prop.get("IndividualChannels") == "true",
                'LegacySequenceMethod': master_prop.get("LegacySequenceMethod", ""),
                'Opacity': float(master_prop.get("Opacity", 1.0)),
                'MasterDimmable': master_prop.get("MasterDimmable") == "true",
                'PreviewBulbSize': float(master_prop.get("PreviewBulbSize", 1.0)),
                'MasterPropId': None,  # Master props have no master
                'SeparateIds': master_prop.get("SeparateIds") == "true",
                'StartLocation': master_prop.get("StartLocation", ""),
                'StringType': master_prop.get("StringType", ""),
                'TraditionalColors': master_prop.get("TraditionalColors", ""),
                'TraditionalType': master_prop.get("TraditionalType", ""),
                'EffectBulbSize': float(master_prop.get("EffectBulbSize", 1.0)),
                'Tag': master_prop.get("Tag", ""),
                'Parm1': master_prop.get("Parm1", ""),
                'Parm2': master_prop.get("Parm2", ""),
                'Parm3': master_prop.get("Parm3", ""),
                'Parm4': master_prop.get("Parm4", ""),
                'Parm5': master_prop.get("Parm5", ""),
                'Parm6': master_prop.get("Parm6", ""),
                'Parm7': master_prop.get("Parm7", ""),
                'Parm8': master_prop.get("Parm8", ""),
                'Lights': int(master_prop.get("Parm2", 0)),
                'PreviewID': preview_id
            })

            # Process remaining props as subprops
            for prop in props:
                if prop.get("id") != master_prop_id:
                    # Parse ChannelGrid for subprops
                    channel_grid = prop.get("ChannelGrid", "")
                    for grid in channel_grid.split(";"):
                        parts = grid.split(",")
                        if len(parts) >= 5:
                            sub_props.append({
                                'SubPropID': prop.get("id"),
                                'MasterPropID': master_prop_id,
                                'PreviewID': preview_id,
                                'Name': prop.get("Name", ""),
                                'LORComment': comment,
                                'Network': parts[0],
                                'UID': parts[1],
                                'StartChannel': int(parts[2]),
                                'EndChannel': int(parts[3]),
                                'Unknown': parts[4],
                                'Color': parts[5] if len(parts) > 5 else None
                            })

    # Insert master props and subprops into the database
    insert_props(preview_id, lor_props)
    insert_sub_props(preview_id, sub_props)

    if DEBUG:
        print(f"[DEBUG] Processed and inserted {len(lor_props)} LOR props and {len(sub_props)} subprops for PreviewID: {preview_id}")


def process_lor_multiple_channel_grids(preview_id, root):
    """
    Process props with DeviceType == LOR and multiple ChannelGrid groups.
    - Retains the original master prop in the props table.
    - Parses each ChannelGrid group and creates subprops.
    - Inserts subprops into the subProps table with grid data and links to the master prop.
    """
    # Lists to hold master props and subprops
    lor_props = []
    sub_props = []

    # Iterate over all PropClass elements
    for prop in root.findall(".//PropClass"):
        if prop.get("DeviceType") == "LOR" and ";" in prop.get("ChannelGrid", ""):
            master_prop_id = prop.get("id")
            channel_grid = prop.get("ChannelGrid")

            # Add the master prop to the props list
            lor_props.append({
                'PropID': master_prop_id,
                'Name': prop.get("Name", ""),
                'LORComment': prop.get("Comment", ""),
                'DeviceType': prop.get("DeviceType", ""),
                'BulbShape': prop.get("BulbShape", ""),
                'Network': prop.get("Network", ""),  # Default to ""
                'UID': prop.get("UID", ""),  # Default to ""
                'StartChannel': int(prop.get("StartChannel", 0)),
                'EndChannel': int(prop.get("EndChannel", 0)),
                'Unknown': prop.get("Unknown", ""),  # Default to ""
                'Color': prop.get("Color", ""),  # Default to ""
                'DimmingCurveName': prop.get("DimmingCurveName", ""),
                'MaxChannels': int(prop.get("MaxChannels", 0)),
                'CustomBulbColor': prop.get("CustomBulbColor", ""),
                'IndividualChannels': prop.get("IndividualChannels") == "true",
                'LegacySequenceMethod': prop.get("LegacySequenceMethod", ""),
                'Opacity': float(prop.get("Opacity", 1.0)),
                'MasterDimmable': prop.get("MasterDimmable") == "true",
                'PreviewBulbSize': float(prop.get("PreviewBulbSize", 1.0)),
                'MasterPropId': None,  # Master props have no master
                'SeparateIds': prop.get("SeparateIds") == "true",
                'StartLocation': prop.get("StartLocation", ""),
                'StringType': prop.get("StringType", ""),
                'TraditionalColors': prop.get("TraditionalColors", ""),
                'TraditionalType': prop.get("TraditionalType", ""),
                'EffectBulbSize': float(prop.get("EffectBulbSize", 1.0)),
                'Tag': prop.get("Tag", ""),
                'Parm1': prop.get("Parm1", ""),
                'Parm2': prop.get("Parm2", ""),
                'Parm3': prop.get("Parm3", ""),
                'Parm4': prop.get("Parm4", ""),
                'Parm5': prop.get("Parm5", ""),
                'Parm6': prop.get("Parm6", ""),
                'Parm7': prop.get("Parm7", ""),
                'Parm8': prop.get("Parm8", ""),
                'Lights': int(prop.get("Parm2", 0)),
                'PreviewID': preview_id
            })

            # Parse ChannelGrid groups to create subprops
            grid_groups = channel_grid.split(";")
            for grid in grid_groups:
                parts = grid.split(",")
                if len(parts) >= 5:
                    sub_props.append({
                        'SubPropID': f"{master_prop_id}-{parts[2]}",  # Unique subprop ID using master and StartChannel
                        'MasterPropID': master_prop_id,
                        'PreviewID': preview_id,
                        'Name': f"{prop.get('Name', '')} ({parts[2]})",  # Include StartChannel in the name
                        'LORComment': prop.get("Comment", ""),
                        'DeviceType': prop.get("DeviceType", ""),  # Default to ""
                        'BulbShape': prop.get("BulbShape", ""),  # Default to ""
                        'Network': parts[0],
                        'UID': parts[1],
                        'StartChannel': int(parts[2]),
                        'EndChannel': int(parts[3]),
                        'Unknown': parts[4],
                        'Color': parts[5] if len(parts) > 5 else None,
                        'CustomBulbColor': prop.get("CustomBulbColor", ""),
                        'DimmingCurveName': prop.get("DimmingCurveName", ""),
                        'IndividualChannels': prop.get("IndividualChannels") == "true",
                        'LegacySequenceMethod': prop.get("LegacySequenceMethod", ""),
                        'MaxChannels': int(prop.get("MaxChannels", 0)),
                        'Opacity': float(prop.get("Opacity", 1.0)),
                        'MasterDimmable': prop.get("MasterDimmable") == "true",
                        'PreviewBulbSize': float(prop.get("PreviewBulbSize", 1.0)),
                        'SeparateIds': prop.get("SeparateIds") == "true",
                        'StartLocation': prop.get("StartLocation", ""),
                        'StringType': prop.get("StringType", ""),
                        'TraditionalColors': prop.get("TraditionalColors", ""),
                        'TraditionalType': prop.get("TraditionalType", ""),
                        'EffectBulbSize': float(prop.get("EffectBulbSize", 1.0)),
                        'Tag': prop.get("Tag", ""),
                        'Parm1': prop.get("Parm1", ""),
                        'Parm2': prop.get("Parm2", ""),
                        'Parm3': prop.get("Parm3", ""),
                        'Parm4': prop.get("Parm4", ""),
                        'Parm5': prop.get("Parm5", ""),
                        'Parm6': prop.get("Parm6", ""),
                        'Parm7': prop.get("Parm7", ""),
                        'Parm8': prop.get("Parm8", ""),
                        'Lights': int(prop.get("Parm2", 0))
                    })

    # Insert master props and subprops into the database
    insert_props(preview_id, lor_props)
    insert_sub_props(preview_id, sub_props)

    if DEBUG:
        print(f"[DEBUG] Processed and inserted {len(lor_props)} LOR props and {len(sub_props)} subprops for PreviewID: {preview_id}")









def process_file(file_path):
    """Process a single .lorprev file."""
    print(f"[DEBUG] Processing file: {file_path}")
    preview = locate_preview_class_deep(file_path)
    if preview is not None:
        preview_data = process_preview(preview)
        insert_previews(preview_data)

        # Parse and process DeviceType == None and DMX props
        tree = ET.parse(file_path)
        root = tree.getroot()
        process_none_props(preview_data["id"], root)
        process_dmx_props(preview_data["id"], root)
        process_lor_props(preview_data["id"], root)
        process_lor_multiple_channel_grids(preview_data["id"], root)
    else:
        print(f"[WARNING] No <PreviewClass> found in {file_path}")

def process_folder(folder_path):
    """Process all .lorprev files in the specified folder."""
    if not os.listdir(folder_path):
        print(f"[WARNING] No files found in folder: {folder_path}")
        return

    for file_name in os.listdir(folder_path):
        if file_name.endswith(".lorprev"):
            file_path = os.path.join(folder_path, file_name)
            process_file(file_path)

def main():
    """Main entry point for the script."""
    folder_path = input("Enter the folder path containing .lorprev files: ").strip()

    if not os.path.isdir(folder_path):
        print(f"[ERROR] '{folder_path}' is not a valid directory.")
        return

    # Set up the database
    setup_database()

    # Process all files in the folder
    process_folder(folder_path)
    print("Processing complete. Check the database.")

if __name__ == "__main__":
    main()