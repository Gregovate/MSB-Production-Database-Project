"""PR evidence gate for existing MSB engineering authority (no server access).

This cannot establish design quality, the chronological order of decisions,
browser acceptance or production authorization. Those require human review.
"""
from __future__ import annotations
import os
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
RULES = [
    "System_Documentation/Project_Rules/Repository_Change_Workflow.md",
    "System_Documentation/Project_Rules/Runbook_First_Production_Rule.md",
    "System_Documentation/Standards/Documentation_Maintenance_Rule.md",
    "System_Documentation/Standards/README_Portal_Standard.md",
]
FIELDS = ("Design authority:", "Implementation scope:", "Regression evidence:",
          "Acceptance status:", "Runbook / existing mechanism:")


def validate(changed: list[str], body: str, existing: set[str]) -> list[str]:
    errors: list[str] = []
    for authority in RULES:
        if authority not in existing:
            errors.append(f"Missing governing standard: {authority}")
    if not changed:
        return errors + ["No changed paths found for compliance review."]
    protected = any(p.startswith((
        "Setup/Acceptance/", "WorkOrders/Acceptance/", ".github/workflows/",
        "System_Documentation/Project_Rules/", "System_Documentation/Standards/"
    )) for p in changed)
    implementation = any(p.startswith((
        "Setup/Application/", "Setup/Database/", "WorkOrders/Application/",
        "WorkOrders/Database/", "FieldWiring/Application/", "Database/"
    )) for p in changed)
    if implementation or protected:
        for field in FIELDS:
            match = re.search(r"(?im)^\s*" + re.escape(field) + r"\s*(.+)$", body)
            if not match or len(match.group(1).strip()) < 8:
                errors.append(f"PR description must give nonempty '{field}' evidence.")
        reference = re.search(r"(?im)^\s*Design authority:\s*(.+)$", body)
        if reference:
            # Prevent a chat URL, issue or PR alone being asserted as design authority.
            value = reference.group(1).strip().lower()
            if value.startswith(("chat", "issue #", "pr #", "conversation")):
                errors.append("Design authority must identify a controlled design document.")
    if protected:
        justification = re.search(r"(?im)^\s*Infrastructure reuse / exception:\s*(.+)$", body)
        if not justification or len(justification.group(1).strip()) < 12:
            errors.append("Protected tooling change requires 'Infrastructure reuse / exception:' rationale.")
    if implementation:
        # Reviewers can follow the owning design, not just a PR description.
        doc_changes = any(p.startswith(("Docs/", "System_Documentation/", "WorkOrders/Acceptance/"))
                          and p.endswith(".md") for p in changed)
        if not doc_changes:
            errors.append("Implementation change lacks a controlled documentation change; document the owning design or explicitly separate the approved documentation PR before proceeding.")
    return errors


def main() -> int:
    if os.getenv("EVENT_NAME") == "workflow_dispatch":
        print("Manual run: checker unit tests run; PR-specific evidence requires pull_request.")
        return 0
    base = os.environ.get("PR_BASE_SHA", "")
    if not re.fullmatch(r"[0-9a-f]{40}", base):
        print("HOLD: required PR base SHA missing.")
        return 1
    changed = subprocess.check_output(
        ["git", "diff", "--name-only", base, "HEAD"], cwd=ROOT, text=True
    ).splitlines()
    existing = {str(p.relative_to(ROOT)) for p in ROOT.rglob("*") if p.is_file()}
    errors = validate(changed, os.environ.get("PR_BODY", ""), existing)
    for error in errors:
        print("FAIL:", error)
    if errors:
        return 1
    print(f"PASS: reviewed {len(changed)} paths against existing authority/evidence contracts")
    print("NOTE: This does NOT prove design correctness, approved exceptions, browser acceptance or Production readiness.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
