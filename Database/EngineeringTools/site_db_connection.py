"""Use the governed Setup/FieldWiring psycopg2 runtime for GIS intake.

Autocommit keeps projection reads from leaving idle transactions. Each importer
explicitly brackets all of its writes in one transaction; errors roll it back.
No dependency installation or production-runtime modification is performed.
"""
from contextlib import contextmanager


class SiteConnection:
    def __init__(self, raw):
        self.raw = raw
        self.raw.autocommit = True
        self._in_transaction = False

    @property
    def info(self):
        return self.raw.info

    def cursor(self):
        return self.raw.cursor()

    @contextmanager
    def transaction(self):
        # Current intake operations are independent atomic units. Reject nested
        # use instead of accidentally committing an outer caller's transaction.
        if self._in_transaction:
            raise RuntimeError('Nested GIS intake transactions are not supported')
        self._in_transaction = True
        try:
            with self.cursor() as cursor:
                cursor.execute('BEGIN')
            try:
                yield
                with self.cursor() as cursor:
                    cursor.execute('COMMIT')
            except BaseException:
                with self.cursor() as cursor:
                    cursor.execute('ROLLBACK')
                raise
        finally:
            self._in_transaction = False


@contextmanager
def connect(dsn):
    import psycopg2
    raw = psycopg2.connect(dsn)
    try:
        yield SiteConnection(raw)
    finally:
        raw.close()
