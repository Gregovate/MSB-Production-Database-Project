"""Disposable #81 contract checks; no database or production connection."""
import os
import unittest
from unittest.mock import MagicMock, patch
import current_source as source


def fixture():
    return dict(status='COMPLETED', validation_state='PASSED', parser_validation_status='PASSED',
                cancelled_at=None, blocked_count=0, deferred_count=0, unresolved_count=0,
                source_manifest_sha256='a'*64, source_sqlite_sha256='b'*64, report_sha256='c'*64,
                completed_at='2026-10-27', report_published_at='2026-10-27',
                report_url='https://example.org/report.html', source_lor_version='6.6.12',
                source_preview_folder=r'G:\Shared drives\MSB Database\Database Previews V6.6.12',
                preview_count=1, lor_reconciliation_run_id=32, import_run_id=74)


def previews():
    return [dict(source_filename='Rotary-Trees.lorprev', preview_id='stable-id', preview_name='Rotary-Trees', preview_revision=57)]


class CurrentSourceTests(unittest.TestCase):
    def test_later_completed_source_supersedes_old_digest(self):
        old = fixture(); old.update(lor_reconciliation_run_id=29, source_manifest_sha256='d'*64)
        new = source.accepted_document(fixture(), previews())
        self.assertNotEqual(new['evidence_id'], source.accepted_document(old, previews())['evidence_id'])
        self.assertEqual(new['source_manifest_sha256'], 'a'*64)
        self.assertEqual(new['previews'][0]['preview_id'], 'stable-id')

    def test_every_unaccepted_lifecycle_blocks(self):
        for status in ('REPORTING', 'CANCELLED', 'COMPLETED_WITH_EXCEPTIONS', 'READY_TO_FINISH'):
            with self.subTest(status=status), self.assertRaises(source.SourceUnavailable):
                source.accepted_document(dict(fixture(), status=status), previews())

    def test_missing_frozen_evidence_blocks_without_old_run_fallback(self):
        for key in ('source_manifest_sha256', 'source_sqlite_sha256', 'report_sha256', 'report_url',
                    'report_published_at', 'source_lor_version', 'source_preview_folder'):
            with self.subTest(key=key), self.assertRaises(source.SourceUnavailable):
                source.accepted_document(dict(fixture(), **{key: None}), previews())

    def test_validation_and_exceptions_block(self):
        for key, value in [('validation_state', 'FAILED'), ('parser_validation_status', 'FAILED'),
                           ('blocked_count', 1), ('deferred_count', 1), ('unresolved_count', 1), ('cancelled_at', 'yesterday')]:
            with self.subTest(key=key), self.assertRaises(source.SourceUnavailable):
                source.accepted_document(dict(fixture(), **{key: value}), previews())

    def test_missing_inventory_and_duplicate_ids_block(self):
        for items in ([], previews()*2, [dict(previews()[0], source_filename='../bad.lorprev')]):
            with self.subTest(items=items), self.assertRaises(source.SourceUnavailable):
                source.accepted_document(dict(fixture(), preview_count=len(items)), items)

    def test_version_folder_mismatch_blocks(self):
        with self.assertRaises(source.SourceUnavailable):
            source.accepted_document(dict(fixture(), source_lor_version='7.0.0'), previews())

    def test_revision_is_evidence_not_winner_selection(self):
        low = source.accepted_document(fixture(), [dict(previews()[0], preview_revision=1)])
        self.assertEqual(low['run_id'], 32)
        self.assertEqual(low['previews'][0]['revision'], '1')

    def test_single_snapshot_query_selects_latest_before_metadata_validation(self):
        conn = MagicMock(); cur = conn.cursor.return_value.__enter__.return_value
        cur.fetchone.return_value = dict(fixture(), previews=previews())
        result = source.load_current_source(conn, None)
        self.assertEqual(result['run_id'], 32)
        sql = cur.execute.call_args.args[0]
        self.assertIn("WHERE status = 'COMPLETED'", sql)
        self.assertIn('ORDER BY completed_at DESC', sql)
        self.assertIn('LEFT JOIN', sql)
        self.assertEqual(cur.execute.call_count, 1)
        conn.commit.assert_not_called()

    def test_route_requires_identity_and_disables_caching(self):
        import backend
        app = backend.app.test_client()
        self.assertEqual(app.get('/current-source').status_code, 401)
        document = source.accepted_document(fixture(), previews())
        conn = MagicMock()
        cur = conn.cursor.return_value.__enter__.return_value
        cur.fetchone.return_value = dict(role_name='Production Crew', policy_names=[])
        with patch.object(backend, 'database') as db, patch.object(source, 'load_current_source', return_value=document):
            db.return_value.__enter__.return_value = conn
            result = app.get('/current-source', headers={'Cf-Access-Authenticated-User-Email': 'crew@example.org'})
        self.assertEqual(result.status_code, 200)
        self.assertIn('no-store', result.headers['Cache-Control'])
        self.assertEqual(result.json['run_id'], 32)

    def test_crew_access_does_not_grant_reconciliation_operator_access(self):
        import backend
        app = backend.app.test_client()
        conn = MagicMock(); cur = conn.cursor.return_value.__enter__.return_value
        for role, status in [('Volunteer', 403), ('Production Crew', 200), ('Administrator', 200)]:
            with self.subTest(role=role), patch.object(backend, 'database') as db, patch.object(source, 'load_current_source', return_value=source.accepted_document(fixture(), previews())):
                db.return_value.__enter__.return_value = conn
                cur.fetchone.return_value = dict(role_name=role, policy_names=[])
                response = app.get('/current-source', headers={'Cf-Access-Authenticated-User-Email': 'crew@example.org'})
                self.assertEqual(response.status_code, status)
        with patch.dict(os.environ, {'LOR_PREFLIGHT_OPERATORS': 'admin@example.org'}), backend.app.test_request_context(headers={'Cf-Access-Authenticated-User-Email': 'crew@example.org'}):
            with self.assertRaises(backend.ApiError) as rejected:
                backend.operator_email()
            self.assertEqual(rejected.exception.status, 403)

    def test_shared_dashboard_does_not_grant_parser_or_ingest(self):
        import backend
        app = backend.app.test_client()
        headers = {'Cf-Access-Authenticated-User-Email': 'viewer@example.org'}
        with patch.dict(os.environ, {'LOR_PREFLIGHT_OPERATORS': 'admin@example.org'}), patch.object(backend, 'database'), patch.object(backend, 'load_dashboard', return_value={'workflow': {}}):
            self.assertEqual(app.get('/dashboard').status_code, 401)
            response = app.get('/dashboard', headers=headers)
            self.assertEqual(response.status_code, 200)
            self.assertFalse(response.json['access']['can_run_parser'])
            self.assertFalse(response.json['access']['can_operate_lor'])
            self.assertIn('no-store', response.headers['Cache-Control'])
            for path in ['/parser/run', '/ingest/start', '/parser/approve', '/runs/start']:
                with self.subTest(path=path):
                    self.assertEqual(app.post(path, headers=headers, json={}).status_code, 403)


if __name__ == '__main__':
    unittest.main()
