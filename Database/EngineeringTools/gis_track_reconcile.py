"""Reviewed GPX derivatives for #428; no shared-master or database writes.

The current ExpertGPS source SHA and original track ordinal bind every decision.
Track metadata stays with the explicitly chosen master track; only reviewed
recording geometry is substituted in a separate candidate.
"""
import hashlib
import json
import math
import re
import uuid
from datetime import datetime, timezone
from pathlib import Path
from xml.dom import minidom
import xml.etree.ElementTree as ET

NS = "http://www.topografix.com/GPX/1/1"
G = "{"+NS+"}"

def annual_history_evidence(track):
    """Group note-year references without inventing dated geometry.

    Release evidence for #319, not an implemented database history model.
    """
    by_year={}
    for field in ("comments","description"):
        for line in track.get(field,"").splitlines():
            for value in set(re.findall(r"\b(?:19|20)\d{2}\b",line)):
                year=int(value)
                entry=by_year.setdefault(year,dict(year=year,evidence=[],
                                  geometry_at_that_year="Unknown; current geometry is not a historical survey",
                                  needs_review=True))
                evidence=dict(field=field,text=line)
                if evidence not in entry["evidence"]:entry["evidence"].append(evidence)
    return [by_year[year] for year in sorted(by_year)]


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def tracks(path):
    root = ET.parse(path).getroot()
    if root.tag != G+"gpx":
        raise ValueError("Expected GPX 1.1")
    result = []
    for ordinal,node in enumerate(root.findall(G+"trk"),1):
        segments = [[(float(p.get("lat")),float(p.get("lon")))
                     for p in s.findall(G+"trkpt")] for s in node.findall(G+"trkseg")]
        result.append(dict(index=ordinal,name=node.findtext(G+"name") or "(unnamed)",
                           type=node.findtext(G+"type") or "",
                           comments=node.findtext(G+"cmt") or "",
                           description=node.findtext(G+"desc") or "",
                           metadata="\n".join(ET.tostring(c,encoding="unicode") for c in node
                                              if c.tag != G+"trkseg"),
                           segments=segments,points=[p for s in segments for p in s]))
    return result


def recording_vertices(path,ordinal):
    node=ET.parse(path).getroot().findall(G+"trk")[ordinal-1]
    result=[]
    for segment,s in enumerate(node.findall(G+"trkseg")):
        for p in s.findall(G+"trkpt"):
            result.append(dict(source_index=len(result),segment=segment,
                               lat=float(p.get("lat")),lon=float(p.get("lon"))))
    return result


def validate_vertices(vertices):
    if len(vertices)<2:
        raise ValueError("Keep at least two recording vertices")
    ids=[v["source_index"] for v in vertices]
    if ids != sorted(set(ids)):
        raise ValueError("Recording vertices must remain in their original order")
    for v in vertices:
        if not (math.isfinite(v["lat"]) and math.isfinite(v["lon"])
                and -90<=v["lat"]<=90 and -180<=v["lon"]<=180):
            raise ValueError("Invalid latitude or longitude")


def rank_matches(points,master_tracks,limit=12):
    """Rank by raw-to-master segment distance and reversible endpoints.

    Ranking is a review suggestion, never physical cable identity acceptance.
    """
    if not points:return []
    lat0=sum(p[0] for p in points)/len(points)
    def xy(p):
        return (p[1]*math.cos(math.radians(lat0))*364000,p[0]*364000)
    raw=[xy(p) for p in points]
    sample=raw[::max(1,len(raw)//30)]
    def distance(a,b):return math.hypot(a[0]-b[0],a[1]-b[1])
    def to_segment(p,a,b):
        dx,dy=b[0]-a[0],b[1]-a[1]
        t=max(0,min(1,((p[0]-a[0])*dx+(p[1]-a[1])*dy)/(dx*dx+dy*dy))) if dx or dy else 0
        return distance(p,(a[0]+t*dx,a[1]+t*dy))
    ranked=[]
    for track in master_tracks:
        if len(track["points"])<2:continue
        segs=[[xy(p) for p in s] for s in track["segments"]]
        edges=[(a,b) for s in segs for a,b in zip(s,s[1:])]
        if not edges:continue
        first,last=xy(track["points"][0]),xy(track["points"][-1])
        endpoint=min(distance(raw[0],first)+distance(raw[-1],last),
                     distance(raw[0],last)+distance(raw[-1],first))/2
        route=sum(min(to_segment(p,a,b) for a,b in edges) for p in sample)/len(sample)
        ranked.append(dict(track=track,endpoint_ft=round(endpoint,1),
                           route_ft=round(route,1),score=route+endpoint/2))
    return sorted(ranked,key=lambda r:r["score"])[:limit]


def retain(path,folder):
    path=Path(path);sha=digest(path)
    folder=Path(folder);folder.mkdir(parents=True,exist_ok=True)
    target=folder/(sha+".gpx")
    if not target.exists():
        with target.open("xb") as stream:stream.write(path.read_bytes())
    if digest(target)!=sha:raise ValueError("Retained source hash mismatch")
    return target


def accept_replacement(intake,master,master_sha,source,source_sha,raw_index,
                       master_index,vertices,review_note,action="replace"):
    if action not in ("replace","keep"):raise ValueError("Unknown review action")
    validate_vertices(vertices)
    if not review_note.strip():raise ValueError("Record the reason/evidence for this replacement")
    if digest(master)!=master_sha:raise ValueError("Master changed; reload and review against the latest file")
    if digest(source)!=source_sha:raise ValueError("Garmin recording changed; reload before accepting")
    original=recording_vertices(source,raw_index)
    for v in vertices:
        i=v["source_index"]
        if not 0<=i<len(original) or v["segment"]!=original[i]["segment"]:
            raise ValueError("Recording vertex lineage mismatch")
    chosen=next((t for t in tracks(master) if t["index"]==master_index),None)
    if chosen is None:raise ValueError("Chosen master track is unavailable")
    for existing in decisions(intake,master_sha):
        if (action=="replace" and existing.get("action","replace")=="replace" and existing["master_index"]==master_index
                and (existing["source_sha256"],existing["raw_index"])!=(source_sha,raw_index)):
            raise ValueError("Another recording already replaces this master track; review that decision first")
    folder=Path(intake)/"Reconciliation"/master_sha
    folder.mkdir(parents=True,exist_ok=True)
    # Immutable snapshots retain every original metadata field and old route.
    master_copy=retain(master,folder/"Sources")
    raw_copy=retain(source,folder/"Sources")
    if digest(master)!=master_sha or digest(source)!=source_sha:
        raise ValueError("Source changed during acceptance; review again")
    decision=dict(schema="msb.gis.track-replacement.v1",master_sha256=master_sha,
                  master_snapshot=str(master_copy),source_sha256=source_sha,
                  source_snapshot=str(raw_copy),source_path=str(source),raw_index=raw_index,
                  master_index=master_index,master_name=chosen["name"],vertices=vertices,
                  action=action,
                  review_note=review_note.strip(),accepted_utc=datetime.now(timezone.utc).isoformat(),
                  status="Accepted for working GPX candidate; not released to PostgreSQL")
    target=folder/(datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%f")+"-"+uuid.uuid4().hex+".json")
    with target.open("x",encoding="utf8") as stream:json.dump(decision,stream,indent=2)
    return target


def decisions(intake,master_sha):
    folder=Path(intake)/"Reconciliation"/master_sha
    latest={}
    for path in sorted(folder.glob("*.json")):
        d=json.loads(path.read_text(encoding="utf8"))
        if d.get("schema")!="msb.gis.track-replacement.v1":continue
        latest[(d["source_sha256"],d["raw_index"])]=d
    return list(latest.values())


def children(node,name):
    return [c for c in node.childNodes if c.nodeType==c.ELEMENT_NODE
            and c.namespaceURI==NS and c.localName==name]


def export_candidate(intake,master,master_sha,output):
    """Replace only trkseg nodes in a new GPX; all master metadata is retained."""
    if digest(master)!=master_sha:raise ValueError("Current master changed; reload and reconcile")
    reviewed=decisions(intake,master_sha)
    accepted=[d for d in reviewed if d.get("action","replace")=="replace"]
    if not accepted:raise ValueError("No accepted replacements for this master revision")
    targets=[d["master_index"] for d in accepted]
    if len(set(targets))!=len(targets):
        raise ValueError("Two recordings target the same master track; resolve the match before export")
    output=Path(output)
    if output.exists():raise ValueError("Choose a new output filename; existing files are never overwritten")
    if output.with_suffix(output.suffix+".review.json").exists():
        raise ValueError("A review manifest already exists for that filename")
    if output.resolve()==Path(master).resolve():raise ValueError("Cannot overwrite the shared master")
    doc=minidom.parse(str(master))
    master_nodes=children(doc.documentElement,"trk")
    for d in accepted:
        if d["master_sha256"]!=master_sha or digest(d["master_snapshot"])!=master_sha:
            raise ValueError("Accepted master snapshot changed")
        if digest(d["source_snapshot"])!=d["source_sha256"]:
            raise ValueError("Retained Garmin recording changed")
        validate_vertices(d["vertices"])
        rawdoc=minidom.parse(d["source_snapshot"])
        raw=children(rawdoc.documentElement,"trk")[d["raw_index"]-1]
        rawpoints=[p for s in children(raw,"trkseg") for p in children(s,"trkpt")]
        target=master_nodes[d["master_index"]-1]
        names=children(target,"name")
        original_name="".join(c.data for c in names[0].childNodes if c.nodeType==c.TEXT_NODE) if names else "(unnamed)"
        if original_name!=d["master_name"]:raise ValueError("Accepted master track identity mismatch")
        for old in children(target,"trkseg"):target.removeChild(old)
        segment=None;previous=None
        for v in d["vertices"]:
            if previous!=v["segment"]:
                segment=doc.createElementNS(NS,(target.prefix+":" if target.prefix else "")+"trkseg")
                target.appendChild(segment);previous=v["segment"]
            original_point=rawpoints[v["source_index"]]
            point=doc.importNode(original_point,True)
            # Garmin and ExpertGPS can reuse gpxtpx for different versions.
            # Retain the source's inherited bindings locally on each imported
            # point rather than changing the master's global namespace map.
            ancestors=[];ancestor=original_point
            while ancestor.nodeType==ancestor.ELEMENT_NODE:
                ancestors.append(ancestor);ancestor=ancestor.parentNode
            for ancestor in reversed(ancestors):
                for i in range(ancestor.attributes.length):
                    attr=ancestor.attributes.item(i)
                    if attr.name=="xmlns" or attr.name.startswith("xmlns:"):
                        point.setAttribute(attr.name,attr.value)
            point.setAttribute("lat",str(v["lat"]));point.setAttribute("lon",str(v["lon"]))
            segment.appendChild(point)
    # Namespace-qualified Garmin points also need any default GPX prefix.
    rawbytes=doc.toxml(encoding="utf-8")
    ET.fromstring(rawbytes)  # Reject malformed namespace output before creating it.
    if digest(master)!=master_sha:raise ValueError("Master changed during export")
    with output.open("xb") as stream:stream.write(rawbytes)
    manifest=output.with_suffix(output.suffix+".review.json")
    with manifest.open("x",encoding="utf8") as stream:
        json.dump(dict(schema="msb.gis.reviewed-master-candidate.v1",
                       base_master_sha256=master_sha,candidate_sha256=digest(output),
                       replacements=accepted,review_decisions=reviewed,
                       annual_history_policy=dict(record_grain="one version per physical track per year",
                           overall_start_year=2012,core_infrastructure_start_year=2014,
                           edit_by_edit_history=False,database_implementation="pending #319 acceptance"),
                       annual_history_evidence=[
                           dict(master_index=t["index"],master_name=t["name"],
                                years=annual_history_evidence(t))
                           for t in tracks(master) if annual_history_evidence(t)],
                       status="Working GPX only; PostgreSQL reconciliation/release pending"),
                  stream,indent=2)
    return output
