"""#81: read-only accepted source contract, independent of programmer-PC sync.

Authority comes exclusively from frozen reconciliation evidence. Never inspect
current preview files here or fall back to an earlier run with better metadata.
"""
from __future__ import annotations

import hashlib
import json
import re
from pathlib import PureWindowsPath


class SourceUnavailable(ValueError):
    pass


def accepted_document(run, previews):
    """Validate one latest completed row; missing evidence blocks publication."""
    if not run or run.get('status') != 'COMPLETED':
        raise SourceUnavailable('No completed accepted LOR2DB source is available')
    if (run.get('validation_state') != 'PASSED'
            or run.get('parser_validation_status') != 'PASSED'
            or run.get('cancelled_at') is not None
            or any(run.get(k) != 0 for k in ('blocked_count', 'deferred_count', 'unresolved_count'))):
        raise SourceUnavailable('Latest completed source lacks clean validation')
    for key in ('source_manifest_sha256', 'source_sqlite_sha256', 'report_sha256'):
        if not re.fullmatch('[0-9a-f]{64}', str(run.get(key) or '')):
            raise SourceUnavailable(f'Latest completed source lacks {key}')
    for key in ('completed_at', 'report_published_at', 'report_url', 'source_lor_version', 'source_preview_folder'):
        if not run.get(key):
            raise SourceUnavailable(f'Latest completed source lacks {key}')
    folder = PureWindowsPath(run['source_preview_folder'])
    if not folder.is_absolute() or folder.name != 'Database Previews V' + run['source_lor_version']:
        raise SourceUnavailable('Accepted source is not the exact versioned preview folder')
    if not previews or len(previews) != run.get('preview_count'):
        raise SourceUnavailable('Frozen preview inventory is incomplete')
    names, ids, items = set(), set(), []
    for p in previews:
        filename, identity = str(p.get('source_filename') or ''), str(p.get('preview_id') or '').lower()
        if (PureWindowsPath(filename).name != filename or '/' in filename
                or not filename.lower().endswith('.lorprev') or not identity
                or filename.casefold() in names or identity in ids or not p.get('preview_name')):
            raise SourceUnavailable('Frozen preview inventory has invalid or duplicate identities')
        if p.get('preview_revision') is None:
            raise SourceUnavailable('Frozen preview revision evidence is missing')
        names.add(filename.casefold())
        ids.add(identity)
        items.append(dict(filename=filename, preview_id=identity, name=p['preview_name'], revision=str(int(p['preview_revision']))))
    document = dict(schema_version=1, run_id=run['lor_reconciliation_run_id'],
                    import_run_id=run['import_run_id'], status='COMPLETED', validation='PASSED',
                    lor_version=run['source_lor_version'], source_folder=str(folder),
                    preview_count=len(items), source_manifest_sha256=run['source_manifest_sha256'],
                    source_sqlite_sha256=run['source_sqlite_sha256'], report_url=run['report_url'],
                    report_sha256=run['report_sha256'], previews=sorted(items, key=lambda p: p['filename'].casefold()))
    document['evidence_id'] = hashlib.sha256(json.dumps(document, ensure_ascii=False, sort_keys=True, separators=(',', ':')).encode()).hexdigest()
    return document


def load_current_source(conn, cursor_factory):
    # One SQL statement sees one PostgreSQL snapshot, including the inventory.
    # Select the latest COMPLETED run FIRST; incomplete evidence must never
    # silently select an older source. REPORTING/CANCELLED are not accepted.
    with conn.cursor(cursor_factory=cursor_factory) as cur:
        cur.execute('''
            SELECT r.*, sr.source_preview_folder, sr.source_lor_version,
                   sr.source_manifest_sha256, sr.source_sqlite_sha256,
                   sr.parser_validation_status, sr.preview_count,
                   (SELECT json_agg(p) FROM ops.lor_reconciliation_source_preview p
                    WHERE p.lor_reconciliation_run_id = r.lor_reconciliation_run_id) AS previews
            FROM (SELECT * FROM ops.lor_reconciliation_run
                  WHERE status = 'COMPLETED'
                  ORDER BY completed_at DESC, lor_reconciliation_run_id DESC LIMIT 1) r
            LEFT JOIN ops.lor_reconciliation_source_run sr
              ON sr.lor_reconciliation_run_id = r.lor_reconciliation_run_id
        ''')
        row = cur.fetchone()
    return accepted_document(row, row.get('previews') or []) if row else accepted_document(None, [])
