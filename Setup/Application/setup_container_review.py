"""#88 exception projection and persistence; no physical work inferred on GET."""
from __future__ import annotations

import json
from datetime import datetime, timezone

from psycopg2.extras import RealDictCursor, Json

from setup_movement_repository import SetupMovementRepository
from setup_production_report import movement_picture, report_context, chicago_time


def captured_scope(notes):
    """Read the saved snapshot, never substitute today's Container membership."""
    try:
        text = notes.split('contents_reconciliation=', 1)[1]
        data, _ = json.JSONDecoder().raw_decode(text)
        context = data.get('review_context') or {}
        if context.get('context_available') is not True:
            return None
        scope = context.get('expected_displays')
        return scope if isinstance(scope,list) and all(isinstance(d,dict) and d.get('display_id') for d in scope) else None
    except (ValueError, IndexError, TypeError, AttributeError):
        return None


def exception_context(picture, reviews, snapshots, container_id=None):
    context = report_context({}, picture, 0)
    cases = []
    for c in context['containers']:
        cid = c['container_id']
        history = [r for r in reviews if r['container_id'] == cid]
        resolved = {flag for r in history for flag in r['resolved_flag_ids']}
        flags = [{**f, 'captured_displays': captured_scope(f.get('notes') or '')}
                 for f in c['review_flags'] if f['setup_movement_event_id'] not in resolved]
        protected = c.get('container_type_name') == 'Standalone Display' or (
            c.get('container_type_name') in {'Display Pallet', 'Display-Pallet'} and len(c['attached']+c['detached']) == 1)
        reasons = []
        returned = c.get('movement_status') == 'RETURNED' or c['latest'].get('event_type') == 'RETURNED'
        if returned and c['attached']:
            reasons.append(dict(code='RETURNED_ATTACHED', label='Returned Home with recorded Displays attached',
                                next_action='Confirm empty return; leave remaining Displays at the prior park location.'))
        if protected and c['detached']:
            reasons.append(dict(code='PROTECTED_DETACHED', label='Standalone / single-Display Pallet recorded detached',
                                next_action='Verify and restore the assigned attachment.'))
        unresolved = [d for d in c['detached'] if 'unresolved' in (d.get('current_location_note') or '').lower()]
        if unresolved:
            reasons.append(dict(code='UNRESOLVED_LOCATION', label='Display unload location unresolved',
                                next_action='Confirm the selected Display location from a crew report or existing evidence.'))
        if flags:
            reasons.append(dict(code='CONTENTS_REVIEW', label=f'{len(flags)} open contents review(s)',
                                next_action='Review captured Display Names; confirm, correct, or request a field check.'))
        pending_checks = []
        for index, review in enumerate(history):
            if review['action'] != 'NEEDS_FIELD_CHECK':
                continue
            scope = set(review.get('display_ids') or [d['display_id'] for d in review.get('snapshot',{}).get('displays',[])])
            later = [r for r in history[index+1:] if r['action'] != 'NEEDS_FIELD_CHECK']
            accounted = {d for r in later for d in r.get('display_ids',[])}
            # A later movement alone is not an explicit review outcome.
            if (scope and not scope <= accounted) or (not scope and not any(
                    r.get('request',{}).get('whole_case_confirmed') for r in later)):
                pending_checks.append(review)
        if pending_checks:
            reasons.append(dict(code='FIELD_CHECK', label='Field verification still outstanding',
                                next_action='Record the requested verification; partial work leaves the rest open.'))
        if not reasons and not history and cid != container_id:
            continue
        # Find the same trip anchor used by the command, never a nearest estimate.
        prior = None
        if returned:
            for e in c['history']:
                if (e['occurred_at'],e['setup_movement_event_id']) >= (c['latest']['occurred_at'],c['latest']['setup_movement_event_id']):
                    break
                if e['event_type'] == 'RETURNED':
                    prior = None
                elif e['event_type'] not in {'PICKED','LOADED','IN_TRANSIT'} and (
                    e.get('gps_latitude') is not None or e.get('destination_stage_id') or e.get('destination_location_note')):
                    prior = e
        last_review = history[-1] if history else None
        oldest = min((f['received_at'] for f in flags), default=c['latest'].get('received_at'))
        age = max(0, (picture['generated_at']-oldest).days) if oldest else 0
        cases.append({**{k:v for k,v in c.items() if k not in {'history','review_flags'}},
                      'reasons':reasons, 'open_flags':flags,
                      'reviews':[{k:v for k,v in r.items() if k not in {'snapshot','request'}} for r in history],
                      'snapshot':snapshots.get(cid), 'protected':protected, 'prior_park':prior,
                      'status':('NEEDS_FIELD_CHECK' if pending_checks
                                else 'OPEN') if reasons else ('RESOLVED' if history else 'NOT_FLAGGED'),
                      'age_days':age, 'last_activity':chicago_time(last_review['recorded_at'] if last_review else c['latest'].get('received_at'))})
    cases.sort(key=lambda c:(c['status']=='RESOLVED', not any(r['code'] in {'RETURNED_ATTACHED','PROTECTED_DETACHED'} for r in c['reasons']),-c['age_days'],c['container_id']))
    return dict(cases=cases, through_event_id=picture['through_event_id'], generated=context['generated'],
                counts=dict(open=sum(c['status'] in {'OPEN','NEEDS_FIELD_CHECK'} for c in cases),
                            field_check=sum(c['status']=='NEEDS_FIELD_CHECK' for c in cases),
                            resolved=sum(c['status']=='RESOLVED' for c in cases)))


class SetupContainerReviewRepository(SetupMovementRepository):
    def exceptions(self, session_id, container_id=None):
        # Evidence, review lifecycle and write preconditions share one snapshot.
        with self.connect() as conn:
            picture = movement_picture(self, session_id, connection=conn, include_unobserved=True)
            with conn.cursor(cursor_factory=RealDictCursor) as cur:
                cur.execute('SELECT * FROM ops.setup_container_review_event WHERE setup_session_id=%s ORDER BY setup_container_review_event_id', (session_id,))
                reviews = [dict(r) for r in cur.fetchall()]
                context = exception_context(picture, reviews, {}, container_id)
                # Only actionable/reviewed Containers need write preconditions;
                # avoid rebuilding snapshots for every healthy reference asset.
                cur.execute('SELECT c.container_id, ops.setup_container_review_snapshot(%s,c.container_id) AS snapshot FROM ref.container c WHERE c.container_id=ANY(%s)',
                            (session_id,[c['container_id'] for c in context['cases']]))
                snapshots = {r['container_id']:r['snapshot'] for r in cur.fetchall()}
        for case in context['cases']:
            case['snapshot'] = snapshots.get(case['container_id'])
        return context

    def record_review(self, *, email, season_year, container_id, client_event_id, snapshot, command):
        with self.write_connect() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute('SELECT * FROM ops.review_setup_container_contents(%s,%s,%s,%s::uuid,%s::jsonb,%s::jsonb)',
                        (email,season_year,container_id,str(client_event_id),Json(snapshot),Json(command)))
            result = self._one(cur, 'Contents review returned no result')
            conn.commit()
            return result
