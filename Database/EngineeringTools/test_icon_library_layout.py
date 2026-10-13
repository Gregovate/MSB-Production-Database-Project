"""#171 disposable small-screen Tk layout smoke test.

Only creates a temporary application window. Never clicks install/publish,
reads HKCU, opens ExpertGPS or touches live G:/GPX/Production files.
Run under xvfb-run on Linux or on a test desktop with an active GUI.
"""
from pathlib import Path
import runpy
import tkinter as tk
from tkinter import ttk
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


if __name__ == "__main__":
    unittest.main()
