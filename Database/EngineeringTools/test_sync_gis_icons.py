"""Disposable MSB #171 icon sync regression suite; never touches real G: assets."""
import csv
import io
import json
import os
from pathlib import Path
import struct
import subprocess
import tempfile
import unittest
import zlib
import zipfile
from unittest.mock import patch

from sync_gis_icons import (IconError, MAX_PX, canonical_sources, destination_preflight,
                            png_canvas, run, sha, sha_file, svg_canvas, source_freshness_warnings,
                            prepare_run, apply_canonical, make_stage, readme_bytes, preview_readme_bytes, README_URL)


def png(w, h):
    # Minimal real 8-bit truecolor+alpha PNG for all source-canvas checks.
    def chunk(tag, data):
        return struct.pack('>I', len(data)) + tag + data + struct.pack('>I', zlib.crc32(tag + data) & 0xffffffff)
    ihdr = struct.pack('>IIBBBBB', w, h, 8, 6, 0, 0, 0)
    data = b''.join(b'\x00' + b'\x00\x22\x99\xff' * w for _ in range(h))
    return b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', ihdr) + chunk(b'IDAT', zlib.compress(data)) + chunk(b'IEND', b'')


def svg(width, height, extras=''):
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 32 32">{extras}</svg>'.encode()


class CanvasTests(unittest.TestCase):
    def test_smaller_axis(self):
        self.assertEqual(svg_canvas('car.svg', svg('32px', '18px')), (32, 18))
        self.assertEqual(svg_canvas('tiny.svg', svg('16', '32')), (16, 32))
    def test_units_and_size(self):
        for w, h in [('121', '121'), ('32mm', '32mm'), ('32', '33'), ('32', '32.5'), ('0', '20'), ('32cm', '30')]:
            with self.subTest(w=w, h=h), self.assertRaises(IconError):
                svg_canvas('antenna-l.svg', svg(w, h))
    def test_missing_units(self):
        with self.assertRaises(IconError):
            svg_canvas('bad.svg', b'<svg xmlns="http://www.w3.org/2000/svg" height="32"/>')
    def test_external_asset_and_editor_metadata(self):
        linked='<image xmlns:xlink="http://www.w3.org/1999/xlink" xlink:href="file:///temp/icon.png"/>'
        with self.assertRaises(IconError): svg_canvas('bad.svg', svg(32,32,linked))
        editor='<g xmlns:inkscape="http://www.inkscape.org/namespaces/inkscape" inkscape:label="layer" />'
        with self.assertRaises(IconError): svg_canvas('bad.svg', svg(32,32,editor))
    def test_png_validation(self):
        self.assertEqual(png_canvas(png(16,32), 'ok.png'), (16,32))
        with self.assertRaises(IconError): png_canvas(png(121,121), 'big.png')


class ProcessTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.plain = self.root / 'Plain'
        self.plain.mkdir()
        self.dest = self.root / 'png'
        self.readme = self.root / 'readme.txt'
        self.readme.write_text('https://webassets.sheboyganlights.org/images/symbols/\n', encoding='utf-8')
        self.sources = {'lp.svg': (32,32), 'antenna-l.svg': (16, 32), 'antenna-r.svg': (24, 24)}
        for name, (w, h) in self.sources.items():
            (self.plain / name).write_bytes(svg(w,h))
        self.args = type('Args', (), dict(plain=str(self.plain), canonical_png=str(self.dest),
                         readme=str(self.readme), inkscape='fake-inkscape', report_parent=str(self.root), apply=False))()

    def tearDown(self):
        self.temp.cleanup()

    def fake_render(self, args, **_):
        src = Path(args[1])
        output = Path(args[3].split('=',1)[1])
        w, h = svg_canvas(src.name, src.read_bytes())
        output.write_bytes(png(w,h))
        return subprocess.CompletedProcess(args,0,'','')

    def mocked_run(self):
        with patch('sync_gis_icons.choose_inkscape', return_value='fake-inkscape'), patch('sync_gis_icons.subprocess.run', self.fake_render):
            return run(self.args)

    def test_preview_without_this_users_expertgps_readme(self):
        # Command Center workstation may never have used ExpertGPS.
        # Step 1 and its staging ZIP cannot demand any local TopoGrafix file.
        self.readme.unlink()
        summary = self.mocked_run()
        self.assertEqual(summary['source_svg_count'], 3)
        with zipfile.ZipFile(summary['staging_zip']) as bundle:
            self.assertEqual(bundle.read('msb/readme.txt'), preview_readme_bytes())
            self.assertEqual(bundle.read('msb/readme.txt'), (README_URL + '\n').encode())
        self.assertFalse(self.readme.exists(), 'Preview must not install ExpertGPS')
        self.assertFalse(self.dest.exists(), 'Preview must not write canonical G: PNGs')

    def test_preview_ignores_wrong_user_expertgps_readme(self):
        # An unrelated/misconfigured profile must not corrupt the portable
        # bundle or block G: source validation. Step 5 still rejects it.
        self.readme.write_text('https://wrong.example/icons/\n', encoding='utf-8')
        before = self.readme.read_bytes()
        summary = self.mocked_run()
        with zipfile.ZipFile(summary['staging_zip']) as bundle:
            self.assertEqual(bundle.read('msb/readme.txt'), preview_readme_bytes())
        self.assertEqual(self.readme.read_bytes(), before)

    def test_branded_shortcut_and_window_use_checked_in_icon(self):
        here = Path(__file__).parent
        artwork = here / 'assets' / 'MSB-Icon-Library-Manager.ico'
        source = here / 'assets' / 'MSB-Icon-Library-Manager.svg'
        self.assertTrue(source.is_file())
        blob = artwork.read_bytes()
        self.assertEqual(blob[:4], b'\x00\x00\x01\x00')
        self.assertEqual(struct.unpack_from('<H', blob, 4)[0], 1)
        self.assertEqual(struct.unpack_from('<I', blob, 18)[0], 22)
        self.assertEqual(blob[22:30], b'\x89PNG\r\n\x1a\n')
        self.assertIn('IconLocation', (here / 'Install-MSB-Icon-Library-Shortcut.cmd').read_text())
        self.assertIn('iconbitmap', (here / 'icon_library_manager.pyw').read_text())

    def test_local_expertgps_button_gets_independent_full_width_row(self):
        # Display scaling used to crowd the long Step 5 label alongside web
        # publication controls, making installation hard to identify.
        gui = (Path(__file__).parent / 'icon_library_manager.pyw').read_text()
        self.assertIn('local_controls = ttk.Frame(root,', gui)
        self.assertIn('publication_controls = ttk.Frame(root,', gui)
        self.assertIn('self.local_png_btn.pack(side="left")', gui)
        self.assertIn('self.web_publish_btn.pack(side="left"', gui)
        self.assertIn('self.web_png_btn.pack(side="left")', gui)
        self.assertLess(gui.index('local_controls = ttk.Frame(root,'),
                        gui.index('footer = ttk.Frame(root,'))

    def test_verified_shared_cache_does_not_require_inkscape(self):
        # First authoring PC validated the G: release-history cache.
        first = self.mocked_run()
        self.assertEqual(first['source_svg_count'], 3)
        self.readme.unlink()  # No local ExpertGPS dependency on this PC either.
        # Second field PC may have no Inkscape executable, but every cached
        # PNG is still bound to the current source SHA, PNG SHA and canvas.
        with patch('sync_gis_icons.choose_inkscape',
                   side_effect=AssertionError('No CLI lookup on full cache')), \
             patch('sync_gis_icons.subprocess.run',
                   side_effect=AssertionError('Do not render a cache hit')):
            second = run(self.args)
        self.assertEqual(second['source_svg_count'], 3)
        self.assertFalse(self.dest.exists())
        log = (Path(second['staging_zip']).parent / 'Inkscape-export.log').read_text()
        self.assertIn('3 hash-verified unchanged icons reused; 0 newly rendered', log)

    def test_missing_cache_requires_renderer_for_only_missing_icon(self):
        first = self.mocked_run()
        first_stage = Path(first['staging_zip']).parent
        (first_stage / 'msb' / 'antenna-l.png').unlink()
        rendered = []
        def count_render(args, **kw):
            rendered.append(Path(args[1]).name)
            return self.fake_render(args, **kw)
        with patch('sync_gis_icons.choose_inkscape', return_value='fake-inkscape') as lookup, \
             patch('sync_gis_icons.subprocess.run', side_effect=count_render):
            updated = run(self.args)
        lookup.assert_called_once_with('fake-inkscape')
        self.assertEqual(rendered, ['antenna-l.svg'])
        self.assertEqual(updated['source_svg_count'], 3)
        log = (Path(updated['staging_zip']).parent / 'Inkscape-export.log').read_text()
        self.assertIn('2 hash-verified unchanged icons reused; 1 newly rendered', log)

    def test_stale_svg_cache_and_missing_cli_fails_closed(self):
        self.mocked_run()
        (self.plain / 'antenna-r.svg').write_bytes(svg(20, 28))
        with patch('sync_gis_icons.choose_inkscape',
                   side_effect=IconError('Inkscape CLI unavailable')), \
             patch('sync_gis_icons.subprocess.run',
                   side_effect=AssertionError('No renderer executable available')):
            with self.assertRaisesRegex(IconError,
                                        'antenna-r.svg: no current SHA-256-verified preview cache'):
                run(self.args)
        self.assertFalse(self.dest.exists())
        self.assertTrue(list(self.root.glob('MSB-GIS-Icon-Sync-*/ERROR.txt')))

    def test_preview_progress_monotonic_and_has_filename(self):
        events = []
        stage = make_stage(self.root)
        def report(phase, current, total, detail):
            events.append((phase, current, total, detail))
        with patch('sync_gis_icons.choose_inkscape', return_value='fake-inkscape'), \
             patch('sync_gis_icons.subprocess.run', self.fake_render):
            sources, rows, archive = prepare_run(self.plain, stage, 'fake-inkscape',
                                                 readme_bytes(self.readme), progress=report)
        self.assertEqual(len(rows), 3)
        self.assertTrue(archive.is_file())
        self.assertEqual(events[0][0], 'validate')
        self.assertIsNone(events[0][2])
        completed = [e for e in events if e[0] == 'render' and
                     e[3].endswith(('cached', 'rendered'))]
        self.assertEqual([e[1] for e in completed], [1, 2, 3])
        self.assertTrue(all(e[2] == 3 for e in completed))
        self.assertTrue(all('.svg' in e[3] for e in completed))
        self.assertIn('package', [e[0] for e in events])
        self.assertEqual(events[-1][:3], ('ready', 3, 3))

    def test_apply_progress_only_completes_after_verified_receipts(self):
        stage = make_stage(self.root)
        with patch('sync_gis_icons.choose_inkscape', return_value='fake-inkscape'), \
             patch('sync_gis_icons.subprocess.run', self.fake_render):
            sources, rows, _archive = prepare_run(self.plain, stage, 'fake-inkscape',
                                                   readme_bytes(self.readme))
        events = []
        receipt = apply_canonical(self.dest, stage, rows, sources, self.plain,
                                  progress=lambda *values: events.append(values))
        self.assertEqual(len(receipt), 3)
        self.assertEqual(events[0][0], 'preflight')
        self.assertEqual([e[1] for e in events if e[0]=='apply' and
                          e[3].endswith('hash verified')], [1, 2, 3])
        self.assertEqual(events[-1][:3], ('apply', 3, 3))
        self.assertTrue((stage/'MSB_GIS_Promotion_Receipt.csv').exists())
        self.assertTrue(all(sha_file(self.dest/r['PNG']) == r['PNG_SHA256'] for r in rows))

    def test_dry_run_then_additive_apply(self):
        summary = self.mocked_run()
        self.assertEqual(summary['source_svg_count'], 3)
        self.assertFalse(self.dest.exists())
        self.assertEqual(summary['plan'], {'add':3,'replace':0,'identical':0})
        self.args.apply=True
        summary2 = self.mocked_run()
        self.assertEqual(summary2['status'],'applied')
        self.assertEqual(len(list(self.dest.glob('*.png'))),3)
        summary3 = self.mocked_run()
        self.assertEqual(summary3['plan'], {'add':0,'replace':0,'identical':3})
        self.assertTrue(list(self.root.glob('MSB-GIS-Icon-Sync-*/MSB_GIS_Promotion_Receipt.csv')))

    def test_changed_source_backed_up(self):
        self.args.apply=True
        self.mocked_run()
        orig=self.dest/'antenna-r.png'
        old=orig.read_bytes()
        orig.write_bytes(png(1,1))
        summary=self.mocked_run()
        self.assertEqual(summary['plan'], {'add':0,'replace':1,'identical':2})
        self.assertEqual(orig.read_bytes(),old)
        backup_paths=list(self.root.glob('MSB-GIS-Icon-Sync-*/backups-before-replacement/antenna-r.png'))
        self.assertEqual(len(backup_paths),1)
        self.assertEqual(backup_paths[0].read_bytes(),png(1,1))

    def test_file_case_conflict_aborts_before_any_writes(self):
        self.dest.mkdir()
        (self.dest / 'Antenna-L.png').write_bytes(png(16,32))
        self.args.apply=True
        with self.assertRaises(IconError): self.mocked_run()
        self.assertEqual(len(list(self.dest.iterdir())),1)

    def test_reject_wrong_plain_units_without_copy(self):
        (self.plain/'antenna-r.svg').write_bytes(svg('32mm','32mm'))
        self.args.apply=True
        with self.assertRaises(IconError): self.mocked_run()
        self.assertFalse(self.dest.exists())

    def test_updating_one_icon_preserves_others(self):
        self.args.apply=True
        self.mocked_run()
        old={(p.name,sha_file(p)) for p in self.dest.iterdir()}
        (self.plain/'antenna-l.svg').write_bytes(svg(20,25))
        summary=self.mocked_run()
        self.assertEqual(summary['plan'], {'add':0,'replace':1,'identical':2})
        after={(p.name,sha_file(p)) for p in self.dest.iterdir()}
        self.assertEqual(len(old & after),2)

    def test_hash_checked_cache_skips_unchanged_icons(self):
        rendered = []
        def count_render(args, **kwargs):
            rendered.append(Path(args[1]).name)
            return self.fake_render(args, **kwargs)
        with patch('sync_gis_icons.choose_inkscape', return_value='fake-inkscape'), \
             patch('sync_gis_icons.subprocess.run', count_render):
            first = run(self.args)
            self.assertEqual(first['source_svg_count'], 3)
            self.assertEqual(len(rendered), 3)

            # Repeat check / preview: hashes unchanged, no Inkscape launches.
            second = run(self.args)
            self.assertEqual(second['source_svg_count'], 3)
            self.assertEqual(len(rendered), 3)
            self.assertIn('CACHE HIT', (Path(second['staging_zip']).parent /
                                         'Inkscape-export.log').read_text())

            # Master-only edits do not affect Plain; saving corrected Plain does.
            (self.plain/'antenna-r.svg').write_bytes(svg(20, 28))
            third = run(self.args)
            self.assertEqual(third['source_svg_count'], 3)
            self.assertEqual(rendered[-1], 'antenna-r.svg')
            self.assertEqual(len(rendered), 4)
            self.assertEqual(third['plan'], {'add':3,'replace':0,'identical':0})

    def test_corrupted_cache_is_not_trusted(self):
        rendered = []
        def count_render(args, **kwargs):
            rendered.append(Path(args[1]).name)
            return self.fake_render(args, **kwargs)
        with patch('sync_gis_icons.choose_inkscape', return_value='fake-inkscape'), \
             patch('sync_gis_icons.subprocess.run', count_render):
            first = run(self.args)
            old_stage = Path(first['staging_zip']).parent
            (old_stage/'msb'/'lp.png').write_bytes(b'corrupt PNG')
            second = run(self.args)
            self.assertEqual(second['source_svg_count'], 3)
            self.assertEqual(rendered.count('lp.svg'), 2)
            self.assertEqual(len(rendered), 4)

    def test_stale_master_and_layered_family_get_review_warning(self):
        masters = self.root / "Masters"
        masters.mkdir()
        m = masters / "lp-combo-inkscape.svg"
        m.write_bytes(svg(32,32))
        source = canonical_sources(self.plain)
        import time
        os.utime(m, (time.time()+300, time.time()+300))
        (self.plain / "lp-network.svg").write_bytes(svg(32, 32))
        source = canonical_sources(self.plain)
        warnings = source_freshness_warnings(self.plain, masters, source)
        self.assertTrue(any("lp-network.svg" in x and "lp-combo-inkscape.svg" in x for x in warnings))

    def test_source_set_detects_added_unstaged_icon(self):
        old = canonical_sources(self.plain)
        (self.plain/'wifi-new.svg').write_bytes(svg(32,20))
        from sync_gis_icons import check_source_snapshot
        with self.assertRaises(IconError): check_source_snapshot(self.plain, old)


if __name__=='__main__':
    unittest.main()