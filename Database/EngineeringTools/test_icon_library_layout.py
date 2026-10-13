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
                    ("car-l.png", 32, 18),
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
