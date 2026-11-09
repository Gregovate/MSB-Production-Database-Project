#!/usr/bin/env python3
"""#171 field handoff: correct GPS symbols IN A WORKING GPX, preserving tracks.

Never modify the authoritative master; require the known LPFT-PS test filename.
Backup the original bytes first. Re-parse after saving and verify exact waypoint
and route/track semantics except for mapped <sym> values.
"""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import sys
import xml.etree.ElementTree as ET
from garmin_bmp_derivatives import load_registry

NS="{http://www.topografix.com/GPX/1/1}"
EXPECTED="MSB-Park-Infrastructure-TEST-LPFT-PS and Icon alignnemt.gpx"

def fingerprint(x):
    return hashlib.sha256(x).hexdigest()

def norm(root, *, suppress_sym=False):
    import copy
    o=copy.deepcopy(root)
    if suppress_sym:
        for wp in o.findall(NS+"wpt"):
            s=wp.find(NS+"sym")
            if s is not None:
                wp.remove(s)
    return ET.tostring(o)

def run(path:Path, registry:Path, *, apply=False):
    if path.name != EXPECTED or not path.is_file():
        raise ValueError("Refusing anything other than the specified existing LPFT-PS TEST GPX")
    original=path.read_bytes()
    root=ET.fromstring(original)
    if root.tag!=NS+"gpx": raise ValueError("Expected GPX 1.1")
    source_norm=norm(root,suppress_sym=True)
    mapping={r["type"]:r["symbol"] for r in load_registry(registry)}
    modified=[]
    for wp in root.findall(NS+"wpt"):
        kind=wp.findtext(NS+"type")
        desired=mapping.get(kind)
        sym=wp.find(NS+"sym")
        if desired is None or (sym is not None and sym.text==desired):
            continue
        prior=sym.text if sym is not None else None
        if sym is None:
            sym=ET.Element(NS+"sym")
            idx=next((i for i,e in enumerate(wp) if e.tag in (NS+"type",NS+"extensions")),len(wp))
            wp.insert(idx,sym)
        sym.text=desired
        modified.append({"waypoint":wp.findtext(NS+"name"),"type":kind,"old":prior,"new":desired})
    if norm(root,suppress_sym=True)!=source_norm:
        raise ValueError("Unsafe non-symbol GPX semantic difference")
    result={"working_file":str(path),"before_sha256":fingerprint(original),
            "waypoints":len(root.findall(NS+"wpt")),
            "tracks":len(root.findall(NS+"trk")),"routes":len(root.findall(NS+"rte")),
            "symbol_corrections":len(modified),
            "changes_by_type":{k:sum(c["type"]==k for c in modified) for k in mapping}}
    if not apply:return result
    backup=path.with_name(path.name+".BEFORE-GARMIN-SYM.bak")
    if backup.exists():raise ValueError("Existing backup: stop; never overwrite it")
    with backup.open("xb") as fp:fp.write(original)
    if fingerprint(backup.read_bytes())!=fingerprint(original):raise ValueError("Backup verification failed")
    output=ET.tostring(root,encoding="utf-8",xml_declaration=True)
    # No write to the working file until semantic readback and backup accepted.
    parsed=ET.fromstring(output)
    if norm(parsed,suppress_sym=True)!=source_norm:raise ValueError("Export semantics changed")
    temporary=path.with_name(path.name+".garmin-pending")
    if temporary.exists():raise ValueError("Temporary output exists")
    with temporary.open("xb") as fp:fp.write(output)
    if norm(ET.fromstring(temporary.read_bytes()),suppress_sym=True)!=source_norm:
        raise ValueError("Temporary readback changed coordinates or tracks")
    import os
    os.replace(temporary,path)
    result["after_sha256"]=fingerprint(path.read_bytes())
    result["backup"]=str(backup)
    receipt=path.with_name(path.stem+".GARMIN-SYMBOL-RECEIPT.json")
    with receipt.open("x",encoding="utf-8") as fp:
        json.dump(dict(result,changes=modified),fp,indent=2)
    result["receipt"]=str(receipt)
    return result

if __name__=="__main__":
    p=argparse.ArgumentParser()
    p.add_argument("--test-gpx",type=Path,required=True)
    p.add_argument("--registry",type=Path,default=Path(__file__).with_name("garmin_symbol_registry.json"))
    p.add_argument("--apply",action="store_true")
    a=p.parse_args()
    try:
        print(json.dumps(run(a.test_gpx,a.registry,apply=a.apply),indent=2))
    except (ValueError,OSError,ET.ParseError) as e:
        print("STOP:",e,file=sys.stderr);sys.exit(1)
