"""#171 actual served Park Map must show GPX Workshop, never obsolete marker."""
from pathlib import Path

from stage_locate_source_preview import build_review
from test_stage_locate_source_preview import setup_fixture
from verify_locate_workshop_preview import inspect_served_html


def test_reviewed_preview_has_real_workshop_only(tmp_path):
    config, review, repo, _ = setup_fixture(tmp_path)
    dest = tmp_path / "preview"
    build_review(config=config, review_folder=review, repo=repo,
                 output_root=dest)
    page = (dest / "setup" / "locate" / "index.html").read_text(encoding="utf-8")
    summary = inspect_served_html(page)
    assert summary["result"] == "CORRECTED_GPX_PREVIEW"
    assert summary["real_workshop_count"] == 1
    assert summary["obsolete_temporary_workshop_present"] is False
    assert summary["gpx_points"] == 233
    assert summary["gpx_tracks"] == 181


def test_old_preview_warns_even_if_real_gpx_point_is_present(tmp_path):
    config, review, repo, _ = setup_fixture(tmp_path)
    old = (review / "park-map-corrected-candidate.html").read_text(encoding="utf-8")
    summary = inspect_served_html(old)
    assert summary["real_workshop_count"] == 1
    assert summary["obsolete_temporary_workshop_present"] is True
    assert summary["result"] == "STALE_OR_WRONG_MAP"
