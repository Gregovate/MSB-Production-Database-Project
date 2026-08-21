"""Run the one-time V7.0.11 documentation closeout with corrected repo-root resolution.

The first closeout helper used HERE.parents[4], which resolves one directory above
the repository when the helper lives under Docs/01_LOR_System/02_Data_Extraction/Parser.
This runner corrects that single line in memory, executes the existing guarded
closeout, and removes itself only after a successful run. It does not modify the
closeout helper before its clean-working-tree guard executes.
"""

from __future__ import annotations

from pathlib import Path


HERE = Path(__file__).resolve().parent
TARGET = HERE / "apply_v7011_documentation_closeout.py"
SELF = Path(__file__).resolve()


def main() -> None:
    if not TARGET.exists():
        raise SystemExit(f"[FATAL] Missing closeout helper: {TARGET}")

    source = TARGET.read_text(encoding="utf-8")
    old = "ROOT = HERE.parents[4]"
    new = "ROOT = HERE.parents[3]"
    count = source.count(old)
    if count != 1:
        raise SystemExit(
            f"[FATAL] Expected exactly one incorrect repo-root anchor, found {count}"
        )

    corrected = source.replace(old, new, 1)
    namespace = {
        "__name__": "__main__",
        "__file__": str(TARGET),
        "__package__": None,
    }
    exec(compile(corrected, str(TARGET), "exec"), namespace, namespace)

    if SELF.exists():
        SELF.unlink()
        print(f"[OK] Removed one-time corrected closeout runner: {SELF.name}")


if __name__ == "__main__":
    main()
