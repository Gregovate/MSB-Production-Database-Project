# Initial Release: 2022-01-20 V0.1.0
# Written by: Greg Liebig, Engineering Innovations, LLC.
# Description: This script parses LOR .lorprev files and extracts prop data into a SQLite database.
# Modified Schema as a test to create a new primary Key as an integer

import os
import xml.etree.ElementTree as ET
import sqlite3
from collections import defaultdict
import uuid

DEBUG = False  # Global debug flag
DB_FILE = "G:\Shared drives\MSB Database\database\lor_output_v6.db"

def setup_database():
    """Initialize the database schema, dropping tables if they already exist."""
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
        PropID TEXT UNIQUE,
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
            IntSubPropID INTEGER PRIMARY KEY AUTOINCREMENT,
            SubPropID TEXT UNIQUE,
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
        IntDMXChannelID INTEGER PRIMARY KEY AUTOINCREMENT,
        PropId TEXT,
        Network TEXT,
        StartUniverse INTEGER,
        StartChannel INTEGER,
        EndChannel INTEGER,
        Unknown TEXT,
        PreviewId TEXT,
        FOREIGN KEY (PropId) REFERENCES props (PropID),
        FOREIGN KEY (PreviewId) REFERENCES previews (id)
    );
    """)

    conn.commit()
    conn.close()
    print("[DEBUG] Database setup complete, all tables created.")

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
    - Split ChannelGrid into groups.
    - Insert all relevant fields from PropClass into the props table.
    - Insert DMX channels into the dmxChannels table.
    """
    conn = sqlite3.connect(DB_FILE)
    cursor = conn.cursor()

    for prop in root.findall(".//PropClass"):
        device_type = prop.get("DeviceType")
        if device_type == "DMX":
            master_prop_id = prop.get("id")  # Use the original PropID from XML
            name = prop.get("Name")
            LORComment = prop.get("Comment")
            bulb_shape = prop.get("BulbShape")
            dimming_curve_name = prop.get("DimmingCurveName")
            max_channels = prop.get("MaxChannels")
            custom_bulb_color = prop.get("CustomBulbColor")
            individual_channels = prop.get("IndividualChannels")
            legacy_sequence_method = prop.get("LegacySequenceMethod")
            opacity = prop.get("Opacity")
            master_dimmable = prop.get("MasterDimmable")
            preview_bulb_size = prop.get("PreviewBulbSize")
            separate_ids = prop.get("SeparateIds")
            start_location = prop.get("StartLocation")
            string_type = prop.get("StringType")
            traditional_colors = prop.get("TraditionalColors")
            traditional_type = prop.get("TraditionalType")
            effect_bulb_size = prop.get("EffectBulbSize")
            tag = prop.get("Tag")
            parm1 = prop.get("Parm1")
            parm2 = prop.get("Parm2")
            parm3 = prop.get("Parm3")
            parm4 = prop.get("Parm4")
            parm5 = prop.get("Parm5")
            parm6 = prop.get("Parm6")
            parm7 = prop.get("Parm7")
            parm8 = prop.get("Parm8")
            lights = int(parm2) if parm2 and parm2.isdigit() else 0  # Assume Parm2 is light count
            channel_grid = prop.get("ChannelGrid")

            # Insert Master Prop into props table
            cursor.execute("""
            INSERT OR REPLACE INTO props (
                PropID, Name, LORComment, DeviceType, BulbShape, DimmingCurveName,
                MaxChannels, CustomBulbColor, IndividualChannels, LegacySequenceMethod,
                Opacity, MasterDimmable, PreviewBulbSize, SeparateIds, StartLocation,
                StringType, TraditionalColors, TraditionalType, EffectBulbSize, Tag,
                Parm1, Parm2, Parm3, Parm4, Parm5, Parm6, Parm7, Parm8, Lights, PreviewId
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, (
                master_prop_id, name, LORComment, device_type, bulb_shape, dimming_curve_name,
                max_channels, custom_bulb_color, individual_channels, legacy_sequence_method,
                opacity, master_dimmable, preview_bulb_size, separate_ids, start_location,
                string_type, traditional_colors, traditional_type, effect_bulb_size, tag,
                parm1, parm2, parm3, parm4, parm5, parm6, parm7, parm8, lights, preview_id
            ))
            if DEBUG:
                print(f"[DEBUG] Inserted Master Prop: {master_prop_id}")

            # Process ChannelGrid for dmxChannels table
            if channel_grid:
                grid_parts = channel_grid.split(";")
                for grid in grid_parts:
                    parts = grid.split(",")
                    if len(parts) >= 5:
                        network = parts[0]
                        start_universe = int(parts[1])
                        start_channel = int(parts[2])
                        end_channel = int(parts[3])
                        unknown = parts[4]

                        # Insert into dmxChannels table
                        cursor.execute("""
                        INSERT OR REPLACE INTO dmxChannels (
                            PropId, Network, StartUniverse, StartChannel, EndChannel, Unknown, PreviewId
                        ) VALUES (?, ?, ?, ?, ?, ?, ?)
                        """, (
                            master_prop_id, network, start_universe, start_channel, end_channel, unknown, preview_id
                        ))
                        if DEBUG:
                            print(f"[DEBUG] Inserted DMX Channel: Network={network}, Universe={start_universe}, Start={start_channel}, End={end_channel}")

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

    props_grouped_by_comment = {}

    # Group props by Comment
    for prop in root.findall(".//PropClass"):
        device_type = prop.get("DeviceType")
        if device_type == "LOR":
            # Safely get attributes with defaults
            prop_data = {
                "PropID": prop.get("id", None),
                "Name": prop.get("Name", ""),
                "DeviceType": device_type,
                "LORComment": prop.get("Comment", ""),  # Default to empty string
                "MasterPropID": prop.get("MasterPropId", None),
                "BulbShape": prop.get("BulbShape", ""),
                "DimmingCurveName": prop.get("DimmingCurveName", ""),
                "MaxChannels": prop.get("MaxChannels", None),
                "CustomBulbColor": prop.get("CustomBulbColor", ""),
                "IndividualChannels": prop.get("IndividualChannels", False),
                "LegacySequenceMethod": prop.get("LegacySequenceMethod", ""),
                "Opacity": prop.get("Opacity", None),
                "MasterDimmable": prop.get("MasterDimmable", False),
                "PreviewBulbSize": prop.get("PreviewBulbSize", None),
                "SeparateIds": prop.get("SeparateIds", False),
                "StartLocation": prop.get("StartLocation", ""),
                "StringType": prop.get("StringType", ""),
                "TraditionalColors": prop.get("TraditionalColors", ""),
                "TraditionalType": prop.get("TraditionalType", ""),
                "EffectBulbSize": prop.get("EffectBulbSize", None),
                "Tag": prop.get("Tag", ""),
                "Parm1": prop.get("Parm1", ""),
                "Parm2": prop.get("Parm2", ""),
                "Parm3": prop.get("Parm3", ""),
                "Parm4": prop.get("Parm4", ""),
                "Parm5": prop.get("Parm5", ""),
                "Parm6": prop.get("Parm6", ""),
                "Parm7": prop.get("Parm7", ""),
                "Parm8": prop.get("Parm8", ""),
                "Lights": int(prop.get("Parm2")) if prop.get("Parm2") and prop.get("Parm2").isdigit() else 0,
                "ChannelGrid": prop.get("ChannelGrid", ""),
                "PreviewId": preview_id
            }

            # Parse ChannelGrid for grid data
            channel_grid = prop_data["ChannelGrid"]
            if channel_grid:
                grid_parts = channel_grid.split(";")
                grid_data = []
                for grid in grid_parts:
                    parts = grid.split(",")
                    grid_data.append({
                        "Network": parts[0] if len(parts) > 0 else None,
                        "UID": parts[1] if len(parts) > 1 else None,
                        "StartChannel": int(parts[2]) if len(parts) > 2 and parts[2].isdigit() else None,
                        "EndChannel": int(parts[3]) if len(parts) > 3 and parts[3].isdigit() else None,
                        "Unknown": parts[4] if len(parts) > 4 else None,
                        "Color": parts[5] if len(parts) > 5 else None
                    })
                prop_data["GridData"] = grid_data
                prop_data["StartChannel"] = min(
                    [g["StartChannel"] for g in grid_data if g["StartChannel"] is not None], default=None
                )
            else:
                prop_data["GridData"] = []
                prop_data["StartChannel"] = None


            if prop_data["LORComment"] not in props_grouped_by_comment:
                props_grouped_by_comment[prop_data["LORComment"]] = []
            props_grouped_by_comment[prop_data["LORComment"]].append(prop_data)

    # Process grouped props
    for LORComment, props in props_grouped_by_comment.items():
        # Identify the master prop (lowest StartChannel)
        master_prop = min(props, key=lambda x: x["StartChannel"] or float("inf"))

        # Extract the first grid part for the master prop
        master_grid = master_prop["GridData"][0] if master_prop["GridData"] else {
            "Network": None,
            "UID": None,
            "StartChannel": None,
            "EndChannel": None,
            "Unknown": None,
            "Color": None
        }

        # Insert master prop into the props table
        # Insert master prop into the props table
        cursor.execute("""
        INSERT OR REPLACE INTO props (
            PropID, Name, LORComment, DeviceType, BulbShape, DimmingCurveName, MaxChannels,
            CustomBulbColor, IndividualChannels, LegacySequenceMethod, Opacity, MasterDimmable,
            PreviewBulbSize, SeparateIds, StartLocation, StringType, TraditionalColors, TraditionalType,
            EffectBulbSize, Tag, Parm1, Parm2, Parm3, Parm4, Parm5, Parm6, Parm7, Parm8, Lights,
            Network, UID, StartChannel, EndChannel, Unknown, Color, PreviewId
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, (
            master_prop["PropID"], master_prop["Name"], master_prop["LORComment"], master_prop["DeviceType"],
            master_prop["BulbShape"], master_prop["DimmingCurveName"], master_prop["MaxChannels"],
            master_prop["CustomBulbColor"], master_prop["IndividualChannels"], master_prop["LegacySequenceMethod"],
            master_prop["Opacity"], master_prop["MasterDimmable"], master_prop["PreviewBulbSize"],
            master_prop["SeparateIds"], master_prop["StartLocation"], master_prop["StringType"],
            master_prop["TraditionalColors"], master_prop["TraditionalType"], master_prop["EffectBulbSize"],
            master_prop["Tag"], master_prop["Parm1"], master_prop["Parm2"], master_prop["Parm3"], master_prop["Parm4"],
            master_prop["Parm5"], master_prop["Parm6"], master_prop["Parm7"], master_prop["Parm8"],
            master_prop["Lights"], master_grid["Network"], master_grid["UID"], master_grid["StartChannel"],
            master_grid["EndChannel"], master_grid["Unknown"], master_grid["Color"], master_prop["PreviewId"]
        ))

        if DEBUG:
            print(f"[DEBUG] Inserted Master Prop: {master_prop['PropID']} with Grid Parts")

        # Process remaining props as subprops
        for subprop in props:
            if subprop["PropID"] != master_prop["PropID"]:
                for grid in subprop["GridData"]:
                    cursor.execute("""
                    INSERT OR REPLACE INTO subProps (
                        SubPropID, Name, LORComment, DeviceType, BulbShape, Network, UID, StartChannel,
                        EndChannel, Unknown, Color, CustomBulbColor, DimmingCurveName, IndividualChannels,
                        LegacySequenceMethod, MaxChannels, Opacity, MasterDimmable, PreviewBulbSize, RgbOrder,
                        MasterPropId, SeparateIds, StartLocation, StringType, TraditionalColors, TraditionalType,
                        EffectBulbSize, Tag, Parm1, Parm2, Parm3, Parm4, Parm5, Parm6, Parm7, Parm8, Lights, PreviewId
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """, (
                        subprop["PropID"], subprop["Name"], subprop["LORComment"], subprop["DeviceType"],
                        subprop["BulbShape"], grid["Network"], grid["UID"], grid["StartChannel"],
                        grid["EndChannel"], grid["Unknown"], grid["Color"], subprop["CustomBulbColor"],
                        subprop["DimmingCurveName"], subprop["IndividualChannels"], subprop["LegacySequenceMethod"],
                        subprop["MaxChannels"], subprop["Opacity"], subprop["MasterDimmable"], subprop["PreviewBulbSize"],
                        None, master_prop["PropID"], subprop["SeparateIds"], subprop["StartLocation"],
                        subprop["StringType"], subprop["TraditionalColors"], subprop["TraditionalType"],
                        subprop["EffectBulbSize"], subprop["Tag"], subprop["Parm1"], subprop["Parm2"],
                        subprop["Parm3"], subprop["Parm4"], subprop["Parm5"], subprop["Parm6"], subprop["Parm7"],
                        subprop["Parm8"], subprop["Lights"], subprop["PreviewId"]
                    ))
                    if DEBUG:
                        print(f"[DEBUG] Inserted SubProp: {subprop['PropID']} with MasterPropID: {master_prop['PropID']} and GridData: {grid}")

    conn.commit()
    conn.close()



def process_lor_multiple_channel_grids(preview_id, root):
    """
    Process props with DeviceType == LOR and multiple ChannelGrid groups.
    - Retains the original master prop in the props table.
    - Parses each ChannelGrid group and creates subprops.
    - Inserts subprops into the subProps table with grid data and links to the master prop.
    """
    conn = sqlite3.connect(DB_FILE)
    cursor = conn.cursor()

    for prop in root.findall(".//PropClass"):
        device_type = prop.get("DeviceType")
        master_prop_id = prop.get("id")
        if device_type == "LOR" and prop.get("MasterPropId", "") == "" and ";" in prop.get("ChannelGrid", ""):
            # Master Prop
            name = prop.get("Name")
            LORComment = prop.get("Comment")
            channel_grid = prop.get("ChannelGrid")
            grid_groups = channel_grid.split(";")

            if DEBUG:
                print(f"[DEBUG] Processing Master Prop: {master_prop_id} with ChannelGrid Groups: {len(grid_groups)}")

            # Insert master prop into props table
            cursor.execute("""
            INSERT OR REPLACE INTO props (
                PropID, Name, LORComment, DeviceType, BulbShape, DimmingCurveName, MaxChannels,
                CustomBulbColor, IndividualChannels, LegacySequenceMethod, Opacity, MasterDimmable,
                PreviewBulbSize, SeparateIds, StartLocation, StringType, TraditionalColors, TraditionalType,
                EffectBulbSize, Tag, Parm1, Parm2, Parm3, Parm4, Parm5, Parm6, Parm7, Parm8, Lights, PreviewId
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, (
                master_prop_id, name, LORComment, device_type, prop.get("BulbShape"), prop.get("DimmingCurveName"),
                prop.get("MaxChannels"), prop.get("CustomBulbColor"), prop.get("IndividualChannels"),
                prop.get("LegacySequenceMethod"), prop.get("Opacity"), prop.get("MasterDimmable"),
                prop.get("PreviewBulbSize"), prop.get("SeparateIds"), prop.get("StartLocation"),
                prop.get("StringType"), prop.get("TraditionalColors"), prop.get("TraditionalType"),
                prop.get("EffectBulbSize"), prop.get("Tag"), prop.get("Parm1"), prop.get("Parm2"),
                prop.get("Parm3"), prop.get("Parm4"), prop.get("Parm5"), prop.get("Parm6"), prop.get("Parm7"),
                prop.get("Parm8"), int(prop.get("Parm2") or 0), preview_id
            ))
            if DEBUG:
                print(f"[DEBUG] Inserted Master Prop: {master_prop_id}")

            # Process ChannelGrid Groups
            for grid in grid_groups:
                grid_parts = grid.split(",")
                start_channel = int(grid_parts[2]) if len(grid_parts) > 2 and grid_parts[2].isdigit() else 0
                subprop_id_suffix = f"{start_channel:02d}"  # Format StartChannel as two digits
                subprop_id = f"{master_prop_id}-{subprop_id_suffix}"

                # Extract the first part of LORComment
                lor_comment_first_part = LORComment.split(" ")[0] if LORComment else ""

                # Subprop Name: 1st part of LOR Comment, Color, UID, StartChannel padded to 2 places
                subprop_name = f"{lor_comment_first_part} {grid_parts[5] if len(grid_parts) > 5 else ''} " \
                               f"{grid_parts[1] if len(grid_parts) > 1 else ''}-{start_channel:02d}".strip()

                subprop_data = {
                    "Network": grid_parts[0] if len(grid_parts) > 0 else None,
                    "UID": grid_parts[1] if len(grid_parts) > 1 else None,
                    "StartChannel": start_channel,
                    "EndChannel": int(grid_parts[3]) if len(grid_parts) > 3 and grid_parts[3].isdigit() else None,
                    "Unknown": grid_parts[4] if len(grid_parts) > 4 else None,
                    "Color": grid_parts[5] if len(grid_parts) > 5 else None
                }

                # Insert subprop into the subProps table
                cursor.execute("""
                INSERT OR REPLACE INTO subProps (
                    SubPropID, Name, LORComment, DeviceType, BulbShape, Network, UID, StartChannel,
                    EndChannel, Unknown, Color, CustomBulbColor, DimmingCurveName, IndividualChannels,
                    LegacySequenceMethod, MaxChannels, Opacity, MasterDimmable, PreviewBulbSize, RgbOrder,
                    MasterPropId, SeparateIds, StartLocation, StringType, TraditionalColors, TraditionalType,
                    EffectBulbSize, Tag, Parm1, Parm2, Parm3, Parm4, Parm5, Parm6, Parm7, Parm8, Lights, PreviewId
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """, (
                    subprop_id, subprop_name, LORComment, device_type, prop.get("BulbShape"),
                    subprop_data["Network"], subprop_data["UID"], subprop_data["StartChannel"],
                    subprop_data["EndChannel"], subprop_data["Unknown"], subprop_data["Color"],
                    prop.get("CustomBulbColor"), prop.get("DimmingCurveName"), prop.get("IndividualChannels"),
                    prop.get("LegacySequenceMethod"), prop.get("MaxChannels"), prop.get("Opacity"),
                    prop.get("MasterDimmable"), prop.get("PreviewBulbSize"), None, master_prop_id,
                    prop.get("SeparateIds"), prop.get("StartLocation"), prop.get("StringType"),
                    prop.get("TraditionalColors"), prop.get("TraditionalType"), prop.get("EffectBulbSize"),
                    prop.get("Tag"), prop.get("Parm1"), prop.get("Parm2"), prop.get("Parm3"), prop.get("Parm4"),
                    prop.get("Parm5"), prop.get("Parm6"), prop.get("Parm7"), prop.get("Parm8"),
                    int(prop.get("Parm2") or 0), preview_id
                ))
                if DEBUG:
                    print(f"[DEBUG] Inserted SubProp: {subprop_id} with Name: {subprop_name}")

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

    # ✅ Build the wiring views in the SAME DB file the parser just wrote
    create_wiring_views_v6(DB_FILE)
    
    print("Processing complete. Check the database.")

# === Wiring views for V6 (map + sorted) GAL 25-08-23 ===
def create_wiring_views_v6(db_file: str):
    import sqlite3

    ddl = """
    DROP VIEW IF EXISTS preview_wiring_map_v6;
    CREATE VIEW preview_wiring_map_v6 AS
        -- Master props (single-grid legs on props)
        SELECT
            pv.Name             AS PreviewName,
            TRIM(p.LORComment)  AS DisplayName,   -- LOR Comment (Display)
            p.Name              AS LORName,       -- LOR Name
            p.Network           AS Network,
            p.UID               AS Controller,
            p.StartChannel      AS StartChannel,
            p.EndChannel        AS EndChannel,
            p.DeviceType        AS DeviceType,
            'PROP'              AS Source,
            p.Tag               AS LORTag
        FROM props p
        JOIN previews pv ON pv.id = p.PreviewId
        WHERE p.Network IS NOT NULL AND p.StartChannel IS NOT NULL

        UNION ALL
        -- Materialized multi-grid legs + LOR cross-reuse (subProps)
        -- If a subProp comment is blank, fall back to the master's comment
        SELECT
            pv.Name,
            TRIM(COALESCE(NULLIF(sp.LORComment,''), p.LORComment)) AS DisplayName,
            sp.Name,
            sp.Network,
            sp.UID,
            sp.StartChannel,
            sp.EndChannel,
            COALESCE(sp.DeviceType,'LOR') AS DeviceType,
            'SUBPROP' AS Source,
            sp.Tag
        FROM subProps sp
        JOIN props p  ON p.PropID = sp.MasterPropId
        JOIN previews pv ON pv.id = sp.PreviewId

        UNION ALL
        -- DMX universes (controller shown as Universe)
        SELECT
            pv.Name,
            TRIM(p.LORComment),
            p.Name,
            dc.Network,
            CAST(dc.StartUniverse AS TEXT),
            dc.StartChannel,
            dc.EndChannel,
            'DMX',
            'DMX',
            p.Tag
        FROM dmxChannels dc
        JOIN props p  ON p.PropID = dc.PropId
        JOIN previews pv ON pv.id = p.PreviewId;

    DROP VIEW IF EXISTS preview_wiring_sorted_v6;
    CREATE VIEW preview_wiring_sorted_v6 AS
    SELECT
      PreviewName,
      DisplayName,
      LORName,
      Network,
      Controller,
      StartChannel,
      EndChannel,
      DeviceType,
      Source,
      LORTag
    FROM preview_wiring_map_v6
    ORDER BY
      PreviewName  COLLATE NOCASE ASC,
      DisplayName  COLLATE NOCASE ASC,
      Controller   ASC,
      StartChannel ASC;

    -- Helpful indexes for speed when filtering/sorting
    CREATE INDEX IF NOT EXISTS idx_props_preview     ON props(PreviewId);
    CREATE INDEX IF NOT EXISTS idx_subprops_preview  ON subProps(PreviewId);
    CREATE INDEX IF NOT EXISTS idx_dmx_prop          ON dmxChannels(PropId);
    """

    conn = sqlite3.connect(db_file)
    try:
        conn.executescript(ddl)
        conn.commit()
        print("[INFO] Created preview_wiring_map_v6 and preview_wiring_sorted_v6.")
    finally:
        conn.close()


if __name__ == "__main__":
    main()