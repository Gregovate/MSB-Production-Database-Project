"""Crew circuit capture on the existing FieldWiring host and DB command boundary."""
from __future__ import annotations

import json
from contextlib import closing

import psycopg2
from flask import Blueprint, jsonify, request

from controller_access import cloudflare_operator_email
from repository import ConfigError, PostgresRepository

power_api = Blueprint('power_api', __name__)


def _repo():
    # Lazy import avoids a second Flask host and preserves existing test injection.
    from backend import repository
    repo = repository()
    if not isinstance(repo, PostgresRepository):
        raise ConfigError('Circuit capture requires PostgreSQL')
    return repo


@power_api.after_request
def private_response(response):
    response.headers['Cache-Control'] = 'no-store'
    response.headers['Vary'] = 'Cf-Access-Authenticated-User-Email'
    return response


@power_api.get('/api/power')
def snapshot():
    email = cloudflare_operator_email(request.headers)
    with closing(psycopg2.connect(_repo().dsn)) as connection:
        connection.set_session(readonly=True)
        with connection.cursor() as cursor:
            cursor.execute('SELECT ref.site_power_snapshot(%s)', (email,))
            return jsonify(cursor.fetchone()[0])


@power_api.post('/api/power/commands')
def commands():
    """Save one edit or a multi-waypoint assignment in a single transaction.

    Each request ID is stable on retry. PostgreSQL checks replay content, Directus
    authority, revision, typed fields and audit attribution independently.
    """
    email = cloudflare_operator_email(request.headers)
    if not request.is_json or request.headers.get('X-MSB-Power-Command') != '1':
        return jsonify(error='Circuit command request guard is missing'), 403
    body = request.get_json(silent=True)
    if not isinstance(body, dict) or set(body) != {'revision', 'commands'}:
        return jsonify(error='Revision and commands are required'), 400
    revision, batch = body['revision'], body['commands']
    if type(revision) is not int or revision < 0 or not isinstance(batch, list) or not 1 <= len(batch) <= 100:
        return jsonify(error='Invalid revision or command count'), 400
    for entry in batch:
        if not isinstance(entry, dict) or set(entry) != {'request_id', 'kind', 'id', 'fields'} \
                or not isinstance(entry['fields'], dict) or not isinstance(entry['request_id'], str) \
                or not isinstance(entry['kind'], str) \
                or (entry['id'] is not None and (type(entry['id']) is not int or entry['id'] <= 0)):
            return jsonify(error='Invalid circuit command'), 400
    with closing(psycopg2.connect(_repo().dsn)) as connection:
        connection.set_session(readonly=False, autocommit=False)
        try:
            results = []
            with connection.cursor() as cursor:
                for entry in batch:
                    cursor.execute('SELECT ref.site_power_command(%s,%s::uuid,%s,%s,%s,%s::jsonb)',
                                   (email, entry['request_id'], revision, entry['kind'], entry['id'], json.dumps(entry['fields'])))
                    result = cursor.fetchone()[0]
                    revision = result['revision']
                    results.append(result)
            connection.commit()
        except Exception:
            connection.rollback()
            raise
    return jsonify(revision=revision, results=results)


@power_api.errorhandler(psycopg2.Error)
def database_error(exc):
    code = exc.pgcode or ''
    status = (403 if code == '42501' else 409 if code in {'40001','23505'} else
              404 if code == 'P0002' else 400 if code.startswith('22') or code.startswith('23') else 503)
    # Installation failures must be visible, without leaking internal SQL or DSNs.
    message = ('Panel circuit capture is unavailable. Its database release may not be installed.' if status == 503
               else getattr(exc.diag, 'message_primary', None) or 'Circuit command was rejected')
    return jsonify(error=message), status
