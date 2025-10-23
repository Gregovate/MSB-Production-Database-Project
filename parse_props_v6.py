# MSB Database — LOR Preview Parser (v6)
# Initial Release : 2022-01-20  V0.1.0
# Current Version : 2025-10-23  V6.7.5 (GAL)
# Author          : Greg Liebig, Engineering Innovations, LLC.
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
# Recent Additions (GAL 2025-10-23 → v6.7.5)
# -------------------------------------------
# • DeviceType ="None" handling re-aligned to Core Model v1.0:
#     – Masters ( MasterPropId is NULL ) → insert into props as stand-alone inventory records.  
#     – Linked units ( MasterPropId set ) → ignored or optional subProps write (no wiring impact).  
#     – No local fan-out; global fan-out handled later in the pipeline.
#
# • Global uniqueness audit added for DisplayName masters across previews.  
#     – A DisplayName can be mastered in only one preview → hard error with CSV reports.  
#     – Grouped console output restored (props/subProps counts per preview).
#
# • Reports now write to a dedicated folder:  
#       G:\Shared drives\MSB Database\Database Previews\reports\
#        – duplicate_display_names_masters.csv  
#        – duplicate_display_names_by_preview.csv
#
# • get_reports_dir() enhanced to honor REPORTS_DIR or REPORTS_PATH and auto-create the folder.
#
# • Minor documentation alignment with lor_core.py (field map clarity; no logic changes).

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
#           - Lights count from Parm2 (if present) aggregated by LORComment.
#           - Present for labeling, inventory, storage.
#           - Excluded from wiring views (no channels).
#
# Wiring Views
# ------------
# • preview_wiring_map_v6 / preview_wiring_sorted_v6 present channel maps for wiring.
# • Only channel-based items appear (LOR, DMX).
# • DeviceType=None props are omitted from views but remain in `props`.
#
# IDs and Scoping
# ---------------
# LOR Visualizer can reuse PropClass.id across different previews. If you need
# globally unique keys, scope every raw xml id by preview:
#
#     def scoped_id(preview_id: str, raw_id: str) -> str:
#         return f"{preview_id}:{raw_id}"
#
# Use the scoped value consistently for:
#   - props.PropID
#   - subProps.MasterPropId
#   - subProps.SubPropID
#
# Error Checking & Reports (GAL 2025-10-23)
# -----------------------------------------
# • PropID/SubPropID collisions:
#     - Console ERROR: “Prop/SubProp collision: Preview='<Name>' Display='<LORComment>' Channel='<Name>' …”
#     - CSVs: propid_collisions.csv, subpropid_collisions.csv
# • (Planned next) Duplicate Display Names (ERROR) across system → duplicate_display_names.csv
# • (Planned next) Wiring collisions across previews (INFO) → wiring_collisions_all_previews.csv
#
# Logging Toggles
# ---------------
# • DEBUG:            chatty per-item logs and per-display listing.
# • PREVIEW_DEBUG:    dumps full preview dicts (off by default).
# • PREVIEW_SUMMARY_STYLE: "short" | "long" line format for per-preview summaries.
#
# Notice & Artifacts
# ------------------
# On completion, a notice file is written to:
#     G:\Shared drives\MSB Database\Database Previews\_notifications\db-rebuild-YYYYMMDD-HHMMSS.txt
# It lists standard artifacts (wiring views, preview manifest, spreadsheet log) and any present reports.



import os
import sys
import xml.etree.ElementTree as ET
import sqlite3
import pathlib
from collections import defaultdict
import uuid
from pathlib import Path
import re
# GAL 25-10-22 (GAL): CSV + filesystem for reporting
import csv


# GAL 25-10-16: Align parser docs with Core Model v1.0 (no logic changes)
# - Declares LOR→DB naming map inline for clarity (Comment→DisplayName, Name→ChannelName, etc.)
# - Attempts to import field lists from lor_core for documentation parity only

# LOR→DB field map (doc parity; see lor_core.py for canonical list):
#   PreviewClass.id     → previews.id           (PreviewID; key)
#   PreviewClass.Name   → previews.Name         (PreviewName; operator label)
#   PreviewClass.BackgroundFile → previews.BackgroundFile  (QA/low)
#   PropClass.id        → props.PropID / subProps.SubPropID   (key)
#   PropClass.Comment   → props.LORComment / subProps.LORComment (Display Name)
#   PropClass.Name      → props.Name / subProps.Name            (Channel Name)
#   ChannelGrid         → props.Network, props.UID, props.StartChannel, props.EndChannel, props.Unknown, props.Color
#   DimmingCurveName    → props.DimmingCurveName / subProps.DimmingCurveName
#   DeviceType          → props.DeviceType / subProps.DeviceType ("LOR" | "DMX" | "None")
#   DMX grid (universe) → dmxChannels.(Network, StartUniverse, StartChannel, EndChannel, Unknown)

try:
    # Documentation parity only; do not rely on these at runtime
    from lor_core import PREVIEW_FIELDS, LOR_FIELDS, DMX_FIELDS  # noqa: F401
except Exception:
    # Keep parser standalone if lor_core.py isn’t present
    PREVIEW_FIELDS = LOR_FIELDS = DMX_FIELDS = []


# ============================= G: ONLY ============================= #
G = Path(r"G:\Shared drives\MSB Database")
# GAL 25-10-23 reports directory for collision CSVs and audits
REPORTS_DIR = Path(r"G:\Shared drives\MSB Database\Database Previews\reports")
def require_g():
    if not G.exists():
        print("[FATAL] G: drive not available. All data lives on the shared drive.")
        print("        Mount the shared drive and try again.")
        sys.exit(2)

def get_reports_dir() -> str:
    """
    Resolve a writable reports directory:
      1) REPORTS_DIR (Path or str), if defined
      2) REPORTS_PATH (str), if defined
      3) <folder of DB_FILE>\reports
    Ensures the directory exists and returns an absolute path.
    """
    import os
    # Prefer REPORTS_DIR if present
    rd = globals().get("REPORTS_DIR", None)
    if rd:
        reports_dir = os.path.abspath(str(rd))
    else:
        rp = globals().get("REPORTS_PATH", None)
        if rp:
            reports_dir = os.path.abspath(rp)
        else:
            db_dir = os.path.abspath(os.path.dirname(DB_FILE))
            reports_dir = os.path.join(db_dir, "reports")

    os.makedirs(reports_dir, exist_ok=True)
    return reports_dir

# ============================= G: ONLY ============================= #



# ---- Global flags & defaults (must be defined before functions) ----
DEBUG = False  # Global debug flag
# GAL 25-10-22: toggle for ultra-verbose preview dict logging
PREVIEW_DEBUG = False  # set True only when you want the full preview dict dumped

# Hard-set G:\ defaults
DEFAULT_DB_FILE      = G / "database" / "lor_output_v6.db"
DEFAULT_PREVIEW_PATH = G / "Database Previews"

# Globals that existing functions use; will be set/confirmed in main()
DB_FILE = DEFAULT_DB_FILE
PREVIEW_PATH = DEFAULT_PREVIEW_PATH


def get_path(prompt: str, default_path: str) -> str:
    """Prompt for a path, using a default if user just hits Enter."""
    user_input = input(f"{prompt} [{default_path}]: ").strip()
    if user_input:
        return os.path.normpath(user_input)
    return default_path


# --- Preview name resolver ---------------------------------------------------
# GAL 25-10-22 (GAL): Resolve previews.id -> previews.Name for human reports.
_preview_name_cache: dict[str, str] = {}

def get_preview_name(cursor, preview_id: str | None) -> str:
    if not preview_id:
        return ""
    if preview_id in _preview_name_cache:
        return _preview_name_cache[preview_id]
    try:
        cursor.execute("SELECT Name FROM previews WHERE id = ?", (preview_id,))
        row = cursor.fetchone()
        name = row[0] if row else ""
        _preview_name_cache[preview_id] = name
        return name
    except Exception:
        return ""

# GAL 25-10-23: compact per-preview summary (no duplicate ctx name)
# Console logging format
PREVIEW_SUMMARY_STYLE = "short"  # "short" | "long"

def log_preview_summary(pd: dict, display_count: int):
    """
    Short, readable line per preview.
      short → [..][INFO][ctx=Show Background Stage 14 Icicle Tunnel] S=14 R=103 D=34
      long  → [..][INFO][ctx=Show Background Stage 14 Icicle Tunnel] StageID=14 Rev=103 Displays=34
    """
    name = pd.get("Name", "")
    stage = pd.get("StageID", "--")
    rev = pd.get("Revision", "?")
    if PREVIEW_SUMMARY_STYLE == "short":
        INFO(f"ID={stage} Rev={rev} DispQty={display_count}", ctx=name)
    else:
        INFO(f"StageID={stage} Rev={rev} Displays={display_count}", ctx=name)



# -----------------------------------------------------------------------------
# GAL 25-10-22 (GAL): PropID collision helpers (standalone, no extra deps)
# (TOP-LEVEL definitions; NOT nested inside get_preview_name)
# -----------------------------------------------------------------------------

# In-memory accumulator for collisions (write once at end-of-run)
try:
    _PROPID_COLLISIONS  # may already exist if pasted earlier
except NameError:
    _PROPID_COLLISIONS: list[dict] = []

def find_prop_by_id(cursor, prop_id: str) -> dict | None:
    """
    Return an existing props row as dict if present, else None.
    Pulls only columns we need for actionable collision messages.
    Uses literal column names to avoid alias dependencies.
    """
    try:
        cursor.execute("""
            SELECT
                PropID,
                Name,
                LORComment,
                PreviewId,
                DeviceType,
                Network,
                UID,
                StartChannel,
                EndChannel
            FROM props
            WHERE PropID = ?
        """, (prop_id,))
        row = cursor.fetchone()
        if row is None:
            return None
        cols = [d[0] for d in cursor.description]
        return {k: v for k, v in zip(cols, row)}
    except Exception as e:
        WARN(f"find_prop_by_id failed for PropID='{prop_id}': {e}")
        return None

def _record_propid_collision(incoming: dict, existing: dict):
    """
    Record a PropID collision for console + CSV later.
    We prefer human-readable names in the console; IDs remain in the CSV.
    """
    # Prefer human preview names if present
    new_prev_name = incoming.get("PreviewName") or incoming.get("Incoming_PreviewName") or ""
    old_prev_name = existing.get("PreviewName") or existing.get("Existing_PreviewName") or ""

    # Fallback to IDs if names missing
    new_prev_id = incoming.get("PreviewId", "")
    old_prev_id = (existing or {}).get("PreviewId", "")

    # Display & channel names
    new_disp  = incoming.get("LORComment") or incoming.get("Name") or ""
    old_disp  = (existing or {}).get("LORComment") or (existing or {}).get("Name") or ""
    new_chan  = incoming.get("Name") or ""
    old_chan  = (existing or {}).get("Name") or ""

    # Wiring context
    new_net   = incoming.get("Network", "")
    new_uid   = incoming.get("UID", "")
    new_start = incoming.get("StartChannel", "")
    new_end   = incoming.get("EndChannel", "")
    new_dtype = incoming.get("DeviceType", "")

    old_net   = (existing or {}).get("Network", "")
    old_uid   = (existing or {}).get("UID", "")
    old_start = (existing or {}).get("StartChannel", "")
    old_end   = (existing or {}).get("EndChannel", "")
    old_dtype = (existing or {}).get("DeviceType", "")

    # Console ERROR (human-focused)
    disp_ctx = new_prev_name or new_prev_id or new_disp or "unknown"
    ERROR(
        "Prop collision: "
        f"Preview='{new_prev_name or new_prev_id}', Display='{new_disp}', Channel='{new_chan}' "
        f"conflicts with existing in Preview='{old_prev_name or old_prev_id}', "
        f"Display='{old_disp}', Channel='{old_chan}' "
        f"(Dev='{old_dtype}', Net='{old_net}', UID='{old_uid}', Ch={old_start}-{old_end})",
        ctx=disp_ctx
    )

    # CSV row (keep full structured data; IDs + later-resolved names)
    _PROPID_COLLISIONS.append({
        "PropID": incoming.get("PropID", ""),
        "Existing_PreviewId": old_prev_id,
        "Existing_PreviewName": old_prev_name,
        "Existing_DisplayName": old_disp,
        "Existing_DeviceType": old_dtype,
        "Existing_Network": old_net,
        "Existing_UID": old_uid,
        "Existing_StartChannel": old_start,
        "Existing_EndChannel": old_end,

        "Incoming_PreviewId": new_prev_id,
        "Incoming_PreviewName": new_prev_name,
        "Incoming_DisplayName": new_disp,
        "Incoming_DeviceType": new_dtype,
        "Incoming_Network": new_net,
        "Incoming_UID": new_uid,
        "Incoming_StartChannel": new_start,
        "Incoming_EndChannel": new_end,
    })

# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# GAL 25-10-22 (GAL): SubPropID collision detection (standalone)
# -----------------------------------------------------------------------------

# In-memory accumulator for subprop collisions
try:
    _SUBPROPID_COLLISIONS  # may already exist
except NameError:
    _SUBPROPID_COLLISIONS: list[dict] = []

def find_subprop_by_id(cursor, subprop_id: str) -> dict | None:
    """
    Return an existing subProps row as dict if present, else None.
    Pull columns that make the collision message actionable.
    """
    try:
        cursor.execute("""
            SELECT
                SubPropID,
                Name,
                LORComment,
                PreviewId,
                DeviceType,
                Network,
                UID,
                StartChannel,
                EndChannel,
                MasterPropId
            FROM subProps
            WHERE SubPropID = ?
        """, (subprop_id,))
        row = cursor.fetchone()
        if row is None:
            return None
        cols = [d[0] for d in cursor.description]
        return {k: v for k, v in zip(cols, row)}
    except Exception as e:
        WARN(f"find_subprop_by_id failed for SubPropID='{subprop_id}': {e}")
        return None

def _record_subprop_collision(incoming: dict, existing: dict):
    """
    Capture a SubPropID collision (human-friendly console; detailed CSV).
    """
    new_prev_name = incoming.get("PreviewName") or incoming.get("Incoming_PreviewName") or ""
    old_prev_name = existing.get("PreviewName") or existing.get("Existing_PreviewName") or ""

    new_prev_id = incoming.get("PreviewId", "")
    old_prev_id = (existing or {}).get("PreviewId", "")

    new_disp  = incoming.get("LORComment") or incoming.get("Name") or ""
    old_disp  = (existing or {}).get("LORComment") or (existing or {}).get("Name") or ""
    new_chan  = incoming.get("Name") or ""
    old_chan  = (existing or {}).get("Name") or ""

    new_net   = incoming.get("Network", "")
    new_uid   = incoming.get("UID", "")
    new_start = incoming.get("StartChannel", "")
    new_end   = incoming.get("EndChannel", "")
    new_dtype = incoming.get("DeviceType", "")
    new_mid   = incoming.get("MasterPropId", "")

    old_net   = (existing or {}).get("Network", "")
    old_uid   = (existing or {}).get("UID", "")
    old_start = (existing or {}).get("StartChannel", "")
    old_end   = (existing or {}).get("EndChannel", "")
    old_dtype = (existing or {}).get("DeviceType", "")
    old_mid   = (existing or {}).get("MasterPropId", "")

    disp_ctx = new_prev_name or new_prev_id or new_disp or "unknown"
    ERROR(
        "SubProp collision: "
        f"Preview='{new_prev_name or new_prev_id}', Display='{new_disp}', Channel='{new_chan}' "
        f"conflicts with existing in Preview='{old_prev_name or old_prev_id}', "
        f"Display='{old_disp}', Channel='{old_chan}' "
        f"(Dev='{old_dtype}', Net='{old_net}', UID='{old_uid}', Ch={old_start}-{old_end}, Master='{old_mid}')",
        ctx=disp_ctx
    )

    _SUBPROPID_COLLISIONS.append({
        "SubPropID": incoming.get("SubPropID",""),
        "Existing_PreviewId": old_prev_id,
        "Existing_PreviewName": old_prev_name,
        "Existing_DisplayName": old_disp,
        "Existing_DeviceType": old_dtype,
        "Existing_Network": old_net,
        "Existing_UID": old_uid,
        "Existing_StartChannel": old_start,
        "Existing_EndChannel": old_end,
        "Existing_MasterPropId": old_mid,

        "Incoming_PreviewId": new_prev_id,
        "Incoming_PreviewName": new_prev_name,
        "Incoming_DisplayName": new_disp,
        "Incoming_DeviceType": new_dtype,
        "Incoming_Network": new_net,
        "Incoming_UID": new_uid,
        "Incoming_StartChannel": new_start,
        "Incoming_EndChannel": new_end,
        "Incoming_MasterPropId": new_mid,
    })


# -----------------------------------------------------------------------------
# GAL 25-10-23: collision-aware subProps insert (fixed local 'sid' scope)
# -----------------------------------------------------------------------------
def safe_insert_subprop(cursor, insert_sql: str, params: tuple | list, incoming_context: dict):
    """
    Perform a subProps INSERT with collision detection by SubPropID.
    - If SubPropID missing: ERROR and skip
    - If SubPropID exists: ERROR, record collision, skip
    - Else: execute the INSERT
    """
    sid = incoming_context.get("SubPropID")
    if not sid:
        ERROR("Attempted to insert subprop without SubPropID; insert skipped.", ctx=incoming_context.get("PreviewId"))
        return False

    # Pre-check for existing SubPropID
    existing = find_subprop_by_id(cursor, sid)
    if existing:
        # Enrich with human preview names for a clearer console message
        try:
            inc = dict(incoming_context)
            inc["PreviewName"] = get_preview_name(cursor, inc.get("PreviewId"))
            ex = dict(existing)
            ex["PreviewName"] = get_preview_name(cursor, ex.get("PreviewId"))
        except Exception:
            inc = incoming_context
            ex = existing

        _record_subprop_collision(inc, ex)
        return False

    # Attempt the actual insert
    try:
        cursor.execute(insert_sql, params)
        return True
    except sqlite3.IntegrityError as e:
        ERROR(f"DB integrity error inserting SubPropID='{sid}': {e}", ctx=incoming_context.get("PreviewId"))
        return False
    except Exception as e:
        ERROR(f"DB error inserting SubPropID='{sid}': {e}", ctx=incoming_context.get("PreviewId"))
        return False
# -----------------------------------------------------------------------------



def write_subprop_collisions_csv(cursor=None):
    """Write all recorded SubPropID collisions to REPORTS_DIR/subpropid_collisions.csv."""
    # Nothing to do if empty/undefined
    try:
        if not _SUBPROPID_COLLISIONS:
            return
    except NameError:
        return

    # Ensure folder
    try:
        REPORTS_DIR.mkdir(parents=True, exist_ok=True)
    except Exception as e:
        WARN(f"Could not ensure reports directory: {e}")

    out_path = REPORTS_DIR / "subpropid_collisions.csv"
    try:
        fieldnames = [
            "SubPropID",
            "Existing_PreviewId", "Existing_PreviewName", "Existing_DisplayName",
            "Existing_DeviceType", "Existing_Network", "Existing_UID", "Existing_StartChannel", "Existing_EndChannel", "Existing_MasterPropId",
            "Incoming_PreviewId", "Incoming_PreviewName", "Incoming_DisplayName",
            "Incoming_DeviceType", "Incoming_Network", "Incoming_UID", "Incoming_StartChannel", "Incoming_EndChannel", "Incoming_MasterPropId",
        ]

        rows = []
        for r in _SUBPROPID_COLLISIONS:
            rp = dict(r)
            if cursor:
                rp["Existing_PreviewName"] = get_preview_name(cursor, r.get("Existing_PreviewId"))
                rp["Incoming_PreviewName"] = get_preview_name(cursor, r.get("Incoming_PreviewId"))
            else:
                rp["Existing_PreviewName"] = ""
                rp["Incoming_PreviewName"] = ""
            rows.append(rp)

        with open(out_path, "w", encoding="utf-8", newline="") as f:
            w = csv.DictWriter(f, fieldnames=fieldnames)
            w.writeheader()
            w.writerows(rows)
        INFO(f"Wrote SubPropID collision report: {out_path}")
    except Exception as e:
        WARN(f"Failed writing SubPropID collision CSV: {e}")
# -----------------------------------------------------------------------------


# --- Debug print -------------------------------------------------------------
# (Existing behavior retained)
def dprint(msg: str):
    """Safe debug print that won't crash if DEBUG isn't bound elsewhere."""
    if DEBUG:
        print(msg)

# GAL 25-10-22 (GAL): Structured console logging helpers
# Notes:
# - We keep dprint(...) for very chatty lines.
# - INFO/WARN/ERROR add a timestamp and an optional context tag (e.g., PreviewName).
# - Zero behavior changes elsewhere; these are additive and safe to call anywhere.
import datetime as _dt

def _log(level: str, msg: str, ctx: str | None = None):
    """
    Emit a structured console line.
    Example:
        INFO("Processed preview", ctx="RGB Plus Prop Stage 03 Mega Cube")
    Output:
        [2025-10-22 20:11:03][INFO][ctx=RGB Plus Prop Stage 03 Mega Cube] Processed preview
    """
    ts = _dt.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    ctx_part = f"[ctx={ctx}] " if ctx else ""
    # Use print(..., flush=True) so lines appear immediately in long runs.
    print(f"[{ts}][{level}]{ctx_part}{msg}", flush=True)

def INFO(msg: str, ctx: str | None = None): _log("INFO", msg, ctx)
def WARN(msg: str, ctx: str | None = None): _log("WARN", msg, ctx)
def ERROR(msg: str, ctx: str | None = None): _log("ERROR", msg, ctx)


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
        # GAL 25-10-16: Comment→DisplayName hygiene should match lor_core.validate_display_name()
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

def _who_ran() -> str:
    """
    Return a friendly 'User on Host' string.
    Works on Windows and *nix without throwing in services.
    """
    # user
    user = (
        os.environ.get("USERNAME")
        or os.environ.get("USER")
        or getpass.getuser()
        or "unknown"
    )

    # host
    host = (
        os.environ.get("COMPUTERNAME")
        or socket.gethostname()
        or platform.node()
        or "unknown-host"
    )

    # normalize to avoid whitespace surprises
    user = str(user).strip() or "unknown"
    host = str(host).strip() or "unknown-host"

    return f"{user} on {host}"


# -----------------------------------------------------------------------------
# Notification message and file writer
# -----------------------------------------------------------------------------

def _notice_text(preview_path: str | Path, db_file: str | Path, actor: str | None = None) -> str:
    # GAL 25-10-22 (GAL): include Actor; list standard artifacts; tack on
    # optional audit reports if they exist. No behavior changes for callers.
    ts = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    actor = actor or _who_ran()

    # Core body (unchanged, preserving your wording/layout)
    body = (
        "MSB Database rebuild complete\n"
        f"Timestamp : {ts}\n"
        f"Actor     : {actor}\n"          # <-- NEW in your version; preserved
        f"Database  : {Path(db_file)}\n"
        f"Previews  : {Path(preview_path)}\n"
        "Artifacts :\n"
        "  - Wiring views created (v6)\n"
        "  - Preview manifest written G:\\Shared drives\\MSB Database\\Database Previews\\current_previews_manifest.html\n"
        "  - Spreadsheet Log written G:\\Shared drives\\MSB Database\\Database Previews\\lorprev_reports.xlsx\n"
    )

    # Optional audits (only shown if present)
    try:
        from pathlib import Path as _P
        reports_dir = _P(r"G:\Shared drives\MSB Database\Database Previews\reports")
        extras = []
        if (reports_dir / "propid_collisions.csv").exists():
            extras.append("  - PropID collision report (if any): Database Previews\\reports\\propid_collisions.csv")
        if (reports_dir / "duplicate_display_names.csv").exists():
            extras.append("  - Duplicate Display Names report (if any): Database Previews\\reports\\duplicate_display_names.csv")
        if (reports_dir / "wiring_collisions_all_previews.csv").exists():
            extras.append("  - Wiring collisions report (if any): Database Previews\\reports\\wiring_collisions_all_previews.csv")
        if extras:
            body += "".join(line + "\n" for line in extras)
    except Exception:
        # Non-fatal; keep the core notice if any error occurs checking files
        pass

    return body

def write_notice_file(preview_path: str | Path, text: str) -> Path:
    # GAL 25-10-22 (GAL): INFO log with written path; otherwise unchanged
    outdir = Path(preview_path) / "_notifications"
    outdir.mkdir(parents=True, exist_ok=True)
    fname = f"db-rebuild-{datetime.now().strftime('%Y%m%d-%H%M%S')}.txt"
    outpath = outdir / fname
    outpath.write_text(text, encoding="utf-8")
    INFO(f"Notice written: {outpath}")
    return outpath
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# GAL 25-10-22 (GAL): Write PropID collision CSV (resolves preview names)
# -----------------------------------------------------------------------------
def write_propid_collisions_csv(cursor=None):
    """Write all recorded PropID collisions to REPORTS_DIR/propid_collisions.csv."""
    try:
        if not _PROPID_COLLISIONS:
            return
    except NameError:
        return  # not defined = nothing to write

    # Make sure the folder exists without relying on _ensure_reports_dir()
    try:
        REPORTS_DIR.mkdir(parents=True, exist_ok=True)
    except Exception as e:
        WARN(f"Could not ensure reports directory: {e}")

    out_path = REPORTS_DIR / "propid_collisions.csv"
    try:
        fieldnames = [
            "PropID",
            "Existing_PreviewId", "Existing_PreviewName", "Existing_DisplayName",
            "Existing_DeviceType", "Existing_Network", "Existing_UID", "Existing_StartChannel", "Existing_EndChannel",
            "Incoming_PreviewId", "Incoming_PreviewName", "Incoming_DisplayName",
            "Incoming_DeviceType", "Incoming_Network", "Incoming_UID", "Incoming_StartChannel", "Incoming_EndChannel",
        ]

        # Enrich with preview names if cursor provided
        rows = []
        for r in _PROPID_COLLISIONS:
            rp = dict(r)  # copy
            if cursor:
                rp["Existing_PreviewName"] = get_preview_name(cursor, r.get("Existing_PreviewId"))
                rp["Incoming_PreviewName"] = get_preview_name(cursor, r.get("Incoming_PreviewId"))
            else:
                rp["Existing_PreviewName"] = ""
                rp["Incoming_PreviewName"] = ""
            rows.append(rp)

        with open(out_path, "w", encoding="utf-8", newline="") as f:
            w = csv.DictWriter(f, fieldnames=fieldnames)
            w.writeheader()
            w.writerows(rows)

        INFO(f"Wrote PropID collision report: {out_path}")
    except Exception as e:
        WARN(f"Failed writing PropID collision CSV: {e}")

# Call this once at end-of-run (after all inserts; before exit/close):
# try:
#     write_propid_collisions_csv(cursor)
# except Exception as _e:
#     WARN(f"Unable to write PropID collision CSV: {_e}")
# -----------------------------------------------------------------------------





# --- Column Aliases (documentation + safer references) -----------------------
# GAL 25-10-22 (GAL): We keep DB column names identical to LOR XML where possible.
# These aliases are for readability in code/reports. Do NOT change schema.
DISPLAY_NAME    = "LORComment"   # Human "Display Name" (from XML Comment)
CONTROLLER_UID  = "UID"          # Hex controller ID (human-readable)
CONTROLLER_NET  = "Network"      # Regular, Aux A, Aux B, ...
CHANNEL_START   = "StartChannel" # A/C plug for AC controllers; RGB start chan
CHANNEL_END     = "EndChannel"   # RGB end channel
DEVICE_TYPE     = "DeviceType"   # LOR, DMX, None (Undetermined in LOR UI)
PREVIEW_ID_COL  = "PreviewId"    # FK to previews.id
PROP_ID_COL     = "PropID"       # LOR-generated prop GUID (join key downstream)
PROP_NAME_COL   = "Name"         # Human channel name (from XML Name)


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
    # GAL 25-10-16: Table mirrors Core Model v1.0 preview fields (PreviewID/Name/BackgroundFile)
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
    # GAL 25-10-16: Table mirrors Core Model v1.0 for LOR/DMX master rows; Comment→LORComment, Name→ChannelName
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
    # GAL 25-10-16: Subprops carry same naming map (Comment→LORComment, Name→ChannelName)
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
    # GAL 25-10-16: DMX channels reflect universe-based wiring per Core Model v1.0
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
    # GAL 25-10-22: keep the old dump but gate it behind PREVIEW_DEBUG
    if PREVIEW_DEBUG:
        dprint(f"[DEBUG] Processed Preview: {preview_data}")
    return preview_data

# --- Stage ID extraction -----------------------------------------------------
# GAL 25-10-22 (GAL): Refined StageID logic and documentation
#   Purpose:
#     - Capture only the two-digit number that follows the word "Stage"
#       Example: "Show Background Stage 05 Mega Star" -> StageID = "05"
#     - If "Animation" is in the name (and no Stage found), use the entire
#       preview name as StageID for clarity and uniqueness.
#     - If neither found, return None (safe default).
#
#   Why:
#     Previous versions could extract trailing digits from longer numbers
#     (e.g., "Stage 00 HWY42" -> "0042").  This version avoids that bug.
#
#   Notes:
#     - Zero-pads single digits ("Stage 7" -> "07").
#     - Case-insensitive.
#     - Safe for missing/None names.

_STAGE_RE = re.compile(r"\bStage\s*(\d{1,2})\b", flags=re.IGNORECASE)

def extract_stage_id(name: str | None):
    """Return normalized 2-digit StageID or None if not found."""
    if not name:
        return None

    # Primary: look for "Stage NN" (two digits)
    m = _STAGE_RE.search(name)
    if m:
        try:
            # normalize to exactly 2 digits
            return f"{int(m.group(1)):02d}"
        except Exception:
            # In case of malformed capture, return None safely
            return None

    # Secondary: "Animation" fallback (use full name as ID)
    if "animation" in name.lower():
        return name

    # Otherwise, no StageID context available
    return None
# (GAL 25-10-22)

# ---- Insert Helpers ---------------------------------------------------------
# -----------------------------------------------------------------------------
# GAL 25-10-22 (GAL): Collision-aware insert wrapper for props
# -----------------------------------------------------------------------------
# -----------------------------------------------------------------------------
# GAL 25-10-23: collision-aware props insert (fixed local 'pid' scope)
# -----------------------------------------------------------------------------
def safe_insert_prop(cursor, insert_sql: str, params: tuple | list, incoming_context: dict):
    """
    Perform a props INSERT with collision detection by PropID.
    - If PropID missing: ERROR and skip
    - If PropID exists: ERROR, record collision, skip
    - Else: execute the INSERT
    """
    pid = incoming_context.get("PropID")
    if not pid:
        ERROR("Attempted to insert prop without PropID; insert skipped.", ctx=incoming_context.get("PreviewId"))
        return False

    # Pre-check for existing PropID
    existing = find_prop_by_id(cursor, pid)
    if existing:
        # Enrich with human preview names for the console message
        try:
            inc = dict(incoming_context)
            inc["PreviewName"] = get_preview_name(cursor, inc.get("PreviewId"))
            ex = dict(existing)
            ex["PreviewName"] = get_preview_name(cursor, ex.get("PreviewId"))
        except Exception:
            inc = incoming_context
            ex = existing

        _record_propid_collision(inc, ex)
        return False

    # Attempt the actual insert
    try:
        cursor.execute(insert_sql, params)
        return True
    except sqlite3.IntegrityError as e:
        ERROR(f"DB integrity error inserting PropID='{pid}': {e}", ctx=incoming_context.get("PreviewId"))
        return False
    except Exception as e:
        ERROR(f"DB error inserting PropID='{pid}': {e}", ctx=incoming_context.get("PreviewId"))
        return False
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------


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

# 



# ============================ Parsing Modules ===========================================
# def process_none_props(preview_id, root):
# def process_none_props(preview_id, root, skip_display_names: set[str] | None = None):
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

def process_none_props(preview_id, root, skip_display_names: set[str] | None = None):
    """
    DeviceType == "None" (masters-only to props; linked units ignored by default)
    Policy (per user spec):
      • If MasterPropId (XML) is empty  → this record is the INVENTORY MASTER → INSERT into props.
      • If MasterPropId is present      → this record is a linked unit        → IGNORE (or write to subProps if desired).
      • Do NOT fan-out here.
    """

    WRITE_LINKED_TO_SUBPROPS = False  # set True if you want to keep linked units in subProps for reference

    conn = sqlite3.connect(DB_FILE)
    cur = conn.cursor()

    def _scoped(preview_id: str, raw_id: str | None) -> str | None:
        raw_id = (raw_id or "").strip()
        if not raw_id:
            return None
        return raw_id if ":" in raw_id else f"{preview_id}:{raw_id}"

    # Pass 0: collect NONE records
    # We’ll detect duplicate masters per DisplayName to avoid ambiguous inventory.
    masters_by_display: dict[str, dict] = {}
    linked_rows: list[dict] = []
    seen_master_displaynames: dict[str, list[dict]] = {}

    for prop in root.findall(".//PropClass"):
        if (prop.get("DeviceType") or "").strip() != "None":
            continue

        comment = (prop.get("Comment") or "").strip()
        if not comment:
            continue
        if skip_display_names and comment in skip_display_names:
            continue

        rec = {
            "raw_id":              (prop.get("id") or "").strip(),
            "name":                prop.get("Name") or "",
            "comment":             comment,
            "max_ch":              safe_int(prop.get("MaxChannels"), 0),
            "parm1":               prop.get("Parm1"),
            "parm2":               prop.get("Parm2"),
            "parm3":               prop.get("Parm3"),
            "parm4":               prop.get("Parm4"),
            "parm5":               prop.get("Parm5"),
            "parm6":               prop.get("Parm6"),
            "parm7":               prop.get("Parm7"),
            "parm8":               prop.get("Parm8"),
            "bulb_shape":          prop.get("BulbShape"),
            "dimming_curve_name":  prop.get("DimmingCurveName"),
            "traditional_type":    prop.get("TraditionalType"),
            "traditional_colors":  prop.get("TraditionalColors"),
            "string_type":         prop.get("StringType"),
            "effect_bulb_size":    prop.get("EffectBulbSize"),
            "custom_bulb_color":   prop.get("CustomBulbColor"),
            "tag":                 prop.get("Tag"),
            "opacity":             prop.get("Opacity"),
            "preview_bulb_size":   prop.get("PreviewBulbSize"),
            "separate_ids":        prop.get("SeparateIds"),
            "start_location":      prop.get("StartLocation"),
            "legacy_method":       prop.get("LegacySequenceMethod"),
            "individual_ch":       prop.get("IndividualChannels"),
            "master_dimmable":     prop.get("MasterDimmable"),
            "master_raw":          (prop.get("MasterPropId") or prop.get("UseSameChannelAs") or "").strip(),
        }

        if rec["master_raw"] == "":  # MASTER
            # detect duplicate masters for same DisplayName
            lst = seen_master_displaynames.setdefault(comment, [])
            lst.append(rec)
        else:  # LINKED
            linked_rows.append(rec)

    # Guardrail: error if >1 master per DisplayName in this preview
    dup_masters = [dn for dn, lst in seen_master_displaynames.items() if len(lst) > 1]
    if dup_masters:
        print("[ERROR] Multiple MASTER inventory records for the same DisplayName within a single preview (DeviceType=None).")
        for dn in dup_masters:
            names = ", ".join((r["name"] or r["raw_id"] or "?") for r in seen_master_displaynames[dn])
            print(f"  - PreviewId={preview_id} DisplayName='{dn}' has {len(seen_master_displaynames[dn])} masters: {names}")
        raise SystemExit(2)

    # Build final maps
    for dn, lst in seen_master_displaynames.items():
        masters_by_display[dn] = lst[0]  # the only one (we just enforced uniqueness)

    # Pass 1: insert MASTERS to props
    for dn, m in masters_by_display.items():
        prop_id_scoped = _scoped(preview_id, m["raw_id"]) or f"{preview_id}:NONE"
        try:
            cur.execute("""
                INSERT INTO props (
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
                prop_id_scoped, m["name"], dn, "None",
                m["bulb_shape"], m["dimming_curve_name"], m["max_ch"],
                m["custom_bulb_color"], m["individual_ch"], m["legacy_method"],
                m["opacity"], m["master_dimmable"], m["preview_bulb_size"], m["separate_ids"], m["start_location"],
                m["string_type"], m["traditional_colors"], m["traditional_type"], m["effect_bulb_size"], m["tag"],
                m["parm1"], m["parm2"], m["parm3"], m["parm4"], m["parm5"], m["parm6"], m["parm7"], m["parm8"],
                safe_int(m["parm2"], 0), preview_id, None
            ))
        except sqlite3.IntegrityError as e:
            print(f"[ERROR] Duplicate PropID (None/MASTER): {prop_id_scoped} "
                  f"(PreviewId={preview_id}, Display='{dn}') -> {e}")
            raise

        if DEBUG:
            print(f"[NONE->MASTER] {prop_id_scoped}  name='{m['name']}'  display='{dn}'")

    # Pass 2: (optional) write LINKED units to subProps for reference; otherwise IGNORE
    if WRITE_LINKED_TO_SUBPROPS and linked_rows:
        # Pre-resolve master scoped ids by their DisplayName + raw master id
        master_scoped_by_raw = {
            masters_by_display[dn]["raw_id"]: _scoped(preview_id, masters_by_display[dn]["raw_id"]) or f"{preview_id}:NONE"
            for dn in masters_by_display
        }

        for r in linked_rows:
            # only write if this linked row references a known master for its DisplayName
            dn = r["comment"]
            master_rec = masters_by_display.get(dn)
            if not master_rec:
                # Linked references a display with no master in this preview → ignore silently (or log)
                if DEBUG:
                    print(f"[NONE->SKIP-LINK] raw_id='{r['raw_id']}' display='{dn}' (no master found in this preview)")
                continue

            # XML says "MasterPropId = PropID of the record that stands alone" → that is the master's raw_id
            # Be strict: ensure it matches the master we accepted for this display
            if r["master_raw"] != master_rec["raw_id"]:
                # Mismatch: linked points to a different raw master id than the accepted master for this display
                if DEBUG:
                    print(f"[NONE->SKIP-LINK] raw_id='{r['raw_id']}' display='{dn}' master_raw='{r['master_raw']}' "
                          f"!= expected '{master_rec['raw_id']}'")
                continue

            sub_scoped    = _scoped(preview_id, r["raw_id"]) or f"{preview_id}:NONE"
            master_scoped = master_scoped_by_raw[master_rec["raw_id"]]

            try:
                cur.execute("""
                    INSERT INTO subProps (
                        SubPropID, MasterPropId,
                        Name, LORComment, DeviceType,
                        Parm1, Parm2, Parm3, Parm4, Parm5, Parm6, Parm7, Parm8,
                        PreviewId
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """, (
                    sub_scoped, master_scoped,
                    r["name"], dn, "None",
                    r["parm1"], r["parm2"], r["parm3"], r["parm4"],
                    r["parm5"], r["parm6"], r["parm7"], r["parm8"],
                    preview_id
                ))
            except sqlite3.IntegrityError as e:
                print(f"[ERROR] Duplicate SubPropID (None/LINK): {sub_scoped} "
                      f"(Master={master_scoped}, Display='{dn}') -> {e}")
                raise

            if DEBUG:
                print(f"[NONE->SUB] {sub_scoped}  name='{r['name']}'  display='{dn}'  master='{master_scoped}'")

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

        # GAL 25-10-16: Comment→DisplayName hygiene should match lor_core.validate_display_name()
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
        # GAL 25-10-22: use collision-aware insert (no silent overwrite)
        insert_sql = """
            INSERT INTO props (
                PropID, Name, LORComment, DeviceType, BulbShape, DimmingCurveName,
                MaxChannels, CustomBulbColor, IndividualChannels, LegacySequenceMethod,
                Opacity, MasterDimmable, PreviewBulbSize, SeparateIds, StartLocation,
                StringType, TraditionalColors, TraditionalType, EffectBulbSize, Tag,
                Parm1, Parm2, Parm3, Parm4, Parm5, Parm6, Parm7, Parm8, Lights, PreviewId
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """
        params = (
            master["PropID"], master["Name"], master["LORComment"], "DMX",
            master["BulbShape"], master["DimmingCurveName"], master["MaxChannels"],
            master["CustomBulbColor"], master["IndividualChannels"], master["LegacySequenceMethod"],
            master["Opacity"], master["MasterDimmable"], master["PreviewBulbSize"], master["SeparateIds"],
            master["StartLocation"], master["StringType"], master["TraditionalColors"], master["TraditionalType"],
            master["EffectBulbSize"], master["Tag"], master["Parm1"], master["Parm2"], master["Parm3"],
            master["Parm4"], master["Parm5"], master["Parm6"], master["Parm7"], master["Parm8"],
            master["Lights"], preview_id
        )
        incoming_ctx = {
            "PropID":       master.get("PropID"),
            "Name":         master.get("Name"),
            "LORComment":   comment,
            "PreviewId":    preview_id,
            "DeviceType":   "DMX",
            # DMX master insert usually has no Network/UID/Channels at this point;
            # include if present in your master dict (harmless if missing):
            "Network":      master.get("Network", ""),
            "UID":          master.get("UID", ""),
            "StartChannel": master.get("StartChannel", ""),
            "EndChannel":   master.get("EndChannel", ""),
        }
        ok = safe_insert_prop(cur, insert_sql, params, incoming_ctx)
        if DEBUG:
            if ok:
                print(f"[DEBUG] (DMX) master → props INSERT: {master['PropID']}  Display='{comment}'")
            else:
                print(f"[DEBUG] (DMX) master → props SKIP (collision/error): {master['PropID']}  Display='{comment}'")


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
            # Process_LOR_Props PASS 0: SPARE rows (single-grid) -> props as-is
            # GAL 25-10-22: collision-aware insert (no silent overwrite)
            insert_sql = """
                INSERT INTO props (
                    PropID, Name, LORComment, DeviceType, BulbShape, DimmingCurveName, MaxChannels,
                    CustomBulbColor, IndividualChannels, LegacySequenceMethod, Opacity, MasterDimmable,
                    PreviewBulbSize, SeparateIds, StartLocation, StringType, TraditionalColors, TraditionalType,
                    EffectBulbSize, Tag, Parm1, Parm2, Parm3, Parm4, Parm5, Parm6, Parm7, Parm8, Lights,
                    Network, UID, StartChannel, EndChannel, Unknown, Color, PreviewId
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """
            params = (
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
            )
            incoming_ctx = {
                "PropID":       prop_id_scoped,
                "Name":         name,
                "LORComment":   prop.get("Comment", ""),
                "PreviewId":    preview_id,
                "DeviceType":   "LOR",
                "Network":      grid.get("Network", ""),
                "UID":          grid.get("UID", ""),
                "StartChannel": grid.get("StartChannel", ""),
                "EndChannel":   grid.get("EndChannel", ""),
            }
            ok = safe_insert_prop(cursor, insert_sql, params, incoming_ctx)
            if DEBUG:
                if ok:
                    print(f"[DEBUG] (LOR single) SPARE -> props INSERT: {prop_id_scoped} '{name}'")
                else:
                    print(f"[DEBUG] (LOR single) SPARE -> props SKIP (collision/error): {prop_id_scoped} '{name}'")


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
        # Process_LOR_Props PASS 0B: MANUAL SUBPROPS (MasterPropId set)
        # GAL 25-10-22: collision-aware insert (no silent overwrite)
        insert_sql = """
            INSERT INTO subProps (
                SubPropID, Name, LORComment, DeviceType, BulbShape, Network, UID, StartChannel,
                EndChannel, Unknown, Color, CustomBulbColor, DimmingCurveName, IndividualChannels,
                LegacySequenceMethod, MaxChannels, Opacity, MasterDimmable, PreviewBulbSize, RgbOrder,
                MasterPropId, SeparateIds, StartLocation, StringType, TraditionalColors, TraditionalType,
                EffectBulbSize, Tag, Parm1, Parm2, Parm3, Parm4, Parm5, Parm6, Parm7, Parm8, Lights, PreviewId
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """
        params = (
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
        )
        incoming_ctx = {
            "SubPropID":    sub_id_scoped,
            "Name":         sp.get("Name",""),
            "LORComment":   sp.get("Comment",""),
            "PreviewId":    preview_id,
            "DeviceType":   "LOR",
            "Network":      g.get("Network",""),
            "UID":          g.get("UID",""),
            "StartChannel": g.get("StartChannel",""),
            "EndChannel":   g.get("EndChannel",""),
            "MasterPropId": master_id_scoped,
        }
        ok = safe_insert_subprop(cursor, insert_sql, params, incoming_ctx)
        if DEBUG:
            if ok:
                print(f"[DEBUG] (LOR manual subprop) INSERT: {sub_id_scoped}  Master='{master_id_scoped}'")
            else:
                print(f"[DEBUG] (LOR manual subprop) SKIP (collision/error): {sub_id_scoped}  Master='{master_id_scoped}'")


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



        # Insert new master  Pre-index non-manual, single-grid, non-spare rows by Display_Name
        # Insert new master  Pre-index non-manual, single-grid, non-spare rows by Display_Name
        # GAL 25-10-22: collision-aware insert (no silent overwrite)
        insert_sql = """
            INSERT INTO props (
                PropID, Name, LORComment, DeviceType, BulbShape, DimmingCurveName, MaxChannels,
                CustomBulbColor, IndividualChannels, LegacySequenceMethod, Opacity, MasterDimmable,
                PreviewBulbSize, SeparateIds, StartLocation, StringType, TraditionalColors, TraditionalType,
                EffectBulbSize, Tag, Parm1, Parm2, Parm3, Parm4, Parm5, Parm6, Parm7, Parm8, Lights,
                Network, UID, StartChannel, EndChannel, Unknown, Color, PreviewId
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """
        params = (
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
        )
        incoming_ctx = {
            "PropID":       new_master_id,
            "Name":         new_master.get("Name",""),
            "LORComment":   new_comment,
            "PreviewId":    preview_id,
            "DeviceType":   "LOR",
            "Network":      g_master.get("Network",""),
            "UID":          g_master.get("UID",""),
            "StartChannel": g_master.get("StartChannel",""),
            "EndChannel":   g_master.get("EndChannel",""),
        }
        ok = safe_insert_prop(cursor, insert_sql, params, incoming_ctx)
        if DEBUG:
            if ok:
                print(f"[DEBUG] (LOR master new) -> props INSERT: {new_master_id}  Display='{new_comment}'")
            else:
                print(f"[DEBUG] (LOR master new) -> props SKIP (collision/error): {new_master_id}  Display='{new_comment}'")

        # Everyone else in the group -> subProps under new master
        # Everyone else in the group -> subProps under new master
        for node in full_group:
            if node is new_master:
                continue
            g = grid_or(node)
            sub_id = scoped_id(preview_id, node.get("id") or "")

            # GAL 25-10-22: collision-aware insert (no silent overwrite)
            insert_sql = """
                INSERT INTO subProps (
                    SubPropID, Name, LORComment, DeviceType, BulbShape, Network, UID, StartChannel,
                    EndChannel, Unknown, Color, CustomBulbColor, DimmingCurveName, IndividualChannels,
                    LegacySequenceMethod, MaxChannels, Opacity, MasterDimmable, PreviewBulbSize, RgbOrder,
                    MasterPropId, SeparateIds, StartLocation, StringType, TraditionalColors, TraditionalType,
                    EffectBulbSize, Tag, Parm1, Parm2, Parm3, Parm4, Parm5, Parm6, Parm7, Parm8, Lights, PreviewId
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """
            params = (
                sub_id, node.get("Name",""), new_comment, "LOR", node.get("BulbShape"),
                g["Network"], g["UID"], g["StartChannel"], g["EndChannel"], g["Unknown"], g["Color"],
                node.get("CustomBulbColor"), node.get("DimmingCurveName"), node.get("IndividualChannels"),
                node.get("LegacySequenceMethod"), node.get("MaxChannels"), node.get("Opacity"), node.get("MasterDimmable"),
                node.get("PreviewBulbSize"), None,
                new_master_id, node.get("SeparateIds"), node.get("StartLocation"), node.get("StringType"),
                node.get("TraditionalColors"), node.get("TraditionalType"), node.get("EffectBulbSize"),
                node.get("Tag"), node.get("Parm1"), node.get("Parm2"), node.get("Parm3"), node.get("Parm4"), node.get("Parm5"),
                node.get("Parm6"), node.get("Parm7"), node.get("Parm8"),
                int(node.get("Parm2")) if (node.get("Parm2") and str(node.get("Parm2")).isdigit()) else 0,
                preview_id
            )
            incoming_ctx = {
                "SubPropID":    sub_id,
                "Name":         node.get("Name",""),
                "LORComment":   new_comment,
                "PreviewId":    preview_id,
                "DeviceType":   "LOR",
                "Network":      g.get("Network",""),
                "UID":          g.get("UID",""),
                "StartChannel": g.get("StartChannel",""),
                "EndChannel":   g.get("EndChannel",""),
                "MasterPropId": new_master_id,
            }
            ok = safe_insert_subprop(cursor, insert_sql, params, incoming_ctx)
            if DEBUG:
                if ok:
                    print(f"[DEBUG] (LOR group sub) -> subProps INSERT: {sub_id}  Master='{new_master_id}' Display='{new_comment}'")
                else:
                    print(f"[DEBUG] (LOR group sub) -> subProps SKIP (collision/error): {sub_id}  Master='{new_master_id}' Display='{new_comment}'")

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
        # GAL 25-10-22: collision-aware insert (no silent overwrite)
        insert_sql = """
            INSERT INTO props (
                PropID, Name, LORComment, DeviceType, BulbShape, DimmingCurveName, MaxChannels,
                CustomBulbColor, IndividualChannels, LegacySequenceMethod, Opacity, MasterDimmable,
                PreviewBulbSize, SeparateIds, StartLocation, StringType, TraditionalColors, TraditionalType,
                EffectBulbSize, Tag, Parm1, Parm2, Parm3, Parm4, Parm5, Parm6, Parm7, Parm8, Lights,
                Network, UID, StartChannel, EndChannel, Unknown, Color, PreviewId
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """
        params = (
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
        )
        incoming_ctx = {
            "PropID":       master_id,
            "Name":         master.get("Name",""),
            "LORComment":   display_name,
            "PreviewId":    master.get("PreviewId"),
            "DeviceType":   master.get("DeviceType",""),
            "Network":      (m_grid or {}).get("Network",""),
            "UID":          (m_grid or {}).get("UID",""),
            "StartChannel": (m_grid or {}).get("StartChannel",""),
            "EndChannel":   (m_grid or {}).get("EndChannel",""),
        }
        ok = safe_insert_prop(cursor, insert_sql, params, incoming_ctx)
        if DEBUG:
            if ok:
                print(f"[DEBUG] (LOR single) MASTER -> props INSERT: {master_id} '{display_name}' Start={m_grid['StartChannel']}")
            else:
                print(f"[DEBUG] (LOR single) MASTER -> props SKIP (collision/error): {master_id} '{display_name}' Start={m_grid['StartChannel']}")


        # REMAINING -> subProps
        # REMAINING -> subProps
        for rec in group:
            if rec["PropID_scoped"] == master_id:
                continue
            g = rec["Grid"] or {"Network":None,"UID":None,"StartChannel":None,"EndChannel":None,"Unknown":None,"Color":None}
            sub_id = scoped_id(preview_id, rec["PropID_raw"])

            # GAL 25-10-22: collision-aware insert (no silent overwrite)
            insert_sql = """
                INSERT INTO subProps (
                    SubPropID, Name, LORComment, DeviceType, BulbShape, Network, UID, StartChannel,
                    EndChannel, Unknown, Color, CustomBulbColor, DimmingCurveName, IndividualChannels,
                    LegacySequenceMethod, MaxChannels, Opacity, MasterDimmable, PreviewBulbSize, RgbOrder,
                    MasterPropId, SeparateIds, StartLocation, StringType, TraditionalColors, TraditionalType,
                    EffectBulbSize, Tag, Parm1, Parm2, Parm3, Parm4, Parm5, Parm6, Parm7, Parm8, Lights, PreviewId
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """
            params = (
                sub_id, rec["Name"], rec["LORComment"], rec["DeviceType"], rec["BulbShape"],
                g["Network"], g["UID"], g["StartChannel"], g["EndChannel"], g["Unknown"], g["Color"],
                rec["CustomBulbColor"], rec["DimmingCurveName"], rec["IndividualChannels"], rec["LegacySequenceMethod"],
                rec["MaxChannels"], rec["Opacity"], rec["MasterDimmable"], rec["PreviewBulbSize"], None,
                master_id, rec["SeparateIds"], rec["StartLocation"], rec["StringType"], rec["TraditionalColors"],
                rec["TraditionalType"], rec["EffectBulbSize"], rec["Tag"], rec["Parm1"], rec["Parm2"], rec["Parm3"],
                rec["Parm4"], rec["Parm5"], rec["Parm6"], rec["Parm7"], rec["Parm8"], rec["Lights"], rec["PreviewId"]
            )
            incoming_ctx = {
                "SubPropID":    sub_id,
                "Name":         rec.get("Name",""),
                "LORComment":   rec.get("LORComment",""),
                "PreviewId":    rec.get("PreviewId"),
                "DeviceType":   rec.get("DeviceType",""),
                "Network":      (g or {}).get("Network",""),
                "UID":          (g or {}).get("UID",""),
                "StartChannel": (g or {}).get("StartChannel",""),
                "EndChannel":   (g or {}).get("EndChannel",""),
                "MasterPropId": master_id,
            }
            ok = safe_insert_subprop(cursor, insert_sql, params, incoming_ctx)
            if DEBUG:
                if ok:
                    print(f"[DEBUG] (LOR single) AUTO -> subProps INSERT: parent={master_id} sub={sub_id} Start={g['StartChannel']}")
                else:
                    print(f"[DEBUG] (LOR single) AUTO -> subProps SKIP (collision/error): parent={master_id} sub={sub_id} Start={g['StartChannel']}")


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

        # GAL 25-10-16: Comment→DisplayName hygiene should match lor_core.validate_display_name()
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
        # Handle a single LOR PropClass that contains MULTIPLE ChannelGrid groups (";"-separated).
        # Keep the original prop as the master; materialize each grid group as its own subProp
        # GAL 25-10-22: collision-aware insert (no silent overwrite)
        insert_sql = """
            INSERT INTO props (
                PropID, Name, LORComment, DeviceType, BulbShape, DimmingCurveName, MaxChannels,
                CustomBulbColor, IndividualChannels, LegacySequenceMethod, Opacity, MasterDimmable,
                PreviewBulbSize, SeparateIds, StartLocation, StringType, TraditionalColors, TraditionalType,
                EffectBulbSize, Tag, Parm1, Parm2, Parm3, Parm4, Parm5, Parm6, Parm7, Parm8, Lights,
                Network, UID, StartChannel, EndChannel, Unknown, Color, PreviewId
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """
        # props_row already matches the column order above
        params = props_row

        # Build a minimal context for clear collision messages
        name_for_ctx = ""
        try:
            if isinstance(props_row, (list, tuple)) and len(props_row) > 1:
                name_for_ctx = props_row[1] or ""
        except Exception:
            pass
        incoming_ctx = {
            "PropID":       master_id,
            "Name":         name_for_ctx,
            "LORComment":   comment,
            "PreviewId":    preview_id,
            "DeviceType":   "LOR",
            "Network":      (m_grid or {}).get("Network", ""),
            "UID":          (m_grid or {}).get("UID", ""),
            "StartChannel": (m_grid or {}).get("StartChannel", ""),
            "EndChannel":   (m_grid or {}).get("EndChannel", ""),
        }

        ok = safe_insert_prop(cursor, insert_sql, params, incoming_ctx)
        if DEBUG:
            if ok:
                print(f"[DEBUG] (LOR multi) MASTER → props INSERT id={master_id}  comment={comment}  start={m_grid['StartChannel']} uid={m_grid['UID']}")
            else:
                print(f"[DEBUG] (LOR multi) MASTER → props SKIP (collision/error) id={master_id}  comment={comment}  start={m_grid['StartChannel']} uid={m_grid['UID']}")

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
            # Insert master into props (WITH full network/channel fields)
            # Keep the original prop as the master; materialize each grid group as its own subProp
            # GAL 25-10-22: collision-aware insert (no silent overwrite)
            insert_sql = """
                INSERT INTO subProps (
                    SubPropID, Name, LORComment, DeviceType, BulbShape, Network, UID, StartChannel,
                    EndChannel, Unknown, Color, CustomBulbColor, DimmingCurveName, IndividualChannels,
                    LegacySequenceMethod, MaxChannels, Opacity, MasterDimmable, PreviewBulbSize, RgbOrder,
                    MasterPropId, SeparateIds, StartLocation, StringType, TraditionalColors, TraditionalType,
                    EffectBulbSize, Tag, Parm1, Parm2, Parm3, Parm4, Parm5, Parm6, Parm7, Parm8, Lights, PreviewId
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """
            params = (
                sub_id, sub_name, comment, "LOR", d["BulbShape"],
                g["Network"], uid, g["StartChannel"], g["EndChannel"], g["Unknown"], g["Color"],
                d["CustomBulbColor"], d["DimmingCurveName"], d["IndividualChannels"], d["LegacySequenceMethod"],
                d["MaxChannels"], d["Opacity"], d["MasterDimmable"], d["PreviewBulbSize"], None,  # RgbOrder=NULL
                master_id, d["SeparateIds"], d["StartLocation"], d["StringType"], d["TraditionalColors"],
                d["TraditionalType"], d["EffectBulbSize"], d["Tag"], d["Parm1"], d["Parm2"], d["Parm3"],
                d["Parm4"], d["Parm5"], d["Parm6"], d["Parm7"], d["Parm8"], d["Lights"], preview_id
            )
            incoming_ctx = {
                "SubPropID":    sub_id,
                "Name":         sub_name,
                "LORComment":   comment,
                "PreviewId":    preview_id,
                "DeviceType":   "LOR",
                "Network":      g.get("Network",""),
                "UID":          uid,
                "StartChannel": g.get("StartChannel",""),
                "EndChannel":   g.get("EndChannel",""),
                "MasterPropId": master_id,
            }

            ok = safe_insert_subprop(cursor, insert_sql, params, incoming_ctx)
            if DEBUG:
                if ok:
                    print(f"[DEBUG] (LOR multi) SUB  → subProps INSERT id={sub_id}  parent={master_id}  start={g['StartChannel']} uid={uid}")
                else:
                    print(f"[DEBUG] (LOR multi) SUB  → subProps SKIP (collision/error) id={sub_id}  parent={master_id}  start={g['StartChannel']} uid={uid}")

    conn.commit()
    conn.close()




def process_file(file_path):
    """Process a single .lorprev file."""
    dprint(f"[DEBUG] Processing file: {file_path}")  # quieter unless DEBUG=True
    preview = locate_preview_class_deep(file_path)
    if preview is not None:
        preview_data = process_preview(preview)   # full dict dump is now gated by PREVIEW_DEBUG inside process_preview
        insert_preview_data(preview_data)

        # Parse and process DeviceType == None and DMX props
        tree = ET.parse(file_path)
        root = tree.getroot()

        # --- Count unique Displays (by PropClass/@Comment) for a concise summary ---
        display_names = set()
        for node in root.findall(".//PropClass"):
            c = (node.get("Comment") or "").strip()
            if c:
                display_names.add(c)

        # One concise INFO line per preview
        # INFO(
        #     f"Preview OK: Name='{preview_data.get('Name','')}', "
        #     f"StageID={preview_data.get('StageID')}, "
        #     f"Rev={preview_data.get('Revision')}, "
        #     f"Displays={len(display_names)}",
        #     ctx=preview_data.get('Name','')
        # )
        # One concise INFO line per preview
        log_preview_summary(preview_data, len(display_names))

        # Optional: show each display only when DEBUG=True
        if DEBUG:
            for dn in sorted(display_names, key=str.lower):
                dprint(f"    - {dn}")

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
        WARN(f"No <PreviewClass> found in {file_path}")


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

# --- GAL 25-10-23: Enforce global uniqueness of DisplayName across previews (masters only) ---
# --- GAL 25-10-23: Masters-only uniqueness audit with grouped console output ---
def audit_displayname_masters_unique_across_previews(
    db_path: str,
    out_csv_flat_name: str = "duplicate_display_names_masters.csv",
    out_csv_grouped_name: str = "duplicate_display_names_by_preview.csv",
) -> None:
    import sqlite3, csv
    from collections import defaultdict, Counter
    import os

    reports_dir = get_reports_dir()
    out_csv_flat = os.path.join(reports_dir, out_csv_flat_name)
    out_csv_grouped = os.path.join(reports_dir, out_csv_grouped_name)

    conn = sqlite3.connect(db_path)

    # 1) Find offending DisplayNames based on MASTERS-ONLY uniqueness rule
    q_masters = r"""
    WITH masters AS (
      SELECT
        p.PreviewId,
        pv.Name AS PreviewName,
        UPPER(TRIM(p.LORComment)) AS DisplayKey,
        p.PropID
      FROM props p
      JOIN previews pv ON pv.id = p.PreviewId
      WHERE TRIM(COALESCE(p.LORComment,'')) <> ''
        AND UPPER(p.LORComment) <> 'SPARE'
        AND p.MasterPropId IS NULL
    ),
    offenders AS (
      SELECT DisplayKey
      FROM masters
      GROUP BY DisplayKey
      HAVING COUNT(DISTINCT PreviewId) > 1
    )
    SELECT m.DisplayKey, m.PreviewId, m.PreviewName, m.PropID
    FROM masters m
    JOIN offenders o ON o.DisplayKey = m.DisplayKey
    ORDER BY m.DisplayKey, m.PreviewName;
    """
    masters_rows = conn.execute(q_masters).fetchall()

    if not masters_rows:
        print("[OK] All DisplayNames are unique across previews (masters only).")
        conn.close()
        return

    offender_keys = {r[0] for r in masters_rows}

    # Flat CSV of masters
    with open(out_csv_flat, "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(["DisplayName", "PreviewId", "PreviewName", "MasterPropID"])
        for display_key, preview_id, preview_name, prop_id in masters_rows:
            w.writerow([display_key, preview_id, preview_name, prop_id])

    # 3) Per-preview counts (for readable console + grouped CSV)
    q_canon = r"""
    WITH canon AS (
      SELECT p.PreviewId, pv.Name AS PreviewName,
             UPPER(TRIM(p.LORComment)) AS DisplayKey,
             'props' AS Source
      FROM props p
      JOIN previews pv ON pv.id = p.PreviewId
      WHERE TRIM(COALESCE(p.LORComment,'')) <> '' AND UPPER(p.LORComment) <> 'SPARE'
      UNION ALL
      SELECT sp.PreviewId, pv.Name AS PreviewName,
             UPPER(TRIM(COALESCE(NULLIF(sp.LORComment,''), p.LORComment))) AS DisplayKey,
             'subProps' AS Source
      FROM subProps sp
      JOIN props p  ON p.PropID = sp.MasterPropId
      JOIN previews pv ON pv.id = sp.PreviewId
      WHERE TRIM(COALESCE(COALESCE(NULLIF(sp.LORComment,''), p.LORComment),'')) <> ''
        AND UPPER(COALESCE(NULLIF(sp.LORComment,''), p.LORComment)) <> 'SPARE'
    )
    SELECT DisplayKey, PreviewName, Source, COUNT(*) AS N
    FROM canon
    WHERE DisplayKey IN ({placeholders})
    GROUP BY DisplayKey, PreviewName, Source
    ORDER BY DisplayKey, PreviewName, Source;
    """.format(placeholders=",".join("?" for _ in offender_keys))

    canon_rows = conn.execute(q_canon, tuple(sorted(offender_keys))).fetchall()
    conn.close()

    grouped = defaultdict(lambda: defaultdict(Counter))
    for display_key, preview_name, source, n in canon_rows:
        grouped[display_key][preview_name][source] += n

    # Grouped CSV
    with open(out_csv_grouped, "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(["DisplayName", "PreviewName", "props_count", "subProps_count"])
        for dk in sorted(grouped):
            for pn in sorted(grouped[dk]):
                c = grouped[dk][pn]
                w.writerow([dk, pn, c.get("props", 0), c.get("subProps", 0)])

    print("\n[ERROR] Duplicate DisplayName(s) found across previews (masters-only rule):")
    for dk in sorted(grouped):
        bits = []
        for pn in sorted(grouped[dk]):
            c = grouped[dk][pn]
            parts = []
            if c.get("props"):    parts.append(f"props:{c['props']}")
            if c.get("subProps"): parts.append(f"subProps:{c['subProps']}")
            bits.append(f"{pn} ({', '.join(parts)})" if parts else pn)
        print(f"  - {dk}  →  " + " | ".join(bits))

    print(f"[ERROR] See details: {out_csv_flat}")
    print(f"[ERROR] Grouped by preview: {out_csv_grouped}")
    raise SystemExit(2)


def main():
    """Main entry point for the script."""
    require_g()  # fail fast if G:\ isn’t mounted

    global DB_FILE, PREVIEW_PATH  # keep other functions happy

    # Prompt, but default always to G:\ paths
    db_in = input(f"Enter database path [{DEFAULT_DB_FILE}]: ").strip()
    prev_in = input(f"Enter the folder path containing .lorprev files [{DEFAULT_PREVIEW_PATH}]: ").strip()

    DB_FILE = Path(db_in) if db_in else DEFAULT_DB_FILE
    PREVIEW_PATH = Path(prev_in) if prev_in else DEFAULT_PREVIEW_PATH

    # Enforce both on G:\
    def _is_on_g(p: Path) -> bool:
        drv = getattr(p, "drive", "")
        return (drv.upper() == "G:") or str(p)[:2].upper() == "G:"

    for label, p in [("DB_FILE", DB_FILE), ("PREVIEW_PATH", PREVIEW_PATH)]:
        if not _is_on_g(p):
            print(f"[FATAL] {label} must be on G:\\ — got: {p}")
            sys.exit(2)

    print(f"[INFO] Using database: {DB_FILE}")
    print(f"[INFO] Using preview folder: {PREVIEW_PATH}")

    if not PREVIEW_PATH.is_dir():
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

    # 🚨 Fail-fast audit: a DisplayName can be mastered in ONLY one preview
    audit_displayname_masters_unique_across_previews(DB_FILE)

    # # 🚨 Fail-fast audits (write CSV + exit non-zero if problems)
    # audit_duplicate_display_names(DB_FILE)   # required
    # # audit_prop_id_crosspreview(DB_FILE)    # optional but recommended during transition

    print("Processing complete. Check the database.")


    # -----------------------------------------------------------------------------
    # GAL 25-10-22: End-of-run reporting (collision CSVs + notice)
    # We open a short-lived connection here just to resolve preview names in reports.
    # -----------------------------------------------------------------------------
    try:
        _conn = sqlite3.connect(DB_FILE)
        _cursor = _conn.cursor()
        try:
            write_propid_collisions_csv(_cursor)
        except Exception as _e:
            WARN(f"Unable to write PropID collision CSV: {_e}")
        try:
            write_subprop_collisions_csv(_cursor)
        except Exception as _e:
            WARN(f"Unable to write SubPropID collision CSV: {_e}")
    finally:
        try:
            _conn.close()
        except Exception:
            pass

    # === Notice breadcrumb (FILE ONLY; no webhook required) ===
    try:
        actor = _who_ran()
        text = _notice_text(PREVIEW_PATH, DB_FILE, actor=actor)  # pass actor for clarity
        notice_path = write_notice_file(PREVIEW_PATH, text)
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

    ddl = """
DROP VIEW IF EXISTS preview_wiring_map_v6;
CREATE VIEW preview_wiring_map_v6 AS
    -- Master props (single-grid legs on props)
    SELECT
        pv.Name             AS PreviewName,
        REPLACE(TRIM(p.LORComment), ' ', '-') AS DisplayName,
        p.Name              AS LORName,
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
    SELECT
        pv.Name,
        REPLACE(TRIM(COALESCE(NULLIF(sp.LORComment,''), p.LORComment)), ' ', '-') AS DisplayName,
        sp.Name              AS LORName,  -- ✅ subprop’s own channel name
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
    SELECT
        pv.Name,
        REPLACE(TRIM(p.LORComment), ' ', '-') AS DisplayName,
        p.Name              AS LORName,
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
  PreviewName, DisplayName, LORName, Network, Controller,
  StartChannel, EndChannel, DeviceType, Source, LORTag
FROM preview_wiring_map_v6
ORDER BY
  PreviewName  COLLATE NOCASE ASC,
  DisplayName  COLLATE NOCASE ASC,
  Controller   ASC,
  StartChannel ASC;

CREATE INDEX IF NOT EXISTS idx_props_preview     ON props(PreviewId);
CREATE INDEX IF NOT EXISTS idx_subprops_preview  ON subProps(PreviewId);
CREATE INDEX IF NOT EXISTS idx_dmx_prop          ON dmxChannels(PropId);
"""

    fieldmap = r"""
DROP VIEW IF EXISTS preview_wiring_fieldmap_v6;
CREATE VIEW preview_wiring_fieldmap_v6 AS
WITH map AS (
  SELECT
    m.Source,
    m.LORName            AS Channel_Name,
    m.DisplayName        AS Display_Name,
    m.Network,
    m.Controller,
    m.StartChannel,
    m.EndChannel,
    CASE WHEN m.DeviceType='DMX' THEN 'RGB' ELSE NULL END AS Color,
    m.DeviceType         AS DeviceType,
    m.LORTag,
    m.PreviewName
  FROM preview_wiring_sorted_v6 m
  WHERE m.Controller IS NOT NULL
    AND m.StartChannel IS NOT NULL
    AND m.DeviceType <> 'None'
),
ranked AS (
  SELECT
    map.*,
    ROW_NUMBER() OVER (
      PARTITION BY PreviewName, Network, Controller, StartChannel, Display_Name
      ORDER BY (Source='PROP') DESC, Channel_Name COLLATE NOCASE
    ) AS lead_rank
  FROM map
),
span AS (
  SELECT
    ranked.*,
    SUM(CASE WHEN lead_rank = 1 THEN 1 ELSE 0 END)
      OVER (PARTITION BY PreviewName, Network, Controller, StartChannel) AS display_span
  FROM ranked
)
SELECT
  PreviewName, Source, Channel_Name, Display_Name,
  Network, Controller, StartChannel, EndChannel, Color, DeviceType, LORTag,
  CASE WHEN lead_rank = 1 THEN 'FIELD' ELSE 'INTERNAL' END AS ConnectionType,
  CASE WHEN display_span > 1 THEN 1 ELSE 0 END            AS CrossDisplay
FROM span;

DROP VIEW IF EXISTS preview_wiring_fieldonly_v6;
CREATE VIEW preview_wiring_fieldonly_v6 AS
SELECT *
FROM preview_wiring_fieldmap_v6
WHERE ConnectionType = 'FIELD';


--------------------------------------------------------------------
-- FIELD WIRING HELPERS (Stage/Preview-focused)
-- Paste this block AFTER preview_wiring_map_v6 / preview_wiring_sorted_v6 are created
--------------------------------------------------------------------

-- Field/Internal mapping without COUNT(DISTINCT) window functions
DROP VIEW IF EXISTS preview_wiring_fieldmap_v6;
CREATE VIEW preview_wiring_fieldmap_v6 AS
WITH map AS (
  SELECT
    m.PreviewName,
    m.Source,
    m.LORName            AS Channel_Name,
    m.DisplayName        AS Display_Name,
    m.Network,
    m.Controller,
    m.StartChannel,
    m.EndChannel,
    CASE WHEN m.DeviceType='DMX' THEN 'RGB' ELSE NULL END AS Color,
    m.DeviceType         AS DeviceType,
    m.LORTag
  FROM preview_wiring_sorted_v6 m
  WHERE m.Controller IS NOT NULL
    AND m.StartChannel IS NOT NULL
    AND m.DeviceType <> 'None'
),
ranked AS (
  SELECT
    map.*,
    ROW_NUMBER() OVER (
      PARTITION BY PreviewName, Network, Controller, StartChannel, Display_Name
      ORDER BY (Source='PROP') DESC, Channel_Name COLLATE NOCASE
    ) AS lead_rank
  FROM map
),
span AS (
  SELECT
    ranked.*,
    SUM(CASE WHEN lead_rank = 1 THEN 1 ELSE 0 END)
      OVER (PARTITION BY PreviewName, Network, Controller, StartChannel) AS display_span
  FROM ranked
)
SELECT
  PreviewName, Source, Channel_Name, Display_Name,
  Network, Controller, StartChannel, EndChannel, Color, DeviceType, LORTag,
  CASE WHEN lead_rank = 1 THEN 'FIELD' ELSE 'INTERNAL' END AS ConnectionType,
  CASE WHEN display_span > 1 THEN 1 ELSE 0 END            AS CrossDisplay
FROM span;

-- Exactly one lead row per display per circuit (what to wire in the field)
DROP VIEW IF EXISTS preview_wiring_fieldlead_v6;
CREATE VIEW preview_wiring_fieldlead_v6 AS
WITH ranked AS (
  SELECT
    f.*,
    ROW_NUMBER() OVER (
      PARTITION BY f.PreviewName, f.Network, f.Controller, f.StartChannel, f.Display_Name
      ORDER BY (f.Source='PROP') DESC, f.Channel_Name COLLATE NOCASE
    ) AS lead_rank
  FROM preview_wiring_fieldmap_v6 f
)
SELECT *
FROM ranked
WHERE lead_rank = 1;

-- Per-circuit rollup for auditing shared circuits
DROP VIEW IF EXISTS preview_wiring_circuit_rollup_v6;
CREATE VIEW preview_wiring_circuit_rollup_v6 AS
SELECT
  PreviewName,
  Network,
  Controller,
  StartChannel,
  COUNT(*) AS display_count,
  GROUP_CONCAT(Display_Name, ' | ') AS displays
FROM preview_wiring_fieldlead_v6
GROUP BY PreviewName, Network, Controller, StartChannel
ORDER BY Network, CAST(Controller AS INTEGER), StartChannel;

-- Convenience slice: field-only rows for a given stage/preview
DROP VIEW IF EXISTS preview_wiring_fieldonly_v6;
CREATE VIEW preview_wiring_fieldonly_v6 AS
SELECT *
FROM preview_wiring_fieldmap_v6
WHERE ConnectionType = 'FIELD';
"""

    conn = sqlite3.connect(db_file)
    try:
        conn.executescript(ddl)
        conn.executescript(fieldmap)
        conn.commit()
        print("[INFO] Created preview_wiring_map_v6, preview_wiring_sorted_v6, and FIELD/INTERNAL views.")
    finally:
        conn.close()

    conn = sqlite3.connect(db_file)
    try:
        conn.executescript(ddl)
        conn.commit()
        print("[INFO] Created wiring views + helpers (props slice, controller_networks_v6, breaking_check_v6).")
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


    # def create_breaking_check_view(conn):
    #     ddl = """
    #     DROP VIEW IF EXISTS breaking_check_v6;
    #     CREATE VIEW breaking_check_v6 AS
    #     SELECT
    #         m.RawPropID,
    #         m.ChannelName   AS ChannelName_2024,
    #         m.DisplayName   AS DisplayName_2024,
    #         p.Name          AS ChannelName_Now,
    #         p.LORComment    AS DisplayName_Now,
    #         CASE WHEN p.PropID IS NULL THEN 1 ELSE 0 END AS Missing_Now,
    #         CASE WHEN p.PropID IS NOT NULL
    #             AND m.ChannelName != IFNULL(p.Name,'') THEN 1 ELSE 0 END AS ChannelName_Changed,
    #         CASE WHEN p.PropID IS NOT NULL
    #             AND m.DisplayName != IFNULL(p.LORComment,'') THEN 1 ELSE 0 END AS DisplayName_Changed
    #     FROM master_musical_prev_keys m
    #     LEFT JOIN props p ON p.PropID = m.RawPropID;
    #     """
    #     conn.executescript(ddl)
    #     conn.commit()
    #     print("[INFO] Created breaking_check_v6 view")

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

# --- GAL 25-10-23: Duplicate DisplayName audit across previews ---
def audit_duplicate_display_names(db_path: str, out_csv: str = "duplicate_display_names.csv") -> None:
    """
    Error if any 'DisplayName' (dashified LORComment) appears in >1 preview.
    Writes a CSV with all collisions for triage, then exits non-zero.
    """
    import sqlite3, csv
    q = r"""
    WITH canon AS (
      -- props (use raw p.LORComment; dashify only for display)
      SELECT
        p.PreviewId,
        pv.Name AS PreviewName,
        UPPER(TRIM(p.LORComment)) AS DisplayKey,
        'props' AS Source,
        COALESCE(p.DeviceType,'') AS DeviceType,
        p.PropID AS ItemID
      FROM props p
      JOIN previews pv ON pv.id = p.PreviewId
      WHERE TRIM(COALESCE(p.LORComment,'')) <> '' AND UPPER(p.LORComment) <> 'SPARE'

      UNION ALL

      -- subProps (prefer sub comment when present)
      SELECT
        sp.PreviewId,
        pv.Name AS PreviewName,
        UPPER(TRIM(COALESCE(NULLIF(sp.LORComment,''), p.LORComment))) AS DisplayKey,
        'subProps' AS Source,
        COALESCE(sp.DeviceType,'') AS DeviceType,
        sp.SubPropID AS ItemID
      FROM subProps sp
      JOIN props p  ON p.PropID = sp.MasterPropId
      JOIN previews pv ON pv.id = sp.PreviewId
      WHERE TRIM(COALESCE(COALESCE(NULLIF(sp.LORComment,''), p.LORComment),'')) <> ''
        AND UPPER(COALESCE(NULLIF(sp.LORComment,''), p.LORComment)) <> 'SPARE'
    ),
    dups AS (
      SELECT DisplayKey
      FROM canon
      GROUP BY DisplayKey
      HAVING COUNT(DISTINCT PreviewId) > 1
    )
    SELECT c.DisplayKey, c.PreviewId, c.PreviewName, c.Source, c.DeviceType, c.ItemID
    FROM canon c
    JOIN dups d ON d.DisplayKey = c.DisplayKey
    ORDER BY c.DisplayKey, c.PreviewName, c.Source, c.ItemID;
    """
    conn = sqlite3.connect(db_path)
    rows = conn.execute(q).fetchall()
    conn.close()

    if not rows:
        print("[OK] No duplicate display names across previews.")
        return

    # write details for triage
    # --- Write flat detail CSV (existing behavior) ---
    with open(out_csv, "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(["DisplayName", "PreviewId", "PreviewName", "Source", "DeviceType", "ItemID"])
        for r in rows:
            w.writerow(r)

    # --- Also build a grouped-by-preview summary for console + CSV ---
    from collections import defaultdict, Counter

    by_key = defaultdict(list)  # DisplayName -> list of (PreviewName, Source)
    for display_key, _pid, preview_name, source, _dtype, _itemid in rows:
        by_key[display_key].append((preview_name, source))

    # Console output: each duplicate with its previews + counts by source
    print("\n[ERROR] Duplicate DisplayName(s) found across previews:")
    for display_key in sorted(by_key):
        entries = by_key[display_key]
        preview_counts = defaultdict(Counter)  # PreviewName -> Counter({props: n, subProps: n})
        for pn, src in entries:
            preview_counts[pn][src] += 1

        # Compose a readable per-duplicate line
        preview_bits = []
        for pn in sorted(preview_counts):
            c = preview_counts[pn]
            parts = []
            if c.get("props"):    parts.append(f"props:{c['props']}")
            if c.get("subProps"): parts.append(f"subProps:{c['subProps']}")
            preview_bits.append(f"{pn} ({', '.join(parts)})")
        print(f"  - {display_key}  →  " + " | ".join(preview_bits))

    # Grouped CSV for quick triage
    grouped_csv = out_csv.replace(".csv", "_by_preview.csv")
    with open(grouped_csv, "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(["DisplayName", "PreviewName", "props_count", "subProps_count"])
        for display_key in sorted(by_key):
            entries = by_key[display_key]
            preview_counts = defaultdict(Counter)
            for pn, src in entries:
                preview_counts[pn][src] += 1
            for pn in sorted(preview_counts):
                w.writerow([display_key, pn, preview_counts[pn].get("props", 0), preview_counts[pn].get("subProps", 0)])

    print(f"[ERROR] See details: {out_csv}")
    print(f"[ERROR] Grouped by preview: {grouped_csv}")
    raise SystemExit(2)



# --- GAL 25-10-23: Optional belt-and-suspenders audit (PropID cross-preview) ---
def audit_prop_id_crosspreview(db_path: str) -> None:
    """
    Should be empty if all PropIDs are properly preview-scoped.
    """
    import sqlite3
    q = """
    SELECT PropID, COUNT(DISTINCT PreviewId) AS previews
    FROM props
    GROUP BY PropID
    HAVING COUNT(DISTINCT PreviewId) > 1
    """
    conn = sqlite3.connect(db_path)
    rows = conn.execute(q).fetchall()
    conn.close()
    if rows:
        print("[ERROR] Unscoped PropID(s) exist across previews:")
        for pid, cnt in rows:
            print(f"  - {pid} in {cnt} previews")
        raise SystemExit(2)




if __name__ == "__main__":
    main()