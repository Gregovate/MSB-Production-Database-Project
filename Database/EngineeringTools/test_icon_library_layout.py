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
                        "Review / submit this PC configuration",
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
            self.assertIn("V0.2.0-profile-proposals", title)
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
                 patch.object(manager, "async_operation", side_effect=fake_async):
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
                 patch("tkinter.messagebox.showinfo") as acknowledged:
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
