"""Catalog API authorization/forwarding tests, no production connection."""
import os
import unittest
from contextlib import contextmanager
from unittest.mock import patch,MagicMock
import backend

class CatalogApiTests(unittest.TestCase):
    def setUp(self):
        self.env=patch.dict(os.environ,{'LOR_PREVIEW_CATALOG_ENABLED':'true',
            'LOR_CATALOG_PUBLISHERS':'publisher@example.org','LOR_CATALOG_ORIGIN':'https://my.example.org'})
        self.env.start();self.addCleanup(self.env.stop)
        self.client=backend.app.test_client()
        self.headers={'Cf-Access-Authenticated-User-Email':'publisher@example.org','Origin':'https://my.example.org'}

    def test_no_identity_crew_parser_operator_and_wrong_origin_rejected_before_database(self):
        with patch.object(backend,'database') as db:
            for headers in [{},dict(self.headers,**{'Cf-Access-Authenticated-User-Email':'crew@example.org'}),
                            dict(self.headers,Origin='https://evil.example'),
                            {'Cf-Access-Authenticated-User-Email':'publisher@example.org'}]:
                for route in ('review','publish'):
                    response=self.client.post('/catalog/'+route,headers=headers,json={'review_id':'a'*64,'confirm_publish':True})
                    self.assertIn(response.status_code,(401,403))
            db.assert_not_called()

    def test_missing_confirmation_rejected(self):
        with patch.object(backend,'database') as db:
            response=self.client.post('/catalog/publish',headers=self.headers,json={'review_id':'a'*64})
            self.assertEqual(response.status_code,400);db.assert_not_called()

    def test_review_source_is_server_derived_and_does_not_accept_paths(self):
        connection=MagicMock()
        @contextmanager
        def db():yield connection
        with patch.object(backend,'database',db),patch('current_source.load_current_source',return_value={'evidence_id':'current'}) as load,patch.object(backend,'runner_request',return_value={'review_id':'a'*64}) as runner:
            response=self.client.post('/catalog/review',headers=self.headers,json={'accepted_source':{'evidence_id':'forged'},'source_folder':'evil'})
            self.assertEqual(response.status_code,200)
            self.assertEqual(runner.call_args.args,('catalog/review',{'accepted_source':{'evidence_id':'current'},'actor':'publisher@example.org'}))
            connection.commit.assert_not_called()

    def test_publication_fetches_latest_baseline_again(self):
        connection=MagicMock()
        @contextmanager
        def db():yield connection
        with patch.object(backend,'database',db),patch('current_source.load_current_source',return_value={'evidence_id':'new-current'}),patch.object(backend,'runner_request',return_value={'source':{'evidence_id':'catalog'}}) as runner:
            response=self.client.post('/catalog/publish',headers=self.headers,json={'review_id':'a'*64,'confirm_publish':True})
            self.assertEqual(response.status_code,200)
            self.assertEqual(runner.call_args.args[1]['accepted_source'],{'evidence_id':'new-current'})
            connection.commit.assert_not_called()

    def test_disabled_catalog_denies_publication(self):
        with patch.dict(os.environ,{'LOR_PREVIEW_CATALOG_ENABLED':'false'}):
            self.assertEqual(self.client.post('/catalog/review',headers=self.headers,json={}).status_code,403)

if __name__=='__main__':unittest.main()
