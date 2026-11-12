"""Durable PostgreSQL delivery claims through restricted worker functions."""
from dataclasses import asdict

import psycopg2
from psycopg2.extras import Json

from mail_delivery import Delivery


class PostgresDeliveryStore:
    """Each call commits before returning; SMTP must be outside transactions.

    Connection failure after commit is intentionally conservative: a retained
    claim blocks duplicate sends until an operator reconciles the outcome.
    """
    def __init__(self, dsn: str):
        self.dsn = dsn

    def _call(self, statement, args):
        conn = psycopg2.connect(self.dsn)
        try:
            with conn:
                with conn.cursor() as cur:
                    cur.execute(statement, args)
                    result = cur.fetchone()[0]
            return result
        finally:
            conn.close()

    def claim(self, delivery: Delivery) -> bool:
        return bool(self._call(
            'SELECT ops.work_management_mail_claim(%s,%s,%s,%s)',
            (delivery.key, delivery.event_key, delivery.recipient,
             Json(asdict(delivery.content)))))

    def render_failure(self, event_key: str) -> None:
        """Persist only a fixed diagnostic, never raw ticket content or exceptions."""
        self._call('SELECT ops.work_management_mail_render_failure(%s)', (event_key,))

    def finish(self, key: str, status: str, evidence: str) -> None:
        self._call('SELECT ops.work_management_mail_finish(%s,%s,%s)',
                   (key, status, evidence))
