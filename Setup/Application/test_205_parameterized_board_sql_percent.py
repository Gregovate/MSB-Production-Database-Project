"""Regression for #205 browser HTTP 500: psycopg2 SQL percent parsing.

The #205 annual-task completion-date query introduced a SQL comment containing
``100%``, which psycopg2 treats as parameter formatting while binding
``(setup_session_id,)``. The error is raised in cursor.execute BEFORE SQL
reaches PostgreSQL. This test checks the actual bound query source, not only a
copied excerpt. It requires no Production/clone database connection.
"""
from __future__ import annotations

import ast
from pathlib import Path


REPOSITORY_SOURCE = Path(__file__).with_name("setup_scheduling_board_repository.py")


def _annual_task_query() -> tuple[str, ast.AST]:
    tree = ast.parse(REPOSITORY_SOURCE.read_text(encoding="utf-8"))
    matches = []
    for node in ast.walk(tree):
        if not isinstance(node, ast.Call):
            continue
        if not isinstance(node.func, ast.Attribute) or node.func.attr != "execute":
            continue
        if len(node.args) < 2:
            continue
        arg = node.args[0]
        if not isinstance(arg, ast.Constant) or not isinstance(arg.value, str):
            continue
        if "AS completion_work_date" in arg.value:
            matches.append((arg.value, node.args[1]))
    assert len(matches) == 1, "Exactly one annual-task completion query must be present"
    return matches[0]


def _parse_psycopg_placeholders(query: str) -> int:
    count = 0
    i = 0
    while i < len(query):
        if query[i] != "%":
            i += 1
            continue
        if query.startswith("%%", i):
            i += 2
            continue
        if query.startswith("%s", i):
            count += 1
            i += 2
            continue
        raise AssertionError(
            "Unescaped percent sign in psycopg2-bound SQL at "
            f"offset {i}, around {query[max(0, i - 50):i + 80]!r}. "
            "Even SQL comments are interpolated by psycopg2 before execution."
        )
    return count


def test_annual_board_query_has_only_real_psycopg_placeholders() -> None:
    sql, bound_args = _annual_task_query()
    assert "max(p.performed_on) FILTER" in sql
    assert "p.percent_complete = 100" in sql
    assert "AS completion_work_date" in sql
    assert isinstance(bound_args, ast.Tuple), "Bind arguments must be a tuple"
    assert len(bound_args.elts) == 1, "Board annual query binds only Setup session ID"
    assert _parse_psycopg_placeholders(sql) == len(bound_args.elts)


def test_bad_percent_in_query_comment_would_fail_before_postgres() -> None:
    sql, _ = _annual_task_query()
    try:
        _parse_psycopg_placeholders(sql.replace(
            "Current full-completion work evidence",
            "Current 100% work evidence"
        ))
    except AssertionError as exc:
        assert "Unescaped percent sign" in str(exc)
    else:
        raise AssertionError("Regression check failed to detect the original 100% comment")
