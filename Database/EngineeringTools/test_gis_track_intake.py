"""#428 source-only safeguards. Run: python -m unittest test_gis_track_intake.py"""
import tempfile
import unittest
from pathlib import Path
from gis_track_intake import parse, nearest, type_hint, propose, save, source_digest, mercator, aerial_image, AERIAL_URL, fit_zoom

GPX = '<gpx xmlns="http://www.topografix.com/GPX/1/1"><wpt lat="43.1" lon="-87.1"><name>FE-00</name><type>Panel</type></wpt><wpt lat="43.101" lon="-87.102"><name>FE-07</name><type>OUT-Combo</type></wpt><trk><name>2026-10-20 NET</name><type>Network</type><trkseg><trkpt lat="43.1" lon="-87.1"/><trkpt lat="43.101" lon="-87.102"/></trkseg></trk></gpx>'

class IntakeTests(unittest.TestCase):
    def test_infrastructure_reference_filter_and_voltage_variants(self):
        import xml.etree.ElementTree as ET
        from gis_track_intake import infrastructure_waypoint, reference_track, road_or_trail
        for kind in ("Display Anchor","Light Pole","LP-Combo","LP_Power","Out-Combo",
                     "Outlet Power","Panel","Panel Auxiliary","WiFi AP","Transformer"):
            node=ET.fromstring('<wpt xmlns="http://www.topografix.com/GPX/1/1"><type>'+kind+'</type></wpt>')
            self.assertTrue(infrastructure_waypoint(node),kind)
        for kind in ("Stage","Camera","Hydrant","Trailhead","Waypoint","Building"):
            node=ET.fromstring('<wpt xmlns="http://www.topografix.com/GPX/1/1"><type>'+kind+'</type></wpt>')
            self.assertFalse(infrastructure_waypoint(node),kind)
        stage=ET.fromstring('<wpt xmlns="http://www.topografix.com/GPX/1/1"><name>Panel stage</name><type>Stage</type></wpt>')
        self.assertFalse(infrastructure_waypoint(stage))
        for kind in ("High Voltage","High Voltage 12-2","High Voltage 12-3","High Voltage Custom",
                     "Network","Primary","Abandoned","Road","Trail"):
            self.assertTrue(reference_track({"type":kind}),kind)
        self.assertFalse(reference_track({"type":"GPS Tracklog"}))
        self.assertTrue(road_or_trail({"type":"Road"}))
        self.assertTrue(road_or_trail({"type":"Trails"}))
        self.assertFalse(road_or_trail({"type":"Network"}))
        self.assertEqual(type_hint("High Voltage 12-2"),"High Voltage 12-2")
        self.assertEqual(type_hint("HV 12-3"),"High Voltage 12-3")
        self.assertEqual(type_hint("Maybe Abandoned/Dead"),"Maybe Abandoned/Dead")

    def test_close_zoom_preserves_registration_and_published_tile_limit(self):
        import io
        from PIL import Image
        from gis_track_intake import unproject, inches_per_pixel
        point=(43.778,-87.742)
        x,y=mercator(*point,24)
        lat,lon=unproject(x,y,24)
        self.assertAlmostEqual(lat,point[0])
        self.assertAlmostEqual(lon,point[1])
        self.assertLess(inches_per_pixel(point[0],24),.3)
        tile=io.BytesIO();Image.new("RGB",(256,256)).save(tile,format="PNG")
        calls=[]
        def fetch(url):
            calls.append(url);return tile.getvalue()
        image,(ox,oy)=aerial_image([point],560,320,24,fetch,center=point)
        self.assertEqual(image.size,(560,320))
        self.assertAlmostEqual(x-ox,280)
        self.assertAlmostEqual(y-oy,160)
        self.assertTrue(all("/20/" in url for url in calls))

    def test_waypoint_suggestion_and_type(self):
        with tempfile.TemporaryDirectory() as d:
            p=Path(d)/"raw.gpx";p.write_text(GPX)
            tracks,waypoints=parse(p)
            self.assertEqual(len(tracks),1)
            self.assertEqual(nearest(tracks[0][2][0],waypoints)[0][0],"FE-00")
            self.assertEqual(nearest(tracks[0][2][-1],waypoints)[0][0],"FE-07")
            self.assertEqual(type_hint(tracks[0][1]),"Network")
            self.assertEqual(propose("NET","FE-00","FE-07"),"NET FE-00 to FE-07")
    def test_save_archives_original_and_preserves_bytes(self):
        with tempfile.TemporaryDirectory() as d:
            root=Path(d);source=root/"raw.gpx";source.write_text(GPX)
            before=source.read_bytes();digest=source_digest(source)
            reviewed=save(root/"Field-Recordings",source,1,"NET FE-00 to FE-07","NET","FE-00","FE-07")
            self.assertTrue(reviewed.is_file())
            self.assertEqual(source.read_bytes(),before)
            self.assertEqual(len(list((root/"Field-Recordings").glob("*/Originals/*.gpx"))),1)
            self.assertEqual(source_digest(source),digest)
            save(root/"Field-Recordings",source,1,"NET FE-00 to FE-07","NET","FE-00","FE-07")
            self.assertEqual(len(list((root/"Field-Recordings").glob("*/Originals/*.gpx"))),1)
    def test_existing_aerial_xyz_calibration(self):
        import io
        from PIL import Image
        self.assertIn("evergreen-2019-v1/{z}/{x}/{y}.jpg", AERIAL_URL)
        origin=mercator(0,0,1)
        self.assertAlmostEqual(origin[0],256)
        self.assertAlmostEqual(origin[1],256)
        tile=io.BytesIO()
        Image.new("RGB",(256,256),(110,120,130)).save(tile,format="JPEG")
        called=[]
        def fetch(url):
            called.append(url)
            return tile.getvalue()
        rendered,offset=aerial_image([(43.778,-87.742),(43.77801,-87.74201)],256,256,zoom=19,fetch=fetch)
        self.assertEqual(rendered.size,(256,256))
        self.assertTrue(called)
        self.assertTrue(all("/maps/evergreen-2019-v1/19/" in u for u in called))
    def test_fit_zoom_keeps_full_track_visible(self):
        pts=[(43.778,-87.742),(43.779,-87.743)]
        z=fit_zoom(pts,550,290)
        self.assertGreaterEqual(z,14)
        self.assertLessEqual(z,20)
        xy=[mercator(*p,z) for p in pts]
        self.assertLessEqual(abs(xy[0][0]-xy[1][0]),550*0.82)
        self.assertLessEqual(abs(xy[0][1]-xy[1][1]),290*0.82)

    def test_unknown_type_not_forced(self):
        self.assertEqual(type_hint("2026-10-20 08:00"),"Unknown")
        self.assertEqual(type_hint("2026-10-14 11:19:07 Hvfe00 tfe04&02"),"High Voltage")
        self.assertEqual(type_hint("2026-10-14 11:26:10 Netfe00tfe15"),"Network")
        self.assertEqual(type_hint("New run 2026 lpfc01"),"Unknown")

    def test_source_and_master_change_block_review_before_archive(self):
        with tempfile.TemporaryDirectory() as d:
            root=Path(d); source=root/'raw.gpx'; master=root/'master.gpx'
            source.write_text(GPX); master.write_text(GPX)
            digest=source_digest(source); md=source_digest(master)
            source.write_text(GPX.replace('NET','HV'))
            with self.assertRaisesRegex(ValueError,'Recording changed'):
                save(root/'intake',source,1,'route','NET','A','B',expected_digest=digest)
            self.assertFalse((root/'intake').exists())
            source.write_text(GPX); master.write_text(GPX.replace('FE-00','FE-01'))
            with self.assertRaisesRegex(ValueError,'Master changed'):
                save(root/'intake',source,1,'route','NET','A','B',expected_digest=digest,
                     master=master,master_digest=md)
            self.assertFalse((root/'intake').exists())

    def test_segment_gaps_are_preserved_and_bad_coordinates_rejected(self):
        with tempfile.TemporaryDirectory() as d:
            source=Path(d)/'raw.gpx'
            source.write_text(GPX.replace('<trkpt lat="43.101"', '</trkseg><trkseg><trkpt lat="43.101"'))
            tracks,_=parse(source)
            self.assertEqual([len(s) for s in tracks[0][2].segments],[1,1])
            source.write_text(GPX.replace('43.101','nan'))
            with self.assertRaisesRegex(ValueError,'Invalid GPX'):
                parse(source)

    def test_uneven_sampling_does_not_clip_extreme_endpoint(self):
        import io
        from PIL import Image
        points=[(43.778,-87.742)]*100+[(43.779,-87.743)]
        width,height=550,290
        zoom=fit_zoom(points,width,height)
        tile=io.BytesIO(); Image.new('RGB',(256,256)).save(tile,format='JPEG')
        _,(ox,oy)=aerial_image(points,width,height,zoom,fetch=lambda _:tile.getvalue())
        for lat,lon in points:
            x,y=mercator(lat,lon,zoom)
            self.assertTrue(0 <= x-ox <= width)
            self.assertTrue(0 <= y-oy <= height)

    def test_unrenderable_extent_stops_instead_of_clipping(self):
        with self.assertRaisesRegex(ValueError,'extends beyond'):
            fit_zoom([(0,0),(45,45)],550,290)

    def test_tk_read_save_next_and_reopen(self):
        import tkinter as tk
        import time
        from tkinter import ttk
        from unittest.mock import patch
        from PIL import Image
        from gis_track_intake import open_intake
        def walk(w):
            yield w
            for child in w.winfo_children():
                yield from walk(child)
        def fake_map(points,width,height,zoom,center=None):
            x,y=mercator(*(center or points[0]),zoom)
            return Image.new('RGB',(width,height)),(x-width/2,y-height/2)
        with tempfile.TemporaryDirectory() as d:
            rootdir=Path(d); raw=rootdir/'Garmin'; raw.mkdir()
            master=rootdir/'master.gpx'; master.write_text(GPX)
            source=raw/'raw.gpx'; source.write_text(GPX)
            intake=rootdir/'Field-Recordings'; intake.mkdir()
            before=(source.read_bytes(), master.read_bytes())
            root=tk.Tk(); root.withdraw()
            self.addCleanup(root.destroy)
            errors=[]
            with patch('gis_track_intake.find_garmin_gpx_dirs',return_value=[]), \
                 patch('gis_track_intake.aerial_image',side_effect=fake_map) as map_fetch, \
                 patch('gis_track_intake.messagebox.showerror',side_effect=lambda *a,**k:errors.append(a)):
                win=open_intake(root); root.update()
                self.assertEqual(next(w for w in walk(win) if isinstance(w,tk.Listbox)).cget("selectmode"),"extended")
                entries=[w for w in walk(win) if type(w) is ttk.Entry]
                for entry,value in zip(entries,[str(raw),str(master),str(intake)]):
                    entry.delete(0,'end'); entry.insert(0,value)
                buttons={w.cget('text'):w for w in walk(win) if isinstance(w,ttk.Button)}
                for label in ['Read Garmin tracks (read only)','Save identification only']:
                    button=buttons[label]
                    self.assertTrue(button.winfo_ismapped(),label)
                    self.assertLessEqual(button.winfo_rooty()+button.winfo_height(),
                                         win.winfo_rooty()+win.winfo_height(),label)
                # Enlarging the map must never hide identification or save tools.
                buttons['Hide folders'].invoke(); root.update()
                for entry in entries[3:]:
                    self.assertTrue(entry.winfo_ismapped())
                for label in ['Save identification only','Suggest name from selected endpoints',
                              'Match and name from master','Export GPX for ExpertGPS']:
                    self.assertTrue(buttons[label].winfo_ismapped(),label)
                self.assertFalse(entries[0].winfo_ismapped())
                buttons['Show folders'].invoke(); root.update()
                self.assertTrue(entries[0].winfo_ismapped())
                buttons['Hide folders'].invoke(); root.update()
                buttons['Read Garmin tracks (read only)'].invoke()
                deadline=time.monotonic()+3
                while time.monotonic()<deadline:
                    root.update(); time.sleep(.02)
                    if any('2019 MSB aerial' in str(w.cget('text')) for w in walk(win) if isinstance(w,ttk.Label)):
                        break
                entries[-1].delete(0,'end');entries[-1].insert(0,'Operator corrected name')
                canvas=next(w for w in walk(win) if isinstance(w,tk.Canvas))
                plates=canvas.find_withtag('label-background')
                self.assertTrue(plates)
                self.assertEqual(canvas.itemcget(plates[0],'fill'),'#ffffff')
                image_item=canvas.find_withtag('map-content')[0]
                position=canvas.coords(image_item)
                canvas.event_generate('<ButtonPress-1>',x=150,y=150)
                canvas.event_generate('<B1-Motion>',x=200,y=175)
                self.assertEqual(canvas.coords(image_item),[position[0]+50,position[1]+25])
                canvas.event_generate('<ButtonRelease-1>',x=200,y=175)
                deadline=time.monotonic()+3
                while time.monotonic()<deadline:
                    root.update();time.sleep(.02)
                    if any('2019 MSB aerial' in str(w.cget('text')) for w in walk(win) if isinstance(w,ttk.Label)):
                        break
                buttons['6-inch detail'].invoke()
                deadline=time.monotonic()+3
                while time.monotonic()<deadline:
                    root.update();time.sleep(.02)
                    if any('zoom 24' in str(w.cget('text')) for w in walk(win) if isinstance(w,ttk.Label)):
                        break
                self.assertEqual(entries[-1].get(),'Operator corrected name')
                self.assertTrue(any('zoom 24' in str(w.cget('text')) for w in walk(win) if isinstance(w,ttk.Label)))
                prior_call=map_fetch.call_args
                win.geometry('1300x850')
                deadline=time.monotonic()+3
                while time.monotonic()<deadline:
                    root.update();time.sleep(.02)
                    if (canvas.image_ref.width(),canvas.image_ref.height()) == (canvas.winfo_width(),canvas.winfo_height()):
                        break
                self.assertEqual((canvas.image_ref.width(),canvas.image_ref.height()),
                                 (canvas.winfo_width(),canvas.winfo_height()))
                self.assertEqual(map_fetch.call_args.kwargs['zoom'],24)
                self.assertEqual(map_fetch.call_args.kwargs['center'],prior_call.kwargs['center'])
                self.assertEqual(entries[-1].get(),'Operator corrected name')
                buttons['Save identification only'].invoke();root.update()
                self.assertFalse(errors)
                receipt=next((intake/'Reviews').glob('*.json'))
                import json
                saved=json.loads(receipt.read_text())
                self.assertEqual(saved['working_name'],'Operator corrected name')
                self.assertEqual(saved['master_sha256'],source_digest(master))
                buttons['Read Garmin tracks (read only)'].invoke();root.update()
                self.assertEqual(entries[-1].get(),'Operator corrected name')
                self.assertEqual((source.read_bytes(),master.read_bytes()),before)
                deadline=time.monotonic()+3
                while time.monotonic()<deadline:
                    root.update();time.sleep(.02)
                    if any('2019 MSB aerial' in str(w.cget('text')) for w in walk(win) if isinstance(w,ttk.Label)):
                        break
                self.assertFalse(errors)
                self.assertTrue(next(w for w in walk(win) if isinstance(w,tk.Listbox)).curselection())
                buttons['Match and name from master'].invoke();root.update()
                review=next(w for w in walk(win) if w.winfo_name()=="run_review")
                self.assertFalse(any(isinstance(w,ttk.Treeview) for w in walk(review)))
                self.assertFalse(isinstance(review,tk.Toplevel))
                metadata=next(w for w in walk(review) if isinstance(w,tk.Text) and str(w.cget("state"))=="disabled")
                self.assertIn("Master track #",metadata.get("1.0","end"))
                combo=next(w for w in walk(review) if isinstance(w,tk.Listbox))
                combo.selection_set(0);combo.event_generate('<<ListboxSelect>>');root.update()
                deadline=time.monotonic()+3
                while time.monotonic()<deadline:
                    root.update();time.sleep(.02)
                    if any('2019 MSB aerial' in str(w.cget('text')) for w in walk(win) if isinstance(w,ttk.Label)):
                        break
                note=next(w for w in walk(review) if isinstance(w,tk.Text) and str(w.cget('state'))=='normal')
                note.insert('1.0','Disposable fixture: verified matching track')
                next(w for w in walk(review) if isinstance(w,ttk.Checkbutton)).invoke()
                next(w for w in walk(review) if isinstance(w,ttk.Button) and w.cget('text')=='Save match & Next').invoke()
                root.update()
                import gis_track_reconcile as reconcile
                self.assertEqual(len(reconcile.decisions(intake,source_digest(master))),1)
                output=rootdir/'ExpertGPS-working.gpx'
                with patch('gis_track_intake.filedialog.asksaveasfilename',return_value=str(output)):
                    buttons['Export GPX for ExpertGPS'].invoke();root.update()
                self.assertTrue(output.is_file())
                self.assertEqual(parse(output),parse(master))
                self.assertTrue(output.with_suffix('.gpx.review.json').is_file())
                self.assertFalse(errors)
                self.assertEqual((source.read_bytes(),master.read_bytes()),before)

if __name__=="__main__":unittest.main()
