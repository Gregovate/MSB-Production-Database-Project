"""#428 Garmin recording identification in the EXISTING MSB GIS Manager.
This workspace leaves master and Garmin files unchanged. Registered aerial
alignment is required before operator acceptance; do not infer surveyed fixes.
"""
from __future__ import annotations
import hashlib
import json
import math
import re
from datetime import datetime, timezone
from pathlib import Path
import xml.etree.ElementTree as ET
import tkinter as tk
from tkinter import ttk, filedialog, messagebox

GPX = "{http://www.topografix.com/GPX/1/1}"
KINDS = ("Unknown", "HV", "NET", "PRI")

def parse(path):
    root = ET.fromstring(Path(path).read_bytes())
    if root.tag != GPX + "gpx":
        raise ValueError("Only GPX 1.1 is supported")
    tracks = []
    for i, node in enumerate(root.findall(GPX + "trk"), 1):
        pts = [(float(p.get("lat")), float(p.get("lon"))) for p in node.iter(GPX + "trkpt")]
        if len(pts) > 1:
            tracks.append((i, node.findtext(GPX + "name") or "", pts))
    points = [(w.findtext(GPX + "name") or "(unnamed)", float(w.get("lat")), float(w.get("lon")))
              for w in root.findall(GPX + "wpt")]
    return tracks, points

def dist_ft(a, b):
    lat = math.radians((a[0] + b[0]) / 2)
    return 20925524.9 * math.hypot(math.radians(b[0]-a[0]),
                                   math.radians(b[1]-a[1])*math.cos(lat))

def nearest(point, waypoints, count=5):
    return sorted([(w[0], round(dist_ft(point, (w[1], w[2])), 1))
                   for w in waypoints], key=lambda x: x[1])[:count]

def type_hint(text):
    parts = re.findall(r"[A-Z]+", text.upper())
    return next((x for x in ("HV", "NET", "PRI") if x in parts), "Unknown")

def propose(kind, start, end):
    return ((kind+" ") if kind != "Unknown" else "") + start + " to " + end

def source_digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()

def reviewed_path(intake, digest, index):
    return Path(intake) / "Reviews" / (digest + "_" + str(index) + ".json")

def save(intake, source, index, name, kind, start, end):
    """Create review receipt, keeping Garmin, original GPX and master unchanged."""
    if not name.strip() or kind not in KINDS:
        raise ValueError("Name and temporary classification are required")
    source = Path(source)
    digest = source_digest(source)
    destination = reviewed_path(intake, digest, index)
    destination.parent.mkdir(parents=True, exist_ok=True)
    previous = json.loads(destination.read_text(encoding="utf8")) if destination.exists() else None
    data = dict(schema="msb.gis.intake.v1", source_sha256=digest,
                source_path=str(source), track_index=index, working_name=name.strip(),
                temporary_type=kind, start_waypoint=start, end_waypoint=end,
                status="Identified (not merged)",
                reviewed_utc=datetime.now(timezone.utc).isoformat())
    if previous is not None:
        data["previous_review"] = previous
    temp = destination.with_suffix(".json.tmp")
    temp.write_text(json.dumps(data, indent=2), encoding="utf8")
    temp.replace(destination)
    return destination

def open_intake(parent):
    win = tk.Toplevel(parent)
    win.title("MSB GIS Manager — Garmin Track Intake #428")
    win.geometry("1040x700")
    base = ttk.Frame(win, padding=12)
    base.pack(fill="both", expand=True)
    ttk.Label(base, text="Garmin Track Intake", font=("Segoe UI",16,"bold")).pack(anchor="w")
    ttk.Label(base, text="Read track → identify on aerial → suggest name/type → correct → Save & Next. Originals stay unchanged.").pack(anchor="w")
    src, master, intake = tk.StringVar(), tk.StringVar(), tk.StringVar()
    fields = [("Garmin GPX folder", src, True), ("Current master GPX", master, False),
              ("Existing Field-Recordings folder", intake, True)]
    for label, variable, isdir in fields:
        row = ttk.Frame(base); row.pack(fill="x", pady=3)
        ttk.Label(row, text=label, width=29).pack(side="left")
        ttk.Entry(row, textvariable=variable).pack(side="left", fill="x", expand=True)
        def browse(v=variable, d=isdir):
            value = filedialog.askdirectory(parent=win) if d else filedialog.askopenfilename(
                parent=win, filetypes=[("GPX", "*.gpx")])
            if value: v.set(value)
        ttk.Button(row, text="Browse", command=browse).pack(side="left")
    row = ttk.Frame(base); row.pack(fill="both", expand=True)
    queue = tk.Listbox(row, width=34, exportselection=False); queue.pack(side="left",fill="y")
    panel = ttk.Frame(row, padding=8); panel.pack(side="left",fill="both",expand=True)
    ttk.Label(panel, text="Selected track and waypoint suggestions").pack(anchor="w")
    drawing = tk.Canvas(panel,bg="#f0f2ed",height=290); drawing.pack(fill="both",expand=True)
    ttk.Label(panel, text="Map preview is not yet the calibrated 2019 aerial — operator aerial acceptance BLOCKED.",
              foreground="#8c3f11", wraplength=610).pack(anchor="w")
    start, end, name, kind = tk.StringVar(),tk.StringVar(),tk.StringVar(),tk.StringVar(value="Unknown")
    for label,var in [("Start waypoint",start),("End waypoint",end),("Working name",name)]:
        r=ttk.Frame(panel);r.pack(fill="x",pady=3)
        ttk.Label(r,text=label,width=19).pack(side="left")
        ttk.Entry(r,textvariable=var).pack(side="left",fill="x",expand=True)
    r=ttk.Frame(panel);r.pack(fill="x",pady=3)
    ttk.Label(r,text="Temporary type",width=19).pack(side="left")
    ttk.Combobox(r,textvariable=kind,values=KINDS,state="readonly").pack(side="left",fill="x",expand=True)
    status=tk.StringVar(value="Choose a mounted Garmin GPX folder, master and intake root.")
    ttk.Label(base,textvariable=status,wraplength=900).pack(anchor="w")
    state={"items":[],"waypoints":[]}
    def select(event=None):
        selection=queue.curselection()
        if not selection:return
        source,(idx,original,points)=state["items"][selection[0]]
        digest=source_digest(source)
        a,b=nearest(points[0],state["waypoints"]),nearest(points[-1],state["waypoints"])
        start.set(a[0][0] if a else "Unknown");end.set(b[0][0] if b else "Unknown")
        kind.set(type_hint(original+" "+source.stem))
        name.set(propose(kind.get(),start.get(),end.get()))
        receipt=reviewed_path(intake.get(),digest,idx)
        if receipt.exists():
            prior=json.loads(receipt.read_text(encoding="utf8"))
            name.set(prior.get("working_name",name.get()))
            kind.set(prior.get("temporary_type",kind.get()))
            start.set(prior.get("start_waypoint",start.get()))
            end.set(prior.get("end_waypoint",end.get()))
        drawing.delete("all");width=max(drawing.winfo_width(),550);height=max(drawing.winfo_height(),290)
        nearby=[w for w in state["waypoints"] if min(dist_ft((w[1],w[2]),p) for p in points)<250]
        allpts=points+[(w[1],w[2]) for w in nearby]
        lat0,lat1=min(x[0] for x in allpts),max(x[0] for x in allpts)
        lon0,lon1=min(x[1] for x in allpts),max(x[1] for x in allpts)
        def xy(p):
            return (28+(p[1]-lon0)/max(lon1-lon0,1e-8)*(width-56),
                    height-28-(p[0]-lat0)/max(lat1-lat0,1e-8)*(height-56))
        flat=[c for p in points for c in xy(p)]
        drawing.create_line(*flat,fill="#176bb5",width=3)
        for w in nearby:
            x,y=xy((w[1],w[2]))
            drawing.create_oval(x-3,y-3,x+3,y+3,fill="#b53d22")
            drawing.create_text(x+5,y-5,text=w[0],anchor="sw")
        status.set(f"{source.name} — {len(points)} vertices; start: {a[:3]}, end: {b[:3]}. Distances are suggestions only.")
    def load():
        try:
            if not Path(master.get()).is_file() or not Path(src.get()).is_dir() or not Path(intake.get()).is_dir():
                raise ValueError("Select existing Garmin folder, current master and intake directory")
            state["waypoints"]=parse(master.get())[1]
            state["items"]=[]
            for file in sorted(Path(src.get()).rglob("*")):
                if file.is_file() and file.suffix.lower()==".gpx":
                    for trk in parse(file)[0]:state["items"].append((file,trk))
            queue.delete(0,"end")
            for file,(idx,title,pts) in state["items"]:
                queue.insert("end",title or file.name)
            status.set(f"{len(state['items'])} tracks; {len(state['waypoints'])} master waypoints.")
            if state["items"]: queue.selection_set(0); select()
        except (OSError, ValueError, ET.ParseError) as e:
            messagebox.showerror("Intake stopped",str(e),parent=win)
    def next_item():
        try:
            selected=queue.curselection()
            if not selected: return
            file,(idx,_,_)=state["items"][selected[0]]
            path=save(intake.get(),file,idx,name.get(),kind.get(),start.get(),end.get())
            old=selected[0]
            queue.delete(old);queue.insert(old,name.get())
            if old+1 < len(state["items"]):
                queue.selection_clear(0,"end");queue.selection_set(old+1);queue.see(old+1);select()
            else:status.set("Saved: "+str(path)+" — last recording reviewed.")
        except (OSError, ValueError) as e:messagebox.showerror("Save stopped",str(e),parent=win)
    def suggest(*_):
        if start.get() and end.get():name.set(propose(kind.get(),start.get(),end.get()))
    ttk.Button(base,text="Read Garmin tracks (read only)",command=load).pack(anchor="w",pady=4)
    queue.bind("<<ListboxSelect>>",select)
    start.trace_add("write",lambda *_:None);end.trace_add("write",lambda *_:None)
    controls=ttk.Frame(panel);controls.pack(fill="x")
    ttk.Button(controls,text="Suggest name from selected endpoints",command=suggest).pack(side="left")
    ttk.Button(controls,text="Save & Next",command=next_item).pack(side="right")
    return win
