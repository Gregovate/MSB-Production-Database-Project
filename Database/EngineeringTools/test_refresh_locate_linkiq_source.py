"""#171 current Park Map LinkIQ candidate conserves UUIDs/appearances/routes."""
import json
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
import refresh_locate_linkiq_source as candidate


def example_data():
    features = []
    for i in range(233):
        lon = -87.749 + i * 0.0001
        name = "PANEL A5-00" if i == 0 else "A5-07/09" if i == 1 else f"TEST-{i}"
        features.append({
            "type": "Feature",
            "geometry": {"type": "Point", "coordinates": [lon, 43.778]},
            "properties": {"id": f"w{i}", "name": name, "type": "OUT-Combo"}
        })
    for i in range(181):
        coords = ([[-87.749, 43.778], [-87.7489, 43.778]] if i == 0
                  else [[-87.749, 43.778]])
        features.append({
            "type": "Feature",
            "geometry": {"type": "LineString", "coordinates": coords},
            "properties": {"id": f"t{i}", "name": f"NET route {i}",
                           "class": "NET", "type": "Network"}
        })
    html = ('<html><script>const data='
            + json.dumps({"type": "FeatureCollection", "features": features})
            + ';data.features.push({"properties":{"id":"temporary-workshop"}})'
            + '</script></html>')
    prior = {
        "format_version": 1,
        "mapped_routes": [],
        "unresolved_routes": [{"route_id": f"t{i}"} for i in range(181)],
        "screen_radius_ft": 30,
        "devices": [{"source_id": "old-device"}],
        "legacy_edges": [{"source_id": "old-edge"}],
        "drawio_cables": [{"source_id": "old-schematic"}],
        "lor_inventory": {"source_name": "old-lor-snapshot"},
    }
    tests = []
    for i in range(476):
        label = ("PANEL A5-00 TO A5-07/09 REG" if i != 475
                 else "unparseable cable with no network")
        appearance = {
            "source_row": i+1,
            "original_test_id": f"TESTER-{i}",
            "display_cable_name": label,
            "project": "MSB-Park-Network",
            "deleted": "NO",
            "length_ft": i+10,
            "test_standard": "1000BASE-T",
            "record_time_span": 1,
            "test_status_code": 1,
        }
        apps = [appearance]
        if i < 208:
            apps.append({**appearance, "source_row": i+477,
                         "project": "Park Network"})
        tests.append({
            "test_uuid": f"00000000-0000-4000-8000-{i:012d}",
            "preferred_display_cable_name": label,
            "preferred_project": "MSB-Park-Network",
            "source_appearances": apps,
        })
    source = {
        "sha256": "e"*64,
        "source_row_count": 684,
        "unique_test_count": 476,
        "duplicate_project_appearances": 208,
        "variant_measurement_conflicts": [],
        "tests": tests,
    }
    return html, prior, source


def test_regenerates_unique_uuid_evidence_with_old_schematic_marked_unreviewed(monkeypatch):
    html, prior, extracted = example_data()
    monkeypatch.setattr(candidate, "extract_flw", lambda path: extracted)
    result, receipt = candidate.rebuild_network_source(Path("corrected.flw"), html, prior)
    counts = receipt["counts"]
    assert counts["saved_test_uuids"] == 476
    assert counts["source_project_rows"] == 684
    assert counts["duplicate_project_appearances"] == 208
    assert counts["cables_with_parseable_active_names"] == 475
    assert counts["tests_requiring_name_or_delete_review"] == 1
    assert len(result["cables"]) + len(result["review_records"]) == 476
    assert len(result["mapped_routes"]) + len(result["unresolved_routes"]) == 181
    assert len({r["source_id"] for r in result["cables"] + result["review_records"]}) == 476
    assert sum(r["project_appearances"] for r in result["cables"] + result["review_records"]) == 684
    assert result["source_name"] == "corrected.flw"
    assert result["source_sha256"] == "e"*64
    assert result["schematic_status"] == "PRIOR_DRAWIO_SNAPSHOT_UNREVIEWED"
    assert result["source_identities_reviewed"] is False
    assert result["devices"] == prior["devices"]
    assert result["cables"][0]["attributes"]["Cable_ID"] == "PANEL A5-00 TO A5-07/09 REG"
    assert result["cables"][0]["drawio_matches"] == []
    assert len(receipt["review_records"]) == 1
    assert receipt["review_records"][0]["reason"] == "NAME_REQUIRES_REVIEW"


def test_rejects_disagreeing_source_baseline(monkeypatch):
    html, prior, extracted = example_data()
    extracted["unique_test_count"] = 475
    monkeypatch.setattr(candidate, "extract_flw", lambda path: extracted)
    import pytest
    with pytest.raises(ValueError, match="684 rows / 476"):
        candidate.rebuild_network_source(Path("corrected.flw"), html, prior)


def test_rejects_route_id_drift(monkeypatch):
    html, prior, extracted = example_data()
    prior["unresolved_routes"].pop()
    monkeypatch.setattr(candidate, "extract_flw", lambda path: extracted)
    import pytest
    with pytest.raises(ValueError, match="Changed/lost route IDs"):
        candidate.rebuild_network_source(Path("corrected.flw"), html, prior)
