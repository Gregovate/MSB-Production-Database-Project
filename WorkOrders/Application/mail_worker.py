"""Bounded #419 notification worker. Default is no-send preview.

Deployment supplies the separate mail-role DSN. --send additionally requires
the explicit release environment flag; the database enforces Flow cutover.
This module never enables capture, modifies Flows or retries retained claims.
"""
import argparse
import json
import os

import psycopg2
from psycopg2.extras import RealDictCursor

from email_templates import render_email
from mail_delivery import Delivery, dispatch, message_for
from mail_store import PostgresDeliveryStore


def run_batch(dsn: str, *, send: bool = False) -> list[dict]:
    if send and os.environ.get('WORK_MGMT_MAIL_SEND_ENABLED') != '1':
        raise RuntimeError('Work Order mail activation is OFF')
    conn = psycopg2.connect(dsn)
    try:
        conn.set_session(readonly=True)
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute('SELECT session_user AS role, current_database() AS db')
            identity = cur.fetchone()
            if identity != {'role': 'work_management_mail', 'db': 'msb'}:
                raise RuntimeError('Dedicated Production mail identity required')
            cur.execute('SELECT * FROM ops.work_management_mail_candidates()')
            candidates = list(cur.fetchall())
    finally:
        conn.close()
    # Validate/render the entire bounded batch before the first SMTP attempt.
    store = PostgresDeliveryStore(dsn)
    deliveries = []
    for row in candidates:
        try:
            delivery = Delivery(row['event_key'], row['recipient_email'],
                                render_email(row['message_kind'], row['payload']))
            message_for(delivery)  # Validate every envelope before the first send.
            deliveries.append(delivery)
        except (ValueError, TypeError, KeyError, OSError):
            if send:
                store.render_failure(row['event_key'])
            raise
    outcomes = []
    for delivery in deliveries:
        status = dispatch(delivery, store, enabled=send)
        outcomes.append(dict(key=delivery.key, status=status,
            subject=delivery.content.subject,
            template_sha256=delivery.content.template_sha256))
        if status in {'UNKNOWN', 'FAILED_BEFORE_DATA', 'REJECTED'}:
            break  # Preserve the evidence and stop this run; no blind retries.
    return outcomes


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--send', action='store_true')
    args = parser.parse_args()
    dsn = os.environ.get('WORK_MGMT_MAIL_DSN', '')
    if not dsn:
        raise SystemExit('Dedicated mail DSN missing')
    print(json.dumps(run_batch(dsn, send=args.send), indent=2))
