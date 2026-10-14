"""#171 deliberate shared Symbol Library cutover, no automatic folder mutation.

Use the CLI only after reviewing the read-only preflight and closing active
writers. A rename on the same shared drive preserves all subdirectories,
receipts and bytes; a post-rename manifest proves the inventory survived.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import sys
import time
from pathlib import Path

from sync_gis_icons import GIS_PARENT


class MigrationError(RuntimeError):
    pass


def manifest(root: Path) -> dict[str, str]:
    if not root.is_dir() or root.is_symlink():
        raise MigrationError(f"Missing or linked source folder: {root}")
    results = {}
    started = time.monotonic()
    print(f"Inventorying shared Symbol Library: {root}", file=sys.stderr, flush=True)
    for index, f in enumerate(sorted(root.rglob("*")), 1):
        if index % 100 == 0:
            print(f"  Scanned {index} entries ({time.monotonic() - started:.1f}s)...",
                  file=sys.stderr, flush=True)
        if f.is_symlink():
            raise MigrationError(f"Linked file/folder is not allowed: {f}")
        if f.is_file():
            key = f.relative_to(root).as_posix()
            if key.casefold() in (k.casefold() for k in results):
                raise MigrationError("Case-clashing library files: " + key)
            results[key] = hashlib.sha256(f.read_bytes()).hexdigest()
    print(f"  Completed hashing {len(results)} files in "
          f"{time.monotonic() - started:.1f}s.", file=sys.stderr, flush=True)
    if not results:
        raise MigrationError("Source library is empty; abort")
    for folder in ("Masters", "Plain", "png"):
        if not (root / folder).is_dir():
            raise MigrationError(f"Missing approved {folder} directory")
    return results


def inspect(parent: Path = GIS_PARENT) -> dict:
    old, new = parent / "Symbols", parent / "Symbol Library"
    if old.exists() and new.exists():
        raise MigrationError("Both library roots exist. Stop; never merge automatically.")
    if old.exists():
        return {"state": "NOT_MIGRATED", "source": str(old), "target": str(new),
                "files": manifest(old)}
    if new.exists():
        return {"state": "ALREADY_MIGRATED", "source": str(new), "target": str(new),
                "files": manifest(new)}
    raise MigrationError("Neither approved library root exists")


def migrate(parent: Path = GIS_PARENT, *, approved_digest: str):
    preflight = inspect(parent)
    if preflight["state"] != "NOT_MIGRATED":
        raise MigrationError("Cutover requires precisely the old source root")
    evidence = json.dumps(preflight["files"], sort_keys=True).encode()
    before = hashlib.sha256(evidence).hexdigest()
    if approved_digest != before:
        raise MigrationError("Inventory changed since review; no rename")
    old, new = parent / "Symbols", parent / "Symbol Library"
    old.rename(new)
    after = manifest(new)
    if after != preflight["files"]:
        raise MigrationError("Post-rename inventory mismatch: STOP, inspect new root")
    return {"status": "VERIFIED", "root": str(new), "count": len(after),
            "sha256": before}


def cli(argv=None):
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--parent", type=Path, default=GIS_PARENT)
    p.add_argument("--approve-cutover-digest", default="")
    args = p.parse_args(argv)
    try:
        if args.approve_cutover_digest:
            result = migrate(args.parent, approved_digest=args.approve_cutover_digest)
        else:
            review = inspect(args.parent)
            digest = hashlib.sha256(json.dumps(review["files"], sort_keys=True).encode()).hexdigest()
            result = {"state": review["state"], "source": review["source"],
                      "target": review["target"], "count": len(review["files"]),
                      "review_digest": digest,
                      "note": "Read-only. No folder renamed."}
        print(json.dumps(result, indent=2))
        return 0
    except (MigrationError, OSError) as exc:
        print("STOP: " + str(exc))
        return 1


if __name__ == "__main__":
    raise SystemExit(cli())
