"""Manager-only #88 exception queue and audited review commands."""
from flask import Blueprint, jsonify, request
import psycopg2

from setup_api import require_manager, require_setup_command, json_body, setup_database_dsn
from setup_movement_api import (positive_int, required_uuid, required_timestamp, optional_positive_int_list,
                                movement_authentication_error, movement_command_error, movement_database_error)
from setup_api import SetupAuthenticationError, SetupCommandError
from setup_container_review import SetupContainerReviewRepository

setup_container_review_api = Blueprint('setup_container_review_api', __name__)


def repo():
    return SetupContainerReviewRepository(setup_database_dsn())


@setup_container_review_api.get('/api/setup/container-exceptions')
def exceptions():
    base, _email, _access = require_manager()
    year = positive_int(request.args.get('season_year'), 'season_year')
    session = base.movement_summary(year)
    if not session.get('setup_session_id'):
        return jsonify(error='No Setup Session exists for this year'), 404
    raw_container = request.args.get('container_id')
    container = positive_int(raw_container,'container_id') if raw_container else None
    result = repo().exceptions(session['setup_session_id'], container_id=container)
    if container and not any(c['container_id']==container for c in result['cases']):
        return jsonify(error='Container not found'),404
    response = jsonify(result)
    response.headers['Cache-Control'] = 'no-store, max-age=0'
    return response


@setup_container_review_api.post('/api/setup/container-exceptions/<int:container_id>/review')
def review(container_id):
    require_setup_command()
    _base, email, _access = require_manager()
    payload = json_body()
    year = positive_int(payload.get('season_year'), 'season_year')
    event = required_uuid(payload.get('client_event_id'), 'client_event_id')
    command = payload.get('command')
    if not isinstance(payload.get('snapshot'),dict) or not isinstance(command,dict):
        return jsonify(error='Refresh the case and supply a reviewed command'), 400
    if command.get('action') not in {'NEEDS_FIELD_CHECK','CONFIRM','LOCATION','PRIOR_PARK','ATTACH'}:
        return jsonify(error='Choose a review action'), 400
    required_timestamp(command.get('observed_at'), 'observed_at')
    for key in ('display_ids','flag_ids','resolve_flag_ids'):
        if not isinstance(command.get(key),list):
            return jsonify(error=f'{key} must be a list'), 400
        command[key] = optional_positive_int_list(command[key],key)
    if not isinstance(command.get('evidence'),str) or not 5<=len(command['evidence'].strip())<=4000:
        return jsonify(error='Provide evidence/source and the reason (5–4000 characters)'), 400
    if not isinstance(command.get('whole_case_confirmed',False),bool):
        return jsonify(error='Whole-case confirmation must be true or false'), 400
    result = repo().record_review(email=email,season_year=year,container_id=container_id,
                                  client_event_id=event,snapshot=payload['snapshot'],command=command)
    return jsonify(review=result)


setup_container_review_api.register_error_handler(SetupAuthenticationError,movement_authentication_error)
setup_container_review_api.register_error_handler(SetupCommandError,movement_command_error)

@setup_container_review_api.errorhandler(psycopg2.Error)
def database_error(exc):
    if exc.pgcode in {'40001','23505'}:
        return jsonify(error=exc.diag.message_primary or 'Evidence changed; refresh and review again'), 409
    return movement_database_error(exc)
