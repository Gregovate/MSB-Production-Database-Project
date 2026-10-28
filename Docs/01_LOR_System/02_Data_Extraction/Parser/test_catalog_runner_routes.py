"""Exercise actual runner dispatch/auth/lock with disposable catalog storage."""
import os
import threading
from types import SimpleNamespace
from unittest.mock import MagicMock, patch
from http import HTTPStatus
from lor_operator_runner import RequestHandler
import unittest
import test_preview_catalog as fixtures

class RunnerRoutesTests(unittest.TestCase):
    setUp = fixtures.CatalogTests.setUp
    def test_authenticated_dispatch_review_publish_and_current(self):
        env={'LOR_RUNNER_TOKEN':'token','LOR_CATALOG_ROOT':str(self.catalog.root),'LOR_CATALOG_PUBLISHERS':self.actor}
        runner=SimpleNamespace(store=SimpleNamespace(read=lambda:{'current_preview_folder':str(self.folder),'current_lor_version':'6.6.12'}),operation_lock=threading.Lock())
        handler=object.__new__(RequestHandler);handler.server=SimpleNamespace(runner=runner)
        handler.headers={'Authorization':'Bearer token'};handler.command='POST';handler.log_error=MagicMock()
        payload={'accepted_source':self.accepted,'actor':self.actor}
        handler.body=lambda:payload
        with patch.dict(os.environ,env):
            handler.path='/catalog/review';code,review=handler.dispatch()
            self.assertEqual(code,HTTPStatus.OK)
            payload.update(review_id=review['review_id'],confirm_publish=True)
            handler.path='/catalog/publish';code,publication=handler.dispatch()
            self.assertEqual(code,HTTPStatus.OK)
            handler.path='/catalog/current';code,current=handler.dispatch()
            self.assertEqual(current,publication)
            payload['actor']='crew@example.org';handler.path='/catalog/review'
            self.assertEqual(handler.dispatch()[0],HTTPStatus.FORBIDDEN)
            runner.operation_lock.acquire()
            self.assertEqual(handler.dispatch()[0],HTTPStatus.CONFLICT)
            runner.operation_lock.release()
            handler.headers={'Authorization':'Bearer wrong'}
            self.assertEqual(handler.dispatch()[0],HTTPStatus.UNAUTHORIZED)
