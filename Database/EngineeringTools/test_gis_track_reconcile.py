import copy
import json
import tempfile
import unittest
from pathlib import Path
import xml.etree.ElementTree as ET
import gis_track_reconcile as r
from gis_track_intake import parse

MASTER='''<gpx xmlns="http://www.topografix.com/GPX/1/1" xmlns:x="urn:expert" version="1.1">
<wpt lat="43.778" lon="-87.742"><name>Stage label</name><type>Stage</type><extensions><x:note>keep stage in master</x:note></extensions></wpt>
<wpt lat="43.778" lon="-87.742"><name>FE-10</name><type>OUT-Combo</type></wpt>
<trk><name>HV FE-10 to FE-02</name><cmt>Repaired 2026</cmt><desc>Installed 2017; spare conduit</desc><type>High Voltage</type>
<extensions><x:label>Historical label</x:label><x:year>2017</x:year></extensions>
<trkseg><trkpt lat="43.778" lon="-87.742"/><trkpt lat="43.7782" lon="-87.7422"/></trkseg></trk>
<trk><name>Other track</name><desc>2020 untouched</desc><trkseg><trkpt lat="43.8" lon="-87.8"/><trkpt lat="43.81" lon="-87.81"/></trkseg></trk></gpx>'''
RAW='''<gpx xmlns="http://www.topografix.com/GPX/1/1" xmlns:g="urn:garmin" version="1.1"><trk><name>New Garmin</name>
<trkseg><trkpt lat="43.778" lon="-87.742"><time>2026-10-19T08:00:00Z</time><extensions><g:quality>original</g:quality></extensions></trkpt>
<trkpt lat="43.7781" lon="-87.7421"/><trkpt lat="43.7782" lon="-87.7422"/></trkseg>
<trkseg><trkpt lat="43.7783" lon="-87.7423"/><trkpt lat="43.7784" lon="-87.7424"/></trkseg></trk></gpx>'''


class ReconcileTests(unittest.TestCase):
    def test_map_label_wins_without_rewriting_gps_name(self):
        self.master.write_text(MASTER.replace('<name>FE-10</name>', '<name>OLD-GPS</name><extensions><x:label_text>FE-10</x:label_text></extensions>').replace('<x:label>Historical label</x:label>', '<x:label_text>Reviewed HV label</x:label_text>'))
        self.assertEqual(parse(self.master)[1][1][0], 'FE-10')
        self.assertEqual(r.tracks(self.master)[0]['name'], 'Reviewed HV label')
        self.accept()
        out=r.export_candidate(self.intake,self.master,r.digest(self.master),self.root/'labels.gpx')
        self.assertEqual(r.tracks(out)[0]['gps_name'], 'HV FE-10 to FE-02')
        self.assertEqual(r.tracks(out)[0]['name'], 'Reviewed HV label')

    def test_new_run_is_named_selected_idempotent_and_preserves_master(self):
        original=self.master.read_bytes()
        vertices=r.recording_vertices(self.raw,1)[:3]
        def accept(name='NET new segment'):
            return r.accept_new_run(self.intake,self.master,r.digest(self.master),self.raw,r.digest(self.raw),
                                    1,vertices,name,'Network','Reviewed new physical run')
        accept();accept('NET corrected segment')
        self.assertEqual(len(r.decisions(self.intake,r.digest(self.master))),1)
        out=r.export_candidate(self.intake,self.master,r.digest(self.master),self.root/'new.gpx')
        old=r.tracks(self.master);new=r.tracks(out)
        self.assertEqual(new[:2],old)
        self.assertEqual(len(new),3)
        self.assertEqual(new[-1]['name'],'NET corrected segment')
        self.assertEqual(new[-1]['type'],'Network')
        self.assertEqual(len(new[-1]['points']),3)
        self.assertEqual(parse(out)[1],parse(self.master)[1])
        self.assertEqual(self.master.read_bytes(),original)
        with self.assertRaisesRegex(ValueError,'already exists'):
            accept('HV FE-10 to FE-02')
        with self.assertRaisesRegex(ValueError,'known type'):
            r.accept_new_run(self.intake,self.master,r.digest(self.master),self.raw,r.digest(self.raw),
                            1,vertices,'Unnamed type','Unknown','reviewed')

    def test_one_walk_updates_two_runs_with_separate_ranges_and_history(self):
        vertices=r.recording_vertices(self.raw,1)
        self.accept(vertices[:3])
        r.accept_replacement(self.intake,self.master,r.digest(self.master),self.raw,r.digest(self.raw),
                             1,2,vertices[3:],"Second run on the same walk")
        self.assertEqual(len(r.decisions(self.intake,r.digest(self.master))),2)
        out=r.export_candidate(self.intake,self.master,r.digest(self.master),self.root/"multi.gpx")
        old=r.tracks(self.master);new=r.tracks(out)
        for a,b in zip(old,new):
            self.assertEqual(a["metadata"],b["metadata"])
        self.assertEqual([len(t["points"]) for t in new],[3,2])
        self.assertEqual(new[1]["points"][0],(vertices[3]["lat"],vertices[3]["lon"]))
        # Correcting the first run must not discard the second run.
        self.accept(vertices[:2])
        self.assertEqual(len(r.decisions(self.intake,r.digest(self.master))),2)

    def test_nearby_overlays_do_not_depend_on_raw_name_or_type(self):
        from gis_track_intake import nearby_runs,run_color,suggested_range
        points=parse(self.raw)[0][0][2]
        nearby=nearby_runs(points,r.tracks(self.master))
        self.assertEqual([t["index"] for t in nearby],[1])
        self.assertEqual(suggested_range(points,nearby[0]),(1,3))
        for kind,color in (("Network","#0066ff"),("High Voltage 12-3","#ff2020"),("Primary","#ff8c00")):
            self.assertEqual(run_color({"type":kind}),color)

    def test_annual_history_groups_notes_not_individual_edits(self):
        history=r.annual_history_evidence(dict(comments="2014 installed\n2014 corrected",
                                              description="2012 survey\nUpdated 2026, repaired 2026"))
        self.assertEqual([h["year"] for h in history],[2012,2014,2026])
        self.assertEqual(len(history[1]["evidence"]),2)
        self.assertTrue(all(h["needs_review"] for h in history))
        self.assertEqual(r.annual_history_evidence(dict(description="Installation year unknown")),[])
    def test_shared_network_route_export_and_year_without_invented_date(self):
        labels="REG, E1.31, INET, AUX-E, AUX-F, AUX-G, AUX-H, SPARE-1"
        data=r.route_installation("Network","2026",labels)
        self.assertEqual(data["year_installed"],2026)
        self.assertEqual(len(data["cable_assignments"]),8)
        self.assertEqual(data["cable_assignments"][-1]["spare_designation"],"SPARE-1")
        self.assertIsNone(data["cable_assignments"][-1]["site_network_id"])
        r.accept_new_run(self.intake,self.master,r.digest(self.master),self.raw,r.digest(self.raw),1,
                         r.recording_vertices(self.raw,1),"NET shared route","Network","Install notes retained",installation=data)
        out=r.export_candidate(self.intake,self.master,r.digest(self.master),self.root/"shared.gpx")
        exported=r.tracks(out)
        self.assertEqual(len(exported),3)  # two originals, exactly one added route
        self.assertEqual(exported[-1]["comments"],"Install notes retained")
        self.assertEqual(exported[-1]["description"],"Year installed: 2026\nNetworks: "+labels)
        node=ET.parse(out).getroot().findall(r.G+"trk")[-1]
        self.assertEqual(len(node.findall(".//{"+r.ROUTE_NS+"}designation")),8)
        manifest=json.loads(out.with_suffix(".gpx.review.json").read_text())
        self.assertEqual(manifest["replacements"][0]["installation"],data)
        self.assertEqual(r.tracks(self.master),exported[:2])

    def test_installation_preserves_old_notes_and_extensions_on_replacement(self):
        data=r.route_installation("High Voltage","2026")
        r.accept_replacement(self.intake,self.master,r.digest(self.master),self.raw,r.digest(self.raw),1,1,
                             r.recording_vertices(self.raw,1),"New evidence",installation=data)
        out=r.export_candidate(self.intake,self.master,r.digest(self.master),self.root/"history.gpx")
        old,new=r.tracks(self.master)[0],r.tracks(out)[0]
        self.assertEqual(old["comments"],new["comments"])
        self.assertEqual(old["description"],new["description"])
        self.assertEqual(ET.parse(out).getroot().findtext(".//{urn:expert}year"),"2017")
        self.assertIsNone(r.route_installation("High Voltage")["year_installed"])
        with self.assertRaises(ValueError):r.route_installation("High Voltage","2026","REG")
        with self.assertRaises(ValueError):r.route_installation("Network","26","REG")
        with self.assertRaises(ValueError):r.route_installation("Network","2026","REG, reg")

    def test_network_table_identity_and_spare_remain_distinct(self):
        snapshot=self.root/"catalog.json"
        snapshot.write_text(json.dumps(dict(data_mode="postgres",format_version=1,revision=7,
            networks=[dict(site_network_id=42,network_code="REG",network_kind="LOR")])))
        catalog=r.read_network_catalog(snapshot)
        data=r.route_installation("Network","2026","REG, SPARE-1",catalog)
        self.assertEqual(data["cable_assignments"][0]["site_network_id"],42)
        self.assertIsNone(data["cable_assignments"][1]["site_network_id"])
        self.assertEqual(data["network_catalog"]["revision"],7)
        snapshot.write_text('{}')
        with self.assertRaises(ValueError):r.read_network_catalog(snapshot)

    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup)
        self.root=Path(self.temp.name)
        self.master=self.root/"master.gpx";self.master.write_text(MASTER)
        self.raw=self.root/"raw.gpx";self.raw.write_text(RAW)
        self.intake=self.root/"intake"

    def accept(self,vertices=None):
        return r.accept_replacement(self.intake,self.master,r.digest(self.master),self.raw,r.digest(self.raw),
                                    1,1,vertices or r.recording_vertices(self.raw,1),"Verified same installed cable")

    def test_only_stage_reference_hidden_not_deleted(self):
        self.assertEqual([w[0] for w in parse(self.master,exclude_stages=True)[1]],["FE-10"])
        self.assertEqual(len(parse(self.master)[1]),2)

    def test_match_ranking_prefers_near_route(self):
        match=r.rank_matches(parse(self.raw)[0][0][2],r.tracks(self.master))
        self.assertEqual(match[0]["track"]["index"],1)
        self.assertLess(match[0]["route_ft"],match[1]["route_ft"])

    def test_polished_export_retains_history_extensions_and_unrelated_features(self):
        vertices=r.recording_vertices(self.raw,1)
        vertices.pop(1);vertices[-1]["lon"]=-87.74245
        decision=self.accept(vertices)
        out=self.root/"reviewed.gpx"
        r.export_candidate(self.intake,self.master,r.digest(self.master),out)
        self.assertEqual(self.master.read_text(),MASTER)
        self.assertEqual(self.raw.read_text(),RAW)
        before=ET.parse(self.master).getroot();after=ET.parse(out).getroot()
        oldtrack=before.findall(r.G+"trk")[0];newtrack=after.findall(r.G+"trk")[0]
        oldmeta=[ET.tostring(e) for e in oldtrack if e.tag!=r.G+"trkseg"]
        newmeta=[ET.tostring(e) for e in newtrack if e.tag!=r.G+"trkseg"]
        self.assertEqual(oldmeta,newmeta)
        self.assertEqual(ET.tostring(before.findall(r.G+"trk")[1]),ET.tostring(after.findall(r.G+"trk")[1]))
        self.assertEqual([ET.tostring(w) for w in before.findall(r.G+"wpt")],
                         [ET.tostring(w) for w in after.findall(r.G+"wpt")])
        self.assertEqual([len(s.findall(r.G+"trkpt")) for s in newtrack.findall(r.G+"trkseg")],[2,2])
        pts=newtrack.findall(".//"+r.G+"trkpt")
        self.assertEqual(pts[0].findtext(r.G+"time"),"2026-10-19T08:00:00Z")
        self.assertEqual(pts[0].findtext(".//{urn:garmin}quality"),"original")
        self.assertAlmostEqual(float(pts[-1].get("lon")),-87.74245)
        d=json.loads(decision.read_text())
        self.assertEqual(Path(d["master_snapshot"]).read_bytes(),self.master.read_bytes())
        self.assertEqual(Path(d["source_snapshot"]).read_bytes(),self.raw.read_bytes())

    def test_stale_master_and_duplicate_target_stop(self):
        self.accept()
        old=r.digest(self.master)
        self.master.write_text(MASTER.replace("spare conduit","new installation note"))
        with self.assertRaisesRegex(ValueError,"changed"):
            r.export_candidate(self.intake,self.master,old,self.root/"out.gpx")
        self.master.write_text(MASTER)
        other=self.root/"other.gpx";other.write_text(RAW.replace("New Garmin","Different recording"))
        with self.assertRaisesRegex(ValueError,"already replaces"):
            r.accept_replacement(self.intake,self.master,r.digest(self.master),other,r.digest(other),
                                 1,1,r.recording_vertices(other,1),"Conflicting replacement")

    def test_invalid_polish_and_snapshot_tampering_stop(self):
        with self.assertRaises(ValueError):
            self.accept([dict(source_index=0,segment=0,lat=float("nan"),lon=0),
                         dict(source_index=1,segment=0,lat=0,lon=0)])
        d=json.loads(self.accept().read_text())
        Path(d["source_snapshot"]).write_text(RAW+" ")
        with self.assertRaisesRegex(ValueError,"changed"):
            r.export_candidate(self.intake,self.master,r.digest(self.master),self.root/"out.gpx")

    def test_garmin_namespace_version_does_not_change_master_extensions(self):
        self.master.write_text(MASTER.replace('xmlns:x="urn:expert"','xmlns:x="urn:expert" xmlns:g="urn:garmin-v2"'))
        self.accept()
        out=r.export_candidate(self.intake,self.master,r.digest(self.master),self.root/"out.gpx")
        root=ET.parse(out).getroot()
        self.assertEqual(root.findtext(".//{urn:garmin}quality"),"original")
        self.assertEqual(root.findtext(".//{urn:expert}year"),"2017")


if __name__=="__main__":unittest.main()
