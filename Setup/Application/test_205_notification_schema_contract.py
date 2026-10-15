"""Static #205 checks complement actual disposable migration 074/Postgres tests."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
APP = Path(__file__).resolve().parent


def test_outbox_migration_is_closed_on_db_identity_and_dedup():
    sql = (ROOT/"Database/074_add_setup_notification_outbox.sql").read_text()
    for token in (
        "CREATE TABLE public.setup_notification_outbox",
        "message_key text NOT NULL UNIQUE",
        "CREATE TRIGGER trg_guard_setup_notification_outbox",
        "CREATE TRIGGER trg_setup_notice_immutable",
        "ref.setup_browser_capabilities(lower(btrim(p.email)))",
        "c.captain_person_id=NEW.recipient_person_id",
        "NOT EXISTS (",
        "p.setup_work_day_task_id=a.setup_work_day_task_id",
        "wd.day_status <> 'CANCELLED'",
        "NEW.message_key IS DISTINCT FROM v_expected_key",
        "recipient_email",
        "GRANT SELECT, INSERT, UPDATE ON public.setup_notification_outbox TO directus_app",
        "REVOKE ALL ON public.setup_notification_outbox FROM fieldwiring_app",
        "ON CONFLICT (collection) DO NOTHING",
    ):
        assert token in sql
    assert "INSERT INTO public.directus_flows" not in sql
    assert "INSERT INTO stage.work_order_intake" not in sql


def test_disposable_validation_rolls_back_and_proves_security():
    sql = (ROOT/"Acceptance/setup_205_notification_outbox_disposable_validation.sql").read_text()
    assert sql.startswith("/* #205")
    assert "BEGIN;" in sql and sql.rstrip().endswith("ROLLBACK;")
    for expected in ("unique_violation","INVALID MANAGER ADDRESS WAS ACCEPTED",
                     "INVALID IDEMPOTENCY KEY WAS ACCEPTED",
                     "OUTBOX RECIPIENT RETARGET WAS ACCEPTED",
                     "can_manage_setup", "dispatch_status"):
        assert expected in sql


def test_notification_api_integrated_and_sending_off_by_default():
    prod = (APP/"production_backend.py").read_text()
    service = (APP/"setup_notification_service.py").read_text()
    api = (APP/"setup_notification_api.py").read_text()
    assert "app.register_blueprint(setup_notification_api)" in prod
    assert '"/items/setup_notification_outbox"' in service
    assert "SETUP_NOTIFICATION_DAILY_ENABLED" in service
    assert "SETUP_NOTIFICATION_TEST_SEND_ENABLED" in service
    assert "DIRECTUS_OPENER" in service
    assert "import smtplib" not in service
    assert "work_order_intake" not in service
    assert '"/api/setup/notifications/email-myself"' in api
    assert '"MANAGER_SELF_TEST"' in api
    assert "require_manager()" in api and "require_setup_command()" in api
