"""MSB LOR preview XML compatibility checker.

Initial release: 2026-08-13 V1.0.0

This checker is deliberately parser-independent. It inventories the complete
XML contract, including fields the production parser does not consume, before
the candidate preview set is allowed to exercise the parser.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
import uuid
import xml.etree.ElementTree as ET
from collections import Counter, defaultdict
from dataclasses import dataclass, asdict
from datetime import datetime
from pathlib import Path
from typing import Any, Iterable


CHECKER_VERSION = "V1.3.1"
MANIFEST_VERSION = 4
CRITICAL_ELEMENTS = {"PreviewClass", "Scene", "PropClass"}
UUID_RE = re.compile(
    r"^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$",
    re.IGNORECASE,
)
INT_RE = re.compile(r"^[+-]?\d+$")
FLOAT_RE = re.compile(r"^[+-]?(?:\d+\.\d*|\d*\.\d+)$")


def local_name(name: str) -> str:
    return name.rsplit("}", 1)[-1].rsplit(":", 1)[-1]


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def value_shape(value: str | None) -> str:
    if value is None or not value.strip():
        return "blank"
    value = value.strip()
    lower = value.casefold()
    if lower in {"true", "false"}:
        return "boolean"
    if UUID_RE.fullmatch(value):
        return "uuid"
    if INT_RE.fullmatch(value):
        return "integer"
    if FLOAT_RE.fullmatch(value):
        return "decimal"
    if "\\" in value or "/" in value:
        return "path"
    return "string"


def channel_grid_profile(value: str) -> dict[str, Any]:
    records = [record.strip() for record in value.split(";") if record.strip()]
    token_counts: Counter[str] = Counter()
    position_shapes: defaultdict[str, Counter[str]] = defaultdict(Counter)
    for record in records:
        tokens = [token.strip() for token in record.split(",")]
        token_counts[str(len(tokens))] += 1
        for index, token in enumerate(tokens, start=1):
            position_shapes[str(index)][value_shape(token)] += 1
    return {
        "record_count": len(records),
        "token_counts": dict(sorted(token_counts.items())),
        "position_shapes": {
            position: dict(sorted(shapes.items()))
            for position, shapes in sorted(position_shapes.items(), key=lambda item: int(item[0]))
        },
    }


def merge_profile_counter(target: defaultdict[str, Counter[str]], profile: dict[str, Any]) -> None:
    for position, shapes in profile["position_shapes"].items():
        target[position].update(shapes)


def namespace_uri(tag: str) -> str | None:
    if tag.startswith("{") and "}" in tag:
        return tag[1:].split("}", 1)[0]
    return None


def iter_with_paths(root: ET.Element) -> Iterable[tuple[ET.Element, str]]:
    stack = [(root, f"/{local_name(root.tag)}")]
    while stack:
        element, path = stack.pop()
        yield element, path
        children = list(element)
        for child in reversed(children):
            stack.append((child, f"{path}/{local_name(child.tag)}"))


def one_file_contract(path: Path) -> dict[str, Any]:
    root = ET.parse(path).getroot()
    element_counts: Counter[str] = Counter()
    path_counts: Counter[str] = Counter()
    edges: Counter[str] = Counter()
    transitions: Counter[str] = Counter()
    attributes: defaultdict[str, set[str]] = defaultdict(set)
    shapes: defaultdict[str, defaultdict[str, Counter[str]]] = defaultdict(
        lambda: defaultdict(Counter)
    )
    namespaces: set[str] = set()
    ids: defaultdict[str, set[str]] = defaultdict(set)
    channel_tokens: Counter[str] = Counter()
    channel_positions: defaultdict[str, Counter[str]] = defaultdict(Counter)
    channel_record_counts: Counter[str] = Counter()
    delimited_values: Counter[str] = Counter()
    delimited_tokens: defaultdict[str, Counter[str]] = defaultdict(Counter)
    delimited_positions: defaultdict[str, defaultdict[str, Counter[str]]] = defaultdict(
        lambda: defaultdict(Counter)
    )
    delimited_record_counts: defaultdict[str, Counter[str]] = defaultdict(Counter)

    for element, path_name in iter_with_paths(root):
        tag = local_name(element.tag)
        element_counts[tag] += 1
        path_counts[path_name] += 1
        uri = namespace_uri(element.tag)
        if uri:
            namespaces.add(uri)
        for attribute_name, raw_value in element.attrib.items():
            attribute = local_name(attribute_name)
            attributes[tag].add(attribute)
            shapes[tag][attribute][value_shape(raw_value)] += 1
            if attribute == "id" and raw_value.strip():
                ids[tag].add(raw_value.strip())
            if tag == "PropClass" and attribute == "ChannelGrid" and raw_value.strip():
                profile = channel_grid_profile(raw_value)
                channel_tokens.update(profile["token_counts"])
                merge_profile_counter(channel_positions, profile)
                channel_record_counts[str(profile["record_count"])] += 1
            if ("," in raw_value or ";" in raw_value) and raw_value.strip():
                field = f"{tag}.{attribute}"
                profile = channel_grid_profile(raw_value)
                delimited_values[field] += 1
                delimited_tokens[field].update(profile["token_counts"])
                delimited_record_counts[field][str(profile["record_count"])] += 1
                for position, position_shapes in profile["position_shapes"].items():
                    delimited_positions[field][position].update(position_shapes)

        children = list(element)
        child_names = [local_name(child.tag) for child in children]
        for child_name in child_names:
            edges[f"{tag}>{child_name}"] += 1
        for left, right in zip(child_names, child_names[1:]):
            transitions[f"{tag}:{left}>{right}"] += 1

    return {
        "filename": path.name,
        "sha256": sha256_file(path),
        "root_element": local_name(root.tag),
        "namespaces": sorted(namespaces),
        "element_counts": dict(sorted(element_counts.items())),
        "path_counts": dict(sorted(path_counts.items())),
        "edges": dict(sorted(edges.items())),
        "transitions": dict(sorted(transitions.items())),
        "attributes": {tag: sorted(names) for tag, names in sorted(attributes.items())},
        "attribute_shapes": {
            tag: {
                attribute: dict(sorted(counter.items()))
                for attribute, counter in sorted(by_attribute.items())
            }
            for tag, by_attribute in sorted(shapes.items())
        },
        "ids": {tag: sorted(values) for tag, values in sorted(ids.items())},
        "channel_grid": {
            "prop_record_counts": dict(sorted(channel_record_counts.items())),
            "token_counts": dict(sorted(channel_tokens.items())),
            "position_shapes": {
                position: dict(sorted(counter.items()))
                for position, counter in sorted(channel_positions.items(), key=lambda item: int(item[0]))
            },
        },
        "delimited_fields": {
            field: {
                "value_count": delimited_values[field],
                "record_counts": dict(sorted(delimited_record_counts[field].items())),
                "token_counts": dict(sorted(delimited_tokens[field].items())),
                "position_shapes": {
                    position: dict(sorted(counter.items()))
                    for position, counter in sorted(
                        delimited_positions[field].items(), key=lambda item: int(item[0])
                    )
                },
            }
            for field in sorted(delimited_values)
        },
    }


def merge_contracts(files: list[dict[str, Any]]) -> dict[str, Any]:
    roots: Counter[str] = Counter()
    namespaces: set[str] = set()
    elements: Counter[str] = Counter()
    paths: Counter[str] = Counter()
    edges: Counter[str] = Counter()
    transitions: Counter[str] = Counter()
    attributes: defaultdict[str, set[str]] = defaultdict(set)
    shapes: defaultdict[str, defaultdict[str, Counter[str]]] = defaultdict(
        lambda: defaultdict(Counter)
    )
    channel_tokens: Counter[str] = Counter()
    channel_positions: defaultdict[str, Counter[str]] = defaultdict(Counter)
    channel_record_counts: Counter[str] = Counter()
    delimited_values: Counter[str] = Counter()
    delimited_tokens: defaultdict[str, Counter[str]] = defaultdict(Counter)
    delimited_positions: defaultdict[str, defaultdict[str, Counter[str]]] = defaultdict(
        lambda: defaultdict(Counter)
    )
    delimited_record_counts: defaultdict[str, Counter[str]] = defaultdict(Counter)

    for contract in files:
        roots[contract["root_element"]] += 1
        namespaces.update(contract["namespaces"])
        elements.update(contract["element_counts"])
        paths.update(contract["path_counts"])
        edges.update(contract["edges"])
        transitions.update(contract["transitions"])
        for tag, names in contract["attributes"].items():
            attributes[tag].update(names)
        for tag, by_attribute in contract["attribute_shapes"].items():
            for attribute, counter in by_attribute.items():
                shapes[tag][attribute].update(counter)
        grid = contract["channel_grid"]
        channel_tokens.update(grid["token_counts"])
        channel_record_counts.update(grid["prop_record_counts"])
        for position, counter in grid["position_shapes"].items():
            channel_positions[position].update(counter)
        for field, profile in contract["delimited_fields"].items():
            delimited_values[field] += profile["value_count"]
            delimited_tokens[field].update(profile["token_counts"])
            delimited_record_counts[field].update(profile["record_counts"])
            for position, counter in profile["position_shapes"].items():
                delimited_positions[field][position].update(counter)

    return {
        "root_elements": dict(sorted(roots.items())),
        "namespaces": sorted(namespaces),
        "element_counts": dict(sorted(elements.items())),
        "path_counts": dict(sorted(paths.items())),
        "edges": dict(sorted(edges.items())),
        "transitions": dict(sorted(transitions.items())),
        "attributes": {tag: sorted(names) for tag, names in sorted(attributes.items())},
        "attribute_shapes": {
            tag: {
                attribute: dict(sorted(counter.items()))
                for attribute, counter in sorted(by_attribute.items())
            }
            for tag, by_attribute in sorted(shapes.items())
        },
        "channel_grid": {
            "prop_record_counts": dict(sorted(channel_record_counts.items())),
            "token_counts": dict(sorted(channel_tokens.items())),
            "position_shapes": {
                position: dict(sorted(counter.items()))
                for position, counter in sorted(channel_positions.items(), key=lambda item: int(item[0]))
            },
        },
        "delimited_fields": {
            field: {
                "value_count": delimited_values[field],
                "record_counts": dict(sorted(delimited_record_counts[field].items())),
                "token_counts": dict(sorted(delimited_tokens[field].items())),
                "position_shapes": {
                    position: dict(sorted(counter.items()))
                    for position, counter in sorted(
                        delimited_positions[field].items(), key=lambda item: int(item[0])
                    )
                },
            }
            for field in sorted(delimited_values)
        },
    }


def preview_identity(contract: dict[str, Any]) -> str:
    """Return the stable per-preview identity, falling back only when LOR omitted it."""
    preview_ids = contract.get("ids", {}).get("PreviewClass", [])
    if len(preview_ids) == 1:
        return f"PreviewClass:{preview_ids[0].casefold()}"
    return f"Filename:{contract['filename'].casefold()}"


def manifest_source_signature(manifest: dict[str, Any]) -> str:
    """Return a deterministic digest of the exact reviewed preview files."""
    source_files = sorted(
        (
            {
                "filename": item["filename"],
                "identity": preview_identity(item),
                "sha256": item["sha256"],
            }
            for item in manifest["files"]
        ),
        key=lambda item: (item["identity"], item["filename"].casefold()),
    )
    payload = json.dumps(source_files, sort_keys=True, separators=(",", ":"))
    return hashlib.sha256(payload.encode()).hexdigest()


def build_manifest(
    folder: Path,
    lor_version: str,
    deep_preview: str | None,
    deep_identity: str | None = None,
) -> dict[str, Any]:
    paths = sorted(folder.glob("*.lorprev"), key=lambda item: item.name.casefold())
    if not paths:
        raise ValueError(f"No .lorprev files found in {folder}")
    file_contracts = [one_file_contract(path) for path in paths]
    identities = Counter(preview_identity(contract) for contract in file_contracts)
    duplicates = sorted(identity for identity, count in identities.items() if count > 1)
    if duplicates:
        raise ValueError(
            "Duplicate PreviewClass identity across preview files: " + ", ".join(duplicates)
        )
    deep_name = deep_preview or max(paths, key=lambda item: item.stat().st_size).name
    deep = next((item for item in file_contracts if item["filename"] == deep_name), None)
    if deep is None and deep_identity:
        matches = [
            item for item in file_contracts if preview_identity(item) == deep_identity
        ]
        if len(matches) == 1:
            deep = matches[0]
            deep_name = deep["filename"]
    if deep is None:
        expected = f" ({deep_identity})" if deep_identity else ""
        raise ValueError(
            f"Deep preview is not present in the selected folder: {deep_name}{expected}"
        )
    manifest = {
        "manifest_version": MANIFEST_VERSION,
        "checker_version": CHECKER_VERSION,
        "generated_at": datetime.now().astimezone().isoformat(timespec="seconds"),
        "lor_version": lor_version,
        "preview_folder": str(folder.resolve()),
        "file_count": len(file_contracts),
        "deep_preview": deep_name,
        "deep_preview_identity": preview_identity(deep),
        "files": file_contracts,
        "aggregate": merge_contracts(file_contracts),
        "deep_contract": deep,
    }
    manifest["source_signature_sha256"] = manifest_source_signature(manifest)
    manifest_payload = json.dumps(manifest, sort_keys=True, separators=(",", ":"))
    manifest["manifest_sha256"] = hashlib.sha256(manifest_payload.encode()).hexdigest()
    return manifest


@dataclass(frozen=True)
class Finding:
    severity: str
    area: str
    message: str
    parser_modification_required: str | None = None


def _same_version_authoring_finding(finding: Finding) -> Finding:
    """Keep normal Motion FX authoring visible without blocking same-version runs."""
    if finding.severity != "BLOCKING":
        return finding
    evidence = f"{finding.area} {finding.message}"
    if "MotionRowDefault" not in evidence:
        return finding
    return Finding(
        "INFO",
        finding.area,
        finding.message
        + " Same-version Motion FX authoring is nonblocking; the V7 production parser does not consume MotionRowDefault data.",
        None,
    )


def set_difference_findings(
    baseline: Iterable[str], candidate: Iterable[str], area: str, noun: str
) -> list[Finding]:
    old, new = set(baseline), set(candidate)
    findings: list[Finding] = []
    for value in sorted(new - old):
        findings.append(Finding(
            "BLOCKING", area, f"New {noun}: {value}",
            f"Review and explicitly support or reject {noun} {value!r} before production.",
        ))
    for value in sorted(old - new):
        findings.append(Finding(
            "BLOCKING", area, f"Removed {noun}: {value}",
            f"Update the parser contract for removed {noun} {value!r}, or restore it in LOR.",
        ))
    return findings


def compare_shapes(baseline: dict[str, Any], candidate: dict[str, Any]) -> list[Finding]:
    findings: list[Finding] = []
    all_tags = sorted(set(baseline) | set(candidate))
    for tag in all_tags:
        old_attributes = baseline.get(tag, {})
        new_attributes = candidate.get(tag, {})
        for attribute in sorted(set(old_attributes) | set(new_attributes)):
            old_shapes = set(old_attributes.get(attribute, {}))
            new_shapes = set(new_attributes.get(attribute, {}))
            if old_shapes != new_shapes:
                findings.append(Finding(
                    "BLOCKING", f"{tag}.{attribute}",
                    f"Value shapes changed from {sorted(old_shapes)} to {sorted(new_shapes)}.",
                    f"Confirm parsing and materialization of {tag}.{attribute} for every new value shape.",
                ))
    return findings


def compare_delimited_fields(
    baseline: dict[str, Any], candidate: dict[str, Any], area_prefix: str = ""
) -> list[Finding]:
    """Detect positional contract drift in every comma/semicolon-encoded field."""
    findings: list[Finding] = []
    old_fields, new_fields = set(baseline), set(candidate)
    for field in sorted(new_fields - old_fields):
        findings.append(Finding(
            "BLOCKING", area_prefix + field,
            f"New delimiter-encoded field layout: {field}.",
            f"Document and support the positional layout of {field} before production.",
        ))
    for field in sorted(old_fields - new_fields):
        findings.append(Finding(
            "BLOCKING", area_prefix + field,
            f"Delimiter-encoded field layout disappeared: {field}.",
            f"Update code that relies on positional layout in {field} before production.",
        ))
    for field in sorted(old_fields & new_fields):
        # ChannelGrid retains its dedicated, explicit comparison and report area.
        if field == "PropClass.ChannelGrid":
            continue
        old, new = baseline[field], candidate[field]
        for key, noun in (
            ("record_counts", "semicolon record count"),
            ("token_counts", "comma token count"),
        ):
            findings.extend(set_difference_findings(
                old[key], new[key], area_prefix + field, noun
            ))
        positions = sorted(
            set(old["position_shapes"]) | set(new["position_shapes"]), key=int
        )
        for position in positions:
            old_shapes = set(old["position_shapes"].get(position, {}))
            new_shapes = set(new["position_shapes"].get(position, {}))
            if old_shapes != new_shapes:
                findings.append(Finding(
                    "BLOCKING", f"{area_prefix}{field} position {position}",
                    f"Delimited value shapes changed from {sorted(old_shapes)} "
                    f"to {sorted(new_shapes)}.",
                    f"Confirm the positional meaning and parsing of {field} position {position}.",
                ))
    return findings


def compare_file_contracts(baseline: dict[str, Any], candidate: dict[str, Any]) -> list[Finding]:
    """Compare every matching preview, not only the aggregate/deep preview."""
    findings: list[Finding] = []
    old_files = {preview_identity(item): item for item in baseline["files"]}
    new_files = {preview_identity(item): item for item in candidate["files"]}
    for identity in sorted(set(old_files) | set(new_files), key=str.casefold):
        if identity not in old_files:
            findings.append(Finding(
                "REVIEW", "preview set",
                f"New preview identity/file: {new_files[identity]['filename']} ({identity}).",
            ))
            continue
        if identity not in new_files:
            findings.append(Finding(
                "BLOCKING", "preview set",
                f"Approved preview identity removed: {old_files[identity]['filename']} ({identity}).",
            ))
            continue
        old, new = old_files[identity], new_files[identity]
        old_filename, new_filename = old["filename"], new["filename"]
        if old_filename != new_filename:
            findings.append(Finding(
                "REVIEW", "preview filename",
                f"Preview filename changed from {old_filename} to {new_filename}; "
                f"stable identity {identity} was preserved.",
            ))
        prefix = (
            f"{old_filename}: " if old_filename == new_filename
            else f"{old_filename} -> {new_filename}: "
        )
        findings.extend(set_difference_findings(
            [old["root_element"]], [new["root_element"]], prefix + "document", "root element"
        ))
        for key, area, noun in (
            ("namespaces", "document", "namespace"),
            ("element_counts", "XML", "element"),
            ("path_counts", "XML hierarchy", "element path"),
            ("edges", "XML hierarchy", "parent/child edge"),
            ("transitions", "XML ordering", "sibling transition"),
        ):
            findings.extend(set_difference_findings(
                old[key], new[key], prefix + area, noun
            ))
        for tag in sorted(set(old["attributes"]) | set(new["attributes"])):
            findings.extend(set_difference_findings(
                old["attributes"].get(tag, []), new["attributes"].get(tag, []),
                prefix + tag, "attribute",
            ))
        for item in compare_shapes(old["attribute_shapes"], new["attribute_shapes"]):
            findings.append(Finding(
                item.severity, prefix + item.area, item.message,
                item.parser_modification_required,
            ))
        for tag in sorted(CRITICAL_ELEMENTS):
            old_count = old["element_counts"].get(tag, 0)
            new_count = new["element_counts"].get(tag, 0)
            if old_count != new_count:
                findings.append(Finding(
                    "REVIEW", prefix + tag,
                    f"{tag} count changed from {old_count} to {new_count}.",
                ))
            old_ids = set(old["ids"].get(tag, []))
            new_ids = set(new["ids"].get(tag, []))
            if old_ids != new_ids:
                findings.append(Finding(
                    "REVIEW", prefix + f"{tag} identity",
                    f"{len(old_ids - new_ids)} IDs were removed and "
                    f"{len(new_ids - old_ids)} IDs were added.",
                ))
        findings.extend(compare_delimited_fields(
            old["delimited_fields"], new["delimited_fields"], prefix
        ))
        old_grid, new_grid = old["channel_grid"], new["channel_grid"]
        findings.extend(set_difference_findings(
            old_grid["token_counts"], new_grid["token_counts"],
            prefix + "PropClass.ChannelGrid", "record token count",
        ))
        for item in compare_shapes(
            {"PropClass.ChannelGrid": old_grid["position_shapes"]},
            {"PropClass.ChannelGrid": new_grid["position_shapes"]},
        ):
            findings.append(Finding(
                item.severity, prefix + item.area, item.message,
                item.parser_modification_required,
            ))
    return findings


def compare_manifests(baseline: dict[str, Any], candidate: dict[str, Any]) -> list[Finding]:
    old = baseline["aggregate"]
    new = candidate["aggregate"]
    findings: list[Finding] = []
    findings.extend(compare_file_contracts(baseline, candidate))
    findings.extend(set_difference_findings(old["root_elements"], new["root_elements"], "document", "root element"))
    findings.extend(set_difference_findings(old["namespaces"], new["namespaces"], "document", "namespace"))
    findings.extend(set_difference_findings(old["element_counts"], new["element_counts"], "XML", "element"))
    findings.extend(set_difference_findings(old["path_counts"], new["path_counts"], "XML hierarchy", "element path"))
    findings.extend(set_difference_findings(old["edges"], new["edges"], "XML hierarchy", "parent/child edge"))
    findings.extend(set_difference_findings(old["transitions"], new["transitions"], "XML ordering", "sibling transition"))

    all_tags = sorted(set(old["attributes"]) | set(new["attributes"]))
    for tag in all_tags:
        findings.extend(set_difference_findings(
            old["attributes"].get(tag, []), new["attributes"].get(tag, []), tag, "attribute"
        ))
    findings.extend(compare_shapes(old["attribute_shapes"], new["attribute_shapes"]))
    findings.extend(compare_delimited_fields(
        old["delimited_fields"], new["delimited_fields"]
    ))

    old_grid, new_grid = old["channel_grid"], new["channel_grid"]
    findings.extend(set_difference_findings(
        old_grid["token_counts"], new_grid["token_counts"], "PropClass.ChannelGrid", "record token count"
    ))
    findings.extend(compare_shapes(
        {"ChannelGrid": old_grid["position_shapes"]},
        {"ChannelGrid": new_grid["position_shapes"]},
    ))

    if baseline["file_count"] != candidate["file_count"]:
        findings.append(Finding(
            "REVIEW", "preview set",
            f"Preview file count changed from {baseline['file_count']} to {candidate['file_count']}.",
        ))

    old_deep, new_deep = baseline["deep_contract"], candidate["deep_contract"]
    for tag in sorted(CRITICAL_ELEMENTS):
        old_count = old_deep["element_counts"].get(tag, 0)
        new_count = new_deep["element_counts"].get(tag, 0)
        if old_count != new_count:
            findings.append(Finding(
                "REVIEW", f"deep preview {tag}",
                f"{tag} count changed from {old_count} to {new_count} in the deep preview.",
            ))
        old_ids = set(old_deep["ids"].get(tag, []))
        new_ids = set(new_deep["ids"].get(tag, []))
        if old_ids != new_ids:
            findings.append(Finding(
                "REVIEW", f"deep preview {tag} identity",
                f"{len(old_ids - new_ids)} IDs were removed and {len(new_ids - old_ids)} IDs were added.",
            ))

    if baseline.get("lor_version") == candidate.get("lor_version"):
        findings = [_same_version_authoring_finding(item) for item in findings]
    return findings


def report_document(baseline: dict[str, Any], candidate: dict[str, Any], findings: list[Finding]) -> dict[str, Any]:
    blocking = [finding for finding in findings if finding.severity == "BLOCKING"]
    review = [finding for finding in findings if finding.severity == "REVIEW"]
    status = "FAILED" if blocking else ("REVIEW_REQUIRED" if review else "PASSED")
    modifications = sorted({
        finding.parser_modification_required
        for finding in blocking
        if finding.parser_modification_required
    })
    return {
        "checker_version": CHECKER_VERSION,
        "checked_at": datetime.now().astimezone().isoformat(timespec="seconds"),
        "current_lor_version": baseline["lor_version"],
        "new_lor_version": candidate["lor_version"],
        "baseline_manifest_sha256": baseline["manifest_sha256"],
        "candidate_manifest_sha256": candidate["manifest_sha256"],
        "status": status,
        "approval_blocked": status != "PASSED",
        "blocking_count": len(blocking),
        "review_count": len(review),
        "parser_modifications_required": modifications,
        "findings": [asdict(finding) for finding in findings],
    }


def markdown_report(report: dict[str, Any]) -> str:
    lines = [
        "# LOR Preview Compatibility Report",
        "",
        f"- Current LOR version: {report['current_lor_version']}",
        f"- New LOR version: {report['new_lor_version']}",
        f"- Status: **{report['status']}**",
        f"- Production approval blocked: **{'YES' if report['approval_blocked'] else 'NO'}**",
        f"- Blocking findings: {report['blocking_count']}",
        f"- Review findings: {report['review_count']}",
        "",
        "## Parser modifications required",
        "",
    ]
    modifications = report["parser_modifications_required"]
    lines.extend([f"- {item}" for item in modifications] or ["- None identified."])
    lines.extend(["", "## Findings", ""])
    if not report["findings"]:
        lines.append("No XML structure, field, ordering, identity, or ChannelGrid contract changes were detected.")
    else:
        lines.append("| Severity | Area | Finding |")
        lines.append("|---|---|---|")
        for finding in report["findings"]:
            message = finding["message"].replace("|", "\\|")
            area = finding["area"].replace("|", "\\|")
            lines.append(f"| {finding['severity']} | {area} | {message} |")
    return "\n".join(lines) + "\n"


def write_json(path: Path, value: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def parser() -> argparse.ArgumentParser:
    root = argparse.ArgumentParser(description="Inventory and compare complete .lorprev XML contracts")
    commands = root.add_subparsers(dest="command", required=True)
    snapshot = commands.add_parser("snapshot", help="Create an approved-version XML manifest")
    snapshot.add_argument("--lor-version", required=True)
    snapshot.add_argument("--preview-folder", required=True, type=Path)
    snapshot.add_argument("--deep-preview")
    snapshot.add_argument("--output", required=True, type=Path)

    compare = commands.add_parser("compare", help="Compare candidate XML to an approved manifest")
    compare.add_argument("--baseline", required=True, type=Path)
    compare.add_argument("--new-lor-version", required=True)
    compare.add_argument("--preview-folder", required=True, type=Path)
    compare.add_argument("--deep-preview")
    compare.add_argument("--candidate-manifest", type=Path)
    compare.add_argument("--report-json", required=True, type=Path)
    compare.add_argument("--report-md", required=True, type=Path)
    return root


def main(argv: list[str] | None = None) -> int:
    arguments = parser().parse_args(argv)
    try:
        if arguments.command == "snapshot":
            manifest = build_manifest(
                arguments.preview_folder, arguments.lor_version, arguments.deep_preview
            )
            write_json(arguments.output, manifest)
            print(f"[OK] Wrote LOR {arguments.lor_version} XML manifest: {arguments.output}")
            return 0

        baseline = json.loads(arguments.baseline.read_text(encoding="utf-8"))
        baseline_deep_identity = (
            baseline.get("deep_preview_identity")
            or preview_identity(baseline["deep_contract"])
        )
        candidate = build_manifest(
            arguments.preview_folder,
            arguments.new_lor_version,
            arguments.deep_preview or baseline.get("deep_preview"),
            deep_identity=baseline_deep_identity,
        )
        if arguments.candidate_manifest:
            write_json(arguments.candidate_manifest, candidate)
        report = report_document(baseline, candidate, compare_manifests(baseline, candidate))
        write_json(arguments.report_json, report)
        arguments.report_md.parent.mkdir(parents=True, exist_ok=True)
        arguments.report_md.write_text(markdown_report(report), encoding="utf-8")
        print(f"[{report['status']}] {report['blocking_count']} blocking; {report['review_count']} review")
        return 0 if report["status"] == "PASSED" else 2
    except (OSError, ET.ParseError, ValueError, KeyError, json.JSONDecodeError) as error:
        print(f"[FATAL] {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())