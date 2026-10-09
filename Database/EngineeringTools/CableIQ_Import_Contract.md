# CableIQ import and validation — #171 / #230

The October 2026 operator-supplied schema and 2021 CableIQ CSV establish the
first validation workflow. Run `validate_cableiq_import.py SOURCE --output REVIEW.json`.
This tool creates a review manifest only. It does not connect to PostgreSQL.

## Import workflow

1. Upload and retain the original export with a source checksum.
2. Validate the header layout, positional fields, row widths, date/time, units,
   lengths and individual application results. Report errors by source row.
3. Collapse exact duplicate rows in the review manifest, retaining every row
   reference. Preserve distinct retests. Record hashes support later idempotency.
4. Match human CableID labels to physical cable identities through reviewed
   source cross-references. Name similarity proposes a candidate; it does not
   approve a match. GG-10 is the operator-confirmed historical name of GG-11.
5. Review cable identity, endpoints, timezone, conflicts and source provenance.
6. Once the linked schema and writer exist, commit validated, approved records
   transactionally with an import receipt. Re-import must not duplicate tests.
   Retests append history; correction must retain original evidence.

## Record ownership

Reuse existing controller, Stage and Display identities and Wiring entry points.
The supplied October 9 dump has no dedicated physical cable/network/test tables;
design the smallest linked extension after inspecting draw.io source keys.
draw.io governs network identity/connectivity/test evidence; GPX supplies spatial
route evidence and currently lacks a shared reconciliation key. CableIQ supplies
qualification measurements. Preserve source attributes independently of editable
MSB network names, verified lengths and configuration values.

## Semantics and limits

Duplicate OperatorField2 headings are retained positionally. Overall Disqualified
may coexist with a Qualified application or wiremap. 1000BASE-T/100BASE-TX/10BASE-T
qualification is not actual throughput or current negotiated speed. Dates have no
timezone; do not fabricate UTC timestamps. The supplied export uses feet.

The supported header is explicit. A changed newer export must be reviewed before
adding a versioned adapter. Every manifest remains UNMATCHED and not ready for
database import; the CLI cannot approve records or write operational state.

## Validation evidence

The sample has 86 data rows, 48 distinct records, 38 duplicated records, and no
invalid records under this layout. Three focused tests cover positional duplicate
headers, duplicate source provenance, mixed application outcomes, retest identity,
invalid measurement rejection and unsupported layouts. Current Candyland cables
require current evidence following reconstruction of 12 cut cables.
