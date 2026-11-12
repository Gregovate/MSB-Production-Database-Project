"""#171: Local source-only browser preview is bounded and source-conserving."""
import hashlib
import json
from pathlib import Path

import pytest

from stage_locate_source_preview import build_review, ASSETS, OLD_BANNER


MAP_COUNTS = {
    "old_map_waypoints": 229, "gpx_waypoints": 233,
    "old_map_tracks": 181, "gpx_tracks": 181,
    "corrected_names": 14, "new_waypoints": 4,
    "coordinate_matches": 229, "conflicts": 0,
}
NETWORK_COUNTS = {
    "saved_test_uuids": 476,
    "source_project_rows": 684,
    "duplicate_project_appearances": 208,
    "cables_with_parseable_active_names": 455,
    "tests_requiring_name_or_delete_review": 21,
    "source_deleted_uuid_count": 7,
    "mapped_candidate_tracks": 32,
    "unresolved_tracks": 149,
}


def setup_fixture(tmp_path):
    repo = tmp_path / "repo"
    app = repo / "Setup" / "Application"
    app.mkdir(parents=True)
    for asset in ASSETS:
        text = ("// PRIOR_DRAWIO_SNAPSHOT_UNREVIEWED"
                " PRIOR_LOR_SNAPSHOT_UNREVIEWED" if
                asset == "setup_locate_networks.js" else "// fixture")
        (app / asset).write_text(text, encoding="utf-8")
    (app / "setup_workshop_reference.json").write_text(json.dumps({
        "map_coordinates": {"longitude": -87.73321549,
                            "latitude": 43.778402029}
    }))

    source_dir = tmp_path / "source"
    source_dir.mkdir()
    gpx = source_dir / "corrected.gpx"
    flw = source_dir / "corrected.flw"
    gpx.write_bytes(b"dummy gpx source bytes")
    flw.write_bytes(b"dummy flw source bytes")
    gpxsha = hashlib.sha256(gpx.read_bytes()).hexdigest()
    flwsha = hashlib.sha256(flw.read_bytes()).hexdigest()
    config = source_dir / "source-paths.json"
    config.write_text(json.dumps({
        "GPX": str(gpx), "FLW": str(flw),
        "GPX_SHA256": gpxsha.upper(), "FLW_SHA256": flwsha.upper(),
    }))

    review = tmp_path / "review"
    review.mkdir()
    features = [{
        "type": "Feature",
        "geometry": {"type": "Point",
                     "coordinates": ([-87.73321549, 43.77840207]
                                     if i == 3 else
                                     [-87.7 + i * 0.00001, 43.77])},
        "properties": {"id": f"w{i}",
                       "name": ("PANEL A5-00" if i == 0 else
                                "A5-07/09" if i == 1 else
                                "42-02S" if i == 2 else
                                "Workshop" if i == 3 else
                                "LB WiFi Antenna" if i == 4 else f"WP-{i}"),
                       "type": ("Waypoint" if i == 3 else
                                "Tower" if i == 4 else "OUT-Combo"),
                       "time": ("2026-10-10T18:40:42.586Z" if i == 4 else "")}
    } for i in range(233)]
    features += [{
        "type": "Feature",
        "geometry": {"type": "LineString",
                     "coordinates": [[-87.7, 43.77], [-87.69, 43.77]]},
        "properties": {"id": f"t{i}", "name": f"route-{i}"}
    } for i in range(181)]
    html = ("<html><div id=\"network-status\"></div><p>" +
            "GPX candidate SHA " + gpxsha[:16] + "</p><p>" +
            OLD_BANNER + "</p><script>const data=" +
            json.dumps({"type": "FeatureCollection", "features": features}) +
            ';data.features.push({"type":"Feature","geometry":{"type":"Point","coordinates":[-87.73315025812246,43.778472269285245]},"properties":{"id":"temporary-workshop","name":"Workshop","type":"Workshop","desc":"Temporary operator-provided reference, October 8, 2026. EPSG:8158 X 213626.715, Y 186613.225 USft (first screenshot point). Expected location before picking; not an asset GPS observation."}});const map=0;'
            "</script></html>")
    (review / "park-map-corrected-candidate.html").write_text(html, encoding="utf-8")
    (review / "park-map-correction-report.json").write_text(
        json.dumps({"gpx_sha256": gpxsha, "counts": MAP_COUNTS}))
    test_items = []
    for i in range(476):
        test_items.append({
            "source_id": f"test-{i}", "project_appearances": 2 if i < 208 else 1,
        })
    routes = [{"route_id": f"t{i}"} for i in range(181)]
    network = {
        "format_version": 1, "source_sha256": flwsha,
        "test_uuid_count": 476,
        "cables": test_items[:455], "review_records": test_items[455:],
        "mapped_routes": routes[:32], "unresolved_routes": routes[32:],
        "schematic_status": "PRIOR_DRAWIO_SNAPSHOT_UNREVIEWED",
        "lor_status": "PRIOR_LOR_SNAPSHOT_UNREVIEWED",
    }
    (review / "park-network-corrected-candidate.json").write_text(
        json.dumps(network))
    (review / "park-network-correction-report.json").write_text(
        json.dumps({"source_sha256": flwsha, "counts": NETWORK_COUNTS}))
    return config, review, repo, source_dir


def test_stage_same_existing_map_and_network_without_mutating_inputs(tmp_path):
    config, review, repo, source = setup_fixture(tmp_path)
    before = {
        path: path.read_bytes() for path in (source / "corrected.gpx",
                                             source / "corrected.flw")
    }
    root = tmp_path / "preview"
    result = build_review(config=config, review_folder=review,
                          repo=repo, output_root=root)
    assert result["status"] == "LOCAL_SOURCE_PREVIEW_NOT_DEPLOYED"
    page = root / "setup" / "locate" / "index.html"
    assert page.is_file()
    assert "SOURCE-CORRECTION LOCAL REVIEW" in page.read_text()
    assert OLD_BANNER not in page.read_text()
    # The real source-authored Workshop remains; only the placeholder is gone.
    assert "temporary-workshop" not in page.read_text()
    assert "LB WiFi Antenna" in page.read_text()
    assert "2026-10-10T18:40:42.586Z" in page.read_text()
    assert "Workshop" in page.read_text()
    assert result["legacy_temporary_workshop_removed"] is True
    assert result["workshop_source"] == "GPX Label on Map / Workshop / Waypoint"
    assert result["workshop_home_anchor_separation_ft"] < 0.2
    assert result["workshop_gpx_coordinate"] == [-87.73321549, 43.77840207]
    assert "GPX Workshop / Waypoint retained" in page.read_text()
    assert (root / "setup" / "locate" / "assets" /
            "setup_locate_networks.json").is_file()
    assert len((root / "setup" / "locate" / "assets" /
                "setup_locate_networks.json").read_text()) > 100
    assert (root / "preview-manifest.json").is_file()
    for path, original in before.items():
        assert path.read_bytes() == original
    with pytest.raises(ValueError, match="overwrite existing preview"):
        build_review(config=config, review_folder=review,
                     repo=repo, output_root=root)


def test_rejects_changed_shared_source_before_staging(tmp_path):
    config, review, repo, source = setup_fixture(tmp_path)
    (source / "corrected.flw").write_bytes(b"changed while operator was away")
    with pytest.raises(ValueError, match="does not match saved SHA-256"):
        build_review(config=config, review_folder=review,
                     repo=repo, output_root=tmp_path / "output")
    assert not (tmp_path / "output").exists()


def test_rejects_stale_or_missing_network_evidence(tmp_path):
    config, review, repo, _ = setup_fixture(tmp_path)
    network = review / "park-network-corrected-candidate.json"
    data = json.loads(network.read_text())
    data["schematic_status"] = "REVIEWED"
    network.write_text(json.dumps(data))
    with pytest.raises(ValueError, match="Stale schematic/LOR warnings absent"):
        build_review(config=config, review_folder=review,
                     repo=repo, output_root=tmp_path / "output")
    assert not (tmp_path / "output").exists()


def test_refuses_to_remove_placeholder_without_real_gpx_workshop(tmp_path):
    config, review, repo, _ = setup_fixture(tmp_path)
    page = review / "park-map-corrected-candidate.html"
    html = page.read_text(encoding="utf-8")
    # Changing only the real waypoint name destroys source authority.
    html = html.replace('"name": "Workshop"', '"name": "Worksh0p"', 1)
    page.write_text(html, encoding="utf-8")
    with pytest.raises(ValueError, match="authoritative GPX Workshop"):
        build_review(config=config, review_folder=review,
                     repo=repo, output_root=tmp_path / "output")


def test_refuses_unrecognized_extra_map_injection(tmp_path):
    config, review, repo, _ = setup_fixture(tmp_path)
    page = review / "park-map-corrected-candidate.html"
    html = page.read_text(encoding="utf-8").replace(
        '"id":"temporary-workshop"', '"id":"someone-else"', 1)
    page.write_text(html, encoding="utf-8")
    with pytest.raises(ValueError, match="Unexpected extra map feature"):
        build_review(config=config, review_folder=review,
                     repo=repo, output_root=tmp_path / "output")


def test_fails_if_home_anchor_no_longer_agrees_with_gpx(tmp_path):
    config, review, repo, _ = setup_fixture(tmp_path)
    home = repo / "Setup" / "Application" / "setup_workshop_reference.json"
    home.write_text(json.dumps({
        "map_coordinates": {"longitude": -87.73315025812246,
                            "latitude": 43.778472269285245}
    }), encoding="utf-8")
    with pytest.raises(ValueError, match="GPX Workshop location disagrees"):
        build_review(config=config, review_folder=review,
                     repo=repo, output_root=tmp_path / "output")
