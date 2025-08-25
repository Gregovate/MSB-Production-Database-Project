# Initial Release: 2022-01-20 V0.1.0
# Written by: Greg Liebig, Engineering Innovations, LLC.
# Description: This script parses LOR .lorprev files and extracts prop data into a SQLite database.
# Modified Schema as a test to create a new primary Key as an integer

import os
import xml.etree.ElementTree as ET
import sqlite3
from collections import defaultdict
import uuid

# ---- Global flags & defaults (must be defined before functions) ----
DEBUG = False  # Global debug flag

DEFAULT_DB_FILE = r"G:\Shared drives\MSB Database\database\lor_output_v6.db"
DEFAULT_PREVIEW_PATH = r"G:\Shared drives\MSB Database\Database Previews"

# Globals that existing functions use; will be set in main()
DB_FILE = DEFAULT_DB_FILE
PREVIEW_PATH = DEFAULT_PREVIEW_PATH

def get_path(prompt: str, default_path: str) -> str:
    """Prompt for a path, using a default if user just hits Enter."""
    user_input = input(f"{prompt} [{default_path}]: ").strip()
    if user_input:
        return os.path.normpath(user_input)
    return default_path

def dprint(msg: str):
    """Safe debug print that won't crash if DEBUG isn't bound elsewhere."""
    if DEBUG:
        print(msg)

# --- ID scoping: prevent cross-preview overwrites --------------------------
def scoped_id(preview_id: str, raw_id: str) -> str:
    """
    Visualizer reuses PropClass.id across previews. Scope every ID by PreviewId
    so (props, subProps, dmx, etc.) never collide between different previews.
    """
    return f"{preview_id}:{raw_id}"
# --- helpers ---------------------------------------------------------------
def safe_int(s, default=None):
    """
    Return int(s) if s is a clean digit string; else `default`.
    Examples:
      safe_int("12") -> 12
      safe_int(" 07 ") -> 7
      safe_int(None) -> default
      safe_int("5F") -> default
    """
    if s is None:
        return default
    s = str(s).strip()
    return int(s) if s.isdigit() else default

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
    Process props with DeviceType == "None":
    - Aggregate lights (Parm2) by LORComment.
    - Ensure exactly ONE props row per LORComment for THIS preview.
    - Use a PREVIEW-SCOPED, GROUP-LEVEL PropID so cross-preview collisions are impossible.

    WHY A GROUP-LEVEL ID?
    ---------------------
    Visualizer may reuse PropClass.id across previews, and even within a preview
    you can have multiple raw ids sharing the same LORComment. Since we collapse
    these into one row per LORComment, we should NOT pick one raw id; instead we
    synthesize a stable, preview-scoped group id:

        group_prop_id = f"{preview_id}:none:{LORComment}"

    That way:
      • Importing another preview won’t overwrite these rows.
      • Re-runs for the same preview produce the same key.
    """
    import sqlite3
    from collections import defaultdict

    conn = sqlite3.connect(DB_FILE)
    cursor = conn.cursor()

    # ----------------------------- helpers -----------------------------------
    def safe_lights(parm2):
        """Return int(Parm2) if it's a clean digit string; else 0."""
        if parm2 is None:
            return 0
        s = str(parm2).strip()
        return int(s) if s.isdigit() else 0

    def group_prop_id(preview_id_str, lor_comment):
        """
        Build a stable, preview-scoped id for the aggregated row.
        We keep the raw comment text; SQLite TEXT keys are fine with spaces.
        """
        lc = (lor_comment or "")
        return f"{preview_id_str}:none:{lc}"

    # -------------------------------------------------------------------------
    # Aggregate all DeviceType == "None" by LORComment
    #
    # We keep:
    #   Lights: total Parm2 across the group
    #   Name:   first non-empty Name encountered in the group (for display)
    #   RawIDs: set of raw PropClass ids (debug only)
    # -------------------------------------------------------------------------
    props_summary = defaultdict(lambda: {
        "Lights": 0,
        "Name":   None,
        "RawIDs": set(),
    })

    for prop in root.findall(".//PropClass"):
        if prop.get("DeviceType") != "None":
            continue

        lor_comment = prop.get("Comment")
        lights = safe_lights(prop.get("Parm2"))

        g = props_summary[lor_comment]
        g["Lights"] += lights
        if not g["Name"]:
            nm = prop.get("Name")
            if nm:
                g["Name"] = nm
        raw_id = prop.get("id")
        if raw_id:
            g["RawIDs"].add(raw_id)

    # -------------------------------------------------------------------------
    # Write one row per LORComment to props, using the preview-scoped group id
    # -------------------------------------------------------------------------
    for lor_comment, g in props_summary.items():
        # Choose a display name: first non-empty Name, else fall back to comment
        display_name = g["Name"] or (lor_comment or "(no name)")

        scoped_group_id = group_prop_id(preview_id, lor_comment)

        cursor.execute("""
            INSERT OR REPLACE INTO props (
                PropID, Name, LORComment, DeviceType, Lights, PreviewId
            ) VALUES (?, ?, ?, ?, ?, ?)
        """, (
            scoped_group_id,             # << preview-scoped, group-level id
            display_name,
            lor_comment,
            "None",                      # DeviceType for this handler
            g["Lights"],
            preview_id
        ))

        if DEBUG:
            # Print a compact debug line showing the aggregation result
            raw_ids_note = f"{len(g['RawIDs'])} raw ids" if g["RawIDs"] else "0 raw ids"
            print(f"[DEBUG] (None) Upsert props: id={scoped_group_id} comment='{lor_comment}' "
                  f"name='{display_name}' lights={g['Lights']} ({raw_ids_note})")

    conn.commit()
    conn.close()


def process_dmx_props(preview_id, root):
    """
    Process props with DeviceType == DMX:
    - Split ChannelGrid into groups.
    - Insert all relevant fields from PropClass into the props table.
    - Insert DMX channels into the dmxChannels table.

    IMPORTANT: ID SCOPING
    ---------------------
    Visualizer reuses PropClass.id across *different* previews. If we store the raw
    id, a later preview can overwrite an earlier one. To prevent cross-preview
    clobbering, we scope every id we write using the current preview_id:

        scoped_id = f"{preview_id}:{raw_id}"

    We must use the SAME scoped id consistently for:
      - props.PropID
      - dmxChannels.PropId
      - (and anywhere else we reference that prop)
    """

    conn = sqlite3.connect(DB_FILE)
    cursor = conn.cursor()

    for prop in root.findall(".//PropClass"):
        device_type = prop.get("DeviceType")
        if device_type != "DMX":
            continue

        # RAW id from Visualizer; we DO NOT store this directly in the DB
        raw_id = prop.get("id")
        master_prop_id = scoped_id(preview_id, raw_id)   # << scoped id used everywhere below

        # --- fields copied as-is from the PropClass --------------------------
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
        # Your original assumption: Parm2 holds light count for DMX
        lights = int(parm2) if parm2 and str(parm2).isdigit() else 0

        channel_grid = prop.get("ChannelGrid") or ""

        # --- Master Prop -> props (scoped PropID) ----------------------------
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
            print(f"[DEBUG] (DMX) Inserted Master Prop: raw_id={raw_id} scoped_id={master_prop_id}  Name={name}")

        # --- ChannelGrid -> dmxChannels (one row per ';' group) --------------
        # Expected DMX pattern per your data: "Network,StartUniverse,StartChannel,EndChannel,Unknown"
        if channel_grid.strip():
            for grid in channel_grid.split(";"):
                grid = grid.strip()
                if not grid:
                    continue
                parts = [p.strip() for p in grid.split(",")]

                # Be defensive: require at least the first 5 tokens
                if len(parts) < 5:
                    if DEBUG:
                        print(f"[DEBUG] (DMX) Skipping malformed grid (len={len(parts)}): {grid}")
                    continue

                network        = parts[0]
                start_universe = safe_int(parts[1], 0)
                start_channel  = safe_int(parts[2], 0)
                end_channel    = safe_int(parts[3], 0)
                unknown        = parts[4]  # keep as string

                cursor.execute("""
                    INSERT OR REPLACE INTO dmxChannels (
                        PropId, Network, StartUniverse, StartChannel, EndChannel, Unknown, PreviewId
                    ) VALUES (?, ?, ?, ?, ?, ?, ?)
                """, (
                    master_prop_id,   # << use the same scoped id we used for props.PropID
                    network, start_universe, start_channel, end_channel, unknown, preview_id
                ))
                if DEBUG:
                    print(f"[DEBUG] (DMX) Inserted Channel: PropId={master_prop_id} Net={network} Univ={start_universe} Start={start_channel} End={end_channel}")

    conn.commit()
    conn.close()


def process_lor_props(preview_id, root):
    """
    Process props with DeviceType == LOR (SINGLE ChannelGrid ONLY):

    RULES
    -----
    - Skip multi-grid props here (handled by process_lor_multiple_channel_grids).
    - 'Spare' (Name contains 'spare', case-insensitive) goes directly to props (keep its grid).
    - If MasterPropId != "" => this XML record is a MANUAL SUBPROP:
        * Write to subProps using THIS record's own grid (if missing, copy master's grid).
        * Keep Name (Channel Name) and LORComment (Display Name) EXACTLY as in XML.
    - Else (MasterPropId == "") => AUTO GROUP by LORComment (Display Name):
        * Choose lowest StartChannel as master -> write to props with its grid.
        * Remaining rows become subProps under that master.
        * SubPropID is derived: "<master_id>-<UID or NA>-<Start:02d>" (deterministic).
        * Keep Name and LORComment EXACTLY as in XML.

    IMPORTANT: ID SCOPING
    - Visualizer reuses PropClass.id across previews. Always scope ids by preview:
        scoped = f"{preview_id}:{raw_id}"
      Use the scoped value for:
        - props.PropID
        - subProps.MasterPropId
        - subProps.SubPropID (for manual subprops use child's own scoped id;
                              for auto subprops use the derived "<master>-<UID>-<Start:02d>").
    """

    import sqlite3
    conn = sqlite3.connect(DB_FILE)
    cursor = conn.cursor()

    # --- helper: parse single-grid "Network,UID,Start,End,Unknown[,Color]" ---
    def parse_single_grid(channel_grid_text):
        if not channel_grid_text:
            return None
        parts = [p.strip() for p in channel_grid_text.split(",")]
        if len(parts) < 5:
            return None
        return {
            "Network":      parts[0],
            "UID":          parts[1] if len(parts) > 1 else None,
            "StartChannel": safe_int(parts[2]),
            "EndChannel":   safe_int(parts[3]),
            "Unknown":      parts[4],
            "Color":        parts[5] if len(parts) > 5 else None,
        }

    # -----------------------------------------------------------------------
    # PASS 0: SPARE rows (single-grid) -> props as-is, no grouping
    # -----------------------------------------------------------------------
    for prop in root.findall(".//PropClass"):
        if prop.get("DeviceType") != "LOR":
            continue

        name = (prop.get("Name") or "")
        ch_raw = (prop.get("ChannelGrid") or "").strip()

        # Single-grid only in this function
        if ";" in ch_raw:
            continue

        if "spare" in name.lower():
            grid = parse_single_grid(ch_raw)
            raw_id = prop.get("id") or ""
            prop_id_scoped = scoped_id(preview_id, raw_id)

            cursor.execute("""
                INSERT OR REPLACE INTO props (
                    PropID, Name, LORComment, DeviceType, BulbShape, DimmingCurveName, MaxChannels,
                    CustomBulbColor, IndividualChannels, LegacySequenceMethod, Opacity, MasterDimmable,
                    PreviewBulbSize, SeparateIds, StartLocation, StringType, TraditionalColors, TraditionalType,
                    EffectBulbSize, Tag, Parm1, Parm2, Parm3, Parm4, Parm5, Parm6, Parm7, Parm8, Lights,
                    Network, UID, StartChannel, EndChannel, Unknown, Color, PreviewId
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, (
                prop_id_scoped, name, prop.get("Comment", ""), "LOR", prop.get("BulbShape"), prop.get("DimmingCurveName"),
                prop.get("MaxChannels"), prop.get("CustomBulbColor"), prop.get("IndividualChannels"),
                prop.get("LegacySequenceMethod"), prop.get("Opacity"), prop.get("MasterDimmable"),
                prop.get("PreviewBulbSize"), prop.get("SeparateIds"), prop.get("StartLocation"),
                prop.get("StringType"), prop.get("TraditionalColors"), prop.get("TraditionalType"),
                prop.get("EffectBulbSize"), prop.get("Tag"), prop.get("Parm1"), prop.get("Parm2"),
                prop.get("Parm3"), prop.get("Parm4"), prop.get("Parm5"), prop.get("Parm6"), prop.get("Parm7"),
                prop.get("Parm8"),
                int(prop.get("Parm2")) if (prop.get("Parm2") and str(prop.get("Parm2")).isdigit()) else 0,
                (grid or {}).get("Network"), (grid or {}).get("UID"), (grid or {}).get("StartChannel"),
                (grid or {}).get("EndChannel"), (grid or {}).get("Unknown"), (grid or {}).get("Color"),
                preview_id
            ))
            if DEBUG:
                print(f"[DEBUG] (LOR single) SPARE -> props: scoped_id={prop_id_scoped} Name='{name}'")

    # -----------------------------------------------------------------------
    # PASS 0B: MANUAL SUBPROPS (MasterPropId set) -> subProps
    # Keep Name/LORComment exactly. Use child's grid, else copy master's grid.
    # -----------------------------------------------------------------------
    manual_child_ids = set()  # raw ids of manual subprops (to exclude from auto grouping)
    for prop in root.findall(".//PropClass"):
        if prop.get("DeviceType") != "LOR":
            continue

        ch_raw = (prop.get("ChannelGrid") or "").strip()
        if ";" in ch_raw:
            continue  # single-grid only here

        master_raw = (prop.get("MasterPropId") or "").strip()
        if not master_raw:
            continue

        child_raw = prop.get("id") or ""
        manual_child_ids.add(child_raw)

        sub_id    = scoped_id(preview_id, child_raw)    # child's own identity
        master_id = scoped_id(preview_id, master_raw)

        # Use child's grid if present; otherwise copy master's grid (reuse channels)
        grid = parse_single_grid(ch_raw)
        if grid is None:
            master_node = root.find(f".//PropClass[@id='{master_raw}']")
            grid = parse_single_grid(master_node.get("ChannelGrid") or "") if master_node is not None else None
        if grid is None:
            grid = {"Network": None, "UID": None, "StartChannel": None, "EndChannel": None, "Unknown": None, "Color": None}

        cursor.execute("""
            INSERT OR REPLACE INTO subProps (
                SubPropID, Name, LORComment, DeviceType, BulbShape, Network, UID, StartChannel,
                EndChannel, Unknown, Color, CustomBulbColor, DimmingCurveName, IndividualChannels,
                LegacySequenceMethod, MaxChannels, Opacity, MasterDimmable, PreviewBulbSize, RgbOrder,
                MasterPropId, SeparateIds, StartLocation, StringType, TraditionalColors, TraditionalType,
                EffectBulbSize, Tag, Parm1, Parm2, Parm3, Parm4, Parm5, Parm6, Parm7, Parm8, Lights, PreviewId
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, (
            sub_id, prop.get("Name", ""), prop.get("Comment", ""), "LOR", prop.get("BulbShape", ""),
            grid["Network"], grid["UID"], grid["StartChannel"], grid["EndChannel"], grid["Unknown"], grid["Color"],
            prop.get("CustomBulbColor", ""), prop.get("DimmingCurveName", ""), prop.get("IndividualChannels", False),
            prop.get("LegacySequenceMethod", ""), prop.get("MaxChannels"), prop.get("Opacity"),
            prop.get("MasterDimmable", False), prop.get("PreviewBulbSize"), None,   # RgbOrder = NULL
            master_id, prop.get("SeparateIds", False), prop.get("StartLocation", ""), prop.get("StringType", ""),
            prop.get("TraditionalColors", ""), prop.get("TraditionalType", ""), prop.get("EffectBulbSize"),
            prop.get("Tag", ""), prop.get("Parm1", ""), prop.get("Parm2", ""), prop.get("Parm3", ""), prop.get("Parm4", ""),
            prop.get("Parm5", ""), prop.get("Parm6", ""), prop.get("Parm7", ""), prop.get("Parm8", ""),
            int(prop.get("Parm2")) if (prop.get("Parm2") and str(prop.get("Parm2")).isdigit()) else 0,
            preview_id
        ))
        if DEBUG:
            print(f"[DEBUG] (LOR single) MANUAL -> subProps: child={child_raw} sub_id={sub_id} master={master_id} UID={grid['UID']} Start={grid['StartChannel']}")

    # -----------------------------------------------------------------------
    # PASS 1: AUTO GROUP by LORComment (exclude SPARE and MANUAL)
    # -----------------------------------------------------------------------
    props_grouped_by_comment = {}

    for prop in root.findall(".//PropClass"):
        if prop.get("DeviceType") != "LOR":
            continue

        # Skip already-handled cases
        name = (prop.get("Name") or "")
        if "spare" in name.lower():
            continue
        if (prop.get("MasterPropId") or "").strip():  # manual subprop handled above
            continue

        ch_raw = (prop.get("ChannelGrid") or "").strip()
        if ";" in ch_raw:
            continue  # single-grid only in this function

        grid = parse_single_grid(ch_raw)
        raw_id = prop.get("id") or ""

        rec = {
            "PropID_raw":         raw_id,
            "PropID_scoped":      scoped_id(preview_id, raw_id),
            "Name":               name,                          # Channel Name (unchanged)
            "DeviceType":         "LOR",
            "LORComment":         prop.get("Comment", "") or "", # Display Name (unchanged)
            "BulbShape":          prop.get("BulbShape", ""),
            "DimmingCurveName":   prop.get("DimmingCurveName", ""),
            "MaxChannels":        prop.get("MaxChannels"),
            "CustomBulbColor":    prop.get("CustomBulbColor", ""),
            "IndividualChannels": prop.get("IndividualChannels", False),
            "LegacySequenceMethod":prop.get("LegacySequenceMethod", ""),
            "Opacity":            prop.get("Opacity"),
            "MasterDimmable":     prop.get("MasterDimmable", False),
            "PreviewBulbSize":    prop.get("PreviewBulbSize"),
            "SeparateIds":        prop.get("SeparateIds", False),
            "StartLocation":      prop.get("StartLocation", ""),
            "StringType":         prop.get("StringType", ""),
            "TraditionalColors":  prop.get("TraditionalColors", ""),
            "TraditionalType":    prop.get("TraditionalType", ""),
            "EffectBulbSize":     prop.get("EffectBulbSize"),
            "Tag":                prop.get("Tag", ""),
            "Parm1":              prop.get("Parm1", ""),
            "Parm2":              prop.get("Parm2", ""),
            "Parm3":              prop.get("Parm3", ""),
            "Parm4":              prop.get("Parm4", ""),
            "Parm5":              prop.get("Parm5", ""),
            "Parm6":              prop.get("Parm6", ""),
            "Parm7":              prop.get("Parm7", ""),
            "Parm8":              prop.get("Parm8", ""),
            "Lights":             int(prop.get("Parm2")) if (prop.get("Parm2") and str(prop.get("Parm2")).isdigit()) else 0,
            "Grid":               grid,
            "StartChannel":       (grid or {}).get("StartChannel"),
            "PreviewId":          preview_id,
        }

        key = rec["LORComment"]
        props_grouped_by_comment.setdefault(key, []).append(rec)

    # Process each comment group
    for LORComment, group in props_grouped_by_comment.items():
        if not group:
            continue

        # Master = lowest StartChannel (None => +inf)
        master = min(group, key=lambda r: r["StartChannel"] if r["StartChannel"] is not None else float("inf"))
        m_grid = master["Grid"] or {"Network": None, "UID": None, "StartChannel": None, "EndChannel": None, "Unknown": None, "Color": None}
        master_id = master["PropID_scoped"]

        # MASTER -> props (names/comments unchanged)
        cursor.execute("""
            INSERT OR REPLACE INTO props (
                PropID, Name, LORComment, DeviceType, BulbShape, DimmingCurveName, MaxChannels,
                CustomBulbColor, IndividualChannels, LegacySequenceMethod, Opacity, MasterDimmable,
                PreviewBulbSize, SeparateIds, StartLocation, StringType, TraditionalColors, TraditionalType,
                EffectBulbSize, Tag, Parm1, Parm2, Parm3, Parm4, Parm5, Parm6, Parm7, Parm8, Lights,
                Network, UID, StartChannel, EndChannel, Unknown, Color, PreviewId
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, (
            master_id, master["Name"], LORComment, master["DeviceType"], master["BulbShape"],
            master["DimmingCurveName"], master["MaxChannels"], master["CustomBulbColor"],
            master["IndividualChannels"], master["LegacySequenceMethod"], master["Opacity"],
            master["MasterDimmable"], master["PreviewBulbSize"], master["SeparateIds"],
            master["StartLocation"], master["StringType"], master["TraditionalColors"],
            master["TraditionalType"], master["EffectBulbSize"], master["Tag"], master["Parm1"],
            master["Parm2"], master["Parm3"], master["Parm4"], master["Parm5"], master["Parm6"],
            master["Parm7"], master["Parm8"], master["Lights"],
            m_grid["Network"], m_grid["UID"], m_grid["StartChannel"], m_grid["EndChannel"], m_grid["Unknown"], m_grid["Color"],
            master["PreviewId"]
        ))
        if DEBUG:
            print(f"[DEBUG] (LOR single) MASTER -> props: scoped_id={master_id} LORComment='{LORComment}' Start={m_grid['StartChannel']}")

        # REMAINING -> subProps (auto materialization; names/comments unchanged)
        for rec in group:
            if rec["PropID_scoped"] == master_id:
                continue

            g = rec["Grid"] or {"Network": None, "UID": None, "StartChannel": None, "EndChannel": None, "Unknown": None, "Color": None}
            uid   = g["UID"] or "NA"
            start = g["StartChannel"] if g["StartChannel"] is not None else 0

            # Deterministic key under master: "<master_id>-<UID>-<Start:02d>"
            sub_id = f"{master_id}-{uid}-{start:02d}"

            cursor.execute("""
                INSERT OR REPLACE INTO subProps (
                    SubPropID, Name, LORComment, DeviceType, BulbShape, Network, UID, StartChannel,
                    EndChannel, Unknown, Color, CustomBulbColor, DimmingCurveName, IndividualChannels,
                    LegacySequenceMethod, MaxChannels, Opacity, MasterDimmable, PreviewBulbSize, RgbOrder,
                    MasterPropId, SeparateIds, StartLocation, StringType, TraditionalColors, TraditionalType,
                    EffectBulbSize, Tag, Parm1, Parm2, Parm3, Parm4, Parm5, Parm6, Parm7, Parm8, Lights, PreviewId
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, (
                sub_id, rec["Name"], rec["LORComment"], rec["DeviceType"], rec["BulbShape"],
                g["Network"], g["UID"], g["StartChannel"], g["EndChannel"], g["Unknown"], g["Color"],
                rec["CustomBulbColor"], rec["DimmingCurveName"], rec["IndividualChannels"], rec["LegacySequenceMethod"],
                rec["MaxChannels"], rec["Opacity"], rec["MasterDimmable"], rec["PreviewBulbSize"], None,  # RgbOrder=NULL
                master_id, rec["SeparateIds"], rec["StartLocation"], rec["StringType"], rec["TraditionalColors"],
                rec["TraditionalType"], rec["EffectBulbSize"], rec["Tag"], rec["Parm1"], rec["Parm2"], rec["Parm3"],
                rec["Parm4"], rec["Parm5"], rec["Parm6"], rec["Parm7"], rec["Parm8"], rec["Lights"], rec["PreviewId"]
            ))
            if DEBUG:
                print(f"[DEBUG] (LOR single) AUTO -> subProps: parent={master_id} sub_id={sub_id} UID={uid} Start={start}")

    conn.commit()
    conn.close()





def process_lor_multiple_channel_grids(preview_id, root):
    """
    Process props with DeviceType == LOR and multiple ChannelGrid groups.

    WHAT THIS HANDLER DOES
    ----------------------
    • Targets ONLY multi-grid LOR props (ChannelGrid contains ';'). We intentionally
      include BOTH "true masters" (MasterPropId == '') and "reuse-only" children.
    • Groups all such props by LORComment and FLATTENS all of their grid entries.
    • Picks the MASTER GRID for the group as the entry with the LOWEST StartChannel.
    • Inserts a master row into props with full Network/UID/Start/End/Unknown/Color.
    • Inserts every REMAINING grid entry for the group into subProps with a unique id:
        SubPropID = "{<scoped master id>}-{UID}-{Start:02d}"
      and links them via MasterPropId = <scoped master id>.

    IMPORTANT: ID SCOPING
    ---------------------
    Visualizer reuses PropClass.id across different previews. To prevent cross-preview
    overwrites, we scope every id we store using the current preview id:
        scoped_id = f"{preview_id}:{raw_id}"
    We must use the SAME scoped value consistently for:
      - props.PropID
      - subProps.MasterPropId
      - subProps.SubPropID  (plus UID + Start to make it unique within the master)

    NAMING (unchanged from your convention)
    ---------------------------------------
    SubProp Name = "<first-token-of-LORComment> <Color?> <UID>-<Start:02d>"

    SCHEMA NOTES
    ------------
    • props insert includes Network/UID/StartChannel/EndChannel/Unknown/Color (no RgbOrder).
    • subProps insert includes RgbOrder (set to NULL); safe even if column exists.
    """
    conn = sqlite3.connect(DB_FILE)
    cursor = conn.cursor()

    def parse_grid(seg):
        """
        Parse a single grid segment "Net,UID,Start,End,Unknown,Color?" → dict.
        Handles both A/C (with Color) and RGB (Color may be empty).
        """
        parts = [p.strip() for p in (seg or "").split(",")]
        return {
            "Network":      parts[0] if len(parts) > 0 else None,
            "UID":          parts[1] if len(parts) > 1 else None,
            "StartChannel": safe_int(parts[2] if len(parts) > 2 else None),
            "EndChannel":   safe_int(parts[3] if len(parts) > 3 else None),
            "Unknown":      parts[4] if len(parts) > 4 else None,
            "Color":        parts[5] if len(parts) > 5 else None,
        }

    def uid_sort_key(uid):
        """
        Deterministic ordering for UIDs that may be hex ('5F') or decimal.
        We sort by StartChannel first (elsewhere), then use this as tiebreaker.
        """
        if uid is None:
            return (2, 0)
        u = uid.strip()
        try:
            return (0, int(u, 16))  # hex wins if parseable
        except Exception:
            try:
                return (1, int(u))   # then decimal
            except Exception:
                return (2, u)        # then raw string

    def first_token(s):
        s = (s or "").strip()
        return s.split(" ")[0] if s else ""

    # --------------------- collect multi-grid by comment ---------------------
    # We collect *all* LOR PropClass nodes whose ChannelGrid contains ';'
    # (masters and reused children) and flatten every grid entry into a group.
    groups = {}  # LORComment -> list of flat entries
    for prop in root.findall(".//PropClass"):
        if prop.get("DeviceType") != "LOR":
            continue
        ch_raw = (prop.get("ChannelGrid") or "").strip()
        if ";" not in ch_raw:
            continue  # single-grid handled by process_lor_props

        comment = prop.get("Comment") or ""
        raw_id  = prop.get("id") or ""
        # flatten each grid segment
        for seg in (s.strip() for s in ch_raw.split(";") if s.strip()):
            g = parse_grid(seg)
            entry = {
                "prop":         prop,
                "raw_id":       raw_id,
                "Name":         prop.get("Name"),
                "LORComment":   comment,
                "BulbShape":    prop.get("BulbShape"),
                "DimmingCurveName": prop.get("DimmingCurveName"),
                "MaxChannels":  prop.get("MaxChannels"),
                "CustomBulbColor": prop.get("CustomBulbColor"),
                "IndividualChannels": prop.get("IndividualChannels"),
                "LegacySequenceMethod": prop.get("LegacySequenceMethod"),
                "Opacity":      prop.get("Opacity"),
                "MasterDimmable": prop.get("MasterDimmable"),
                "PreviewBulbSize": prop.get("PreviewBulbSize"),
                "MasterPropId_attr": prop.get("MasterPropId"),  # original attribute for reference
                "SeparateIds":  prop.get("SeparateIds"),
                "StartLocation": prop.get("StartLocation"),
                "StringType":   prop.get("StringType"),
                "TraditionalColors": prop.get("TraditionalColors"),
                "TraditionalType":   prop.get("TraditionalType"),
                "EffectBulbSize": prop.get("EffectBulbSize"),
                "Tag":          prop.get("Tag"),
                "Parm1":        prop.get("Parm1"),
                "Parm2":        prop.get("Parm2"),
                "Parm3":        prop.get("Parm3"),
                "Parm4":        prop.get("Parm4"),
                "Parm5":        prop.get("Parm5"),
                "Parm6":        prop.get("Parm6"),
                "Parm7":        prop.get("Parm7"),
                "Parm8":        prop.get("Parm8"),
                "Lights":       int(prop.get("Parm2")) if (prop.get("Parm2") and str(prop.get("Parm2")).isdigit()) else 0,
                "Grid":         g,  # parsed grid dict
            }
            groups.setdefault(comment, []).append(entry)

    # ---------------------- process each multi-grid group --------------------
    for comment, items in groups.items():
        if len(items) < 2:
            continue  # true multi-grid groups only

        # Choose master GRID by lowest StartChannel; tiebreaker: UID sorting
        items_sorted = sorted(
            items,
            key=lambda d: ((d["Grid"]["StartChannel"] if d["Grid"]["StartChannel"] is not None else 1_000_000),
                           uid_sort_key(d["Grid"]["UID"]))
        )
        master = items_sorted[0]

        # Compose scoped master id from the PropClass that *owns* the master grid
        master_raw_id = master["raw_id"]
        master_id     = scoped_id(preview_id, master_raw_id)

        # Fields for master props row
        m_grid = master["Grid"]
        props_row = (
            master_id, master["Name"], comment, "LOR", master["BulbShape"], master["DimmingCurveName"],
            master["MaxChannels"], master["CustomBulbColor"], master["IndividualChannels"],
            master["LegacySequenceMethod"], master["Opacity"], master["MasterDimmable"], master["PreviewBulbSize"],
            master["SeparateIds"], master["StartLocation"], master["StringType"], master["TraditionalColors"],
            master["TraditionalType"], master["EffectBulbSize"], master["Tag"], master["Parm1"], master["Parm2"],
            master["Parm3"], master["Parm4"], master["Parm5"], master["Parm6"], master["Parm7"], master["Parm8"],
            master["Lights"],  # Lights
            m_grid["Network"], m_grid["UID"], m_grid["StartChannel"], m_grid["EndChannel"], m_grid["Unknown"], m_grid["Color"],
            preview_id
        )

        # Insert master into props (WITH full network/channel fields)
        cursor.execute("""
            INSERT OR REPLACE INTO props (
                PropID, Name, LORComment, DeviceType, BulbShape, DimmingCurveName, MaxChannels,
                CustomBulbColor, IndividualChannels, LegacySequenceMethod, Opacity, MasterDimmable,
                PreviewBulbSize, SeparateIds, StartLocation, StringType, TraditionalColors, TraditionalType,
                EffectBulbSize, Tag, Parm1, Parm2, Parm3, Parm4, Parm5, Parm6, Parm7, Parm8, Lights,
                Network, UID, StartChannel, EndChannel, Unknown, Color, PreviewId
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, props_row)

        if DEBUG:
            print(f"[DEBUG] (LOR multi) MASTER → props  id={master_id}  comment={comment}  start={m_grid['StartChannel']} uid={m_grid['UID']}")

        # Insert remaining grids into subProps
        lor_first = first_token(comment)
        for d in items_sorted[1:]:
            g = d["Grid"]
            uid   = g["UID"]
            start = g["StartChannel"] if g["StartChannel"] is not None else 0
            sub_id = f"{master_id}-{uid}-{start:02d}"   # unique under this master/preview

            # Subprop name pattern: "<first-token-of-LORComment> <Color?> <UID>-<Start:02d>"
            name_parts = [lor_first]
            if g["Color"]:
                name_parts.append(g["Color"])
            if uid is not None:
                name_parts.append(f"{uid}-{start:02d}")
            sub_name = " ".join(name_parts).strip()

            cursor.execute("""
                INSERT OR REPLACE INTO subProps (
                    SubPropID, Name, LORComment, DeviceType, BulbShape, Network, UID, StartChannel,
                    EndChannel, Unknown, Color, CustomBulbColor, DimmingCurveName, IndividualChannels,
                    LegacySequenceMethod, MaxChannels, Opacity, MasterDimmable, PreviewBulbSize, RgbOrder,
                    MasterPropId, SeparateIds, StartLocation, StringType, TraditionalColors, TraditionalType,
                    EffectBulbSize, Tag, Parm1, Parm2, Parm3, Parm4, Parm5, Parm6, Parm7, Parm8, Lights, PreviewId
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, (
                sub_id, sub_name, comment, "LOR", d["BulbShape"],
                g["Network"], uid, g["StartChannel"], g["EndChannel"], g["Unknown"], g["Color"],
                d["CustomBulbColor"], d["DimmingCurveName"], d["IndividualChannels"], d["LegacySequenceMethod"],
                d["MaxChannels"], d["Opacity"], d["MasterDimmable"], d["PreviewBulbSize"], None,  # RgbOrder=NULL
                master_id, d["SeparateIds"], d["StartLocation"], d["StringType"], d["TraditionalColors"],
                d["TraditionalType"], d["EffectBulbSize"], d["Tag"], d["Parm1"], d["Parm2"], d["Parm3"],
                d["Parm4"], d["Parm5"], d["Parm6"], d["Parm7"], d["Parm8"], d["Lights"], preview_id
            ))
            if DEBUG:
                print(f"[DEBUG] (LOR multi) SUB  → subProps id={sub_id}  parent={master_id}  start={g['StartChannel']} uid={uid}")

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
    global DB_FILE, PREVIEW_PATH  # keep other functions happy

    DB_FILE = get_path("Enter database path", DEFAULT_DB_FILE)
    PREVIEW_PATH = get_path("Enter the folder path containing .lorprev files", DEFAULT_PREVIEW_PATH)

    print(f"[INFO] Using database: {DB_FILE}")
    print(f"[INFO] Using preview folder: {PREVIEW_PATH}")

    if not os.path.isdir(PREVIEW_PATH):
        print(f"[ERROR] '{PREVIEW_PATH}' is not a valid directory.")
        return

    # Set up the database
    setup_database()

    # Process all files in the folder
    process_folder(PREVIEW_PATH)

    # ✅ Build the wiring views in the SAME DB file the parser just wrote
    create_wiring_views_v6(DB_FILE)

    print("Processing complete. Check the database.")

# === Wiring views for V6 (map + sorted) GAL 25-08-23 ===
def create_wiring_views_v6(db_file: str):
    import sqlite3
    ddl = r"""
    DROP VIEW IF EXISTS preview_wiring_map_v6;
    DROP VIEW IF EXISTS preview_wiring_sorted_v6;

    -- LOR masters (props)
    CREATE VIEW preview_wiring_map_v6 AS
    SELECT
    pv.Name AS PreviewName,
    p.Name AS Channel_Name,              -- RAW channel name
    p.LORComment AS Display_Name,        -- RAW display name (inventory key)
    REPLACE(TRIM(
        COALESCE(NULLIF(p.LORComment,''), p.Name)
        || CASE
            WHEN UPPER(p.LORComment) LIKE '% DS%' OR UPPER(p.Tag) LIKE '% DS%' THEN '-DS'
            WHEN UPPER(p.LORComment) LIKE '% PS%' OR UPPER(p.Tag) LIKE '% PS%' THEN '-PS'
            WHEN UPPER(p.LORComment) LIKE '% LH%' OR UPPER(p.Tag) LIKE '% LH%' THEN '-LH'
            WHEN UPPER(p.LORComment) LIKE '% RH%' OR UPPER(p.Tag) LIKE '% RH%' THEN '-RH'
            ELSE ''
        END
        || CASE
            WHEN INSTR(p.Tag,'Group ')>0
                AND SUBSTR(p.Tag, INSTR(p.Tag,'Group ')+6, 1) BETWEEN 'A' AND 'Z'
            THEN '-'||SUBSTR(p.Tag, INSTR(p.Tag,'Group ')+6, 1)
            ELSE ''
        END
        || CASE WHEN p.UID IS NOT NULL AND p.StartChannel IS NOT NULL
                THEN '-'||p.UID||'-'||printf('%02d', p.StartChannel)
                ELSE '' END
    ), ' ','-') AS Suggested_Name,
    p.Network AS Network,
    p.UID     AS Controller,
    p.StartChannel, p.EndChannel,
    p.DeviceType, 'PROP' AS Source, p.Tag AS LORTag
    FROM props p
    JOIN previews pv ON pv.id = p.PreviewId
    WHERE p.DeviceType='LOR' AND p.Network IS NOT NULL AND p.StartChannel IS NOT NULL

    UNION ALL

    -- LOR subprops
    SELECT
    pv.Name,
    sp.Name       AS Channel_Name,      -- RAW subprop channel name
    sp.LORComment AS Display_Name,      -- RAW subprop display name
    REPLACE(TRIM(
        COALESCE(NULLIF(sp.LORComment,''), p.LORComment)
        || CASE
            WHEN UPPER(COALESCE(sp.LORComment,p.LORComment)) LIKE '% DS%' OR UPPER(sp.Tag) LIKE '% DS%' THEN '-DS'
            WHEN UPPER(COALESCE(sp.LORComment,p.LORComment)) LIKE '% PS%' OR UPPER(sp.Tag) LIKE '% PS%' THEN '-PS'
            WHEN UPPER(COALESCE(sp.LORComment,p.LORComment)) LIKE '% LH%' OR UPPER(sp.Tag) LIKE '% LH%' THEN '-LH'
            WHEN UPPER(COALESCE(sp.LORComment,p.LORComment)) LIKE '% RH%' OR UPPER(sp.Tag) LIKE '% RH%' THEN '-RH'
            ELSE ''
            END
        || CASE
            WHEN INSTR(sp.Tag,'Group ')>0
                    AND SUBSTR(sp.Tag, INSTR(sp.Tag,'Group ')+6, 1) BETWEEN 'A' AND 'Z'
                THEN '-'||SUBSTR(sp.Tag, INSTR(sp.Tag,'Group ')+6, 1)
            ELSE ''
            END
        || CASE WHEN sp.UID IS NOT NULL AND sp.StartChannel IS NOT NULL
                THEN '-'||sp.UID||'-'||printf('%02d', sp.StartChannel)
                ELSE '' END
    ), ' ','-') AS Suggested_Name,
    sp.Network, sp.UID AS Controller, sp.StartChannel, sp.EndChannel,
    COALESCE(sp.DeviceType,'LOR') AS DeviceType, 'SUBPROP' AS Source, sp.Tag AS LORTag
    FROM subProps sp
    JOIN props p   ON p.PropID = sp.MasterPropId AND p.PreviewId = sp.PreviewId
    JOIN previews pv ON pv.id = sp.PreviewId


    UNION ALL

    -- DMX channels (Controller = Universe)
    SELECT
    pv.Name,
    p.Name AS Channel_Name,
    p.LORComment AS Display_Name,
    REPLACE(TRIM(
        COALESCE(NULLIF(p.LORComment,''), p.Name)
        || CASE
            WHEN UPPER(p.LORComment) LIKE '% DS%' OR UPPER(p.Tag) LIKE '% DS%' THEN '-DS'
            WHEN UPPER(p.LORComment) LIKE '% PS%' OR UPPER(p.Tag) LIKE '% PS%' THEN '-PS'
            WHEN UPPER(p.LORComment) LIKE '% LH%' OR UPPER(p.Tag) LIKE '% LH%' THEN '-LH'
            WHEN UPPER(p.LORComment) LIKE '% RH%' OR UPPER(p.Tag) LIKE '% RH%' THEN '-RH'
            ELSE ''
        END
        || '-U'||dc.StartUniverse||':'||dc.StartChannel
    ), ' ','-') AS Suggested_Name,
    dc.Network, CAST(dc.StartUniverse AS TEXT) AS Controller,
    dc.StartChannel, dc.EndChannel,
    'DMX' AS DeviceType, 'DMX' AS Source, p.Tag AS LORTag
    FROM dmxChannels dc
    JOIN props p   ON p.PropID = dc.PropId AND p.PreviewId = dc.PreviewId
    JOIN previews pv ON pv.id = p.PreviewId;

    -- Sorted convenience view
    CREATE VIEW preview_wiring_sorted_v6 AS
    SELECT
    PreviewName, Channel_Name, Display_Name, Suggested_Name,
    Network, Controller, StartChannel, EndChannel, DeviceType, Source, LORTag
    FROM preview_wiring_map_v6
    ORDER BY PreviewName COLLATE NOCASE, Display_Name COLLATE NOCASE, Controller, StartChannel;

    -- helpful indexes
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