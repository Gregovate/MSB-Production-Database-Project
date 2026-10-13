"""#171 disposable small-screen Tk layout smoke test.

Only creates a temporary application window. Never clicks install/publish,
reads HKCU, opens ExpertGPS or touches live G:/GPX/Production files.
Run under xvfb-run on Linux or on a test desktop with an active GUI.
"""
import runpy
import tempfile
import tkinter as tk
from tkinter import ttk
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch
import unittest

HERE = Path(__file__).resolve().parent
Manager = runpy.run_path(str(HERE / "icon_library_manager.pyw"),
                         run_name="msb_gui_layout_check")["Manager"]


def walk(widget):
    yield widget
    for child in widget.winfo_children():
        yield from walk(child)


class SmallScreenLayoutTests(unittest.TestCase):
    def test_primary_actions_and_close_fit_without_maximizing(self):
        for width, height, scaling in ((930, 615, 1.0), (930, 615, 1.35),
                                       (800, 500, 1.0)):
            with self.subTest(viewport=(width, height), scaling=scaling):
                root = tk.Tk()
                try:
                    root.tk.call("tk", "scaling", scaling)
                    manager = Manager(root)
                    root.geometry(f"{width}x{height}")
                    root.update_idletasks()
                    buttons = {
                        str(w.cget("text")): w for w in walk(root)
                        if isinstance(w, (tk.Button, ttk.Button))
                    }
                    expected = [
                        "1. Check and preview icons",
                        "2. Save approved PNG changes",
                        "3. Review/publish Plain SVGs to web",
                        "4. Publish PNGs to web",
                        "5. Install PNGs for this ExpertGPS user",
                        "6. Compare GIS workstation release (READ ONLY)",
                        "Submit laptop cropped-map proposal",
                        "Inspect this PC / compare with laptop (READ ONLY)",
                        "Review laptop alignment — this PC (READ ONLY)",
                        "Close",
                    ]
                    for label in expected:
                        button = buttons[label]
                        # The label must be wholly within the application's
                        # client viewport, not merely present in widget tree.
                        x = button.winfo_rootx() - root.winfo_rootx()
                        y = button.winfo_rooty() - root.winfo_rooty()
                        self.assertGreaterEqual(x, 0, (label, width, scaling))
                        self.assertGreaterEqual(y, 0, (label, height, scaling))
                        self.assertLessEqual(x + button.winfo_width(),
                                             root.winfo_width(),
                                             (label, width, scaling, x))
                        self.assertLessEqual(y + button.winfo_height(),
                                             root.winfo_height(),
                                             (label, height, scaling, y))
                    self.assertIn("Not verified", manager.profile_release_status.get())
                finally:
                    root.destroy()


    def test_source_candidate_version_is_visible_and_not_release_approval(self):
        # Laptop operator needs visible exact code candidate identity. The SHA
        # refers to this checkout, not the approved workstation GIS release.
        root = tk.Tk()
        try:
            manager = Manager(root)
            root.update_idletasks()
            title = root.title()
            self.assertIn("V0.4.2-native-types-gated", title)
            self.assertIn(manager.build_identity, title)
            labels = [
                str(w.cget("text")) for w in walk(root)
                if isinstance(w, ttk.Label)
            ]
            self.assertTrue(any("PR #378 CANDIDATE" in line
                                and manager.build_identity in line
                                for line in labels))
            self.assertIn("Not verified", manager.profile_release_status.get())
        finally:
            root.destroy()

    def test_pc_proposal_button_previews_before_save_and_cancel_is_inert(self):
        # No real HKCU or G: access: inject a disposable preflight response.
        root = tk.Tk()
        try:
            manager = Manager(root)
            sample = {
                "status": "Read-only preflight", "hostname": "YOGA-GREG",
                "type_count": 59, "png_count": 37, "map_count": 1,
                "destination": r"G:\\MSB GIS\\Proposals\\YOGA-GREG",
                "review_count": 1,
                "review_items": [
                    {"type": "Anchor", "reason": "Historical/unknown MSB filename",
                     "url": "https://example.test/msb/Anchor.png"}],
                "review_source_sha256": "a" * 64,
            }
            calls = []
            def fake_collect(*args, **kwargs):
                calls.append(kwargs)
                if kwargs.get("save"):
                    raise AssertionError("GUI must not save before confirmation")
                return sample
            def fake_async(work, done):
                try:
                    done(work(), None)
                except Exception as exc:
                    done(None, str(exc))
            with patch.dict(
                    Manager.review_current_profile.__globals__,
                    {"prepare_laptop_proposal": fake_collect}), \
                 patch.object(manager, "async_operation", side_effect=fake_async), \
                 patch("gis_workstation_proposal.workstation_hostname", return_value="YOGA-GREG"):
                manager.review_current_profile()
                root.update_idletasks()
                dialogs = [w for w in root.winfo_children()
                           if isinstance(w, tk.Toplevel)]
                self.assertEqual(len(dialogs), 1)
                dialog = dialogs[0]
                self.assertIn("UNAPPROVED", dialog.title())
                viewer = [w for w in walk(dialog)
                          if isinstance(w, tk.Text)][0]
                self.assertIn("Anchor.png", viewer.get("1.0", "end"))
                self.assertEqual(len(calls), 1)
                self.assertFalse(calls[0]["save"])
                options = {
                    str(w.cget("text")): w for w in walk(dialog)
                    if isinstance(w, ttk.Button)
                }
                self.assertIn("Save UNAPPROVED proposal to shared G:", options)
                with patch("tkinter.messagebox.askyesno", return_value=False):
                    options["Save UNAPPROVED proposal to shared G:"].invoke()
                self.assertEqual(len(calls), 1)
                options["Cancel"].invoke()
                self.assertFalse(dialog.winfo_exists())
        finally:
            root.destroy()

    def test_confirmed_gui_proposal_requires_rechecked_review_fingerprint(self):
        # No real G:, registry or PNG operations. Confirmed GUI callback must
        # invoke the engine with the exact approved-in-review snapshot digest.
        root = tk.Tk()
        try:
            manager = Manager(root)
            preview = {
                "status": "Read-only preflight", "hostname": "YOGA-GREG",
                "type_count": 59, "png_count": 37, "map_count": 1,
                "destination": r"G:\\MSB GIS\\Proposals\\YOGA-GREG",
                "review_count": 1,
                "review_items": [{"type": "Anchor",
                                  "reason": "Historical/unknown filename",
                                  "url": "https://example.test/msb/Anchor.png"}],
                "review_source_sha256": "b" * 64,
            }
            save_receipt = {
                "hostname": "YOGA-GREG",
                "destination": preview["destination"] + r"\\saved.json",
                "proposal_sha256_not_approval": "c" * 64,
            }
            called = []
            def fake_engine(*args, **kwargs):
                called.append(kwargs)
                return save_receipt if kwargs.get("save") else preview
            def fake_async(work, done):
                done(work(), None)
            with patch.dict(
                    Manager.review_current_profile.__globals__,
                    {"prepare_laptop_proposal": fake_engine}), \
                 patch.object(manager, "async_operation", side_effect=fake_async), \
                 patch("tkinter.messagebox.askyesno", return_value=True), \
                 patch("tkinter.messagebox.showinfo") as acknowledged, \
                 patch("gis_workstation_proposal.workstation_hostname", return_value="YOGA-GREG"):
                manager.review_current_profile()
                dialog = [w for w in root.winfo_children()
                          if isinstance(w, tk.Toplevel)][0]
                buttons = [w for w in walk(dialog)
                           if isinstance(w, ttk.Button) and
                           w.cget("text").startswith("Save UNAPPROVED")]
                self.assertEqual(len(buttons), 1)
                buttons[0].invoke()
                self.assertEqual(len(called), 2)
                self.assertFalse(called[0]["save"])
                self.assertTrue(called[1]["save"])
                self.assertEqual(
                    called[1]["expected_source_sha256"],
                    preview["review_source_sha256"])
                self.assertFalse(dialog.winfo_exists())
                self.assertTrue(acknowledged.called)
                self.assertIn("UNAPPROVED proposal saved", manager.status.get())
                self.assertIn("Not verified", manager.profile_release_status.get())
        finally:
            root.destroy()

    def test_office_recon_chooses_existing_full_map_and_never_mutates(self):
        root = tk.Tk()
        try:
            manager = Manager(root)
            sample = {
                "hostname": "MSB-OFFICE", "type_count": 28,
                "reverse_count": 13, "selected_map": "Full Office Aerial",
                "map_image_verified": True,
                "png_matched": 0, "png_missing": 37,
                "png_different": 0, "png_total": 37,
                "fingerprint": "a" * 64,
                "profile": {"types": {}, "maps": {}, "local_png_status": {}},
            }
            seen = []
            def scan(plain, dest, *, map_name):
                seen.append(map_name)
                return sample
            def immediate(work, done):
                try:
                    done(work(), None)
                except Exception as exc:
                    done(None, str(exc))
            with patch.dict(
                    Manager.inspect_this_pc.__globals__,
                    {"list_scanned_map_names": lambda: ["Full Office Aerial"],
                     "read_observation": scan}), \
                 patch.object(manager, "async_operation", side_effect=immediate):
                manager.inspect_this_pc()
                root.update_idletasks()
                chooser = [w for w in root.winfo_children()
                           if isinstance(w, tk.Toplevel)][0]
                choices = [w for w in walk(chooser)
                           if isinstance(w, tk.Listbox)][0]
                self.assertEqual(choices.get(0), "Full Office Aerial")
                controls = [
                    w for w in walk(chooser)
                    if isinstance(w, ttk.Button)
                    and w.cget("text") == "Inspect selected map (READ ONLY)"]
                self.assertEqual(len(controls), 1)
                controls[0].invoke()
                self.assertEqual(seen, ["Full Office Aerial"])
                reviews = [
                    w for w in root.winfo_children()
                    if isinstance(w, tk.Toplevel) and w.winfo_exists()]
                self.assertEqual(len(reviews), 1)
                review = reviews[0]
                self.assertIn("not synchronized", review.title())
                visible_headings = [
                    str(w.cget("text")) for w in walk(review)
                    if isinstance(w, ttk.Label)
                ]
                self.assertTrue(any(
                    "GIS RECONNAISSANCE" in label and
                    "NOT SYNCHRONIZED" in label
                    for label in visible_headings))
                buttons = [str(w.cget("text")) for w in walk(review)
                           if isinstance(w, ttk.Button)]
                self.assertIn("Compare with YOGA-GREG laptop", buttons)
                self.assertIn("Save THIS PC observation to shared G:", buttons)
                self.assertIn("Not verified", manager.profile_release_status.get())
                # No save/comparison is performed merely by opening review.
                [w for w in walk(review) if isinstance(w, ttk.Button)
                 and w.cget("text") == "Close"][0].invoke()
        finally:
            root.destroy()

    def test_office_comparison_copy_and_explicit_shared_export(self):
        # The entire 138-line-style diff is usable without selecting Tk text.
        # Everything here is in-memory. No real Shared Drive or HKCU access.
        root = tk.Tk()
        try:
            manager = Manager(root)
            office = {
                "hostname": "MSB-OFFICE-PC", "type_count": 28,
                "reverse_count": 27, "selected_map": "EvergreenParkCropped",
                "map_image_verified": True, "png_matched": 0,
                "png_missing": 32, "png_different": 5, "png_total": 37,
                "fingerprint": "a" * 64,
                "profile": {"types": {}, "maps": {}, "local_png_status": {}},
            }
            compare = {
                "rows": [("GPS Symbol reverse differs", "Flag, Blue", "",
                          "Office: Outlet Power | Laptop: Display Anchor")],
                "office_type_count": 28, "laptop_type_count": 59,
                "laptop_maps": ["2019 Ortho Cropped for GPS Export"],
                "laptop_proposal_sha256": "b" * 64,
            }
            saves = []
            def fake_save(result, observation, *, shared_root):
                saves.append((result, observation))
                return {"text_file": r"G:\\MSB GIS\\comparison.txt",
                        "text_sha256": "c" * 64,
                        "json_file": r"G:\\MSB GIS\\comparison.json",
                        "differences": 1}
            def immediate(work, done):
                done(work(), None)
            with patch.dict(
                    Manager.show_pc_observation.__globals__,
                    {"compare_with_laptop": lambda *args, **kwargs: compare,
                     "save_comparison_report": fake_save}), \
                 patch.object(manager, "async_operation", side_effect=immediate), \
                 patch("tkinter.filedialog.askopenfilename",
                       return_value="fixture-laptop-proposal.json"):
                manager.show_pc_observation(office)
                review = [w for w in root.winfo_children()
                          if isinstance(w, tk.Toplevel)][0]
                compare_button = [w for w in walk(review)
                                  if isinstance(w, ttk.Button) and
                                  str(w.cget("text")).startswith("Compare with")][0]
                compare_button.invoke()
                reports = [w for w in review.winfo_children()
                           if isinstance(w, tk.Toplevel)]
                self.assertEqual(len(reports), 1)
                diff = reports[0]
                buttons = {str(w.cget("text")): w for w in walk(diff)
                           if isinstance(w, ttk.Button)}
                self.assertIn("Copy entire report", buttons)
                self.assertIn("Save report to shared G:", buttons)
                self.assertTrue(any(
                    "READ-ONLY DIFFERENCE REPORT" in str(w.cget("text"))
                    for w in walk(diff) if isinstance(w, ttk.Label)))
                buttons["Copy entire report"].invoke()
                self.assertIn("Flag, Blue", diff.clipboard_get())
                self.assertIn("28", diff.clipboard_get())
                with patch("tkinter.messagebox.askyesno", return_value=False):
                    buttons["Save report to shared G:"].invoke()
                self.assertEqual(saves, [])
                with patch("tkinter.messagebox.askyesno", return_value=True), \
                     patch("tkinter.messagebox.showinfo") as shown:
                    buttons["Save report to shared G:"].invoke()
                self.assertEqual(len(saves), 1)
                self.assertTrue(shown.called)
                self.assertIn("comparison differences saved",
                              manager.status.get())
                self.assertIn("Not verified", manager.profile_release_status.get())
        finally:
            root.destroy()

    def test_office_repair_ui_is_explicitly_gated_before_any_registry_write(self):
        root = tk.Tk()
        try:
            manager = Manager(root)
            preview = {
                "office_pc_hostname": "MSB-OFFICE-PC",
                "master_pc_hostname": "YOGA-GREG",
                "laptop_type_count": 59, "laptop_reverse_count": 40,
                "office_types_before": 28, "office_reverse_before": 27,
                "type_actions": [
                    {"action": "remove_obsolete_Office_Type",
                     "type": "Display", "current": {}, "laptop": None}],
                "reverse_actions": [
                    {"action": "set", "gps_symbol": "Flag, Blue",
                     "office": "Outlet Power", "laptop": "Display Anchor"}],
                "png_actions": [{"action": "install_missing",
                                  "file": "pole-yellow.png"}],
                "required_gates": ["Local rollback exists", "GPX preserved"],
                "native_source_kinds_available": False,
            }
            writes = []
            def fake_apply(*args, **kwargs):
                writes.append(kwargs)
                raise AssertionError("No Office mutation during cancel")
            with patch.dict(
                    Manager.show_office_repair_plan.__globals__,
                    {"apply_office_repair": fake_apply}), \
                 patch("tkinter.messagebox.askyesno", return_value=False):
                manager.show_office_repair_plan(
                    "pinned-G-proposal.json", preview, "a" * 64)
                dialog = [w for w in root.winfo_children()
                          if isinstance(w, tk.Toplevel)][0]
                viewer = [w for w in walk(dialog)
                          if isinstance(w, tk.Text)][0]
                self.assertIn("Office GPX settings repair", dialog.title())
                self.assertIn("Display", viewer.get("1.0", "end"))
                self.assertIn("Flag, Blue", viewer.get("1.0", "end"))
                buttons = {str(w.cget("text")): w for w in walk(dialog)
                           if isinstance(w, ttk.Button)}
                self.assertIn("Back up and repair Office GPX settings", buttons)
                self.assertIn("Restore previous Office backup…", buttons)
                self.assertEqual(str(buttons["Back up and repair Office GPX settings"].cget("state")), "disabled")
                self.assertIn("lacks native", viewer.get("1.0", "end"))
                buttons["Back up and repair Office GPX settings"].invoke()
                self.assertEqual(writes, [])
                buttons["Close without changes"].invoke()
                self.assertFalse(dialog.winfo_exists())
        finally:
            root.destroy()

    def test_other_pc_alignment_preview_has_no_install_button(self):
        root = tk.Tk()
        try:
            manager = Manager(root)
            report = {
                "target_pc_hostname": "SHOW-TEST-PC",
                "office_types_before": 37, "laptop_type_count": 59,
                "office_reverse_before": 19, "laptop_reverse_count": 54,
                "type_actions": [], "reverse_actions": [],
                "png_actions": [], "required_gates": [],
            }
            manager.show_target_alignment_review(report, "a" * 64)
            dialog = [w for w in root.winfo_children()
                      if isinstance(w, tk.Toplevel)][0]
            self.assertIn("NOT INSTALLABLE", dialog.title())
            labels = [str(w.cget("text")) for w in walk(dialog)
                      if isinstance(w, ttk.Label)]
            self.assertTrue(any("NO INSTALL" in x for x in labels))
            buttons = [str(w.cget("text")) for w in walk(dialog)
                       if isinstance(w, ttk.Button)]
            self.assertEqual(buttons, ["Close"])
        finally:
            root.destroy()

    def test_cancel_step6_clears_stale_png_stop_without_registry_changes(self):
        # A preceding Step 4 filename-case collision must not look like a
        # Step 6 failure after the operator cancels the manifest picker.
        root = tk.Tk()
        try:
            manager = Manager(root)
            manager.status.set("Public web PNG library: preflight blocked")
            manager.progress_count.set("Stopped")
            previous = manager.profile_release_status.get()
            with patch("tkinter.filedialog.askopenfilename", return_value=""):
                manager.check_workstation()
            self.assertIn("canceled", manager.status.get())
            self.assertEqual(manager.progress_count.get(), "Canceled")
            self.assertEqual(manager.profile_release_status.get(), previous)
            # Canceling the second, administrator-SHA prompt is also inert.
            manager.status.set("Public web PNG library: preflight blocked")
            with patch("tkinter.filedialog.askopenfilename", return_value="fixture.json"), \
                 patch("tkinter.simpledialog.askstring", return_value=None):
                manager.check_workstation()
            self.assertIn("canceled", manager.status.get())
            self.assertEqual(manager.profile_release_status.get(), previous)
        finally:
            root.destroy()

    def test_preview_png_fits_or_scrolls_in_compact_window(self):
        # Regression for real laptop screenshots: cropped antenna, car and
        # container images with no preview scrollbar after compact UI change.
        with tempfile.TemporaryDirectory() as temp:
            root = tk.Tk()
            try:
                root.tk.call("tk", "scaling", 1.35)
                manager = Manager(root)
                root.geometry("800x500")
                manager.staged = Path(temp)
                icons = manager.staged / "msb"
                icons.mkdir()
                manager.dest = Path(temp) / "canonical"
                manager.plan = {"replace": []}
                root.update_idletasks()
                for name, width, height in (
                    ("antenna-l.png", 32, 32),
                    ("antenna-r.png", 32, 32),
                    ("car-l.png", 32, 18),
                    ("cf50d-l.png", 32, 32),
                    ("container-unknown.png", 32, 32),
                ):
                    source = tk.PhotoImage(width=width, height=height)
                    source.put("#3399cc", to=(0, 0, width, height))
                    source.write(str(icons / name), format="png")
                    manager.tree.insert("", "end", iid=name,
                                        values=(name, f"{width}x{height}", "Unchanged"))
                    manager.tree.selection_set(name)
                    manager.show_preview()
                    root.update_idletasks()
                    self.assertEqual(manager.preview_original.width(), width)
                    self.assertEqual(manager.preview_original.height(), height)
                    # Integer zoom cannot distort the original canvas ratio.
                    self.assertEqual(manager.preview_images[1].width(),
                                     width * manager.preview_zoom)
                    self.assertEqual(manager.preview_images[1].height(),
                                     height * manager.preview_zoom)
                    self.assertLessEqual(manager.preview_images[1].width(),
                                         max(width, manager.preview_canvas.winfo_width()))
                    allowed_height = (
                        manager.preview_canvas.winfo_height()
                        - manager.prev_head.winfo_reqheight()
                        - manager.preview_info.winfo_reqheight() - 24)
                    if allowed_height >= height:
                        self.assertLessEqual(
                            manager.preview_images[1].height(), allowed_height)
                # A long note may exceed the viewport, but can be reached by
                # scrolling just the preview without scrolling the icon list.
                manager.preview_info.configure(
                    text="An intentionally long test note. " * 70)
                root.update_idletasks()
                manager.resize_preview()
                root.update_idletasks()
                start, end = manager.preview_canvas.yview()
                self.assertLess(end - start, 1)
                manager.scroll_preview(SimpleNamespace(delta=-120))
                self.assertGreater(manager.preview_canvas.yview()[0], start)
            finally:
                root.destroy()


if __name__ == "__main__":
    unittest.main()
