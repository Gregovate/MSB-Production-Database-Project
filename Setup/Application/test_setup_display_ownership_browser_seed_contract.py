from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SEED = ROOT / "Acceptance" / "setup_display_ownership_browser_seed.sql"


def source() -> str:
    return SEED.read_text(encoding="utf-8")


def test_browser_seed_prepares_magic_igloo_without_materializing_ownership() -> None:
    sql = source()
    assert "DISPOSABLE BROWSER PREVIEW ONLY" in sql
    assert "Layout / Erect Frame / Strap Down" in sql
    assert "Install Skins and Bungees" in sql
    assert "Install Lighting, Cameras, Mats, Signs, and Finish Setup" in sql
    assert "set_setup_task_display_material_requirement" in sql
    assert "Browser seed must not create explicit Display ownership rows" in sql
    assert "FROM ref.set_setup_task_display_owner(" not in sql


def test_browser_seed_requires_uninitialized_stage26_ownership() -> None:
    sql = source()
    assert "Browser seed requires uninitialized Stage 26 ownership" in sql
    assert "magic_igloo_source_displays" in sql
    assert "v_existing_owner_count <> 0" in sql


def test_browser_seed_preserves_no_2026_session_boundary() -> None:
    sql = source()
    assert "WHERE ss.season_year = 2026" in sql
    assert "Browser seed must not create a 2026 Setup Session" in sql
    assert "SETUP_DISPLAY_OWNERSHIP_BROWSER_SEED_PASS" in sql
