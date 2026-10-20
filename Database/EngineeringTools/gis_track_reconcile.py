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

ROUTE_NS = "urn:msb:gis:route-installation:1"


def read_network_catalog(path):
    data=json.loads(Path(path).read_text(encoding="utf8"))
    if data.get("data_mode")!="postgres" or data.get("format_version")!=1 or "revision" not in data:
        raise ValueError("Choose a PostgreSQL site reference snapshot with its revision")
    rows=data.get("networks")
    if not isinstance(rows,list):raise ValueError("Network table rows are missing")
    ids=set();codes=set()
    for row in rows:
        ident=row.get("site_network_id");code=row.get("network_code")
        if type(ident)!=int or ident<=0 or not isinstance(code,str) or not code.strip():
            raise ValueError("Invalid network table identity")
        if ident in ids or code.casefold() in codes:raise ValueError("Duplicate network table identity")
        ids.add(ident);codes.add(code.casefold())
    return dict(source_table="ref.site_network",revision=data["revision"],snapshot_sha256=digest(path),networks=rows)


def route_installation(kind, year="", designations="", catalog=None):
    """Explicit operator evidence, not inferred cable identities or test dates."""
    year=str(year or "").strip()
    if year and (not re.fullmatch(r"(?:19|20)\d{2}",year)):
        raise ValueError("Installation year must be four digits, or blank if unknown")
    labels=[v.strip().upper() for v in re.split(r"[,;\n]",designations) if v.strip()]
    if len(labels)!=len(set(labels)):
        raise ValueError("Each cable designation must occur only once on this route")
    if any(not re.fullmatch(r"[A-Z0-9][A-Z0-9_.-]*",v) for v in labels):
        raise ValueError("Use comma-separated cable designations, for example REG, E1.31, INET")
    if labels and kind.casefold()!="network":
        raise ValueError("Cable designations in this workflow apply only to Network routes")
    links=[]
    for label in labels:
        spare=bool(re.fullmatch(r"SPARE(?:[- ]\d+)?",label))
        row=next((r for r in (catalog or {}).get("networks",[]) if r["network_code"].casefold()==label.casefold()),None) if not spare else None
        links.append(dict(designation=label,site_network_id=row["site_network_id"] if row else None,
                          network_code=row["network_code"] if row else None,spare_designation=label if spare else None))
    return dict(schema="msb.gis.route-installation.v1",route_type=kind,
                year_installed=int(year) if year else None,cable_designations=labels,cable_assignments=links,network_catalog=catalog,
                evidence_source="operator",physical_cable_identity_status="pending reviewed reconciliation")


def validate_installation(kind,data):
    if data is None:return
    checked=route_installation(kind,data.get("year_installed"),", ".join(data.get("cable_designations",[])),data.get("network_catalog"))
    if checked!=data:raise ValueError("Installation metadata does not match the selected route type")


def installation_summary(data):
    parts=["Year installed: "+str(data.get("year_installed") or "Unknown")]
    if data["route_type"].casefold()=="network":
        parts.append("Networks: "+(", ".join(data["cable_designations"]) or "Unspecified"))
    return "\n".join(parts)


def map_label(node):
    """ExpertGPS Label on Map is the reviewed identity; GPS name is provenance."""
    extensions=node.find(G+"extensions")
    if extensions is not None:
        for child in extensions.iter():
            if child.tag.rsplit("}",1)[-1]=="label_text" and (child.text or "").strip():
                return child.text.strip()
    return node.findtext(G+"name") or "(unnamed)"

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
        result.append(dict(index=ordinal,name=map_label(node),gps_name=node.findtext(G+"name") or "",
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
                       master_index,vertices,review_note,action="replace",installation=None):
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
    validate_installation(chosen["type"],installation)
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
                  action=action,installation=installation,
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
        latest[(d["source_sha256"],d["raw_index"],d["master_index"],
                tuple(v["source_index"] for v in d["vertices"]) if d.get("action")=="add" else ())]=d
    return list(latest.values())


def accept_new_run(intake,master,master_sha,source,source_sha,raw_index,
                   vertices,name,kind,review_note,installation=None):
    """Accept one explicitly reviewed new run, never the entire device."""
    name=name.strip();kind=kind.strip()
    validate_installation(kind,installation)
    if not name or not kind or kind=="Unknown":
        raise ValueError("Give this new run a name and a known type before accepting")
    if not review_note.strip():raise ValueError("Record the evidence for this new run")
    validate_vertices(vertices)
    if digest(master)!=master_sha or digest(source)!=source_sha:
        raise ValueError("Source or master changed; reload before accepting")
    original=recording_vertices(source,raw_index)
    for v in vertices:
        i=v["source_index"]
        if not 0<=i<len(original) or v!=original[i]:
            raise ValueError("New-run points must come from the selected recording")
    points=[(v["lat"],v["lon"]) for v in vertices]
    prior=decisions(intake,master_sha)
    same=lambda d: (d["source_sha256"]==source_sha and d["raw_index"]==raw_index
                    and [v["source_index"] for v in d["vertices"]]==[v["source_index"] for v in vertices])
    for track in tracks(master):
        if name.casefold() in (track["name"].strip().casefold(),track["gps_name"].strip().casefold()):
            raise ValueError("That name already exists in the master. Review it as a replacement.")
        if track["points"]==points or track["points"]==points[::-1]:
            raise ValueError("This geometry already exists in the master. Review it before adding.")
    for d in prior:
        if d.get("action")=="add" and same(d):continue  # revise this same proposed segment
        if d.get("action")=="add" and d["master_name"].casefold()==name.casefold():
            raise ValueError("Another accepted new run already uses that name")
        if same(d) and d.get("action")=="replace":
            raise ValueError("This range already replaces a master run. Review that decision first.")
    folder=Path(intake)/"Reconciliation"/master_sha
    master_copy=retain(master,folder/"Sources");raw_copy=retain(source,folder/"Sources")
    if digest(master_copy)!=master_sha or digest(raw_copy)!=source_sha:
        raise ValueError("Source changed during acceptance")
    data=dict(schema="msb.gis.track-replacement.v1",action="add",master_index=0,
              master_name=name,new_type=kind,master_sha256=master_sha,
              master_snapshot=str(master_copy),source_sha256=source_sha,
              source_snapshot=str(raw_copy),source_path=str(source),raw_index=raw_index,
              vertices=vertices,installation=installation,review_note=review_note.strip(),
              accepted_utc=datetime.now(timezone.utc).isoformat(),
              status="Accepted new run for working GPX only")
    path=folder/(datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%f")+"-"+uuid.uuid4().hex+".json")
    with path.open("x",encoding="utf8") as stream:json.dump(data,stream,indent=2)
    return path


def children(node,name):
    return [c for c in node.childNodes if c.nodeType==c.ELEMENT_NODE
            and c.namespaceURI==NS and c.localName==name]


def export_candidate(intake,master,master_sha,output):
    """Replace only trkseg nodes in a new GPX; all master metadata is retained."""
    if digest(master)!=master_sha:raise ValueError("Current master changed; reload and reconcile")
    reviewed=decisions(intake,master_sha)
    accepted=[d for d in reviewed if d.get("action","replace") in ("replace","add")]
    if not accepted:raise ValueError("No accepted runs for this master revision")
    targets=[d["master_index"] for d in accepted if d.get("action")!="add"]
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
        if d.get("action")=="add":
            target=doc.createElementNS(NS,"trk")
            target.setAttribute("xmlns",NS)
            for tag,value in (("name",d["master_name"]),("cmt",d["review_note"]),("desc",installation_summary(d["installation"]) if d.get("installation") else ""),("type",d["new_type"])):
                element=doc.createElementNS(NS,tag)
                element.appendChild(doc.createTextNode(value));target.appendChild(element)
            root_extensions=children(doc.documentElement,"extensions")
            doc.documentElement.insertBefore(target,root_extensions[0] if root_extensions else None)
        else:
            target=master_nodes[d["master_index"]-1]
        names=children(target,"name")
        original_name="".join(c.data for c in names[0].childNodes if c.nodeType==c.TEXT_NODE) if names else "(unnamed)"
        if d.get("action")!="add" and d["master_name"] not in (
                original_name,tracks(master)[d["master_index"]-1]["name"]):
            # Parse through the full document so inherited namespace bindings remain available.
            actual=tracks(master)[d["master_index"]-1]["name"]
            if actual!=d["master_name"]:raise ValueError("Accepted master track identity mismatch")
        if d.get("installation"):
            data=d["installation"]
            expected_kind=d["new_type"] if d.get("action")=="add" else tracks(master)[d["master_index"]-1]["type"]
            checked=route_installation(expected_kind,data.get("year_installed"),", ".join(data.get("cable_designations",[])),data.get("network_catalog"))
            if checked!=data:raise ValueError("Installation metadata does not match the reviewed route type")
            extensions=children(target,"extensions")
            if extensions:extension=extensions[0]
            else:
                extension=doc.createElementNS(NS,(target.prefix+":" if target.prefix else "")+"extensions")
                old_segments=children(target,"trkseg")
                target.insertBefore(extension,old_segments[0] if old_segments else None)
            # Append reviewed evidence; retain all historical notes and extensions.
            evidence=doc.createElementNS(ROUTE_NS,"msbr:installation")
            evidence.setAttribute("xmlns:msbr",ROUTE_NS)
            evidence.setAttribute("year",str(data["year_installed"] or "unknown"))
            evidence.setAttribute("routeType",data["route_type"])
            evidence.setAttribute("source","operator")
            for label in data["cable_designations"]:
                cable=doc.createElementNS(ROUTE_NS,"msbr:designation")
                assignment=next(a for a in data["cable_assignments"] if a["designation"]==label)
                if assignment["site_network_id"] is not None:cable.setAttribute("siteNetworkId",str(assignment["site_network_id"]))
                cable.setAttribute("kind","spare" if assignment["spare_designation"] else "network")
                cable.appendChild(doc.createTextNode(label));evidence.appendChild(cable)
            extension.appendChild(evidence)
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
