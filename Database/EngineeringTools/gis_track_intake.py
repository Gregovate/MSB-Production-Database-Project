"""#428 Garmin recording identification in the EXISTING MSB GIS Manager.
This workspace leaves master and Garmin files unchanged. Registered aerial
alignment is required before operator acceptance; do not infer surveyed fixes.
"""
from __future__ import annotations
import hashlib
import json
import math
import re
import shutil
import threading
import queue as thread_queue
from datetime import datetime, timezone
from pathlib import Path
import xml.etree.ElementTree as ET
import tkinter as tk
from io import BytesIO
from urllib.request import urlopen, Request
from urllib.error import URLError, HTTPError
from PIL import Image, ImageTk
from sync_gis_icons import PARK
from tkinter import ttk, filedialog, messagebox
import gis_track_reconcile as reconcile

GPX = "{http://www.topografix.com/GPX/1/1}"
KINDS = ("Unknown", "High Voltage", "High Voltage 12-2", "High Voltage 12-3",
         "Maybe Abandoned/Dead", "Network", "Primary")
TYPE_NAMES = {"HV": "High Voltage", "NET": "Network", "PRI": "Primary"}


def infrastructure_waypoint(node):
    """Use the master's infrastructure types, with known name-prefix fallback."""
    kind = (node.findtext(GPX+"type") or "").strip().casefold()
    name = (node.findtext(GPX+"name") or "").strip().casefold()
    if kind in ("stage", "stages"):
        return False
    return (kind in ("display anchor", "light pole", "transformer", "outlet power")
            or kind.startswith(("lp-", "lp_", "out-", "panel", "wifi"))
            or name.startswith(("lp-", "lp_", "out-", "panel", "wifi")))


def road_or_trail(track):
    return bool(re.match(r"^(road|trail)(?:s|\b)", track["type"].strip(), re.I))


def reference_track(track):
    value = track["type"].strip().casefold()
    return (value.startswith("high voltage")
            or value in ("network", "primary", "abandoned", "dead", "maybe abandoned/dead")
            or road_or_trail(track))
# Existing calibrated 2019 orthophoto tile layer from Setup/Application/locate_preview.html.
AERIAL_URL = "https://webassets.sheboyganlights.org/maps/evergreen-2019-v1/{z}/{x}/{y}.jpg"


class TrackPoints(list):
    """Keep GPX segment boundaries; flatten only for endpoint/distance queries."""
    def __init__(self, segments):
        self.segments = segments
        super().__init__(p for segment in segments for p in segment)


def coordinate(node):
    lat, lon = float(node.get("lat")), float(node.get("lon"))
    if not (math.isfinite(lat) and math.isfinite(lon) and -90 <= lat <= 90 and -180 <= lon <= 180):
        raise ValueError("Invalid GPX latitude/longitude")
    return lat, lon


def run_color(track):
    kind=track["type"].strip().casefold()
    if kind=="network":return "#0066ff"
    if kind.startswith("high voltage"):return "#ff2020"
    if kind=="primary":return "#ff8c00"
    return "#888888"


def nearby_runs(points, tracks, radius=100):
    walked=dict(segments=getattr(points,"segments",[points]),points=points)
    found=[]
    for track in tracks:
        if not reference_track(track) or road_or_trail(track) or len(track["points"])<2:continue
        match=reconcile.rank_matches(track["points"],[walked],limit=1)
        if match and match[0]["route_ft"]<=radius:found.append(track)
    return found


def suggested_range(points, track):
    ends=[min(range(len(points)),key=lambda i:dist_ft(points[i],p))
          for p in (track["points"][0],track["points"][-1])]
    a,b=sorted(ends)
    if a==b:return 1,len(points)
    return a+1,b+1


def parse(path, exclude_stages=False, infrastructure_only=False):
    root = ET.fromstring(Path(path).read_bytes())
    if root.tag != GPX + "gpx":
        raise ValueError("Only GPX 1.1 is supported")
    tracks = []
    for i, node in enumerate(root.findall(GPX + "trk"), 1):
        pts = TrackPoints([[coordinate(p) for p in seg.findall(GPX + "trkpt")]
                           for seg in node.findall(GPX + "trkseg")])
        if len(pts) > 1:
            tracks.append((i, node.findtext(GPX + "name") or "", pts))
    points = [(w.findtext(GPX + "name") or "(unnamed)", *coordinate(w))
              for w in root.findall(GPX + "wpt")
              if not infrastructure_only or infrastructure_waypoint(w)
              if not exclude_stages or (w.findtext(GPX+"type") or "").strip().casefold() not in ("stage","stages")]
    return tracks, points

def dist_ft(a, b):
    lat = math.radians((a[0] + b[0]) / 2)
    return 20925524.9 * math.hypot(math.radians(b[0]-a[0]),
                                   math.radians(b[1]-a[1])*math.cos(lat))

def nearest(point, waypoints, count=5):
    return sorted([(w[0], round(dist_ft(point, (w[1], w[2])), 1))
                   for w in waypoints], key=lambda x: x[1])[:count]

def type_hint(text):
    voltage = re.search(r"\b(?:HIGH\s*VOLTAGE|HV)\s*(12[- ](?:2|3))?\b",text,re.I)
    if voltage:
        return "High Voltage"+(" "+voltage[1].replace(" ","-") if voltage[1] else "")
    if re.search(r"\b(?:ABANDONED|DEAD)\b",text,re.I):
        return "Maybe Abandoned/Dead"
    parts = re.findall(r"[A-Z]+", text.upper())
    for kind in ("HV", "NET", "PRI"):
        if kind in parts or re.search(r"(?<![A-Z])"+kind+r"[A-Z]{1,3}\d", text.upper()):
            return TYPE_NAMES[kind]
    return "Unknown"

def propose(kind, start, end):
    kind = {"High Voltage":"HV", "Network":"NET", "Primary":"PRI"}.get(kind,kind)
    return ((kind+" ") if kind != "Unknown" else "") + start + " to " + end

def source_digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()

def reviewed_path(intake, digest, index):
    return Path(intake) / "Reviews" / (digest + "_" + str(index) + ".json")

def save(intake, source, index, name, kind, start, end, expected_digest=None, master=None, master_digest=None):
    """Create review receipt, keeping Garmin, original GPX and master unchanged."""
    kind = TYPE_NAMES.get(kind,kind)
    if not name.strip() or not (kind in KINDS or kind.casefold().startswith("high voltage")):
        raise ValueError("Name and temporary classification are required")
    if not start.strip() or not end.strip():
        raise ValueError("Review starting and ending waypoints")
    source = Path(source)
    digest = source_digest(source)
    if expected_digest is not None and digest != expected_digest:
        raise ValueError("Recording changed since display; read tracks again")
    if master is not None and source_digest(master) != master_digest:
        raise ValueError("Master changed since display; read tracks again")
    if index not in [t[0] for t in parse(source)[0]]:
        raise ValueError("Selected track no longer exists")
    day = datetime.fromtimestamp(source.stat().st_mtime).strftime("%Y-%m-%d")
    originals = Path(intake) / day / "Originals"
    archive = originals / (digest[:16] + "_" + re.sub(r"[^A-Za-z0-9_.-]", "_", source.name))
    originals.mkdir(parents=True, exist_ok=True)
    if not archive.exists():
        with archive.open("xb") as target:
            target.write(source.read_bytes())
    if source_digest(archive) != digest:
        raise ValueError("Archive hash mismatch — review not saved")
    destination = reviewed_path(intake, digest, index)
    destination.parent.mkdir(parents=True, exist_ok=True)
    if source_digest(source) != digest:
        raise ValueError("Recording changed during intake; review again")
    previous = json.loads(destination.read_text(encoding="utf8")) if destination.exists() else None
    data = dict(schema="msb.gis.intake.v1", source_sha256=digest,
                source_path=str(source), archived_original=str(archive), track_index=index, working_name=name.strip(),
                temporary_type=kind, start_waypoint=start, end_waypoint=end,
                status="Identified (not merged)",
                reviewed_utc=datetime.now(timezone.utc).isoformat())
    if master is not None:
        data.update(master_path=str(master), master_sha256=master_digest,
                    aerial_layer=AERIAL_URL)
    if previous is not None:
        data["previous_review"] = previous
    temp = destination.with_suffix(".json.tmp")
    temp.write_text(json.dumps(data, indent=2), encoding="utf8")
    temp.replace(destination)
    return destination

def mercator(lat, lon, zoom):
    """Pixel coordinate in the existing web map's EPSG:3857 XYZ tile grid."""
    lat = max(-85.05112878, min(85.05112878, lat))
    scale = 256 * (2 ** zoom)
    x = (lon + 180.0) / 360.0 * scale
    sine = math.sin(math.radians(lat))
    y = (0.5 - math.log((1 + sine) / (1 - sine)) / (4 * math.pi)) * scale
    return x, y

def fit_zoom(track, width, height, max_zoom=20, min_zoom=14):
    """Highest XYZ zoom fitting all raw vertices with a visible margin."""
    for zoom in range(max_zoom, min_zoom - 1, -1):
        xy = [mercator(lat, lon, zoom) for lat, lon in track]
        span_x = max(p[0] for p in xy) - min(p[0] for p in xy)
        span_y = max(p[1] for p in xy) - min(p[1] for p in xy)
        if span_x <= width * 0.82 and span_y <= height * 0.82:
            return zoom
    raise ValueError("Track extends beyond the available park aerial viewport")

def unproject(x, y, zoom):
    scale = 256 * 2 ** zoom
    return math.degrees(math.atan(math.sinh(math.pi * (1-2*y/scale)))), x/scale*360-180

def inches_per_pixel(lat, zoom):
    return 40075016.68557849 * math.cos(math.radians(lat)) / (256*2**zoom) / .0254

def aerial_image(track, width, height, zoom=19, fetch=None, center=None):
    """Compose the existing MSB published orthophoto tiles around a track.
    No fallback fake aerial; callers must visibly report unavailable imagery.
    """
    if fetch is None:
        def fetch(url):
            request = Request(url, headers={"User-Agent": "Mozilla/5.0 MSB-GIS-Manager/0.4.6",
                                            "Referer": "https://my.sheboyganlights.org/"})
            with urlopen(request, timeout=10) as response:
                return response.read()
    # Published imagery ends at z20. Higher display zoom enlarges those same
    # pixels, preserving registration without implying additional detail.
    if zoom > 20:
        factor = 2 ** (zoom-20)
        image, offset = aerial_image(track, math.ceil(width/factor), math.ceil(height/factor),
                                     20, fetch, center)
        return image.resize((image.width*factor,image.height*factor),
                            Image.Resampling.NEAREST).crop((0,0,width,height)), tuple(v*factor for v in offset)
    projected = [mercator(*p, zoom) for p in track]
    center = mercator(*center, zoom) if center is not None else (
              (min(p[0] for p in projected)+max(p[0] for p in projected))/2,
              (min(p[1] for p in projected)+max(p[1] for p in projected))/2)
    ox, oy = center[0]-width/2, center[1]-height/2
    output = Image.new("RGB", (width,height))
    for tx in range(math.floor(ox/256), math.floor((ox+width-1)/256)+1):
        for ty in range(math.floor(oy/256), math.floor((oy+height-1)/256)+1):
            url = AERIAL_URL.format(z=zoom, x=tx, y=ty)
            raw = fetch(url)
            with Image.open(BytesIO(raw)) as tile:
                if tile.size != (256,256):
                    raise ValueError("Unexpected aerial tile dimensions")
                output.paste(tile.convert("RGB"), (round(tx*256-ox), round(ty*256-oy)))
    return output, (ox,oy)

def find_garmin_gpx_dirs():
    """Read-only discovery of mounted Windows Garmin GPX folders."""
    from string import ascii_uppercase
    found = []
    for drive in ascii_uppercase:
        root = Path(f"{drive}:/Garmin/GPX")
        try:
            if root.is_dir():
                found.append(root)
        except OSError:
            continue
    return found

def open_intake(parent):
    win = tk.Toplevel(parent)
    win.title("MSB GIS Manager — Garmin Track Intake #428")
    win.geometry("1400x900")
    if win.tk.call("tk", "windowingsystem")=="win32":win.state("zoomed")
    base = ttk.Frame(win, padding=12)
    base.pack(fill="both", expand=True)
    ttk.Label(base, text="Garmin Track Intake", font=("Segoe UI",16,"bold")).pack(anchor="w")
    ttk.Label(base, text="Read track → identify on aerial → suggest name/type → correct → Save & Next. Originals stay unchanged.").pack(anchor="w")
    found_devices = find_garmin_gpx_dirs()
    gis_root = PARK.parent
    src = tk.StringVar(value=str(found_devices[0]) if len(found_devices)==1 else "")
    master = tk.StringVar(value=str(gis_root / "MSB-Park-Infrastructure.gpx"))
    intake = tk.StringVar(value=str(gis_root / "Field-Recordings"))
    fields = [("Garmin GPX folder", src, True), ("Current master GPX", master, False),
              ("Existing Field-Recordings folder", intake, True)]
    path_rows=[]
    for label, variable, isdir in fields:
        row = ttk.Frame(base); row.pack(fill="x", pady=3);path_rows.append(row)
        ttk.Label(row, text=label, width=29).pack(side="left")
        ttk.Entry(row, textvariable=variable).pack(side="left", fill="x", expand=True)
        def browse(v=variable, d=isdir):
            value = filedialog.askdirectory(parent=win) if d else filedialog.askopenfilename(
                parent=win, filetypes=[("GPX", "*.gpx")])
            if value: v.set(value)
        ttk.Button(row, text="Browse", command=browse).pack(side="left")
    row = ttk.Frame(base); row.pack(fill="both", expand=True)
    queue = tk.Listbox(row, width=34, exportselection=False, selectmode="extended"); queue.pack(side="left",fill="y")
    panel = ttk.Frame(row, padding=8); panel.pack(side="left",fill="both",expand=True)
    ttk.Label(panel, text="Selected track and waypoint suggestions").pack(anchor="w")
    map_controls = ttk.Frame(panel); map_controls.pack(fill="x")
    editor = ttk.Frame(panel)
    editor.pack(side="bottom",fill="x")
    drawing = tk.Canvas(panel,bg="#f0f2ed",height=290); drawing.pack(fill="both",expand=True)
    aerial_status = tk.StringVar(value="2019 aerial loads when you select a track.")
    ttk.Label(panel, textvariable=aerial_status, wraplength=620).pack(side="bottom",anchor="w",before=drawing)
    start, end, name, kind = tk.StringVar(),tk.StringVar(),tk.StringVar(),tk.StringVar(value="Unknown")
    identification_rows=[]
    for label,var in [("Start waypoint",start),("End waypoint",end),("Working name",name)]:
        r=ttk.Frame(editor);r.pack(fill="x",pady=3);identification_rows.append(r)
        ttk.Label(r,text=label,width=19).pack(side="left")
        ttk.Entry(r,textvariable=var).pack(side="left",fill="x",expand=True)
    r=ttk.Frame(editor);r.pack(fill="x",pady=3)
    identification_rows.append(r)
    ttk.Label(r,text="Temporary type",width=19).pack(side="left")
    type_choice=ttk.Combobox(r,textvariable=kind,values=KINDS,state="readonly")
    type_choice.pack(side="left",fill="x",expand=True)
    show_roads=tk.BooleanVar(value=False)
    show_all_runs=tk.BooleanVar(value=True)
    status=tk.StringVar(value="Garmin GPX detected — verify paths and click Read." if len(found_devices)==1 else
                       "Select mounted Garmin GPX folder, current master and intake root.")
    ttk.Label(base,textvariable=status,wraplength=900).pack(anchor="w",before=row)
    state={"items":[],"waypoints":[],"aerial_ready":False,"generation":0}
    results = thread_queue.Queue()
    def select(event=None):
        if state.get("review_window") and state["review_window"].winfo_exists():
            state["review_window"].destroy()
        state.pop("matched_track",None)
        show_all_runs.set(True)
        state["generation"] += 1
        state["aerial_ready"]=False
        selection=queue.curselection()
        if not selection:return
        active=state.get("active_recording",selection[0])
        if active not in selection:active=selection[0]
        state["active_recording"]=active
        state["comparison_points"]=[state["items"][i][1][2] for i in selection if i!=active]
        source,(idx,original,points)=state["items"][active]
        digest=state["digests"][source]
        a,b=nearest(points[0],state["waypoints"]),nearest(points[-1],state["waypoints"])
        start.set(a[0][0] if a else "Unknown");end.set(b[0][0] if b else "Unknown")
        kind.set(type_hint(original+" "+source.stem))
        name.set(propose(kind.get(),start.get(),end.get()))
        receipt=reviewed_path(intake.get(),digest,idx)
        try:
            if receipt.exists():
                prior=json.loads(receipt.read_text(encoding="utf8"))
                name.set(prior.get("working_name",name.get()))
                saved_kind=prior.get("temporary_type",kind.get())
                kind.set(TYPE_NAMES.get(saved_kind,saved_kind))
                start.set(prior.get("start_waypoint",start.get()))
                end.set(prior.get("end_waypoint",end.get()))
        except (OSError, ValueError) as error:
            status.set(f"Cannot read saved review: {error}")
            return
        state["points"] = points
        comparison=TrackPoints([*points.segments,*[seg for p in state["comparison_points"] for seg in p.segments]])
        state["nearby_runs"]=nearby_runs(comparison,state["master_tracks"])
        state["nearby"] = [w for w in state["waypoints"] if min(dist_ft((w[1],w[2]),p) for p in points)<250]
        state["center"] = None
        state["zoom"] = None
        request_map()
        status.set(f"{source.name} — {len(points)} vertices; start: {a[:3]}, end: {b[:3]}. Distances are suggestions only.")

    def request_map():
        if not state.get("points"): return
        state["generation"] += 1
        state["aerial_ready"] = False
        points, nearby = state["points"], state["nearby"]
        width=max(drawing.winfo_width(),1); height=max(drawing.winfo_height(),1)
        state["requested_size"] = (width,height)
        zoom, center = state.get("zoom"), state.get("center")
        aerial_status.set("Loading published 2019 aerial…")
        generation = state["generation"]
        def fetch_map():
            try:
                z = zoom if zoom is not None else fit_zoom(points,width,height)
                tile, offset = aerial_image(points,width,height,zoom=z,center=center)
                results.put((generation, (tile, offset, z, points, nearby), None))
            except Exception as error:
                results.put((generation, None, str(error)))
        threading.Thread(target=fetch_map, daemon=True).start()

    def poll_map():
        try:
            while True:
                generation, result, error = results.get_nowait()
                if generation != state["generation"]:
                    continue
                drawing.delete("all")
                if error:
                    drawing.create_text(20,20,anchor="nw",text="Aerial unavailable; no map review possible.",fill="#ad1e1e")
                    aerial_status.set(f"AERIAL STOP — {error}. No calibrated map displayed.")
                    continue
                render_map(*result)
        except thread_queue.Empty:
            pass
        if win.winfo_exists():
            win.after(100, poll_map)

    def render_map(tile, offset, zoom, points, nearby):
        ox,oy = offset
        try:
            photo=ImageTk.PhotoImage(tile, master=win)
            drawing.image_ref=photo
            drawing.create_image(0,0,image=photo,anchor="nw")
            def xy(p):
                x,y=mercator(p[0],p[1],zoom)
                return x-ox,y-oy
            def map_label(x,y,text):
                label = drawing.create_text(x,y,text=text,anchor="sw",fill="#111111",
                                            font=("Segoe UI",11,"bold"),tags=("map-label",))
                bounds = drawing.bbox(label)
                if bounds:
                    a,b,c,d=bounds
                    plate=drawing.create_rectangle(a-4,b-2,c+4,d+2,fill="#ffffff",
                                                   outline="#111111",tags=("label-background",))
                    drawing.tag_lower(plate,label)
            # Existing master route is context, never modified by preview.
            if show_roads.get():
                for track in state.get("master_tracks",[]):
                    if not road_or_trail(track):continue
                    for segment in track["segments"]:
                        if len(segment)>1:
                            coords=[c for p in segment for c in xy(p)]
                            drawing.create_line(*coords,fill="#111111",width=5,tags=("road-trail",))
                            drawing.create_line(*coords,fill="#ffffff",width=2,dash=(6,4),tags=("road-trail",))
            for track in state.get("nearby_runs",[]):
                selected=track["index"]==state.get("matched_track",{}).get("index")
                if not show_all_runs.get() and state.get("matched_track") and not selected:
                    continue
                for segment in track["segments"]:
                    if len(segment)>1:
                        coords=[c for p in segment for c in xy(p)]
                        drawing.create_line(*coords,fill="white",width=8 if selected else 5,tags=("master-run",f"run-{track['index']}"))
                        drawing.create_line(*coords,fill=run_color(track),width=5 if selected else 3,tags=("master-run",f"run-{track['index']}"))
            if state.get("review_window") and state["review_window"].winfo_exists():
                for i,p in enumerate(state.get("raw_preview",points),1):
                    x,y=xy(p)
                    drawing.create_oval(x-3,y-3,x+3,y+3,fill="#ffe600",outline="black")
                    drawing.create_text(x+6,y+6,text=str(i),anchor="nw",fill="white",font=("Segoe UI",9,"bold"))
            for comparison in state.get("comparison_points",[]):
                for segment in comparison.segments:
                    if len(segment)>1:drawing.create_line(*[c for p in segment for c in xy(p)],fill="#ffe600",width=2,dash=(3,7))
            for segment in getattr(points, "segments", [points]):
                if len(segment) > 1:
                    drawing.create_line(*[c for p in segment for c in xy(p)],fill="#ffe600",width=4,dash=(8,4))
                elif segment:
                    x,y=xy(segment[0])
                    drawing.create_oval(x-3,y-3,x+3,y+3,fill="#ffe600")
            for label,p in [("START",points[0]),("END",points[-1])]:
                x,y=xy(p)
                map_label(x,y+24,label)
            for w in nearby:
                x,y=xy((w[1],w[2]))
                drawing.create_oval(x-5,y-5,x+5,y+5,fill="#ffdf00",outline="#111111",width=2)
                map_label(x+9,y-9,w[0])
            drawing.addtag_all("map-content")
            state["aerial_ready"]=True
            state.update(zoom=zoom, offset=offset, center=unproject(ox+tile.width/2,oy+tile.height/2,zoom))
            scale = inches_per_pixel(state["center"][0],zoom)
            bar_inches = 6 if zoom >= 22 else 120
            length = bar_inches/scale
            drawing.create_rectangle(12,12,220,58,fill="white",outline="")
            drawing.create_line(22,44,22+length,44,fill="black",width=3)
            drawing.create_text(22,22,anchor="nw",text=f'{bar_inches} inches — {scale:.2f} in/pixel')
            aerial_status.set(f"2019 MSB aerial • zoom {zoom} • {scale:.2f} inches/pixel"
                              + (" • enlarged z20 imagery" if zoom>20 else "")
                              + " • Display scale is not GPS accuracy.")
        except (OSError, ValueError, TimeoutError, RuntimeError, URLError, HTTPError) as error:
            drawing.create_text(20,20,anchor="nw",text="Aerial unavailable; no map review possible.",
                                fill="#ad1e1e")
            aerial_status.set(f"AERIAL STOP — {error}. No calibrated map displayed.")
    def change_zoom(delta=0, event=None, target=None):
        if not state.get("aerial_ready"): return
        old = state["zoom"]
        new = max(14,min(24,target if target is not None else old+delta))
        x = event.x if event is not None else drawing.winfo_width()/2
        y = event.y if event is not None else drawing.winfo_height()/2
        ox,oy = state["offset"]
        factor = 2**(new-old)
        state["center"] = unproject((ox+x)*factor-x+drawing.winfo_width()/2,
                                   (oy+y)*factor-y+drawing.winfo_height()/2,new)
        state["zoom"] = new
        request_map()
    def fit_track():
        state["center"] = None; state["zoom"] = None
        request_map()
    def pan_start(event):
        if state.get("aerial_ready"):
            state["drag"] = (event.x,event.y)
            state["drag_last"] = (event.x,event.y)
            drawing.configure(cursor="fleur")
    def pan_move(event):
        previous=state.get("drag_last")
        if previous is None:return
        drawing.move("map-content",event.x-previous[0],event.y-previous[1])
        state["drag_last"]=(event.x,event.y)
    def pan_end(event):
        anchor = state.pop("drag",None)
        state.pop("drag_last",None)
        drawing.configure(cursor="hand2")
        if anchor is None or not state.get("aerial_ready"): return
        if abs(event.x-anchor[0])+abs(event.y-anchor[1])<5:
            hits=drawing.find_overlapping(event.x-7,event.y-7,event.x+7,event.y+7)
            for item in reversed(hits):
                for tag in drawing.gettags(item):
                    if tag.startswith("run-"):
                        review_replacement(int(tag[4:]));return
            return
        x,y=mercator(*state["center"],state["zoom"])
        state["center"]=unproject(x-(event.x-anchor[0]),y-(event.y-anchor[1]),state["zoom"])
        request_map()
    ttk.Button(map_controls,text="−",command=lambda:change_zoom(-1),width=3).pack(side="left")
    ttk.Button(map_controls,text="+",command=lambda:change_zoom(1),width=3).pack(side="left")
    ttk.Button(map_controls,text="6-inch detail",command=lambda:change_zoom(target=24)).pack(side="left")
    ttk.Button(map_controls,text="Fit track",command=fit_track).pack(side="left")
    ttk.Checkbutton(map_controls,text="All nearby runs",variable=show_all_runs,
                    command=request_map).pack(side="left")
    ttk.Checkbutton(map_controls,text="Roads / trails",variable=show_roads,
                    command=request_map).pack(side="left")
    ttk.Label(map_controls,text="Master: blue network / red power / orange primary. Yellow = Garmin. Wheel to zoom • Drag to pan").pack(side="left")
    drawing.bind("<MouseWheel>",lambda e:change_zoom(1 if e.delta>0 else -1,e))
    drawing.bind("<ButtonPress-1>",pan_start)
    drawing.bind("<B1-Motion>",pan_move)
    drawing.bind("<ButtonRelease-1>",pan_end)
    drawing.configure(cursor="hand2")
    def resized(event):
        if not state.get("points") or (event.width,event.height)==state.get("requested_size"):
            return
        # Invalidate in-flight tiles immediately, then wait for the resize to
        # settle. Keep the geographic center, zoom and operator edits.
        state["generation"] += 1
        state["aerial_ready"] = False
        aerial_status.set("Resizing 2019 aerial…")
        pending=state.pop("resize_job",None)
        if pending is not None: win.after_cancel(pending)
        def redraw():
            state.pop("resize_job",None)
            request_map()
        state["resize_job"]=win.after(250,redraw)
    drawing.bind("<Configure>",resized)
    def load():
        state["generation"] += 1
        state["aerial_ready"] = False
        state["items"] = []
        state.pop("points",None)
        queue.delete(0,"end")
        try:
            if not Path(master.get()).is_file() or not Path(src.get()).is_dir() or not Path(intake.get()).is_dir():
                raise ValueError("Select existing Garmin folder, current master and intake directory")
            source_root = Path(src.get()).resolve()
            intake_root = Path(intake.get()).resolve()
            if intake_root == source_root or source_root in intake_root.parents:
                raise ValueError("Intake destination must be outside the Garmin source folder")
            state["master"]=Path(master.get()).resolve()
            state["master_digest"]=source_digest(state["master"])
            state["waypoints"]=parse(state["master"],infrastructure_only=True)[1]
            state["master_tracks"]=reconcile.tracks(state["master"])
            type_choice.configure(values=tuple(dict.fromkeys((*KINDS,*sorted({
                t["type"] for t in state["master_tracks"]
                if t["type"].strip().casefold().startswith("high voltage")})))))
            if not state["waypoints"]:
                raise ValueError("The current master has no waypoint identities")
            state["intake"] = str(intake_root)
            state["digests"] = {}
            for file in sorted(Path(src.get()).rglob("*")):
                if file.is_file() and file.suffix.lower()==".gpx":
                    digest = source_digest(file)
                    tracks = parse(file)[0]
                    if source_digest(file) != digest:
                        raise ValueError("Recording changed while reading; try again")
                    state["digests"][file] = digest
                    for trk in tracks:state["items"].append((file,trk))
            queue.delete(0,"end")
            reviewed={(d["source_sha256"],d["raw_index"]):d
                      for d in reconcile.decisions(state["intake"],state["master_digest"])}
            for file,(idx,title,pts) in state["items"]:
                decision=reviewed.get((state["digests"][file],idx))
                queue.insert("end",(("✓ Keep: " if decision.get("action")=="keep" else "✓ Replace: ")+decision["master_name"])
                             if decision else title or file.name)
            status.set(f"{len(state['items'])} tracks; {len(state['waypoints'])} master waypoints.")
            if state["items"]: queue.selection_set(0); select()
        except (OSError, ValueError, TypeError, ET.ParseError) as e:
            state["items"] = []
            queue.delete(0,"end")
            messagebox.showerror("Intake stopped",str(e),parent=win)
    def next_item():
        try:
            selected=queue.curselection()
            if not selected: return
            if not state["aerial_ready"]:
                raise ValueError("Calibrated aerial is unavailable; do not approve track identification")
            file,(idx,_,_)=state["items"][selected[0]]
            if intake.get() != state["intake"] and str(Path(intake.get()).resolve()) != state["intake"]:
                raise ValueError("Destination changed; read tracks again")
            path=save(state["intake"],file,idx,name.get(),kind.get(),start.get(),end.get(),
                      expected_digest=state["digests"][file], master=state["master"],
                      master_digest=state["master_digest"])
            old=selected[0]
            queue.delete(old);queue.insert(old,name.get())
            if old+1 < len(state["items"]):
                queue.selection_clear(0,"end");queue.selection_set(old+1);queue.see(old+1);select()
            else:status.set("Saved: "+str(path)+" — last recording reviewed.")
        except (OSError, ValueError) as e:messagebox.showerror("Save stopped",str(e),parent=win)
    def suggest(*_):
        if start.get() and end.get():name.set(propose(kind.get(),start.get(),end.get()))
    def review_replacement(master_index=None):
        selected=queue.curselection()
        if not selected or not state.get("aerial_ready"):return
        if state.get("review_window") and state["review_window"].winfo_exists():
            if master_index is not None:state["choose_master"](master_index)
            return
        active=state.get("active_recording",selected[0])
        file,(raw_index,raw_name,raw_points)=state["items"][active]
        review=ttk.Frame(row,name="run_review",width=620);state["review_window"]=review
        review.pack(side="right",fill="y",before=panel);review.pack_propagate(False)
        frame=ttk.Frame(review,padding=10);frame.pack(fill="both",expand=True)
        ttk.Label(frame,text="Current ExpertGPS master → reviewed replacement",font=("Segoe UI",11,"bold"),wraplength=560).pack(anchor="w")
        ttk.Label(frame,text="Choose a cable run, review its notes, and select the part of this walk to use. Save each run separately.\nMaster: network blue / power red / primary orange. Garmin recording: yellow.",wraplength=560).pack(anchor="w")
        matches=reconcile.rank_matches(raw_points,state["nearby_runs"],limit=None)
        choices=tk.Listbox(frame,exportselection=False,height=7)
        for m in matches:choices.insert("end",m["track"]["name"])
        choices.pack(fill="x",pady=5)
        metadata=tk.Text(frame,height=8,width=35,wrap="word");metadata.pack(fill="both",expand=True)
        verts=reconcile.recording_vertices(file,raw_index)
        draft=[dict(v) for v in verts]
        state["raw_preview"]=raw_points
        range_row=ttk.Frame(frame);range_row.pack(fill="x")
        ttk.Label(range_row,text="Points: From").pack(side="left")
        first,last=tk.IntVar(value=1),tk.IntVar(value=len(verts))
        ttk.Spinbox(range_row,from_=1,to=len(verts),textvariable=first,width=7).pack(side="left")
        ttk.Label(range_row,text="through").pack(side="left")
        ttk.Spinbox(range_row,from_=1,to=len(verts),textvariable=last,width=7).pack(side="left")
        def preview():
            confirmed.set(False)
            try:
                a,b=first.get(),last.get()
                if not 1<=a<b<=len(verts):raise ValueError("Choose at least two consecutive Garmin points")
                draft[:]=[dict(v) for v in verts[a-1:b]]
                segments=[];previous=None
                for v in draft:
                    if v["segment"]!=previous:segments.append([]);previous=v["segment"]
                    segments[-1].append((v["lat"],v["lon"]))
                state["points"]=TrackPoints(segments);request_map()
            except (ValueError,tk.TclError) as e:message.set(str(e))
        ttk.Button(frame,text="Preview selected point range",command=preview).pack(fill="x")
        first.trace_add("write",lambda *_:confirmed.set(False))
        last.trace_add("write",lambda *_:confirmed.set(False))
        def choose(event=None):
            i=(choices.curselection()[0] if choices.curselection() else -1)
            if i<0:return
            track=matches[i]["track"]
            state["matched_track"]=track
            show_all_runs.set(False)
            metadata.configure(state="normal");metadata.delete("1.0","end")
            metadata.insert("end",f'Master track #{track["index"]}: {track["name"]}\nType: {track["type"]}\n'
                            f'Years mentioned in notes: {", ".join(str(y["year"]) for y in reconcile.annual_history_evidence(track)) or "Not specified"}\n'
                            f'Comments:\n{track["comments"] or "(none)"}\nInstallation/description:\n{track["description"] or "(none)"}'
                            "\n\nAll master extensions and original metadata are retained in the exported GPX.")
            metadata.configure(state="disabled")
            a,b=suggested_range(raw_points,track);first.set(a);last.set(b);preview()
            near=matches[i]
            message.set("Very close to existing master geometry — this may already be processed. Compare the notes before replacing."
                        if near["route_ft"]<3 and near["endpoint_ft"]<3 else
                        "Verify the match, then save. Finish geometry edits in ExpertGPS.")
        choices.bind("<<ListboxSelect>>",choose)
        def choose_master(index):
            i=next((i for i,m in enumerate(matches) if m["track"]["index"]==index),None)
            if i is not None:
                choices.selection_clear(0,"end");choices.selection_set(i);choices.see(i);choose()
        state["choose_master"]=choose_master
        ttk.Label(frame,text="Optional match note:").pack(anchor="w")
        note=tk.Text(frame,height=2,width=35,wrap="word");note.pack(fill="x")
        confirmed=tk.BooleanVar(value=False)
        ttk.Checkbutton(frame,text="I verified this run and point range.",variable=confirmed).pack(anchor="w")
        message=tk.StringVar(value="Select a candidate; proximity is only a suggestion.")
        ttk.Label(frame,textvariable=message,wraplength=560).pack(anchor="w")
        def accept(action="replace",advance=True):
            try:
                if (choices.curselection()[0] if choices.curselection() else -1)<0 or not confirmed.get():raise ValueError("Select and verify the matching master track")
                if not state.get("aerial_ready"):raise ValueError("Wait for the calibrated preview before acceptance")
                a,b=first.get(),last.get()
                if [v["source_index"] for v in draft]!=list(range(a-1,b)):raise ValueError("Preview the selected range before saving")
                track=matches[(choices.curselection()[0] if choices.curselection() else -1)]["track"]
                path=reconcile.accept_replacement(state["intake"],state["master"],state["master_digest"],file,
                      state["digests"][file],raw_index,track["index"],draft,note.get("1.0","end").strip() or "Operator matched Garmin recording to master for editing in ExpertGPS.",action=action)
                old=active
                queue.delete(old);queue.insert(old,("✓ Replace: " if action=="replace" else "✓ Keep: ")+track["name"])
                if not advance:
                    confirmed.set(False)
                    message.set("Saved: "+track["name"]+". Choose another run for this same walk.")
                    return
                review.destroy()
                if old+1<len(state["items"]):
                    queue.selection_clear(0,"end");queue.selection_set(old+1);queue.see(old+1);select()
                status.set(("Match saved for ExpertGPS: " if action=="replace" else "Existing master route retained: ")
                           +track["name"]+". Shared master and PostgreSQL unchanged.")
            except (ValueError,OSError) as error:messagebox.showerror("Replacement stopped",str(error),parent=review)
        ttk.Button(frame,text="Save run; choose another",command=lambda:accept(advance=False)).pack(fill="x",pady=2)
        ttk.Button(frame,text="Save match & Next",command=accept).pack(fill="x",pady=2)
        ttk.Button(frame,text="Keep existing & Next",command=lambda:accept("keep")).pack(fill="x",pady=2)
        def cancel():
            state["points"]=raw_points;state.pop("matched_track",None)
            review.destroy();request_map()
        ttk.Button(frame,text="Close review",command=cancel).pack(fill="x",pady=2)
        if matches:
            choose_master(master_index if master_index is not None else matches[0]["track"]["index"])
        else:
            metadata.insert("end","No nearby master cable runs found for this recording.")
            metadata.configure(state="disabled")
    def export_reviewed():
        if not state.get("master"):return
        output=filedialog.asksaveasfilename(parent=win,title="Export working GPX for ExpertGPS",
                  initialdir=state["intake"],initialfile="MSB-Park-Infrastructure-reviewed-"+datetime.now().strftime("%Y%m%d-%H%M%S")+".gpx",
                  defaultextension=".gpx",filetypes=[("GPX","*.gpx")])
        if not output:return
        try:
            reconcile.export_candidate(state["intake"],state["master"],state["master_digest"],output)
            status.set("Open this working GPX in ExpertGPS: "+output+". PostgreSQL comparison/release is still pending.")
        except (ValueError,OSError,ET.ParseError) as error:messagebox.showerror("Export stopped",str(error),parent=win)
    review_controls=ttk.Frame(editor);review_controls.pack(fill="x",pady=4)
    ttk.Button(review_controls,text="Match and name from master",command=review_replacement).pack(side="left")
    ttk.Button(review_controls,text="Export GPX for ExpertGPS",command=export_reviewed).pack(side="right")
    ttk.Button(base,text="Read Garmin tracks (read only)",command=load).pack(anchor="w",pady=4,before=row)
    queue.bind("<<ListboxSelect>>",select)
    def clicked_recording(event):
        index=queue.nearest(event.y)
        if index in queue.curselection():
            state["active_recording"]=index;select()
    queue.bind("<ButtonRelease-1>",clicked_recording)
    def focus_map():
        for widget in path_rows+identification_rows:widget.pack_forget()
        controls.pack_forget()
    def show_fields():
        for widget in path_rows:widget.pack(fill="x",pady=3,before=row)
        for widget in identification_rows:widget.pack(fill="x",pady=3,before=review_controls)
        controls.pack(fill="x")
    ttk.Button(map_controls,text="Maximize map",command=focus_map).pack(side="left",before=map_controls.winfo_children()[0])
    ttk.Button(map_controls,text="Show fields",command=show_fields).pack(side="left",before=map_controls.winfo_children()[1])
    win.after(500,focus_map)
    start.trace_add("write",lambda *_:None);end.trace_add("write",lambda *_:None)
    controls=ttk.Frame(editor);controls.pack(fill="x")
    ttk.Button(controls,text="Suggest name from selected endpoints",command=suggest).pack(side="left")
    ttk.Button(controls,text="Save identification only",command=next_item).pack(side="right")
    win.after(100, poll_map)
    return win
