# Initial Release: 2022-01-20 V0.1.0
# Written by: Greg Liebig, Engineering Innovations, LLC.
# Description: This script parses LOR .lorprev files and extracts prop data into a SQLite database.


import os
import xml.etree.ElementTree as ET
import sqlite3
from collections import defaultdict
import uuid

DEBUG = False  # Global debug flag
DB_FILE = "G:\\Shared drives\\MSB Database\\database\\lor_output_v5.db"

def setup_database():
    """Initialize the database schema, dropping tables if they already exist."""
    conn = sqlite3.connect(DB_FILE)
    cursor = conn.cursor()

    # Drop tables if they exist
    cursor.execute("DROP TABLE IF EXISTS previews")
    cursor.execute("DROP TABLE IF EXISTS props")
    cursor.execute("DROP TABLE IF EXISTS subProps")
    cursor.execute("DROP TABLE IF EXISTS dmxChannels")
    cursor.execute("DROP TABLE IF EXISTS duplicateProps")

    # Create Previews Table
    cursor.execute("""
    CREATE TABLE previews (
        id TEXT PRIMARY KEY,
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
    )
    """)

    # Create SubProps Table
    cursor.execute("""
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

    """)

    # Create DMX Channels Table
    cursor.execute("""
    CREATE TABLE dmxChannels (
        PropId TEXT,
        Network TEXT,
        StartUniverse INTEGER,
        StartChannel INTEGER,
        EndChannel INTEGER,
        Unknown TEXT,
        PreviewId TEXT,
        PRIMARY KEY (PropId, StartUniverse, StartChannel),
        FOREIGN KEY (PropId) REFERENCES props (PropID),
        FOREIGN KEY (PreviewId) REFERENCES previews (id)
    )
    """)

    # Create Duplicate Props Table
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

def insert_preview_data(preview_data):
    """Insert preview data into the database."""
    conn = sqlite3.connect(DB_FILE)
    cursor = conn.cursor()

    cursor.execute("""
    INSERT OR REPLACE INTO previews (id, StageID, Name, Revision, Brightness, BackgroundFile)
    VALUES (?, ?, ?, ?, ?, ?)
    """, (
        preview_data["id"],
        preview_data["StageID"],
        preview_data["Name"],
        preview_data["Revision"],
        preview_data["Brightness"],
        preview_data["BackgroundFile"]
    ))

    conn.commit()
    conn.close()
    if DEBUG:
        print(f"[DEBUG] Inserted Preview into database: {preview_data}")

def process_none_props(preview_id, root):
    """
    Process props with DeviceType == None:
    - Aggregate lights (Parm2) by LORComment.
    - Ensure one entry per LORComment in the props table.
    """
    conn = sqlite3.connect(DB_FILE)
    cursor = conn.cursor()

    props_summary = defaultdict(lambda: {"Lights": 0, "Name": None, "PropID": None, "DeviceType": None})

    # Collect and aggregate data for props with DeviceType == "None"
    for prop in root.findall(".//PropClass"):
        device_type = prop.get("DeviceType")
        if device_type == "None":
            LORComment = prop.get("Comment")
            Parm2 = prop.get("Parm2")
            lights = int(Parm2) if Parm2 and Parm2.isdigit() else 0

            # Aggregate lights by LORComment
            props_summary[LORComment]["Lights"] += lights
            props_summary[LORComment]["Name"] = prop.get("Name")
            props_summary[LORComment]["PropID"] = prop.get("id")
            props_summary[LORComment]["DeviceType"] = device_type

    # Insert aggregated props into the database
    for LORComment, prop_data in props_summary.items():
        if handle_duplicate_prop(cursor, prop_data["PropID"], prop_data["Name"], LORComment, prop_data["DeviceType"], preview_id, "Duplicate PropID detected"):
            continue  # Skip duplicate

        cursor.execute("""
        INSERT OR REPLACE INTO props (PropID, Name, LORComment, DeviceType, Lights, PreviewId)
        VALUES (?, ?, ?, ?, ?, ?)
        """, (
            prop_data["PropID"],
            prop_data["Name"],
            LORComment,
            prop_data["DeviceType"],
            prop_data["Lights"],
            preview_id
        ))
    if DEBUG:        
        print(f"[DEBUG] Inserted Prop into database: {prop_data}")

    conn.commit()
    conn.close()

def process_dmx_props(preview_id, root):
    """
    Process props with DeviceType == DMX:
    - Identify groups by LORComment.
    - Select the prop with the lowest StartChannel as the master prop.
    - Insert the master prop into the props table.
    - Insert remaining props into the dmxChannels table.
    """
    conn = sqlite3.connect(DB_FILE)
    cursor = conn.cursor()

    # Group props by LORComment
    props_grouped_by_comment = defaultdict(list)
    for prop in root.findall(".//PropClass"):
        if prop.get("DeviceType") == "DMX":
            LORComment = prop.get("Comment", "")
            props_grouped_by_comment[LORComment].append(prop)

    # Process grouped props
    for LORComment, props in props_grouped_by_comment.items():
        # Identify the master prop (lowest StartChannel)
        master_prop = min(
            props,
            key=lambda x: int(x.get("ChannelGrid", "").split(",")[2]) if x.get("ChannelGrid") else float("inf")
        )

        master_prop_id = master_prop.get("id")
        name = master_prop.get("Name", "")
        device_type = master_prop.get("DeviceType", "DMX")

        # Check for duplicate PropID
        if handle_duplicate_prop(cursor, master_prop_id, name, LORComment, device_type, preview_id, "Duplicate PropID detected"):
            continue  # Skip duplicate

        # Insert master prop into the props table
        cursor.execute("""
        INSERT OR REPLACE INTO props (
            PropID, Name, LORComment, DeviceType, Network, UID, StartChannel, EndChannel, Unknown, Color, PreviewId
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, (
            master_prop_id,
            name,
            LORComment,
            device_type,
            master_prop.get("Network"),
            master_prop.get("UID"),
            int(master_prop.get("ChannelGrid", "").split(",")[2]) if master_prop.get("ChannelGrid") else None,
            int(master_prop.get("ChannelGrid", "").split(",")[3]) if master_prop.get("ChannelGrid") else None,
            master_prop.get("ChannelGrid", "").split(",")[4] if master_prop.get("ChannelGrid") else None,
            master_prop.get("ChannelGrid", "").split(",")[5] if master_prop.get("ChannelGrid") else None,
            preview_id
        ))
        if DEBUG:
            print(f"[DEBUG] Inserted Master DMX Prop: {master_prop_id}")

        # Process remaining props as DMX channels
        for prop in props:
            if prop.get("id") == master_prop_id:
                continue  # Skip the master prop

            prop_id = prop.get("id")
            channel_grid = prop.get("ChannelGrid", "")
            grid_parts = channel_grid.split(",") if channel_grid else []

            cursor.execute("""
            INSERT OR REPLACE INTO dmxChannels (
                PropId, Network, StartUniverse, StartChannel, EndChannel, Unknown, PreviewId
            ) VALUES (?, ?, ?, ?, ?, ?, ?)
            """, (
                prop_id,
                grid_parts[0] if len(grid_parts) > 0 else None,
                grid_parts[1] if len(grid_parts) > 1 else None,
                int(grid_parts[2]) if len(grid_parts) > 2 and grid_parts[2].isdigit() else None,
                int(grid_parts[3]) if len(grid_parts) > 3 and grid_parts[3].isdigit() else None,
                grid_parts[4] if len(grid_parts) > 4 else None,
                preview_id
            ))
            if DEBUG:
                print(f"[DEBUG] Inserted DMX Channel for Prop: {prop_id}")

    conn.commit()
    conn.close()


def process_lor_props(preview_id, root):
    """
    Process props with DeviceType == LOR:
    - Single ChannelGrid
    - Identify the master prop as the prop with the lowest StartChannel among props with the same Comment.
    - Insert the master prop into the props table, including its grid parts.
    - Insert remaining props into the subProps table, linking them to the master prop and including their grid parts.
    - If the Name contains 'spare', place the prop directly into the props table and save grid parts.
    """
    conn = sqlite3.connect(DB_FILE)
    cursor = conn.cursor()

    props_grouped_by_comment = defaultdict(list)

    # Group props by LORComment
    for prop in root.findall(".//PropClass"):
        device_type = prop.get("DeviceType")
        if device_type == "LOR":
            LORComment = prop.get("Comment", "")
            props_grouped_by_comment[LORComment].append(prop)

    # Process grouped props
    for LORComment, props in props_grouped_by_comment.items():
        # Identify the master prop (lowest StartChannel)
        master_prop = min(
            props,
            key=lambda x: int(x.get("ChannelGrid", "").split(",")[2])
            if x.get("ChannelGrid") and len(x.get("ChannelGrid").split(",")) > 2 and x.get("ChannelGrid").split(",")[2].isdigit()
            else float("inf")
        )

        master_prop_id = master_prop.get("id")
        name = master_prop.get("Name", "")
        device_type = master_prop.get("DeviceType", "LOR")
        channel_grid = master_prop.get("ChannelGrid", "")

        # Special Rule: If "spare" is in the Name, insert directly into the props table
        if "spare" in name.lower():
            grid_parts = channel_grid.split(";") if channel_grid else []
            for grid in grid_parts:
                grid_data = grid.split(",")
                cursor.execute("""
                INSERT OR REPLACE INTO props (
                    PropID, Name, LORComment, DeviceType, Network, UID, StartChannel, EndChannel, Unknown, Color, PreviewId
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """, (
                    master_prop_id,
                    name,
                    LORComment,
                    device_type,
                    grid_data[0] if len(grid_data) > 0 else None,
                    grid_data[1] if len(grid_data) > 1 else None,
                    int(grid_data[2]) if len(grid_data) > 2 and grid_data[2].isdigit() else None,
                    int(grid_data[3]) if len(grid_data) > 3 and grid_data[3].isdigit() else None,
                    grid_data[4] if len(grid_data) > 4 else None,
                    grid_data[5] if len(grid_data) > 5 else None,
                    preview_id
                ))
                if DEBUG:
                    print(f"[DEBUG] Inserted Spare Prop: {master_prop_id}")
            continue  # Skip further processing for this prop

        # Check for duplicate PropID before inserting master prop
        if handle_duplicate_prop(
            cursor,
            master_prop_id,
            name,
            LORComment,
            device_type,
            preview_id,
            "Duplicate PropID detected"
        ):
            continue  # Skip duplicate

        # Insert master prop into the props table
        grid_parts = channel_grid.split(";") if channel_grid else []
        for grid in grid_parts:
            grid_data = grid.split(",")
            cursor.execute("""
            INSERT OR REPLACE INTO props (
                PropID, Name, LORComment, DeviceType, Network, UID, StartChannel, EndChannel, Unknown, Color, PreviewId
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, (
                master_prop_id,
                name,
                LORComment,
                device_type,
                grid_data[0] if len(grid_data) > 0 else None,
                grid_data[1] if len(grid_data) > 1 else None,
                int(grid_data[2]) if len(grid_data) > 2 and grid_data[2].isdigit() else None,
                int(grid_data[3]) if len(grid_data) > 3 and grid_data[3].isdigit() else None,
                grid_data[4] if len(grid_data) > 4 else None,
                grid_data[5] if len(grid_data) > 5 else None,
                preview_id
            ))
        if DEBUG:
            print(f"[DEBUG] Inserted Master Prop: {master_prop_id}")

        # Insert remaining props into the subProps table
        for prop in props:
            if prop.get("id") == master_prop_id:
                continue  # Skip the master prop

            prop_id = prop.get("id")
            channel_grid = prop.get("ChannelGrid", "")
            sub_grid_parts = channel_grid.split(";") if channel_grid else []

            for grid in sub_grid_parts:
                grid_data = grid.split(",")
                cursor.execute("""
                INSERT OR REPLACE INTO subProps (
                    SubPropID, Name, LORComment, DeviceType, Network, UID, StartChannel, EndChannel, Unknown, Color, PreviewId
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """, (
                    prop_id,
                    prop.get("Name", ""),
                    LORComment,
                    "LOR",
                    grid_data[0] if len(grid_data) > 0 else None,
                    grid_data[1] if len(grid_data) > 1 else None,
                    int(grid_data[2]) if len(grid_data) > 2 and grid_data[2].isdigit() else None,
                    int(grid_data[3]) if len(grid_data) > 3 and grid_data[3].isdigit() else None,
                    grid_data[4] if len(grid_data) > 4 else None,
                    grid_data[5] if len(grid_data) > 5 else None,
                    preview_id
                ))
                if DEBUG:
                    print(f"[DEBUG] Inserted SubProp: {prop_id}")

    conn.commit()
    conn.close()


def process_lor_multiple_channel_grids(preview_id, root):
    """
    Process props with DeviceType == LOR and multiple ChannelGrid groups:
    - Group props by LORComment.
    - Identify the prop with the lowest StartChannel as the master prop for the group and write it to the props table.
    - Process remaining props as subprops, including their ChannelGrid groups.
    - Applies the naming convention to both props and subprops.
    - Check for duplicates using the duplicateProps table.
    """
    conn = sqlite3.connect(DB_FILE)
    cursor = conn.cursor()

    # Ensure the duplicateProps table exists
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

    # Group props by LORComment
    props_grouped_by_comment = defaultdict(list)
    for prop in root.findall(".//PropClass"):
        device_type = prop.get("DeviceType")
        if device_type == "LOR" and ";" in prop.get("ChannelGrid", ""):
            LORComment = prop.get("Comment", "")
            props_grouped_by_comment[LORComment].append(prop)

    # Process each group of props by LORComment
    for LORComment, props in props_grouped_by_comment.items():
        # Identify the master prop (lowest StartChannel)
        master_prop = min(
            props,
            key=lambda x: int(x.get("ChannelGrid", "").split(",")[2])
            if x.get("ChannelGrid") and len(x.get("ChannelGrid").split(",")) > 2 and x.get("ChannelGrid").split(",")[2].isdigit()
            else float("inf")
        )

        master_prop_id = master_prop.get("id")
        master_name = master_prop.get("Name", "")
        device_type = master_prop.get("DeviceType", "LOR")
        master_channel_grid = master_prop.get("ChannelGrid", "")
        master_grid_parts = master_channel_grid.split(";") if master_channel_grid else []

        # Check for duplicate PropID before inserting master prop
        if handle_duplicate_prop(
            cursor,
            master_prop_id,
            master_name,
            LORComment,
            device_type,
            preview_id,
            "Duplicate PropID detected"
        ):
            continue  # Skip duplicate

        # Insert master prop into the props table
        for grid in master_grid_parts:
            grid_data = grid.split(",")
            cursor.execute("""
            INSERT OR REPLACE INTO props (
                PropID, Name, LORComment, DeviceType, Network, UID, StartChannel, EndChannel, Unknown, Color, PreviewId
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, (
                master_prop_id,
                master_name,
                LORComment,
                device_type,
                grid_data[0] if len(grid_data) > 0 else None,
                grid_data[1] if len(grid_data) > 1 else None,
                int(grid_data[2]) if len(grid_data) > 2 and grid_data[2].isdigit() else None,
                int(grid_data[3]) if len(grid_data) > 3 and grid_data[3].isdigit() else None,
                grid_data[4] if len(grid_data) > 4 else None,
                grid_data[5] if len(grid_data) > 5 else None,
                preview_id
            ))
        if DEBUG:
            print(f"[DEBUG] Inserted Master Prop: {master_prop_id}")

        # Process remaining props as subprops
        for prop in props:
            if prop.get("id") == master_prop_id:
                continue  # Skip the master prop

            subprop_id = prop.get("id")
            subprop_name = prop.get("Name", "")
            subprop_channel_grid = prop.get("ChannelGrid", "")
            subprop_grid_parts = subprop_channel_grid.split(";") if subprop_channel_grid else []

            for grid in subprop_grid_parts:
                grid_data = grid.split(",")
                cursor.execute("""
                INSERT OR REPLACE INTO subProps (
                    SubPropID, Name, LORComment, DeviceType, Network, UID, StartChannel, EndChannel, Unknown, Color, PreviewId
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """, (
                    subprop_id,
                    subprop_name,
                    LORComment,
                    device_type,
                    grid_data[0] if len(grid_data) > 0 else None,
                    grid_data[1] if len(grid_data) > 1 else None,
                    int(grid_data[2]) if len(grid_data) > 2 and grid_data[2].isdigit() else None,
                    int(grid_data[3]) if len(grid_data) > 3 and grid_data[3].isdigit() else None,
                    grid_data[4] if len(grid_data) > 4 else None,
                    grid_data[5] if len(grid_data) > 5 else None,
                    preview_id
                ))
                if DEBUG:
                    print(f"[DEBUG] Inserted SubProp: {subprop_id}")

    conn.commit()
    conn.close()










def process_file(file_path):
    """Process a single .lorprev file."""
    print(f"[DEBUG] Processing file: {file_path}")
    preview = locate_preview_class_deep(file_path)
    if preview is not None:
        preview_data = process_preview(preview)
        insert_preview_data(preview_data)

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