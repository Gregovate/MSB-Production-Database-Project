"""#171 recurring LinkIQ reconciliation; proposals never create physical cables.

Only maintained labels and accepted aliases resolve endpoints. Historical spelling
rewrites from the map prototype are deliberately not identity authority here.
"""
from __future__ import annotations

import re
from collections import defaultdict


def label_key(value):
    """Ignore case/whitespace only; do not invent punctuation or endpoint aliases."""
    return ' '.join((value or '').upper().split())


def waypoint_lookup(waypoints, aliases, gps_names=()):
    lookup = defaultdict(set)
    # Name on GPS is retained separately, never substituted for Name on Map.
    # Operator-approved panel shorthand yields candidates, not cable approval.
    for waypoint_id, label in [*waypoints, *aliases, *gps_names]:
        key = label_key(label)
        if not key:
            continue
        lookup[key].add(waypoint_id)
        if key.startswith('PANEL ') and key[6:]:
            lookup[key[6:]].add(waypoint_id)
        if key == 'PANEL 10 WV-00':
            lookup['WV-00'].add(waypoint_id)
    return lookup


def propose_test(test, lookup, cables, existing=None, previous_labels=()):
    """Produce a durable, reviewable proposal without changing accepted bindings.

    Cable candidates use unordered reviewed endpoints plus exact designation.
    Even a single candidate needs review: another parallel cable may exist.
    """
    appearances = test['source_appearances']
    first = appearances[0]
    reasons = []
    active = [a for a in appearances if str(a['deleted']).upper() != 'YES']
    preferred = active[0] if active else first
    label = preferred['display_cable_name'] or ''
    endpoint_ids = []
    endpoint_labels = []
    qualifier = None
    candidate_ids = []
    designation = None
    parsed = re.fullmatch(
        r'(.+?)\s+TO\s+(.+?)\s+(AUX[- ][A-Z0-9]+|INET|E1\.31|REG|SPARE(?:[- ]\d+)?|WIFI|LINE-?\d+)(?:\s+(.*))?',
        label.strip(), re.I)
    if not active:
        reasons.append('SOURCE_DELETED')
    if not parsed or re.search(r'\bTO\b', (parsed[1] + ' ' + parsed[2]) if parsed else '', re.I):
        reasons.append('NAME_REQUIRES_REVIEW')
    else:
        designation = label_key(parsed[3])
        endpoint_labels = [label_key(parsed[1]), label_key(parsed[2])]
        qualifier = label_key(parsed[4]) if parsed[4] else None
        for endpoint in (parsed[1], parsed[2]):
            ids = sorted(lookup.get(label_key(endpoint), set()))
            endpoint_ids.append(ids)
        if any(len(ids) != 1 for ids in endpoint_ids):
            reasons.append('ENDPOINT_UNRESOLVED_OR_AMBIGUOUS')
        else:
            a, b = (ids[0] for ids in endpoint_ids)
            if a == b:
                reasons.append('SAME_ENDPOINT_REQUIRES_REVIEW')
            else:
                candidate_ids = sorted(c['id'] for c in cables
                    if c['reviewed'] and {c['a'], c['b']} == {a, b}
                    and label_key(c['designation']) == designation)
                if len(candidate_ids) != 1:
                    reasons.append('NO_REVIEWED_CABLE' if not candidate_ids else 'PARALLEL_CABLES_REQUIRE_REVIEW')
    # Preserve all source variants and compare raw evidence, not just a few fields.
    if len({a['payload_sha256'] for a in appearances}) > 1:
        reasons.append('SOURCE_PAYLOAD_VARIANTS')
    semantic = ('test_status_code', 'test_standard', 'length_ft', 'record_time_span')
    if any(len({str(a.get(key)) for a in appearances}) > 1 for key in semantic):
        reasons.append('SOURCE_MEASUREMENT_VARIANTS')
    if existing:
        if any(a['payload_sha256'] != existing['evidence_sha256'] for a in appearances):
            reasons.append('EXISTING_TEST_PAYLOAD_CHANGED')
        for key in ('test_status_code', 'test_standard', 'length_ft'):
            old = existing.get(key)
            new = first.get(key)
            # Decimal values from PostgreSQL compare numerically with JSON numbers.
            if key == 'length_ft' and old is not None and new is not None:
                from decimal import Decimal
                same = Decimal(str(old)) == Decimal(str(new))
            else:
                same = old == new
            if not same:
                reasons.append('EXISTING_TEST_MEASUREMENT_CHANGED')
                break
    if previous_labels and label not in previous_labels:
        reasons.append('DISPLAY_LABEL_CHANGED')
    binding = existing.get('physical_site_cable_id') if existing else None
    reviewed = bool(existing and existing['identity_review_status'] == 'REVIEWED' and binding)
    if reviewed and (candidate_ids != [binding]):
        reasons.append('REVIEWED_BINDING_SOURCE_DISAGREEMENT')
    status = 'RETAINED_REVIEWED' if reviewed and not reasons else 'REVIEW_REQUIRED'
    return {'test_uuid': test['test_uuid'], 'status': status,
            'display_label': label, 'designation': designation,
            'endpoint_labels': endpoint_labels, 'qualifier': qualifier,
            'endpoint_candidates': endpoint_ids, 'cable_candidates': candidate_ids,
            'retained_cable_id': binding, 'reasons': sorted(set(reasons))}
