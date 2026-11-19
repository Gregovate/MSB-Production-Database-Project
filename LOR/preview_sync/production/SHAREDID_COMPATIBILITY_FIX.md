# Approved-version ViewMember.sharedid compatibility correction

Issue #299 / PR #300. Checker V1.4.2, 2026-11-02.

The complete XML inventory treated a newly encountered ViewMember.sharedid
attribute as parser-breaking even under approved LOR 6.6.12. The production
parser does not consume this attribute. Retain its finding as INFO only for
same-version comparisons. Other unknown attributes, other elements, and
cross-version comparisons retain their blocking behavior.

Controller changes still require the ordinary parser, SQLite review, ingest,
and reconciliation approvals. This correction does not approve those changes.
No XML or accepted manifests are edited. No automatic parser or ingest runs.

Validation: 21 compatibility regression tests passed, including four new tests
for same-version allowance, unknown-field rejection, other-element rejection,
and strict cross-version handling. Windows deployment remains operator pending.
The bounded installer backs up only the compatibility module, uses the existing
managed runner Stop/Start, and preserves task credentials and pairing.
