"""#419: source-only guards for the governed, read-only unified ticket ledger.

These tests protect the database integration contract, not live PostgreSQL
permissions or browser behavior. Live/disposable acceptance is separate.
"""
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
WO_DIR = (
    ROOT
    / "Docs/02_Production_Database/01_System_Architecture/06_Work_Orders"
)
SQL = WO_DIR / "engineering/WO419_Unified_Ticket_Read_Only_Candidate.sql"
DESIGN = WO_DIR / "Work_Order_System_Design.md"


def test_419_unified_ticket_ledger_reads_both_authoritative_sources():
    sql = SQL.read_text(encoding="utf-8")
    for token in (
        "FROM ops.work_order w",
        "FROM stage.work_order_intake i",
        "ops.work_order_assignment a",
        "ops.work_order_status_history h",
        "ref.work_order_status s",
        "UNION ALL",
        "source_intake_id AS intake_id",
        "i.intake_id",
        "'TASK_FEEDBACK'",
        "'WORK_ORDER'",
    ):
        assert token in sql, token


def test_419_ticket_ledger_preserves_completion_and_assignment_truth():
    sql = SQL.read_text(encoding="utf-8")
    for token in (
        "a.active_flag",
        "w.date_completed",
        "w.is_active",
        "h.changed_at DESC",
        "'DONE_DATE_ONLY'",
        "'STATUS_NOT_RECORDED'",
        "'CORRECTION_OWNER_NOT_TRACKED'",
        "'UNASSIGNED'",
    ):
        assert token in sql, token
    # Do not regress to the archival table or bypass the Person/role boundary.
    assert "work_order_assignee" not in sql
    assert "directus_users" not in sql


def test_419_ticket_ledger_is_source_only_read_model():
    sql = SQL.read_text(encoding="utf-8")
    actual_sql = "\n".join(
        line for line in sql.splitlines()
        if not line.lstrip().startswith("--")
    ).lstrip().upper()
    assert actual_sql.startswith("WITH ASSIGNMENT_ROLLUP AS")
    for statement in (
        "CREATE TABLE",
        "CREATE VIEW",
        "ALTER TABLE",
        "DROP TABLE",
        "INSERT INTO",
        "DELETE FROM",
        "TRUNCATE",
        "UPDATE OPS.",
        "UPDATE STAGE.",
        "SELECT STAGE.P_PROCESS_WORK_ORDER_INTAKE",
        "SET ROLE",
        "GRANT ",
    ):
        assert statement not in actual_sql, statement


def test_419_design_is_authority_for_reader_and_reporter_closure():
    design = DESIGN.read_text(encoding="utf-8").casefold()
    for required in (
        "## #419 — Unified MSB Work Management Application Contract",
        "**Engineering authority and status:**",
        "**Status interpretation:**",
        "**Every actionable item must be discoverable",
        "Request Clarification",
        "January review",
        "source provenance",
    ):
        assert required.casefold() in design, required


def test_419_scope_uses_real_person_ids_not_display_names():
    """App may choose Me / All / another assignee using stable Person IDs."""
    sql = SQL.read_text(encoding="utf-8")
    design = DESIGN.read_text(encoding="utf-8")
    for token in (
        "a.person_id",
        "a.active_flag",
        "active_assignee_person_ids",
        "array_agg(DISTINCT a.person_id ORDER BY a.person_id)",
        "NULL::integer[] AS active_assignee_person_ids",
        "active_assignee_person_ids AS assignee_ids",
    ):
        assert token in sql, token
    for token in (
        "### Work Order landing view — default My Work",
        "All Work Orders",
        "Show completed",
        "ref.person.person_id",
        "server-side",
    ):
        assert token in design, token


def test_419_testing_origin_is_explicit_and_not_a_fake_intake():
    """Testing-generated repairs must link back to the real Test Session."""
    sql = SQL.read_text(encoding="utf-8")
    design = DESIGN.read_text(encoding="utf-8")
    for token in (
        "w.display_test_session_id AS test_detail_id",
        "w.display_id AS display_id",
        "NULL::bigint AS test_detail_id",
        "NULL::bigint AS display_id",
        "test_detail_id AS test_id",
        "display_id AS disp_id",
        "w.submitted_by_person_id AS reporter_person_id",
        "i.submitter_person_id AS reporter_person_id",
    ):
        assert token in sql, token
    for token in (
        "### Test Session-generated Work Orders — feedback and ownership",
        "Test Session repair",
        "No competing communication model",
        "does **not** automatically have an original Intake reporter",
    ):
        assert token.casefold() in design.casefold(), token


def test_419_directus_cutover_is_per_event_and_testing_safe():
    """A unified app cannot run alongside competing Directus event handlers."""
    design = DESIGN.read_text(encoding="utf-8")
    readme = (WO_DIR / "README.md").read_text(encoding="utf-8")
    section_title = (
        "### Directus Flow retirement and one-authority Production cutover"
    )
    assert section_title in design
    section = design.split(section_title, 1)[1].split(
        "### Permission, integration, and engineering sequence", 1
    )[0]

    for flow in (
        "WOI Request Triage Email",
        "Work Order Email Assignees",
        "Create Repair Work Order",
        "Work Order Complete-Update Display Test Session",
        "Work Order – Auto Complete Fields",
        "Work Order Promote from Intake",
    ):
        assert flow in section, flow

    for requirement in (
        "one authoritative writer",
        "one authorized notification producer",
        "Do not bulk-disable every Work Order Flow",
        "duplicate",
        "rollback",
        "Test Session",
        "exact live Flow IDs",
        "governing Server Management",
        "no lost Intake",
        "RUNBOOK GAP FOUND",
        "before any Production Flow change",
    ):
        assert requirement.casefold() in section.casefold(), requirement

    assert "Launch blocker" in readme
    assert "per-event Directus Flow" in readme


def test_419_disposable_browser_acceptance_is_end_to_end():
    """#419 candidate cannot stop at a static list or a mock mail success."""
    design = DESIGN.read_text(encoding="utf-8")
    readme = (WO_DIR / "README.md").read_text(encoding="utf-8")
    section_title = "### #419 disposable end-to-end browser acceptance candidate"
    assert section_title in design
    section = design.split(section_title, 1)[1].split(
        "### Permission, integration, and engineering sequence", 1
    )[0]
    for required in (
        "My Work",
        "All Work Orders",
        "Show completed",
        "New Internal Work Order",
        "choose assignees",
        "Task Feedback",
        "clarification",
        "reporter",
        "display_test_session_id",
        "current-Production PostgreSQL clone",
        "test-only",
        "exact source SHA",
        "CLEAN EXIT",
        "Server Management Application and Test Port Register",
        "Do not call the design complete",
    ):
        assert required.casefold() in section.casefold(), required
    assert "first integrated application review target" in readme
    assert "not merged, built or deployed" in readme


def test_419_p0_reporter_email_and_one_step_promotion_are_release_gates():
    """Existing Intake + Work Orders need closed-loop reporting before launch."""
    design = DESIGN.read_text(encoding="utf-8")
    readme = (WO_DIR / "README.md").read_text(encoding="utf-8")
    heading = (
        "### P0 first-release gate — reporter clarification, outcome email, "
        "and one-step triage"
    )
    assert heading in design
    p0 = design.split(heading, 1)[1].split(
        "### Accountability and two-way reporter communication", 1
    )[0]
    for required in (
        "P0 release blockers",
        "Request More Information",
        "Send Request",
        "original verified reporter",
        "View/Respond",
        "same ticket",
        "final outcome email",
        "Promote is not Complete",
        "Promote & Assign",
        "one transaction",
        "assignee_count=0",
        "original Intake remains actionable",
        "Repeated clicks",
        "no-send",
        "INTAKE-60",
        "INTAKE-40",
        "Test Session",
        "do not deploy",
    ):
        assert required.casefold() in p0.casefold(), required
    assert "**#419 P0 first-release acceptance:**" in readme
    assert "None of these P0 actions has been implemented" in readme


def test_419_setup_task_feedback_consumed_as_alternate_correction_workflow():
    """Do not turn every Setup finding into a repair Work Order."""
    design = DESIGN.read_text(encoding="utf-8")
    readme = (WO_DIR / "README.md").read_text(encoding="utf-8")
    heading = "### Setup Task Feedback consumption — alternate correction workflow (P0)"
    assert heading in design
    section = design.split(heading, 1)[1].split(
        "### P0 first-release gate", 1
    )[0]

    for requirement in (
        "existing Setup Task Feedback",
        "separate",
        "stage.work_order_intake",
        "source_form_name='SETUP_CORRECTION'",
        "source_payload",
        "ops.prepare_setup_work_order_intake",
        "What did you find?",
        "Manager",
        "non-Work-Order correction",
        "assigned to the authorized owning subsystem",
        "Request More Information",
        "outcome email",
        "Triage → Promote & Assign",
        "not automatically prove",
        "triage_dropdown='4'",
        "Intake #60",
        "#209",
        "disposable",
        "not yet implemented",
    ):
        assert requirement.casefold() in section.casefold(), requirement

    assert "**#419 Setup Task Feedback consumer (P0):**" in readme
    assert "the work management consumer and alternate correction workflow are not" in (
        readme.casefold()
    )


def test_419_setup_correction_input_remains_existing_172_contract():
    """Actual #172 submitter provenance is not replaced by a new public form."""
    source = ROOT / "Setup/Database/062_add_setup_context_work_order_intake.sql"
    api = ROOT / "Setup/Application/setup_work_order_intake_api.py"
    assert source.is_file()
    assert api.is_file()
    sql = source.read_text(encoding="utf-8")
    handler = api.read_text(encoding="utf-8")
    for required in (
        "'source_form_name', 'SETUP_CORRECTION'",
        "'source_payload', v_payload",
        "'reporter_person_id', v_person_id",
        "'setup_session_task_id', p_setup_session_task_id",
        "'setup_work_day_task_id', p_setup_work_day_task_id",
        "'procedure_context', v_procedure",
        "'triage_dropdown', '1'",
    ):
        assert required in sql, required
    assert "directus_client().create_intake(intake_payload)" in handler


def test_419_correction_category_and_typed_source_references():
    """A correction stays distinct from repair and may refer to many existing objects."""
    design = DESIGN.read_text(encoding="utf-8")
    readme = (WO_DIR / "README.md").read_text(encoding="utf-8")
    section = design.split(
        "### Correction category and linked references — P0", 1
    )[1].split("### Setup Task Feedback consumption", 1)[0]
    for phrase in (
        "**Repair** and **Correction**",
        "Correction / Task Feedback",
        "Kit Inventory / Extra Materials",
        "Procedure / Work Instructions",
        "more than one linked object",
        "ref.container.container_id",
        "ref.container.container_type_id=2",
        "ref.setup_task_container_support",
        "ref.setup_container_extra_material",
        "ref.display.display_id",
        "display_name",
        "source_payload.procedure_context",
        "optional searchable selector",
        "reference kind",
        "Add related item",
        "Kit Inventory correction",
        "Procedure correction",
        "not an assertion",
    ):
        assert phrase.casefold() in section.casefold(), phrase
    assert "**#419 correction categories and source links (P0):**" in readme
    assert "don't invent a second Kit identity" in readme


def test_419_existing_kit_and_procedure_references_are_reused():
    """Protect real Kit Box container and existing Setup Procedure resolver."""
    kit_api = (ROOT / "Setup/Application/setup_kit_inventory_api.py").read_text(
        encoding="utf-8"
    )
    for token in (
        "FROM ref.container AS c",
        "WHERE c.container_type_id = 2",
        "ref.setup_task_container_support",
        "tc.relationship_type = 'KIT'",
        "ref.setup_container_extra_material",
        "FROM ref.display AS d",
        "d.display_id",
    ):
        assert token in kit_api, token

    correction_api = (
        ROOT / "Setup/Application/setup_work_order_intake_api.py"
    ).read_text(encoding="utf-8")
    correction_sql = (
        ROOT / "Setup/Database/062_add_setup_context_work_order_intake.sql"
    ).read_text(encoding="utf-8")
    for token in (
        '"scope_type": scope_type',
        '"documents": documents',
        'for item in (instructions.get("current_documents") or [])',
    ):
        assert token in correction_api, token
    for token in (
        "'procedure_context', v_procedure",
        "'setup_session_task_id', p_setup_session_task_id",
        "'setup_work_day_task_id', p_setup_work_day_task_id",
        "'source_form_name', 'SETUP_CORRECTION'",
    ):
        assert token in correction_sql, token


def test_419_stage_resource_discovery_has_explicit_provenance():
    """Show relevant Stage/Scene resources even when the reporting task lacks links."""
    design = DESIGN.read_text(encoding="utf-8")
    readme = (WO_DIR / "README.md").read_text(encoding="utf-8")
    heading = "### Stage-first relevant resources — no scavenger hunt (P0)"
    assert heading in design
    section = design.split(heading, 1)[1].split(
        "### Setup Task Feedback consumption", 1
    )[0]
    for required in (
        "Stage Setup context is the starting point",
        "Related Information",
        "Directly linked to this task",
        "Related to this Scene",
        "Related to this Stage",
        "Confirmed for this correction",
        "ref.setup_task_container_support",
        "ref.setup_task_extra_material",
        "ref.setup_container_extra_material",
        "ref.lor_scene_display",
        "source_payload.procedure_context",
        "same Stage",
        "Mark relevant to this correction",
        "no pre-confirmed Kit/Display links",
        "not a runnable/accepted browser result",
        "No fabricated candidate",
    ):
        assert required.casefold() in section.casefold(), required
    assert "**#419 Stage-first relevant resources (P0):**" in readme
    assert "read-only Stage resource aggregation and collapsed Related Information UI" in readme


def test_419_stage_source_reuses_existing_setup_relationships():
    """Source check only: Stage resource discovery reuses Setup ownership."""
    board = (ROOT / "Setup/Application/setup_scheduling_board_repository.py").read_text(
        encoding="utf-8"
    )
    kit = (ROOT / "Setup/Application/setup_kit_inventory_api.py").read_text(
        encoding="utf-8"
    )
    scope = (ROOT / "Setup/Application/setup_assignment_layer.py").read_text(
        encoding="utf-8"
    )
    feedback = (
        ROOT / "Setup/Database/062_add_setup_context_work_order_intake.sql"
    ).read_text(encoding="utf-8")
    for required in (
        "st.annual_stage_id AS stage_id",
        "ref.setup_task_container_support tc",
        "ref.setup_task_extra_material tm",
    ):
        assert required in board, required
    for required in (
        "c.container_type_id = 2",
        "ref.setup_container_extra_material",
        "tc.relationship_type = 'KIT'",
        "d.container_id = c.container_id",
    ):
        assert required in kit, required
    for required in ("ref.lor_scene_display", "ref.lor_scene", "LOR_STAGE_LEVEL"):
        assert required in scope, required
    for required in (
        "'stage_id', v_stage_id",
        "'lor_scene_id', v_scene_id",
        "'procedure_context', v_procedure",
    ):
        assert required in feedback, required


def test_419_first_app_source_is_read_only_and_related_information_optional():
    """First V0.1 source uses a collapsed disclosure; P0 actions not mocked as done."""
    app_dir = ROOT / "WorkOrders/Application"
    backend = (app_dir / "backend.py").read_text(encoding="utf-8")
    repo = (app_dir / "repository.py").read_text(encoding="utf-8")
    html = (app_dir / "index.html").read_text(encoding="utf-8")
    js = (app_dir / "app.js").read_text(encoding="utf-8")
    for required in (
        "WORK_MGMT_PREVIEW_MODE",
        "WORK_MGMT_DATABASE_DSN",
        "readonly=True",
        "current_database()",
        "stage.work_order_intake",
        "ref.setup_browser_capabilities",
        "ref.person",
        "ref.setup_task_container_support",
        "ref.lor_scene_display",
        "source_payload",
    ):
        assert required in backend + repo + html + js, required

    assert '<details id="related-information"' in html
    assert '<details id="related-information" open' not in html
    assert '"toggle", loadRelated' in js
    assert "Related Information" in html
    for required in (
        'scope=person',
        "My Work",
        "Show completed",
        "Request More Information",
        "Promote &amp; Assign",
    ):
        if required != "scope=person":
            assert required in html + js, required
    for forbidden in ("@app.post(", "@app.patch(", "@app.delete("):
        assert forbidden not in backend
