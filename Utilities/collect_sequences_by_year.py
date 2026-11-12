import os
import tkinter as tk
from tkinter import filedialog

OUTPUT_ROOT = r"G:\Shared drives\MSB Database\Sequence Lists"


def pick_folder():
    root = tk.Tk()
    root.withdraw()              # Hide empty root window
    root.attributes('-topmost', True)  # Force on top
    root.update()                # Process events so dialog appears in front

    folder = filedialog.askdirectory(
        title="Select folder containing .loredit / .LMS sequence files"
    )

    root.destroy()
    return folder


def main():
    print("Pick the folder containing .loredit / .LMS files…")
    src_dir = pick_folder()

    if not src_dir:
        print("No folder selected. Exiting.")
        return

    year = input("Enter year for output filename (e.g. 2024): ").strip()
    if not year:
        print("No year entered. Exiting.")
        return

    os.makedirs(OUTPUT_ROOT, exist_ok=True)
    out_path = os.path.join(OUTPUT_ROOT, f"{year}.txt")

    entries = []
    for name in os.listdir(src_dir):
        full_path = os.path.join(src_dir, name)
        if not os.path.isfile(full_path):
            continue

        ext = name.lower()
        if ext.endswith(".loredit"):
            seq_type = "S6"
        elif ext.endswith(".lms"):
            seq_type = "S4"
        else:
            continue

        entries.append(f"{seq_type}\t{full_path}")

    entries.sort()

    with open(out_path, "w", encoding="utf-8") as f:
        for line in entries:
            f.write(line + "\n")

    print(f"\nFound {len(entries)} sequence files.")
    print(f"Output written to:\n{out_path}\n")


if __name__ == "__main__":
    main()
