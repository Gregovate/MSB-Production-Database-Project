# Catalog baseline rollover and overwritten-export recovery

Issue #299 / PR #300, 2026-11-03.

Normal authoring exports overwrite existing master files while retaining UUIDs.
A completed ingest/reconciliation changes accepted-source evidence identity.
Previously, a new identity had no catalog baseline and bootstrap demanded the
original bytes even after normal authoring had overwritten them.

Before each configured catalog runner ingest, capture immutable catalog contracts
bound to the validated SQLite SHA256 and exact parser source manifest. Capture
uses XML only; background-file availability cannot block database evidence
capture. If the master changed after parsing, ingest stops before PostgreSQL.
The new run registers from that retained record after reconciliation, allowing
later exports without preserving old files manually.

For existing runs without a retained record, catalog review can recover using
the exact reconciled SQLite bytes and identical parser SHA256. It parses copied
current exports into a disposable TEST SQLite. Compare preview/stage identities,
physical props, subprops, DMX channels, scenes, and scene memberships. Exclude
only documented presentation fields: preview label/revision/background/viewing
preferences; scene background/viewport; prop master dimming; channel Name only
when nonblank Display Comment provides identity. All other parsed fields remain
strict, including UUIDs, Comment, network, Unit ID and channels. Unknown projected
differences block recovery rather than being silently accepted.

Only after proof and repeated source/digest checks does review append a baseline
with recovery provenance under the new accepted-source evidence ID. Old run
baselines, publications and pointers remain untouched. Publication still requires
the administrator's explicit approval. No master, production SQLite, runner
parser/ingest state, PostgreSQL, task credentials or pairing is changed by proof.
The runner's existing operation lock covers recovery. A bounded installer replaces
only preview_catalog.py and lor_operator_runner.py and retains exact-byte rollback.

Validation: 89 existing catalog tests (3 fixture-dependent skips), 9 rollover and
recovery tests, and an actual V7.0.11 disposable-parser recovery experiment passed.
Production installation/recovery remains operator pending. No catalog published.

Windows preflight originally stopped on leaked SQLite handles. Recovery reads now
explicitly close connections; fixture writes commit and close. A regression checks
closed handles on successful comparison and rejection. Production was unchanged
by that failed preflight. Corrected native Windows preflight remains pending.
