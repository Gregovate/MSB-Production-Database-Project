# lor_core.py
# GAL 25-10-16: Introduce Core Model v1.0 shared helpers for merger/parser alignment
# - Adds deterministic signatures and resilient row keys
# - Documents LOR→DB field mapping (incl. Comment → DisplayName)
# - Centralizes Display Name (Comment) validation

"""
Core Model v1.0 — DB-facing field dictionary shared by preview_merger.py and parse_props_v6.py

LOR → DB naming map (key fields and user-visible labels)
- PreviewClass.id            → PreviewID           (key; Critical if drift)
- PreviewClass.Name          → PreviewName         (operator label; High)
- PreviewClass.BackgroundFile→ BackgroundFile      (QA only; Low)
- PropClass.id               → PropID              (key; Critical if drift)
- PropClass.Comment          → DisplayName         (a.k.a. "LOR Comment"; High)
- PropClass.Name             → ChannelName         (channel label; High)
- ChannelGrid.(Network, UID, StartChannel, EndChannel) → wiring core (Critical/High)
- DimmingCurveName           → DimmingCurveName    (Medium)
- DeviceType                 → DeviceType          (Critical if flip)
- DMX.(StartUniverse, StartChannel, EndChannel)    → DMX wiring core (Critical/High)

Comment / Display Name hygiene used across Author + Staging scans:
- must be present and non-blank
- no leading/trailing spaces
- no double spaces inside
(Extend here with any show-specific rules; "SPARE" exceptions, suffix patterns, etc.)
"""

from __future__ import annotations
from hashlib import sha256
import json
from typing import Dict, Tuple, Iterable, Optional
from pathlib import Path

# -----------------------------
# Canonical field sets (DB-facing)
# -----------------------------
# PREVIEWS table (parser persists these)
PREVIEW_FIELDS = [
    "PreviewID",        # <PreviewClass id>  (LOR key, stable unless re-created)
    "PreviewName",      # <PreviewClass Name>
    "BackgroundFile",   # <PreviewClass BackgroundFile> (QA only)
]

# LOR legs (ultimately rows that end up in props/subProps)
LOR_FIELDS = [
    "DisplayName",        # LOR Comment => props.DisplayName
    "ChannelName",        # LOR Name    => props.Name / subProps.Name
    "Network",
    "UID",                # controller hex id
    "StartChannel",
    "EndChannel",
    "DimmingCurveName",
    "DeviceType",         # expect "LOR" here; Critical if flips
]

# DMX legs (props + dmxChannels)
DMX_FIELDS = [
    "DisplayName",        # props.DisplayName
    "ChannelName",        # props.Name
    "Network",
    "StartUniverse",
    "StartChannel",
    "EndChannel",
    # DeviceType is "DMX" but not included in signature (we’ll flag flips separately)
]

# -----------------------------
# Normalization helpers
# -----------------------------
def _norm(value):
    # Make signatures stable across types/spacing
    if isinstance(value, str):
        return value.strip()
    return value

def _pick(d: Dict, keys: Iterable[str]) -> Dict:
    return {k: _norm(d.get(k)) for k in keys}

def _sha(obj: Dict) -> str:
    return sha256(json.dumps(obj, sort_keys=True, ensure_ascii=False).encode("utf-8")).hexdigest()

# -----------------------------
# Signatures (exclude revision; we report rev deltas separately)
# -----------------------------
def preview_signature(preview_row: Dict) -> str:
    return _sha(_pick(preview_row, PREVIEW_FIELDS))

def lor_leg_signature(row: Dict) -> str:
    return _sha(_pick(row, LOR_FIELDS))

def dmx_leg_signature(row: Dict) -> str:
    return _sha(_pick(row, DMX_FIELDS))

# -----------------------------
# Resilient row keys for “same leg”
# NOTE: include PreviewID to avoid cross-preview collisions.
# Prefer controller+start anchors instead of PropID (PropID can drift when re-created).
# -----------------------------
def lor_row_key(row: Dict) -> Tuple:
    return (
        _norm(row.get("PreviewID")),
        _norm(row.get("DisplayName")),
        _norm(row.get("UID")),
        _norm(row.get("StartChannel")),
    )

def dmx_row_key(row: Dict) -> Tuple:
    return (
        _norm(row.get("PreviewID")),
        _norm(row.get("DisplayName")),
        _norm(row.get("StartUniverse")),
        _norm(row.get("StartChannel")),
    )

# -----------------------------
# Device type flip detector (Critical)
# -----------------------------
def device_type_flip(old_type: Optional[str], new_type: Optional[str]) -> bool:
    o = (old_type or "").strip().lower()
    n = (new_type or "").strip().lower()
    if not o or not n:
        return False
    return o != n

# -----------------------------
# Display Name hygiene (used in Missing_Comments)
# Return (ok: bool, reason: str)
# -----------------------------
def validate_display_name(name: Optional[str]) -> Tuple[bool, str]:
    if name is None:
        return False, "missing"
    s = name.strip()
    if not s:
        return False, "blank"
    if s != name:
        return False, "leading_or_trailing_space"
    if "  " in s:
        return False, "double_spaces"
    # Add other project rules here (e.g., disallow trailing -XX unless valid)
    return True, "ok"

# -----------------------------
# Fine-grained field diff → categories
# Returns a set of category tags you can aggregate per row/preview:
#  - KeyChange, DisplayNameChange, WiringChange, SpanChange, LabelChange,
#    CurveChange, DeviceTypeChange, PreviewNameChange
# -----------------------------
def categorize_lor_change(old: Dict, new: Dict) -> set:
    cats = set()
    # Wiring
    if _norm(old.get("Network")) != _norm(new.get("Network")) \
       or _norm(old.get("UID")) != _norm(new.get("UID")) \
       or _norm(old.get("StartChannel")) != _norm(new.get("StartChannel")):
        cats.add("WiringChange")
    if _norm(old.get("EndChannel")) != _norm(new.get("EndChannel")):
        cats.add("SpanChange")
    # Labels
    if _norm(old.get("ChannelName")) != _norm(new.get("ChannelName")):
        cats.add("LabelChange")
    if _norm(old.get("DisplayName")) != _norm(new.get("DisplayName")):
        cats.add("DisplayNameChange")
    if _norm(old.get("DimmingCurveName")) != _norm(new.get("DimmingCurveName")):
        cats.add("CurveChange")
    if device_type_flip(old.get("DeviceType"), new.get("DeviceType")):
        cats.add("DeviceTypeChange")
    return cats

def categorize_dmx_change(old: Dict, new: Dict) -> set:
    cats = set()
    if _norm(old.get("Network")) != _norm(new.get("Network")) \
       or _norm(old.get("StartUniverse")) != _norm(new.get("StartUniverse")) \
       or _norm(old.get("StartChannel")) != _norm(new.get("StartChannel")):
        cats.add("WiringChange")
    if _norm(old.get("EndChannel")) != _norm(new.get("EndChannel")):
        cats.add("SpanChange")
    if _norm(old.get("ChannelName")) != _norm(new.get("ChannelName")):
        cats.add("LabelChange")
    if _norm(old.get("DisplayName")) != _norm(new.get("DisplayName")):
        cats.add("DisplayNameChange")
    return cats

# -----------------------------
# Preview-level diffs
# -----------------------------
def categorize_preview_change(old: Dict, new: Dict) -> set:
    cats = set()
    if _norm(old.get("PreviewName")) != _norm(new.get("PreviewName")):
        cats.add("PreviewNameChange")
    # BackgroundFile differences are low-priority; omit from categories, keep in notes if needed
    return cats

# -----------------------------
# Utility: “same wiring, new key” detector
# Use when you suspect PropID drift. If signatures equal but PropIDs differ → key change.
# -----------------------------
def is_key_change_same_core(old_row: Dict, new_row: Dict, device_type: str) -> bool:
    if device_type.lower() == "lor":
        return (old_row.get("PropID") != new_row.get("PropID")) and \
               (lor_leg_signature(old_row) == lor_leg_signature(new_row))
    if device_type.lower() == "dmx":
        return (old_row.get("PropID") != new_row.get("PropID")) and \
               (dmx_leg_signature(old_row) == dmx_leg_signature(new_row))
    return False

# ====================== GAL 25-10-18: Core comparison helper ======================



def core_different(file_a: Path, file_b: Path) -> bool:
    """
    Return True if two .lorprev files differ in their wiring/core fields.
    Ignores comments, revision, and minor metadata.

    Steps:
    - Each .lorprev is a JSON (or XML) file parsed upstream by parse_props_v6.py
    - We look at both LOR and DMX legs and preview-level changes
    """
    try:
        # assume each .lorprev can be loaded via json; adjust if it's XML later
        a = json.loads(file_a.read_text(encoding="utf-8"))
        b = json.loads(file_b.read_text(encoding="utf-8"))
    except Exception:
        # if unreadable, consider changed
        return True

    device_type = str(a.get("DeviceType") or b.get("DeviceType") or "").lower()
    if "dmx" in device_type:
        cats = categorize_dmx_change(a, b)
    else:
        cats = categorize_lor_change(a, b)
    cats |= categorize_preview_change(a, b)
    # any category at all means core difference
    return bool(cats)

# ====================== GAL 25-10-19: XML core extractor ======================
from pathlib import Path as _LCPath

def _lc_norm(s):
    return (s or "").strip()

def _lc_i(s, default=None):
    s = (s or "").strip()
    return int(s) if s.isdigit() else default

def _lc_parse_channel_grid(grid_text: str) -> list[tuple]:
    """
    Returns list of channel legs as tuples. Accepts both LOR and DMX layouts.
    LOR leg: ( "LOR", network, uid, start, end, color )
    DMX leg: ( "DMX", network, universe, start, end )
    """
    legs = []
    if not grid_text:
        return legs
    for seg in (p.strip() for p in grid_text.split(";") if p.strip()):
        parts = [p.strip() for p in seg.split(",")]
        if len(parts) >= 5:
            # Heuristic: DMX puts Universe in slot 2; LOR puts UID in slot 2.
            # We will let the caller decide which tuple shape to build.
            legs.append(parts)
    return legs

def core_items_from_lorprev(path: _LCPath) -> tuple[set[tuple], dict]:
    """
    Build a normalized 'core' set for a .lorprev.

    Rules (aligned with parse_props_v6) with multiplicity:
      - DeviceType None  → compare by (DisplayName=Comment, ChannelName=Name) WITH COUNTS.
      - LOR legs        → (LOR, Network, UID, Start, End, Color) WITH COUNTS.
      - DMX legs        → (DMX, Network, Universe, Start, End) WITH COUNTS.
    Plus label-health signals so fixes to blank labels trigger a stage:
      - For every PropClass, we record multiplicity markers for:
          ("LBLMISS", DeviceType, "COMMENT") when Comment is blank
          ("LBLMISS", DeviceType, "NAME")    when Name    is blank
    """
    import xml.etree.ElementTree as ET
    from collections import Counter

    stats = {
        "props_total": 0,
        "props_none": 0,
        "legs_lor": 0,
        "legs_dmx": 0,
        "missing_comment": 0,
        "missing_name": 0,
    }

    # Multiplicity-preserving buckets
    none_keys      = Counter()
    lor_keys       = Counter()
    dmx_keys       = Counter()
    fallback_keys  = Counter()
    # NEW: label-health counters (by device type)
    miss_comment   = Counter()
    miss_name      = Counter()

    root = ET.parse(str(path)).getroot()
    for node in root.findall(".//PropClass"):
        stats["props_total"] += 1

        dev = _lc_norm(node.get("DeviceType")).upper() or "NONE"
        display = _lc_norm(node.get("Comment")).lower()
        channel = _lc_norm(node.get("Name")).lower()

        # Track blank label health
        if not display:
            miss_comment[(dev, "COMMENT")] += 1
            stats["missing_comment"] += 1
        if not channel:
            miss_name[(dev, "NAME")] += 1
            stats["missing_name"] += 1

        if dev == "NONE":
            # DeviceType=None → aggregate by (comment, name)
            if display or channel:
                none_keys[("NONE", display, channel)] += 1
                stats["props_none"] += 1
            continue

        grid = _lc_norm(node.get("ChannelGrid"))
        if not grid:
            # No legs – keep a minimal, typed placeholder so empties are detectable
            if dev == "LOR":
                lor_keys[("LOR", "", "", None, None, "")] += 1
            elif dev == "DMX":
                dmx_keys[("DMX", "", None, None, None)] += 1
            else:
                fallback_keys[(dev, display, channel)] += 1
            continue

        parts_list = _lc_parse_channel_grid(grid)

        if dev == "LOR":
            for parts in parts_list:
                net   = parts[0] if len(parts) > 0 else ""
                uid   = parts[1] if len(parts) > 1 else ""
                start = _lc_i(parts[2])
                end   = _lc_i(parts[3])
                color = parts[5] if len(parts) > 5 else ""
                lor_keys[("LOR", net, uid, start, end, color)] += 1
                stats["legs_lor"] += 1
            continue

        if dev == "DMX":
            for parts in parts_list:
                net   = parts[0] if len(parts) > 0 else ""
                uni   = _lc_i(parts[1])
                start = _lc_i(parts[2])
                end   = _lc_i(parts[3])
                dmx_keys[("DMX", net, uni, start, end)] += 1
                stats["legs_dmx"] += 1
            continue

        # Unknown types: fall back to labels only (still preserve multiplicity)
        fallback_keys[(dev, display, channel)] += 1

    # Expand counters into a set that encodes multiplicity deterministically
    def expand(counter: Counter) -> set[tuple]:
        out = set()
        for key, n in counter.items():
            for i in range(1, n + 1):
                out.add((*key, i))   # append ordinal
        return out

    items = set()
    items |= expand(none_keys)
    items |= expand(lor_keys)
    items |= expand(dmx_keys)
    items |= expand(fallback_keys)

    # NEW: fold label-health into the core (so label fixes trigger staging)
    # Example emitted items:
    #   ("LBLMISS", "LOR", "COMMENT", 1), ("LBLMISS", "LOR", "COMMENT", 2), ...
    for key, n in miss_comment.items():
        dev, kind = key  # kind="COMMENT"
        for i in range(1, n + 1):
            items.add(("LBLMISS", dev, kind, i))
    for key, n in miss_name.items():
        dev, kind = key  # kind="NAME"
        for i in range(1, n + 1):
            items.add(("LBLMISS", dev, kind, i))

    return items, stats
