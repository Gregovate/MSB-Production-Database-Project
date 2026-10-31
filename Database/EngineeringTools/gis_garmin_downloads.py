"""Verified, content-addressed Garmin GPX retention; device removal is explicit."""
import hashlib
import json
from pathlib import Path
import xml.etree.ElementTree as ET


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def archive(root):
    return Path(root) / "Garmin-Downloads"


def retained(root):
    result = []
    index = archive(root) / 'index.json'
    latest = json.loads(index.read_text(encoding='utf8')) if index.exists() else {}
    for sha in sorted(set(latest.values())):
        path = archive(root) / 'objects' / sha / 'recording.gpx'
        if digest(path) != path.parent.name:
            raise ValueError(f"Retained file failed verification: {path}")
        result.append(path)
    return result


def inventory(source, root):
    source = Path(source).resolve(strict=True)
    rows = []
    for path in sorted(source.rglob("*")):
        if not path.is_file() or path.suffix.lower() != ".gpx":
            continue
        if not path.resolve().is_relative_to(source):
            raise ValueError("Linked file outside Garmin folder")
        sha = digest(path)
        document = ET.parse(path).getroot()
        creator = document.get("creator", "")
        target = archive(root) / "objects" / sha / "recording.gpx"
        rows.append(dict(relative=str(path.relative_to(source)), sha256=sha,
                         downloaded=target.is_file() and digest(target) == sha,
                         uploaded="expertgps" in creator.lower() or "topografix" in creator.lower(),
                         tracks=sum(n.tag.split('}')[-1] == 'trk' for n in document),
                         waypoints=sum(n.tag.split('}')[-1] == 'wpt' for n in document)))
    return rows


def device_file(source, row):
    base = Path(source).resolve(strict=True)
    path = (base / row["relative"]).resolve(strict=True)
    if not path.is_relative_to(base) or path.suffix.lower() != '.gpx':
        raise ValueError("Invalid device file")
    if digest(path) != row["sha256"]:
        raise ValueError(f"Device file changed; refresh first: {row['relative']}")
    return path


def download(source, root, rows):
    base = Path(source).resolve(strict=True)
    if archive(root).resolve().is_relative_to(base):
        raise ValueError("Downloads must be outside the Garmin folder")
    index = archive(root) / 'index.json'
    latest = json.loads(index.read_text(encoding='utf8')) if index.exists() else {}
    for row in rows:
        path = device_file(source, row)
        target = archive(root) / "objects" / row['sha256'] / "recording.gpx"
        target.parent.mkdir(parents=True, exist_ok=True)
        if not target.exists():
            data = path.read_bytes()
            if hashlib.sha256(data).hexdigest() != row['sha256']:
                raise ValueError("Device file changed during download")
            with target.open('xb') as stream:
                stream.write(data)
        if digest(target) != row['sha256']:
            raise ValueError("Retained copy failed verification")
        receipt = target.parent / "download.json"
        receipt.write_text(json.dumps(row, indent=2), encoding='utf8')
        latest[row['relative']] = row['sha256']
        temporary = index.with_suffix('.tmp')
        temporary.write_text(json.dumps(latest, indent=2), encoding='utf8')
        temporary.replace(index)


def remove_verified(source, root, rows):
    # Validate the entire selection before removing any file.
    paths = []
    for row in rows:
        path = device_file(source, row)
        target = archive(root) / 'objects' / row['sha256'] / 'recording.gpx'
        if not target.is_file() or digest(target) != row['sha256']:
            raise ValueError(f"No verified retained copy: {row['relative']}")
        paths.append((path, row))
    for path, row in paths:
        device_file(source, row).unlink()
