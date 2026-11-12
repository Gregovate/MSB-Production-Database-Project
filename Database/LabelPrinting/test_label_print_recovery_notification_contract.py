"""Static safety contract for the Label Print notification migration."""

from pathlib import Path
import unittest


SQL = Path(__file__).with_name(
    "001_label_print_recovery_notifications.sql"
).read_text(encoding="utf-8")
ACCEPTANCE = Path(__file__).with_name(
    "label_print_disposable_acceptance.sql"
).read_text(encoding="utf-8")
ITEM_NAMES = Path(__file__).with_name(
    "002_label_print_human_readable_request_items.sql"
).read_text(encoding="utf-8")


class LabelPrintRecoveryNotificationContractTests(unittest.TestCase):
    def test_migration_is_fail_closed_and_not_self_authorizing(self) -> None:
        self.assertIn("approved_maintenance_snapshot", SQL)
        self.assertIn("approved_disposable_clone", SQL)
        self.assertIn("label_print_mail", SQL)
        self.assertNotIn("INSERT INTO ops.label_print_notification_admin", SQL)
        self.assertNotIn("smtp-relay.gmail.com", SQL)
        self.assertNotIn("smtplib", SQL)

    def test_requester_identity_is_frozen_at_request_time(self) -> None:
        self.assertIn("CREATE TABLE ops.label_print_request", SQL)
        self.assertIn("requester_verified", SQL)
        self.assertIn("LEGACY_ROW_AUDIT", SQL)
        self.assertIn("zz_controller_label_request_capture", SQL)
        self.assertIn("zz_display_label_request_capture", SQL)
        self.assertIn("zz_container_label_request_capture", SQL)

    def test_printservice_has_narrow_functions_not_table_access(self) -> None:
        self.assertIn("ops.label_print_heartbeat", SQL)
        self.assertIn("ops.label_print_incident_upsert", SQL)
        self.assertIn("ops.label_print_incident_resolve", SQL)
        self.assertIn("GRANT EXECUTE ON FUNCTION", SQL)
        self.assertNotIn("GRANT SELECT ON ops.label_print_notification_outbox", SQL)
        self.assertNotIn("GRANT INSERT ON ops.label_print_notification_outbox", SQL)

    def test_dedup_and_conservative_delivery_states_are_durable(self) -> None:
        self.assertIn("event_key text PRIMARY KEY", SQL)
        for state in (
            "SMTP_ACCEPTED",
            "FAILED_BEFORE_DATA",
            "REJECTED",
            "UNKNOWN",
        ):
            self.assertIn(state, SQL)
        self.assertIn("delivery_key text PRIMARY KEY", SQL)
        self.assertIn("UNIQUE (event_key, attempt_number)", SQL)
        self.assertIn("bounded_retry_scheduled_after_proven_no_send", SQL)

    def test_resolution_email_requires_prior_smtp_acceptance(self) -> None:
        self.assertIn("active_event.delivery_status = 'SMTP_ACCEPTED'", SQL)

    def test_requesters_receive_success_and_media_events(self) -> None:
        self.assertIn("CREATE FUNCTION ops.label_print_queue_success_events", SQL)
        self.assertIn("'REQUESTER_SUCCESS'", SQL)
        self.assertIn("'PREFLIGHT_MEDIA', 'ACTIVE_MEDIA'", SQL)
        self.assertIn("'print-success:'", SQL)

    def test_requester_items_always_include_names_and_ids(self) -> None:
        self.assertIn("d.display_name", ITEM_NAMES)
        self.assertIn("c.description", ITEM_NAMES)
        self.assertIn("c.location_code", ITEM_NAMES)
        self.assertIn("m.model_code", ITEM_NAMES)
        self.assertIn("m.model_name", ITEM_NAMES)
        self.assertIn("Display ID", ITEM_NAMES)
        self.assertIn("CTRL:", ITEM_NAMES)
        self.assertIn("trg_label_print_humanize_outbox_request_items", ITEM_NAMES)
        self.assertIn("WV-MtCrumpit-Scaffold-01 (Display ID 8)", ACCEPTANCE)
        self.assertIn("Mt. Crumpit controller tote (C037)", ACCEPTANCE)
        self.assertIn(
            "CTB32 — CTB32 Generation 3 Controller Board (CTRL:1001)",
            ACCEPTANCE,
        )

    def test_admin_is_reserved_for_unrecovered_or_unhealthy_state(self) -> None:
        self.assertIn(
            "'FAILED_BATCH', 'OBSERVATION', 'SERVICE_HEARTBEAT'",
            SQL,
        )
        self.assertIn("incident_resolved_before_send", SQL)

    def test_watchdog_is_server_side_and_deduplicated(self) -> None:
        self.assertIn("CREATE FUNCTION ops.label_print_watchdog_evaluate", SQL)
        self.assertIn("service:PRINT-SERVER:heartbeat-stale", SQL)
        self.assertIn("ON CONFLICT (event_key) DO NOTHING", SQL)

    def test_restart_recovery_evidence_is_durable_and_narrow(self) -> None:
        self.assertIn("CREATE TABLE ops.label_print_batch_recovery", SQL)
        self.assertIn("brother_active_observed", SQL)
        self.assertIn("spooler_cleared", SQL)
        self.assertIn("ready_idle_observed", SQL)
        self.assertIn("RECONCILIATION_REQUIRED", SQL)
        self.assertIn("ops.label_print_recovery_checkpoint", SQL)
        self.assertIn("ops.label_print_recovery_candidates", SQL)
        self.assertIn("ops.label_print_release_batch_requests", SQL)

    def test_disposable_acceptance_exercises_requested_operating_rules(self) -> None:
        for evidence in (
            "24 mm laminated tape",
            "REQUESTER_SUCCESS",
            "ADMIN_ACTIVE",
            "FAILED_BEFORE_DATA",
            "SMTP_ACCEPTED",
            "RELEASED_NO_SUBMISSION",
            "least-privilege boundary",
        ):
            self.assertIn(evidence, ACCEPTANCE)


if __name__ == "__main__":
    unittest.main()
