"""#419 Manager Intake approval source and wiring exception contracts.

The same-Stage comparison is required for public Intake before promotion.
Wiring/verify is optional and only for relevant Setup defects. A link or
fault attribution is not inferred from Stage name alone.
"""
from pathlib import Path
ROOT = Path(__file__).resolve().parent
html = (ROOT/"index.html").read_text(encoding="utf-8")
js = (ROOT/"review_actions.js").read_text(encoding="utf-8")
repo = (ROOT/"repository.py").read_text(encoding="utf-8")
api = (ROOT/"backend.py").read_text(encoding="utf-8")
wiring = (ROOT/"setup_accountability.py").read_text(encoding="utf-8")


def test_promotion_comparison_is_in_original_intake_approval():
    assert 'id="review-intake-approval-links"' in html
    assert "Manager approval · Compare other repair requests" in html
    assert "review-intake-related-requests" in html
    assert "/intake-approval-review" in js
    assert "if (kind === \"promote\") {" in js
    assert "approvalLoadedFor !== model.ticket?.ticket" in js
    assert "review-intake-checked" in js
    assert "wiring_accountability" in api
    assert "intake_approval_review" in api
    assert 'actor.get("can_manage")' in repo.split("def intake_approval_review(",1)[1].split(
        "def related_information(",1)[0]


def test_setup_task_is_optional_for_operational_work_orders():
    assert 'value="not_applicable"' in html
    assert 'value="review"' in html
    assert "No — normal repair, operations or other Work Order" in html
    assert "review-intake-wiring-review" in html
    assert 'byId("review-intake-setup-association").value === "review"' in js
    assert "Only an existing PLUG IN &amp; VERIFY wiring step is eligible" in html
    assert "annual_task_name ~*" in wiring
    assert "CANDIDATE_NOT_LINKED" in wiring


def test_related_reports_not_mislabeled_as_duplicates():
    assert "SAME_STAGE_REVIEW" in wiring
    assert "not proven duplicates" in wiring.lower()
    assert "stage.work_order_intake" in wiring
    assert "ops.work_order" in wiring
    assert "Mark duplicate of an existing Work Order" in html
    assert "promotion_approved" in repo
    assert "promotion_approved\":False" in repo or '"promotion_approved":False' in repo
    assert "INSERT INTO" not in wiring
