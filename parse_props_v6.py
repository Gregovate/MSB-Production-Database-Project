# MSB Database — LOR Preview Parser (v6)
# Initial Release: 2022-01-20 V0.1.0
# Author: Greg Liebig, Engineering Innovations, LLC.
#
# Purpose
# -------
# Parse Light-O-Rama (.lorprev) previews and materialize a normalized SQLite DB:
#   • previews
#   • props
#   • subProps
#   • dmxChannels
#   • wiring views (preview_wiring_map_v6 / preview_wiring_sorted_v6)
#
# Naming Convention
# -----------------
# Display names follow a consistent pattern:
#     <Name>[-<Location>][-<Seq><Color?>]
#
# • Name: CamelCase (capitalize each word, no spaces).
#         Stage/section or pattern may be embedded (e.g., DF_A, ElfP2, NoteB).
# • Location (optional): DS, PS, LH, RH, Center, Front, Rear, A/B/C… (sections).
# • Seq (optional): instance number.
#       - Use 1..9 if guaranteed <10 total.
#       - Use zero-padded 01, 02, …, 10, 11… if 10+ possible.
# • Color (optional): single-letter suffix appended to Seq with no extra hyphen.
#       R=Red, G=Green, B=Blue, W=White, Y=Yellow (e.g., -01R).
#       If needed, full color names (e.g., -Red) may be used, but suffix is preferred.
#
# Device Types
# ------------
# • LOR   : Single- or multi-grid channel props.
#           - Master prop = lowest StartChannel among items with the same LORComment.
#           - Master goes to `props`.
#           - Other legs go to `subProps` (linked via MasterPropId).
#
# • DMX   : Channel grids are split into universes.
#           - Master metadata goes to `props`.
#           - Each universe leg goes to `dmxChannels`.
#
# • None  : Props with no electronic channels (physical-only, e.g., static cutouts).
#           - Saved in `props` with DeviceType="None".
#           - Lights count pulled from Parm2 (if present) and aggregated by LORComment.
#           - Present for labeling, inventory, storage.
#           - Excluded from wiring views (since no channels).
#
# Wiring Views
# ------------
# • preview_wiring_map_v6 and preview_wiring_sorted_v6 present a channel map for wiring.
# • Only channel-based items appear (LOR, DMX).
# • DeviceType=None props are omitted (no wiring), but remain in `props`.
# • DisplayName is derived by dashifying LORComment (spaces → '-').
#
# IMPORTANT: ID SCOPING 
# -----------------------------------
# LOR Visualizer can reuse PropClass.id across different previews. If you need
# globally unique keys, scope every raw xml id by preview:
#
#     def scoped_id(preview_id: str, raw_id: str) -> str:
#         return f"{preview_id}:{raw_id}"
#
# Use the scoped value consistently for:
#   - props.PropID
#   - subProps.MasterPropId
#   - subProps.SubPropID (manual subprops can use their own scoped id; auto
#     subprops may derive "<master>-<Start:02d>" or similar, prefixed with master).
#
# NOTE: The current script uses xml ids as-is. If collisions across previews are
# observed, enable scoping and update inserts accordingly.


import os
import xml.etree.ElementTree as ET
import sqlite3
import pathlib
from collections import defaultdict
import uuid

# ---- Global flags & defaults (must be defined before functions) ----
DEBUG = False  # Global debug flag

DEFAULT_DB_FILE = r"G:\Shared drives\MSB Database\database\lor_output_v6.db"
DEFAULT_PREVIEW_PATH = r"G:\Shared drives\MSB Database\Database Previews"
#DEFAULT_PREVIEW_PATH = r"G:\Shared drives\MSB Database\Database Previews\2024MasterPreviews"

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
# --- Device Type = NONE  ---
def safe_int(x, default=0):
    try:
        return int(str(x).strip())
    except Exception:
        return default


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

# --- Pre-scan: which display names clearly belong to channel-bearing props?
def collect_channel_display_names(xml_root) -> set[str]:
    """
    Return lowercased LORComment values that should be owned by LOR/DMX paths.
    We flag a node as 'channel-bearing' if:
      - DeviceType is LOR or DMX, OR
      - it has a non-empty ChannelGrid, OR
      - it carries manual wiring hints (MasterPropId / 'same channel as' fields).
    """
    channelish = set()

    def _t(s):  # normalize strings (lowercase/trim)
        return (s or "").strip().lower()

    for node in xml_root.findall(".//PropClass"):
        dev = (node.get("DeviceType") or "").strip().upper()
        # lorcomment = _t(node.get("LORComment")) GAL 25-09-20
        lorcomment = _t(node.get("Comment"))

        if not lorcomment:
            continue  # we already ignore blank comments in your parser

        # Obvious channel devices
        if dev in ("LOR", "DMX"):
            channelish.add(lorcomment)
            continue

        # Any real-looking channel grid?
        grid = (node.get("ChannelGrid") or "").strip()
        if grid:
            channelish.add(lorcomment)
            continue

        # Manual wiring hints (treat as channelish so LOR/DMX logic can own it)
        if (node.get("MasterPropId") or "").strip():
            channelish.add(lorcomment)
            continue

        # “uses same channel as …” style pointers (map keys if yours differ)
        for k in ("SameAsProp", "SameAsPreview", "SameAsSubprop", "SameAsChannel", "UsesSameChannelAs"):
            if (node.get(k) or "").strip():
                channelish.add(lorcomment)
                break

    return channelish

# ---------- Notification when DB Updated 25-09-20 GAL -----------------------------
from pathlib import Path
from datetime import datetime

def _notice_text(preview_path: str | Path, db_file: str | Path) -> str:
    ts = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    return (
        "MSB Database rebuild complete\n"
        f"Timestamp : {ts}\n"
        f"Database  : {Path(db_file)}\n"
        f"Previews  : {Path(preview_path)}\n"
        "Artifacts :\n"
        "  - Wiring views created (v6)\n"
        "  - Preview manifest written\n"
    )

def write_notice_file(preview_path: str | Path, text: str) -> Path:
    outdir = Path(preview_path) / "_notifications"
    outdir.mkdir(parents=True, exist_ok=True)
    fname = f"db-rebuild-{datetime.now().strftime('%Y%m%d-%H%M%S')}.txt"
    outpath = outdir / fname
    outpath.write_text(text, encoding="utf-8")
    return outpath
# -----------------------------------------------------------------------------


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

def reconcile_subprops_to_canonical_master(db_file: str):
    """
    Snap all subProps.MasterPropId to the canonical PROP for each
    (PreviewId, Display_Name/LORComment) group.

    Choose ONE of the two SQL blocks below (A or B) and keep only that one.
    """
    import sqlite3
    conn = sqlite3.connect(db_file)
    try:
        sql = r"""
        -- === OPTION B (matches Python's (UID, StartChannel) ordering) ===
        WITH canon AS (
          SELECT p.PreviewId,
                 p.LORComment AS Display_Name,
                 COALESCE(p.UID,'ZZ') AS uid,
                 COALESCE(p.StartChannel,1000000000) AS sc,
                 p.PropID
          FROM props p
          WHERE p.DeviceType='LOR'
            AND TRIM(IFNULL(p.LORComment,'')) <> ''
            AND UPPER(p.LORComment) <> 'SPARE'
        ),
        min_uid AS (
          SELECT PreviewId, Display_Name, MIN(uid) AS min_uid
          FROM canon GROUP BY PreviewId, Display_Name
        ),
        min_pair AS (
          SELECT c.PreviewId, c.Display_Name, mu.min_uid,
                 MIN(c.sc) AS min_sc
          FROM canon c
          JOIN min_uid mu
            ON mu.PreviewId=c.PreviewId AND mu.Display_Name=c.Display_Name
           AND c.uid=mu.min_uid
          GROUP BY c.PreviewId, c.Display_Name
        ),
        canon_pick AS (
          SELECT c.PreviewId, c.Display_Name,
                 MIN(c.PropID) AS CanonPropID
          FROM canon c
          JOIN min_pair mp
            ON mp.PreviewId=c.PreviewId AND mp.Display_Name=c.Display_Name
           AND c.uid=mp.min_uid AND c.sc=mp.min_sc
          GROUP BY c.PreviewId, c.Display_Name
        )
        UPDATE subProps
        SET MasterPropId = (
          SELECT cp.CanonPropID
          FROM canon_pick cp
          WHERE cp.PreviewId    = subProps.PreviewId
            AND cp.Display_Name = subProps.LORComment
        )
        WHERE EXISTS (
          SELECT 1 FROM canon_pick cp
          WHERE cp.PreviewId    = subProps.PreviewId
            AND cp.Display_Name = subProps.LORComment
        )
        AND (
              MasterPropId IS NULL
           OR NOT EXISTS (SELECT 1 FROM props p WHERE p.PropID = subProps.MasterPropId)
           OR MasterPropId <> (SELECT cp.CanonPropID
                               FROM canon_pick cp
                               WHERE cp.PreviewId=subProps.PreviewId
                                 AND cp.Display_Name=subProps.LORComment)
        );
        """
        # If you truly want StartChannel-first then UID (your original), replace the sql above
        # with the "Option A" block you pasted.
        conn.executescript(sql)
        conn.commit()
        print("[INFO] Reconciled subProps → canonical masters.")
    finally:
        conn.close()

# ============================ Parsing Modules ===========================================
# def process_none_props(preview_id, root):
def process_none_props(preview_id, root, skip_display_names: set[str] | None = None):
    r"""
    RULES (DeviceType == "None")
    ----------------------------
    Purpose
      - Persist physical-only props that have **no channels** (inventory/BOM only).
      - Keep them in `props` so they do NOT appear in wiring views (no Network/UID/StartChannel).
      - Skip any record with a **blank Comment** (display name).  [25-08-30 GAL]

    Behavior (current, clarified 25-09-22)
      - **Fan-out instances**: materialize N instances per record using:
            N = MaxChannels if > 0
                else Parm2 if numeric and > 0
                else 1
        Each instance gets a stable suffix: `PropID-01, -02, …, -NN`.
      - **Use Same Channel As** (a/k/a Master link):
            * If blank/null  → just fan-out into `props` rows (no linkage).
            * If present     → still fan-out, and set `MasterPropId` on each `props` row
                               to the referenced PropID (linkage only; still no channels).
      - **No grouping/aggregation by LORComment**: we write per-instance rows (one row per
        physical unit) rather than a single aggregated row. This keeps counts/BOM accurate.
      - **No ChannelGrid parsing** here (these are channel-less by design).
      - **No `subProps` writes** from this function. These inventory-only items remain in `props`
        and wiring views naturally exclude them because they lack Network/StartChannel.
      - **Manual sub-prop assignments** are respected by the `MasterPropId` linkage; they do not
        create channels and do not leak into wiring.  [25-09-20 GAL]

    Inputs
      - preview_id: id of the <PreviewClass>.
      - root: ElementTree root of the preview XML.
      - skip_display_names: optional set of LORComment strings to ignore (case-sensitive).

    Outputs
      - Inserts N rows per qualifying record into `props`:
            PropID (with -NN), Name, LORComment, DeviceType="None",
            MaxChannels, Parm1..Parm8, Lights (from Parm2 if present),
            PreviewId, MasterPropId (if “Use Same Channel As” provided),
            plus descriptive fields (BulbShape, DimmingCurveName, Tag, etc.).

    Notes
      - Wiring views remain clean because these rows have no Network/UID/StartChannel.
      - “Blank Comment” items are skipped to avoid inventory churn.
      - If future audits need visibility in `subProps`, add a separate writer and
        harden the wiring view to exclude DeviceType='None' on the sub-prop leg.
    """

    conn = sqlite3.connect(DB_FILE)
    cursor = conn.cursor()

    for prop in root.findall(".//PropClass"):
        if (prop.get("DeviceType") or "").strip() != "None":
            continue

        comment = (prop.get("Comment") or "").strip()
        if not comment:
            # skip blanks; they cause churn in inventory
            continue

        raw_id    = prop.get("id") or ""
        base_name = prop.get("Name") or ""
        max_ch    = safe_int(prop.get("MaxChannels"), 0)
        parm2     = prop.get("Parm2")
        lights    = safe_int(parm2, 0)

        # Determine how many instances to materialize
        count = max(1, max_ch if max_ch > 0 else (lights if lights > 0 else 1))

        # "Use same channel as" can come through under different attribute names;
        # check both common variants.
        same_as = (
            (prop.get("UseSameChannelAs") or "").strip()
            or (prop.get("MasterPropId") or "").strip()
        )
        if same_as.lower() in ("", "none", "null"):
            same_as = ""

        # Copy over other descriptive fields you want to retain on NONE records
        dimming_curve_name = prop.get("DimmingCurveName")
        bulb_shape         = prop.get("BulbShape")
        traditional_type   = prop.get("TraditionalType")
        traditional_colors = prop.get("TraditionalColors")
        string_type        = prop.get("StringType")
        effect_bulb_size   = prop.get("EffectBulbSize")
        custom_bulb_color  = prop.get("CustomBulbColor")
        tag                = prop.get("Tag")
        opacity            = prop.get("Opacity")
        preview_bulb_size  = prop.get("PreviewBulbSize")
        separate_ids       = prop.get("SeparateIds")
        start_location     = prop.get("StartLocation")
        legacy_method      = prop.get("LegacySequenceMethod")
        individual_ch      = prop.get("IndividualChannels")

        # Materialize count instances: PropID-01, PropID-02, ...
        for i in range(1, count + 1):
            inst_id = f"{raw_id}-{i:02d}"

            # only suffix when we actually fan-out to multiple rows
            if count > 1:
                inst_comment = f"{comment}-{i:02d}"
            else:
                inst_comment = comment

            cursor.execute("""
                INSERT OR REPLACE INTO props (
                    PropID, Name, LORComment, DeviceType,
                    BulbShape, DimmingCurveName, MaxChannels,
                    CustomBulbColor, IndividualChannels, LegacySequenceMethod,
                    Opacity, MasterDimmable, PreviewBulbSize, SeparateIds, StartLocation,
                    StringType, TraditionalColors, TraditionalType, EffectBulbSize, Tag,
                    Parm1, Parm2, Parm3, Parm4, Parm5, Parm6, Parm7, Parm8,
                    Lights, PreviewId, MasterPropId
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?,
                        ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, (
                inst_id, base_name, inst_comment, "None",     # ← here
                bulb_shape, dimming_curve_name, max_ch,
                custom_bulb_color, individual_ch, legacy_method,
                opacity, prop.get("MasterDimmable"), preview_bulb_size, separate_ids, start_location,
                string_type, traditional_colors, traditional_type, effect_bulb_size, tag,
                prop.get("Parm1"), prop.get("Parm2"), prop.get("Parm3"), prop.get("Parm4"),
                prop.get("Parm5"), prop.get("Parm6"), prop.get("Parm7"), prop.get("Parm8"),
                lights, preview_id, same_as or None
            ))

            if DEBUG:
                mode = "EXPAND+LINK" if same_as else "EXPAND"
                print(f"[NONE->{mode}] {inst_id}  name='{base_name}'  comment='{inst_comment}'")


    conn.commit()
    conn.close()


def process_dmx_props(preview_id, root):
    """
    RULES
    -----
    Purpose
      - Persist DMX props and their universe/channel legs.
    
    DMX grouping rules:
      • Group by LORComment (display name).
      • Write exactly ONE master props row per group.
      • Attach ALL DMX ChannelGrid legs from every row in the group to that master (dmxChannels.PropId = master).
      • Choose master by the smallest (StartUniverse, StartChannel); tie-break by PropID for determinism.

    Behavior
      - For each PropClass with DeviceType == "DMX":
          * Write master metadata to `props` (PropID, Name, LORComment, etc.).
          * Parse ChannelGrid; for each "network,universe,start,end,unknown" leg:
              - Insert a row into `dmxChannels` with (PropId, Network, StartUniverse, StartChannel, EndChannel, Unknown).
      - Lights count:
          * If Parm2 is numeric, treat as approximate light count; store in `props.Lights`.

    Inputs
      - preview_id: string id of the <PreviewClass>.
      - root: XML root (ElementTree).

    Outputs
      - Inserts into `props` and `dmxChannels`.

    Notes
      - Wiring views join `dmxChannels` back to `props` to show universes as Controllers.
    """

    import sqlite3
    from collections import defaultdict

    def norm(s): return (s or "").strip()
    def safe_int(v, d=0):
        try: return int(v)
        except: return d

    conn = sqlite3.connect(DB_FILE)
    cur  = conn.cursor()

    # 1) Collect DMX rows and parse ChannelGrid
    groups = defaultdict(list)  # comment -> [row, ...]
    for prop in root.findall(".//PropClass"):
        if (prop.get("DeviceType") or "").strip().upper() != "DMX":
            continue

        comment = norm(prop.get("Comment"))
        if not comment:
            continue

        raw_id = prop.get("id") or ""
        scoped = scoped_id(preview_id, raw_id)  # keep consistent with the rest of the parser

        # Parse ChannelGrid into legs
        legs = []
        cg = norm(prop.get("ChannelGrid"))
        if cg:
            for seg in cg.split(";"):
                seg = seg.strip()
                if not seg:
                    continue
                parts = [p.strip() for p in seg.split(",")]
                if len(parts) >= 5:
                    legs.append({
                        "Network": parts[0],
                        "StartUniverse": safe_int(parts[1], 0),
                        "StartChannel":  safe_int(parts[2], 0),
                        "EndChannel":    safe_int(parts[3], 0),
                        "Unknown":       parts[4],
                    })

        # Decide sort key (lowest universe, then channel; default high if missing)
        min_uni = min([l["StartUniverse"] for l in legs], default=10**9)
        min_ch  = min([l["StartChannel"]  for l in legs], default=10**9)

        row = {
            "PropID": scoped,
            "RawID": raw_id,
            "Name": prop.get("Name"),
            "LORComment": comment,
            "DeviceType": "DMX",
            "BulbShape": prop.get("BulbShape"),
            "DimmingCurveName": prop.get("DimmingCurveName"),
            "MaxChannels": prop.get("MaxChannels"),
            "CustomBulbColor": prop.get("CustomBulbColor"),
            "IndividualChannels": prop.get("IndividualChannels"),
            "LegacySequenceMethod": prop.get("LegacySequenceMethod"),
            "Opacity": prop.get("Opacity"),
            "MasterDimmable": prop.get("MasterDimmable"),
            "PreviewBulbSize": prop.get("PreviewBulbSize"),
            "SeparateIds": prop.get("SeparateIds"),
            "StartLocation": prop.get("StartLocation"),
            "StringType": prop.get("StringType"),
            "TraditionalColors": prop.get("TraditionalColors"),
            "TraditionalType": prop.get("TraditionalType"),
            "EffectBulbSize": prop.get("EffectBulbSize"),
            "Tag": prop.get("Tag"),
            "Parm1": prop.get("Parm1"),
            "Parm2": prop.get("Parm2"),
            "Parm3": prop.get("Parm3"),
            "Parm4": prop.get("Parm4"),
            "Parm5": prop.get("Parm5"),
            "Parm6": prop.get("Parm6"),
            "Parm7": prop.get("Parm7"),
            "Parm8": prop.get("Parm8"),
            "Lights": int(prop.get("Parm2")) if prop.get("Parm2") and str(prop.get("Parm2")).isdigit() else 0,
            "Legs": legs,
            "SortKey": (min_uni, min_ch, scoped)  # stable tie-break
        }
        groups[comment].append(row)

    # 2) Emit one master `props` row per comment; attach all legs to that master in `dmxChannels`
    for comment, arr in groups.items():
        arr.sort(key=lambda r: r["SortKey"])
        master = arr[0]

        # Master props row (single row per comment)
        cur.execute("""
            INSERT OR REPLACE INTO props (
                PropID, Name, LORComment, DeviceType, BulbShape, DimmingCurveName,
                MaxChannels, CustomBulbColor, IndividualChannels, LegacySequenceMethod,
                Opacity, MasterDimmable, PreviewBulbSize, SeparateIds, StartLocation,
                StringType, TraditionalColors, TraditionalType, EffectBulbSize, Tag,
                Parm1, Parm2, Parm3, Parm4, Parm5, Parm6, Parm7, Parm8, Lights, PreviewId
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, (
            master["PropID"], master["Name"], master["LORComment"], "DMX",
            master["BulbShape"], master["DimmingCurveName"], master["MaxChannels"],
            master["CustomBulbColor"], master["IndividualChannels"], master["LegacySequenceMethod"],
            master["Opacity"], master["MasterDimmable"], master["PreviewBulbSize"], master["SeparateIds"],
            master["StartLocation"], master["StringType"], master["TraditionalColors"], master["TraditionalType"],
            master["EffectBulbSize"], master["Tag"], master["Parm1"], master["Parm2"], master["Parm3"],
            master["Parm4"], master["Parm5"], master["Parm6"], master["Parm7"], master["Parm8"],
            master["Lights"], preview_id
        ))
        if DEBUG:
            print(f"[DEBUG] (DMX) master → props: {master['PropID']}  Display='{comment}'")

        # All legs from every member of the group get attached to the master
        for r in arr:
            for leg in r["Legs"]:
                cur.execute("""
                    INSERT OR REPLACE INTO dmxChannels (
                        PropId, Network, StartUniverse, StartChannel, EndChannel, Unknown, PreviewId
                    ) VALUES (?, ?, ?, ?, ?, ?, ?)
                """, (
                    master["PropID"], leg["Network"], leg["StartUniverse"],
                    leg["StartChannel"], leg["EndChannel"], leg["Unknown"], preview_id
                ))
                if DEBUG:
                    print(f"[DEBUG] (DMX) +leg master={master['PropID']} U={leg['StartUniverse']} S={leg['StartChannel']} E={leg['EndChannel']}")
    conn.commit()
    conn.close()

def process_lor_props(preview_id, root):
    """
    RULES
    -----
    - Group by Display Name (LORComment).
    - There must be exactly one PROP (master).
    - The master is the lowest (ControllerUID, StartChannel) pair.
    - All other legs in that Display_Name group become subProps under that master.
    - ControllerUID is a 2-digit hex string, so plain text sort works (because everything is zero-padded hex).
    - If an XML row has MasterPropId but its Display_Name differs from its master's, that *new* Display_Name
      forms its own group: pick the *lowest StartChannel in that group* as the new master; all others -> subProps.
    - SPARE rows (single-grid) are copied to props as-is and excluded from grouping.

    Skip
      - Multi-grid props are handled in process_lor_multiple_channel_grids().

    Grouping
      - Group by LORComment (Display Name). Within each group:
          * Within each (PreviewId, Display_Name/LORComment) group:

    Ties break by the smallest ID (stable/deterministic).
          * Master is written to `props` and carries the first grid part (Network, UID, Start/End, Unknown, Color).
          * All remaining rows become `subProps`, each with its full grid data and MasterPropId pointing to the master.

    Preserve
      - Keep Name (channel name) and LORComment (display name) exactly as in XML.
      - Lights = int(Parm2) when numeric; else 0.

    Manual subprops
      - If the XML row already represents a subprop (MasterPropId set) it is written directly to `subProps`
        with its own grid (the current code does this implicitly by grouping; explicit manual subprop handling
        can be added if needed).

    Inputs
      - preview_id: string id of the <PreviewClass>.
      - root: XML root (ElementTree).

    Outputs
      - Inserts master row into `props`.
      - Inserts other legs into `subProps`.

    Views
      - Wiring views dashify LORComment (spaces -> '-') into DisplayName for stable sort.
    """

    import sqlite3, re
    conn = sqlite3.connect(DB_FILE)
    cursor = conn.cursor()

    # --- helpers -------------------------------------------------------------
    def parse_single_grid(channel_grid_text):
        if not channel_grid_text:
            return None
        parts = [p.strip() for p in channel_grid_text.split(",")]
        if len(parts) < 5:
            return None
        return {
            "Network":      parts[0],
            "UID":          parts[1] if len(parts) > 1 else None,
            "StartChannel": safe_int(parts[2]) if len(parts) > 2 else None,
            "EndChannel":   safe_int(parts[3]) if len(parts) > 3 else None,
            "Unknown":      parts[4] if len(parts) > 4 else None,
            "Color":        parts[5] if len(parts) > 5 else None,
        }

    # -----------------------------------------------------------------------
    # PASS 0: SPARE rows (single-grid) -> props as-is
    # -----------------------------------------------------------------------
    for prop in root.findall(".//PropClass"):
        if prop.get("DeviceType") != "LOR":
            continue
        name = (prop.get("Name") or "")
        ch_raw = (prop.get("ChannelGrid") or "").strip()
        if ";" in ch_raw:
            continue  # multi-grid handled elsewhere
        if "spare" in name.lower():
            grid = parse_single_grid(ch_raw) or {}
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
                prop_id_scoped, name, prop.get("Comment", ""), "LOR",
                prop.get("BulbShape"), prop.get("DimmingCurveName"), prop.get("MaxChannels"),
                prop.get("CustomBulbColor"), prop.get("IndividualChannels"), prop.get("LegacySequenceMethod"),
                prop.get("Opacity"), prop.get("MasterDimmable"), prop.get("PreviewBulbSize"),
                prop.get("SeparateIds"), prop.get("StartLocation"), prop.get("StringType"),
                prop.get("TraditionalColors"), prop.get("TraditionalType"), prop.get("EffectBulbSize"),
                prop.get("Tag"), prop.get("Parm1"), prop.get("Parm2"), prop.get("Parm3"), prop.get("Parm4"),
                prop.get("Parm5"), prop.get("Parm6"), prop.get("Parm7"), prop.get("Parm8"),
                int(prop.get("Parm2")) if (prop.get("Parm2") and str(prop.get("Parm2")).isdigit()) else 0,
                grid.get("Network"), grid.get("UID"), grid.get("StartChannel"), grid.get("EndChannel"),
                grid.get("Unknown"), grid.get("Color"), preview_id
            ))
            if DEBUG:
                print(f"[DEBUG] (LOR single) SPARE -> props: {prop_id_scoped} '{name}'")

    # -----------------------------------------------------------------------
    # PASS 0B: MANUAL SUBPROPS (MasterPropId set)
    # Materialize full groups when a manual has a *changed* Display_Name.
    # -----------------------------------------------------------------------
    xml_by_id = {p.get("id"): p for p in root.findall(".//PropClass")}

    def grid_or(node, fallback=None):
        g = parse_single_grid((node.get("ChannelGrid") or "").strip())
        return g if g else (fallback if fallback else {"Network":None,"UID":None,"StartChannel":None,"EndChannel":None,"Unknown":None,"Color":None})

    manuals_same = []              # [(sp_node, master_node)]
    changed_by_comment = {}        # { new_display_name: [manual_sp_nodes...] }

    for sp in root.findall(".//PropClass"):
        if sp.get("DeviceType") != "LOR":
            continue
        ch_raw = (sp.get("ChannelGrid") or "").strip()
        if ";" in ch_raw:
            continue  # single-grid only here
        m_raw = (sp.get("MasterPropId") or "").strip()
        if not m_raw:
            continue
        master = xml_by_id.get(m_raw)
        sub_comment    = (sp.get("Comment") or "").strip()
        master_comment = (master.get("Comment") or "").strip() if master is not None else ""
        if sub_comment == master_comment:
            manuals_same.append((sp, master))
        else:
            changed_by_comment.setdefault(sub_comment, []).append(sp)

    # Keep manuals with same comment under original master
    for sp, master in manuals_same:
        sub_id_scoped    = scoped_id(preview_id, sp.get("id") or "")
        master_id_scoped = scoped_id(preview_id, master.get("id") or "") if master is not None else None
        g = grid_or(sp, grid_or(master))
        cursor.execute("""
            INSERT OR REPLACE INTO subProps (
                SubPropID, Name, LORComment, DeviceType, BulbShape, Network, UID, StartChannel,
                EndChannel, Unknown, Color, CustomBulbColor, DimmingCurveName, IndividualChannels,
                LegacySequenceMethod, MaxChannels, Opacity, MasterDimmable, PreviewBulbSize, RgbOrder,
                MasterPropId, SeparateIds, StartLocation, StringType, TraditionalColors, TraditionalType,
                EffectBulbSize, Tag, Parm1, Parm2, Parm3, Parm4, Parm5, Parm6, Parm7, Parm8, Lights, PreviewId
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, (
            sub_id_scoped, sp.get("Name",""), sp.get("Comment",""), "LOR", sp.get("BulbShape"),
            g["Network"], g["UID"], g["StartChannel"], g["EndChannel"], g["Unknown"], g["Color"],
            sp.get("CustomBulbColor"), sp.get("DimmingCurveName"), sp.get("IndividualChannels"),
            sp.get("LegacySequenceMethod"), sp.get("MaxChannels"), sp.get("Opacity"),
            sp.get("MasterDimmable"), sp.get("PreviewBulbSize"), None,
            master_id_scoped, sp.get("SeparateIds"), sp.get("StartLocation"), sp.get("StringType"),
            sp.get("TraditionalColors"), sp.get("TraditionalType"), sp.get("EffectBulbSize"), sp.get("Tag"),
            sp.get("Parm1"), sp.get("Parm2"), sp.get("Parm3"), sp.get("Parm4"), sp.get("Parm5"), sp.get("Parm6"),
            sp.get("Parm7"), sp.get("Parm8"),
            int(sp.get("Parm2")) if (sp.get("Parm2") and str(sp.get("Parm2")).isdigit()) else 0,
            preview_id
        ))

    # For manuals whose Display_Name changed: build FULL group (manual + non-manual) for that Display_Name
    materialized_comments = set()

    # Pre-index non-manual, single-grid, non-spare rows by Display_Name
    nonmanual_by_comment = {}
    for node in root.findall(".//PropClass"):
        if node.get("DeviceType") != "LOR":
            continue
        if ";" in (node.get("ChannelGrid") or ""):
            continue
        if (node.get("MasterPropId") or "").strip():
            continue
        if "spare" in (node.get("Name") or "").lower():
            continue
        key = (node.get("Comment") or "").strip()
        nonmanual_by_comment.setdefault(key, []).append(node)

    for new_comment, manual_nodes in changed_by_comment.items():
        # full group = manuals + any non-manuals with same Display_Name
        full_group = list(manual_nodes) + nonmanual_by_comment.get(new_comment, [])

        # pick master by (UID, StartChannel) — NODE version to match your helpers
        def _pair_key_node(node):
            g = parse_single_grid(node.get("ChannelGrid") or "")
            uid = ((g or {}).get("UID") or "").strip().upper()     # '0A','0B',...
            uid_key = uid if uid else "ZZ"                          # missing UID last
            sc = (g or {}).get("StartChannel")
            sc_key = int(sc) if sc is not None else 10**9           # missing channel last
            rid = node.get("id") or node.get("Name") or "~"         # deterministic tie-break
            return (uid_key, sc_key, rid)

        # def start_of(node):
        #     g = parse_single_grid(node.get("ChannelGrid") or "")
        #     sc = g.get("StartChannel") if g else None
        #     return sc if sc is not None else 10**9
        def start_of(node):
            g = parse_single_grid(node.get("ChannelGrid") or "")
            sc = g.get("StartChannel") if g else None
            return sc if sc is not None else 10**9


        # new_master = min(full_group, key=start_of)
        # g_master = grid_or(new_master)
        # new_master_id = scoped_id(preview_id, new_master.get("id") or "")
        new_master = min(full_group, key=start_of)   # lowest StartChannel in that group
        g_master = grid_or(new_master)
        new_master_id = scoped_id(preview_id, new_master.get("id") or "")



        # Insert new master
        cursor.execute("""
            INSERT OR REPLACE INTO props (
                PropID, Name, LORComment, DeviceType, BulbShape, DimmingCurveName, MaxChannels,
                CustomBulbColor, IndividualChannels, LegacySequenceMethod, Opacity, MasterDimmable,
                PreviewBulbSize, SeparateIds, StartLocation, StringType, TraditionalColors, TraditionalType,
                EffectBulbSize, Tag, Parm1, Parm2, Parm3, Parm4, Parm5, Parm6, Parm7, Parm8, Lights,
                Network, UID, StartChannel, EndChannel, Unknown, Color, PreviewId
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, (
            new_master_id, new_master.get("Name",""), new_comment, "LOR",
            new_master.get("BulbShape"), new_master.get("DimmingCurveName"), new_master.get("MaxChannels"),
            new_master.get("CustomBulbColor"), new_master.get("IndividualChannels"),
            new_master.get("LegacySequenceMethod"), new_master.get("Opacity"), new_master.get("MasterDimmable"),
            new_master.get("PreviewBulbSize"), new_master.get("SeparateIds"), new_master.get("StartLocation"),
            new_master.get("StringType"), new_master.get("TraditionalColors"), new_master.get("TraditionalType"),
            new_master.get("EffectBulbSize"), new_master.get("Tag"), new_master.get("Parm1"), new_master.get("Parm2"),
            new_master.get("Parm3"), new_master.get("Parm4"), new_master.get("Parm5"), new_master.get("Parm6"),
            new_master.get("Parm7"), new_master.get("Parm8"),
            int(new_master.get("Parm2")) if (new_master.get("Parm2") and str(new_master.get("Parm2")).isdigit()) else 0,
            g_master["Network"], g_master["UID"], g_master["StartChannel"], g_master["EndChannel"],
            g_master["Unknown"], g_master["Color"], preview_id
        ))

        # Everyone else in the group -> subProps under new master
        for node in full_group:
            if node is new_master: 
                continue
            g = grid_or(node)
            sub_id = scoped_id(preview_id, node.get("id") or "")
            cursor.execute("""
                INSERT OR REPLACE INTO subProps (
                    SubPropID, Name, LORComment, DeviceType, BulbShape, Network, UID, StartChannel,
                    EndChannel, Unknown, Color, CustomBulbColor, DimmingCurveName, IndividualChannels,
                    LegacySequenceMethod, MaxChannels, Opacity, MasterDimmable, PreviewBulbSize, RgbOrder,
                    MasterPropId, SeparateIds, StartLocation, StringType, TraditionalColors, TraditionalType,
                    EffectBulbSize, Tag, Parm1, Parm2, Parm3, Parm4, Parm5, Parm6, Parm7, Parm8, Lights, PreviewId
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, (
                sub_id, node.get("Name",""), new_comment, "LOR", node.get("BulbShape"),
                g["Network"], g["UID"], g["StartChannel"], g["EndChannel"], g["Unknown"], g["Color"],
                node.get("CustomBulbColor"), node.get("DimmingCurveName"), node.get("IndividualChannels"),
                node.get("LegacySequenceMethod"), node.get("MaxChannels"), node.get("Opacity"), node.get("MasterDimmable"),
                node.get("PreviewBulbSize"), None, new_master_id, node.get("SeparateIds"), node.get("StartLocation"),
                node.get("StringType"), node.get("TraditionalColors"), node.get("TraditionalType"), node.get("EffectBulbSize"),
                node.get("Tag"), node.get("Parm1"), node.get("Parm2"), node.get("Parm3"), node.get("Parm4"), node.get("Parm5"),
                node.get("Parm6"), node.get("Parm7"), node.get("Parm8"),
                int(node.get("Parm2")) if (node.get("Parm2") and str(node.get("Parm2")).isdigit()) else 0,
                preview_id
            ))
        materialized_comments.add(new_comment)

    # -----------------------------------------------------------------------
    # PASS 1: AUTO GROUP by LORComment (exclude SPARE, MANUALS, and any
    #         Display_Names already materialized in PASS 0B)
    # -----------------------------------------------------------------------
    props_grouped_by_comment = {}
    for prop in root.findall(".//PropClass"):
        if prop.get("DeviceType") != "LOR":
            continue
        name = (prop.get("Name") or "")
        if "spare" in name.lower():
            continue
        if (prop.get("MasterPropId") or "").strip():
            continue  # manuals handled in 0B
        lor_comment = (prop.get("Comment", "") or "").strip()
        if lor_comment in materialized_comments:
            continue  # already got a master in 0B
        ch_raw = (prop.get("ChannelGrid") or "").strip()
        if ";" in ch_raw:
            continue  # single-grid only

        grid = parse_single_grid(ch_raw)
        raw_id = prop.get("id") or ""
        rec = {
            "PropID_raw":    raw_id,
            "PropID_scoped": scoped_id(preview_id, raw_id),
            "Name":          name,
            "DeviceType":    "LOR",
            "LORComment":    lor_comment,
            "BulbShape":     prop.get("BulbShape", ""),
            "DimmingCurveName": prop.get("DimmingCurveName", ""),
            "MaxChannels":   prop.get("MaxChannels"),
            "CustomBulbColor": prop.get("CustomBulbColor", ""),
            "IndividualChannels": prop.get("IndividualChannels"),
            "LegacySequenceMethod": prop.get("LegacySequenceMethod", ""),
            "Opacity":       prop.get("Opacity"),
            "MasterDimmable": prop.get("MasterDimmable"),
            "PreviewBulbSize": prop.get("PreviewBulbSize"),
            "SeparateIds":   prop.get("SeparateIds"),
            "StartLocation": prop.get("StartLocation", ""),
            "StringType":    prop.get("StringType", ""),
            "TraditionalColors": prop.get("TraditionalColors", ""),
            "TraditionalType":   prop.get("TraditionalType", ""),
            "EffectBulbSize":    prop.get("EffectBulbSize"),
            "Tag":           prop.get("Tag",""),
            "Parm1":         prop.get("Parm1",""),
            "Parm2":         prop.get("Parm2",""),
            "Parm3":         prop.get("Parm3",""),
            "Parm4":         prop.get("Parm4",""),
            "Parm5":         prop.get("Parm5",""),
            "Parm6":         prop.get("Parm6",""),
            "Parm7":         prop.get("Parm7",""),
            "Parm8":         prop.get("Parm8",""),
            "Lights":        int(prop.get("Parm2")) if (prop.get("Parm2") and str(prop.get("Parm2")).isdigit()) else 0,
            "Grid":          grid or {},
            "StartChannel":  (grid or {}).get("StartChannel"),
            "PreviewId":     preview_id,
        }
        props_grouped_by_comment.setdefault(lor_comment, []).append(rec)

        # helper: choose by (UID, StartChannel), with Nones sorted last; deterministic tie-break on PropID GAL 25-08-27
        def _pair_key(rec):
            g = rec.get("Grid") or {}
            uid = (g.get("UID") or "").strip().upper()       # 2-digit hex like '0A', '0B'
            uid_key = uid if uid else "ZZ"                   # missing UID sorts last
            sc = rec.get("StartChannel")
            sc_key = sc if sc is not None else 10**9         # missing channel sorts last
            pid = rec.get("PropID_scoped") or "~"            # deterministic tie-break
            return (uid_key, sc_key, pid)


    # for display_name, group in props_grouped_by_comment.items():
    #     if not group:
    #         continue
    #     # master = min(group, key=lambda r: r["StartChannel"] if r["StartChannel"] is not None else float("inf"))
    #     master = min(group, key=_pair_key)
    #     m_grid = master["Grid"] or {"Network":None,"UID":None,"StartChannel":None,"EndChannel":None,"Unknown":None,"Color":None}
    #     master_id = master["PropID_scoped"]
    for display_name, group in props_grouped_by_comment.items():
        # master = min(... by StartChannel)
        master = min(group, key=_pair_key)           # ← uses (UID, StartChannel)
        m_grid = master["Grid"] or {...}
        master_id = master["PropID_scoped"]
            # MASTER -> props
        cursor.execute("""
            INSERT OR REPLACE INTO props (
                PropID, Name, LORComment, DeviceType, BulbShape, DimmingCurveName, MaxChannels,
                CustomBulbColor, IndividualChannels, LegacySequenceMethod, Opacity, MasterDimmable,
                PreviewBulbSize, SeparateIds, StartLocation, StringType, TraditionalColors, TraditionalType,
                EffectBulbSize, Tag, Parm1, Parm2, Parm3, Parm4, Parm5, Parm6, Parm7, Parm8, Lights,
                Network, UID, StartChannel, EndChannel, Unknown, Color, PreviewId
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, (
            master_id, master["Name"], display_name, master["DeviceType"], master["BulbShape"],
            master["DimmingCurveName"], master["MaxChannels"], master["CustomBulbColor"],
            master["IndividualChannels"], master["LegacySequenceMethod"], master["Opacity"],
            master["MasterDimmable"], master["PreviewBulbSize"], master["SeparateIds"],
            master["StartLocation"], master["StringType"], master["TraditionalColors"],
            master["TraditionalType"], master["EffectBulbSize"], master["Tag"], master["Parm1"],
            master["Parm2"], master["Parm3"], master["Parm4"], master["Parm5"], master["Parm6"],
            master["Parm7"], master["Parm8"], master["Lights"],
            m_grid["Network"], m_grid["UID"], m_grid["StartChannel"], m_grid["EndChannel"],
            m_grid["Unknown"], m_grid["Color"], master["PreviewId"]
        ))
        if DEBUG:
            print(f"[DEBUG] (LOR single) MASTER -> props: {master_id} '{display_name}' Start={m_grid['StartChannel']}")

        # REMAINING -> subProps
        for rec in group:
            if rec["PropID_scoped"] == master_id:
                continue
            g = rec["Grid"] or {"Network":None,"UID":None,"StartChannel":None,"EndChannel":None,"Unknown":None,"Color":None}
            sub_id = scoped_id(preview_id, rec["PropID_raw"])
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
                rec["MaxChannels"], rec["Opacity"], rec["MasterDimmable"], rec["PreviewBulbSize"], None,
                master_id, rec["SeparateIds"], rec["StartLocation"], rec["StringType"], rec["TraditionalColors"],
                rec["TraditionalType"], rec["EffectBulbSize"], rec["Tag"], rec["Parm1"], rec["Parm2"], rec["Parm3"],
                rec["Parm4"], rec["Parm5"], rec["Parm6"], rec["Parm7"], rec["Parm8"], rec["Lights"], rec["PreviewId"]
            ))
            if DEBUG:
                print(f"[DEBUG] (LOR single) AUTO -> subProps: parent={master_id} sub={sub_id} Start={g['StartChannel']}")

    conn.commit()
    conn.close()





def process_lor_multiple_channel_grids(preview_id, root):
    """
    RULES
    -----
    Purpose
      - Handle a single LOR PropClass that contains MULTIPLE ChannelGrid groups (";"-separated).
      - Keep the original prop as the master; materialize each grid group as its own subProp.

    Detection
      - DeviceType == "LOR"
      - MasterPropId is empty (it’s the top-level prop)
      - ChannelGrid contains ';' => multiple groups

    Behavior
      - Write the original prop to `props` (master).
      - For each grid group:
          * Build a deterministic SubPropID by suffixing the master's id with the two-digit StartChannel.
          * Name each subprop using:
              - first token of LORComment,
              - Color (if present),
              - UID,
              - StartChannel zero-padded (NN).
          * Insert into `subProps` with MasterPropId pointing to the master and full grid data.

    Preserve
      - Keep LORComment as-is; keep Name as used for the master.

    Inputs
      - preview_id: string id of the <PreviewClass>.
      - root: XML root (ElementTree).

    Outputs
      - Inserts master into `props`; emits one `subProps` row per grid group.

    Notes
      - This complements process_lor_props(); only one of the two will handle a given prop.
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
    # Choose master GRID by lowest (UID, StartChannel)  [controller wins]
    def _pair_key_grid(d):
        g = d.get("Grid") or {}
        uid = (g.get("UID") or "").strip().upper()      # e.g. '0A', '0B'
        uid_key = uid if uid else "ZZ"                  # missing UID sorts last
        sc = g.get("StartChannel")
        sc_key = sc if sc is not None else 10**9        # missing channel sorts last
        # deterministic tie-breaker (if needed)
        rid = d.get("PropID_scoped") or d.get("id") or d.get("Name") or ""
        return (uid_key, sc_key, rid)
    
    for comment, items in groups.items():
        if len(items) < 2:
            continue  # true multi-grid groups only

        # Choose master GRID by lowest StartChannel; tiebreaker: UID sorting
        # items_sorted = sorted(
        #     items,
        #     key=lambda d: ((d["Grid"]["StartChannel"] if d["Grid"]["StartChannel"] is not None else 1_000_000),
        #                    uid_sort_key(d["Grid"]["UID"]))
        # )
        items_sorted = sorted(items, key=_pair_key_grid)
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

        # Pre-scan: which display names should be owned by LOR/DMX/manual wiring?
        channel_names = collect_channel_display_names(root)

        # Process in the same order, but let process_none_props skip channel-owned names
        # process_none_props(preview_data["id"], root)

        # None props: skip anything that will be owned by LOR/DMX/manual wiring GAL 25-09-20
        process_none_props(preview_data["id"], root, skip_display_names=channel_names)

        # DMX/LOR unchanged
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

def collapse_duplicate_masters(db_file: str):
    """
    For each (PreviewId, Display_Name/LORComment):
      - keep one canonical PROP (min UID, then min StartChannel; tie-break on PropID)
      - demote all other PROPs in that group to subProps under the canonical master
    """
    import sqlite3
    conn = sqlite3.connect(db_file)
    try:
        sql = r"""
        -- Build canon from PROPs (exclude blank/SPARE)
        DROP TABLE IF EXISTS _canon;
        CREATE TEMP TABLE _canon AS
        SELECT p.PreviewId,
               p.LORComment AS Display_Name,
               COALESCE(p.UID,'ZZ')                AS uid,
               COALESCE(p.StartChannel,1000000000) AS sc,
               p.PropID
        FROM props p
        WHERE p.DeviceType='LOR'
          AND TRIM(COALESCE(p.LORComment,'')) <> ''
          AND UPPER(p.LORComment) <> 'SPARE';

        -- Choose by (UID, StartChannel) — UID first, then StartChannel
        DROP TABLE IF EXISTS _min_uid;
        CREATE TEMP TABLE _min_uid AS
        SELECT PreviewId, Display_Name, MIN(uid) AS min_uid
        FROM _canon
        GROUP BY PreviewId, Display_Name;

        DROP TABLE IF EXISTS _min_pair;
        CREATE TEMP TABLE _min_pair AS
        SELECT c.PreviewId, c.Display_Name, mu.min_uid AS uid, MIN(c.sc) AS min_sc
        FROM _canon c
        JOIN _min_uid mu
          ON mu.PreviewId=c.PreviewId AND mu.Display_Name=c.Display_Name
         AND c.uid=mu.min_uid
        GROUP BY c.PreviewId, c.Display_Name;

        -- Deterministic canonical master within the min pair
        DROP TABLE IF EXISTS _canon_pick;
        CREATE TEMP TABLE _canon_pick AS
        SELECT c.PreviewId, c.Display_Name, MIN(c.PropID) AS CanonPropID
        FROM _canon c
        JOIN _min_pair mp
          ON mp.PreviewId=c.PreviewId AND mp.Display_Name=c.Display_Name
         AND c.uid=mp.uid AND c.sc=mp.min_sc
        GROUP BY c.PreviewId, c.Display_Name;

        -- Demote extra PROPs -> subProps under the canonical master
        INSERT OR REPLACE INTO subProps (
            SubPropID, Name, LORComment, DeviceType, BulbShape,
            Network, UID, StartChannel, EndChannel, Unknown, Color,
            CustomBulbColor, DimmingCurveName, IndividualChannels, LegacySequenceMethod,
            MaxChannels, Opacity, MasterDimmable, PreviewBulbSize, RgbOrder,
            MasterPropId, SeparateIds, StartLocation, StringType, TraditionalColors, TraditionalType,
            EffectBulbSize, Tag, Parm1, Parm2, Parm3, Parm4, Parm5, Parm6, Parm7, Parm8, Lights, PreviewId
        )
        SELECT
            p.PropID, p.Name, p.LORComment, p.DeviceType, p.BulbShape,
            p.Network, p.UID, p.StartChannel, p.EndChannel, p.Unknown, p.Color,
            p.CustomBulbColor, p.DimmingCurveName, p.IndividualChannels, p.LegacySequenceMethod,
            p.MaxChannels, p.Opacity, p.MasterDimmable, p.PreviewBulbSize, NULL,
            cp.CanonPropID,
            p.SeparateIds, p.StartLocation, p.StringType, p.TraditionalColors, p.TraditionalType,
            p.EffectBulbSize, p.Tag, p.Parm1, p.Parm2, p.Parm3, p.Parm4, p.Parm5, p.Parm6, p.Parm7, p.Parm8,
            p.Lights, p.PreviewId
        FROM props p
        JOIN _canon_pick cp
          ON cp.PreviewId=p.PreviewId AND cp.Display_Name=p.LORComment
        WHERE p.DeviceType='LOR'
          AND TRIM(COALESCE(p.LORComment,'')) <> ''
          AND UPPER(p.LORComment) <> 'SPARE'
          AND p.PropID <> cp.CanonPropID;

        -- Delete the demoted PROPs
        DELETE FROM props
        WHERE DeviceType='LOR'
          AND TRIM(COALESCE(LORComment,'')) <> ''
          AND UPPER(LORComment) <> 'SPARE'
          AND EXISTS (
                SELECT 1 FROM _canon_pick cp
                WHERE cp.PreviewId = props.PreviewId
                  AND cp.Display_Name = props.LORComment
                  AND props.PropID <> cp.CanonPropID
          );

        -- Ensure existing subProps point to the canonical master
        UPDATE subProps
        SET MasterPropId = (
          SELECT cp.CanonPropID FROM _canon_pick cp
          WHERE cp.PreviewId=subProps.PreviewId
            AND cp.Display_Name=subProps.LORComment
        )
        WHERE EXISTS (
          SELECT 1 FROM _canon_pick cp
          WHERE cp.PreviewId=subProps.PreviewId
            AND cp.Display_Name=subProps.LORComment
        )
        AND (
              MasterPropId IS NULL
           OR NOT EXISTS (SELECT 1 FROM props p WHERE p.PropID = subProps.MasterPropId)
           OR MasterPropId <> (SELECT cp.CanonPropID FROM _canon_pick cp
                               WHERE cp.PreviewId=subProps.PreviewId
                                 AND cp.Display_Name=subProps.LORComment)
        );

        -- Clean up
        DROP TABLE IF EXISTS _canon;
        DROP TABLE IF EXISTS _min_uid;
        DROP TABLE IF EXISTS _min_pair;
        DROP TABLE IF EXISTS _canon_pick;
        """
        conn.executescript(sql)
        conn.commit()
        print("[INFO] Collapsed duplicate masters → kept canonical, demoted others to subProps.")
    finally:
        conn.close()



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

    # Collapse any duplicate masters first (this fixes the CarCounterDS/PS case)
    collapse_duplicate_masters(DB_FILE)

    # Reconciler (canon master snap)
    reconcile_subprops_to_canonical_master(DB_FILE)

    # ✅ Build the wiring views in the SAME DB file the parser just wrote
    create_wiring_views_v6(DB_FILE)

    print("Processing complete. Check the database.")

    # === Notice breadcrumb (FILE ONLY; no webhook required) ===
    try:
        text = _notice_text(PREVIEW_PATH, DB_FILE)  # you said this helper exists
        notice_path = write_notice_file(PREVIEW_PATH, text)  # and this one too
        print(f"[notify] Wrote notice file → {notice_path}")
    except Exception as e:
        print(f"[notify] failed: {e}")
        import traceback; traceback.print_exc()

# === Wiring views for V6 (map + sorted) GAL 25-08-23 ===
    """
    RULES
    -----
    Purpose
      - Build channel-centric views for wiring and QA.

    Views
      - preview_wiring_map_v6:
          * LOR master rows from `props` that have channels.
          * LOR legs from `subProps`.
          * DMX legs from `dmxChannels` (Controller shows the Universe).
          * DisplayName = dashified LORComment (spaces -> '-').
      - preview_wiring_sorted_v6:
          * Sorted projection of the map, ordered by PreviewName, DisplayName, Controller, StartChannel.

    Exclusions
      - DeviceType="None" items (no channels) are not included.

    Indexes
      - Adds supporting indexes on props/subProps/dmxChannels for faster filtering/sorting.
    """
def create_wiring_views_v6(db_file: str):
    import sqlite3
    ddl = r"""
    DROP VIEW IF EXISTS preview_wiring_map_v6;
    DROP VIEW IF EXISTS preview_wiring_sorted_v6;

    -- LOR masters (props) — KEEP masters even if a subprop shares the same address
    CREATE VIEW preview_wiring_map_v6 AS
    SELECT
      pv.Name AS PreviewName,
      'PROP'  AS Source,
      p.Name  AS Channel_Name,
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
      p.Color   AS Color,
      p.DeviceType, p.Tag AS LORTag
    FROM props p
    JOIN previews pv ON pv.id = p.PreviewId
    WHERE p.DeviceType='LOR'
      AND p.Network IS NOT NULL
      AND p.StartChannel IS NOT NULL

    UNION ALL

    -- LOR subprops — SHOW all, EXCEPT the one that shares the master's address (to avoid dup line)
    SELECT
      pv.Name,
      'SUBPROP' AS Source,
      sp.Name       AS Channel_Name,
      sp.LORComment AS Display_Name,
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
      sp.Color   AS Color,
      COALESCE(sp.DeviceType,'LOR') AS DeviceType, sp.Tag AS LORTag
    FROM subProps sp
    JOIN props p     ON p.PropID    = sp.MasterPropId AND p.PreviewId = sp.PreviewId
    JOIN previews pv ON pv.id       = sp.PreviewId
    WHERE NOT (sp.UID = p.UID AND sp.StartChannel = p.StartChannel)

    UNION ALL

    -- Inventory / unlit assets
    SELECT
      pv.Name, 'PROP', '', p.LORComment,
      REPLACE(TRIM(COALESCE(NULLIF(p.LORComment,''), p.Name)), ' ','-'),
      NULL, NULL, NULL, NULL,
      p.Color, 'None', p.Tag
    FROM props p
    JOIN previews pv ON pv.id = p.PreviewId
    WHERE p.DeviceType = 'None'

    UNION ALL

    -- DMX channels
    SELECT
      pv.Name,
      'DMX',
      p.Name,
      p.LORComment,
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
      ), ' ','-'),
      dc.Network, CAST(dc.StartUniverse AS TEXT),
      dc.StartChannel, dc.EndChannel,
      'RGB', 'DMX', p.Tag
    FROM dmxChannels dc
    JOIN props p     ON p.PropID   = dc.PropId AND p.PreviewId = dc.PreviewId
    JOIN previews pv ON pv.id      = p.PreviewId;

    -- Sorted convenience view
    CREATE VIEW preview_wiring_sorted_v6 AS
    SELECT
      PreviewName, Source, Channel_Name, Display_Name, Suggested_Name,
      Network, Controller, StartChannel, EndChannel, Color, DeviceType, LORTag
    FROM preview_wiring_map_v6
    ORDER BY PreviewName COLLATE NOCASE, Network COLLATE NOCASE, Controller, StartChannel;

    -- Exactly one LOR master per (PreviewId, Display_Name), excluding SPARE/blank
    CREATE UNIQUE INDEX IF NOT EXISTS uniq_master_per_preview_name
    ON props(PreviewId, LORComment)
    WHERE DeviceType='LOR'
    AND TRIM(COALESCE(LORComment,'')) <> ''
    AND UPPER(LORComment) <> 'SPARE';

    -- helpful indexes
    CREATE INDEX IF NOT EXISTS idx_props_preview                  ON props(PreviewId);
    CREATE INDEX IF NOT EXISTS idx_subprops_preview               ON subProps(PreviewId);
    CREATE INDEX IF NOT EXISTS idx_subprops_preview_uid_ch        ON subProps(PreviewId, UID, StartChannel);
    CREATE INDEX IF NOT EXISTS idx_dmx_prop                       ON dmxChannels(PropId);
    CREATE INDEX IF NOT EXISTS idx_props_preview_comment   ON props(PreviewId, LORComment);
    CREATE INDEX IF NOT EXISTS idx_subprops_preview_comment ON subProps(PreviewId, LORComment);
    """
    conn = sqlite3.connect(db_file)
    try:
        conn.executescript(ddl)
        conn.commit()
        print("[INFO] Created preview_wiring_map_v6 and preview_wiring_sorted_v6 (keep masters; hide only duplicate sub at same address).")
    finally:
        conn.close()

    # use last year's Master musical preview to see where changes have occurred (OPTIONAL)
    def load_master_keys_csv(conn, csv_path):
        import csv
        c = conn.cursor()
        c.execute("DROP TABLE IF EXISTS master_musical_prev_keys")

        with open(csv_path, newline='', encoding='utf-8') as f:
            reader = csv.reader(f)
            headers = next(reader)

            col_defs = ", ".join([f'"{h}" TEXT' for h in headers])
            c.execute(f"CREATE TABLE master_musical_prev_keys ({col_defs});")

            f.seek(0)
            reader = csv.DictReader(f)
            rows = [tuple(row[h] for h in headers) for row in reader]

        placeholders = ", ".join(["?"] * len(headers))
        c.executemany(
            f'INSERT INTO master_musical_prev_keys ({",".join(headers)}) VALUES ({placeholders})',
            rows
        )
        conn.commit()
        print(f"[INFO] Imported {len(rows)} rows into master_musical_prev_keys")


    def create_breaking_check_view(conn):
        ddl = """
        DROP VIEW IF EXISTS breaking_check_v6;
        CREATE VIEW breaking_check_v6 AS
        SELECT
            m.RawPropID,
            m.ChannelName   AS ChannelName_2024,
            m.DisplayName   AS DisplayName_2024,
            p.Name          AS ChannelName_Now,
            p.LORComment    AS DisplayName_Now,
            CASE WHEN p.PropID IS NULL THEN 1 ELSE 0 END AS Missing_Now,
            CASE WHEN p.PropID IS NOT NULL
                AND m.ChannelName != IFNULL(p.Name,'') THEN 1 ELSE 0 END AS ChannelName_Changed,
            CASE WHEN p.PropID IS NOT NULL
                AND m.DisplayName != IFNULL(p.LORComment,'') THEN 1 ELSE 0 END AS DisplayName_Changed
        FROM master_musical_prev_keys m
        LEFT JOIN props p ON p.PropID = m.RawPropID;
        """
        conn.executescript(ddl)
        conn.commit()
        print("[INFO] Created breaking_check_v6 view")

    # (Optional) Kick off the display-name comparison report Remove when done with spreadsheet GAL
    try:
        import subprocess, sys
        compare_script = r"G:\Shared drives\MSB Database\Spreadsheet\compare_displays_vs_db.py"
        if os.path.exists(compare_script):
            print("[INFO] Running compare_displays_vs_db.py …")
            subprocess.run([sys.executable, compare_script], check=False)
        else:
            print(f"[INFO] Compare script not found at: {compare_script} (skipping)")
    except Exception as e:
        print(f"[WARN] Could not run compare script: {e}")


if __name__ == "__main__":
    main()