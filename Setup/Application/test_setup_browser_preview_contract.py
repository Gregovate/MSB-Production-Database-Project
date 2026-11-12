from __future__ import annotations

from pathlib import Path


APP_DIR = Path(__file__).resolve().parent
SETUP_DIR = APP_DIR.parent
ACCEPT = SETUP_DIR / "Acceptance"
BASE_CANDIDATE_SHA = "c0b6e4342129516f2f9b344acd4331f4e068e23b"
CANDIDATE_SHA = "7362c6aece365448f21cb91f4ceebf2752da3375"
SERVER_SHA_PLACEHOLDER = "c72644f02b825acb830603fe6b4f7bd48713b681"


def read_acceptance(name: str) -> str:
    return (ACCEPT / name).read_text(encoding="utf-8")


def test_preview_harness_files_exist() -> None:
    for name in (
        "run_setup_session_browser_preview.ps1",
        "run_setup_session_browser_preview_patch_impl.ps1",
        "run_setup_session_browser_preview_impl.ps1",
        "setup_session_browser_preview_server.sh",
        "setup_session_browser_preview_entry.py",
        "setup_session_browser_preview_cleanup_server.sh",
    ):
        assert (ACCEPT / name).is_file(), name


def test_preview_pins_exact_candidate_and_disposable_database() -> None:
    launcher = read_acceptance("run_setup_session_browser_preview.ps1")
    patch = read_acceptance("run_setup_session_browser_preview_patch_impl.ps1")
    impl = read_acceptance("run_setup_session_browser_preview_impl.ps1")
    server = read_acceptance("setup_session_browser_preview_server.sh")

    assert "run_setup_session_browser_preview_patch_impl.ps1" in launcher
    assert f"`$CandidateSha = '{BASE_CANDIDATE_SHA}'" in patch
    assert f"`$CandidateSha = '{CANDIDATE_SHA}'" in patch
    assert f"$CandidateSha = '{BASE_CANDIDATE_SHA}'" in impl
    assert f'$targetOld = \'TARGET_SHA="{SERVER_SHA_PLACEHOLDER}"\'' in impl
    assert '$targetNew = "TARGET_SHA=`"$CandidateSha`""' in impl
    assert '$serverText = $serverText.Replace($targetOld, $targetNew)' in impl
    assert f'TARGET_SHA="{SERVER_SHA_PLACEHOLDER}"' in server
    assert 'TEST_CONTAINER="msb-setup-browser-preview-' in server
    assert 'pg_dump -U "$DB_ACTOR" -d "$PROD_DB" -Fc' in server
    assert 'pg_restore -U "$DB_ACTOR" -d "$TEST_DB" --no-owner --no-acl --exit-on-error' in server
    assert 'SETUP_DATABASE_DSN="$DSN"' in server
    assert 'Production DB:  pg_dump + SELECT only' in server
    assert 'Preview writes: disposable PostgreSQL clone only' in server


def test_preview_packages_full_review_contract_into_detached_gate() -> None:
    impl = read_acceptance("run_setup_session_browser_preview_impl.ps1")
    patch = read_acceptance("run_setup_session_browser_preview_patch_impl.ps1")
    composed = impl + patch
    for contract in (
        "test_setup_google_doc_index_contract.py",
        "test_setup_review_usability_contract.py",
        "test_setup_next_pass_contract.py",
        "test_setup_final_scope_contract.py",
        "test_setup_browser_acceptance_findings_contract.py",
    ):
        assert contract in composed
    assert "$serverText = $serverText.Replace($testOld, $testNew)" in impl
    assert "Replace-Required" in patch


def test_preview_applies_008_through_014_only_to_disposable_clone() -> None:
    server = read_acceptance("setup_session_browser_preview_server.sh")
    impl = read_acceptance("run_setup_session_browser_preview_impl.ps1")
    patch = read_acceptance("run_setup_session_browser_preview_patch_impl.ps1")
    composed = impl + patch

    assert '008_create_setup_resource_management_commands.sql' in server
    for migration in (
        '009_create_setup_scope_schedule_execution_commands.sql',
        '010_seed_2025_stage02_elf_scope_corrections.sql',
        '011_create_setup_planning_order_and_crew_lanes.sql',
        '012_seed_site_infrastructure_review_tasks.sql',
        '013_fix_setup_task_creation_command.sql',
        '014_grant_setup_scene_field_context_read.sql',
    ):
        assert migration in composed
    assert 'psql_test < "$RESOURCE_MIGRATION"' in impl
    assert 'psql_test < "$NEXT_PASS_MIGRATION"' in impl
    assert 'psql_test < "$REVIEW_CORRECTION_SEED"' in impl
    assert 'psql_test < "$CREATE_TASK_FIX"' in patch
    assert 'psql_test < "$SCENE_CONTEXT_GRANT"' in patch
    assert 'Migrations 008-014 are applied only to that disposable clone.' in patch
    assert '[PREVIEW ONLY] Execution reset to READY' in impl
    assert 'Production DB:  pg_dump + SELECT only' in server


def test_preview_validates_stage_scene_review_corrections() -> None:
    impl = read_acceptance("run_setup_session_browser_preview_impl.ps1")
    assert "02-Mega Tree" in impl
    assert "02-Fred''s Stars" in impl
    assert "Install Fred''s Stars" in impl
    assert "Boom Lift" in impl
    assert "Elf Choir Locates prerequisite is missing" in impl
    assert "Final Stage/Scene/Command Center/Park Infrastructure validation: PASS" in impl


def test_preview_preserves_setup_authorization_and_no_broad_dml() -> None:
    server = read_acceptance("setup_session_browser_preview_server.sh")
    impl = read_acceptance("run_setup_session_browser_preview_impl.ps1")

    assert "ref.setup_browser_capabilities(text)" in server
    assert "ref.setup_management_actor(text,boolean)" in server
    assert "ops.create_setup_session(text,integer,text)" in server
    assert "ref.create_setup_task(" in server
    assert "ref.update_setup_task(" in server
    assert "ops.update_setup_session_task_review(" in server
    assert "has_table_privilege('fieldwiring_app', 'ref.setup_task', 'UPDATE')" in server
    assert "has_table_privilege('fieldwiring_app', 'ref.setup_task_resource', 'UPDATE')" in server
    assert "has_table_privilege('fieldwiring_app', 'ops.setup_session_task', 'UPDATE')" in server
    assert "has_table_privilege('fieldwiring_app', 'ops.setup_movement_event', 'INSERT')" in server
    assert "has_table_privilege('fieldwiring_app', 'directus_users', 'SELECT')" in server
    assert "has_table_privilege('fieldwiring_app', 'ops.setup_task_progress', 'INSERT')" in impl
    assert "has_table_privilege('fieldwiring_app', 'ops.setup_work_day_task', 'UPDATE')" in impl
    assert "has_table_privilege('fieldwiring_app', 'ref.setup_task_dependency', 'INSERT')" in impl
    assert "ref.set_setup_task_scope(text,bigint,integer,bigint)" in impl
    assert "ref.set_setup_task_dependency(text,bigint,bigint,text,boolean)" in impl
    assert "ops.upsert_setup_work_day(text,integer,date,text,text)" in impl
    assert "ops.record_setup_task_progress(text,bigint,bigint,text,integer,integer,text,text,boolean)" in impl


def test_preview_uses_separate_local_port_and_foreground_ssh() -> None:
    server = read_acceptance("setup_session_browser_preview_server.sh")
    launcher = read_acceptance("run_setup_session_browser_preview.ps1")
    impl = read_acceptance("run_setup_session_browser_preview_impl.ps1")

    assert 'PREVIEW_PORT="${1:-8794}"' in server
    assert "[Parameter(Mandatory=$true)]" in launcher
    assert "[int]$PreviewPort," in launcher
    assert "PreviewPort 8794 is the live Production Setup listener" in launcher
    assert 'MSB_SETUP_PREVIEW_HOST="127.0.0.1"' in server
    assert 'http://127.0.0.1:$PREVIEW_PORT/' in server
    assert '& ssh -tt -L "${PreviewPort}:127.0.0.1:${PreviewPort}"' in impl
    assert 'Start-Process $browserUrl' not in launcher + impl
    assert 'setsid /opt/fieldwiring/.venv/bin/python "$MSB_SETUP_PREVIEW_ENTRY"' in server
    assert "setsid sudo" not in server


def test_preview_packages_post_start_validator_under_fieldwiring_account() -> None:
    impl = read_acceptance("run_setup_session_browser_preview_impl.ps1")
    assert '$validatorOld = "/opt/fieldwiring/.venv/bin/python -' in impl
    assert '$validatorNew = "sudo -u fieldwiring -H /opt/fieldwiring/.venv/bin/python -' in impl
    assert '$serverText = $serverText.Replace($validatorOld, $validatorNew)' in impl


def test_preview_uses_production_setup_app_and_read_only_display_folders() -> None:
    entry = read_acceptance("setup_session_browser_preview_entry.py")
    server = read_acceptance("setup_session_browser_preview_server.sh")

    assert "from production_backend import app" in entry
    assert 'HTTP_CF_ACCESS_AUTHENTICATED_USER_EMAIL' in entry
    assert 'SETUP_DRIVE_ROOT="/mnt/msb-display-folders"' in server
    assert 'systemctl is-active --quiet msb-display-folders.service' in server
    assert "test -r /mnt/msb-display-folders" in server
    assert "test -x /mnt/msb-display-folders" in server


def test_preview_uses_lazy_google_doc_link_view_without_recursive_scan() -> None:
    server = read_acceptance("setup_session_browser_preview_server.sh")

    assert '/usr/bin/rclone mount msb-display-folders:' in server
    assert '--drive-export-formats link.html' in server
    assert 'SETUP_GOOGLE_DOC_LINK_ROOT="$GOOGLE_DOC_LINK_ROOT"' in server
    assert 'Lazy Google Doc link view: PASS' in server
    assert 'Mega Cube Google Doc/native Word discrimination: PASS' in server
    assert '03-Mega Cube-MC Setup Procedure.link.html' in server
    assert 'Mega Cube - Randy.docx' in server
    assert 'rclone lsjson' not in server
    assert '--recursive' not in server
    assert 'SETUP_GOOGLE_DOC_INDEX=' not in server


def test_preview_checks_new_stage_scene_schedule_and_captain_read_surfaces() -> None:
    impl = read_acceptance("run_setup_session_browser_preview_impl.ps1")
    assert "/api/setup/organization" in impl
    assert "/api/setup/schedule?season_year=2025" in impl
    assert "/api/setup/execution?season_year=2025" in impl
    assert "Organization + ordered backlog + Schedule + Captain read APIs: PASS" in impl
    assert "Review Stage/Scene grouping" in impl
    assert "Perform Work" in impl
    assert "movement/scanning writes remain intentionally absent" in impl


def test_preview_checks_resource_api_and_review_target() -> None:
    server = read_acceptance("setup_session_browser_preview_server.sh")
    assert '/api/setup/resources' in server
    assert 'Front Entrance should show SkyTrak + Boom Lift' in server
    assert 'Equipment / Resources Needed' in server


def test_preview_cleanup_guards_live_checkout_setup_fingerprint_and_link_mount() -> None:
    server = read_acceptance("setup_session_browser_preview_server.sh")
    cleanup = read_acceptance("setup_session_browser_preview_cleanup_server.sh")

    assert "prod_fingerprint()" in server
    assert "FROM ref.setup_resource r" in server
    assert "FROM ref.setup_task_resource tr" in server
    assert "Production Setup fingerprint unchanged" in server
    assert "live shared checkout unchanged" in server
    assert "worktree remove --force" in server
    assert "docker rm -f" in server
    assert 'mountpoint -q "$GOOGLE_DOC_LINK_ROOT"' in server
    assert 'fusermount -u "$GOOGLE_DOC_LINK_ROOT"' in server
    assert "msb-setup-browser-preview-candidate-" in cleanup
    assert "msb-setup-browser-preview-" in cleanup


def test_stale_cleanup_handles_msb_docs_fs_owned_mount_root_and_fails_closed() -> None:
    cleanup = read_acceptance("setup_session_browser_preview_cleanup_server.sh")
    impl = read_acceptance("run_setup_session_browser_preview_impl.ps1")

    assert 'sudo rm -rf -- "$link_root"' in cleanup
    assert 'FAIL: stale Setup Google Doc link view is still mounted' in cleanup
    assert "&& timeout --signal=TERM 28800s bash '$remoteScript'" in impl
    assert "; timeout --signal=TERM 28800s bash '$remoteScript'" not in impl
    assert 'timeout --signal=TERM 7200s' not in impl
