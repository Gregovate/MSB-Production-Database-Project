"""Task-scoped QC read and command adapter.

#122: PostgreSQL SECURITY DEFINER functions enforce identity and exact task
scope. No direct application SELECT/INSERT/UPDATE grants on QC/Intake tables.
"""
from __future__ import annotations

import psycopg2


class SetupQcRepository:
    def __init__(self, dsn: str):
        self.dsn = dsn

    def snapshot(self, email: str, season_year: int) -> dict:
        with psycopg2.connect(self.dsn) as conn:
            with conn.cursor() as cur:
                cur.execute(
                    "SELECT ops.setup_qc_snapshot(%s,%s)",
                    (email,season_year),
                )
                return cur.fetchone()[0]

    def intake_candidates(self, email: str, season_year: int) -> list[dict]:
        with psycopg2.connect(self.dsn) as conn:
            with conn.cursor() as cur:
                cur.execute(
                    "SELECT ops.setup_qc_intake_candidates(%s,%s)",
                    (email,season_year),
                )
                return cur.fetchone()[0]

    def signoff(self, email: str, payload: dict) -> dict:
        """Finalize only through the database-owned gate; no synthetic progress."""
        with psycopg2.connect(self.dsn) as conn:
            conn.set_session(readonly=False, autocommit=False)
            with conn.cursor() as cur:
                cur.execute("SELECT ops.setup_qc_ready_for_production(%s,%s,%s,%s,%s)", (
                    email, payload['setup_session_task_id'], payload['note'],
                    payload['test_seconds'], payload['sequence_reference']))
                result = cur.fetchone()[0]
            conn.commit()
        return result

    def command(self, email: str, payload: dict) -> dict:
        with psycopg2.connect(self.dsn) as conn:
            # Installed fieldwiring_app defaults to read-only; explicitly opt
            # in only for the narrow audited SECURITY DEFINER QC command.
            conn.set_session(readonly=False, autocommit=False)
            with conn.cursor() as cur:
                cur.execute("""
                   SELECT ops.setup_qc_command(
                     %s,%s,%s,%s,%s,%s,%s,%s,%s
                   )
                """, (
                    email, payload['action'], payload['setup_session_task_id'],
                    payload.get('qc_finding_id'), payload.get('note'),
                    payload.get('title'), payload.get('discovery_phase'),
                    payload.get('location_detail'), payload.get('intake_id'),
                ))
                result=cur.fetchone()[0]
            conn.commit()
        return result

    def edit_finding(self, email: str, payload: dict) -> dict:
        """One audited correction; preserve original reports and exact identity."""
        with psycopg2.connect(self.dsn) as conn:
            conn.set_session(readonly=False, autocommit=False)
            with conn.cursor() as cur:
                cur.execute("SELECT ops.setup_qc_edit_finding(%s,%s,%s,%s,%s,%s)", (
                    email, payload['qc_finding_id'], payload['setup_session_task_id'],
                    payload['target_task_id'], payload['note'], payload['expected_updated_at']))
                result = cur.fetchone()[0]
            conn.commit()
        return result

    def accept_exception(self, email: str, payload: dict) -> dict:
        with psycopg2.connect(self.dsn) as conn:
            conn.set_session(readonly=False, autocommit=False)
            with conn.cursor() as cur:
                cur.execute("SELECT ops.setup_qc_accept_for_season(%s,%s,%s,%s,%s,%s,%s)", (
                    email,payload['qc_finding_id'],payload['setup_session_task_id'],payload['note'],
                    payload['due_by'],payload['task_type_id'],payload['expected_updated_at']))
                result=cur.fetchone()[0]
            conn.commit()
        return result
